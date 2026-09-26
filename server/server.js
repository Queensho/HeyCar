require('dotenv').config();

const express=require('express');
const {Pool}=require('pg');
const cors=require('cors');
const helmet=require('helmet');

const registerQrRoutes=require('./qr-routes');
const registerOnboardingRoutes=require('./onboarding-routes');
const registerOwnerAuthRoutes=require('./owner-auth-routes');
const registerBusinessRoutes=require('./business-routes');
const registerAdminManagementRoutes=require('./admin-management-routes');
const {registerAdminAuthRoutes}=require('./admin-auth-routes');
const {configureTrustedProxy}=require('./proxy-security');

const app=express();
configureTrustedProxy(app);
app.disable('x-powered-by');
app.use(helmet());

const defaultBrowserOrigins=[
  'https://queensho.github.io',
  'https://cepqar.com',
  'https://www.cepqar.com',
];
const configuredOrigins=String(process.env.CORS_ORIGINS||'')
  .split(',')
  .map(x=>x.trim())
  .filter(Boolean);
const allowedOrigins=configuredOrigins.length?configuredOrigins:defaultBrowserOrigins;

app.use(cors({
  origin(origin,callback){
    // Native/mobile clients normally send no Origin header; browser clients
    // must match the configured/default allow-list.
    if(!origin||allowedOrigins.includes(origin)){
      return callback(null,true);
    }
    return callback(new Error('CORS_ORIGIN_DENIED'));
  },
}));

app.use(express.json({limit:'1mb'}));

function databaseConfig(){
  const url=String(process.env.DATABASE_URL||'').trim();
  if(url)return {connectionString:url};

  const host=String(process.env.DB_HOST||process.env.PGHOST||'').trim();
  const database=String(process.env.DB_NAME||process.env.PGDATABASE||'').trim();
  const user=String(process.env.DB_USER||process.env.PGUSER||'').trim();
  const password=String(process.env.DB_PASSWORD||process.env.PGPASSWORD||'');
  const portRaw=String(process.env.DB_PORT||process.env.PGPORT||'5432').trim();
  const port=Number(portRaw);

  if(!host||!database||!user||!password){
    throw new Error('DATABASE_CONFIG_REQUIRED');
  }
  if(!Number.isInteger(port)||port<1||port>65535){
    throw new Error('DATABASE_PORT_INVALID');
  }

  return {host,port,database,user,password};
}

const pool=new Pool(databaseConfig());
app.locals.heycarPool=pool;

app.get('/health',async(_req,res)=>{
  try{
    await pool.query('SELECT 1');
    return res.json({ok:true,service:'heycar-api'});
  }catch(e){
    console.error('health',e);
    return res.status(500).json({ok:false,service:'heycar-api'});
  }
});

const adminAuth=registerAdminAuthRoutes(app,pool);

// QR routes are the canonical owner/public feature bundle. They internally
// register notifications, conversations, calls, drivers, DND, maintenance,
// reminders, parking and vehicle-management exactly once.
registerQrRoutes(app,pool);
registerOnboardingRoutes(app,pool);
registerOwnerAuthRoutes(app,pool);
registerBusinessRoutes(app,pool);
registerAdminManagementRoutes(app,pool,adminAuth);

app.use((err,_req,res,next)=>{
  if(err?.message==='CORS_ORIGIN_DENIED'){
    return res.status(403).json({error:'CORS_ORIGIN_DENIED'});
  }
  return next(err);
});

const port=Number(process.env.PORT||8090);
const server=app.listen(port,'127.0.0.1',4096,()=>{
  console.log(`HeyCar API running on 127.0.0.1:${port}`);
});

async function shutdown(signal){
  console.log(`${signal} received, shutting down HeyCar API`);
  server.close(async()=>{
    try{await pool.end();}catch(_){}
    process.exit(0);
  });
  setTimeout(()=>process.exit(1),10000).unref();
}

process.on('SIGTERM',()=>shutdown('SIGTERM'));
process.on('SIGINT',()=>shutdown('SIGINT'));

module.exports={app,pool};
