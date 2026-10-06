const express=require('express');
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {writeAdminAudit}=require('./admin-audit');

const SCHEMA_VERSION=1;
const COMPONENT_TYPES=new Set([
  'weather_card','vehicle_security','story_carousel','quick_actions','monthly_summary',
  'services_grid','promo_banner','recent_notifications','image_banner','text_banner','spacer'
]);
const ACTIONS=new Set([
  'NONE','OPEN_TOWING','OPEN_ROADSIDE','OPEN_VALE','OPEN_OPPORTUNITIES','OPEN_PARKING',
  'OPEN_MAINTENANCE','OPEN_DRIVERS','OPEN_INSPECTION','OPEN_WEATHER','OPEN_PREMIUM',
  'OPEN_NOTIFICATIONS','OPEN_VEHICLES','EXTERNAL_URL'
]);
const AUDIENCES=new Set(['all','pro','non_pro','qr_active','qr_inactive']);
const TOKENS=new Set(['primary','accent','surface','success','warning','danger','info']);
const FITS=new Set(['contain','cover']);
const ALIGNS=new Set(['topLeft','topRight','center','bottomLeft','bottomRight']);
const ASSET_CATEGORIES=new Set(['service','banner','story','icon','decorative','brand']);
const HEX=/^#[0-9A-Fa-f]{6}$/;
const ID=/^[A-Za-z0-9_-]{1,80}$/;
const DEFAULT_CONFIG={"schemaVersion":1,"theme":{"tokens":{"primary":"#713BFF","accent":"#C8FC06","background":"#F7F7FC","surface":"#FFFFFF","textPrimary":"#111628","textSecondary":"#71798E","success":"#23C976","warning":"#FF9D47","danger":"#FF5E76"},"cardRadius":18,"buttonRadius":15,"shadowLevel":1},"brand":{"lightLogo":"","darkLogo":"","headerLogo":""},"home":{"components":[{"id":"home_weather","type":"weather_card","enabled":true,"sortOrder":10,"audience":"all","config":{}},{"id":"home_vehicle_security","type":"vehicle_security","enabled":true,"sortOrder":20,"audience":"all","config":{}},{"id":"home_story","type":"story_carousel","enabled":true,"sortOrder":30,"audience":"all","config":{}},{"id":"home_quick_actions","type":"quick_actions","enabled":true,"sortOrder":40,"audience":"all","config":{}},{"id":"home_monthly","type":"monthly_summary","enabled":true,"sortOrder":50,"audience":"all","config":{}},{"id":"home_services","type":"services_grid","enabled":true,"sortOrder":60,"audience":"all","config":{}},{"id":"home_promo","type":"promo_banner","enabled":false,"sortOrder":70,"audience":"all","config":{}},{"id":"home_recent","type":"recent_notifications","enabled":true,"sortOrder":80,"audience":"all","config":{}}]},"services":[{"id":"towing","title":"Çekici","subtitle":"Çekici çağır ve canlı takip et.","icon":"tow_truck","iconToken":"warning","backgroundToken":"surface","imageUrl":"","imageScale":1,"imageX":0,"imageY":0,"imageOpacity":0.15,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_TOWING","enabled":true,"sortOrder":10,"audience":"all","testOnly":true},{"id":"roadside","title":"Yol Yardım","subtitle":"Akü, lastik, yakıt ve yerinde destek.","icon":"sos","iconToken":"danger","backgroundToken":"surface","imageUrl":"","imageScale":1,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_ROADSIDE","enabled":true,"sortOrder":20,"audience":"all","testOnly":true},{"id":"valet","title":"Vale","subtitle":"Aracınızı güvenle teslim edin.","icon":"valet","iconToken":"primary","backgroundToken":"surface","imageUrl":"","imageScale":1,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_VALE","enabled":true,"sortOrder":30,"audience":"all","testOnly":true},{"id":"offers","title":"Fırsatlar","subtitle":"Size özel kampanya ve ayrıcalıklar.","icon":"offer","iconToken":"success","backgroundToken":"surface","imageUrl":"","imageScale":1,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_OPPORTUNITIES","enabled":true,"sortOrder":40,"audience":"all","testOnly":true}],"quickActions":[{"id":"parking","title":"Park Yerim","icon":"parking","iconToken":"success","backgroundToken":"surface","action":"OPEN_PARKING","enabled":true,"sortOrder":10,"audience":"all"},{"id":"maintenance","title":"Bakım Geçmişi","icon":"maintenance","iconToken":"primary","backgroundToken":"surface","action":"OPEN_MAINTENANCE","enabled":true,"sortOrder":20,"audience":"all"},{"id":"drivers","title":"Sürücüler","icon":"drivers","iconToken":"primary","backgroundToken":"surface","action":"OPEN_DRIVERS","enabled":true,"sortOrder":30,"audience":"all"},{"id":"inspection","title":"Muayene","icon":"inspection","iconToken":"info","backgroundToken":"surface","action":"OPEN_INSPECTION","enabled":true,"sortOrder":40,"audience":"all"}],"banners":[]};

function clean(v,max=300){return String(v==null?'':v).trim().slice(0,max);}
function asNum(v,fallback=0){const n=Number(v);return Number.isFinite(n)?n:fallback;}
function clamp(v,min,max){return Math.max(min,Math.min(max,asNum(v,min)));}
function int(v,fallback=0){return Math.trunc(asNum(v,fallback));}
function bool(v,fallback=false){return v===undefined?fallback:v===true;}
function safeHttpUrl(value,{assetOnly=false}={}){
  const s=clean(value,1600);
  if(!s)return '';
  try{
    const u=new URL(s);
    if(!['http:','https:'].includes(u.protocol))return null;
    if(assetOnly&&!u.pathname.includes('/uploads/app-assets/'))return null;
    return u.toString();
  }catch(_){return null;}
}
function action(actionValue,targetValue){
  const type=clean(actionValue,40).toUpperCase()||'NONE';
  const target=clean(targetValue,1200);
  if(!ACTIONS.has(type))return null;
  if(type==='EXTERNAL_URL'){
    const u=safeHttpUrl(target);
    if(!u)return null;
    return {type,target:u};
  }
  if(target)return null;
  return {type,target:''};
}
function semver(value){
  const p=String(value||'0.0.0').split(/[+-]/)[0].split('.').slice(0,3).map(x=>Number.parseInt(x,10)||0);
  while(p.length<3)p.push(0);
  return p;
}
function compareVersion(a,b){
  const x=semver(a),y=semver(b);
  for(let i=0;i<3;i++){if(x[i]<y[i])return -1;if(x[i]>y[i])return 1;}
  return 0;
}
function compatible(row,appVersion){
  const min=clean(row.minAppVersion,30),max=clean(row.maxAppVersion,30);
  if(min&&compareVersion(appVersion,min)<0)return false;
  if(max&&compareVersion(appVersion,max)>0)return false;
  return true;
}
function activeNow(row,now=new Date()){
  if(row.enabled===false)return false;
  const starts=row.startsAt?new Date(row.startsAt):null;
  const ends=row.endsAt?new Date(row.endsAt):null;
  if(starts&&Number.isFinite(starts.getTime())&&starts>now)return false;
  if(ends&&Number.isFinite(ends.getTime())&&ends<=now)return false;
  return true;
}
function audienceOk(row,ctx){
  const a=clean(row.audience||'all',30);
  if(a==='all')return true;
  if(a==='pro')return ctx.premium;
  if(a==='non_pro')return !ctx.premium;
  if(a==='qr_active')return ctx.qrActive;
  if(a==='qr_inactive')return !ctx.qrActive;
  return false;
}
function targetOk(row,ctx){
  const city=clean(row.targetCity,100),district=clean(row.targetDistrict,100);
  if(city&&(!ctx.city||city.toLowerCase()!==ctx.city.toLowerCase()))return false;
  if(district&&(!ctx.district||district.toLowerCase()!==ctx.district.toLowerCase()))return false;
  return true;
}
function sanitizeSchedule(raw,out){
  const starts=clean(raw.startsAt,60),ends=clean(raw.endsAt,60);
  if(starts&&Number.isNaN(Date.parse(starts)))throw new Error('INVALID_STARTS_AT');
  if(ends&&Number.isNaN(Date.parse(ends)))throw new Error('INVALID_ENDS_AT');
  if(starts&&ends&&Date.parse(ends)<=Date.parse(starts))throw new Error('INVALID_DATE_RANGE');
  if(starts)out.startsAt=new Date(starts).toISOString();
  if(ends)out.endsAt=new Date(ends).toISOString();
  const audience=clean(raw.audience||'all',30);
  if(!AUDIENCES.has(audience))throw new Error('INVALID_AUDIENCE');
  out.audience=audience;
  const city=clean(raw.targetCity,100),district=clean(raw.targetDistrict,100);
  if(district&&!city)throw new Error('CITY_REQUIRED_FOR_DISTRICT');
  if(city)out.targetCity=city;
  if(district)out.targetDistrict=district;
  const min=clean(raw.minAppVersion,30),max=clean(raw.maxAppVersion,30);
  if(min)out.minAppVersion=min;
  if(max)out.maxAppVersion=max;
  if(min&&max&&compareVersion(min,max)>0)throw new Error('INVALID_APP_VERSION_RANGE');
}
function iconKey(v){const x=clean(v,50);return x||'campaign';}
function token(v,fallback='primary'){const x=clean(v,30);return TOKENS.has(x)?x:fallback;}
function sanitizeItem(raw,kind){
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('INVALID_ITEM');
  const id=clean(raw.id,80);
  if(!ID.test(id))throw new Error('INVALID_ID');
  const out={id,enabled:raw.enabled!==false,sortOrder:int(raw.sortOrder,0)};
  sanitizeSchedule(raw,out);
  if(kind==='service'){
    out.title=clean(raw.title,80);out.subtitle=clean(raw.subtitle,180);
    if(!out.title)throw new Error('TITLE_REQUIRED');
    out.icon=iconKey(raw.icon);out.iconUrl=safeHttpUrl(raw.iconUrl,{assetOnly:true})||'';out.iconToken=token(raw.iconToken,'primary');out.backgroundToken=token(raw.backgroundToken,'surface');
    out.imageUrl=safeHttpUrl(raw.imageUrl)||'';
    out.imageScale=clamp(raw.imageScale,0,1.5);out.imageX=clamp(raw.imageX,-100,100);out.imageY=clamp(raw.imageY,-100,100);out.imageOpacity=clamp(raw.imageOpacity,0,1);
    out.fit=FITS.has(raw.fit)?raw.fit:'contain';out.alignment=ALIGNS.has(raw.alignment)?raw.alignment:'bottomRight';
    out.badgeText=clean(raw.badgeText,40);out.badgeToken=token(raw.badgeToken,'primary');
    const a=action(raw.action,raw.actionTarget);if(!a)throw new Error('INVALID_ACTION');out.action=a.type;if(a.target)out.actionTarget=a.target;
    out.testOnly=raw.testOnly===true;
  }else if(kind==='quick'){
    out.title=clean(raw.title,60);if(!out.title)throw new Error('TITLE_REQUIRED');
    out.icon=iconKey(raw.icon);out.iconToken=token(raw.iconToken,'primary');out.backgroundToken=token(raw.backgroundToken,'surface');
    const a=action(raw.action,raw.actionTarget);if(!a)throw new Error('INVALID_ACTION');out.action=a.type;if(a.target)out.actionTarget=a.target;
  }else if(kind==='banner'){
    out.title=clean(raw.title,100);out.subtitle=clean(raw.subtitle,220);if(!out.title)throw new Error('TITLE_REQUIRED');
    out.imageUrl=safeHttpUrl(raw.imageUrl)||'';out.backgroundToken=token(raw.backgroundToken,'primary');
    out.badgeText=clean(raw.badgeText,40);out.badgeToken=token(raw.badgeToken,'accent');
    out.ctaText=clean(raw.ctaText,60);
    const a=action(raw.action,raw.actionTarget);if(!a)throw new Error('INVALID_ACTION');out.action=a.type;if(a.target)out.actionTarget=a.target;
  }
  return out;
}
function sanitizeComponent(raw){
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new Error('INVALID_COMPONENT');
  const id=clean(raw.id,80),type=clean(raw.type,60);
  if(!ID.test(id)||!COMPONENT_TYPES.has(type))throw new Error('INVALID_COMPONENT_TYPE');
  const out={id,type,enabled:raw.enabled!==false,sortOrder:int(raw.sortOrder,0),config:{}};
  sanitizeSchedule(raw,out);
  const cfg=raw.config&&typeof raw.config==='object'&&!Array.isArray(raw.config)?raw.config:{};
  if(type==='spacer')out.config={height:clamp(cfg.height,0,64)};
  else if(type==='image_banner'||type==='text_banner'){
    out.config={
      title:clean(cfg.title,100),subtitle:clean(cfg.subtitle,220),
      imageUrl:safeHttpUrl(cfg.imageUrl)||'',backgroundToken:token(cfg.backgroundToken,'primary'),
      badgeText:clean(cfg.badgeText,40),badgeToken:token(cfg.badgeToken,'accent'),ctaText:clean(cfg.ctaText,60),
    };
    const a=action(cfg.action,cfg.actionTarget);if(!a)throw new Error('INVALID_ACTION');out.config.action=a.type;if(a.target)out.config.actionTarget=a.target;
  }
  return out;
}
function validateConfig(input){
  if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('INVALID_CONFIG');
  if(Number(input.schemaVersion)!==SCHEMA_VERSION)throw new Error('UNSUPPORTED_SCHEMA_VERSION');
  const rawTheme=input.theme&&typeof input.theme==='object'?input.theme:{};
  const rawTokens=rawTheme.tokens&&typeof rawTheme.tokens==='object'?rawTheme.tokens:{};
  const defaults=DEFAULT_CONFIG.theme.tokens;
  const themeTokens={};
  for(const key of ['primary','accent','background','surface','textPrimary','textSecondary','success','warning','danger']){
    const value=clean(rawTokens[key]??defaults[key],20);
    if(!HEX.test(value))throw new Error('INVALID_THEME_COLOR_'+key);
    themeTokens[key]=value.toUpperCase();
  }
  const theme={
    tokens:themeTokens,
    cardRadius:clamp(rawTheme.cardRadius??18,10,28),
    buttonRadius:clamp(rawTheme.buttonRadius??15,8,26),
    shadowLevel:int(clamp(rawTheme.shadowLevel??1,0,3)),
  };
  const rawBrand=input.brand&&typeof input.brand==='object'?input.brand:{};
  const brand={};
  for(const k of ['lightLogo','darkLogo','headerLogo']){
    const value=clean(rawBrand[k],1600);
    if(value){
      const safe=safeHttpUrl(value);if(!safe)throw new Error('INVALID_BRAND_URL');brand[k]=safe;
    }else brand[k]='';
  }
  const home=input.home&&typeof input.home==='object'?input.home:{};
  const components=Array.isArray(home.components)?home.components:[];
  if(components.length>30)throw new Error('TOO_MANY_COMPONENTS');
  const seen=new Set(),safeComponents=components.map(x=>sanitizeComponent(x));
  for(const c of safeComponents){if(seen.has(c.id))throw new Error('DUPLICATE_COMPONENT_ID');seen.add(c.id);}
  const services=Array.isArray(input.services)?input.services:[];
  const quick=Array.isArray(input.quickActions)?input.quickActions:[];
  const banners=Array.isArray(input.banners)?input.banners:[];
  if(services.length>30||quick.length>30||banners.length>30)throw new Error('TOO_MANY_ITEMS');
  return {
    schemaVersion:SCHEMA_VERSION,theme,brand,
    home:{components:safeComponents},
    services:services.map(x=>sanitizeItem(x,'service')),
    quickActions:quick.map(x=>sanitizeItem(x,'quick')),
    banners:banners.map(x=>sanitizeItem(x,'banner')),
  };
}
function filterConfig(config,ctx){
  const appVersion=ctx.appVersion||'0.0.0';
  const keep=row=>activeNow(row)&&audienceOk(row,ctx)&&targetOk(row,ctx)&&compatible(row,appVersion);
  return {
    schemaVersion:config.schemaVersion,
    theme:config.theme,
    brand:config.brand,
    home:{components:(config.home?.components||[]).filter(keep).sort((a,b)=>a.sortOrder-b.sortOrder)},
    services:(config.services||[]).filter(keep).sort((a,b)=>a.sortOrder-b.sortOrder),
    quickActions:(config.quickActions||[]).filter(keep).sort((a,b)=>a.sortOrder-b.sortOrder),
    banners:(config.banners||[]).filter(keep).sort((a,b)=>a.sortOrder-b.sortOrder),
  };
}
async function ownerContext(pool,req){
  const id=authenticatedOwnerId(req);
  const ctx={premium:false,qrActive:false,city:clean(req.query?.city,100),district:clean(req.query?.district,100),appVersion:clean(req.query?.appVersion,30)||'0.0.0'};
  if(!id)return ctx;
  const r=await pool.query(
    "SELECT (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS premium,"+
    " EXISTS(SELECT 1 FROM vehicles v JOIN qr_tags q ON q.vehicle_id=v.id AND q.status='active' WHERE v.owner_id::text=u.id::text) AS qr_active "+
    "FROM users u WHERE u.id::text=$1 LIMIT 1",[id]
  );
  if(r.rowCount){ctx.premium=r.rows[0].premium===true;ctx.qrActive=r.rows[0].qr_active===true;}
  return ctx;
}
function versionPayload(row){
  return row?{
    id:String(row.id),version:Number(row.version),schemaVersion:Number(row.schema_version),status:String(row.status),
    config:row.config_json,sourceVersionId:row.source_version_id?String(row.source_version_id):null,
    createdAt:row.created_at,updatedAt:row.updated_at,publishedAt:row.published_at,
  }:null;
}
async function nextVersion(db){
  const r=await db.query('SELECT COALESCE(MAX(version),0)+1 AS n FROM app_layout_versions');
  return Number(r.rows[0].n);
}
function assetPayload(row){
  return {
    id:String(row.id),name:String(row.name),fileName:String(row.file_name),url:String(row.url),mimeType:String(row.mime_type),
    width:row.width==null?null:Number(row.width),height:row.height==null?null:Number(row.height),fileSize:Number(row.file_size),
    category:String(row.category),createdAt:row.created_at,usageCount:Number(row.usage_count||0),
  };
}

module.exports=function registerAppBuilderRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
  const assetDir=process.env.APP_ASSET_DIR||'/opt/heycar/uploads/app-assets';
  try{fs.mkdirSync(assetDir,{recursive:true});}catch(e){console.error('app asset dir',e);}

  app.get('/uploads/app-assets/:name',(req,res)=>{
    const name=path.basename(String(req.params.name||''));
    if(!/^appasset-[a-f0-9-]+\.(jpg|jpeg|png|webp)$/i.test(name))return res.status(404).end();
    return res.sendFile(path.join(assetDir,name));
  });

  app.get('/api/app-config',async(req,res)=>{
    try{
      const q=await pool.query("SELECT * FROM app_layout_versions WHERE status='published' ORDER BY version DESC LIMIT 1");
      if(!q.rowCount)return res.status(503).json({error:'APP_CONFIG_NOT_PUBLISHED'});
      const row=q.rows[0],ctx=await ownerContext(pool,req),filtered=filterConfig(row.config_json,ctx);
      const etag='W/"app-config-v'+row.version+'-p'+(ctx.premium?1:0)+'-q'+(ctx.qrActive?1:0)+'-'+ctx.appVersion+'"';
      if(String(req.headers['if-none-match']||'')===etag)return res.status(304).end();
      res.set('ETag',etag);res.set('Cache-Control','private, max-age=60, stale-while-revalidate=300');
      return res.json({ok:true,schemaVersion:SCHEMA_VERSION,version:Number(row.version),config:filtered});
    }catch(e){console.error('app config',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/app-management',guard,async(_req,res)=>{
    try{
      const versions=await pool.query("SELECT * FROM app_layout_versions ORDER BY version DESC LIMIT 80");
      const live=versions.rows.find(x=>x.status==='published')||null;
      const draft=versions.rows.find(x=>x.status==='draft')||null;
      const assets=await pool.query(
        "SELECT a.*, (SELECT COUNT(*) FROM app_layout_versions v WHERE v.config_json::text LIKE '%'||a.url||'%')::int usage_count FROM app_assets a ORDER BY a.created_at DESC LIMIT 300"
      );
      return res.json({ok:true,live:versionPayload(live),draft:versionPayload(draft),versions:versions.rows.map(versionPayload),assets:assets.rows.map(assetPayload),allowed:{componentTypes:[...COMPONENT_TYPES],actions:[...ACTIONS],audiences:[...AUDIENCES],tokens:[...TOKENS]}});
    }catch(e){console.error('app management',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/admin/app-management/drafts',guard,async(req,res)=>{
    try{
      const existing=await pool.query("SELECT * FROM app_layout_versions WHERE status='draft' ORDER BY version DESC LIMIT 1");
      if(existing.rowCount)return res.status(409).json({error:'DRAFT_ALREADY_EXISTS',draft:versionPayload(existing.rows[0])});
      let source=null;
      const sourceId=clean(req.body?.sourceVersionId,80);
      if(sourceId){
        const s=await pool.query('SELECT * FROM app_layout_versions WHERE id::text=$1 LIMIT 1',[sourceId]);
        if(!s.rowCount)return res.status(404).json({error:'SOURCE_VERSION_NOT_FOUND'});
        source=s.rows[0];
      }else{
        const s=await pool.query("SELECT * FROM app_layout_versions WHERE status='published' ORDER BY version DESC LIMIT 1");
        source=s.rows[0]||null;
      }
      const config=validateConfig(source?.config_json||DEFAULT_CONFIG);
      const version=await nextVersion(pool);
      const q=await pool.query(
        "INSERT INTO app_layout_versions(version,schema_version,status,config_json,source_version_id,created_by) VALUES($1,$2,'draft',$3::jsonb,$4,$5) RETURNING *",
        [version,SCHEMA_VERSION,JSON.stringify(config),source?.id||null,req.admin?.id||null]
      );
      await writeAdminAudit(pool,req,{action:'app_config.draft_created',targetType:'app_layout_version',targetId:q.rows[0].id,targetLabel:'v'+version,metadata:{sourceVersion:source?.version||null}});
      return res.status(201).json({ok:true,draft:versionPayload(q.rows[0])});
    }catch(e){console.error('app config draft',e);return res.status(400).json({error:e.message||'INVALID_CONFIG'});}
  });

  app.patch('/api/admin/app-management/drafts/:id',guard,async(req,res)=>{
    try{
      const old=await pool.query("SELECT * FROM app_layout_versions WHERE id::text=$1 AND status='draft' LIMIT 1",[req.params.id]);
      if(!old.rowCount)return res.status(404).json({error:'DRAFT_NOT_FOUND'});
      const config=validateConfig(req.body?.config);
      const q=await pool.query("UPDATE app_layout_versions SET config_json=$2::jsonb,updated_at=NOW() WHERE id::text=$1 AND status='draft' RETURNING *",[req.params.id,JSON.stringify(config)]);
      await writeAdminAudit(pool,req,{action:'app_config.draft_updated',targetType:'app_layout_version',targetId:q.rows[0].id,targetLabel:'v'+q.rows[0].version});
      return res.json({ok:true,draft:versionPayload(q.rows[0])});
    }catch(e){console.error('app config update',e);return res.status(400).json({error:e.message||'INVALID_CONFIG'});}
  });

  app.post('/api/admin/app-management/drafts/:id/publish',guard,async(req,res)=>{
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      const q=await db.query("SELECT * FROM app_layout_versions WHERE id::text=$1 AND status='draft' FOR UPDATE",[req.params.id]);
      if(!q.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'DRAFT_NOT_FOUND'});}
      const config=validateConfig(q.rows[0].config_json);
      await db.query("UPDATE app_layout_versions SET status='archived',updated_at=NOW() WHERE status='published'");
      const published=await db.query(
        "UPDATE app_layout_versions SET status='published',config_json=$2::jsonb,published_by=$3,published_at=NOW(),updated_at=NOW() WHERE id::text=$1 RETURNING *",
        [req.params.id,JSON.stringify(config),req.admin?.id||null]
      );
      await db.query('COMMIT');
      await writeAdminAudit(pool,req,{action:'app_config.published',targetType:'app_layout_version',targetId:published.rows[0].id,targetLabel:'v'+published.rows[0].version});
      return res.json({ok:true,live:versionPayload(published.rows[0])});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('app config publish',e);return res.status(400).json({error:e.message||'PUBLISH_FAILED'});}finally{db.release();}
  });

  app.post('/api/admin/app-management/versions/:id/clone',guard,async(req,res)=>{
    try{
      const existing=await pool.query("SELECT 1 FROM app_layout_versions WHERE status='draft' LIMIT 1");
      if(existing.rowCount)return res.status(409).json({error:'DRAFT_ALREADY_EXISTS'});
      const source=await pool.query('SELECT * FROM app_layout_versions WHERE id::text=$1 LIMIT 1',[req.params.id]);
      if(!source.rowCount)return res.status(404).json({error:'VERSION_NOT_FOUND'});
      const config=validateConfig(source.rows[0].config_json),version=await nextVersion(pool);
      const q=await pool.query("INSERT INTO app_layout_versions(version,schema_version,status,config_json,source_version_id,created_by) VALUES($1,$2,'draft',$3::jsonb,$4,$5) RETURNING *",[version,SCHEMA_VERSION,JSON.stringify(config),source.rows[0].id,req.admin?.id||null]);
      await writeAdminAudit(pool,req,{action:'app_config.version_cloned',targetType:'app_layout_version',targetId:q.rows[0].id,targetLabel:'v'+version,metadata:{sourceVersion:source.rows[0].version}});
      return res.status(201).json({ok:true,draft:versionPayload(q.rows[0])});
    }catch(e){console.error('app config clone',e);return res.status(400).json({error:e.message||'CLONE_FAILED'});}
  });

  app.post('/api/admin/app-management/versions/:id/rollback',guard,async(req,res)=>{
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      const source=await db.query('SELECT * FROM app_layout_versions WHERE id::text=$1 LIMIT 1',[req.params.id]);
      if(!source.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'VERSION_NOT_FOUND'});}
      const config=validateConfig(source.rows[0].config_json);
      const n=await db.query('SELECT COALESCE(MAX(version),0)+1 AS n FROM app_layout_versions');
      const version=Number(n.rows[0].n);
      await db.query("UPDATE app_layout_versions SET status='archived',updated_at=NOW() WHERE status IN ('published','draft')");
      const q=await db.query(
        "INSERT INTO app_layout_versions(version,schema_version,status,config_json,source_version_id,created_by,published_by,published_at) VALUES($1,$2,'published',$3::jsonb,$4,$5,$5,NOW()) RETURNING *",
        [version,SCHEMA_VERSION,JSON.stringify(config),source.rows[0].id,req.admin?.id||null]
      );
      await db.query('COMMIT');
      await writeAdminAudit(pool,req,{action:'app_config.rolled_back',targetType:'app_layout_version',targetId:q.rows[0].id,targetLabel:'v'+version,metadata:{restoredFromVersion:source.rows[0].version}});
      return res.json({ok:true,live:versionPayload(q.rows[0])});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('app config rollback',e);return res.status(400).json({error:e.message||'ROLLBACK_FAILED'});}finally{db.release();}
  });

  app.get('/api/admin/app-management/assets',guard,async(req,res)=>{
    try{
      const q=await pool.query("SELECT a.*, (SELECT COUNT(*) FROM app_layout_versions v WHERE v.config_json::text LIKE '%'||a.url||'%')::int usage_count FROM app_assets a ORDER BY a.created_at DESC, a.id DESC");
      return res.json({ok:true,assets:q.rows.map(assetPayload)});
    }catch(e){console.error('app asset list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/admin/app-management/assets',guard,express.raw({type:'application/octet-stream',limit:'5mb'}),async(req,res)=>{
    try{
      const mime=clean(req.headers['x-file-type'],60).toLowerCase();
      const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':mime==='image/jpeg'||mime==='image/jpg'?'jpg':'';
      if(!ext)return res.status(400).json({error:'INVALID_IMAGE_TYPE'});
      const buf=Buffer.isBuffer(req.body)?req.body:Buffer.alloc(0);
      if(!buf.length||buf.length>5*1024*1024)return res.status(413).json({error:'IMAGE_TOO_LARGE'});
      const category=clean(req.headers['x-asset-category']||'decorative',30);
      if(!ASSET_CATEGORIES.has(category))return res.status(400).json({error:'INVALID_ASSET_CATEGORY'});
      const name=clean(req.headers['x-asset-name']||'Görsel',120)||'Görsel';
      const width=int(req.headers['x-image-width'],0)||null,height=int(req.headers['x-image-height'],0)||null;
      const fileName='appasset-'+crypto.randomUUID()+'.'+ext;
      fs.writeFileSync(path.join(assetDir,fileName),buf,{mode:0o644});
      const proto=String(req.headers['x-forwarded-proto']||req.protocol||'https').split(',')[0].trim();
      const host=req.get('host');
      const base=String(process.env.PUBLIC_API_BASE_URL||(host?proto+'://'+host:'https://heycar-api-185-165-46-213.nip.io')).replace(/\/$/,'');
      const url=base+'/uploads/app-assets/'+fileName;
      const q=await pool.query("INSERT INTO app_assets(name,file_name,url,mime_type,width,height,file_size,category,created_by) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *",[name,fileName,url,mime,width,height,buf.length,category,req.admin?.id||null]);
      await writeAdminAudit(pool,req,{action:'app_asset.uploaded',targetType:'app_asset',targetId:q.rows[0].id,targetLabel:name,metadata:{category,fileSize:buf.length}});
      return res.status(201).json({ok:true,asset:assetPayload(q.rows[0])});
    }catch(e){console.error('app asset upload',e);return res.status(500).json({error:'UPLOAD_FAILED'});}
  });

  app.delete('/api/admin/app-management/assets/:id',guard,async(req,res)=>{
    try{
      const q=await pool.query("SELECT a.*, (SELECT COUNT(*) FROM app_layout_versions v WHERE v.config_json::text LIKE '%'||a.url||'%')::int usage_count FROM app_assets a WHERE a.id::text=$1 LIMIT 1",[req.params.id]);
      if(!q.rowCount)return res.status(404).json({error:'ASSET_NOT_FOUND'});
      if(Number(q.rows[0].usage_count)>0)return res.status(409).json({error:'ASSET_IN_USE',usageCount:Number(q.rows[0].usage_count)});
      await pool.query('DELETE FROM app_assets WHERE id::text=$1',[req.params.id]);
      try{fs.unlinkSync(path.join(assetDir,q.rows[0].file_name));}catch(_){}
      await writeAdminAudit(pool,req,{action:'app_asset.deleted',targetType:'app_asset',targetId:q.rows[0].id,targetLabel:q.rows[0].name});
      return res.json({ok:true});
    }catch(e){console.error('app asset delete',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
