const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');

function n(v){const x=Number(v);return Number.isFinite(x)?x:null;}
function money(v){return Math.round((Number(v)+Number.EPSILON)*100)/100;}

module.exports=function registerTowingRoutes(app,pool,adminGuard){
  app.get('/api/towing/options',async(_req,res)=>{
    try{
      const [vehicles,trucks,settings]=await Promise.all([
        pool.query('SELECT code,name,price_multiplier FROM towing_vehicle_types WHERE active=TRUE ORDER BY sort_order,name'),
        pool.query('SELECT code,name,base_fee,per_km_fee,minimum_fee FROM towing_truck_types WHERE active=TRUE ORDER BY sort_order,name'),
        pool.query('SELECT * FROM towing_pricing_settings WHERE id=1')
      ]);
      return res.json({ok:true,vehicleTypes:vehicles.rows,truckTypes:trucks.rows,settings:settings.rows[0]||null});
    }catch(e){console.error('towing options',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/towing/quote',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const distanceKm=n(req.body?.distanceKm);
    const vehicleType=String(req.body?.vehicleType||'').trim();
    const truckType=String(req.body?.truckType||'').trim();
    const isNight=req.body?.isNight===true;
    if(distanceKm===null||distanceKm<0||distanceKm>2000||!vehicleType||!truckType)return res.status(400).json({error:'INVALID_QUOTE_REQUEST'});
    try{
      const [v,t,s]=await Promise.all([
        pool.query('SELECT code,name,price_multiplier FROM towing_vehicle_types WHERE code=$1 AND active=TRUE',[vehicleType]),
        pool.query('SELECT code,name,base_fee,per_km_fee,minimum_fee FROM towing_truck_types WHERE code=$1 AND active=TRUE',[truckType]),
        pool.query('SELECT * FROM towing_pricing_settings WHERE id=1')
      ]);
      if(!v.rowCount||!t.rowCount||!s.rowCount)return res.status(400).json({error:'TOWING_OPTION_NOT_AVAILABLE'});
      const vehicle=v.rows[0],truck=t.rows[0],settings=s.rows[0];
      const raw=(Number(truck.base_fee)+distanceKm*Number(truck.per_km_fee))*Number(vehicle.price_multiplier);
      const subtotal=Math.max(raw,Number(truck.minimum_fee));
      const nightSurcharge=isNight?subtotal*Number(settings.night_surcharge_pct)/100:0;
      const total=money(subtotal+nightSurcharge);
      return res.json({ok:true,quote:{distanceKm:money(distanceKm),vehicleType:vehicle.code,vehicleTypeName:vehicle.name,truckType:truck.code,truckTypeName:truck.name,baseFee:money(truck.base_fee),perKmFee:money(truck.per_km_fee),vehicleMultiplier:Number(vehicle.price_multiplier),subtotal:money(subtotal),nightSurcharge:money(nightSurcharge),total,currency:settings.currency}});
    }catch(e){console.error('towing quote',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/towing/pricing',adminGuard,async(_req,res)=>{
    try{const [v,t,s]=await Promise.all([pool.query('SELECT * FROM towing_vehicle_types ORDER BY sort_order,name'),pool.query('SELECT * FROM towing_truck_types ORDER BY sort_order,name'),pool.query('SELECT * FROM towing_pricing_settings WHERE id=1')]);return res.json({ok:true,vehicleTypes:v.rows,truckTypes:t.rows,settings:s.rows[0]});}
    catch(e){console.error('admin towing pricing',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/admin/manage/towing/truck-types/:code',adminGuard,async(req,res)=>{
    const code=String(req.params.code||'').trim();const base=n(req.body?.baseFee),km=n(req.body?.perKmFee),min=n(req.body?.minimumFee);
    if(base===null||km===null||min===null||base<0||km<0||min<0)return res.status(400).json({error:'INVALID_PRICING'});
    try{const r=await pool.query('UPDATE towing_truck_types SET base_fee=$2,per_km_fee=$3,minimum_fee=$4 WHERE code=$1 RETURNING *',[code,base,km,min]);if(!r.rowCount)return res.status(404).json({error:'TRUCK_TYPE_NOT_FOUND'});return res.json({ok:true,truckType:r.rows[0]});}
    catch(e){console.error('admin towing truck pricing',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/admin/manage/towing/vehicle-types/:code',adminGuard,async(req,res)=>{
    const code=String(req.params.code||'').trim(),mult=n(req.body?.priceMultiplier);
    if(mult===null||mult<=0||mult>10)return res.status(400).json({error:'INVALID_MULTIPLIER'});
    try{const r=await pool.query('UPDATE towing_vehicle_types SET price_multiplier=$2 WHERE code=$1 RETURNING *',[code,mult]);if(!r.rowCount)return res.status(404).json({error:'VEHICLE_TYPE_NOT_FOUND'});return res.json({ok:true,vehicleType:r.rows[0]});}
    catch(e){console.error('admin towing vehicle pricing',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
