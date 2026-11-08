const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const server=path.resolve(__dirname,'..');
const root=path.resolve(server,'..');
function filesIn(script){
  const source=fs.readFileSync(path.join(root,script),'utf8');
  const match=source.match(/\bFILES=\(([\s\S]*?)\)/);
  assert.ok(match,script+' must declare its copy/rollback file set');
  return new Set(match[1].trim().split(/\s+/));
}
function localImports(file){
  const source=fs.readFileSync(path.join(server,file),'utf8');
  return Array.from(source.matchAll(/require\(['"]\.\/([^'"]+)['"]\)/g),m=>m[1]+'.js');
}
test('matrix partial rollout includes every new marketplace and push-policy dependency',()=>{
  const files=filesIn('deploy/matrix-live-sync.sh');
  const introduced=new Set(['admin-offers-marketplace-routes.js','offer-redemption-service.js','offers-marketplace-routes.js','offer-validation.js','external-services-policy.js']);
  const found=new Set();
  for(const entry of ['admin-management-routes.js','business-routes.js','push-routes.js','web-push-service.js']){
    assert.ok(files.has(entry));
    for(const dependency of localImports(entry))if(introduced.has(dependency)){
      found.add(dependency);
      assert.ok(files.has(dependency),entry+' requires '+dependency+' but the deployment would not copy/back it up');
    }
  }
  assert.equal(found.size,introduced.size,'cover all newly required modules');
});
test('call-only partial rollout keeps the shared push policy with its sender',()=>{
  const files=filesIn('deploy/call-offline-driver-live.sh');
  assert.ok(files.has('push-routes.js'));
  const dependency=localImports('push-routes.js').find(x=>x==='external-services-policy.js');
  assert.ok(dependency);assert.ok(files.has(dependency));
});

// Execute only the compatibility block with mocked shell functions. Never run
// the deployment script, sudo, psql, or any service/database command.
const {spawnSync}=require('node:child_process');
for(const fixture of [
  {role:0,index:0,expected:0,applies:true},
  {role:1,index:1,expected:0,applies:false},
  {role:1,index:0,expected:9,applies:false},
])test('pending index migration compatibility '+JSON.stringify(fixture),()=>{
  const source=fs.readFileSync(path.join(root,'deploy/matrix-live-sync.sh'),'utf8');
  const block=source.split('# BEGIN offer pending-index compatibility')[1]?.split('# END offer pending-index compatibility')[0];
  assert.ok(block);
  const stubs=`set -e
DB=mock_db
TMP=/mock
db_scalar(){ if [[ "$1" == *information_schema.columns* ]]; then echo ${fixture.role}; else echo ${fixture.index}; fi; }
sudo(){ echo MOCK_MIGRATION_APPLY; }
fail(){ echo MOCK_ABORT; exit 9; }
`;
  const result=spawnSync('bash',['-c',stubs+block],{encoding:'utf8'});
  assert.equal(result.status,fixture.expected,result.stderr);
  assert.equal(result.stdout.includes('MOCK_MIGRATION_APPLY'),fixture.applies);
});
