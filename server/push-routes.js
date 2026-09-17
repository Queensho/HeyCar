const crypto=require('crypto');

async function accessToken(){
  const raw=process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if(!raw) return null;
  const sa=JSON.parse(raw);
  const now=Math.floor(Date.now()/1000);
  const b64=o=>Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned=`${b64({alg:'RS256',typ:'JWT'})}.${b64({iss:sa.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})}`;
  const sig=crypto.sign('RSA-SHA256',Buffer.from(unsigned),sa.private_key).toString('base64url');
  const r=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${unsigned}.${sig}`})});
  if(!r.ok) throw new Error(`FCM_AUTH_${r.status}`);
  return (await r.json()).access_token;
}

module.exports=function registerPushRoutes(app,pool){
  let ready=false;
  async function schema(){if(ready)return;await pool.query(`CREATE TABLE IF NOT EXISTS owner_push_tokens(id BIGSERIAL PRIMARY KEY,owner_id TEXT NOT NULL,device_id TEXT NOT NULL,fcm_token TEXT NOT NULL,platform TEXT NOT NULL DEFAULT 'android',active BOOLEAN NOT NULL DEFAULT TRUE,updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),UNIQUE(owner_id,device_id)); CREATE INDEX IF NOT EXISTS idx_owner_push_tokens_owner ON owner_push_tokens(owner_id,active);`);ready=true;}

  app.post('/api/owner/push-token',async(req,res)=>{try{const owner=String(req.headers['x-owner-id']||'').trim();const token=String(req.body?.token||'').trim();const device=String(req.body?.deviceId||'').trim();const platform=String(req.body?.platform||'android').trim();if(!owner||!token||!device)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});await schema();await pool.query(`INSERT INTO owner_push_tokens(owner_id,device_id,fcm_token,platform) VALUES($1,$2,$3,$4) ON CONFLICT(owner_id,device_id) DO UPDATE SET fcm_token=EXCLUDED.fcm_token,platform=EXCLUDED.platform,active=TRUE,updated_at=NOW()`,[owner,device,token,platform]);return res.json({ok:true});}catch(e){console.error('push token',e);return res.status(500).json({error:'SERVER_ERROR'});}});

  async function send(owner,data,title,body){await schema();const key=await accessToken();if(!key){console.warn('FIREBASE_SERVICE_ACCOUNT_JSON missing; push skipped');return;}const project=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON).project_id;const rows=(await pool.query(`SELECT fcm_token FROM owner_push_tokens WHERE owner_id=$1 AND active=TRUE`,[String(owner)])).rows;for(const row of rows){const call=data.type==='incoming_call';const payload={message:{token:row.fcm_token,data:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,String(v??'')])),android:{priority:'HIGH',notification:{channel_id:call?'heycar_incoming_calls':'heycar_notifications',sound:'default',visibility:'PUBLIC',notification_priority:call?'PRIORITY_MAX':'PRIORITY_HIGH'}},notification:{title,body}}};const r=await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`,{method:'POST',headers:{authorization:`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify(payload)});if(!r.ok)console.error('FCM send',r.status,await r.text());}}
  app.locals.heycarPush={send};
};
