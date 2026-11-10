'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const qa=JSON.parse(fs.readFileSync(process.env.QA_FILE,'utf8'));
assert.equal(qa.synthetic,true);assert.equal(qa.status,'passed');assert.match(qa.plate,/^QA-CARWASH-/);
const origin='https://staging-api-185-165-46-213.nip.io';
let step='preflight';
const output=process.env.BROWSER_OUTPUT||'phase4-browser';fs.mkdirSync(output,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||'/usr/bin/google-chrome',args:['--no-sandbox']});
 try{
  const context=await browser.newContext({viewport:{width:1280,height:1000},geolocation:{latitude:41,longitude:29},permissions:['geolocation']});
  const authCheck=await context.request.post(origin+'/api/business/auth/login',{data:{email:qa.business.email,password:qa.business.password}});
  assert.equal(authCheck.status(),200,'QA_DIRECT_LOGIN_FAILED');
  const directToken=(await authCheck.json()).token;assert.ok(directToken);
  const pushConfig=await context.request.get(origin+'/api/qa/services-v2/push/config',{headers:{Authorization:'Bearer '+directToken}});
  assert.equal(pushConfig.status(),200);const qaConfig=await pushConfig.json();
  assert.equal(qaConfig.firebaseProjectId,'cepqontag-staging');assert.equal(qaConfig.recipientRole,'business');
  assert.equal(qaConfig.deliveryEnabled,false);assert.equal(qaConfig.webPush.enabled,true);
  for(const prefix of ['/car-wash-owner/','/car-wash-business/']){
   const worker=await context.request.get(origin+prefix+'qa-service-worker.js');assert.equal(worker.status(),200);assert.ok((await worker.text()).includes("addEventListener('push'"));
   const bootstrap=await context.request.get(origin+prefix+'flutter_bootstrap.js');assert.equal(bootstrap.status(),200);
   assert.ok(!/serviceWorkerVersion:\s*["'][^"']+["']/.test(await bootstrap.text()),'CACHE_WORKER_MUST_NOT_REPLACE_QA_PUSH');
  }
  const page=await context.newPage();page.setDefaultTimeout(15000);const failures=[],responses=[];
  async function enter(label,value,target=page){
   const input=target.getByRole('textbox',{name:label,exact:true});await input.click();
   await input.evaluate(async el=>{if(document.activeElement!==el)throw Error('INPUT_NOT_FOCUSED');await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});
   await input.press('ControlOrMeta+A');await input.press('Backspace');
   await input.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
   await input.pressSequentially(value,{delay:40});await input.press('Tab');
   await input.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
   assert.ok(await input.inputValue()===value,'FIELD_VALUE_MISMATCH_'+label);return await input.inputValue();
  }
  await page.route('**/api/**',async route=>{if(new URL(route.request().url()).origin!==origin){failures.push('BLOCKED_NON_STAGING_API');await route.abort();}else await route.continue();});
  step='business-ui-login';
  page.on('pageerror',e=>failures.push(String(e.message)));
  page.on('response',r=>{if(r.url().startsWith(origin+'/api/business/car-wash/'))responses.push({path:new URL(r.url()).pathname,status:r.status()});});
  await page.goto(origin+'/car-wash-business/');
  const semantics=page.locator('flt-semantics-placeholder');await semantics.waitFor({state:'attached',timeout:60000});await semantics.dispatchEvent('click');
  await page.getByRole('button',{name:'Giriş Yap',exact:true}).click();
  await enter('E-posta',qa.business.email);
  await enter('Şifre',qa.business.password);
  assert.equal(await page.getByRole('textbox',{name:'E-posta',exact:true}).inputValue(),qa.business.email,'EMAIL_INPUT_MISMATCH');
  assert.equal(await page.getByRole('textbox',{name:'Şifre',exact:true}).inputValue(),qa.business.password,'PASSWORD_INPUT_MISMATCH');
  const login=page.waitForResponse(r=>r.url().endsWith('/api/business/auth/login')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Giriş Yap',exact:true}).click();const logged=await login;assert.equal(new URL(logged.url()).origin,origin);assert.equal(logged.status(),200,'UI_LOGIN_FAILED');
  await page.getByRole('button',{name:'QA bildirim izni',exact:true}).waitFor();
  assert.equal(await page.evaluate(()=>typeof window.cepqontagQaEnableWebPush),'function');
  step='business-calendar';
  const settingsWait=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/settings'));
  await page.getByRole('button',{name:'Oto Yıkama Yönetimi',exact:true}).click();
  assert.ok((await (await settingsWait).json()).services.length);
  await page.getByText('Randevu takvimi',{exact:true}).waitFor();
  await page.screenshot({path:output+'/business-calendar-loaded.png',fullPage:true});
  fs.writeFileSync(output+'/calendar-controls.json',JSON.stringify(await page.locator('[role],[aria-label]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.textContent?.slice(0,100)}))),null,2));
  const historyResponse=page.waitForResponse(r=>r.url().includes('/api/business/car-wash/bookings?')&&!r.url().includes('&from='));
  await page.getByRole('checkbox',{name:'Tüm geçmiş',exact:true}).click();
  const historyResult=await historyResponse;assert.equal(historyResult.status(),200);
  const historyData=await historyResult.json();assert.ok(historyData.bookings.some(b=>b.id===qa.bookingId));
  await page.getByText(`${historyData.bookings.length} randevu bu sayfada`,{exact:false}).waitFor();
  await page.screenshot({path:output+'/business-calendar.png',fullPage:true});
  await page.getByRole('button',{name:'Hizmet paketleri ekle',exact:true}).scrollIntoViewIfNeeded();
  await page.getByRole('button',{name:'Hizmet paketleri ekle',exact:true}).click();
  step='service-management';
  const name='Phase 4 QA '+Date.now();
  await enter('Ad',name);
  await enter('Açıklama','Yalnız sentetik staging işletmesi');
  const priceChecks=[],identityProof=[];
  const frame=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const serviceSelector=id=>'[flt-semantics-identifier='+JSON.stringify('car-wash-services-'+id)+']';
  async function serviceRow(id,total){
   assert.match(id,/^[0-9a-f-]{36}$/i);const row=page.locator(serviceSelector(id));
   const initiallyMounted=await row.count()>0;await frame();
   for(let scrolls=0;scrolls<Math.min(120,20+total*2);scrolls++){
    if(await row.count()){
     await row.scrollIntoViewIfNeeded();await frame();
     if(await row.isVisible()){identityProof.push({serviceId:id,initiallyMounted,scrolls,selector:serviceSelector(id)});return row;}
    }
    const viewport=page.viewportSize();await page.mouse.move(viewport.width/2,viewport.height/2);
    await page.mouse.wheel(0,Math.max(240,Math.floor(viewport.height*.65)));await frame();
   }
   await page.screenshot({path:output+'/missing-service-id.png',fullPage:true});
   throw Error('SERVICE_UUID_NOT_RENDERED_'+id);
  }
  async function renderedPrice(id,expected){
   await page.waitForFunction(({selector,text})=>{const el=document.querySelector(selector);if(!el)return false;const values=[el.textContent,el.getAttribute('aria-label'),...Array.from(el.querySelectorAll('[aria-label]')).map(n=>n.getAttribute('aria-label'))];return values.join(' ').includes(text);},{selector:serviceSelector(id),text:(expected/100).toFixed(2)+' ₺'});
  }
  function refreshWait(){return {settings:page.waitForResponse(r=>new URL(r.url()).pathname==='/api/business/car-wash/settings'&&r.request().method()==='GET'),bookings:page.waitForResponse(r=>new URL(r.url()).pathname==='/api/business/car-wash/bookings'&&r.request().method()==='GET')};}
  async function refreshed(wait,id,expected){
   const settings=await wait.settings;assert.equal(settings.status(),200);const data=await settings.json();
   assert.equal((await wait.bookings).status(),200);const found=data.services.find(s=>s.id===id);assert.ok(found,'CREATED_UUID_ABSENT_FROM_REFRESH');assert.equal(found.price_kurus,expected);assert.equal(found.name,name);
   await frame();return data.services;
  }
  function verifyPriceInPostgres(serviceId,expectedKurus){
   const {execFileSync}=require('node:child_process'),path=require('node:path');
   const script='const qaPriceProof='+JSON.stringify({serviceId,expectedKurus})+';\n'+fs.readFileSync(path.join(__dirname,'verify-price.cjs'),'utf8');
   const result=execFileSync('ssh',['-i',process.env.HOME+'/.ssh/staging_key','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-p',process.env.SSH_PORT,process.env.SSH_USER+'@'+process.env.SSH_HOST,'cd /home/cepqontag-deploy/app/server && node -'],{input:script,encoding:'utf8',timeout:20000});
   const report=JSON.parse(result.trim());assert.equal(report.priceKurus,expectedKurus);return report;
  }
  async function recordPrice(item,input,domValue,requestKurus,services){
   const persisted=await context.request.get(origin+'/api/business/car-wash/settings',{headers:{Authorization:'Bearer '+directToken}});assert.equal(persisted.status(),200);
   const readback=(await persisted.json()).services.find(s=>s.id===item.id);assert.ok(readback);assert.equal(readback.price_kurus,requestKurus);
   const db=verifyPriceInPostgres(item.id,requestKurus);
   priceChecks.push({serviceId:item.id,input,domValue,requestKurus,responseKurus:item.price_kurus,apiReadbackKurus:readback.price_kurus,postgresKurus:db.priceKurus,listIndex:services.findIndex(s=>s.id===item.id),serviceCount:services.length});
   fs.writeFileSync(output+'/price-roundtrip.json',JSON.stringify({ok:true,complete:false,onlyOwnSyntheticService:true,checks:priceChecks},null,2));
  }
  const initialDom=await enter('Fiyat (TL)','321.50');await enter('Süre (5–480 dakika)','45');
  const initialRefresh=refreshWait();
  const save=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/services')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Kaydet',exact:true}).click();const saved=await save;assert.equal(saved.request().postDataJSON().priceKurus,32150);assert.equal(saved.status(),200);
  const item=(await saved.json()).item;assert.equal(item.name,name);assert.equal(item.price_kurus,32150);assert.equal(item.duration_minutes,45);
  let services=await refreshed(initialRefresh,item.id,32150);
  await recordPrice(item,'321.50',initialDom,32150,services);
  await serviceRow(item.id,services.length);await renderedPrice(item.id,32150);
  for(const [input,expected] of [['321,50',32150],['0,01',1],['350.00',35000],['350',35000]]){
   const row=await serviceRow(item.id,services.length);await row.getByRole('button',{name:'Düzenle',exact:true}).click();
   const domValue=await enter('Fiyat (TL)',input);const wait=refreshWait();
   const response=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/services')&&r.request().method()==='POST');
   await page.getByRole('button',{name:'Kaydet',exact:true}).click();const r=await response;
   assert.equal(r.request().postDataJSON().id,item.id,'EDIT_MUST_TARGET_CREATED_UUID');assert.equal(r.request().postDataJSON().priceKurus,expected);assert.equal(r.status(),200);
   const changed=(await r.json()).item;assert.equal(changed.id,item.id);assert.equal(changed.price_kurus,expected);
   services=await refreshed(wait,item.id,expected);await recordPrice(changed,input,domValue,expected,services);
   await serviceRow(item.id,services.length);await renderedPrice(item.id,expected);
  }
  fs.writeFileSync(output+'/service-identity.json',JSON.stringify({ok:true,ordering:'created_at ASC',packageFilters:'none',identityProof},null,2));
  fs.writeFileSync(output+'/price-roundtrip.json',JSON.stringify({ok:true,complete:true,onlyOwnSyntheticService:true,checks:priceChecks},null,2));
  await page.screenshot({path:output+'/business-services.png',fullPage:true});
  await page.setViewportSize({width:393,height:852});
  await page.waitForFunction(()=>innerWidth===393&&innerHeight===852);
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await page.screenshot({path:output+'/business-mobile.png',fullPage:false});
  assert.ok(responses.some(r=>r.path.endsWith('/bookings')&&r.status===200));
  assert.ok(responses.every(r=>r.status<400));assert.deepEqual(failures,[]);
  step='owner-common-center-login';
  const ownerPage=await context.newPage();ownerPage.setDefaultTimeout(20000);
  await ownerPage.route('**/api/**',async route=>{if(new URL(route.request().url()).origin!==origin){failures.push('BLOCKED_NON_STAGING_API');await route.abort();}else await route.continue();});
  await ownerPage.goto(origin+'/car-wash-owner/');
  const ownerSemantics=ownerPage.locator('flt-semantics-placeholder');await ownerSemantics.waitFor({state:'attached',timeout:60000});await ownerSemantics.dispatchEvent('click');
  await ownerPage.getByRole('button',{name:'Giriş Yap',exact:true}).click();
  async function ownerEnter(name,value){await enter(name,value,ownerPage);}
  await ownerEnter('5XX XXX XX XX',qa.owner.phone.replace(/^\+90/,''));await ownerEnter('Şifreni gir',qa.owner.password);
  const ownerLogin=ownerPage.waitForResponse(r=>r.url().endsWith('/api/owner/login-phone')&&r.request().method()==='POST');
  await ownerPage.getByRole('button',{name:'Giriş Yap',exact:true}).click();const loggedOwner=await ownerLogin;assert.equal(loggedOwner.status(),200);
  const ownerToken=(await loggedOwner.json()).accessToken;
  const center=await context.request.get(origin+'/api/owner/notifications',{headers:{Authorization:'Bearer '+ownerToken}});assert.equal(center.status(),200);
  const target=(await center.json()).notifications.find(n=>n.service_category==='car_wash');assert.ok(target);
  step='owner-common-center-filters';
  await ownerPage.locator('[flt-semantics-identifier="owner-notifications-bell"]').click();
  await ownerPage.getByText('Tümü',{exact:true}).waitFor();await ownerPage.getByText('Araç',{exact:true}).waitFor();await ownerPage.getByText('Hizmetler',{exact:true}).waitFor();
  await ownerPage.getByText('Randevular',{exact:true}).click();
  const notice=ownerPage.locator('[flt-semantics-identifier='+JSON.stringify('owner-notification-'+target.id)+']');await notice.waitFor({state:'visible'});
  await ownerPage.screenshot({path:output+'/owner-shared-center.png',fullPage:true});
  step='owner-notification-detail';
  const bookingDetail=ownerPage.waitForResponse(r=>r.url().endsWith('/api/car-wash/bookings/'+target.booking_id)&&r.request().method()==='GET');
  await notice.click();const detailResponse=await bookingDetail;assert.equal(detailResponse.status(),200);assert.equal((await detailResponse.json()).booking.id,target.booking_id);
  await ownerPage.getByText('Randevu detayları',{exact:true}).waitFor();
  const readback=await context.request.get(origin+'/api/owner/notifications',{headers:{Authorization:'Bearer '+ownerToken}});assert.equal(readback.status(),200);assert.equal((await readback.json()).notifications.find(n=>n.id===target.id).status,'read');
  await ownerPage.screenshot({path:output+'/owner-notification-booking.png',fullPage:true});
  assert.deepEqual(failures,[]);
  fs.writeFileSync(output+'/result.json',JSON.stringify({ok:true,businessUrl:origin+'/car-wash-business/',checks:['owner-real-ui-login','owner-common-center-filters','owner-notification-exact-booking-route','qa-push-config-no-delivery','qa-worker-assets-no-cache-worker-conflict','qa-permission-button-present','real-business-login','real-calendar-history','service-create','price-duration-persistence','price-update','desktop-mobile-render','no-page-errors'],serviceId:item.id,priceChecks,notificationId:target.id,bookingId:target.booking_id,responses},null,2));
  console.log('PHASE4_BROWSER_OK');
 }finally{await browser.close();}
})().catch(e=>{let reason=String(e.message);for(const secret of [qa.business.password,qa.owner.password,qa.owner.phone,qa.business.email])if(secret)reason=reason.split(secret).join('[REDACTED]');console.error('PHASE4_BROWSER_FAILED',{step,reason});process.exitCode=1;});
