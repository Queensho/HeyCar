// Server-only TomTom flow client. No automatic polling or background requests.
const https=require('https');
const cache=new Map();
const TTL_MS=5*60*1000;
const MAX_CACHE=256;
let period='',used=0;
function validPoint(p){return p&&Number.isFinite(Number(p.lat))&&Number.isFinite(Number(p.lon))&&Math.abs(Number(p.lat))<=90&&Math.abs(Number(p.lon))<=180;}
function request(url){
 return new Promise((resolve,reject)=>{
  const req=https.get(url,{timeout:7000},res=>{
   let body='';
   res.on('data',chunk=>{body+=chunk;if(body.length>100000)req.destroy(new Error('RESPONSE_TOO_LARGE'));});
   res.on('end',()=>{
    if(res.statusCode!==200)return reject(new Error('TOMTOM_HTTP_'+res.statusCode));
    try{resolve(JSON.parse(body));}catch(_){reject(new Error('INVALID_PROVIDER_RESPONSE'));}
   });
  });
  req.on('timeout',()=>req.destroy(new Error('PROVIDER_TIMEOUT')));
  req.on('error',reject);
 });
}
async function flowAt(point){
 const key=String(process.env.TOMTOM_API_KEY||'').trim();
 if(!key)return {available:false,reason:'NOT_CONFIGURED'};
 if(!validPoint(point))return {available:false,reason:'INVALID_COORDINATE'};
 const lat=Number(point.lat).toFixed(5),lon=Number(point.lon).toFixed(5),id=lat+','+lon;
 const now=Date.now(),entry=cache.get(id);
 if(entry&&entry.expires>now)return entry.value;
 const month=new Date().toISOString().slice(0,7);
 if(month!==period){period=month;used=0;}
 // Conservative safety budget, not a provider-reported quota.
 const cap=Math.max(0,Math.min(1000,Number(process.env.TOMTOM_MONTHLY_FLOW_BUDGET||300)||0));
 if(used>=cap)return {available:false,reason:'LOCAL_BUDGET_EXHAUSTED'};
 used++;
 const url=new URL('https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json');
 url.searchParams.set('point',id);
 url.searchParams.set('key',key);
 try{
  const response=await request(url);
  const f=response.flowSegmentData||{};
  const speed=Number(f.currentSpeed),free=Number(f.freeFlowSpeed),confidence=Number(f.confidence);
  if(!Number.isFinite(speed)||!Number.isFinite(free)||free<=0)return {available:false,reason:'INVALID_PROVIDER_RESPONSE'};
  const value={available:true,provider:'tomtom',sampledPoint:{lat:Number(lat),lon:Number(lon)},currentSpeed:speed,freeFlowSpeed:free,confidence:Number.isFinite(confidence)?confidence:null,roadClosure:f.roadClosure===true,checkedAt:new Date().toISOString(),scope:'NEAREST_ROAD_SEGMENT_NOT_FULL_ROUTE'};
  if(cache.size>=MAX_CACHE)cache.delete(cache.keys().next().value);
  cache.set(id,{expires:now+TTL_MS,value});
  return value;
 }catch(e){
  // Never log URLs, as they contain the provider key.
  console.error('TomTom flow error',e.message);
  return {available:false,reason:/^TOMTOM_HTTP_429$/.test(e.message)?'PROVIDER_RATE_LIMIT':'PROVIDER_UNAVAILABLE'};
 }
}
module.exports={flowAt};
