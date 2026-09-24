const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const {driverId: authenticatedDriverId}=require('./driver-auth-service');
const crypto=require('crypto');
const fs=require('fs');

function serviceAccount(){
  const raw=process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if(raw) return JSON.parse(raw);
  const file=process.env.FIREBASE_SERVICE_ACCOUNT_FILE;
  if(file) return JSON.parse(fs.readFileSync(file,'utf8'));
  return null;
}

async function accessToken(){
  const sa=serviceAccount();
  if(!sa) return null;
  const now=Math.floor(Date.now()/1000);
  const b64=o=>Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned=`${b64({alg:'RS256',typ:'JWT'})}.${b64({iss:sa.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})}`;
  const sig=crypto.sign('RSA-SHA256',Buffer.from(unsigned),sa.private_key).toString('base64url');
  const r=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${unsigned}.${sig}`})});
  if(!r.ok){const detail=await r.text();throw new Error(`FCM_AUTH_${r.status}: ${detail}`);}
  return (await r.json()).access_token;
}

module.exports=function registerPushRoutes(app,pool){
  const existing=app.locals.heycarPush;
  if(existing&&(typeof existing.sendOwner==='function'||typeof existing.send==='function'))return existing;
  if(existing){
    console.warn('Replacing invalid Cepqar push service instance');
    delete app.locals.heycarPush;
  }
  let ready=false;
  const health={
    registeredAt:new Date().toISOString(),
    lastAttemptAt:null,
    lastSuccessAt:null,
    lastFailureAt:null,
    lastAttempted:0,
    lastDelivered:0,
    lastError:null,
  };
  const markFailure=(e)=>{
    health.lastFailureAt=new Date().toISOString();
    health.lastError=String(e?.message||e||'Push error').slice(0,800);
  };
  async function schema(){
    if(ready)return;
    const check=await pool.query("SELECT to_regclass('public.owner_push_tokens') AS owner_tokens, to_regclass('public.driver_push_tokens') AS driver_tokens");
    const row=check.rows[0]||{};
    if(!row.owner_tokens||!row.driver_tokens)throw new Error('PUSH_SCHEMA_MISSING');
    ready=true;
  }

  app.post('/api/owner/push-token',async(req,res)=>{try{const owner=authenticatedOwnerId(req);const token=String(req.body?.token||'').trim();const device=String(req.body?.deviceId||'').trim();const platform=String(req.body?.platform||'android').trim();if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});if(!token||!device)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});await schema();await pool.query(`INSERT INTO owner_push_tokens(owner_id,device_id,fcm_token,platform) VALUES($1,$2,$3,$4) ON CONFLICT(owner_id,device_id) DO UPDATE SET fcm_token=EXCLUDED.fcm_token,platform=EXCLUDED.platform,active=TRUE,updated_at=NOW()`,[owner,device,token,platform]);await pool.query('UPDATE owner_push_tokens SET active=FALSE,updated_at=NOW() WHERE owner_id=$1 AND fcm_token=$2 AND device_id<>$3',[owner,token,device]);return res.json({ok:true});}catch(e){console.error('push token',e);return res.status(500).json({error:'SERVER_ERROR'});}});

  app.post('/api/driver/push-token',async(req,res)=>{try{const driver=authenticatedDriverId(req);const token=String(req.body?.token||'').trim();const device=String(req.body?.deviceId||'').trim();const platform=String(req.body?.platform||'android').trim();if(!driver)return res.status(401).json({error:'DRIVER_REQUIRED'});if(!token||!device)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});await schema();await pool.query(`INSERT INTO driver_push_tokens(driver_id,device_id,fcm_token,platform) VALUES($1,$2,$3,$4) ON CONFLICT(driver_id,device_id) DO UPDATE SET fcm_token=EXCLUDED.fcm_token,platform=EXCLUDED.platform,active=TRUE,updated_at=NOW()`,[driver,device,token,platform]);await pool.query('UPDATE driver_push_tokens SET active=FALSE,updated_at=NOW() WHERE driver_id=$1 AND fcm_token=$2 AND device_id<>$3',[driver,token,device]);return res.json({ok:true});}catch(e){console.error('driver push token',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.delete('/api/driver/push-token',async(req,res)=>{try{const driver=authenticatedDriverId(req);const device=String(req.query?.deviceId||req.body?.deviceId||'').trim();if(!driver)return res.status(401).json({error:'DRIVER_REQUIRED'});if(!device)return res.status(400).json({error:'DEVICE_REQUIRED'});await schema();await pool.query('UPDATE driver_push_tokens SET active=FALSE,updated_at=NOW() WHERE driver_id=$1 AND device_id=$2',[driver,device]);return res.json({ok:true});}catch(e){console.error('driver push token deactivate',e);return res.status(500).json({error:'SERVER_ERROR'});}});

  async function sendFrom(table,idColumn,userId,data,title,body){
    health.lastAttemptAt=new Date().toISOString();
    health.lastError=null;
    await schema();
    let sa,key;
    try{
      sa=serviceAccount();
      key=await accessToken();
    }catch(e){
      markFailure(e);
      throw e;
    }
    if(!key||!sa){
      markFailure('Firebase service account missing');
      console.warn('Firebase service account missing; push skipped');
      health.lastAttempted=0;health.lastDelivered=0;
      return {attempted:0,delivered:0};
    }
    const project=sa.project_id;
    const rows=(await pool.query(
      `SELECT DISTINCT ON (fcm_token) id,fcm_token FROM ${table} WHERE ${idColumn}=$1 AND active=TRUE ORDER BY fcm_token,updated_at DESC`,
      [String(userId)]
    )).rows;
    if(!rows.length){health.lastAttempted=0;health.lastDelivered=0;return {attempted:0,delivered:0};}

    const callEvent=data.type==='incoming_call'||data.type==='incoming_call_cancelled';
    const fcmData=Object.fromEntries(Object.entries({...data,title,body}).map(([k,v])=>[k,String(v??'')]));
    const endpoint=`https://fcm.googleapis.com/v1/projects/${project}/messages:send`;

    const results=await Promise.all(rows.map(async row=>{
      const android={priority:'HIGH'};
      if(callEvent){
        android.ttl=data.type==='incoming_call'?'45s':'15s';
        android.collapse_key='cepqar_call_'+String(data.callId||userId);
      }else{
        android.ttl='120s';
      }
      const message={token:row.fcm_token,data:fcmData,android};
      if(!callEvent){
        const sourceType=String(data.sourceType||data.type||'system');
        android.collapse_key='cepqar_'+sourceType;
        const tag=String(data.notificationId||data.messageId||data.eventId||Date.now());
        message.notification={title,body};
        message.android.notification={
          channel_id:'cepqar_notifications_v9',
          sound:'bildirim',
          tag:'cepqar_'+tag,
          notification_priority:'PRIORITY_MAX',
          default_vibrate_timings:true,
          visibility:'PUBLIC'
        };
      }
      try{
        const r=await fetch(endpoint,{method:'POST',headers:{authorization:`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify({message})});
        if(r.ok)return true;
        const detail=await r.text();
        console.error('FCM send',r.status,detail);
        if(r.status===404||detail.includes('UNREGISTERED')||detail.includes('NotRegistered')){
          await pool.query(`UPDATE ${table} SET active=FALSE,updated_at=NOW() WHERE id=$1`,[row.id]).catch(()=>{});
        }
        return false;
      }catch(e){
        console.error('FCM transport',e);
        return false;
      }
    }));

    const delivered=results.filter(Boolean).length;
    health.lastAttempted=rows.length;
    health.lastDelivered=delivered;
    if(delivered>0){
      health.lastSuccessAt=new Date().toISOString();
      health.lastError=null;
    }else if(rows.length>0){
      markFailure('FCM delivery failed for all active tokens');
    }
    return {attempted:rows.length,delivered};
  }
  const sendOwner=(owner,data,title,body)=>sendFrom('owner_push_tokens','owner_id',owner,data,title,body);
  const sendDriver=(driver,data,title,body)=>sendFrom('driver_push_tokens','driver_id',driver,data,title,body);
  const send=sendOwner;
  const getHealth=()=>({...health});
  app.locals.heycarPush={send,sendOwner,sendDriver,getHealth,health};
  console.log('Cepqar push service registered');
  return app.locals.heycarPush;
};
