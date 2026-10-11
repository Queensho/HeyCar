'use strict';

const {ownerId}=require('./owner-auth-service');
const {validateMotorcycleProfile,motorcycleServiceOverview}=require('./motorcycle-service-policy');

function formatProfile(row){
  return {
    engineCc:row?.engine_cc??null,
    oilCapacityMl:row?.oil_capacity_ml??null,
    driveType:row?.drive_type??null,
    lastOilChangeKm:row?.last_oil_change_km??null,
    oilIntervalKm:row?.oil_interval_km??null,
    lastDriveServiceKm:row?.last_drive_service_km??null,
    driveIntervalKm:row?.drive_interval_km??null,
  };
}

module.exports=function registerMotorcycleProfileRoutes(app,pool){
  async function ownedMotorcycle(req,res){
    const owner=ownerId(req);
    if(!owner){res.status(401).json({error:'OWNER_REQUIRED'});return null;}
    const vehicleId=String(req.params.vehicleId||'').trim();
    if(!/^[0-9a-f-]{36}$/i.test(vehicleId)){
      res.status(404).json({error:'MOTORCYCLE_NOT_FOUND'});return null;
    }
    const r=await pool.query(
      `SELECT v.id,COALESCE(v.vehicle_type,'car') AS vehicle_type,
              COALESCE(ms.current_km,0)::int AS current_km
         FROM vehicles v
         LEFT JOIN vehicle_maintenance_state ms ON ms.vehicle_id::text=v.id::text
        WHERE v.id::text=$1 AND v.owner_id::text=$2
        LIMIT 1`,
      [vehicleId,owner]
    );
    const vehicle=r.rows[0];
    if(!vehicle||vehicle.vehicle_type!=='motorcycle'){
      res.status(404).json({error:'MOTORCYCLE_NOT_FOUND'});return null;
    }
    return vehicle;
  }

  app.get('/api/owner/vehicles/:vehicleId/motorcycle-profile',async(req,res)=>{
    try{
      const vehicle=await ownedMotorcycle(req,res);if(!vehicle)return;
      const r=await pool.query(
        'SELECT * FROM vehicle_motorcycle_profiles WHERE vehicle_id=$1 LIMIT 1',
        [vehicle.id]
      );
      const profile=formatProfile(r.rows[0]);
      res.json({ok:true,vehicleId:vehicle.id,profile,
        service: motorcycleServiceOverview(profile,vehicle.current_km)});
    }catch(e){
      console.error('motorcycle profile load',e);
      res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.put('/api/owner/vehicles/:vehicleId/motorcycle-profile',async(req,res)=>{
    let values;
    try{values=validateMotorcycleProfile(req.body);}catch(_){
      return res.status(400).json({error:'INVALID_MOTORCYCLE_PROFILE'});
    }
    try{
      const vehicle=await ownedMotorcycle(req,res);if(!vehicle)return;
      const params=[
        vehicle.id,values.engineCc,values.oilCapacityMl,values.driveType,
        values.lastOilChangeKm,values.oilIntervalKm,
        values.lastDriveServiceKm,values.driveIntervalKm,
      ];
      const r=await pool.query(
        `INSERT INTO vehicle_motorcycle_profiles(
          vehicle_id,engine_cc,oil_capacity_ml,drive_type,
          last_oil_change_km,oil_interval_km,last_drive_service_km,
          drive_interval_km,updated_at
        ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,NOW())
        ON CONFLICT(vehicle_id) DO UPDATE SET
          engine_cc=EXCLUDED.engine_cc,
          oil_capacity_ml=EXCLUDED.oil_capacity_ml,
          drive_type=EXCLUDED.drive_type,
          last_oil_change_km=EXCLUDED.last_oil_change_km,
          oil_interval_km=EXCLUDED.oil_interval_km,
          last_drive_service_km=EXCLUDED.last_drive_service_km,
          drive_interval_km=EXCLUDED.drive_interval_km,
          updated_at=NOW()
        RETURNING *`,
        params
      );
      const profile=formatProfile(r.rows[0]);
      res.json({ok:true,vehicleId:vehicle.id,profile,
        service:motorcycleServiceOverview(profile,vehicle.current_km)});
    }catch(e){
      console.error('motorcycle profile save',e);
      res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};
