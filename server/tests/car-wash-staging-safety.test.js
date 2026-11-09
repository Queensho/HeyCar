const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase3/deploy.cjs'),'utf8');
function attempt({cwd='/home/cepqontag-deploy/app/server',envFile='/home/cepqontag-deploy/app/server/.env',overrides={}}={}){
 let poolCreated=false;
 const env={APP_ENV:'staging',PORT:'8091',STAGING_DISABLE_EXTERNAL_SERVICES:'true',DB_HOST:'127.0.0.1',DB_NAME:'heycar_staging',DB_USER:'cepqontag_staging',...overrides};
 const id='a'.repeat(40),directory='/home/cepqontag-deploy/car-wash-phase3-source/'+id;
 assert.throws(()=>vm.runInNewContext(source,{
  require:name=>{
   if(name==='node:assert/strict')return assert;
   if(name==='node:path')return path;
   if(name==='node:crypto')return require('node:crypto');
   if(name==='node:child_process')return {execFileSync:()=>assert.fail('No command may run')};
   if(name==='node:fs')return {realpathSync:p=>p==='.'?cwd:p==='.env'?envFile:directory,readFileSync:p=>p.endsWith('manifest.json')?JSON.stringify({sha:id,files:{}}):''};
   if(name==='dotenv')return {parse:()=>env};
   if(name==='pg')return {Pool:class{constructor(){poolCreated=true;assert.fail('No database connection is permitted');}}};
   throw Error(name);
  },process:{argv:['node','-',directory]},console,
 }));
 assert.equal(poolCreated,false);
}
test('staging deploy refuses production working directory before touching database',()=>attempt({cwd:'/opt/heycar'}));
test('staging deploy refuses an environment file symlinked into production',()=>attempt({envFile:'/opt/heycar/.env'}));
for(const overrides of [{APP_ENV:'production'},{PORT:'8090'},{DB_NAME:'heycar_db'},{DB_USER:'heycar_user'},{DB_HOST:'remote.example'},{STAGING_DISABLE_EXTERNAL_SERVICES:'false'},{DATABASE_URL:'postgresql://heycar_user:x@localhost/heycar_db'}]){
 test('staging deploy fails closed for '+Object.keys(overrides).join(','),()=>attempt({overrides}));
}
const patchFactory=new Function('assert',source.slice(source.indexOf('function patchedServer'),source.indexOf('(async()=>{'))+';return patchedServer;');
const patch=patchFactory(assert);
const original="const sessions='AUTH_SESSION_REVOKED owner_auth_sessions';\nconst cors={allowedHeaders:['Authorization']};\nregisterQrRoutes(app,pool);\nregisterExistingOffers(app,pool);\nregisterExistingMarketplace(app,pool);\nasync function shutdown(signal){ oldShutdown(); }";
test('staging integration preserves all existing offers/marketplace registrations',()=>{
 const out=patch(original);
 assert.ok(out.includes('registerExistingOffers(app,pool);\nregisterExistingMarketplace(app,pool);'));
 assert.ok(out.includes('Idempotency-Key'));
 assert.ok(out.includes("require('./car-wash-booking-routes')(app,pool)"));
});
test('staging patch refuses an ambiguous registration or missing session guard',()=>{
 assert.throws(()=>patch(original.replace('registerQrRoutes(app,pool);','')));
 assert.throws(()=>patch(original+'\nregisterQrRoutes(app,pool);'));
 assert.throws(()=>patch(original.replace('AUTH_SESSION_REVOKED','OLD')));
});
