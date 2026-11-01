'use strict';
const crypto=require('node:crypto');
const operations=[
 {name:'092_invite_lockout',table:'towing_provider_drivers',constraint:'towing_provider_drivers_invite_failed_attempts_check',
  constraintDefinition:'CHECK (invite_failed_attempts >= 0 AND invite_failed_attempts <= 5)',sql:`
 ALTER TABLE public.towing_provider_drivers ADD COLUMN IF NOT EXISTS invite_failed_attempts integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS invite_locked_at timestamptz;
 DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.towing_provider_drivers WHERE invite_failed_attempts<0 OR invite_failed_attempts>5) THEN
 RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='INVITE_ATTEMPTS_REVIEW_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.towing_provider_drivers'::regclass AND conname='towing_provider_drivers_invite_failed_attempts_check') THEN
 ALTER TABLE public.towing_provider_drivers ADD CONSTRAINT towing_provider_drivers_invite_failed_attempts_check CHECK(invite_failed_attempts>=0 AND invite_failed_attempts<=5) NOT VALID;
 END IF; END $$;
 ALTER TABLE public.towing_provider_drivers VALIDATE CONSTRAINT towing_provider_drivers_invite_failed_attempts_check;`},
 {name:'041_reminder_type_check_only',table:'vehicle_reminders',constraint:'vehicle_reminders_type_check',
  constraintDefinition:"CHECK (type = ANY (ARRAY['inspection'::text, 'traffic_insurance'::text, 'kasko'::text, 'maintenance'::text]))",sql:`
 DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.vehicle_reminders WHERE type NOT IN ('inspection','traffic_insurance','kasko','maintenance')) THEN
 RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='REMINDER_TYPE_REVIEW_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.vehicle_reminders'::regclass AND conname='vehicle_reminders_type_check') THEN
 ALTER TABLE public.vehicle_reminders ADD CONSTRAINT vehicle_reminders_type_check CHECK(type IN ('inspection','traffic_insurance','kasko','maintenance')) NOT VALID;
 END IF; END $$;
 ALTER TABLE public.vehicle_reminders VALIDATE CONSTRAINT vehicle_reminders_type_check;`},
 {name:'094_active_call_index',table:'anonymous_calls',index:'uq_anonymous_calls_active_recipient',requiresCreate:true,
  definition:"CREATE UNIQUE INDEX uq_anonymous_calls_active_recipient ON public.anonymous_calls USING btree (recipient_user_id) WHERE (status = ANY (ARRAY['ringing'::text, 'accepted'::text]))",
  precondition:"SELECT recipient_user_id FROM public.anonymous_calls WHERE recipient_user_id IS NOT NULL AND status IN ('ringing','accepted') GROUP BY recipient_user_id HAVING count(*)>1",
  sql:"CREATE UNIQUE INDEX IF NOT EXISTS uq_anonymous_calls_active_recipient ON public.anonymous_calls(recipient_user_id) WHERE status IN ('ringing','accepted')"},
 {name:'095_global_valet_index',table:'valet_sessions',index:'uq_valet_active_vehicle_global',requiresCreate:true,
  definition:"CREATE UNIQUE INDEX uq_valet_active_vehicle_global ON public.valet_sessions USING btree (vehicle_id) WHERE ((vehicle_id IS NOT NULL) AND (status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])))",
  precondition:"SELECT vehicle_id FROM public.valet_sessions WHERE vehicle_id IS NOT NULL AND status NOT IN ('delivered','cancelled') GROUP BY vehicle_id HAVING count(*)>1",
  sql:"CREATE UNIQUE INDEX IF NOT EXISTS uq_valet_active_vehicle_global ON public.valet_sessions(vehicle_id) WHERE vehicle_id IS NOT NULL AND status NOT IN ('delivered','cancelled')"},
 {name:'100_pending_redemption_index',table:'offer_redemptions',index:'uq_offer_pending_owner_campaign',requiresCreate:true,
  definition:"CREATE UNIQUE INDEX uq_offer_pending_owner_campaign ON public.offer_redemptions USING btree (owner_id, campaign_id) WHERE (status = 'pending'::text)",
  precondition:"SELECT owner_id,campaign_id FROM public.offer_redemptions WHERE owner_id IS NOT NULL AND campaign_id IS NOT NULL AND status='pending' GROUP BY owner_id,campaign_id HAVING count(*)>1",
  sql:"CREATE UNIQUE INDEX IF NOT EXISTS uq_offer_pending_owner_campaign ON public.offer_redemptions(owner_id,campaign_id) WHERE status='pending'"},
 {name:'097_store_order_fk',table:'store_orders',constraint:'store_orders_owner_id_fkey',
  constraintDefinition:'FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE SET NULL',sql:`
 DO $$ DECLARE current_definition text;
 BEGIN
 SELECT pg_get_constraintdef(oid,true) INTO current_definition FROM pg_constraint WHERE conrelid='public.store_orders'::regclass AND conname='store_orders_owner_id_fkey';
 IF current_definition IS NULL OR current_definition NOT IN ('FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE RESTRICT','FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE SET NULL') THEN
 RAISE EXCEPTION 'STORE_OWNER_FK_REVIEW_REQUIRED'; END IF;
 ALTER TABLE public.store_orders ALTER COLUMN owner_id DROP NOT NULL;
 IF current_definition='FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE RESTRICT' THEN
 ALTER TABLE public.store_orders DROP CONSTRAINT store_orders_owner_id_fkey;
 ALTER TABLE public.store_orders ADD CONSTRAINT store_orders_owner_id_fkey FOREIGN KEY(owner_id) REFERENCES public.users(id) ON DELETE SET NULL NOT VALID;
 END IF;
 END $$;
 ALTER TABLE public.store_orders VALIDATE CONSTRAINT store_orders_owner_id_fkey;`},
 {name:'042_maintenance_default_only',table:'app_settings',sql:"ALTER TABLE public.app_settings ALTER COLUMN maintenance_message SET DEFAULT 'CepQontag kısa süre içinde tekrar kullanılabilir olacak.'"}
];
async function fingerprint(client,table){
 const rows=(await client.query('SELECT (to_jsonb(t)'+(table==='towing_provider_drivers'?"-'invite_failed_attempts'-'invite_locked_at'":'')+')::text AS row FROM public."'+table+'" t')).rows;
 const hash=crypto.createHash('sha256');for(const row of rows.map(r=>r.row).sort())hash.update(row+'\n');return hash.digest('hex');
}
async function rehearseIndependent(client,database){
 if(!/^heycar_recovery_test_[0-9a-f]{16}$/.test(database)||(await client.query('SELECT current_database() AS db')).rows[0].db!==database)throw Error('ISOLATED_RESTORE_REQUIRED');
 const results=[];
 for(const op of operations){
  const present=(await client.query('SELECT to_regclass($1) IS NOT NULL AS present',['public.'+op.table])).rows[0].present;
  if(!present){results.push({operation:op.name,status:'not_present_not_repaired'});continue;}
  const before=await fingerprint(client,op.table);
  await client.query('BEGIN');
  try{
   await client.query("SET LOCAL search_path=pg_catalog; SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='30s'");
   const owner=(await client.query('SELECT pg_get_userbyid(relowner) AS owner FROM pg_class WHERE oid=$1::regclass',['public.'+op.table])).rows[0].owner;
   if(owner!=='heycar_user')throw Object.assign(Error('OWNER_REVIEW_REQUIRED'),{code:'42501'});
   const needsCreate=op.requiresCreate&&!(await client.query("SELECT has_schema_privilege('heycar_user','public','CREATE') AS allowed")).rows[0].allowed;
   if(needsCreate)await client.query('GRANT CREATE ON SCHEMA public TO heycar_user');
   await client.query('SET LOCAL ROLE heycar_user');
   await client.query('LOCK TABLE public."'+op.table+'" IN ACCESS EXCLUSIVE MODE');
   if(op.precondition&&(await client.query('SELECT count(*)::int AS n FROM ('+op.precondition+') conflicts')).rows[0].n>0)
    throw Object.assign(Error('EXISTING_RECORDS_REQUIRE_REVIEW'),{code:'23505'});
   if(op.index){
    const existing=(await client.query("SELECT i.indisvalid AS valid,i.indisready AS ready,pg_get_indexdef(i.indexrelid) AS definition FROM pg_index i WHERE i.indexrelid=to_regclass($1)",['public.'+op.index])).rows[0];
    if(existing&&(!existing.valid||!existing.ready||existing.definition!==op.definition))throw Error('INDEX_DEFINITION_REVIEW_REQUIRED');
   }
   await client.query(op.sql);
   if(op.constraint){
    const constraint=(await client.query('SELECT convalidated AS valid,pg_get_constraintdef(oid,true) AS definition FROM pg_constraint WHERE conrelid=$1::regclass AND conname=$2',['public.'+op.table,op.constraint])).rows[0];
    if(!constraint?.valid||constraint.definition!==op.constraintDefinition)throw Error('CONSTRAINT_DEFINITION_REVIEW_REQUIRED');
   }
   if(op.index){
    const index=(await client.query("SELECT i.indisvalid AS valid,i.indisready AS ready,pg_get_indexdef(i.indexrelid) AS definition FROM pg_index i WHERE i.indexrelid=to_regclass($1)",['public.'+op.index])).rows[0];
    if(!index?.valid||!index.ready||index.definition!==op.definition)throw Error('INDEX_DEFINITION_REVIEW_REQUIRED');
   }
   await client.query('RESET ROLE');
   if(needsCreate)await client.query('REVOKE CREATE ON SCHEMA public FROM heycar_user');
   await client.query('COMMIT');
   if(before!==await fingerprint(client,op.table))throw Error('RESTORE_EXISTING_VALUES_CHANGED');
   results.push({operation:op.name,status:'verified_on_restore',existing_values_unchanged:true});
  }catch(error){
   await client.query('ROLLBACK');
   if(before!==await fingerprint(client,op.table))throw Error('RESTORE_EXISTING_VALUES_CHANGED');
   results.push({operation:op.name,status:'blocked_no_record_changes',sqlstate:/^[A-Z0-9]{5}$/.test(error.code||'')?error.code:'REVIEW'});
  }
 }
 return results;
}
module.exports={operations,rehearseIndependent};
