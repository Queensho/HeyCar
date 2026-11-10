const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase3/smoke.cjs'),'utf8');
const preflight=source.slice(0,source.indexOf("const {Pool}=require('pg');"));
function run(value){
 const env={APP_ENV:'staging',PORT:'8091',CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false'};
 if(value!==undefined)env.STAGING_DISABLE_EXTERNAL_SERVICES=value;
 return vm.runInNewContext(preflight,{process:{env},require:n=>{
  if(n==='node:assert/strict')return assert;
  if(n==='node:fs')return {realpathSync:()=>'/home/cepqontag-deploy/app/server'};
  if(n==='node:crypto')return {};
  if(n==='dotenv')return {config:()=>{}};
  assert.fail('Preflight must not open a database or call external services');
 }});
}
test('smoke accepts explicit suppression encodings used by the real external-service policy',()=>{
 for(const v of ['1','true','yes','on',' TRUE ',' On '])assert.doesNotThrow(()=>run(v));
});
test('smoke fails closed for absent, false or unrecognized suppression before database access',()=>{
 for(const v of [undefined,'','0','false','no','off','truthy','2','true,false'])assert.throws(()=>run(v),/EXTERNAL_SERVICE_SUPPRESSION_REQUIRED/);
});
const plateFactory=new Function('assert',source.slice(source.indexOf('function fixturePlate'),source.indexOf('const plate=fixturePlate'))+';return fixturePlate;')(assert);
test('QA fixture plates preserve per-run UUID uniqueness under production plate normalization',()=>{
 const ids=Array.from({length:1000},()=>require('node:crypto').randomUUID());
 const normalized=ids.map(id=>plateFactory(id).toUpperCase().replace(/\s+/g,''));
 assert.equal(new Set(normalized).size,ids.length);
 for(const id of ids)assert.equal(plateFactory(id),plateFactory(id));
 assert.ok(normalized.every(p=>p.startsWith('QA-CARWASH-')));
 assert.throws(()=>plateFactory('34 QA TEST'));
});
