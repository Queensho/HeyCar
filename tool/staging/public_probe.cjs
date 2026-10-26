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
 const dependencies={};
 for(const binary of ['/usr/bin/python3','/usr/sbin/nginx','/usr/bin/certbot','/usr/bin/openssl','/usr/bin/systemctl','/usr/bin/curl'])dependencies[binary]=fs.existsSync(binary);
 const runtimeVersions={python:execFileSync('/usr/bin/python3',['-I','-c','import sys; print(".".join(map(str,sys.version_info[:3])))'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim(),openssl:execFileSync('/usr/bin/openssl',['version'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim()};
 const certbotHelp=execFileSync('/usr/bin/certbot',['--help','all'],{encoding:'utf8',stdio:['ignore','pipe','ignore']});
 const certbotOptions={};for(const flag of ['--no-directory-hooks','--config-dir','--work-dir','--logs-dir','--keep-until-expiring'])certbotOptions[flag]=certbotHelp.includes(flag);
 const productionReadonly={};
 const prodHealth=await fetch('https://heycar-api-185-165-46-213.nip.io/health',{signal:AbortSignal.timeout(15000)});
 assert.equal(prodHealth.status,200);assert.equal((await prodHealth.json()).ok,true);productionReadonly.apiHealthy=true;
 const prodPanel=await fetch('https://queensho.github.io/HeyCar/isletme/',{signal:AbortSignal.timeout(15000)});
 assert.equal(prodPanel.status,200);productionReadonly.panelSha256=require('node:crypto').createHash('sha256').update(Buffer.from(await prodPanel.arrayBuffer())).digest('hex');
 const defaultTlsOutput=execFileSync('/usr/bin/openssl',['s_client','-connect',publicIp+':443','-noservername','-showcerts'],{encoding:'utf8',input:'',timeout:15000,stdio:['pipe','pipe','ignore']});
 const defaultTlsPem=defaultTlsOutput.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/);
 assert(defaultTlsPem,'DEFAULT_TLS_CERTIFICATE_UNAVAILABLE');
 productionReadonly.defaultTlsSha256=require('node:crypto').createHash('sha256').update(new (require('node:crypto').X509Certificate)(defaultTlsPem[0]).raw).digest('hex');
 const cors=await fetch('http://127.0.0.1:8091/api/environment',{method:'OPTIONS',headers:{Origin:'https://queensho.github.io','Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,content-type'},signal:AbortSignal.timeout(10000)});
 assert.equal(cors.headers.get('access-control-allow-origin'),'https://queensho.github.io');
 assert(cors.headers.get('access-control-allow-headers')?.toLowerCase().includes('authorization'));
 const denied=await fetch('http://127.0.0.1:8091/api/environment',{headers:{Origin:'https://untrusted.invalid'},signal:AbortSignal.timeout(10000)});
 assert.equal(denied.status,403);productionReadonly.stagingPagesCors=true;productionReadonly.stagingUntrustedOriginRejected=true;
 let rules='';try{rules=execFileSync('sudo',['-n','-l'],{encoding:'utf8',stdio:['ignore','pipe','ignore']});}catch{}
 const nginxSites=[];
 for(const dir of ['/etc/nginx/sites-enabled','/etc/nginx/conf.d']){
  let files=[];try{files=fs.readdirSync(dir);}catch{continue;}
  for(const name of files){
   try{
    const file=dir+'/'+name;const source=fs.readFileSync(file,'utf8');const directives=source.replace(/^\s*#.*$/gm,'').replace(/[ \t]+#.*$/gm,'');
    const certificateFiles=[...directives.matchAll(/\bssl_certificate\s+([^;]+);/g)].map(m=>m[1].trim());
    const certificates=certificateFiles.map(file=>{
     if(!file.startsWith('/')||file.includes('$'))return {file,readable:false};
     try{return {file,publicMetadata:execFileSync('/usr/bin/openssl',['x509','-in',file,'-noout','-subject','-dates'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim()};}catch{return {file,readable:false};}
    });
    nginxSites.push({file,sha256:require('node:crypto').createHash('sha256').update(source).digest('hex'),serverNames:[...directives.matchAll(/\bserver_name\s+([^;]+);/g)].map(m=>m[1].trim()),listeners:[...directives.matchAll(/\blisten\s+([^;]+);/g)].map(m=>m[1].trim()),upstreams:[...directives.matchAll(/\bproxy_pass\s+([^;]+);/g)].map(m=>m[1].trim().replace(/\/\/[^/@\s]+@/g,'//[redacted]@')),certificates});
   }catch{}
  }
 }
 const helper='/usr/local/sbin/cepqontag-staging-https';
 let helperTrusted=false;try{const s=fs.statSync(helper);helperTrusted=s.uid===0&&(s.mode&0o022)===0;}catch{}
 let canWriteSites=false;try{fs.accessSync('/etc/nginx/sites-enabled',fs.constants.W_OK);canWriteSites=true;}catch{}
 const helperAuthorized=helperTrusted&&rules.includes(helper)&&rules.includes('NOPASSWD');
 console.log(JSON.stringify({identity,publicIp,hostname,addresses,nginxSites,dependencies,runtimeVersions,certbotOptions,productionReadonly,nginxInstalled:fs.existsSync('/usr/sbin/nginx'),certbotInstalled:fs.existsSync('/usr/bin/certbot'),canWriteSites,helperTrusted,helperAuthorized,nginxSudo:rules.includes('/usr/sbin/nginx'),certbotSudo:rules.includes('/usr/bin/certbot'),nginxReloadSudo:/systemctl[^\n]*(?:reload|restart)[^\n]*nginx/.test(rules),unrestrictedSudo:/NOPASSWD:\s*ALL/.test(rules)},null,2));
})().catch(e=>{console.error('PUBLIC_STAGING_PROBE_FAILED: '+e.message);process.exitCode=1;});
