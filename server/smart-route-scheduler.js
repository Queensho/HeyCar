// Optional, read-only background candidate scanner. Push delivery is deliberately disabled.
// Enable only after database migrations, provider budgets and operations review.
const {scanCandidates}=require('./smart-route-alert-scanner');
const {enqueue}=require('./smart-route-alert-outbox');
const {deliverPending}=require('./smart-route-alert-delivery');
function startSmartRouteScan(app,db){
 if(process.env.SMART_ROUTE_SCAN_ENABLED!=='true')return null;
 const minutes=Number(process.env.SMART_ROUTE_SCAN_INTERVAL_MINUTES||30);
 if(!Number.isFinite(minutes)||minutes<15||minutes>1440){
  console.warn('Smart route scanner disabled: invalid interval');return null;
 }
 let busy=false;
 const run=async()=>{
  if(busy)return;
  busy=true;
  try{
   const result=await scanCandidates(db,{limit:10});
   let queued=0;
   if(process.env.SMART_ROUTE_QUEUE_ENABLED==='true'&&result.candidates.length){
    queued=await enqueue(db,result.candidates);
   }
   let delivery={attempted:0,delivered:0};
   if(process.env.SMART_ROUTE_PUSH_ENABLED==='true'&&process.env.SMART_ROUTE_QUEUE_ENABLED==='true'){
    delivery=await deliverPending(app,db,{limit:10});
   }
   // No incident details, route coordinates, user IDs or notification tokens in logs.
   console.info('Smart route scan',{checked:result.routesChecked,eligible:result.routesEligible,
    candidates:result.candidates.length,queued,unavailable:result.unavailable,
    pushEnabled:process.env.SMART_ROUTE_PUSH_ENABLED==='true',delivery});
  }catch(e){console.warn('Smart route scan failed',{code:String(e.code||'SCAN_ERROR').slice(0,40)});}
  finally{busy=false;}
 };
 const timer=setInterval(run,minutes*60*1000);
 timer.unref?.();
 console.info('Smart route scanner enabled in dry-run mode',{intervalMinutes:minutes});
 return ()=>clearInterval(timer);
}
module.exports={startSmartRouteScan};
