const crypto=require('crypto');

module.exports=function registerValetRoutes(app,pool){
 const hash=s=>crypto.createHash('sha256').update(String(s)).digest('hex');
 async function businessAuth(req,res){
  const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
  if(!raw){res.status(401).json({error:'AUTH_REQUIRED'});return null;}
  const q=await pool.query("SELECT b.id AS business_id,b.valet_enabled FROM business_sessions s JOIN business_accounts a ON a.id=s.account_id JOIN businesses b ON b.account_id=a.id WHERE s.token_hash=$1 AND s.expires_at>now()",[hash(raw)]);
  if(!q.rowCount){res.status(401).json({error:'INVALID_SESSION'});return null;}
  return q.rows[0];
 }
 const enabled=(account,res)=>account.valet_enabled||!res.status(403).json({error:'VALET_NOT_ENABLED'});

 app.get('/api/business/valet/overview',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;
  const [staff,areas,sessions]=await Promise.all([
   pool.query("SELECT id,name,phone,is_active,created_at FROM valet_staff WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT * FROM valet_parking_areas WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT * FROM valet_sessions WHERE business_id=$1 AND status NOT IN ('delivered','cancelled') ORDER BY CASE status WHEN 'requested' THEN 0 WHEN 'retrieving' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,created_at DESC",[a.business_id])
  ]);
  res.json({ok:true,staff:staff.rows,areas:areas.rows,sessions:sessions.rows});
 });

 app.post('/api/business/valet/staff',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const {name,phone,pin}=req.body||{};
  if(!name||!/^\d{4,8}$/.test(String(pin||'')))return res.status(400).json({error:'INVALID_STAFF'});
  const q=await pool.query("INSERT INTO valet_staff(business_id,name,phone,pin_hash) VALUES($1,$2,$3,$4) RETURNING id,name,phone,is_active,created_at",[a.business_id,String(name).trim(),phone||null,hash(pin)]);
  res.status(201).json({ok:true,staff:q.rows[0]});
 });

 app.post('/api/business/valet/areas',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const {name,slots}=req.body||{};
  if(!name)return res.status(400).json({error:'AREA_NAME_REQUIRED'});
  const q=await pool.query("INSERT INTO valet_parking_areas(business_id,name,slots) VALUES($1,$2,$3) ON CONFLICT(business_id,name) DO UPDATE SET slots=EXCLUDED.slots,is_active=true RETURNING *",[a.business_id,String(name).trim(),Number.isInteger(Number(slots))?Number(slots):null]);
  res.status(201).json({ok:true,area:q.rows[0]});
 });

 app.post('/api/business/valet/accept',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const b=req.body||{},plate=String(b.plate||'').trim().toUpperCase();
  if(!plate)return res.status(400).json({error:'PLATE_REQUIRED'});
  const v=await pool.query("SELECT id FROM vehicles WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=regexp_replace($1,'[[:space:]]+','','g') LIMIT 1",[plate]);
  const q=await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate,qr_code,parking_area,parking_slot,key_location,note,status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'parked') RETURNING *",[a.business_id,v.rows[0]?.id||null,plate,b.qrCode||null,b.parkingArea||null,b.parkingSlot||null,b.keyLocation||null,b.note||null]);
  res.status(201).json({ok:true,session:q.rows[0]});
 });

 app.patch('/api/business/valet/sessions/:id/status',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const status=String((req.body||{}).status||'');
  if(!['parked','requested','retrieving','ready','delivered','cancelled'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
  const q=await pool.query("UPDATE valet_sessions SET status=$3,requested_at=CASE WHEN $3='requested' THEN COALESCE(requested_at,now()) ELSE requested_at END,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,delivered_at=CASE WHEN $3='delivered' THEN now() ELSE delivered_at END,updated_at=now() WHERE id=$1 AND business_id=$2 RETURNING *",[req.params.id,a.business_id,status]);
  if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true,session:q.rows[0]});
 });
};
