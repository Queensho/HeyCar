'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
process.chdir('/home/cepqontag-deploy/app/server');
require(process.cwd()+'/node_modules/dotenv').config({quiet:true});
const {Pool}=require(process.cwd()+'/node_modules/pg');
(async()=>{
 assert.equal(process.env.DB_NAME,'heycar_staging','STAGING_DATABASE_REQUIRED');
 const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD,connectionTimeoutMillis:5000});
 try{
  const r=await pool.query('SELECT current_database() AS database');
  assert.equal(r.rows[0].database,'heycar_staging');
  const health=await fetch('http://127.0.0.1:8091/health',{signal:AbortSignal.timeout(8000)});
  assert.equal(health.status,200);assert.equal((await health.json()).ok,true);
  const candidates=new Set();
  const configured=process.env.PUBLIC_API_BASE_URL||'';
  if(configured.startsWith('https://')&&!configured.includes('heycar-api-185-165-46-213.nip.io'))candidates.add(configured);
  let nginxReadable=false;
  for(const dir of ['/etc/nginx/sites-enabled','/etc/nginx/conf.d']){
   let files=[];try{files=fs.readdirSync(dir);}catch{continue;}
   for(const file of files){let text='';try{text=fs.readFileSync(dir+'/'+file,'utf8');nginxReadable=true;}catch{continue;}
    for(const match of text.matchAll(/\bserver\s*\{/g)){
     let depth=1,end=match.index+match[0].length;
     for(;end<text.length&&depth;end++){if(text[end]==='{')depth++;if(text[end]==='}')depth--;}
     const block=text.slice(match.index,end);
     if(!/proxy_pass\s+http:\/\/(?:127\.0\.0\.1|localhost):8091\b/.test(block)||!/listen\s+[^;]*443[^;]*ssl/.test(block))continue;
     const names=block.match(/server_name\s+([^;]+);/);
     for(const name of (names?.[1]||'').split(/\s+/)){if(/^[a-z0-9.-]+$/i.test(name)&&name.includes('.')&&!name.includes('heycar-api-185-165-46-213.nip.io'))candidates.add('https://'+name);}
    }
   }
  }
  console.log(JSON.stringify({database:r.rows[0].database,loopbackHealth:true,nginxReadable,httpsCandidates:[...candidates]},null,2));
 }finally{await pool.end();}
})().catch(()=>{console.error('STAGING_PROBE_FAILED: configuration, database or loopback health could not be verified');process.exitCode=1;});
