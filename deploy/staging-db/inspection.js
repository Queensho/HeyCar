'use strict';
const crypto=require('node:crypto');
function renderSql(template,database){
 if(database!=='heycar_staging'&&!/^heycar_recovery_test_[0-9a-f]{16}$/.test(database))throw Error('REHEARSAL_DATABASE_REJECTED');
 return template.replaceAll('__TARGET_DATABASE__',database);
}
async function accountReview(client){
 // No password/token hashes, phone numbers, names or emails are returned.
 const profiles=(await client.query(`WITH normalized AS (
 SELECT u.*,CASE
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^90[5][0-9]{9}$' THEN '+'||regexp_replace(phone,'[^0-9]','','g')
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^0[5][0-9]{9}$' THEN '+90'||substring(regexp_replace(phone,'[^0-9]','','g') from 2)
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^[5][0-9]{9}$' THEN '+90'||regexp_replace(phone,'[^0-9]','','g')
 ELSE phone END AS canonical FROM public.users u),
 duplicates AS (SELECT canonical,dense_rank() OVER(ORDER BY canonical)::int AS group_no
 FROM normalized WHERE phone IS NOT NULL GROUP BY canonical HAVING count(*)>1)
 SELECT u.id::text AS private_id,u.role,u.status,u.password_hash IS NULL AS null_password,
 u.email IS NOT NULL AND length(btrim(u.email))>0 AS has_email,u.phone IS NOT NULL AS has_phone,
 CASE WHEN u.phone ~ '^[+]905[0-9]{9}$' THEN 'TR_E164'
 WHEN u.phone ~ '^05[0-9]{9}$' THEN 'TR_LOCAL_0'
 WHEN u.phone ~ '^5[0-9]{9}$' THEN 'TR_LOCAL_10' ELSE 'OTHER_OR_EMPTY' END AS phone_form,
 u.phone IS DISTINCT FROM u.canonical AS would_normalize,d.group_no AS collision_group,
 (SELECT count(*)::int FROM public.vehicles v WHERE v.owner_id=u.id) AS vehicles,
 (SELECT count(*)::int FROM public.marketplace_appointments a WHERE a.owner_id=u.id::text) AS appointments,
 (SELECT count(*)::int FROM public.owner_auth_sessions s WHERE s.owner_id=u.id AND s.revoked_at IS NULL AND s.expires_at>now()) AS active_owner_sessions,
 (SELECT count(*)::int FROM public.driver_auth_sessions s WHERE s.driver_id=u.id AND s.revoked_at IS NULL AND s.expires_at>now()) AS active_driver_sessions
 FROM normalized u LEFT JOIN duplicates d ON d.canonical=u.canonical
 WHERE u.password_hash IS NULL OR d.group_no IS NOT NULL ORDER BY u.id`)).rows;
 const privateReferences=[],accounts=profiles.map((row,i)=>{
  const {private_id,...facts}=row,reference='account-review-'+(i+1);
  privateReferences.push({reference,id:private_id});return {reference,...facts};
 });
 return {accounts,privateReferences};
}
async function orphanReview(client){
 const tables=['vehicle_maintenance_state','vehicle_maintenance_records','vehicle_maintenance_shares','vehicle_reminders',
 'vehicle_reminder_deliveries','vehicle_parking_locations','vehicle_active_drivers','vehicle_drivers','vehicle_driver_invites','anonymous_calls','qr_tags'];
 const columns=(await client.query("SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='public' AND table_name=ANY($1::text[])",[tables.concat('vehicle_reminder_delivery_claims')])).rows;
 const results=[];
 for(const table of tables){
  const present=columns.filter(c=>c.table_name===table);
  if(!present.length){results.push({table,status:'absent'});continue;}
  if(!present.some(c=>c.column_name==='vehicle_id')){results.push({table,status:'unverified_no_vehicle_id'});continue;}
  const n=(await client.query('SELECT count(*)::int AS n FROM public."'+table+'" d WHERE d.vehicle_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.vehicles v WHERE v.id::text=d.vehicle_id::text)')).rows[0].n;
  results.push({table,orphan_rows:n});
 }
 const claims=columns.filter(c=>c.table_name==='vehicle_reminder_delivery_claims');
 if(claims.some(c=>c.column_name==='reminder_id')){
  const n=(await client.query(`SELECT count(*)::int AS n FROM public.vehicle_reminder_delivery_claims c
   LEFT JOIN public.vehicle_reminders r ON r.id=c.reminder_id
   WHERE r.id IS NULL OR NOT EXISTS(SELECT 1 FROM public.vehicles v WHERE v.id::text=r.vehicle_id::text)`)).rows[0].n;
  results.push({table:'vehicle_reminder_delivery_claims',relation:'reminder_id -> vehicle_reminders -> vehicles',orphan_rows:n});
 }else results.push({table:'vehicle_reminder_delivery_claims',status:claims.length?'unverified_layout':'absent'});
 return results;
}
async function rowFingerprint(client){
 const hashes={};
 for(const table of ['users','vehicles']){
  const rows=(await client.query('SELECT to_jsonb(t)::text AS row FROM public."'+table+'" t ORDER BY id')).rows;
  const hash=crypto.createHash('sha256');for(const row of rows)hash.update(row.row+'\n');hashes[table]=hash.digest('hex');
 }
 return hashes;
}
async function rehearse({restore,database,sqlTemplate}){
 if(!/^heycar_recovery_test_[0-9a-f]{16}$/.test(database))throw Error('ISOLATED_RESTORE_REQUIRED');
 if((await restore.query('SELECT current_database() AS db')).rows[0].db!==database)throw Error('ISOLATED_RESTORE_REQUIRED');
 const before=await rowFingerprint(restore),checks=[];
 const rolesBefore=(await restore.query("SELECT roleid,member,grantor,admin_option,inherit_option,set_option FROM pg_auth_members ORDER BY roleid,member,grantor")).rows;
 const dbAclBefore=(await restore.query('SELECT datname,datacl::text AS acl FROM pg_database ORDER BY datname')).rows;
 const schemaAclBefore=(await restore.query("SELECT nspacl::text AS acl FROM pg_namespace WHERE nspname='public'")).rows;
 await restore.query(renderSql(sqlTemplate,database));
 async function asRole(role,sql,expectedCode){
  await restore.query('SET ROLE "'+role+'"');
  try{
   try{const r=await restore.query(sql);if(expectedCode)throw Error('EXPECTED_REJECTION_MISSING');return {ok:true,result:r.rows[0]?.result};}
   catch(error){if(expectedCode&&error.code===expectedCode)return {ok:true,expected_rejection:error.code};throw error;}
  }finally{await restore.query('RESET ROLE');}
 }
 checks.push({name:'runtime_direct_ddl_denied',...await asRole('cepqontag_staging','ALTER TABLE public.users ALTER COLUMN display_name SET NOT NULL','42501')});
 checks.push({name:'runtime_cannot_execute_phone_repair',...await asRole('cepqontag_staging','SELECT staging_migration_control.apply_phone_index()','42501')});
 checks.push({name:'runtime_cannot_execute_password_repair',...await asRole('cepqontag_staging','SELECT staging_migration_control.apply_password_constraint()','42501')});
 checks.push({name:'fixed_null_free_ddl',...await asRole('cepqontag_staging','SELECT staging_migration_control.apply_null_free_constraints() AS result')});
 checks.push({name:'one_time_capability_revoked',...await asRole('cepqontag_staging','SELECT staging_migration_control.apply_null_free_constraints()','42501')});
 const blocked=[];
 for(const [name,sql,codes] of [
  ['phone','SELECT staging_migration_control.apply_phone_index() AS result',['23505','23514']],
  ['password','SELECT staging_migration_control.apply_password_constraint() AS result',['23514']]]){
  try{
   if(name==='phone'){
    // CREATE INDEX needs CREATE on its table's namespace as well as ownership.
    // Grant/revoke in one DBA transaction: no other session sees an added grant.
    await restore.query('BEGIN');
    try{
     const needsCreate=!(await restore.query("SELECT has_schema_privilege('heycar_user','public','CREATE') AS allowed")).rows[0].allowed;
     if(needsCreate)await restore.query('GRANT CREATE ON SCHEMA public TO heycar_user');
     await restore.query('SET LOCAL ROLE heycar_user');
     const result={ok:true,result:(await restore.query(sql)).rows[0]?.result};
     // Recheck the existing-index branch; IF NOT EXISTS must not mask wrong DDL.
     await restore.query(sql);
     await restore.query('RESET ROLE');
     if(needsCreate)await restore.query('REVOKE CREATE ON SCHEMA public FROM heycar_user');
     await restore.query('COMMIT');checks.push({name:name+'_owner_precondition',temporary_schema_create:needsCreate,...result});
    }catch(error){await restore.query('ROLLBACK');throw error;}
   }else checks.push({name:name+'_owner_precondition',...await asRole('heycar_user',sql)});
  }catch(error){if(!codes.includes(error.code))throw error;blocked.push({operation:name,sqlstate:error.code});}
 }
 const after=await rowFingerprint(restore);
 if(JSON.stringify(before)!==JSON.stringify(after))throw Error('RESTORE_ACCOUNT_DATA_CHANGED');
 const rolesAfter=(await restore.query('SELECT roleid,member,grantor,admin_option,inherit_option,set_option FROM pg_auth_members ORDER BY roleid,member,grantor')).rows;
 const dbAclAfter=(await restore.query('SELECT datname,datacl::text AS acl FROM pg_database ORDER BY datname')).rows;
 const schemaAclAfter=(await restore.query("SELECT nspacl::text AS acl FROM pg_namespace WHERE nspname='public'")).rows;
 if(JSON.stringify(rolesBefore)!==JSON.stringify(rolesAfter)||JSON.stringify(dbAclBefore)!==JSON.stringify(dbAclAfter))throw Error('DATABASE_OR_GLOBAL_ROLE_GRANTS_CHANGED');
 if(JSON.stringify(schemaAclBefore)!==JSON.stringify(schemaAclAfter))throw Error('PUBLIC_SCHEMA_PRIVILEGES_CHANGED');
 return {success:true,checks,blocked,account_data_unchanged:true,global_role_memberships_unchanged:true,database_acls_unchanged:true,public_schema_acl_unchanged:true,source_ddl_attempted:false};
}
module.exports={renderSql,accountReview,orphanReview,rehearse};
