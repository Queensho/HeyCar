'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const phase=process.argv[2],file=process.argv[3],fixture=JSON.parse(fs.readFileSync(file,'utf8'));
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1440,height:1100},...(fs.existsSync('staging-auth-state.json')?{storageState:'staging-auth-state.json'}:{})});
 const page=await context.newPage();
 let violation=false;
 await page.route('**/*',async route=>{
  const request=route.request(),url=new URL(request.url());
  if(url.pathname.startsWith('/api/')&&(url.origin!=='http://127.0.0.1:18091'||request.headers().authorization==='Bearer production-session-sentinel')){
   violation=true;return route.abort();
  }
  return route.continue();
 });
 if(phase==='create')await page.addInitScript(()=>localStorage.setItem('flutter.business_token',JSON.stringify('production-session-sentinel')));
 await page.goto('http://127.0.0.1:8085/HeyCar/isletme-staging/');
 await page.getByText('STAGING / TEST ORTAMI',{exact:true}).waitFor({timeout:60000});
 if(phase==='create'){
  await page.getByRole('button',{name:'Giriş Yap',exact:true}).click();
  await page.getByRole('textbox',{name:'E-posta',exact:true}).fill(fixture.email);
  await page.getByLabel('Şifre',{exact:true}).fill(fixture.password);
  const login=page.waitForResponse(r=>r.url().endsWith('/api/business/auth/login')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Giriş Yap',exact:true}).click();assert.equal((await login).status(),200);
  await page.getByText('CepQontag Staging İşletmesi',{exact:true}).first().waitFor();
  await page.getByRole('button',{name:'Yeni Kampanya Oluştur',exact:true}).click();
  await page.getByRole('textbox',{name:'Kampanya başlığı',exact:true}).fill(fixture.title);
  await page.getByRole('textbox',{name:'Açıklama',exact:true}).fill('Yalnız staging arayüz testi');
  await page.getByRole('textbox',{name:'Normal fiyat (TL)',exact:true}).fill('100');
  await page.getByRole('textbox',{name:'CepQontag fiyatı (TL)',exact:true}).fill('50');
  const created=page.waitForResponse(r=>r.url().endsWith('/api/business/campaigns')&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Yayınla',exact:true}).click();
  const response=await created;assert.equal(response.status(),201);const data=await response.json();
  fixture.campaignId=data.campaign.id;fs.writeFileSync(file,JSON.stringify(fixture),{mode:0o600});
  assert.equal(data.campaign.title,fixture.title);assert.equal(data.campaign.is_active,false);
  await page.getByText(fixture.title,{exact:true}).first().waitFor();
  assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.business_token')),JSON.stringify('production-session-sentinel'));
 }else{
  await page.getByText(fixture.title,{exact:true}).first().waitFor({timeout:60000});
  await page.getByRole('button',{name:'Düzenle',exact:true}).first().click();
  if(phase==='edit')await page.getByRole('textbox',{name:'Açıklama',exact:true}).fill('Staging panelinde düzenlendi');
  else{
   const toggle=page.getByRole('switch',{name:'Aktif',exact:true});
   const current=await toggle.getAttribute('aria-checked');
   if((current==='true')!==(phase==='publish'))await toggle.click();
  }
  const updated=page.waitForResponse(r=>r.url().endsWith('/api/business/campaigns/'+fixture.campaignId)&&r.request().method()==='PATCH');
  await page.getByRole('button',{name:'Kaydet',exact:true}).click();const response=await updated;assert.equal(response.status(),200);
  const body=response.request().postDataJSON();
  if(phase!=='edit')assert.deepEqual(Object.keys(body),['isActive']);
  await page.getByText('Kampanya güncellendi.',{exact:true}).waitFor();
 }
 assert.equal(violation,false,'PRODUCTION_REQUEST_BLOCKED');
 await context.storageState({path:'staging-auth-state.json'});fs.chmodSync('staging-auth-state.json',0o600);
 fs.mkdirSync('staging-evidence',{recursive:true});
 await page.screenshot({path:'staging-evidence/panel-'+phase+'.png',fullPage:true});
 await browser.close();console.log('STAGING_PANEL_UI_'+phase.toUpperCase()+'_PASS');
})().catch(()=>{console.error('STAGING_PANEL_UI_'+phase.toUpperCase()+'_FAILED (credentials and token omitted)');process.exitCode=1;});
