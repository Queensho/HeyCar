'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
process.env.OWNER_AUTH_SECRET='motorcycle-test-secret-must-be-more-than-32-characters';
const {accessToken}=require('../owner-auth-service');
const {validateMotorcycleProfile,motorcycleServiceOverview}=require('../motorcycle-service-policy');
const register=require('../motorcycle-profile-routes');

const OWNER='11111111-1111-4111-8111-111111111111';
const BIKE='22222222-2222-4222-8222-222222222222';
const OTHER='33333333-3333-4333-8333-333333333333';

function req(body,token=accessToken(OWNER),vehicleId=BIKE){
  return {params:{vehicleId},headers:{authorization:'Bearer '+token},body};
}
function res(){
  return {
    statusCode:200,body:null,
    status(code){this.statusCode=code;return this;},
    json(value){this.body=value;return this;},
  };
}
function fixture(kind='motorcycle',authorized=true){
  const routes={};
  const app={get:(path,fn)=>{routes['GET '+path]=fn;},
    put:(path,fn)=>{routes['PUT '+path]=fn;}};
  const queries=[];
  const pool={async query(sql,args){
    queries.push({sql,args});
    if(sql.includes('FROM vehicles v')){
      assert.match(sql,/v\.owner_id::text=\$2/);
      assert.deepEqual(args,[BIKE,OWNER]);
      return {rows:authorized?[{id:BIKE,vehicle_type:kind,current_km:5600}]:[]};
    }
    if(sql.includes('SELECT * FROM vehicle_motorcycle_profiles')){
      return {rows:[{vehicle_id:BIKE,engine_cc:125,oil_capacity_ml:800,
        drive_type:'belt',last_oil_change_km:4500,oil_interval_km:1500,
        last_drive_service_km:3000,drive_interval_km:4000}]};
    }
    if(sql.includes('INSERT INTO vehicle_motorcycle_profiles')){
      assert.deepEqual(args,[BIKE,125,800,'belt',4500,1500,3000,4000]);
      return {rows:[{engine_cc:125,oil_capacity_ml:800,
        drive_type:'belt',last_oil_change_km:4500,oil_interval_km:1500,
        last_drive_service_km:3000,drive_interval_km:4000}]};
    }
    throw new Error('unexpected SQL');
  }};
  register(app,pool);
  return {routes,queries};
}

const route='/api/owner/vehicles/:vehicleId/motorcycle-profile';
const valid={engineCc:125,oilCapacityMl:800,driveType:'belt',
  lastOilChangeKm:4500,oilIntervalKm:1500,
  lastDriveServiceKm:3000,driveIntervalKm:4000};

test('rider supplied CC, oil capacity and intervals are validated, no defaults invented',()=>{
  assert.deepEqual(validateMotorcycleProfile({}),{
    engineCc:null,oilCapacityMl:null,driveType:null,lastOilChangeKm:null,
    oilIntervalKm:null,lastDriveServiceKm:null,driveIntervalKm:null,
  });
  assert.deepEqual(validateMotorcycleProfile(valid),valid);
  for(const v of [
    {...valid,engineCc:-1},{...valid,engineCc:0},
    {...valid,oilCapacityMl:50000},{...valid,oilCapacityMl:'1e3'},
    {...valid,driveType:'hoverboard'},{...valid,lastOilChangeKm:-10},
    {...valid,oilIntervalKm:0},{...valid,driveIntervalKm:90000},
    {...valid,engineCc:{n:125}},null,[],
  ])assert.throws(()=>validateMotorcycleProfile(v),/INVALID_MOTORCYCLE_PROFILE/);
});

test('maintenance due/soon/ok are derived from reported odometer',()=>{
  const p=validateMotorcycleProfile(valid);
  const near=motorcycleServiceOverview(p,5800);
  assert.equal(near.oil.nextDueKm,6000);
  assert.equal(near.oil.remainingKm,200);
  assert.equal(near.oil.status,'soon');
  assert.equal(near.drivetrain.nextDueKm,7000);
  assert.equal(near.drivetrain.status,'ok');
  const overdue=motorcycleServiceOverview(p,7200);
  assert.equal(overdue.oil.status,'overdue');
  assert.equal(overdue.drivetrain.status,'overdue');
  assert.equal(overdue.drivetrain.remainingKm,-200);
  const unknown=motorcycleServiceOverview(p,0);
  assert.equal(unknown.oil.status,'not_configured');
  assert.equal(unknown.oil.nextDueKm,null);
  assert.equal(motorcycleServiceOverview({},5800).oil.configured,false);
});

test('unauthenticated and unauthorized lookups never read private profiles',async()=>{
  const x=fixture();
  const missing=res();
  await x.routes['GET '+route]({params:{vehicleId:BIKE},headers:{}},missing);
  assert.equal(missing.statusCode,401);
  assert.equal(x.queries.length,0);
  const foreign=fixture('motorcycle',false),deny=res();
  await foreign.routes['GET '+route](req({}),deny);
  assert.equal(deny.statusCode,404);
  assert.equal(foreign.queries.length,1);
  const car=fixture('car'),wrongType=res();
  await car.routes['GET '+route](req({}),wrongType);
  assert.equal(wrongType.statusCode,404);
  assert.equal(car.queries.length,1);
});

test('authenticated motorcycle owner reads exact bike profile with km statuses',async()=>{
  const x=fixture(),response=res();
  await x.routes['GET '+route](req({}),response);
  assert.equal(response.statusCode,200);
  assert.equal(response.body.profile.oilCapacityMl,800);
  assert.equal(response.body.service.oil.remainingKm,400);
  assert.equal(response.body.service.drivetrain.remainingKm,1400);
});

test('only owner can save and rejects invalid profile before DB writes',async()=>{
  const x=fixture(),response=res();
  await x.routes['PUT '+route](req(valid),response);
  assert.equal(response.statusCode,200);
  assert.equal(response.body.profile.engineCc,125);
  const invalid=res(),start=x.queries.length;
  await x.routes['PUT '+route](req({...valid,engineCc:999999}),invalid);
  assert.equal(invalid.statusCode,400);
  assert.equal(x.queries.length,start);
  const foreign=fixture('motorcycle',false),denied=res();
  await foreign.routes['PUT '+route](req(valid),denied);
  assert.equal(denied.statusCode,404);
  assert.equal(foreign.queries.length,1);
});
