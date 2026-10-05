const {driverId:authenticatedDriverId}=require('./driver-auth-service');

function normalizePlan(row){
  const premium=row?.premium_active===true||row?.premium===true;
  if(!premium)return 'free';
  const raw=String(row?.premium_plan||'').trim().toLowerCase();
  return raw==='family'?'family':'individual';
}

async function ownerPremiumPlan(db,ownerId){
  if(!ownerId)return {premium:false,plan:'free',family:false};
  const r=await db.query(
    `SELECT
       (COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium_active,
       COALESCE(NULLIF(premium_plan,''),'individual') AS premium_plan,
       premium_expires_at
     FROM users
     WHERE id::text=$1
     LIMIT 1`,
    [String(ownerId)]
  );
  if(!r.rows.length)return {premium:false,plan:'free',family:false};
  const plan=normalizePlan(r.rows[0]);
  return {
    premium:plan!=='free',
    plan,
    family:plan==='family',
    expiresAt:r.rows[0].premium_expires_at||null,
  };
}

async function driverVehicleEntitlement(db,driverId,vehicleId){
  if(!driverId||!vehicleId)return null;
  const r=await db.query(
    `SELECT
       v.id AS vehicle_id,v.owner_id,v.plate,v.make,v.model,
       d.driver_user_id,d.driver_name,
       (a.driver_user_id=d.driver_user_id AND (a.active_until IS NULL OR a.active_until>NOW())) AS active_driver,
       (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS premium_active,
       COALESCE(NULLIF(u.premium_plan,''),'individual') AS premium_plan,
       u.premium_expires_at
     FROM vehicle_drivers d
     JOIN vehicles v ON v.id::text=d.vehicle_id::text
     JOIN users u ON u.id=v.owner_id
     LEFT JOIN vehicle_active_drivers a ON a.vehicle_id=v.id
     WHERE d.driver_user_id::text=$1
       AND v.id::text=$2
     LIMIT 1`,
    [String(driverId),String(vehicleId)]
  );
  if(!r.rows.length)return null;
  const x=r.rows[0],plan=normalizePlan(x);
  return {
    vehicleId:String(x.vehicle_id),
    ownerId:String(x.owner_id),
    plate:x.plate||'',
    make:x.make||'',
    model:x.model||'',
    driverName:x.driver_name||'',
    activeDriver:x.active_driver===true,
    ownerPlan:plan,
    ownerPremium:plan!=='free',
    familyPremium:plan==='family',
    premiumExpiresAt:x.premium_expires_at||null,
    features:{
      towing:true,
      valet:true,
      offers:true,
      parking:true,
      advancedParking:plan==='family',
      maintenance:plan==='family',
      reminders:plan==='family',
      maintenanceShare:plan==='family',
    },
  };
}

async function driverEntitlements(db,driverId){
  if(!driverId)return [];
  const r=await db.query(
    `SELECT
       v.id AS vehicle_id,v.owner_id,v.plate,v.make,v.model,
       d.driver_name,
       (a.driver_user_id=d.driver_user_id AND (a.active_until IS NULL OR a.active_until>NOW())) AS active_driver,
       (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS premium_active,
       COALESCE(NULLIF(u.premium_plan,''),'individual') AS premium_plan,
       u.premium_expires_at
     FROM vehicle_drivers d
     JOIN vehicles v ON v.id::text=d.vehicle_id::text
     JOIN users u ON u.id=v.owner_id
     LEFT JOIN vehicle_active_drivers a ON a.vehicle_id=v.id
     WHERE d.driver_user_id::text=$1
     ORDER BY d.created_at DESC`,
    [String(driverId)]
  );
  return r.rows.map(x=>{
    const plan=normalizePlan(x);
    return {
      vehicleId:String(x.vehicle_id),
      ownerId:String(x.owner_id),
      plate:x.plate||'',
      make:x.make||'',
      model:x.model||'',
      driverName:x.driver_name||'',
      activeDriver:x.active_driver===true,
      ownerPlan:plan,
      ownerPremium:plan!=='free',
      familyPremium:plan==='family',
      premiumExpiresAt:x.premium_expires_at||null,
      features:{
        towing:true,
        valet:true,
        offers:true,
        parking:true,
        advancedParking:plan==='family',
        maintenance:plan==='family',
        reminders:plan==='family',
        maintenanceShare:plan==='family',
      },
    };
  });
}

async function requireDriverVehicle(req,res,db,{family=false,active=false}={}){
  const driverId=authenticatedDriverId(req);
  if(!driverId){
    res.status(401).json({error:'DRIVER_REQUIRED'});
    return null;
  }
  const vehicleId=String(req.params.vehicleId||req.body?.vehicleId||'').trim();
  if(!vehicleId){
    res.status(400).json({error:'VEHICLE_REQUIRED'});
    return null;
  }
  const e=await driverVehicleEntitlement(db,driverId,vehicleId);
  if(!e){
    res.status(403).json({error:'DRIVER_NOT_AUTHORIZED'});
    return null;
  }
  if(family&&!e.familyPremium){
    res.status(402).json({
      error:'FAMILY_PREMIUM_REQUIRED',
      ownerPlan:e.ownerPlan,
      purchaseBy:'owner',
    });
    return null;
  }
  if(active&&!e.activeDriver){
    res.status(403).json({error:'DRIVER_NOT_ACTIVE'});
    return null;
  }
  return {driverId,...e};
}

module.exports={
  ownerPremiumPlan,
  driverVehicleEntitlement,
  driverEntitlements,
  requireDriverVehicle,
};
