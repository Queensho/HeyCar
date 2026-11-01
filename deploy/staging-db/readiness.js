'use strict';
function assess({audit,backup,files}){
 const blockers=[];
 if(audit?.database!=='heycar_staging'||backup?.database!=='heycar_staging')blockers.push('STAGING_IDENTITY_REQUIRED');
 if(!backup?.backup_complete||!backup?.restore_verified||!/^[0-9a-f]{64}$/.test(backup?.dump_sha256||'')||!(backup?.dump_bytes>0))blockers.push('VERIFIED_BACKUP_REQUIRED');
 if(backup?.restore_mode==='private_local_cluster'&&!backup.restore_cluster_stopped)blockers.push('RESTORE_CLUSTER_NOT_STOPPED');
 const r=backup?.rehearsal;
 if(!r?.success||!r.account_data_unchanged||!r.global_role_memberships_unchanged||!r.database_acls_unchanged||!r.public_schema_acl_unchanged)blockers.push('ISOLATED_REHEARSAL_REQUIRED');
 if(r?.blocked?.length)blockers.push('REPAIR_PRECONDITIONS_BLOCKED');
 const requiredChecks=['runtime_direct_ddl_denied','runtime_cannot_execute_phone_repair','runtime_cannot_execute_password_repair','fixed_null_free_ddl','one_time_capability_revoked'];
 if(!Array.isArray(r?.checks)||r.checks.length!==requiredChecks.length||new Set(r.checks.map(x=>x.name)).size!==requiredChecks.length||r.checks.some(x=>!requiredChecks.includes(x.name)||x.ok!==true))blockers.push('LEAST_PRIVILEGE_CHECKS_REQUIRED');
 const operations=require('./schema-repairs').operations.map(x=>x.name),repairs=r?.independent_schema_repairs;
 if(!Array.isArray(repairs)||repairs.length!==operations.length||new Set(repairs.map(x=>x.operation)).size!==operations.length||repairs.some(x=>!operations.includes(x.operation)||x.status!=='verified_on_restore'))blockers.push('INDEPENDENT_SCHEMA_REPAIRS_UNVERIFIED');
 if(backup?.source_modified!==false||backup?.source_row_data_modified!==false||r?.source_ddl_attempted!==false)blockers.push('SOURCE_CHANGE_REQUIRES_REVIEW');
 if(!Array.isArray(audit?.candidate_schema_differences)||audit.candidate_schema_differences.length)blockers.push('SCHEMA_RECONCILIATION_REQUIRED');
 const names=Object.keys(files||{}),tracking=audit?.tracking,deployed=audit?.migrations;
 const valid=(rows,field)=>Array.isArray(rows)&&rows.length===names.length&&new Set(rows.map(x=>x.filename)).size===rows.length&&rows.every(x=>files[x.filename]===String(x[field]||'').trim());
 if(!names.length||names.some(n=>!/^[0-9a-f]{64}$/.test(files[n])))blockers.push('CANDIDATE_MANIFEST_REQUIRED');
 if(!names.length||!valid(tracking,'checksum_sha256'))blockers.push('VERIFIED_PER_FILE_HISTORY_REQUIRED');
 if(!names.length||!valid(deployed,'sha256'))blockers.push('SOURCE_FILE_RECONCILIATION_REQUIRED');
 const d=audit?.recovery_diagnostics;
 if(!d||['display_name','password_hash','vehicle_owner'].some(k=>d.nulls?.[k]!==0))blockers.push('NULLABILITY_REVIEW_REQUIRED');
 if(!d||['duplicate_groups','normalized_duplicate_groups','noncanonical'].some(k=>d.phones?.[k]!==0))blockers.push('PHONE_ACCOUNT_REVIEW_REQUIRED');
 const status={health:200,environment:200,services:200,business_auth:401,admin_auth:401,public_environment:200,public_services:200};
 if(Object.entries(status).some(([key,value])=>audit?.http?.[key]?.status!==value))blockers.push('STAGING_HTTP_CHECKS_REQUIRED');
 for(const reason of audit?.blockers||[]){
  if(reason==='DURABLE_BACKUP_AND_RESTORE_NOT_VERIFIED'&&backup?.restore_verified)continue;
  blockers.push(reason);
 }
 return {ready:blockers.length===0,blockers:[...new Set(blockers)]};
}
module.exports={assess};
if(require.main===module){
 try{
  const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
  // Require the post-rehearsal audit; never silently substitute a stale report.
  const audit=JSON.parse(fs.readFileSync('staging-readiness-after-recovery.json','utf8'));
  const backup=JSON.parse(fs.readFileSync('staging-backup-verification.json','utf8'));
  const files={};for(const name of fs.readdirSync('server/migrations').filter(n=>n.endsWith('.sql')))
   files[name]=crypto.createHash('sha256').update(fs.readFileSync(path.join('server/migrations',name))).digest('hex');
  const report=assess({audit,backup,files});console.log('STAGING_READINESS_RESULT '+JSON.stringify(report));process.exitCode=report.ready?0:1;
 }catch(_){console.log('STAGING_READINESS_RESULT '+JSON.stringify({ready:false,blockers:['CURRENT_EVIDENCE_UNAVAILABLE']}));process.exitCode=1;}
}
