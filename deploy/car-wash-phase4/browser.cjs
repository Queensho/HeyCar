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
   assert.ok(await input.inputValue()===value,'FIELD_VALUE_MISMATCH_'+label);
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
  const priceTrace=[];const priceInput=page.getByRole('textbox',{name:'Fiyat (TL)',exact:true});
  // Reproduce the previous DOM-fill/5ms sequence without saving probe values.
  for(let probe=0;probe<24;probe++){
   await page.getByRole('textbox',{name:'Açıklama',exact:true}).click();
   await priceInput.fill('');await priceInput.pressSequentially('321.50',{delay:5});
   const afterTyping=await priceInput.inputValue();await priceInput.press('Tab');
   await priceInput.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
   priceTrace.push({probe,intended:'321.50',afterTyping,afterBlur:await priceInput.inputValue()});
  }
  fs.writeFileSync(output+'/price-input-diagnostics.json',JSON.stringify({legacySequence:priceTrace,credentialsRecorded:false},null,2));
  await enter('Fiyat (TL)','321.50');
  await enter('Süre (5–480 dakika)','45');
  const save=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/services')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Kaydet',exact:true}).click();const saved=await save;assert.equal(saved.request().postDataJSON().priceKurus,32150,'REQUEST_KURUS_MISMATCH');assert.equal(saved.status(),200);
  const item=(await saved.json()).item;assert.equal(item.price_kurus,32150);assert.equal(item.duration_minutes,45);
  function verifyPriceInPostgres(serviceId,expectedKurus){
   const {execFileSync}=require('node:child_process'),path=require('node:path');
   const script='const qaPriceProof='+JSON.stringify({serviceId,expectedKurus})+';\n'+fs.readFileSync(path.join(__dirname,'verify-price.cjs'),'utf8');
   const result=execFileSync('ssh',['-i',process.env.HOME+'/.ssh/staging_key','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-p',process.env.SSH_PORT,process.env.SSH_USER+'@'+process.env.SSH_HOST,'cd /home/cepqontag-deploy/app/server && node -'],{input:script,encoding:'utf8',timeout:20000});
   const report=JSON.parse(result.trim());assert.equal(report.priceKurus,expectedKurus);return report;
  }
  verifyPriceInPostgres(item.id,32150);
  const priceChecks=[{serviceId:item.id,input:'321.50',domValue:'321.50',requestKurus:32150,responseKurus:item.price_kurus}];
  for(const [input,expected] of [['321,50',32150],['0,01',1],['350.00',35000]]){
   const group=page.getByRole('group',{name:new RegExp('^'+name)});await group.waitFor({state:'visible'});await group.getByRole('button',{name:'Düzenle',exact:true}).click();
   await enter('Fiyat (TL)',input);
   const response=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/services')&&r.request().method()==='POST');
   await page.getByRole('button',{name:'Kaydet',exact:true}).click();const r=await response;
   assert.equal(r.request().postDataJSON().priceKurus,expected);assert.equal(r.status(),200);assert.equal((await r.json()).item.price_kurus,expected);
   const persisted=await context.request.get(origin+'/api/business/car-wash/settings',{headers:{Authorization:'Bearer '+directToken}});assert.equal(persisted.status(),200);
   assert.equal((await persisted.json()).services.find(s=>s.id===item.id).price_kurus,expected);
   await page.getByRole('group',{name:new RegExp('^'+name+'.*'+(expected/100).toFixed(2).replace('.','[.]'),'s')}).waitFor({state:'visible'});
   verifyPriceInPostgres(item.id,expected);
   priceChecks.push({serviceId:item.id,input,domValue:input,requestKurus:expected,responseKurus:expected,apiReadbackKurus:expected});
  }
  fs.writeFileSync(output+'/price-roundtrip.json',JSON.stringify({ok:true,onlyOwnSyntheticService:true,checks:priceChecks},null,2));
  // The business owner can see only their own newly created package; verify an edit via UI.
  const newService=page.getByRole('group',{name:new RegExp('^'+name)});await newService.waitFor({state:'visible'});
  await newService.getByRole('button',{name:'Düzenle',exact:true}).click();
  await enter('Fiyat (TL)','350');
  const update=page.waitForResponse(r=>r.url().endsWith('/api/business/car-wash/services')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Kaydet',exact:true}).click();const updated=await update;assert.equal(updated.request().postDataJSON().priceKurus,35000);assert.equal(((await updated.json()).item).price_kurus,35000);
  await page.getByRole('group',{name:new RegExp('^'+name+'.*350[.]00','s')}).waitFor({state:'visible'});
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
  await ownerPage.getByText('Bildirimler',{exact:true}).last().click();
  await ownerPage.getByText('Tümü',{exact:true}).waitFor();await ownerPage.getByText('Araç',{exact:true}).waitFor();await ownerPage.getByText('Hizmetler',{exact:true}).waitFor();
  await ownerPage.getByText('Randevular',{exact:true}).click();
  await ownerPage.getByText('Oto Yıkama',{exact:true}).first().waitFor();
  await ownerPage.screenshot({path:output+'/owner-shared-center.png',fullPage:true});
  step='owner-notification-detail';
  const bookingDetail=ownerPage.waitForResponse(r=>r.url().endsWith('/api/car-wash/bookings/'+target.booking_id)&&r.request().method()==='GET');
  await ownerPage.getByText('Oto Yıkama',{exact:true}).first().click();assert.equal((await bookingDetail).status(),200);
  await ownerPage.getByText('Randevu detayları',{exact:true}).waitFor();await ownerPage.screenshot({path:output+'/owner-notification-booking.png',fullPage:true});
  assert.deepEqual(failures,[]);
  fs.writeFileSync(output+'/result.json',JSON.stringify({ok:true,businessUrl:origin+'/car-wash-business/',checks:['owner-real-ui-login','owner-common-center-filters','owner-notification-exact-booking-route','qa-push-config-no-delivery','qa-worker-assets-no-cache-worker-conflict','qa-permission-button-present','real-business-login','real-calendar-history','service-create','price-duration-persistence','price-update','desktop-mobile-render','no-page-errors'],serviceId:item.id,priceChecks,responses},null,2));
  console.log('PHASE4_BROWSER_OK');
 }finally{await browser.close();}
})().catch(e=>{let reason=String(e.message);for(const secret of [qa.business.password,qa.owner.password,qa.owner.phone,qa.business.email])if(secret)reason=reason.split(secret).join('[REDACTED]');console.error('PHASE4_BROWSER_FAILED',{step,reason});process.exitCode=1;});
