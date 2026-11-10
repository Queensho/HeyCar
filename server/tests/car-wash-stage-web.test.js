const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase4/staging-web.cjs'),'utf8');
function load(env,filesystem){const module={exports:{}};const routes=[];const context={module,process:{env},require:n=>{
 if(n==='node:assert/strict')return assert;
 if(n==='node:fs')return filesystem;
 if(n==='express')return {static:()=>()=>{}};
 assert.fail('Unexpected dependency');
}};vm.runInNewContext(source,context);module.exports({use:(...args)=>routes.push(args)});return routes;}
test('staging web does no filesystem or routing work in production',()=>{
 assert.equal(load({APP_ENV:'production',PORT:'8091'},new Proxy({},{get:()=>assert.fail('Production filesystem access')})).length,0);
});
test('staging web rejects incorrect cwd and release symlink outside its staging tree',()=>{
 assert.throws(()=>load({APP_ENV:'staging',PORT:'8091'},{realpathSync:()=>'/production'}));
 assert.throws(()=>load({APP_ENV:'staging',PORT:'8091'},{realpathSync:p=>p==='.'?'/home/cepqontag-deploy/app/server':'/production'}));
});
test('staging web mounts only the two test application paths and sets no-store/CSP',()=>{
 const root='/home/cepqontag-deploy/car-wash-phase4-web/releases/'+'a'.repeat(40);
 const routes=load({APP_ENV:'staging',PORT:'8091'},{realpathSync:p=>p==='.'?'/home/cepqontag-deploy/app/server':p.endsWith('/current')?root:p});
 assert.deepEqual(routes.map(r=>r[0]),['/car-wash-business/','/car-wash-owner/']);
 const headers={};routes[0][1]({}, {set:(k,v)=>headers[k]=v},()=>{});
 assert.equal(headers['Cache-Control'],'no-store');assert.match(headers['Content-Security-Policy'],/object-src 'none'/);
});
