'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {readSchema,compareSchema}=require('../marketplace-schema');
test('schema gate detects type, constraint and invalid-index drift while preserving extra objects',()=>{
 const column={table_name:'marketplace_services',name:'id',type:'uuid',not_null:true};
 const constraint={table_name:'marketplace_appointments',name:'service_fk',validated:true,definition:'FOREIGN KEY (service_id) REFERENCES public.marketplace_services(id)'};
 const index={table_name:'marketplace_services',name:'active_idx',valid:true,ready:true,definition:'CREATE INDEX active_idx ON public.marketplace_services USING btree (active)'};
 const reference={columns:[column],constraints:[constraint],indexes:[index]};
 const actual={columns:[{...column,type:'text'},{table_name:'marketplace_services',name:'legacy'}],constraints:[],indexes:[{...index,valid:false}]};
 assert.deepEqual(compareSchema(reference,actual).map(x=>[x.section,x.status]),[['columns','different'],['constraints','missing'],['indexes','different']]);
 assert.deepEqual(compareSchema(reference,{...reference,columns:[{not_null:true,type:'uuid',name:'id',table_name:'marketplace_services'},{name:'legacy'}]}),[]);
 assert.throws(()=>compareSchema(reference,{columns:[]}),/SCHEMA_REFERENCE_INVALID/);
});
test('schema inspection uses a read-only snapshot and rolls back even on catalog query failure',async()=>{
 const calls=[];
 const client={query:async sql=>{calls.push(sql);if(sql.startsWith('SELECT'))throw Error('catalog unavailable');return {rows:[]};}};
 await assert.rejects(readSchema(client),/catalog unavailable/);
 assert.equal(calls[0],'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
 assert.equal(calls.at(-1),'ROLLBACK');
 assert.ok(calls.every(sql=>!/^(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE)\b/.test(sql)));
});
