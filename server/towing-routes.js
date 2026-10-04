const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const fs=require('fs');
const path=require('path');

function n(v){const x=Number(v);return Number.isFinite(x)?x:null;}
function money(v){return Math.round((Number(v)+Number.EPSILON)*100)/100;}

module.exports=function registerTowingRoutes(app,pool,adminGuard){
  const documentDir=process.env.TOWING_DOCUMENT_DIR||'/opt/heycar/uploads/towing-docs';
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
    const pickupAddress=String(req.body?.pickupAddress||'').trim().slice(0,300),destinationAddress=String(req.body?.destinationAddress||'').trim().slice(0,300);
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
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16::jsonb) RETURNING *`,[ownerId,vehicleId,vehicleType,truckType,issueType,issueNote||null,pickupLat,pickupLng,pickupAddress||null,destinationLat,destinationLng,destinationAddress||null,distanceKm,total,settings.currency,JSON.stringify(snapshot)]);
      await client.query('COMMIT');
      try{
        const push=app.locals.heycarPush;
        if(push&&typeof push.sendOwner==='function'){
          const nearby=await pool.query(`SELECT DISTINCT d.user_id
            FROM towing_provider_drivers d
            JOIN towing_providers p ON p.id=d.provider_id
            WHERE d.user_id IS NOT NULL AND d.status='active' AND d.online=TRUE AND p.status='active'
              AND d.last_lat IS NOT NULL AND d.last_lng IS NOT NULL
              AND EXISTS(SELECT 1 FROM towing_provider_vehicles tv WHERE tv.provider_id=d.provider_id AND tv.truck_type=$3 AND tv.status='active')
              AND (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(d.last_lat::float8))*cos(radians(d.last_lng::float8)-radians($2))+sin(radians($1))*sin(radians(d.last_lat::float8))))))<=30
            LIMIT 100`,[pickupLat,pickupLng,truckType]);
          const body=pickupAddress?'Yeni çekici talebi • '+pickupAddress:'Yakınında yeni bir çekici talebi var';
          await Promise.allSettled(nearby.rows.map(row=>push.sendOwner(String(row.user_id),{type:'towing_request',requestId:String(r.rows[0].id),pickupAddress:pickupAddress||'',destinationAddress:destinationAddress||'',truckType:String(truckType)},'Yeni Çekici Talebi',body)));
        }
      }catch(pushError){console.error('towing request push',pushError);}
      return res.status(201).json({ok:true,request:r.rows[0]});
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
    try{const r=await pool.query(`SELECT r.id,r.status,r.driver_lat,r.driver_lng,r.driver_location_at,r.pickup_eta_minutes,r.pickup_distance_km,r.destination_eta_minutes,r.destination_distance_km,
      r.pickup_lat,r.pickup_lng,r.pickup_address,r.destination_lat,r.destination_lng,r.destination_address,r.distance_km,
      p.display_name AS provider_name,p.provider_type,d.full_name AS driver_name,d.phone AS driver_phone,v.plate AS towing_plate,v.brand AS towing_brand,v.model AS towing_model,v.truck_type
      FROM towing_requests r LEFT JOIN towing_providers p ON p.id=r.accepted_provider_id LEFT JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id LEFT JOIN towing_provider_vehicles v ON v.id=r.accepted_towing_vehicle_id
      WHERE r.id=$1 AND r.owner_id=$2 LIMIT 1`,[req.params.id,ownerId]);if(!r.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});return res.json({ok:true,tracking:r.rows[0]});}
    catch(e){console.error('owner towing tracking',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });


  app.get('/api/owner/towing/requests/:id/messages',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const job=await pool.query("SELECT id FROM towing_requests WHERE id=$1 AND owner_id=$2 LIMIT 1",[req.params.id,ownerId]);
      if(!job.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});
      const m=await pool.query("SELECT id,sender_role,message,created_at FROM towing_messages WHERE request_id=$1 ORDER BY created_at,id LIMIT 300",[req.params.id]);
      return res.json({ok:true,items:m.rows});
    }catch(e){console.error('owner towing messages',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/towing/requests/:id/messages',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const message=String(req.body?.message||'').trim().slice(0,1000);if(!message)return res.status(400).json({error:'MESSAGE_REQUIRED'});
    try{
      const job=await pool.query(`SELECT r.id,r.status,d.user_id AS driver_user_id
        FROM towing_requests r LEFT JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
        WHERE r.id=$1 AND r.owner_id=$2 LIMIT 1`,[req.params.id,ownerId]);
      if(!job.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});
      if(!job.rows[0].driver_user_id)return res.status(409).json({error:'TOWING_DRIVER_NOT_ASSIGNED'});
      if(job.rows[0].status==='cancelled')return res.status(409).json({error:'TOWING_CHAT_CLOSED'});
      const m=await pool.query("INSERT INTO towing_messages(request_id,sender_user_id,sender_role,message) VALUES($1,$2,'owner',$3) RETURNING id,sender_role,message,created_at",[req.params.id,ownerId,message]);
      try{const push=app.locals.heycarPush;if(push&&typeof push.sendOwner==='function')await push.sendOwner(String(job.rows[0].driver_user_id),{type:'towing_message',requestId:String(req.params.id),messageId:String(m.rows[0].id)},'Müşteriden mesaj',message);}catch(pushError){console.error('towing owner message push',pushError);}
      return res.status(201).json({ok:true,message:m.rows[0]});
    }catch(e){console.error('owner towing message send',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/towing/providers',adminGuard,async(req,res)=>{
    const status=String(req.query?.status||'all');
    try{const params=[];let where='';if(status!=='all'){params.push(status);where='WHERE p.status=$1';}
      const r=await pool.query(`SELECT p.*,u.display_name owner_name,u.phone owner_phone,u.email owner_email,
        (SELECT COUNT(*)::int FROM towing_provider_documents d WHERE d.provider_id=p.id) document_count,
        (SELECT COUNT(*)::int FROM towing_provider_drivers d WHERE d.provider_id=p.id) driver_count,
        (SELECT COUNT(*)::int FROM towing_provider_vehicles v WHERE v.provider_id=p.id) vehicle_count
        FROM towing_providers p LEFT JOIN users u ON u.id=p.owner_user_id ${where} ORDER BY p.created_at DESC`,params);
      return res.json({ok:true,items:r.rows});}catch(e){console.error('admin towing providers',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/towing/providers/:id',adminGuard,async(req,res)=>{
    try{const [p,d,v,docs]=await Promise.all([
      pool.query('SELECT p.*,u.display_name owner_name,u.phone owner_phone,u.email owner_email FROM towing_providers p LEFT JOIN users u ON u.id=p.owner_user_id WHERE p.id=$1',[req.params.id]),
      pool.query('SELECT id,user_id,full_name,phone,status,online,last_seen_at,created_at FROM towing_provider_drivers WHERE provider_id=$1 ORDER BY created_at',[req.params.id]),
      pool.query('SELECT * FROM towing_provider_vehicles WHERE provider_id=$1 ORDER BY created_at',[req.params.id]),
      pool.query('SELECT id,document_type,original_name,mime_type,size_bytes,status,review_note,reviewed_at,created_at FROM towing_provider_documents WHERE provider_id=$1 ORDER BY document_type',[req.params.id])
    ]);if(!p.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});return res.json({ok:true,provider:p.rows[0],drivers:d.rows,vehicles:v.rows,documents:docs.rows});}
    catch(e){console.error('admin towing provider detail',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/towing/documents/:id/file',adminGuard,async(req,res)=>{
    try{const r=await pool.query('SELECT original_name,mime_type,storage_name FROM towing_provider_documents WHERE id=$1',[req.params.id]);if(!r.rowCount)return res.status(404).json({error:'DOCUMENT_NOT_FOUND'});
      const file=path.join(documentDir,path.basename(r.rows[0].storage_name));if(!fs.existsSync(file))return res.status(404).json({error:'DOCUMENT_FILE_NOT_FOUND'});
      res.type(r.rows[0].mime_type);res.setHeader('Content-Disposition',`inline; filename="${String(r.rows[0].original_name).replace(/["\\r\\n]/g,'_')}"`);return res.sendFile(file);}
    catch(e){console.error('admin towing document file',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/towing/providers/:id/status',adminGuard,async(req,res)=>{
    const status=String(req.body?.status||''),note=String(req.body?.note||'').trim().slice(0,500);
    if(!['active','suspended','rejected','banned'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    try{if(status==='active'){const p=await pool.query('SELECT provider_type FROM towing_providers WHERE id=$1',[req.params.id]);if(!p.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});
      const required=p.rows[0].provider_type==='company'?['identity_license','vehicle_registration','authorization_certificate','tax_certificate']:['identity_license','vehicle_registration','authorization_certificate'];
      const docs=await pool.query("SELECT document_type,status FROM towing_provider_documents WHERE provider_id=$1",[req.params.id]);const approved=new Set(docs.rows.filter(x=>x.status==='approved').map(x=>x.document_type));if(required.some(x=>!approved.has(x)))return res.status(409).json({error:'REQUIRED_DOCUMENTS_NOT_APPROVED'});}
      const r=await pool.query(`UPDATE towing_providers SET status=$2,review_note=$3,reviewed_at=NOW(),verified_at=CASE WHEN $2='active' THEN NOW() ELSE verified_at END,updated_at=NOW() WHERE id=$1 RETURNING *`,[req.params.id,status,note||null]);if(!r.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});
      if(status==='suspended'||status==='banned'||status==='rejected')await pool.query('UPDATE towing_provider_drivers SET online=FALSE,updated_at=NOW() WHERE provider_id=$1',[req.params.id]);
      return res.json({ok:true,provider:r.rows[0]});}catch(e){console.error('admin towing provider status',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/towing/documents/:id',adminGuard,async(req,res)=>{
    const status=String(req.body?.status||''),note=String(req.body?.note||'').trim().slice(0,500);if(!['approved','rejected'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    try{const r=await pool.query('UPDATE towing_provider_documents SET status=$2,review_note=$3,reviewed_at=NOW() WHERE id=$1 RETURNING id,document_type,status,review_note,reviewed_at',[req.params.id,status,note||null]);if(!r.rowCount)return res.status(404).json({error:'DOCUMENT_NOT_FOUND'});return res.json({ok:true,document:r.rows[0]});}
    catch(e){console.error('admin towing document review',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.delete('/api/admin/manage/towing/providers/:id',adminGuard,async(req,res)=>{
    try{const docs=await pool.query('SELECT storage_name FROM towing_provider_documents WHERE provider_id=$1',[req.params.id]);const r=await pool.query('DELETE FROM towing_providers WHERE id=$1 RETURNING id',[req.params.id]);if(!r.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});for(const d of docs.rows){try{fs.unlinkSync(path.join(documentDir,path.basename(d.storage_name)));}catch(_){}}return res.json({ok:true});}
    catch(e){console.error('admin towing provider delete',e);return res.status(500).json({error:'SERVER_ERROR'});}
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
