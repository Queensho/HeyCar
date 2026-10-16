// TomTom traffic incidents for the geographic bounding box of a saved route.
// Incidents are provider-reported, not predictions.
const https=require('https');
function requestJson(url){
 return new Promise((resolve,reject)=>{
  const req=https.get(url,{timeout:8000},res=>{
   let body='';
   res.on('data',chunk=>{body+=chunk;if(body.length>300000)req.destroy(new Error('TOO_LARGE'));});
   res.on('end',()=>{if(res.statusCode!==200)return reject(new Error('HTTP_'+res.statusCode));try{resolve(JSON.parse(body));}catch(_){reject(new Error('BAD_JSON'));}});
  });req.on('timeout',()=>req.destroy(new Error('TIMEOUT')));req.on('error',reject);
 });
}
function valid(p){return p&&typeof p.lat==='number'&&typeof p.lon==='number'&&Number.isFinite(p.lat)&&Number.isFinite(p.lon)&&Math.abs(p.lat)<=90&&Math.abs(p.lon)<=180;}
async function incidents(route,db){
 const key=String(process.env.TOMTOM_API_KEY||'').trim();
 if(!key)return {available:false,reason:'NOT_CONFIGURED',incidents:[]};
 const pts=[route.origin,...(Array.isArray(route.waypoints)?route.waypoints:[]),route.destination];
 if(pts.length>10||pts.some(p=>!valid(p)))return {available:false,reason:'INVALID_COORDINATES',incidents:[]};
 const lats=pts.map(p=>p.lat),lons=pts.map(p=>p.lon);
 const west=Math.max(-180,Math.min(...lons)-0.01),east=Math.min(180,Math.max(...lons)+0.01);
 const south=Math.max(-90,Math.min(...lats)-0.01),north=Math.min(90,Math.max(...lats)+0.01);
 if(east-west>1||north-south>1)return {available:false,reason:'AREA_TOO_LARGE',incidents:[]};
 const cap=Math.max(0,Math.min(1000,Number(process.env.TOMTOM_MONTHLY_INCIDENT_BUDGET||100)||0));
 if(!db||!cap)return {available:false,reason:'BUDGET_UNAVAILABLE',incidents:[]};
 try{
  const budget=await db.query(`INSERT INTO smart_route_provider_usage(provider,service,month_utc,requests)
   VALUES('tomtom','incidents',$1,1) ON CONFLICT(provider,service,month_utc)
   DO UPDATE SET requests=smart_route_provider_usage.requests+1,updated_at=NOW()
   WHERE smart_route_provider_usage.requests<$2 RETURNING requests`,[new Date().toISOString().slice(0,7),cap]);
  if(!budget.rowCount)return {available:false,reason:'LOCAL_BUDGET_EXHAUSTED',incidents:[]};
 }catch(_){return {available:false,reason:'BUDGET_UNAVAILABLE',incidents:[]};}
 const url=new URL('https://api.tomtom.com/traffic/services/5/incidentDetails');
 url.searchParams.set('key',key);
 url.searchParams.set('bbox',[west,south,east,north].join(','));
 url.searchParams.set('fields','{incidents{type,geometry{type,coordinates},properties{id,iconCategory,magnitudeOfDelay,events{description,code},startTime,endTime,from,to,length,delay}}}');
 url.searchParams.set('language','tr-TR');
 url.searchParams.set('timeValidityFilter','present');
 try{
  const data=await requestJson(url);
  const list=Array.isArray(data.incidents)?data.incidents:[];
  return {available:true,scope:'bounding_box_not_route_matched',checkedAt:new Date().toISOString(),
   incidents:list.slice(0,100).map(x=>({id:String(x.properties?.id||'').slice(0,120),category:x.properties?.iconCategory??null,
    description:String(x.properties?.events?.[0]?.description||'').slice(0,300),
    from:String(x.properties?.from||'').slice(0,150),to:String(x.properties?.to||'').slice(0,150),
    delaySeconds:Number.isFinite(x.properties?.delay)?x.properties.delay:null,
    geometry:x.geometry||null}))};
 }catch(e){console.error('TomTom incident lookup failed',e.message);return {available:false,reason:e.message==='HTTP_429'?'PROVIDER_RATE_LIMIT':'PROVIDER_UNAVAILABLE',incidents:[]};}
}
module.exports={incidents};
