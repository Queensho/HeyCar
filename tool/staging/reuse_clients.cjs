'use strict';
const fs=require('node:fs');
const base='https://api.github.com/repos/'+process.env.GITHUB_REPOSITORY;
const headers={Authorization:'Bearer '+process.env.GH_TOKEN,Accept:'application/vnd.github+json'};
async function get(path){const r=await fetch(base+path,{headers});if(!r.ok)throw Error('GitHub client cache query failed: '+r.status);return r.json();}
(async()=>{
 const runs=await get('/actions/workflows/isolated-staging.yml/runs?branch=feature/isolated-marketplace-staging-20261025&per_page=20');
 for(const run of runs.workflow_runs){
  if(String(run.id)===process.env.GITHUB_RUN_ID||run.head_sha===process.env.GITHUB_SHA)continue;
  const comparison=await get('/compare/'+run.head_sha+'...'+process.env.GITHUB_SHA);
  if(!['ahead','identical'].includes(comparison.status)||!comparison.files||comparison.files.length>=300)continue;
  if(comparison.files.some(f=>/^(lib\/|assets\/|android\/|pubspec|tool\/staging\/prepare_sources\.py)/.test(f.filename)))continue;
  const artifacts=await get('/actions/runs/'+run.id+'/artifacts');
  if(!['staging-business-panel-ssh-tunnel','cepqontag-staging-ssh-tunnel-apk'].every(name=>artifacts.artifacts.some(a=>a.name===name&&!a.expired)))continue;
  const file=await get('/contents/.github/workflows/isolated-staging.yml?ref='+run.head_sha);
  const workflow=Buffer.from(file.content,'base64').toString();
  if(!workflow.includes('--dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:18091 --dart-define=STAGING_SSH_TUNNEL=true'))continue;
  fs.appendFileSync(process.env.GITHUB_OUTPUT,'run_id='+run.id+'\n');
  console.log('Reuse client artifacts with unchanged lib/assets/pubspec/platform preparation from '+run.head_sha);
  return;
 }
 fs.appendFileSync(process.env.GITHUB_OUTPUT,'run_id=\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
