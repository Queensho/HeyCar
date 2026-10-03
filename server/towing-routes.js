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

  app.post('/api/owner/towing/requests',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const vehicleId=String(req.body?.vehicleId||'').trim()||null,vehicleType=String(req.body?.vehicleType||'').trim(),truckType=String(req.body?.truckType||'').trim();
    const issueType=String(req.body?.issueType||'other').trim().slice(0,40),issueNote=String(req.body?.issueNote||'').trim().slice(0,500);
    const pickupLat=n(req.body?.pickupLat),pickupLng=n(req.body?.pickupLng),destinationLat=n(req.body?.destinationLat),destinationLng=n(req.body?.destinationLng),distanceKm=n(req.body?.distanceKm);
    if([pickupLat,pickupLng,destinationLat,destinationLng,distanceKm].some(x=>x===null)||distanceKm<0||distanceKm>2000)return res.status(400).json({error:'INVALID_ROUTE'});
    if(pickupLat<-90||pickupLat>90||destinationLat<-90||destinationLat>90||pickupLng<-180||pickupLng>180||destinationLng<-180||destinationLng>180)return res.status(400).json({error:'INVALID_COORDINATES'});
    const client=await pool.connect();
    try{
      await client.query('BEGIN');
      if(vehicleId){const own=await client.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',[vehicleId,ownerId]);if(!own.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'VEHICLE_NOT_FOUND'});}}
      const [v,t,s]=await Promise.all([
        client.query('SELECT code,name,price_multiplier FROM towing_vehicle_types WHERE code=$1 AND active=TRUE',[vehicleType]),
        client.query('SELECT code,name,base_fee,per_km_fee,minimum_fee FROM towing_truck_types WHERE code=$1 AND active=TRUE',[truckType]),
        client.query('SELECT * FROM towing_pricing_settings WHERE id=1')
      ]);
      if(!v.rowCount||!t.rowCount||!s.rowCount){await client.query('ROLLBACK');return res.status(400).json({error:'TOWING_OPTION_NOT_AVAILABLE'});}
      const vehicle=v.rows[0],truck=t.rows[0],settings=s.rows[0];
      const raw=(Number(truck.base_fee)+distanceKm*Number(truck.per_km_fee))*Number(vehicle.price_multiplier);
      const subtotal=Math.max(raw,Number(truck.minimum_fee));
      const total=money(subtotal);
      const snapshot={baseFee:Number(truck.base_fee),perKmFee:Number(truck.per_km_fee),minimumFee:Number(truck.minimum_fee),vehicleMultiplier:Number(vehicle.price_multiplier),distanceKm:money(distanceKm)};
      const r=await client.query(`INSERT INTO towing_requests(owner_id,vehicle_id,vehicle_type,truck_type,issue_type,issue_note,pickup_lat,pickup_lng,pickup_address,destination_lat,destination_lng,destination_address,distance_km,quoted_total,currency,pricing_snapshot)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16::jsonb) RETURNING *`,[ownerId,vehicleId,vehicleType,truckType,issueType,issueNote||null,pickupLat,pickupLng,String(req.body?.pickupAddress||'').trim().slice(0,300)||null,destinationLat,destinationLng,String(req.body?.destinationAddress||'').trim().slice(0,300)||null,distanceKm,total,settings.currency,JSON.stringify(snapshot)]);
      await client.query('COMMIT');return res.status(201).json({ok:true,request:r.rows[0]});
    }catch(e){await client.query('ROLLBACK').catch(()=>{});if(e?.code==='23505')return res.status(409).json({error:'ACTIVE_TOWING_REQUEST_EXISTS'});console.error('towing request create',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}
  });

  app.get('/api/owner/towing/requests',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query('SELECT * FROM towing_requests WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 100',[ownerId]);return res.json({ok:true,items:r.rows});}
    catch(e){console.error('towing request list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/owner/towing/requests/:id',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query('SELECT * FROM towing_requests WHERE id=$1 AND owner_id=$2 LIMIT 1',[req.params.id,ownerId]);if(!r.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});return res.json({ok:true,request:r.rows[0]});}
    catch(e){console.error('towing request detail',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/towing/requests/:id/cancel',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const reason=String(req.body?.reason||'').trim().slice(0,300);
    try{const r=await pool.query(`UPDATE towing_requests SET status='cancelled',cancelled_at=NOW(),cancel_reason=$3,updated_at=NOW() WHERE id=$1 AND owner_id=$2 AND status IN ('searching','accepted','arriving','arrived') RETURNING *`,[req.params.id,ownerId,reason||null]);if(!r.rowCount)return res.status(409).json({error:'TOWING_REQUEST_NOT_CANCELLABLE'});return res.json({ok:true,request:r.rows[0]});}
    catch(e){console.error('towing request cancel',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/owner/towing/requests/:id/tracking',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query(`SELECT r.id,r.status,r.driver_lat,r.driver_lng,r.driver_location_at,r.pickup_eta_minutes,r.pickup_distance_km,
      r.pickup_lat,r.pickup_lng,r.pickup_address,r.destination_lat,r.destination_lng,r.destination_address,r.distance_km,
      p.display_name AS provider_name,p.provider_type,d.full_name AS driver_name,v.plate AS towing_plate,v.brand AS towing_brand,v.model AS towing_model,v.truck_type
      FROM towing_requests r LEFT JOIN towing_providers p ON p.id=r.accepted_provider_id LEFT JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id LEFT JOIN towing_provider_vehicles v ON v.id=r.accepted_towing_vehicle_id
      WHERE r.id=$1 AND r.owner_id=$2 LIMIT 1`,[req.params.id,ownerId]);if(!r.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});return res.json({ok:true,tracking:r.rows[0]});}
    catch(e){console.error('owner towing tracking',e);return res.status(500).json({error:'SERVER_ERROR'});}
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
