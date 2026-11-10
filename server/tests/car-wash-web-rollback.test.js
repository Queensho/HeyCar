const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase4/publish.cjs'),'utf8');
test('failed staging restart restores prior server, module and web release without database access',async()=>{
 const root='/home/cepqontag-deploy/car-wash-phase4-web',release=root+'/releases/'+'a'.repeat(40),prior=root+'/releases/'+'b'.repeat(40);
 const original="owner_auth_sessions Idempotency-Key registerQrRoutes(app,pool); require('./car-wash-staging-web.cjs')(app);";
 const files=new Map([['server.js',original],['car-wash-staging-web.cjs','old-module'],[release+'/staging-web.cjs','new-module']]);
 for(const folder of ['business','owner'])files.set(release+'/'+folder+'/index.html','<base href="/car-wash-'+folder+'/">');
 for(const folder of ['business','owner'])files.set(release+'/'+folder+'/main.dart.js','compiled');
 const links=new Map([[root+'/current',prior]]);let restarts=0;
 const fakeFs={realpathSync:p=>p==='.'?'/home/cepqontag-deploy/app/server':links.get(p)||p,existsSync:p=>files.has(p)||links.has(p),readFileSync:p=>{assert.ok(files.has(p),p);return files.get(p);},writeFileSync:(p,v)=>files.set(p,v),copyFileSync:(a,b)=>files.set(b,files.get(a)),mkdirSync:()=>{},symlinkSync:(target,p)=>links.set(p,target),renameSync:(a,b)=>{if(links.has(a)){links.set(b,links.get(a));links.delete(a);}else{files.set(b,files.get(a));files.delete(a);}},unlinkSync:p=>{links.delete(p);files.delete(p);}};
 const process={argv:['node','-',release],env:{APP_ENV:'staging',PORT:'8091',CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',STAGING_DISABLE_EXTERNAL_SERVICES:'1',DB_HOST:'127.0.0.1',DB_NAME:'heycar_staging',DB_USER:'cepqontag_staging'}};
 await vm.runInNewContext(source,{process,console:{log:()=>{},error:()=>{}},fetch:async()=>({ok:true}),setTimeout,require:n=>{
  if(n==='node:assert/strict')return assert;if(n==='node:fs')return fakeFs;if(n==='node:crypto')return {};
  if(n==='dotenv')return {config:()=>{}};if(n==='pg')return {Pool:class{constructor(){assert.fail('No DB access');}}};
  if(n==='node:child_process')return {execFileSync:(cmd)=>{if(cmd==='sudo'&&++restarts===1)throw Object.assign(Error('simulated restart failure'),{code:'TEST_RESTART_FAILED'});}};
  assert.fail(n);
 }});
 assert.equal(process.exitCode,1);assert.equal(files.get('server.js'),original);assert.equal(files.get('car-wash-staging-web.cjs'),'old-module');assert.equal(links.get(root+'/current'),prior);assert.equal(restarts,2);
});
