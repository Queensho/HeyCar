'use strict';
const assert=require('node:assert/strict'),nativeFs=require('node:fs');
const backupRoot='/home/cepqontag-deploy/car-wash-phase3-backups';
function hardenStagingBackups({environment,database,directory=backupRoot,fs=nativeFs}){
 assert.equal(environment,'staging');assert.equal(database,'heycar_staging');assert.equal(directory,backupRoot);
 const plan=[];
 function add(path,isDirectory){
  const st=fs.lstatSync(path);assert.ok(!st.isSymbolicLink());assert.equal(fs.realpathSync(path),path);
  assert.ok(isDirectory?st.isDirectory():st.isFile());assert.equal(st.uid,process.getuid());
  plan.push({path,mode:isDirectory?0o700:0o600,isDirectory});
 }
 if(!fs.existsSync(directory))return {directories:0,files:0,verified:true};
 add(directory,true);
 for(const name of fs.readdirSync(directory)){
  if(!/^\d{17}-[0-9a-f]{12}$/.test(name))continue;
  const child=directory+'/'+name;add(child,true);
  for(const name of ['heycar_staging.dump','server.js','staging.env'])if(fs.existsSync(child+'/'+name))add(child+'/'+name,false);
 }
 // Validate the complete plan before changing any permissions. Never read/delete content.
 for(const item of plan){fs.chmodSync(item.path,item.mode);assert.equal(fs.lstatSync(item.path).mode&0o777,item.mode);}
 return {directories:plan.filter(p=>p.isDirectory).length,files:plan.filter(p=>!p.isDirectory).length,verified:true};
}
module.exports={hardenStagingBackups,backupRoot};
