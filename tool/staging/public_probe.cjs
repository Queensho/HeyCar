'use strict';
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const dns=require('node:dns').promises;
const assert=require('node:assert/strict');
(async()=>{
 const identity=await (await fetch('http://127.0.0.1:8091/api/environment',{signal:AbortSignal.timeout(10000)})).json();
 assert.equal(identity.environment,'staging');assert.equal(identity.database,'heycar_staging');assert.equal(identity.externalServicesDisabled,true);
 const publicIp=(await (await fetch('https://api.ipify.org',{signal:AbortSignal.timeout(15000)})).text()).trim();
 assert.match(publicIp,/^(?:\d{1,3}\.){3}\d{1,3}$/);
 const hostname='staging-api-'+publicIp.replaceAll('.','-')+'.nip.io';
 const addresses=await dns.resolve4(hostname);
 assert(addresses.includes(publicIp),'NIP_DNS_MISMATCH');
 let rules='';try{rules=execFileSync('sudo',['-n','-l'],{encoding:'utf8',stdio:['ignore','pipe','ignore']});}catch{}
 const nginxSites=[];
 for(const dir of ['/etc/nginx/sites-enabled','/etc/nginx/conf.d']){
  let files=[];try{files=fs.readdirSync(dir);}catch{continue;}
  for(const name of files){
   try{
    const file=dir+'/'+name;const source=fs.readFileSync(file,'utf8');
    const certificateFiles=[...source.matchAll(/\bssl_certificate\s+([^;]+);/g)].map(m=>m[1].trim());
    const certificates=certificateFiles.map(file=>{
     if(!file.startsWith('/')||file.includes('$'))return {file,readable:false};
     try{return {file,publicMetadata:execFileSync('/usr/bin/openssl',['x509','-in',file,'-noout','-subject','-dates'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim()};}catch{return {file,readable:false};}
    });
    nginxSites.push({file,sha256:require('node:crypto').createHash('sha256').update(source).digest('hex'),serverNames:[...source.matchAll(/\bserver_name\s+([^;]+);/g)].map(m=>m[1].trim()),listeners:[...source.matchAll(/\blisten\s+([^;]+);/g)].map(m=>m[1].trim()),upstreams:[...source.matchAll(/\bproxy_pass\s+([^;]+);/g)].map(m=>m[1].trim()),certificates});
   }catch{}
  }
 }
 const helper='/usr/local/sbin/cepqontag-staging-https';
 let helperTrusted=false;try{const s=fs.statSync(helper);helperTrusted=s.uid===0&&(s.mode&0o022)===0;}catch{}
 let canWriteSites=false;try{fs.accessSync('/etc/nginx/sites-enabled',fs.constants.W_OK);canWriteSites=true;}catch{}
 const helperAuthorized=helperTrusted&&rules.includes(helper)&&rules.includes('NOPASSWD');
 console.log(JSON.stringify({identity,publicIp,hostname,addresses,nginxSites,nginxInstalled:fs.existsSync('/usr/sbin/nginx'),certbotInstalled:fs.existsSync('/usr/bin/certbot'),canWriteSites,helperTrusted,helperAuthorized,nginxSudo:rules.includes('/usr/sbin/nginx'),certbotSudo:rules.includes('/usr/bin/certbot'),nginxReloadSudo:/systemctl[^\n]*(?:reload|restart)[^\n]*nginx/.test(rules),unrestrictedSudo:/NOPASSWD:\s*ALL/.test(rules)},null,2));
})().catch(e=>{console.error('PUBLIC_STAGING_PROBE_FAILED: '+e.message);process.exitCode=1;});
