'use strict';
function validateStagingEnvironment(env=process.env){
 if(env.APP_ENV!=='staging')return;
 let database=String(env.DB_NAME||env.PGDATABASE||'');
 if(env.DATABASE_URL){try{database=decodeURIComponent(new URL(env.DATABASE_URL).pathname).slice(1);}catch(_){throw Error('STAGING_ISOLATION_REQUIRED');}}
 if(database!=='heycar_staging'||String(env.PORT)!=='8091'||env.STAGING_DISABLE_EXTERNAL_SERVICES!=='1')throw Error('STAGING_ISOLATION_REQUIRED');
}
function registerStagingIdentity(app,pool){
 if(process.env.APP_ENV!=='staging')return;
 app.get('/api/environment',async(_req,res)=>{
  try{
   const q=await pool.query('SELECT current_database() AS database');
   if(q.rows[0]?.database!=='heycar_staging')return res.status(503).json({error:'STAGING_DATABASE_MISMATCH'});
   return res.set('Cache-Control','no-store').json({environment:'staging',database:'heycar_staging',port:8091,externalServicesDisabled:process.env.STAGING_DISABLE_EXTERNAL_SERVICES==='1'});
  }catch(_){return res.status(503).json({error:'STAGING_UNAVAILABLE'});}
 });
}
module.exports={validateStagingEnvironment,registerStagingIdentity};
