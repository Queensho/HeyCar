require('dotenv').config();

const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const {Pool}=require('pg');

function databaseConfig(){
  const url=String(process.env.DATABASE_URL||'').trim();
  if(url)return {connectionString:url};

  const host=String(process.env.DB_HOST||process.env.PGHOST||'').trim();
  const database=String(process.env.DB_NAME||process.env.PGDATABASE||'').trim();
  const user=String(process.env.DB_USER||process.env.PGUSER||'').trim();
  const password=String(process.env.DB_PASSWORD||process.env.PGPASSWORD||'');
  const port=Number(String(process.env.DB_PORT||process.env.PGPORT||'5432').trim());

  if(!host||!database||!user||!password)throw new Error('DATABASE_CONFIG_REQUIRED');
  if(!Number.isInteger(port)||port<1||port>65535)throw new Error('DATABASE_PORT_INVALID');
  return {host,port,database,user,password};
}

function checksum(text){
  return crypto.createHash('sha256').update(text).digest('hex');
}

function migrationFiles(){
  const dir=path.join(__dirname,'migrations');
  return fs.readdirSync(dir)
    .filter(name=>/^\d{3}_.+\.sql$/.test(name))
    .sort()
    .map(name=>({name,path:path.join(dir,name)}));
}

function baselineThroughArg(){
  const prefix='--baseline-through=';
  const arg=process.argv.find(x=>x.startsWith(prefix));
  return arg?arg.slice(prefix.length):'';
}

async function ensureTracking(client){
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.schema_migrations (
      filename TEXT PRIMARY KEY,
      checksum_sha256 CHAR(64) NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function baseline(client,files,through){
  if(process.env.MIGRATION_BASELINE_CONFIRM!=='YES'){
    throw new Error('MIGRATION_BASELINE_CONFIRM_REQUIRED');
  }
  const targetIndex=files.findIndex(x=>x.name===through);
  if(targetIndex<0)throw new Error('MIGRATION_BASELINE_TARGET_NOT_FOUND');

  const tracked=await client.query('SELECT COUNT(*)::int AS n FROM public.schema_migrations');
  if(Number(tracked.rows[0]?.n||0)!==0)throw new Error('MIGRATION_BASELINE_REQUIRES_EMPTY_TRACKING_TABLE');

  const core=await client.query(`
    SELECT
      to_regclass('public.users') IS NOT NULL AS users,
      to_regclass('public.vehicles') IS NOT NULL AS vehicles,
      to_regclass('public.qr_tags') IS NOT NULL AS qr_tags
  `);
  const row=core.rows[0]||{};
  if(!row.users||!row.vehicles||!row.qr_tags)throw new Error('MIGRATION_BASELINE_CORE_SCHEMA_MISSING');

  for(const file of files.slice(0,targetIndex+1)){
    const sql=fs.readFileSync(file.path,'utf8');
    await client.query(
      `INSERT INTO public.schema_migrations(filename,checksum_sha256)
       VALUES($1,$2)`,
      [file.name,checksum(sql)]
    );
    console.log(`BASELINED ${file.name}`);
  }
}

async function run(){
  const pool=new Pool(databaseConfig());
  const client=await pool.connect();
  const files=migrationFiles();
  const baselineTarget=baselineThroughArg();

  try{
    await client.query('SELECT pg_advisory_lock($1)',[73194016]);
    await ensureTracking(client);

    const trackingState=await client.query('SELECT COUNT(*)::int AS n FROM public.schema_migrations');
    const trackedCount=Number(trackingState.rows[0]?.n||0);
    if(!baselineTarget&&trackedCount===0){
      const existingCore=await client.query("SELECT to_regclass('public.users') IS NOT NULL AS users");
      if(existingCore.rows[0]?.users){
        throw new Error('EXISTING_SCHEMA_REQUIRES_EXPLICIT_BASELINE');
      }
    }

    if(baselineTarget){
      await baseline(client,files,baselineTarget);
    }

    const existing=await client.query(
      'SELECT filename,checksum_sha256 FROM public.schema_migrations ORDER BY filename'
    );
    const applied=new Map(existing.rows.map(r=>[String(r.filename),String(r.checksum_sha256)]));

    for(const file of files){
      const sql=fs.readFileSync(file.path,'utf8');
      const sha=checksum(sql);
      const known=applied.get(file.name);
      if(known){
        if(known!==sha)throw new Error(`MIGRATION_CHECKSUM_MISMATCH: ${file.name}`);
        continue;
      }

      console.log(`APPLY ${file.name}`);
      await client.query(sql);
      await client.query(
        `INSERT INTO public.schema_migrations(filename,checksum_sha256)
         VALUES($1,$2)`,
        [file.name,sha]
      );
      console.log(`APPLIED ${file.name}`);
    }

    const count=await client.query('SELECT COUNT(*)::int AS n FROM public.schema_migrations');
    if(Number(count.rows[0]?.n||0)!==files.length){
      throw new Error(`MIGRATION_TRACKING_COUNT_MISMATCH: expected ${files.length}, found ${count.rows[0]?.n||0}`);
    }
    console.log(`MIGRATIONS_OK count=${files.length}`);
  }finally{
    try{await client.query('SELECT pg_advisory_unlock($1)',[73194016]);}catch(_){}
    client.release();
    await pool.end();
  }
}

run().catch(err=>{
  console.error(err?.stack||err);
  process.exit(1);
});
