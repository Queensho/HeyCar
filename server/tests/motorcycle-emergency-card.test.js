'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
process.env.OWNER_AUTH_SECRET='emergency-test-secret-longer-than-thirty-two-characters';

const register=require('../motorcycle-emergency-routes');
const {validateEmergencyCard}=register;
const {publicEmergencyAvailable}=require('../qr-routes');
const {hashScanToken}=require('../scan-session-service');
const OWNER='11111111-1111-4111-8111-111111111111';
const BIKE='22222222-2222-4222-8222-222222222222';
const TOKEN='CP-QAR-0000001';
const SCAN='secret-from-legitimate-qr-session';

function accessToken(){
  const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const now=Math.floor(Date.now()/1000);
  const p=Buffer.from(JSON.stringify({
    sub:OWNER,typ:'owner',sv:1,sid:'unit-test-session',iat:now,exp:now+900,
  })).toString('base64url');
  const sig=crypto.createHmac('sha256',process.env.OWNER_AUTH_SECRET)
    .update(h+'.'+p).digest('base64url');
  return h+'.'+p+'.'+sig;
}
function response(){
  return {
    statusCode:200,payload:null,headers:{},
    status(v){this.statusCode=v;return this;},
    set(k,v){this.headers[k]=v;return this;},
    json(p){this.payload=p;return this;},
  };
}
function fixture({ownerAllowed=true,published=true,vehicleType='motorcycle',scanValid=true}={}){
  const handlers={},queries=[];
  const app={
    get:(route,...args)=>{handlers['GET '+route]=args.at(-1);},
    put:(route,...args)=>{handlers['PUT '+route]=args.at(-1);},
  };
  const card={
    rider_full_name:'Sürücü Test',blood_group:'A+',
    emergency_contact_name:'Acil Yakını',emergency_contact_phone:'+905551112233',
    is_public:published,
  };
  const pool={async query(sql,params){
    queries.push({sql,params});
    if(sql.includes("FROM vehicles")&&!sql.includes("JOIN vehicles")){
      return {rows:ownerAllowed&&vehicleType==='motorcycle'?[{id:BIKE,owner_id:OWNER}]:[],
        rowCount:ownerAllowed&&vehicleType==='motorcycle'?1:0};
    }
    if(sql.includes('FROM qr_tags q JOIN vehicles v')){
      return {rows:vehicleType==='motorcycle'?[{vehicle_id:BIKE,owner_id:OWNER}]:[],
        rowCount:vehicleType==='motorcycle'?1:0};
    }
    if(sql.includes('FROM qr_scan_sessions s')){
      return {rows:scanValid?[{
        token_hash:hashScanToken(SCAN),qr_token:TOKEN,vehicle_id:BIKE,owner_id:OWNER,
      }]:[],rowCount:scanValid?1:0};
    }
    if(sql.includes('FROM vehicle_motorcycle_emergency_cards')){
      const allow=!sql.includes('is_public=TRUE')||published;
      return {rows:allow?[card]:[],rowCount:allow?1:0};
    }
    if(sql.includes('INSERT INTO vehicle_motorcycle_emergency_cards')){
      assert.match(sql,/ON CONFLICT\(vehicle_id\)/);
      assert.deepEqual(params.slice(0,2),[BIKE,OWNER]);
      return {rows:[{...card,
        rider_full_name:params[2],blood_group:params[3],
        emergency_contact_name:params[4],emergency_contact_phone:params[5],
        is_public:params[6]}],rowCount:1};
    }
    throw Error('UNEXPECTED_SQL: '+sql.slice(0,100));
  }};
  register(app,pool);
  return {handlers,queries};
}
const ownerRoute='/api/owner/vehicles/:vehicleId/emergency-card';
const publicRoute='/api/qr/:token/emergency-card';
const valid={
  riderFullName:'Sürücü Test',bloodGroup:'A+',emergencyContactName:'Acil Yakını',
  emergencyContactPhone:'+905551112233',isPublic:true,
  consent:true,contactConsent:true,
};
const ownerReq=(body,authorized=true)=>({
  headers:authorized?{authorization:'Bearer '+accessToken()}:{},
  params:{vehicleId:BIKE},body,
});
const publicReq=(scan=SCAN)=>({
  headers:scan?{'x-scan-token':scan}:{},
  params:{token:TOKEN},
});

test('default private and publish requires two explicit consents',()=>{
  assert.equal(validateEmergencyCard({...valid,isPublic:false,consent:false,contactConsent:false}).isPublic,false);
  for(const bad of [
    {...valid,contactConsent:false},
    {...valid,consent:false},
    {...valid,emergencyContactName:''},
    {...valid,emergencyContactPhone:''},
    {...valid,riderFullName:''},
    {...valid,bloodGroup:'X+'},
    {...valid,emergencyContactPhone:'12345'},
    {...valid,emergencyContactPhone:'<script>'},
    null,[],
  ])assert.throws(()=>validateEmergencyCard(bad));
  assert.equal(validateEmergencyCard({...valid,bloodGroup:''}).bloodGroup,'');
});

test('only motorcycle owner reads/updates sensitive profile',async()=>{
  const f=fixture(),get=f.handlers['GET '+ownerRoute],put=f.handlers['PUT '+ownerRoute];
  const noAuth=response();
  await get(ownerReq(null,false),noAuth);
  assert.equal(noAuth.statusCode,401);
  assert.equal(f.queries.length,0);
  const wrong=fixture({ownerAllowed:false}),denied=response();
  await wrong.handlers['GET '+ownerRoute](ownerReq(),denied);
  assert.equal(denied.statusCode,404);
  const car=fixture({vehicleType:'car'}),notBike=response();
  await car.handlers['PUT '+ownerRoute](ownerReq(valid),notBike);
  assert.equal(notBike.statusCode,404);
  const saved=response();
  await put(ownerReq(valid),saved);
  assert.equal(saved.statusCode,200);
  assert.equal(saved.payload.card.isPublic,true);
  const hidden=response();
  await put(ownerReq({...valid,isPublic:false,contactConsent:false,consent:false}),hidden);
  assert.equal(hidden.payload.card.isPublic,false);
  assert.equal(hidden.headers['Cache-Control'],'no-store');
});

test('public QR requires real scan session and active motorcycle QR',async()=>{
  const f=fixture(),handler=f.handlers['GET '+publicRoute],none=response();
  await handler(publicReq(''),none);
  assert.equal(none.statusCode,401);
  assert.equal(f.queries.length,0);
  const badScan=fixture({scanValid:false}),denied=response();
  await badScan.handlers['GET '+publicRoute](publicReq(),denied);
  assert.equal(denied.statusCode,401);
  const notBike=fixture({vehicleType:'car'}),notFound=response();
  await notBike.handlers['GET '+publicRoute](publicReq(),notFound);
  assert.equal(notFound.statusCode,404);
  const hidden=fixture({published:false}),privateResult=response();
  await hidden.handlers['GET '+publicRoute](publicReq(),privateResult);
  assert.equal(privateResult.statusCode,404);
  const okay=response();
  await handler(publicReq(),okay);
  assert.equal(okay.statusCode,200);
  assert.equal(okay.payload.card.emergencyContactPhone,'+905551112233');
  assert.equal(okay.headers['Cache-Control'],'no-store');
  assert.match(okay.headers['X-Robots-Tag'],/noindex/);
  assert.ok(f.queries.some(q=>q.sql.includes('is_public=TRUE')));
});

test('transfer, car conversion and public QR URL never leak prior emergency details',()=>{
  const transfer=fs.readFileSync(path.join(__dirname,'../vehicle-transfer-service.js'),'utf8');
  const manage=fs.readFileSync(path.join(__dirname,'../vehicle-management-routes.js'),'utf8');
  const qr=fs.readFileSync(path.join(__dirname,'../qr-routes.js'),'utf8');
  assert.match(transfer,/DELETE FROM vehicle_motorcycle_emergency_cards/);
  assert.match(manage,/vehicleType!=='motorcycle'/);
  assert.doesNotMatch(qr,/emergency_contact_phone|rider_full_name|blood_group/);
});

test('QR resolver reports only opt-in emergency availability',async()=>{
  const queries=[];
  const livePool={async query(sql,params){
    queries.push({sql,params});
    return {rows:[{available:true}]};
  }};
  const vehicle={vehicle_id:BIKE,vehicle_type:'motorcycle'};
  assert.equal(await publicEmergencyAvailable(livePool,vehicle,'active'),true);
  assert.equal(queries.length,1);
  assert.deepEqual(queries[0].params,[BIKE]);
  assert.match(queries[0].sql,/card\.is_public=TRUE/);
  assert.match(queries[0].sql,/owner_vehicle\.owner_id=card\.owner_id/);
  assert.doesNotMatch(queries[0].sql,/rider_full_name|blood_group|emergency_contact_phone/);
  assert.equal(await publicEmergencyAvailable(livePool,vehicle,'paused'),false);
  assert.equal(await publicEmergencyAvailable(livePool,{...vehicle,vehicle_type:'car'},'active'),false);
  assert.equal(queries.length,1);
  const missingTable={query:async()=>{throw Error('undefined_table');}};
  assert.equal(await publicEmergencyAvailable(missingTable,vehicle,'active'),false);
  const unpublished={query:async()=>({rows:[{available:false}]})};
  assert.equal(await publicEmergencyAvailable(unpublished,vehicle,'active'),false);
});
