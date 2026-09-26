const webpush=require('web-push');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {driverId:authenticatedDriverId}=require('./driver-auth-service');

module.exports=function registerWebPush(app,pool){
  const publicKey=String(process.env.WEB_PUSH_VAPID_PUBLIC_KEY||'').trim();
  const privateKey=String(process.env.WEB_PUSH_VAPID_PRIVATE_KEY||'').trim();
  const subject=String(process.env.WEB_PUSH_VAPID_SUBJECT||'mailto:support@cepqar.com').trim();
  const enabled=Boolean(publicKey&&privateKey);
  if(enabled)webpush.setVapidDetails(subject,publicKey,privateKey);

  app.get('/api/push/web/config',(_req,res)=>res.json({ok:true,enabled,publicKey:enabled?publicKey:''}));

  app.post('/api/owner/web-push-subscription',async(req,res)=>{
    try{
      const owner=authenticatedOwnerId(req);
      if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
      if(!enabled)return res.status(503).json({error:'WEB_PUSH_NOT_CONFIGURED'});
      const endpoint=String(req.body?.endpoint||'').trim();
      const p256dh=String(req.body?.keys?.p256dh||'').trim();
      const auth=String(req.body?.keys?.auth||'').trim();
      if(!endpoint||!p256dh||!auth)return res.status(400).json({error:'INVALID_SUBSCRIPTION'});
      await pool.query(
        `INSERT INTO owner_web_push_subscriptions(owner_id,endpoint,p256dh,auth,user_agent,active)
         VALUES($1,$2,$3,$4,$5,TRUE)
         ON CONFLICT(endpoint) DO UPDATE SET owner_id=EXCLUDED.owner_id,p256dh=EXCLUDED.p256dh,auth=EXCLUDED.auth,user_agent=EXCLUDED.user_agent,active=TRUE,updated_at=NOW()`,
        [owner,endpoint,p256dh,auth,String(req.headers['user-agent']||'').slice(0,500)]
      );
      return res.json({ok:true});
    }catch(e){
      console.error('owner web push subscribe',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.post('/api/driver/web-push-subscription',async(req,res)=>{
    try{
      const driver=authenticatedDriverId(req);
      if(!driver)return res.status(401).json({error:'DRIVER_REQUIRED'});
      if(!enabled)return res.status(503).json({error:'WEB_PUSH_NOT_CONFIGURED'});
      const endpoint=String(req.body?.endpoint||'').trim();
      const p256dh=String(req.body?.keys?.p256dh||'').trim();
      const auth=String(req.body?.keys?.auth||'').trim();
      if(!endpoint||!p256dh||!auth)return res.status(400).json({error:'INVALID_SUBSCRIPTION'});
      await pool.query(
        `INSERT INTO driver_web_push_subscriptions(driver_id,endpoint,p256dh,auth,user_agent,active)
         VALUES($1,$2,$3,$4,$5,TRUE)
         ON CONFLICT(endpoint) DO UPDATE SET driver_id=EXCLUDED.driver_id,p256dh=EXCLUDED.p256dh,auth=EXCLUDED.auth,user_agent=EXCLUDED.user_agent,active=TRUE,updated_at=NOW()`,
        [driver,endpoint,p256dh,auth,String(req.headers['user-agent']||'').slice(0,500)]
      );
      return res.json({ok:true});
    }catch(e){
      console.error('driver web push subscribe',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  async function sendFrom(table,idColumn,userId,data,title,body){
    if(!enabled)return {attempted:0,delivered:0,skipped:'WEB_PUSH_NOT_CONFIGURED'};
    const rows=(await pool.query(
      `SELECT id,endpoint,p256dh,auth FROM ${table} WHERE ${idColumn}=$1 AND active=TRUE ORDER BY updated_at DESC`,
      [String(userId)]
    )).rows;
    if(!rows.length)return {attempted:0,delivered:0};
    const payload=JSON.stringify({
      title,
      body,
      data,
      url:'/HeyCar/owner/',
      icon:'/HeyCar/owner/icons/cepqar-192.png',
      badge:'/HeyCar/owner/icons/cepqar-192.png'
    });
    let delivered=0;
    for(const row of rows){
      try{
        await webpush.sendNotification(
          {endpoint:row.endpoint,keys:{p256dh:row.p256dh,auth:row.auth}},
          payload,
          {TTL:(data.type==='incoming_call'||data.type==='call_request')?45:120,urgency:'high'}
        );
        delivered++;
      }catch(e){
        const status=Number(e?.statusCode||0);
        if(status===404||status===410){
          await pool.query(`UPDATE ${table} SET active=FALSE,updated_at=NOW() WHERE id=$1`,[row.id]).catch(()=>{});
        }
        console.error('Web push send',{status:status||'ERR',message:String(e?.message||e).slice(0,300)});
      }
    }
    return {attempted:rows.length,delivered};
  }

  return {
    enabled,
    sendOwner:(owner,data,title,body)=>sendFrom('owner_web_push_subscriptions','owner_id',owner,data,title,body),
    sendDriver:(driver,data,title,body)=>sendFrom('driver_web_push_subscriptions','driver_id',driver,data,title,body),
  };
};
