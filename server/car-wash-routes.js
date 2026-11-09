const {ownerId}=require('./owner-auth-service');

// Read-only first phase. No account, vehicle or booking creation endpoints.
module.exports=function registerCarWashRoutes(app,pool,{enabled=()=>process.env.CAR_WASH_CATALOG_ENABLED==='true'}={}){
  const publicFields='b.id,b.name,b.address,b.latitude,b.longitude,b.opening_hours,b.description,b.logo_url';
  function allowed(req,res){
    res.set('Cache-Control','no-store');
    if(!enabled()){res.status(503).json({error:'CAR_WASH_DISABLED'});return false;}
    if(!ownerId(req)){res.status(401).json({error:'AUTH_REQUIRED'});return false;}
    return true;
  }
  function unavailable(res){return res.status(503).json({error:'CAR_WASH_UNAVAILABLE'});}
  app.get('/api/car-wash/nearby',async(req,res)=>{
    if(!allowed(req,res))return;
    const number=value=>typeof value==='string'&&value.trim()!==''?Number(value):NaN;
    const lat=number(req.query.lat),lon=number(req.query.lon);
    const radius=req.query.radiusKm===undefined?10:number(req.query.radiusKm);
    if(!Number.isFinite(lat)||Math.abs(lat)>90||!Number.isFinite(lon)||Math.abs(lon)>180||
      !Number.isFinite(radius)||radius<0.1||radius>50){
      return res.status(400).json({error:'INVALID_LOCATION'});
    }
    try{
      const result=await pool.query(`WITH nearby AS (
        SELECT ${publicFields},6371*2*asin(sqrt(least(1.0,greatest(0.0,
          power(sin(radians(b.latitude-$1)/2),2)+cos(radians($1))*cos(radians(b.latitude))*
          power(sin(radians(b.longitude-$2)/2),2))))) AS distance_km
        FROM car_wash_locations l JOIN businesses b ON b.id=l.business_id
        WHERE l.published AND b.is_active AND b.latitude BETWEEN -90 AND 90
          AND b.longitude BETWEEN -180 AND 180
      ) SELECT * FROM nearby WHERE distance_km<=$3 ORDER BY distance_km,id LIMIT 50`,[lat,lon,radius]);
      return res.json({ok:true,businesses:result.rows,bookingEnabled:process.env.CAR_WASH_BOOKING_ENABLED==='true'});
    }catch(_){return unavailable(res);}
  });
  app.get('/api/car-wash/businesses/:businessId',async(req,res)=>{
    if(!allowed(req,res))return;
    const id=String(req.params.businessId||'');
    if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)){
      return res.status(400).json({error:'INVALID_BUSINESS_ID'});
    }
    try{
      // One statement keeps publication and service visibility in one snapshot.
      const phase2=process.env.CAR_WASH_BOOKING_ENABLED==='true';
      const extra=phase2?',l.photos,l.booking_enabled':'';
      const result=await pool.query(`SELECT ${publicFields}${extra},COALESCE((
        SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'description',s.description,
          'priceKurus',s.price_kurus,'currency','TRY','durationMinutes',s.duration_minutes) ORDER BY s.price_kurus,s.id)
        FROM car_wash_services s WHERE s.business_id=b.id AND s.active
      ),'[]'::jsonb) AS services
        FROM car_wash_locations l JOIN businesses b ON b.id=l.business_id
        WHERE b.id=$1 AND l.published AND b.is_active`,[id]);
      if(!result.rows.length)return res.status(404).json({error:'BUSINESS_NOT_FOUND'});
      return res.json({ok:true,business:result.rows[0],bookingEnabled:phase2&&result.rows[0].booking_enabled===true});
    }catch(_){return unavailable(res);}
  });
};
