'use strict';
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {writeAdminAudit}=require('./admin-audit');
const {rateLimit}=require('express-rate-limit');

// Fails CLOSED. Production writes must be explicitly enabled only after migration,
// privacy review, and a separate operator-approved rollout.
const live=()=>process.env.TOWING_INTEREST_ENABLED==='1';
const statuses=new Set(['gathering','evaluating','negotiating','preparing','pilot','active']);
const interestWriteLimiter=rateLimit({windowMs:60*60*1000,limit:20,standardHeaders:'draft-7',legacyHeaders:false,message:{error:'TOO_MANY_REQUESTS'}});
function normalize(v){
  const value=typeof v==='string'?v.normalize('NFC').trim().replace(/\s+/g,' '):'';
  if(value.length<2||value.length>90||!(/^[\p{L}0-9 .'-]+$/u).test(value))return '';
  return value;
}
function key(value){return value.toLocaleLowerCase('tr-TR');}
function area(body){
  const city=normalize(body?.city),district=normalize(body?.district);
  return city&&district?{city,district,cityKey:key(city),districtKey:key(district)}:null;
}
function requireLive(req,res,next){
  if(!live())return res.status(409).json({error:'TOWING_INTEREST_DEMO_ONLY',demo:true});
  return next();
}
function requireOwner(req,res,next){
  req.towingInterestOwner=authenticatedOwnerId(req);
  if(!req.towingInterestOwner)return res.status(401).json({error:'OWNER_REQUIRED'});
  next();
}
const demoSummary=()=>({ok:true,demo:true,total:0,notifyCount:0,regionCount:0,items:[]});

module.exports=function registerTowingInterestRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  app.get('/api/towing/interest/availability',async(req,res)=>{
    if(!live())return res.json({ok:true,demo:true,mode:'coming_soon'});
    const selected=area(req.query);
    if(!selected)return res.status(400).json({error:'INVALID_AREA'});
    try{
      const r=await pool.query('SELECT status,provider_capacity FROM towing_pilot_regions WHERE city_key=$1 AND district_key=$2',[selected.cityKey,selected.districtKey]);
      const x=r.rows[0];
      return res.json({ok:true,demo:false,mode:x&&['pilot','active'].includes(x.status)&&Number(x.provider_capacity)>0?x.status:'coming_soon'});
    }catch(e){console.error('towing availability',e);return res.status(503).json({error:'TOWING_AVAILABILITY_UNAVAILABLE'});}
  });

  app.get('/api/owner/towing-interest',requireOwner,async(req,res)=>{
    if(!live())return res.json({ok:true,demo:true,interest:null});
    try{
      const r=await pool.query('SELECT city,district,notify_on_launch,updated_at FROM towing_service_interests WHERE owner_id=$1',[req.towingInterestOwner]);
      return res.json({ok:true,demo:false,interest:r.rows[0]||null});
    }catch(e){console.error('towing interest read',e);return res.status(503).json({error:'TOWING_INTEREST_UNAVAILABLE'});}
  });

  app.put('/api/owner/towing-interest',requireOwner,requireLive,interestWriteLimiter,async(req,res)=>{
    const selected=area(req.body);
    if(!selected||typeof req.body?.notifyOnLaunch!=='boolean')return res.status(400).json({error:'INVALID_INTEREST'});
    try{
      const r=await pool.query(
        `INSERT INTO towing_service_interests(owner_id,city,district,city_key,district_key,notify_on_launch)
         VALUES($1,$2,$3,$4,$5,$6)
         ON CONFLICT(owner_id) DO UPDATE SET city=excluded.city,district=excluded.district,city_key=excluded.city_key,
         district_key=excluded.district_key,notify_on_launch=excluded.notify_on_launch,updated_at=NOW()
         RETURNING city,district,notify_on_launch,updated_at`,
        [req.towingInterestOwner,selected.city,selected.district,selected.cityKey,selected.districtKey,req.body.notifyOnLaunch]
      );
      return res.json({ok:true,demo:false,interest:r.rows[0]});
    }catch(e){console.error('towing interest save',e);return res.status(503).json({error:'TOWING_INTEREST_UNAVAILABLE'});}
  });

  app.delete('/api/owner/towing-interest',requireOwner,requireLive,interestWriteLimiter,async(req,res)=>{
    try{await pool.query('DELETE FROM towing_service_interests WHERE owner_id=$1',[req.towingInterestOwner]);return res.json({ok:true});}
    catch(e){console.error('towing interest remove',e);return res.status(503).json({error:'TOWING_INTEREST_UNAVAILABLE'});}
  });

  app.get('/api/admin/manage/towing/interest/summary',guard,async(req,res)=>{
    if(!live())return res.json(demoSummary());
    try{
      const [totals,areas]=await Promise.all([
        pool.query('SELECT COUNT(*)::int AS total, COUNT(*) FILTER (WHERE notify_on_launch)::int AS notify_count, COUNT(DISTINCT (city_key,district_key))::int AS region_count FROM towing_service_interests'),
        pool.query(`SELECT MIN(i.city) AS city, MIN(i.district) AS district,i.city_key,i.district_key,COUNT(*)::int AS requests,
          COUNT(*) FILTER (WHERE i.notify_on_launch)::int AS notify_count,
          COALESCE(p.status,'gathering') AS status,COALESCE(p.provider_capacity,0)::int AS provider_capacity,
          MAX(i.updated_at) AS updated_at
          FROM towing_service_interests i LEFT JOIN towing_pilot_regions p
            ON p.city_key=i.city_key AND p.district_key=i.district_key
          GROUP BY i.city_key,i.district_key,p.status,p.provider_capacity
          ORDER BY requests DESC,i.city_key,i.district_key LIMIT 200`)
      ]);
      return res.json({ok:true,demo:false,total:totals.rows[0]?.total||0,notifyCount:totals.rows[0]?.notify_count||0,regionCount:totals.rows[0]?.region_count||0,items:areas.rows.map(x=>({
        city:x.city,district:x.district,requests:x.requests,notifyCount:x.notify_count,status:x.status,providerCapacity:x.provider_capacity,updatedAt:x.updated_at
      }))});
    }catch(e){console.error('towing interest summary',e);return res.status(503).json({error:'TOWING_INTEREST_UNAVAILABLE'});}
  });

  app.get('/api/admin/manage/towing/pilot-regions',guard,async(req,res)=>{
    if(!live())return res.json({ok:true,demo:true,items:[]});
    try{
      const r=await pool.query(`SELECT p.city,p.district,p.status,p.provider_capacity AS "providerCapacity",
        p.admin_note AS "adminNote",p.planned_launch_at AS "plannedLaunchAt",p.updated_at AS "updatedAt",
        (SELECT COUNT(*)::int FROM towing_service_interests i WHERE i.city_key=p.city_key AND i.district_key=p.district_key) AS requests,
        (SELECT COUNT(*)::int FROM towing_service_interests i WHERE i.city_key=p.city_key AND i.district_key=p.district_key AND i.notify_on_launch) AS "notifyCount"
        FROM towing_pilot_regions p ORDER BY p.updated_at DESC LIMIT 200`);
      return res.json({ok:true,demo:false,items:r.rows});
    }catch(e){console.error('towing pilot list',e);return res.status(503).json({error:'TOWING_PILOT_UNAVAILABLE'});}
  });

  app.put('/api/admin/manage/towing/pilot-regions',guard,requireLive,async(req,res)=>{
    const selected=area(req.body),status=String(req.body?.status||'');
    const capacity=Number(req.body?.providerCapacity);
    const rawDate=req.body?.plannedLaunchAt;
    const parsedDate=rawDate?new Date(rawDate):null;
    if(!selected||!statuses.has(status)||!Number.isInteger(capacity)||capacity<0||capacity>10000||
       (parsedDate&&!Number.isFinite(parsedDate.getTime())))return res.status(400).json({error:'INVALID_PILOT_REGION'});
    if(['pilot','active'].includes(status)&&(!req.body?.confirmActivation||capacity===0))
      return res.status(409).json({error:'PILOT_ACTIVATION_CONFIRMATION_REQUIRED'});
    const note=String(req.body?.adminNote||'').trim().slice(0,500);
    try{
      const r=await pool.query(
        `INSERT INTO towing_pilot_regions(city,district,city_key,district_key,status,provider_capacity,admin_note,planned_launch_at)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT(city_key,district_key) DO UPDATE SET city=excluded.city,district=excluded.district,status=excluded.status,
         provider_capacity=excluded.provider_capacity,admin_note=excluded.admin_note,
         planned_launch_at=excluded.planned_launch_at,updated_at=NOW()
         RETURNING city,district,status,provider_capacity AS "providerCapacity"`,
        [selected.city,selected.district,selected.cityKey,selected.districtKey,status,capacity,note,parsedDate]
      );
      await writeAdminAudit(pool,req,{action:'towing_pilot_region_update',targetType:'towing_pilot_region',
        targetId:selected.cityKey+'/'+selected.districtKey,details:{status,capacity}});
      // Never send push automatically on status changes; requires explicit reviewed send workflow.
      return res.json({ok:true,item:r.rows[0],notificationsSent:0});
    }catch(e){console.error('towing pilot update',e);return res.status(503).json({error:'TOWING_PILOT_UNAVAILABLE'});}
  });
};
