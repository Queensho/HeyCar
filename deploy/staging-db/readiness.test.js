'use strict';
const test=require('node:test'),assert=require('node:assert/strict');const {assess}=require('./readiness');
function evidence(){
 const sha='a'.repeat(64);
 return {files:{'001_example.sql':sha},audit:{database:'heycar_staging',candidate_schema_differences:[],
  tracking:[{filename:'001_example.sql',checksum_sha256:sha}],migrations:[{filename:'001_example.sql',sha256:sha}],
  recovery_diagnostics:{nulls:{display_name:0,password_hash:0,vehicle_owner:0},phones:{duplicate_groups:0,normalized_duplicate_groups:0,noncanonical:0}},
  http:Object.fromEntries(Object.entries({health:200,environment:200,services:200,business_auth:401,admin_auth:401,public_environment:200,public_services:200}).map(([k,status])=>[k,{status}])),blockers:[]},
  backup:{database:'heycar_staging',backup_complete:true,restore_verified:true,dump_sha256:sha,dump_bytes:1024,
   restore_mode:'private_local_cluster',restore_cluster_stopped:true,source_modified:false,source_row_data_modified:false,
   rehearsal:{success:true,account_data_unchanged:true,global_role_memberships_unchanged:true,database_acls_unchanged:true,public_schema_acl_unchanged:true,source_ddl_attempted:false,blocked:[],checks:['runtime_direct_ddl_denied','runtime_cannot_execute_phone_repair','runtime_cannot_execute_password_repair','fixed_null_free_ddl','one_time_capability_revoked'].map(name=>({name,ok:true})),independent_schema_repairs:require('./schema-repairs').operations.map(x=>({operation:x.name,status:'verified_on_restore'}))}}};
}
test('readiness can pass only with complete current schema, history, backup and isolation evidence',()=>{
 assert.equal(assess(evidence()).ready,true);
 for(const mutate of [e=>e.audit.tracking=[],e=>e.audit.migrations[0].sha256='b'.repeat(64),
  e=>e.audit.candidate_schema_differences.push({key:'users.password_hash'}),e=>e.backup.restore_verified=false,
  e=>e.backup.rehearsal.blocked.push({operation:'phone'}),e=>e.audit.recovery_diagnostics.phones.normalized_duplicate_groups=1,
  e=>e.audit.recovery_diagnostics.nulls.password_hash=1,e=>e.backup.source_modified=true,
  e=>e.backup.restore_cluster_stopped=false,e=>delete e.audit.candidate_schema_differences,
  e=>delete e.backup.rehearsal.public_schema_acl_unchanged,e=>e.audit.http.admin_auth.status=200,
  e=>e.audit.tracking.push({...e.audit.tracking[0]}),e=>e.files={},e=>e.backup.rehearsal.checks=[],
  e=>e.backup.rehearsal.independent_schema_repairs[0].status='blocked_no_record_changes']){
  const e=evidence();mutate(e);assert.equal(assess(e).ready,false);
 }
});
