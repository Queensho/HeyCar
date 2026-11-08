// Evaluate at send time, rather than caching the environment at module load.
// An explicit false flag must never override a staging environment marker.
function externalServicesDisabled(env=process.env){
  const normalized=value=>String(value||'').trim().toLowerCase();
  return normalized(env.NODE_ENV)==='staging'
    || normalized(env.APP_ENV)==='staging'
    || ['1','true','yes','on'].includes(normalized(env.STAGING_DISABLE_EXTERNAL_SERVICES));
}
function disabledDeliveryResult(){
  return {attempted:0,delivered:0,skipped:'EXTERNAL_SERVICES_DISABLED'};
}
module.exports={externalServicesDisabled,disabledDeliveryResult};
