'use strict';

const driveTypes=Object.freeze(['chain','belt','shaft','other']);

function optionalInt(raw,min,max){
  if(raw==null||raw==='')return null;
  if(typeof raw==='boolean'||typeof raw==='object')throw new Error('INVALID_MOTORCYCLE_PROFILE');
  const s=String(raw).trim();
  if(!/^\d+$/.test(s))throw new Error('INVALID_MOTORCYCLE_PROFILE');
  const n=Number(s);
  if(!Number.isSafeInteger(n)||n<min||n>max)throw new Error('INVALID_MOTORCYCLE_PROFILE');
  return n;
}

function validateMotorcycleProfile(body){
  if(!body||typeof body!=='object'||Array.isArray(body))throw new Error('INVALID_MOTORCYCLE_PROFILE');
  const drive=body.driveType??body.drive_type??null;
  if(drive!=null&&drive!==''&&!driveTypes.includes(drive))throw new Error('INVALID_MOTORCYCLE_PROFILE');
  const parsed={
    engineCc:optionalInt(body.engineCc??body.engine_cc,1,3000),
    oilCapacityMl:optionalInt(body.oilCapacityMl??body.oil_capacity_ml,100,12000),
    driveType:drive||null,
    lastOilChangeKm:optionalInt(body.lastOilChangeKm??body.last_oil_change_km,0,9999999),
    oilIntervalKm:optionalInt(body.oilIntervalKm??body.oil_interval_km,100,30000),
    lastDriveServiceKm:optionalInt(body.lastDriveServiceKm??body.last_drive_service_km,0,9999999),
    driveIntervalKm:optionalInt(body.driveIntervalKm??body.drive_interval_km,100,50000),
  };
  // Kilometer-based estimates only make sense with both the last performed
  // mileage and rider-entered service interval. Partial setup is allowed.
  return parsed;
}

function serviceItem(label,lastKm,intervalKm,currentKm){
  if(lastKm==null||intervalKm==null||currentKm==null)return {
    label,configured:false,nextDueKm:null,remainingKm:null,status:'not_configured',
  };
  const nextDueKm=lastKm+intervalKm,remainingKm=nextDueKm-currentKm;
  const soonThreshold=Math.max(250,Math.ceil(intervalKm/10));
  return {
    label,configured:true,nextDueKm,remainingKm,
    status:remainingKm<=0?'overdue':remainingKm<=soonThreshold?'soon':'ok',
  };
}

function motorcycleServiceOverview(profile,currentKm){
  const mileage=Number.isInteger(currentKm)&&currentKm>0?currentKm:null;
  const p=profile||{};
  return {
    currentKm:mileage,
    oil:serviceItem('Motor yağı',p.lastOilChangeKm??p.last_oil_change_km??null,p.oilIntervalKm??p.oil_interval_km??null,mileage),
    drivetrain:serviceItem('Zincir / kayış',p.lastDriveServiceKm??p.last_drive_service_km??null,p.driveIntervalKm??p.drive_interval_km??null,mileage),
  };
}

module.exports={validateMotorcycleProfile,motorcycleServiceOverview};
