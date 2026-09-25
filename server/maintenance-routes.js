const express=require('express');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
module.exports=function registerMaintenanceRoutes(app,pool){
 const ownerId=req=>authenticatedOwnerId(req);
 // Maintenance history belongs to the vehicle, not to the owner account that created each record.
 // Access is authorized by current ownership in vehicle(); this keeps history intact after a vehicle transfer.
 async function vehicle(req,res){const o=ownerId(req),v=String(req.params.vehicleId||'');if(!o){res.status(401).json({error:'OWNER_REQUIRED'});return null;}const r=await pool.query('SELECT id,plate,make,model,owner_id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',[v,o]);if(!r.rows.length){res.status(403).json({error:'FORBIDDEN'});return null;}return r.rows[0];}
 async function premium(o){try{const r=await pool.query(`SELECT COALESCE((to_jsonb(u)->>'premium')::boolean,false) premium FROM users u WHERE id::text=$1 LIMIT 1`,[o]);return r.rows[0]?.premium===true;}catch(_){return false;}}
 async function record(req,res,v){const r=await pool.query(`SELECT * FROM vehicle_maintenance_records WHERE id::text=$1 AND vehicle_id=$2 LIMIT 1`,[String(req.params.recordId||''),String(v.id)]);if(!r.rows.length){res.status(404).json({error:'MAINTENANCE_NOT_FOUND'});return null;}return r.rows[0];}
 async function syncKm(v){const r=await pool.query(`SELECT COALESCE(MAX(mileage),0) km FROM vehicle_maintenance_records WHERE vehicle_id=$1`,[String(v.id)]);const max=Number(r.rows[0]?.km||0);await pool.query(`UPDATE vehicle_maintenance_state SET current_km=GREATEST(current_km,$2),updated_at=NOW() WHERE vehicle_id=$1`,[String(v.id),max]);}
 app.get('/api/vehicles/:vehicleId/maintenance',async(req,res)=>{try{const v=await vehicle(req,res);if(!v)return;const o=ownerId(req),isPremium=await premium(o);const km=await pool.query('SELECT current_km,updated_at FROM vehicle_maintenance_state WHERE vehicle_id=$1 LIMIT 1',[String(v.id)]);const records=await pool.query(`SELECT id,service_date,mileage,items,notes,total_cost,invoice_url,next_service_km,created_at,updated_at FROM vehicle_maintenance_records WHERE vehicle_id=$1 ORDER BY mileage DESC,service_date DESC`,[String(v.id)]);const currentKm=Number(km.rows[0]?.current_km||records.rows[0]?.mileage||0);const upcoming=records.rows.filter(x=>Number(x.next_service_km)>0).map(x=>{const remaining=Number(x.next_service_km)-currentKm;return {recordId:x.id,label:Array.isArray(x.items)&&x.items.length?x.items[0]:'Bakım',dueKm:Number(x.next_service_km),remainingKm:remaining,status:remaining<=0?'due':remaining<=1000?'soon':'ok'};}).sort((a,b)=>a.dueKm-b.dueKm);const nearest=upcoming[0],reminderDays=nearest&&nearest.remainingKm<=1000?15:30,lastKmUpdate=km.rows[0]?.updated_at||records.rows[0]?.created_at||null,nextKmReminderAt=lastKmUpdate?new Date(new Date(lastKmUpdate).getTime()+reminderDays*86400000).toISOString():new Date().toISOString();res.json({ok:true,premium:isPremium,vehicle:v,currentKm,records:records.rows,upcoming,kmReminder:{due:!lastKmUpdate||Date.now()>=new Date(nextKmReminderAt).getTime(),intervalDays:reminderDays,lastUpdatedAt:lastKmUpdate,nextReminderAt:nextKmReminderAt,message:'Güncel kilometren kaç?'}});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.get('/api/vehicles/:vehicleId/maintenance/:recordId',async(req,res)=>{try{const v=await vehicle(req,res);if(!v)return;const r=await record(req,res,v);if(!r)return;res.json({ok:true,record:r});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.put('/api/vehicles/:vehicleId/maintenance/km',express.json(),async(req,res)=>{try{const v=await vehicle(req,res);if(!v)return;if(!await premium(ownerId(req)))return res.status(402).json({error:'PREMIUM_REQUIRED'});const km=Math.max(0,Math.round(Number(req.body.currentKm||0)));await pool.query(`INSERT INTO vehicle_maintenance_state(vehicle_id,current_km,updated_at) VALUES($1,$2,NOW()) ON CONFLICT(vehicle_id) DO UPDATE SET current_km=EXCLUDED.current_km,updated_at=NOW()`,[String(v.id),km]);res.json({ok:true,currentKm:km});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.post('/api/vehicles/:vehicleId/maintenance',express.json({limit:'1mb'}),async(req,res)=>{try{const v=await vehicle(req,res);if(!v)return;if(!await premium(ownerId(req)))return res.status(402).json({error:'PREMIUM_REQUIRED'});const mileage=Math.max(0,Math.round(Number(req.body.mileage||0))),items=Array.isArray(req.body.items)?req.body.items.map(x=>String(x).slice(0,80)).slice(0,12):[],interval=Math.max(0,Math.round(Number(req.body.intervalKm||0))),next=interval?mileage+interval:null;if(!mileage||!items.length)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});const r=await pool.query(`INSERT INTO vehicle_maintenance_records(vehicle_id,owner_id,service_date,mileage,items,notes,total_cost,invoice_url,next_service_km) VALUES($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9) RETURNING *`,[String(v.id),ownerId(req),req.body.serviceDate||new Date().toISOString().slice(0,10),mileage,JSON.stringify(items),String(req.body.notes||'').slice(0,1000),Number(req.body.totalCost||0),req.body.invoiceUrl?String(req.body.invoiceUrl).slice(0,1000):null,next]);await pool.query(`INSERT INTO vehicle_maintenance_state(vehicle_id,current_km,updated_at) VALUES($1,$2,NOW()) ON CONFLICT(vehicle_id) DO UPDATE SET current_km=GREATEST(vehicle_maintenance_state.current_km,EXCLUDED.current_km),updated_at=NOW()`,[String(v.id),mileage]);res.status(201).json({ok:true,record:r.rows[0]});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.put('/api/vehicles/:vehicleId/maintenance/:recordId',express.json({limit:'1mb'}),async(req,res)=>{
  const o=ownerId(req),vehicleId=String(req.params.vehicleId||''),recordId=String(req.params.recordId||'');
  if(!o)return res.status(401).json({error:'OWNER_REQUIRED'});
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   const vr=await client.query('SELECT id,plate,make,model,owner_id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1 FOR UPDATE',[vehicleId,o]);
   if(!vr.rows.length){await client.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}
   const pr=await client.query(`SELECT COALESCE((to_jsonb(u)->>'premium')::boolean,false) premium FROM users u WHERE id::text=$1 LIMIT 1`,[o]);
   if(pr.rows[0]?.premium!==true){await client.query('ROLLBACK');return res.status(402).json({error:'PREMIUM_REQUIRED'});}
   const rr=await client.query('SELECT * FROM vehicle_maintenance_records WHERE id::text=$1 AND vehicle_id::text=$2 LIMIT 1 FOR UPDATE',[recordId,vehicleId]);
   if(!rr.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'MAINTENANCE_NOT_FOUND'});}
   const old=rr.rows[0];
   const mileage=Math.max(0,Math.round(Number(req.body.mileage??old.mileage)));
   const items=Array.isArray(req.body.items)?req.body.items.map(x=>String(x).slice(0,80)).slice(0,12):old.items;
   const interval=req.body.intervalKm===undefined?(old.next_service_km?Math.max(0,Number(old.next_service_km)-Number(old.mileage)):0):Math.max(0,Math.round(Number(req.body.intervalKm||0)));
   if(!mileage||!items.length){await client.query('ROLLBACK');return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});}
   const next=interval?mileage+interval:null;
   const r=await client.query(`UPDATE vehicle_maintenance_records SET service_date=$1,mileage=$2,items=$3::jsonb,notes=$4,total_cost=$5,invoice_url=$6,next_service_km=$7,updated_at=NOW() WHERE id=$8 AND vehicle_id::text=$9 RETURNING *`,[req.body.serviceDate||old.service_date,mileage,JSON.stringify(items),String(req.body.notes??old.notes??'').slice(0,1000),Number(req.body.totalCost??old.total_cost??0),req.body.invoiceUrl===undefined?old.invoice_url:(req.body.invoiceUrl?String(req.body.invoiceUrl).slice(0,1000):null),next,old.id,vehicleId]);
   const km=await client.query('SELECT COALESCE(MAX(mileage),0) km FROM vehicle_maintenance_records WHERE vehicle_id::text=$1',[vehicleId]);
   await client.query('UPDATE vehicle_maintenance_state SET current_km=GREATEST(current_km,$2),updated_at=NOW() WHERE vehicle_id::text=$1',[vehicleId,Number(km.rows[0]?.km||0)]);
   await client.query('COMMIT');
   return res.json({ok:true,record:r.rows[0]});
  }catch(e){
   await client.query('ROLLBACK').catch(()=>{});
   console.error(e);
   return res.status(500).json({error:'SERVER_ERROR'});
  }finally{client.release();}
 });
 app.delete('/api/vehicles/:vehicleId/maintenance/:recordId',async(req,res)=>{
  const o=ownerId(req),vehicleId=String(req.params.vehicleId||''),recordId=String(req.params.recordId||'');
  if(!o)return res.status(401).json({error:'OWNER_REQUIRED'});
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   const vr=await client.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1 FOR UPDATE',[vehicleId,o]);
   if(!vr.rows.length){await client.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}
   const pr=await client.query(`SELECT COALESCE((to_jsonb(u)->>'premium')::boolean,false) premium FROM users u WHERE id::text=$1 LIMIT 1`,[o]);
   if(pr.rows[0]?.premium!==true){await client.query('ROLLBACK');return res.status(402).json({error:'PREMIUM_REQUIRED'});}
   const rr=await client.query('SELECT id FROM vehicle_maintenance_records WHERE id::text=$1 AND vehicle_id::text=$2 LIMIT 1 FOR UPDATE',[recordId,vehicleId]);
   if(!rr.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'MAINTENANCE_NOT_FOUND'});}
   const deletedId=rr.rows[0].id;
   await client.query('DELETE FROM vehicle_maintenance_records WHERE id=$1 AND vehicle_id::text=$2',[deletedId,vehicleId]);
   const km=await client.query('SELECT COALESCE(MAX(mileage),0) km FROM vehicle_maintenance_records WHERE vehicle_id::text=$1',[vehicleId]);
   await client.query('UPDATE vehicle_maintenance_state SET current_km=GREATEST(current_km,$2),updated_at=NOW() WHERE vehicle_id::text=$1',[vehicleId,Number(km.rows[0]?.km||0)]);
   await client.query('COMMIT');
   return res.json({ok:true,deletedId});
  }catch(e){
   await client.query('ROLLBACK').catch(()=>{});
   console.error(e);
   return res.status(500).json({error:'SERVER_ERROR'});
  }finally{client.release();}
 });
};
