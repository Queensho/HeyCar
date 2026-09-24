const express=require('express');
const {getAppSettings,clearAppSettingsCache,publicConfig}=require('./app-settings-service');
const {writeAdminAudit}=require('./admin-audit');

function clean(v,max=500){
  if(v===null||v===undefined)return null;
  return String(v).trim().slice(0,max);
}
function validVersion(v){return /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(String(v||''));}
function bool(v){return v===true||v==='true';}
function actor(req){
  return clean(req.headers?.['x-admin-email']||req.headers?.['x-admin-name']||req.headers?.['x-admin-id']||'admin',240);
}
function formatTry(value){
  const n=Number(value);
  if(!Number.isFinite(n))return '';
  return '₺'+n.toFixed(2).replace('.',',');
}

module.exports=function registerAppSettingsRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  app.get('/api/app/config',async(_req,res)=>{
    try{
      const s=await getAppSettings(pool);
      res.set('Cache-Control','no-store');
      return res.json({ok:true,config:publicConfig(s)});
    }catch(e){
      console.error('public app config',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/admin/manage/app-settings',guard,async(_req,res)=>{
    try{
      const s=await getAppSettings(pool,{fresh:true});
      return res.json({ok:true,settings:s});
    }catch(e){
      console.error('admin app settings get',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/admin/manage/app-settings',guard,express.json(),async(req,res)=>{
    const b=req.body||{};
    const androidVersion=clean(b.minAndroidVersion,40);
    const iosVersion=clean(b.minIosVersion,40);
    if(androidVersion!==null&&!validVersion(androidVersion))return res.status(400).json({error:'INVALID_ANDROID_VERSION'});
    if(iosVersion!==null&&!validVersion(iosVersion))return res.status(400).json({error:'INVALID_IOS_VERSION'});

    const fee=b.defaultPlatformFee===undefined?null:Number(b.defaultPlatformFee);
    const premiumMonthly=b.premiumMonthlyPrice===undefined?null:Number(b.premiumMonthlyPrice);
    const premiumYearly=b.premiumYearlyPrice===undefined?null:Number(b.premiumYearlyPrice);
    const qrMax=b.qrRateLimitMax===undefined?null:Number(b.qrRateLimitMax);
    const qrWindow=b.qrRateLimitWindowSeconds===undefined?null:Number(b.qrRateLimitWindowSeconds);
    if(fee!==null&&(!Number.isFinite(fee)||fee<0||fee>100000))return res.status(400).json({error:'INVALID_PLATFORM_FEE'});
    if(premiumMonthly!==null&&(!Number.isFinite(premiumMonthly)||premiumMonthly<0||premiumMonthly>100000))return res.status(400).json({error:'INVALID_PREMIUM_MONTHLY_PRICE'});
    if(premiumYearly!==null&&(!Number.isFinite(premiumYearly)||premiumYearly<0||premiumYearly>1000000))return res.status(400).json({error:'INVALID_PREMIUM_YEARLY_PRICE'});
    if(qrMax!==null&&(!Number.isInteger(qrMax)||qrMax<1||qrMax>10000))return res.status(400).json({error:'INVALID_QR_RATE_MAX'});
    if(qrWindow!==null&&(!Number.isInteger(qrWindow)||qrWindow<1||qrWindow>86400))return res.status(400).json({error:'INVALID_QR_RATE_WINDOW'});

    const features=b.features&&typeof b.features==='object'&&!Array.isArray(b.features)
      ? Object.fromEntries(Object.entries(b.features).map(([k,v])=>[String(k).slice(0,80),Boolean(v)]))
      : null;

    try{
      const before=await getAppSettings(pool,{fresh:true});
      const q=await pool.query(
        `UPDATE app_settings SET
          maintenance_mode=COALESCE($1,maintenance_mode),
          maintenance_title=COALESCE($2,maintenance_title),
          maintenance_message=COALESCE($3,maintenance_message),
          min_android_version=COALESCE($4,min_android_version),
          min_ios_version=COALESCE($5,min_ios_version),
          force_update_android=COALESCE($6,force_update_android),
          force_update_ios=COALESCE($7,force_update_ios),
          android_store_url=CASE WHEN $8::boolean THEN $9 ELSE android_store_url END,
          ios_store_url=CASE WHEN $10::boolean THEN $11 ELSE ios_store_url END,
          default_platform_fee=COALESCE($12,default_platform_fee),
          qr_rate_limit_max=COALESCE($13,qr_rate_limit_max),
          qr_rate_limit_window_seconds=COALESCE($14,qr_rate_limit_window_seconds),
          premium_monthly_price=COALESCE($15,premium_monthly_price),
          premium_yearly_price=COALESCE($16,premium_yearly_price),
          premium_currency=COALESCE($17,premium_currency),
          premium_monthly_price_text=COALESCE($18,premium_monthly_price_text),
          premium_yearly_price_text=COALESCE($19,premium_yearly_price_text),
          features=COALESCE($20::jsonb,features),
          updated_at=NOW(),
          updated_by=$21
        WHERE id=1
        RETURNING *`,
        [
          typeof b.maintenanceMode==='boolean'?b.maintenanceMode:null,
          clean(b.maintenanceTitle,160),
          clean(b.maintenanceMessage,1000),
          androidVersion,
          iosVersion,
          typeof b.forceUpdateAndroid==='boolean'?b.forceUpdateAndroid:null,
          typeof b.forceUpdateIos==='boolean'?b.forceUpdateIos:null,
          Object.prototype.hasOwnProperty.call(b,'androidStoreUrl'),
          clean(b.androidStoreUrl,1000),
          Object.prototype.hasOwnProperty.call(b,'iosStoreUrl'),
          clean(b.iosStoreUrl,1000),
          fee,
          qrMax,
          qrWindow,
          premiumMonthly,
          premiumYearly,
          clean(b.premiumCurrency,12),
          premiumMonthly!==null?formatTry(premiumMonthly):clean(b.premiumMonthlyPriceText,120),
          premiumYearly!==null?formatTry(premiumYearly):clean(b.premiumYearlyPriceText,120),
          features?JSON.stringify(features):null,
          actor(req),
        ]
      );
      clearAppSettingsCache();
      const after=q.rows[0];
      await writeAdminAudit(pool,req,{
        action:'settings.updated',
        targetType:'app_settings',
        targetId:'1',
        targetLabel:'Uygulama Ayarları',
        before:{
          maintenance_mode:before.maintenance_mode,
          min_android_version:before.min_android_version,
          min_ios_version:before.min_ios_version,
          force_update_android:before.force_update_android,
          force_update_ios:before.force_update_ios,
          default_platform_fee:before.default_platform_fee,
          premium_monthly_price:before.premium_monthly_price,
          premium_yearly_price:before.premium_yearly_price,
          premium_currency:before.premium_currency,
          qr_rate_limit_max:before.qr_rate_limit_max,
          qr_rate_limit_window_seconds:before.qr_rate_limit_window_seconds,
          features:before.features,
        },
        after:{
          maintenance_mode:after.maintenance_mode,
          min_android_version:after.min_android_version,
          min_ios_version:after.min_ios_version,
          force_update_android:after.force_update_android,
          force_update_ios:after.force_update_ios,
          default_platform_fee:after.default_platform_fee,
          premium_monthly_price:after.premium_monthly_price,
          premium_yearly_price:after.premium_yearly_price,
          premium_currency:after.premium_currency,
          qr_rate_limit_max:after.qr_rate_limit_max,
          qr_rate_limit_window_seconds:after.qr_rate_limit_window_seconds,
          features:after.features,
        },
      });
      return res.json({ok:true,settings:after});
    }catch(e){
      console.error('admin app settings patch',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};
