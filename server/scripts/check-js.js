const {spawnSync}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
function check(dir){
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  if(['node_modules','uploads'].includes(entry.name))continue;
  const file=path.join(dir,entry.name);
  if(entry.isDirectory())check(file);
  else if(entry.name.endsWith('.js')){
   const r=spawnSync(process.execPath,['--check',file],{stdio:'inherit'});
   if(r.status!==0)process.exit(r.status||1);
  }
 }
}
check(root);
console.log('All backend JavaScript syntax checks passed');
