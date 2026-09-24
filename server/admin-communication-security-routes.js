const {writeAdminAudit}=require('./admin-audit');

async function tableExists(pool,name){
  const r=await pool.query('SELECT to_regclass($1) AS name',['public.'+name]);
  return Boolean(r.rows[0]?.name);
}
function maskVisitor(raw){
  const s=String(raw||'').trim();
  if(!s)return '-';
  if(s.length<=8)return s.slice(0,2)+'•••';
  return s.slice(0,5)+'••••'+s.slice(-3);
}
function adminActor(req){
  return {
    id:String(req.headers?.['x-admin-id']||'').trim()||null,
    email:String(req.headers?.['x-admin-email']||'').trim()||null,
  };
}

module.exports=function registerAdminCommunicationSecurityRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  app.get('/api/admin/manage/push-history',guard,async(req,res)=>{
    try{
      if(!await tableExists(pool,'admin_push_campaigns'))return res.json({ok:true,items:[]});
      const limit=Math.max(1,Math.min(100,Number(req.query?.limit||50)));
      const r=await pool.query(
        `SELECT id,admin_id,admin_email,target_mode,target_filter,title,body,
                targeted_count,attempted_count,delivered_count,failed_count,created_at
           FROM admin_push_campaigns
          ORDER BY created_at DESC LIMIT $1`,
        [limit]
      );
      return res.json({ok:true,items:r.rows});
    }catch(e){console.error('admin push history',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/admin/manage/push',guard,async(req,res)=>{
    const title=String(req.body?.title||'').trim().slice(0,90);
    const body=String(req.body?.body||'').trim().slice(0,400);
    const mode=String(req.body?.mode||'single').trim();
    const segment=String(req.body?.segment||'active').trim();
    const userIds=Array.isArray(req.body?.userIds)?[...new Set(req.body.userIds.map(x=>String(x).trim()).filter(Boolean))].slice(0,1000):[];
    if(!title||!body)return res.status(400).json({error:'TITLE_BODY_REQUIRED'});
    if(!['single','users','segment','all'].includes(mode))return res.status(400).json({error:'INVALID_TARGET_MODE'});
    if(mode==='single'&&userIds.length!==1)return res.status(400).json({error:'SINGLE_USER_REQUIRED'});
    if(mode==='users'&&!userIds.length)return res.status(400).json({error:'USERS_REQUIRED'});
    if(mode==='segment'&&!['premium','standard','active','suspended'].includes(segment))return res.status(400).json({error:'INVALID_SEGMENT'});

    try{
      const push=app.locals.heycarPush;
      if(!push||typeof push.sendOwner!=='function')return res.status(503).json({error:'PUSH_SERVICE_UNAVAILABLE'});

      let q='SELECT DISTINCT u.id::text AS id FROM users u WHERE u.role<>\'admin\'';
      const params=[];
      if(mode==='single'||mode==='users'){
        params.push(userIds);
        q+=' AND u.id::text=ANY($1::text[])';
      }else if(mode==='segment'){
        if(segment==='premium')q+=' AND COALESCE(u.premium,false)=TRUE AND u.status=\'active\'';
        if(segment==='standard')q+=' AND COALESCE(u.premium,false)=FALSE AND u.status=\'active\'';
        if(segment==='active')q+=' AND u.status=\'active\'';
        if(segment==='suspended')q+=' AND u.status<>\'active\'';
      }else{
        // "all" means every non-admin account. Use the "active" segment when
        // the admin intentionally wants only active accounts.
      }
      q+=' ORDER BY u.id::text';
      const targets=(await pool.query(q,params)).rows.map(x=>String(x.id));
      if(!targets.length)return res.status(400).json({error:'NO_TARGET_USERS'});
      if(targets.length>5000)return res.status(400).json({error:'TARGET_TOO_LARGE'});

      let attempted=0,delivered=0;
      for(let i=0;i<targets.length;i+=12){
        const batch=targets.slice(i,i+12);
        const results=await Promise.all(batch.map(async id=>{
          try{
            return await push.sendOwner(id,{type:'admin_announcement',sourceType:'admin_announcement'},title,body);
          }catch(e){
            console.error('admin push send user',id,e);
            return {attempted:0,delivered:0};
          }
        }));
        for(const x of results){
          attempted+=Number(x?.attempted||0);
          delivered+=Number(x?.delivered||0);
        }
      }
      const failed=Math.max(0,attempted-delivered);
      const actor=adminActor(req);
      let campaign=null;
      if(await tableExists(pool,'admin_push_campaigns')){
        const ins=await pool.query(
          `INSERT INTO admin_push_campaigns
             (admin_id,admin_email,target_mode,target_filter,title,body,targeted_count,attempted_count,delivered_count,failed_count)
           VALUES($1,$2,$3,$4::jsonb,$5,$6,$7,$8,$9,$10)
           RETURNING *`,
          [actor.id,actor.email,mode,JSON.stringify({segment:mode==='segment'?segment:null,userIds:(mode==='single'||mode==='users')?userIds:[]}),title,body,targets.length,attempted,delivered,failed]
        );
        campaign=ins.rows[0]||null;
      }
      await writeAdminAudit(pool,req,{
        action:'notification.push_sent',
        targetType:'push_audience',
        targetId:campaign?.id||null,
        targetLabel:mode==='segment'?segment:mode,
        metadata:{mode,segment,targeted:targets.length,attempted,delivered,failed,title},
      });
      return res.json({ok:true,campaign,targeted:targets.length,attempted,delivered,failed});
    }catch(e){console.error('admin push send',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/security-center',guard,async(req,res)=>{
    const requested=Number(req.query?.hours||24);
    const hours=[24,168,720].includes(requested)?requested:24;
    try{
      let events=[],blocked=[],excessive=[],recovery=[],legacyNewDevices=[];
      if(await tableExists(pool,'admin_security_events')){
        const r=await pool.query(
          `SELECT e.id,e.event_type,e.owner_id,e.subject,e.detail,e.ip_address,e.created_at,
                  u.display_name AS owner_name,u.phone AS owner_phone
             FROM admin_security_events e
             LEFT JOIN users u ON u.id::text=e.owner_id::text
            WHERE e.created_at>=NOW()-($1::text||' hours')::interval
            ORDER BY e.created_at DESC LIMIT 150`,
          [hours]
        );
        events=r.rows.map(x=>({...x,subject:maskVisitor(x.subject),ip_address:maskVisitor(x.ip_address)}));
      }
      if(await tableExists(pool,'owner_blocked_visitors')){
        const r=await pool.query(
          `SELECT b.owner_id,b.visitor_key,b.reason,b.created_at,u.display_name AS owner_name,u.phone AS owner_phone
             FROM owner_blocked_visitors b
             LEFT JOIN users u ON u.id::text=b.owner_id::text
            ORDER BY b.created_at DESC LIMIT 100`
        );
        blocked=r.rows.map(x=>({...x,visitor_key:maskVisitor(x.visitor_key)}));
      }
      if(await tableExists(pool,'qr_security_request_log')){
        const r=await pool.query(
          `SELECT owner_id,qr_token,visitor_key,
                  COUNT(*)::int AS request_count,
                  MIN(created_at) AS first_at,MAX(created_at) AS last_at
             FROM qr_security_request_log
            WHERE created_at>=NOW()-($1::text||' hours')::interval
            GROUP BY owner_id,qr_token,visitor_key,date_trunc('minute',created_at)
           HAVING COUNT(*)>=8
            ORDER BY request_count DESC,last_at DESC LIMIT 80`,
          [hours]
        );
        excessive=r.rows.map(x=>({...x,visitor_key:maskVisitor(x.visitor_key)}));
      }
      if(await tableExists(pool,'account_recovery_attempts')){
        const r=await pool.query(
          `SELECT phone,failed_count,window_started_at,blocked_until
             FROM account_recovery_attempts
            WHERE failed_count>0
              AND window_started_at>=NOW()-($1::text||' hours')::interval
            ORDER BY blocked_until DESC NULLS LAST,failed_count DESC LIMIT 80`,
          [hours]
        );
        recovery=r.rows.map(x=>({...x,phone:maskVisitor(x.phone)}));
      }
      if(await tableExists(pool,'owner_security_events')){
        const r=await pool.query(
          `SELECT e.id,e.owner_id,e.type,e.detail,e.created_at,u.display_name AS owner_name,u.phone AS owner_phone
             FROM owner_security_events e
             LEFT JOIN users u ON u.id::text=e.owner_id::text
            WHERE e.type='new_device_login'
              AND e.created_at>=NOW()-($1::text||' hours')::interval
            ORDER BY e.created_at DESC LIMIT 80`,
          [hours]
        );
        legacyNewDevices=r.rows;
      }
      const countType=t=>events.filter(x=>x.event_type===t).length;
      return res.json({
        ok:true,hours,
        summary:{
          qrRateLimits:countType('qr_rate_limited'),
          blockedAttempts:countType('blocked_visitor_attempt'),
          failedLogins:countType('failed_login'),
          newDevices:countType('new_device_login')>0?countType('new_device_login'):legacyNewDevices.length,
          recoveryRateLimits:countType('recovery_rate_limited'),
          blockedVisitors:blocked.length,
          excessiveQrBursts:excessive.length,
        },
        events,blockedVisitors:blocked,excessiveQr:excessive,recoveryAttempts:recovery,newDevices:legacyNewDevices,
      });
    }catch(e){console.error('admin security center',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
