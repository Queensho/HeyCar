'use strict';
const fs=require('node:fs');
const base='https://api.github.com/repos/'+process.env.GITHUB_REPOSITORY;
const headers={Authorization:'Bearer '+process.env.GH_TOKEN,Accept:'application/vnd.github+json'};
async function get(path){const r=await fetch(base+path,{headers});if(!r.ok)throw Error('GitHub client cache query failed: '+r.status);return r.json();}
(async()=>{
 const publicBuild=process.argv[2]==='public';
 const workflowName=publicBuild?'staging-public-release.yml':'isolated-staging.yml';
 const expectedArtifacts=publicBuild?['staging-business-panel-direct-https','cepqontag-staging-direct-https-apk']:['staging-business-panel-ssh-tunnel','cepqontag-staging-ssh-tunnel-apk'];
 const currentFile=await get('/contents/.github/workflows/'+workflowName+'?ref='+process.env.GITHUB_SHA);
 const currentWorkflow=Buffer.from(currentFile.content,'base64').toString();
 const buildSettings=source=>source.split('\n').filter(line=>/STAGING_PUBLIC_API:|flutter build (web|apk)|prepare_sources.py/.test(line)).map(line=>line.trim()).join('\n');
 const runs=await get('/actions/workflows/'+workflowName+'/runs?branch=feature/isolated-marketplace-staging-20261025&per_page=20');
 for(const run of runs.workflow_runs){
  if(String(run.id)===process.env.GITHUB_RUN_ID||run.head_sha===process.env.GITHUB_SHA)continue;
  const comparison=await get('/compare/'+run.head_sha+'...'+process.env.GITHUB_SHA);
  if(!['ahead','identical'].includes(comparison.status)||!comparison.files||comparison.files.length>=300)continue;
  if(comparison.files.some(f=>/^(lib\/|assets\/|android\/|pubspec|tool\/staging\/prepare_sources\.py)/.test(f.filename)))continue;
  const artifacts=await get('/actions/runs/'+run.id+'/artifacts');
  if(!expectedArtifacts.every(name=>artifacts.artifacts.some(a=>a.name===name&&!a.expired)))continue;
  const file=await get('/contents/.github/workflows/'+workflowName+'?ref='+run.head_sha);
  const workflow=Buffer.from(file.content,'base64').toString();
  if(publicBuild){
   if(!workflow.includes('STAGING_PUBLIC_API: https://staging-api-185-165-46-213.nip.io')||!workflow.includes('prepare_sources.py --https-only')||buildSettings(workflow)!==buildSettings(currentWorkflow))continue;
  }else if(!workflow.includes('--dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:18091 --dart-define=STAGING_SSH_TUNNEL=true'))continue;
  fs.appendFileSync(process.env.GITHUB_OUTPUT,'run_id='+run.id+'\n');
  console.log('Reuse client artifacts with unchanged lib/assets/pubspec/platform preparation from '+run.head_sha);
  return;
 }
 fs.appendFileSync(process.env.GITHUB_OUTPUT,'run_id=\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
