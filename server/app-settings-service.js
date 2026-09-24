const DEFAULTS={
  maintenance_mode:false,
  maintenance_title:'Kısa bir bakım yapıyoruz',
  maintenance_message:'Cepqar kısa süre içinde tekrar kullanılabilir olacak.',
  min_android_version:'1.0.0',
  min_ios_version:'1.0.0',
  force_update_android:false,
  force_update_ios:false,
  android_store_url:null,
  ios_store_url:null,
  default_platform_fee:20,
  qr_rate_limit_max:10,
  qr_rate_limit_window_seconds:60,
  premium_monthly_price_text:'₺49,99',
  premium_yearly_price_text:'₺499,99',
  features:{offers:true,messages:true,calls:true,parking:true,premium:true,business:true},
};

let cache=null;
let cacheAt=0;
const TTL=30000;

function normalize(row){
  const r={...DEFAULTS,...(row||{})};
  r.default_platform_fee=Number(r.default_platform_fee||0);
  r.qr_rate_limit_max=Math.max(1,Number(r.qr_rate_limit_max||10));
  r.qr_rate_limit_window_seconds=Math.max(1,Number(r.qr_rate_limit_window_seconds||60));
  r.features={...DEFAULTS.features,...(r.features&&typeof r.features==='object'?r.features:{})};
  return r;
}

async function getAppSettings(pool,{fresh=false}={}){
  if(!fresh&&cache&&Date.now()-cacheAt<TTL)return cache;
  try{
    const exists=await pool.query("SELECT to_regclass('public.app_settings') AS name");
    if(!exists.rows[0]?.name)return normalize(null);
    const q=await pool.query('SELECT * FROM app_settings WHERE id=1 LIMIT 1');
    cache=normalize(q.rows[0]||null);
    cacheAt=Date.now();
    return cache;
  }catch(e){
    if(cache)return cache;
    return normalize(null);
  }
}

function clearAppSettingsCache(){cache=null;cacheAt=0;}

function publicConfig(settings){
  const s=normalize(settings);
  return {
    maintenanceMode:Boolean(s.maintenance_mode),
    maintenanceTitle:String(s.maintenance_title||DEFAULTS.maintenance_title),
    maintenanceMessage:String(s.maintenance_message||DEFAULTS.maintenance_message),
    versions:{
      android:{
        minimum:String(s.min_android_version||'1.0.0'),
        forceUpdate:Boolean(s.force_update_android),
        storeUrl:s.android_store_url||null,
      },
      ios:{
        minimum:String(s.min_ios_version||'1.0.0'),
        forceUpdate:Boolean(s.force_update_ios),
        storeUrl:s.ios_store_url||null,
      },
    },
    premium:{
      monthlyPriceText:String(s.premium_monthly_price_text||''),
      yearlyPriceText:String(s.premium_yearly_price_text||''),
    },
    features:s.features,
    updatedAt:s.updated_at||null,
  };
}

module.exports={DEFAULTS,getAppSettings,clearAppSettingsCache,publicConfig};
