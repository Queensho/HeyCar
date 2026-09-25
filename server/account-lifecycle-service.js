const crypto=require('crypto');

function normalizeTrMobile(raw){
  let d=String(raw||'').replace(/\D/g,'');
  if(d.startsWith('90')&&d.length===12)d=d.slice(2);
  else if(d.startsWith('0')&&d.length===11)d=d.slice(1);
  return /^5\d{9}$/.test(d)?'+90'+d:null;
}
function normalizeRecoveryCode(raw){return String(raw||'').toUpperCase().replace(/[^A-Z0-9]/g,'');}
function recoveryHash(code){return crypto.createHash('sha256').update(normalizeRecoveryCode(code)).digest('hex');}
function recoveryCode(){
  const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const parts=[];
  for(let g=0;g<4;g++){
    let p='';
    for(let i=0;i<4;i++)p+=alphabet[crypto.randomInt(alphabet.length)];
    parts.push(p);
  }
  return 'CQ-'+parts.join('-');
}
async function ensureRecoverySchema(db){
  await db.query(`
    CREATE TABLE IF NOT EXISTS account_recovery_codes(
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS account_recovery_attempts(
      phone TEXT PRIMARY KEY,
      failed_count INTEGER NOT NULL DEFAULT 0,
      window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      blocked_until TIMESTAMPTZ
    );
  `);
}
async function issueRecoveryCode(db,userId){
  await ensureRecoverySchema(db);
  const code=recoveryCode();
  await db.query(`
    INSERT INTO account_recovery_codes(user_id,code_hash,created_at)
    VALUES($1,$2,NOW())
    ON CONFLICT(user_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,created_at=NOW()
  `,[userId,recoveryHash(code)]);
  return code;
}
async function roleExists(db,userId,mode){
  if(mode==='driver'){
    const r=await db.query('SELECT 1 FROM vehicle_drivers WHERE driver_user_id::text=$1 LIMIT 1',[String(userId)]);
    return Boolean(r.rows.length);
  }
  const r=await db.query('SELECT 1 FROM vehicles WHERE owner_id::text=$1 LIMIT 1',[String(userId)]);
  return Boolean(r.rows.length);
}
async function checkThrottle(db,phone){
  await ensureRecoverySchema(db);
  const r=await db.query('SELECT failed_count,window_started_at,blocked_until FROM account_recovery_attempts WHERE phone=$1',[phone]);
  if(!r.rows.length)return true;
  const x=r.rows[0];
  if(x.blocked_until&&new Date(x.blocked_until)>new Date())return false;
  if(new Date(x.window_started_at).getTime()<Date.now()-15*60*1000){
    await db.query('DELETE FROM account_recovery_attempts WHERE phone=$1',[phone]);
  }
  return true;
}
async function failedRecovery(db,phone){
  await db.query(`
    INSERT INTO account_recovery_attempts(phone,failed_count,window_started_at,blocked_until)
    VALUES($1,1,NOW(),NULL)
    ON CONFLICT(phone) DO UPDATE SET
      failed_count=CASE WHEN account_recovery_attempts.window_started_at<NOW()-INTERVAL '15 minutes' THEN 1 ELSE account_recovery_attempts.failed_count+1 END,
      window_started_at=CASE WHEN account_recovery_attempts.window_started_at<NOW()-INTERVAL '15 minutes' THEN NOW() ELSE account_recovery_attempts.window_started_at END,
      blocked_until=CASE
        WHEN (CASE WHEN account_recovery_attempts.window_started_at<NOW()-INTERVAL '15 minutes' THEN 1 ELSE account_recovery_attempts.failed_count+1 END)>=5
        THEN NOW()+INTERVAL '15 minutes'
        ELSE account_recovery_attempts.blocked_until
      END
  `,[phone]);
}
async function recoverPassword(db,{phone,recoveryCode:code,newPassword,mode}){
  const normalizedPhone=normalizeTrMobile(phone);
  if(!normalizedPhone||String(newPassword||'').length<6||!['owner','driver'].includes(mode))return {ok:false,error:'INVALID_INPUT'};
  if(!await checkThrottle(db,normalizedPhone))return {ok:false,error:'RECOVERY_RATE_LIMITED'};
  const c=await db.connect();
  try{
    await c.query('BEGIN');
    const r=await c.query(`
      SELECT u.id,rc.code_hash
      FROM users u
      JOIN account_recovery_codes rc ON rc.user_id=u.id
      WHERE u.phone=$1 AND u.status='active'
      LIMIT 1
      FOR UPDATE OF rc
    `,[normalizedPhone]);
    if(!r.rows.length||!normalizeRecoveryCode(code)||r.rows[0].code_hash!==recoveryHash(code)||!await roleExists(c,r.rows[0].id,mode)){
      await c.query('ROLLBACK');
      await failedRecovery(db,normalizedPhone);
      return {ok:false,error:'RECOVERY_INVALID'};
    }
    const userId=r.rows[0].id;
    await c.query(`UPDATE users SET password_hash=crypt($2,gen_salt('bf',12)) WHERE id=$1`,[userId,String(newPassword)]);
    await c.query('DELETE FROM account_recovery_codes WHERE user_id=$1',[userId]);
    await c.query('UPDATE owner_auth_sessions SET revoked_at=COALESCE(revoked_at,NOW()) WHERE owner_id=$1',[userId]);
    await c.query('UPDATE driver_auth_sessions SET revoked_at=COALESCE(revoked_at,NOW()) WHERE driver_id=$1',[userId]);
    await c.query('DELETE FROM account_recovery_attempts WHERE phone=$1',[normalizedPhone]);
    await c.query('COMMIT');
    return {ok:true};
  }catch(e){
    await c.query('ROLLBACK').catch(()=>{});
    throw e;
  }finally{c.release();}
}
async function verifyPassword(db,userId,password){
  const r=await db.query('SELECT 1 FROM users WHERE id::text=$1 AND password_hash=crypt($2,password_hash) LIMIT 1',[String(userId),String(password||'')]);
  return Boolean(r.rows.length);
}
async function tableExists(db,table){
  const r=await db.query('SELECT to_regclass($1) AS t',['public.'+table]);
  return Boolean(r.rows[0]&&r.rows[0].t);
}
async function deleteWhere(db,table,sql,params){
  if(!await tableExists(db,table))return;
  await db.query('DELETE FROM '+table+' WHERE '+sql,params);
}
async function deleteAccount(pool,userId,{mode}){
  const c=await pool.connect();
  try{
    await c.query('BEGIN');
    const uid=String(userId);
    if(mode==='driver'){
      const owns=await c.query('SELECT 1 FROM vehicles WHERE owner_id::text=$1 LIMIT 1',[uid]);
      if(owns.rows.length){await c.query('ROLLBACK');return {ok:false,error:'OWNER_ACCOUNT_EXISTS'};}
    }
    const vr=await c.query('SELECT id::text AS id FROM vehicles WHERE owner_id::text=$1',[uid]);
    const vehicleIds=vr.rows.map(x=>String(x.id));

    if(vehicleIds.length){
      const arr=vehicleIds;
      if(await tableExists(c,'qr_tags')){
        await c.query("UPDATE qr_tags SET vehicle_id=NULL,status='revoked',activated_at=NULL WHERE vehicle_id::text=ANY($1::text[])",[arr]);
      }
      await deleteWhere(c,'vehicle_maintenance_state','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_maintenance_records','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_maintenance_shares','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_reminders','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_reminder_deliveries','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_reminder_delivery_claims','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_parking_locations','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_active_drivers','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_drivers','vehicle_id=ANY($1::text[])',[arr]);
      await deleteWhere(c,'vehicle_driver_invites','vehicle_id::text=ANY($1::text[])',[arr]);
      await deleteWhere(c,'anonymous_calls','vehicle_id::text=ANY($1::text[])',[arr]);
      await c.query('DELETE FROM vehicles WHERE id::text=ANY($1::text[])',[arr]);
    }

    await deleteWhere(c,'vehicle_active_drivers','owner_id::text=$1 OR driver_user_id::text=$1',[uid]);
    await deleteWhere(c,'vehicle_drivers','owner_id::text=$1 OR driver_user_id::text=$1',[uid]);
    await deleteWhere(c,'vehicle_driver_invites','owner_id::text=$1 OR accepted_by::text=$1',[uid]);
    await deleteWhere(c,'anonymous_calls','owner_id::text=$1 OR recipient_user_id::text=$1',[uid]);
    await deleteWhere(c,'vehicle_notifications','recipient_user_id::text=$1',[uid]);
    await deleteWhere(c,'owner_push_tokens','owner_id::text=$1',[uid]);
    await deleteWhere(c,'driver_push_tokens','driver_id::text=$1',[uid]);
    for(const t of ['owner_privacy_settings','owner_devices','owner_blocked_visitors','qr_request_log','owner_login_events','owner_dnd_settings','owner_security_settings','owner_security_sessions','qr_security_request_log','owner_security_events']){
      await deleteWhere(c,t,'owner_id::text=$1',[uid]);
    }
    await deleteWhere(c,'account_recovery_codes','user_id::text=$1',[uid]);
    await deleteWhere(c,'owner_auth_sessions','owner_id::text=$1',[uid]);
    await deleteWhere(c,'driver_auth_sessions','driver_id::text=$1',[uid]);
    await deleteWhere(c,'correction_requests','owner_id::text=$1',[uid]);
    await deleteWhere(c,'vehicle_transfers','from_owner_id::text=$1 OR accepted_by::text=$1',[uid]);
    const del=await c.query('DELETE FROM users WHERE id::text=$1 RETURNING id',[uid]);
    if(!del.rows.length){await c.query('ROLLBACK');return {ok:false,error:'USER_NOT_FOUND'};}
    await c.query('COMMIT');
    return {ok:true};
  }catch(e){
    await c.query('ROLLBACK').catch(()=>{});
    throw e;
  }finally{c.release();}
}

module.exports={normalizeTrMobile,issueRecoveryCode,recoverPassword,verifyPassword,deleteAccount};
