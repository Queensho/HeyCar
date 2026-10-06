const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const {finalizeVehicleTransfer}=require('./vehicle-transfer-service');
const {cachedLogo,queueResolve,publicBase}=require('./vehicle-brand-logo-service');
module.exports = function registerVehicleManagementRoutes(app, pool) {
  const ownerId = (req) => authenticatedOwnerId(req);

  async function tableExists(db,table){
    const r=await db.query('SELECT to_regclass($1) AS t',['public.'+table]);
    return Boolean(r.rows[0]?.t);
  }

  async function deleteVehicleRows(db,table,vehicleId,castText=false){
    if(!await tableExists(db,table))return 0;
    const sql=castText
      ? `DELETE FROM ${table} WHERE vehicle_id::text=$1`
      : `DELETE FROM ${table} WHERE vehicle_id=$1`;
    const r=await db.query(sql,[vehicleId]);
    return r.rowCount||0;
  }

  async function cleanupVehicleDependents(db,vehicleId){
    const removed={};
    for(const table of [
      'vehicle_maintenance_state',
      'vehicle_maintenance_records',
      'vehicle_maintenance_shares',
      'vehicle_reminders',
      'vehicle_reminder_deliveries',
      'vehicle_reminder_delivery_claims',
      'vehicle_parking_locations',
    ]){
      removed[table]=await deleteVehicleRows(db,table,vehicleId,true);
    }
    for(const table of [
      'vehicle_active_drivers',
      'vehicle_drivers',
      'vehicle_driver_invites',
      'anonymous_calls',
    ]){
      removed[table]=await deleteVehicleRows(db,table,vehicleId,true);
    }
    return removed;
  }

  app.get('/api/owner/vehicles', async (req, res) => {
    const owner = ownerId(req);
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const user = await pool.query(`SELECT
        (COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium,
        COALESCE(NULLIF(premium_plan,''),'individual') AS premium_plan
        FROM users WHERE id::text=$1 LIMIT 1`, [owner]);
      if (!user.rows.length) return res.status(404).json({ error: 'OWNER_NOT_FOUND' });
      const premium = user.rows[0].premium === true;
      const premiumPlan = premium
        ? (String(user.rows[0].premium_plan)==='family'?'family':'individual')
        : 'free';
      const familyPremium = premiumPlan==='family';
      const vehicles = await pool.query(`
        SELECT v.id,v.plate,v.make,v.model,v.color,v.model_year,v.vehicle_type,v.fuel_type,v.created_at,
               COALESCE(ms.current_km,0)::int AS mileage,
               q.token AS qr_token,q.status AS qr_status,q.scan_secret AS qr_scan_secret,
               (SELECT COUNT(*)::int FROM vehicle_drivers vd WHERE vd.vehicle_id=v.id) AS driver_count,
               EXISTS(
                 SELECT 1 FROM vehicle_active_drivers vad
                  WHERE vad.vehicle_id=v.id
                    AND (vad.active_until IS NULL OR vad.active_until>NOW())
               ) AS has_active_driver,
               (SELECT MAX(qsh.created_at) FROM qr_scan_history qsh WHERE qsh.vehicle_id=v.id) AS last_scan_at
          FROM vehicles v
          LEFT JOIN vehicle_maintenance_state ms ON ms.vehicle_id::text=v.id::text
          LEFT JOIN LATERAL (
            SELECT token,status,scan_secret FROM qr_tags
             WHERE vehicle_id=v.id AND status='active'
             ORDER BY activated_at DESC NULLS LAST LIMIT 1
          ) q ON TRUE
         WHERE v.owner_id::text=$1
         ORDER BY v.created_at ASC`, [owner]);
      const base=publicBase(req);
      const enriched=await Promise.all(vehicles.rows.map(async v=>{
        const brandLogo=await cachedLogo(pool,v.make);
        if(!brandLogo.available)queueResolve(pool,v.make,base);
        return {...v,brandLogo};
      }));
      return res.json({ ok:true, premium, premiumPlan, familyPremium, limit: premium ? 3 : 1, vehicles: enriched });
    } catch (e) {
      console.error('owner vehicles list error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/owner/vehicles', async (req, res) => {
    const owner = ownerId(req);
    const plate = String(req.body?.plate || '').trim().toUpperCase().slice(0,20);
    const make = String(req.body?.make || '').trim().slice(0,80);
    const model = String(req.body?.model || '').trim().slice(0,80);
    const color = String(req.body?.color || '').trim().slice(0,40);
    const modelYearRaw=req.body?.modelYear??req.body?.model_year??req.body?.year;
    const modelYear=modelYearRaw==null||modelYearRaw===''?null:Number(modelYearRaw);
    const vehicleType=String(req.body?.vehicleType??req.body?.vehicle_type??'').trim().slice(0,40)||null;
    const fuelType=String(req.body?.fuelType??req.body?.fuel_type??'').trim().slice(0,40)||null;
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!plate || !make || (modelYear!==null&&(!Number.isInteger(modelYear)||modelYear<1900||modelYear>new Date().getFullYear()+1))) return res.status(400).json({ error: 'INVALID_INPUT' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const user = await client.query(`SELECT
        (COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium,
        COALESCE(NULLIF(premium_plan,''),'individual') AS premium_plan
        FROM users WHERE id::text=$1 LIMIT 1 FOR UPDATE`, [owner]);
      if (!user.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'OWNER_NOT_FOUND' }); }
      const premium = user.rows[0].premium === true;
      const premiumPlan = premium
        ? (String(user.rows[0].premium_plan)==='family'?'family':'individual')
        : 'free';
      const familyPremium = premiumPlan==='family';
      const limit = premium ? 3 : 1;
      const count = await client.query(`SELECT COUNT(*)::int AS n FROM vehicles WHERE owner_id::text=$1`, [owner]);
      if ((count.rows[0]?.n || 0) >= limit) { await client.query('ROLLBACK'); return res.status(403).json({ error:'VEHICLE_LIMIT_REACHED', limit, premium }); }
      const normalizedPlate=plate.replace(/\s+/g,'').toUpperCase();
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',[normalizedPlate]);
      const duplicate = await client.query(
        `SELECT 1 FROM vehicles
          WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=$1
          LIMIT 1`,
        [normalizedPlate]
      );
      if (duplicate.rows.length) { await client.query('ROLLBACK'); return res.status(409).json({ error:'PLATE_EXISTS' }); }
      const created = await client.query(`INSERT INTO vehicles(owner_id,plate,make,model,color,model_year,vehicle_type,fuel_type) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id,plate,make,model,color,model_year,vehicle_type,fuel_type,created_at`, [owner,plate,make,model || null,color || null,modelYear,vehicleType,fuelType]);
      await client.query('COMMIT');
      const brandLogo=await cachedLogo(pool,created.rows[0].make);
      if(!brandLogo.available)queueResolve(pool,created.rows[0].make,publicBase(req));
      return res.status(201).json({ ok:true, vehicle:{...created.rows[0],brandLogo}, limit, premium, premiumPlan, familyPremium });
    } catch (e) {
      await client.query('ROLLBACK').catch(()=>{});
      if(e?.code==='23505'&&String(e?.constraint||'').includes('vehicles_plate_normalized')){
        return res.status(409).json({error:'PLATE_EXISTS'});
      }
      console.error('owner vehicle create error', e);
      return res.status(500).json({ error:'SERVER_ERROR' });
    } finally { client.release(); }
  });
  app.put('/api/owner/vehicles/:vehicleId', async (req, res) => {
    const owner = ownerId(req);
    const vehicleId = String(req.params.vehicleId || '').trim();
    const body = req.body || {};
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!vehicleId || typeof body.plate !== 'string' || typeof body.make !== 'string' ||
        (body.model !== undefined && typeof body.model !== 'string')) {
      return res.status(400).json({ error: 'INVALID_INPUT' });
    }
    const plate = body.plate.trim().toUpperCase();
    const make = body.make.trim();
    const model = (body.model || '').trim();
    const color = body.color==null?null:String(body.color).trim().slice(0,40);
    const modelYearRaw=body.modelYear??body.model_year??body.year;
    const modelYear=modelYearRaw==null||modelYearRaw===''?null:Number(modelYearRaw);
    const vehicleType=body.vehicleType==null&&body.vehicle_type==null?null:String(body.vehicleType??body.vehicle_type).trim().slice(0,40)||null;
    const fuelType=body.fuelType==null&&body.fuel_type==null?null:String(body.fuelType??body.fuel_type).trim().slice(0,40)||null;
    const mileageRaw=body.mileage??body.currentKm??body.current_km;
    const mileage=mileageRaw==null||mileageRaw===''?null:Number(mileageRaw);
    if (!plate || !make || plate.length > 20 || make.length > 80 || model.length > 80 ||
        (modelYear!==null&&(!Number.isInteger(modelYear)||modelYear<1900||modelYear>new Date().getFullYear()+1)) ||
        (mileage!==null&&(!Number.isInteger(mileage)||mileage<0||mileage>9999999))) {
      return res.status(400).json({ error: 'INVALID_INPUT' });
    }
    let client;
    try {
      client = await pool.connect();
      await client.query('BEGIN');
      const owned = await client.query(
        'SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',
        [vehicleId, owner]);
      if (!owned.rows.length) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      // Serialize edits that request the same normalized plate.
      const normalizedPlate=plate.replace(/\s+/g,'').toUpperCase();
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [normalizedPlate]);
      const duplicate = await client.query(
        "SELECT 1 FROM vehicles WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=$1 AND id::text<>$2 LIMIT 1",
        [normalizedPlate, vehicleId]);
      if (duplicate.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'PLATE_EXISTS' });
      }
      const updated = await client.query(
        'UPDATE vehicles SET plate=$1,make=$2,model=$3,color=COALESCE($4,color),model_year=$5,vehicle_type=$6,fuel_type=$7 WHERE id::text=$8 AND owner_id::text=$9 RETURNING id,plate,make,model,color,model_year,vehicle_type,fuel_type,created_at',
        [plate, make, model || null, color, modelYear, vehicleType, fuelType, vehicleId, owner]);
      if(mileage!==null){
        await client.query(`INSERT INTO vehicle_maintenance_state(vehicle_id,current_km,updated_at) VALUES($1,$2,NOW())
          ON CONFLICT(vehicle_id) DO UPDATE SET current_km=EXCLUDED.current_km,updated_at=NOW()`,[vehicleId,mileage]);
      }
      await client.query('COMMIT');
      if(mileage!==null)updated.rows[0].mileage=mileage;
      const brandLogo=await cachedLogo(pool,updated.rows[0].make);
      if(!brandLogo.available)queueResolve(pool,updated.rows[0].make,publicBase(req));
      return res.json({ ok: true, vehicle:{...updated.rows[0],brandLogo} });
    } catch (e) {
      if (client) await client.query('ROLLBACK').catch(() => {});
      if (e.code === '23505') return res.status(409).json({ error: 'PLATE_EXISTS' });
      console.error('owner vehicle update error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client?.release();
    }
  });


  app.delete('/api/owner/vehicles/:vehicleId', async (req,res)=>{
    const owner=ownerId(req), vehicleId=String(req.params.vehicleId||'').trim();
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    const client=await pool.connect();
    try{
      await client.query('BEGIN');
      const v=await client.query(
        'SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',
        [vehicleId,owner]
      );
      if(!v.rows.length){
        await client.query('ROLLBACK');
        return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      }

      // Keep the physical QR token for audit/print history, but detach it from the
      // deleted vehicle and make it unusable until an admin explicitly resets it.
      await client.query(
        "UPDATE qr_tags SET vehicle_id=NULL,status='revoked',activated_at=NULL WHERE vehicle_id::text=$1",
        [vehicleId]
      );

      if(await tableExists(client,'vehicle_transfers')){
        await client.query(
          "UPDATE vehicle_transfers SET status='cancelled' WHERE vehicle_id::text=$1 AND status='pending'",
          [vehicleId]
        );
      }

      const removed=await cleanupVehicleDependents(client,vehicleId);

      // FK-backed vehicle data (notifications, conversations, scan sessions/history,
      // park notes, themes, transfers) is removed by ON DELETE CASCADE.
      const deleted=await client.query(
        'DELETE FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 RETURNING id',
        [vehicleId,owner]
      );
      if(!deleted.rows.length){
        await client.query('ROLLBACK');
        return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      }

      await client.query('COMMIT');
      return res.json({ok:true,qrRevoked:true,dependentsRemoved:removed});
    }catch(e){
      await client.query('ROLLBACK').catch(()=>{});
      console.error('vehicle remove',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }finally{
      client.release();
    }
  });

  app.post('/api/owner/vehicles/:vehicleId/transfer',async(req,res)=>{
    const owner=ownerId(req),vehicleId=String(req.params.vehicleId||'').trim();if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const client=await pool.connect();try{await client.query('BEGIN');const v=await client.query('SELECT id,plate FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',[vehicleId,owner]);if(!v.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'VEHICLE_NOT_FOUND'});}
      const lastAccepted=await client.query("SELECT accepted_at FROM vehicle_transfers WHERE vehicle_id=$1 AND status='accepted' AND accepted_at IS NOT NULL ORDER BY accepted_at DESC LIMIT 1",[vehicleId]);
      if(lastAccepted.rows.length){const nextAt=new Date(new Date(lastAccepted.rows[0].accepted_at).getTime()+90*24*60*60*1000);if(nextAt>new Date()){await client.query('ROLLBACK');return res.status(429).json({error:'TRANSFER_COOLDOWN',cooldownDays:90,nextTransferAt:nextAt.toISOString(),adminOverrideRequired:true});}}
      await client.query("UPDATE vehicle_transfers SET status='cancelled' WHERE vehicle_id=$1 AND status='pending'",[vehicleId]);const code=require('crypto').randomBytes(8).toString('hex').toUpperCase();const t=await client.query("INSERT INTO vehicle_transfers(vehicle_id,from_owner_id,transfer_code,expires_at) VALUES($1,$2,$3,now()+interval '24 hours') RETURNING transfer_code,expires_at",[vehicleId,owner,code]);await client.query('COMMIT');return res.status(201).json({ok:true,plate:v.rows[0].plate,...t.rows[0]});
    }catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('vehicle transfer create',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}
  });

  app.post('/api/owner/vehicle-transfers/accept',async(req,res)=>{
    const owner=ownerId(req),code=String(req.body?.code||'').trim().toUpperCase();if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});if(!code)return res.status(400).json({error:'CODE_REQUIRED'});const client=await pool.connect();try{await client.query('BEGIN');const t=await client.query("SELECT t.*,v.plate FROM vehicle_transfers t JOIN vehicles v ON v.id=t.vehicle_id WHERE t.transfer_code=$1 FOR UPDATE",[code]);if(!t.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'TRANSFER_NOT_FOUND'});}const x=t.rows[0];if(x.status!=='pending'||new Date(x.expires_at)<=new Date()){if(x.status==='pending')await client.query("UPDATE vehicle_transfers SET status='expired' WHERE id=$1",[x.id]);await client.query('COMMIT');return res.status(410).json({error:'TRANSFER_EXPIRED'});}if(String(x.from_owner_id)===owner){await client.query('ROLLBACK');return res.status(400).json({error:'SAME_OWNER'});}
      const u=await client.query('SELECT COALESCE(premium,false) premium FROM users WHERE id::text=$1 FOR UPDATE',[owner]);if(!u.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'OWNER_NOT_FOUND'});}const lim=u.rows[0].premium?3:1,cnt=await client.query('SELECT count(*)::int n FROM vehicles WHERE owner_id::text=$1',[owner]);if(cnt.rows[0].n>=lim){await client.query('ROLLBACK');return res.status(403).json({error:'VEHICLE_LIMIT_REACHED',limit:lim});}
      const {privateReset}=await finalizeVehicleTransfer(client,{vehicleId:x.vehicle_id,transferId:x.id,newOwnerId:owner});await client.query('COMMIT');return res.json({ok:true,vehicleId:x.vehicle_id,plate:x.plate,qrPreserved:true,privateHistoryReset:true,privateReset});
    }catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('vehicle transfer accept',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}
  });

};
