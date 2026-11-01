'use strict';
const tables=['marketplace_services','marketplace_appointments','marketplace_reviews','marketplace_service_images',
 'business_accounts','business_sessions','businesses','users','vehicles','owner_auth_sessions','owner_privacy_settings'];
async function readSchema(client,selectedTables=tables){
 await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
 try{
  await client.query('SET LOCAL search_path=pg_catalog');
  const schema={};
  schema.columns=(await client.query(`SELECT c.relname AS table_name,a.attname AS name,
   format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS not_null,
   pg_get_expr(d.adbin,d.adrelid) AS default_expression,a.attidentity AS identity,a.attgenerated AS generated
   FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
   LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
   WHERE n.nspname='public' AND c.relkind IN ('r','p') AND ($1::text[] IS NULL OR c.relname=ANY($1::text[])) AND a.attnum>0 AND NOT a.attisdropped
   ORDER BY c.relname,a.attname`,[selectedTables])).rows;
  schema.constraints=(await client.query(`SELECT c.relname AS table_name,k.conname AS name,k.convalidated AS validated,
   pg_get_constraintdef(k.oid,true) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
   JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND ($1::text[] IS NULL OR c.relname=ANY($1::text[]))
   ORDER BY c.relname,k.conname`,[selectedTables])).rows;
  schema.indexes=(await client.query(`SELECT t.relname AS table_name,c.relname AS name,i.indisvalid AS valid,i.indisready AS ready,
   pg_get_indexdef(i.indexrelid) AS definition FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
   JOIN pg_class t ON t.oid=i.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace
   WHERE n.nspname='public' AND ($1::text[] IS NULL OR t.relname=ANY($1::text[])) ORDER BY t.relname,c.relname`,[selectedTables])).rows;
  return schema;
 }finally{await client.query('ROLLBACK');}
}
function compareSchema(expected,actual){
 const differences=[];
 for(const section of ['columns','constraints','indexes']){
  if(!Array.isArray(expected[section])||!Array.isArray(actual[section]))throw Error('SCHEMA_REFERENCE_INVALID');
  const found=new Map(actual[section].map(row=>[row.table_name+'.'+row.name,row]));
  for(const row of expected[section]){
   const key=row.table_name+'.'+row.name,match=found.get(key);
   if(!match)differences.push({section,key,status:'missing',expected:row});
   else if(Object.keys(row).some(field=>row[field]!==match[field]))differences.push({section,key,status:'different',expected:row,actual:match});
  }
 }
 // Additional deployed objects are retained, never translated into DROP operations.
 return differences;
}
module.exports={readSchema,compareSchema};
if(require.main===module){
 const {Pool}=require('pg');const {databaseConfig}=require('./migrate');
 (async()=>{const p=new Pool(databaseConfig());let c;try{
  c=await p.connect();if((await c.query('SELECT current_database() AS db')).rows[0].db!=='heycar_reference_test')throw Error('REFERENCE_DB_REQUIRED');
  console.log(JSON.stringify(await readSchema(c,process.env.SCHEMA_AUDIT_ALL==='1'?null:tables)));
 }finally{if(c)c.release();await p.end();}})().catch(()=>{console.error('REFERENCE_SCHEMA_EXPORT_FAILED');process.exitCode=1;});
}
