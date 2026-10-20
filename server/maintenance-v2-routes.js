const {ownerId}=require('./owner-auth-service');
module.exports=function registerMaintenanceV2Routes(app,pool){
 const fail=(res,e)=>{console.error('maintenance v2',e);return res.status(500).json({error:'SERVER_ERROR'});};
 async function owned(owner,vehicle){const r=await pool.query('SELECT 1 FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',[vehicle,owner]);return r.rowCount>0;}
 const validId=x=>/^\d+$/.test(String(x||''));
 const numeric=(v,min,max)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max;
 async function gate(req,res){const owner=ownerId(req),vehicle=String(req.params.vehicleId||'');if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});if(!vehicle||!await owned(owner,vehicle))return res.status(404).json({error:'VEHICLE_NOT_FOUND'});return {owner,vehicle};}
 app.get('/api/owner/vehicles/:vehicleId/fuel-v2',async(req,res)=>{try{const a=await gate(req,res);if(!a||!a.owner)return;const r=await pool.query('SELECT id,filled_at,odometer_km,liters,total_cost,full_tank,station,notes FROM vehicle_fuel_entries_v2 WHERE vehicle_id=$1 AND owner_id=$2 ORDER BY filled_at DESC,id DESC LIMIT 200',[a.vehicle,a.owner]);return res.json({ok:true,entries:r.rows});}catch(e){return fail(res,e);}});
 app.post('/api/owner/vehicles/:vehicleId/fuel-v2',async(req,res)=>{try{const a=await gate(req,res);if(!a||!a.owner)return;const b=req.body||{};const date=new Date(b.filledAt);if(!b.filledAt||!Number.isFinite(date.getTime())||!Number.isInteger(b.odometerKm)||!numeric(b.odometerKm,0,9999999)||!numeric(b.liters,0.001,10000)||!numeric(b.totalCost,0,999999999)|| (b.fullTank!==undefined&&typeof b.fullTank!=='boolean'))return res.status(400).json({error:'INVALID_INPUT'});const r=await pool.query('INSERT INTO vehicle_fuel_entries_v2(vehicle_id,owner_id,filled_at,odometer_km,liters,total_cost,full_tank,station,notes) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id',[a.vehicle,a.owner,date,b.odometerKm,b.liters,b.totalCost,b.fullTank!==false,String(b.station||'').slice(0,120),String(b.notes||'').slice(0,2000)]);return res.status(201).json({ok:true,id:r.rows[0].id});}catch(e){return fail(res,e);}});

 app.put('/api/owner/vehicles/:vehicleId/fuel-v2/:entryId',async(req,res)=>{
  try{
   const a=await gate(req,res);if(!a||!a.owner)return;
   if(!validId(req.params.entryId))return res.status(400).json({error:'INVALID_ID'});
   const b=req.body||{},date=new Date(b.filledAt);
   if(!b.filledAt||!Number.isFinite(date.getTime())||!Number.isInteger(b.odometerKm)||
      !numeric(b.odometerKm,0,9999999)||!numeric(b.liters,0.001,10000)||
      !numeric(b.totalCost,0,999999999)||(b.fullTank!==undefined&&typeof b.fullTank!=='boolean'))
     return res.status(400).json({error:'INVALID_INPUT'});
   const r=await pool.query(
    'UPDATE vehicle_fuel_entries_v2 SET filled_at=$1,odometer_km=$2,liters=$3,total_cost=$4,station=$5 WHERE id=$6 AND vehicle_id=$7 AND owner_id=$8 RETURNING id',
    [date,b.odometerKm,b.liters,b.totalCost,String(b.station||'').slice(0,120),req.params.entryId,a.vehicle,a.owner]);
   if(!r.rowCount)return res.status(404).json({error:'ENTRY_NOT_FOUND'});
   return res.json({ok:true,id:r.rows[0].id});
  }catch(e){return fail(res,e);}
 });
 app.delete('/api/owner/vehicles/:vehicleId/fuel-v2/:entryId',async(req,res)=>{
  try{
   const a=await gate(req,res);if(!a||!a.owner)return;
   if(!validId(req.params.entryId))return res.status(400).json({error:'INVALID_ID'});
   const r=await pool.query('DELETE FROM vehicle_fuel_entries_v2 WHERE id=$1 AND vehicle_id=$2 AND owner_id=$3 RETURNING id',
    [req.params.entryId,a.vehicle,a.owner]);
   if(!r.rowCount)return res.status(404).json({error:'ENTRY_NOT_FOUND'});
   return res.json({ok:true});
  }catch(e){return fail(res,e);}
 });
 app.get('/api/owner/vehicles/:vehicleId/expenses-v2',async(req,res)=>{try{const a=await gate(req,res);if(!a||!a.owner)return;const r=await pool.query('SELECT id,spent_at,category,amount,description,receipt_url FROM vehicle_expense_entries_v2 WHERE vehicle_id=$1 AND owner_id=$2 ORDER BY spent_at DESC,id DESC LIMIT 200',[a.vehicle,a.owner]);return res.json({ok:true,entries:r.rows});}catch(e){return fail(res,e);}});
 app.post('/api/owner/vehicles/:vehicleId/expenses-v2',async(req,res)=>{try{const a=await gate(req,res);if(!a||!a.owner)return;const b=req.body||{};const categories=['insurance','tax','parking','toll','repair','parts','cleaning','other'];if(!/^\d{4}-\d{2}-\d{2}$/.test(String(b.spentAt||''))||!Number.isFinite(Date.parse(b.spentAt))||!categories.includes(b.category)||!numeric(b.amount,0,999999999))return res.status(400).json({error:'INVALID_INPUT'});const r=await pool.query('INSERT INTO vehicle_expense_entries_v2(vehicle_id,owner_id,spent_at,category,amount,description) VALUES($1,$2,$3,$4,$5,$6) RETURNING id',[a.vehicle,a.owner,b.spentAt,b.category,b.amount,String(b.description||'').slice(0,2000)]);return res.status(201).json({ok:true,id:r.rows[0].id});}catch(e){return fail(res,e);}});
 app.put('/api/owner/vehicles/:vehicleId/expenses-v2/:entryId',async(req,res)=>{
  try{
   const a=await gate(req,res);if(!a||!a.owner)return;
   if(!validId(req.params.entryId))return res.status(400).json({error:'INVALID_ID'});
   const b=req.body||{};
   const categories=['insurance','tax','parking','toll','repair','parts','cleaning','other'];
   if(!/^\d{4}-\d{2}-\d{2}$/.test(String(b.spentAt||''))||
      !Number.isFinite(Date.parse(b.spentAt))||!categories.includes(b.category)||
      !numeric(b.amount,0.01,999999999))
     return res.status(400).json({error:'INVALID_INPUT'});
   const r=await pool.query(
    'UPDATE vehicle_expense_entries_v2 SET spent_at=$1,category=$2,amount=$3,description=$4 WHERE id=$5 AND vehicle_id=$6 AND owner_id=$7 RETURNING id',
    [b.spentAt,b.category,b.amount,String(b.description||'').slice(0,2000),
     req.params.entryId,a.vehicle,a.owner]);
   if(!r.rowCount)return res.status(404).json({error:'ENTRY_NOT_FOUND'});
   return res.json({ok:true,id:r.rows[0].id});
  }catch(e){return fail(res,e);}
 });
 app.delete('/api/owner/vehicles/:vehicleId/expenses-v2/:entryId',async(req,res)=>{
  try{
   const a=await gate(req,res);if(!a||!a.owner)return;
   if(!validId(req.params.entryId))return res.status(400).json({error:'INVALID_ID'});
   const r=await pool.query(
    'DELETE FROM vehicle_expense_entries_v2 WHERE id=$1 AND vehicle_id=$2 AND owner_id=$3 RETURNING id',
    [req.params.entryId,a.vehicle,a.owner]);
   if(!r.rowCount)return res.status(404).json({error:'ENTRY_NOT_FOUND'});
   return res.json({ok:true});
  }catch(e){return fail(res,e);}
 });

};