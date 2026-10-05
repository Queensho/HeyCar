const express=require('express');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {driverId:authenticatedDriverId}=require('./driver-auth-service');
const {ownerPremiumPlan,driverVehicleEntitlement}=require('./premium-entitlements');
module.exports=function registerMaintenanceRoutes(app,pool){
 const ownerId=req=>authenticatedOwnerId(req);
 const driverId=req=>authenticatedDriverId(req);
 // Maintenance history belongs to the vehicle. Owners with any active Premium
 // plan can manage it; drivers inherit this entitlement only from Family Premium.
 async function access(req,res,{premiumRequired=false}={}){
   const vehicleId=String(req.params.vehicleId||'');
   const o=ownerId(req);
   if(o){
     const r=await pool.query('SELECT id,plate,make,model,owner_id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',[vehicleId,o]);
     if(!r.rows.length){res.status(403).json({error:'FORBIDDEN'});return null;}
     const p=await ownerPremiumPlan(pool,o);
     if(premiumRequired&&!p.premium){res.status(402).json({error:'PREMIUM_REQUIRED',purchaseBy:'owner'});return null;}
     return {vehicle:r.rows[0],ownerId:String(o),premium:p.premium,plan:p.plan,role:'owner'};
   }
   const d=driverId(req);
   if(d){
     const e=await driverVehicleEntitlement(pool,d,vehicleId);
     if(!e){res.status(403).json({error:'DRIVER_NOT_AUTHORIZED'});return null;}
     if(premiumRequired&&!e.familyPremium){res.status(402).json({error:'FAMILY_PREMIUM_REQUIRED',ownerPlan:e.ownerPlan,purchaseBy:'owner'});return null;}
     return {
       vehicle:{id:e.vehicleId,plate:e.plate,make:e.make,model:e.model,owner_id:e.ownerId},
       ownerId:e.ownerId,
       premium:e.familyPremium,
       plan:e.ownerPlan,
       role:'driver',
       activeDriver:e.activeDriver,
     };
   }
   res.status(401).json({error:'AUTH_REQUIRED'});
   return null;
 }
 async function record(req,res,v){const r=await pool.query(`SELECT * FROM vehicle_maintenance_records WHERE id::text=$1 AND vehicle_id=$2 LIMIT 1`,[String(req.params.recordId||''),String(v.id)]);if(!r.rows.length){res.status(404).json({error:'MAINTENANCE_NOT_FOUND'});return null;}return r.rows[0];}
 async function syncKm(v){const r=await pool.query(`SELECT COALESCE(MAX(mileage),0) km FROM vehicle_maintenance_records WHERE vehicle_id=$1`,[String(v.id)]);const max=Number(r.rows[0]?.km||0);await pool.query(`UPDATE vehicle_maintenance_state SET current_km=GREATEST(current_km,$2),updated_at=NOW() WHERE vehicle_id=$1`,[String(v.id),max]);}
 app.get('/api/vehicles/:vehicleId/maintenance',async(req,res)=>{try{const a=await access(req,res);if(!a)return;const v=a.vehicle,isPremium=a.premium;const km=await pool.query('SELECT current_km,updated_at FROM vehicle_maintenance_state WHERE vehicle_id=$1 LIMIT 1',[String(v.id)]);const records=await pool.query(`SELECT id,service_date,mileage,items,notes,total_cost,invoice_url,next_service_km,created_at,updated_at FROM vehicle_maintenance_records WHERE vehicle_id=$1 ORDER BY mileage DESC,service_date DESC`,[String(v.id)]);const currentKm=Number(km.rows[0]?.current_km||records.rows[0]?.mileage||0);const upcoming=records.rows.filter(x=>Number(x.next_service_km)>0).map(x=>{const remaining=Number(x.next_service_km)-currentKm;return {recordId:x.id,label:Array.isArray(x.items)&&x.items.length?x.items[0]:'Bakım',dueKm:Number(x.next_service_km),remainingKm:remaining,status:remaining<=0?'due':remaining<=1000?'soon':'ok'};}).sort((a,b)=>a.dueKm-b.dueKm);const nearest=upcoming[0],reminderDays=nearest&&nearest.remainingKm<=1000?15:30,lastKmUpdate=km.rows[0]?.updated_at||records.rows[0]?.created_at||null,nextKmReminderAt=lastKmUpdate?new Date(new Date(lastKmUpdate).getTime()+reminderDays*86400000).toISOString():new Date().toISOString();res.json({ok:true,premium:isPremium,vehicle:v,currentKm,records:records.rows,upcoming,kmReminder:{due:!lastKmUpdate||Date.now()>=new Date(nextKmReminderAt).getTime(),intervalDays:reminderDays,lastUpdatedAt:lastKmUpdate,nextReminderAt:nextKmReminderAt,message:'Güncel kilometren kaç?'}});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.get('/api/vehicles/:vehicleId/maintenance/:recordId',async(req,res)=>{try{const a=await access(req,res);if(!a)return;const v=a.vehicle;const r=await record(req,res,v);if(!r)return;res.json({ok:true,record:r});}catch(e){console.error(e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.put('/api/vehicles/:vehicleId/maintenance/km',express.json(),async(req,res)=>{const a=await access(req,res,{premiumRequired:true});if(!a)return;const o=a.ownerId;const c=await pool.connect();try{await c.query('BEGIN');const vr=await c.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',[String(req.params.vehicleId||''),o]);if(!vr.rowCount){await c.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}const km=Math.max(0,Math.round(Number(req.body.currentKm||0)));await c.query(`INSERT INTO vehicle_maintenance_state(vehicle_id,current_km,updated_at) VALUES($1,$2,NOW()) ON CONFLICT(vehicle_id) DO UPDATE SET current_km=EXCLUDED.current_km,updated_at=NOW()`,[String(vr.rows[0].id),km]);await c.query('COMMIT');res.json({ok:true,currentKm:km});}catch(e){await c.query('ROLLBACK').catch(()=>{});console.error(e);res.status(500).json({error:'SERVER_ERROR'});}finally{c.release();}});
 app.post('/api/vehicles/:vehicleId/maintenance',express.json({limit:'1mb'}),async(req,res)=>{const a=await access(req,res,{premiumRequired:true});if(!a)return;const o=a.ownerId;const c=await pool.connect();try{await c.query('BEGIN');const vr=await c.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',[String(req.params.vehicleId||''),o]);if(!vr.rowCount){await c.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}const v=vr.rows[0],mileage=Math.max(0,Math.round(Number(req.body.mileage||0))),items=Array.isArray(req.body.items)?req.body.items.map(x=>String(x).slice(0,80)).slice(0,12):[],interval=Math.max(0,Math.round(Number(req.body.intervalKm||0))),next=interval?mileage+interval:null;if(!mileage||!items.length){await c.query('ROLLBACK');return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});}const r=await c.query(`INSERT INTO vehicle_maintenance_records(vehicle_id,owner_id,service_date,mileage,items,notes,total_cost,invoice_url,next_service_km) VALUES($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9) RETURNING *`,[String(v.id),o,req.body.serviceDate||new Date().toISOString().slice(0,10),mileage,JSON.stringify(items),String(req.body.notes||'').slice(0,1000),Number(req.body.totalCost||0),req.body.invoiceUrl?String(req.body.invoiceUrl).slice(0,1000):null,next]);await c.query(`INSERT INTO vehicle_maintenance_state(vehicle_id,current_km,updated_at) VALUES($1,$2,NOW()) ON CONFLICT(vehicle_id) DO UPDATE SET current_km=GREATEST(vehicle_maintenance_state.current_km,EXCLUDED.current_km),updated_at=NOW()`,[String(v.id),mileage]);await c.query('COMMIT');res.status(201).json({ok:true,record:r.rows[0]});}catch(e){await c.query('ROLLBACK').catch(()=>{});console.error(e);res.status(500).json({error:'SERVER_ERROR'});}finally{c.release();}});
 app.put('/api/vehicles/:vehicleId/maintenance/:recordId',express.json({limit:'1mb'}),async(req,res)=>{
  const vehicleId=String(req.params.vehicleId||''),recordId=String(req.params.recordId||'');
  const a=await access(req,res,{premiumRequired:true});if(!a)return;
  const o=a.ownerId;
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   const vr=await client.query('SELECT id,plate,make,model,owner_id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1 FOR UPDATE',[vehicleId,o]);
   if(!vr.rows.length){await client.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}
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
  const vehicleId=String(req.params.vehicleId||''),recordId=String(req.params.recordId||'');
  const a=await access(req,res,{premiumRequired:true});if(!a)return;
  const o=a.ownerId;
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   const vr=await client.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1 FOR UPDATE',[vehicleId,o]);
   if(!vr.rows.length){await client.query('ROLLBACK');return res.status(403).json({error:'FORBIDDEN'});}
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
