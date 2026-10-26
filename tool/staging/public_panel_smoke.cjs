'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:1600,height:900}});let identity=false,productionRequest=false;const errors=[];
  page.on('pageerror',e=>errors.push(e.message.slice(0,200)));
  await page.route('**/*',async route=>{const url=new URL(route.request().url());if(url.pathname.startsWith('/api/')&&url.origin!=='https://staging-api-185-165-46-213.nip.io'){productionRequest=true;return route.abort();}return route.continue();});
  page.on('response',async response=>{if(response.url()==='https://staging-api-185-165-46-213.nip.io/api/environment'&&response.status()===200){const x=await response.json();identity=x.environment==='staging'&&x.database==='heycar_staging'&&x.port===8091&&x.externalServicesDisabled===true;}});
  const url='https://queensho.github.io/HeyCar/isletme-staging/';
  const build=await page.request.get(url+'staging-build.json');assert.equal(build.status(),200);const manifest=await build.json();assert.equal(manifest.environment,'staging');assert.equal(manifest.api,'https://staging-api-185-165-46-213.nip.io');
  await page.goto(url);await page.locator('flutter-view').waitFor({state:'attached',timeout:60000});await page.waitForTimeout(5000);
  assert.equal(identity,true,'PUBLISHED_PANEL_DID_NOT_VERIFY_REAL_STAGING_API');assert.equal(productionRequest,false);assert.equal(errors.length,0,errors.join('\n'));assert.match(await page.title(),/STAGING/);
  fs.mkdirSync('staging-evidence',{recursive:true});await page.screenshot({path:'staging-evidence/published-panel.png',fullPage:true});
  fs.writeFileSync('staging-evidence/published-panel.json',JSON.stringify({url,publicHttpsIdentityVerified:true,productionApiRequests:false,commit:manifest.commit}));console.log('PUBLISHED_PANEL_REAL_BROWSER_HTTPS_BOOT_PASSED');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
