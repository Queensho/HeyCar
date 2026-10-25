'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root='/home/cepqontag-deploy/app/server';
process.chdir(root);
const dotenv=require(root+'/node_modules/dotenv');
const env=dotenv.parse(fs.readFileSync('.env'));
assert.equal(env.DB_NAME,'heycar_staging','STAGING_DATABASE_REQUIRED');
const run=process.argv[2];assert.match(run||'',/^\d+$/);
const backup='/home/cepqontag-deploy/staging-backup-'+run;
if(process.argv[3]==='restore'){
 for(const file of ['.env','server.js','push-routes.js','web-push-service.js'])fs.copyFileSync(path.join(backup,file),file);
 console.log('STAGING_BACKEND_RESTORED');
}else{
 fs.mkdirSync(backup,{mode:0o700});
 for(const file of ['.env','server.js','push-routes.js','web-push-service.js'])fs.copyFileSync(file,path.join(backup,file));
 let entry=fs.readFileSync('server.js','utf8');
 if(!entry.includes("require('./staging-safety')"))entry=entry.replace("require('dotenv').config();","require('dotenv').config();\nconst {validateStagingEnvironment,registerStagingIdentity}=require('./staging-safety');\nvalidateStagingEnvironment();");
 if(!entry.includes('registerStagingIdentity(app,pool)'))entry=entry.replace('app.locals.heycarPool=pool;','app.locals.heycarPool=pool;\nregisterStagingIdentity(app,pool);');
 if(!entry.includes("defaultBrowserOrigins.push('http://127.0.0.1:8085'"))entry=entry.replace('const configuredOrigins=String',"if(process.env.APP_ENV==='staging')defaultBrowserOrigins.push('http://127.0.0.1:8085','http://localhost:8085');\nconst configuredOrigins=String");
 entry=entry.replace('const stopSmartRouteScan=startSmartRouteScan(app,pool);',"const stopSmartRouteScan=process.env.APP_ENV==='staging'?()=>{}:startSmartRouteScan(app,pool);");
 assert(entry.includes('registerStagingIdentity(app,pool)'));
 fs.copyFileSync('.staging-new-safety.js','staging-safety.js');
 fs.writeFileSync('server.js',entry);
 for(const file of ['push-routes.js','web-push-service.js']){
  let source=fs.readFileSync(file,'utf8');
  const guard="if(process.env.APP_ENV==='staging')return {attempted:0,delivered:0,skipped:'staging'};";
  source=source.replace('async function sendFrom(table,idColumn,userId,data,title,body){','async function sendFrom(table,idColumn,userId,data,title,body){\n'+guard);
  source=source.replace('const sendToken=async(token,data,title,body)=>{','const sendToken=async(token,data,title,body)=>{\n'+guard);
  assert(source.includes(guard));fs.writeFileSync(file,source);
 }
 let content=fs.readFileSync('.env','utf8');
 for(const [key,value] of Object.entries({APP_ENV:'staging',PORT:'8091',STAGING_DISABLE_EXTERNAL_SERVICES:'1',PUBLIC_API_BASE_URL:'http://127.0.0.1:18091'})){
  content=content.replace(new RegExp('^'+key+'=.*$','gm'),'');content+='\n'+key+'='+value+'\n';
 }
 fs.writeFileSync('.env',content,{mode:0o600});
 console.log('STAGING_BACKEND_OVERLAY_READY');
}
