'use strict';
const fs=require('node:fs');
const base='https://api.github.com/repos/'+process.env.GITHUB_REPOSITORY;
const headers={Authorization:'Bearer '+process.env.GH_TOKEN,Accept:'application/vnd.github+json'};
async function get(path,optional=false){const response=await fetch(base+path,{headers});if(!response.ok){if(optional)return {httpStatus:response.status};throw Error('Read-only GitHub diagnostic HTTP '+response.status);}return response.json();}
(async()=>{
 const runs=await get('/actions/workflows/staging-public-release.yml/runs?branch=feature/isolated-marketplace-staging-20261025&per_page=10');
 let run,publish;
 for(const candidate of runs.workflow_runs){
  const artifacts=await get('/actions/runs/'+candidate.id+'/artifacts');
  if(!artifacts.artifacts.some(a=>a.name==='staging-business-panel-direct-https'&&!a.expired))continue;
  const jobs=await get('/actions/runs/'+candidate.id+'/jobs?filter=latest');
  const attempt=jobs.jobs.find(job=>job.name==='publish-panel');
  if(!attempt)continue;
  run=candidate;publish=attempt;break;
 }
 if(!run)throw Error('PUBLIC_RELEASE_WITH_READY_PANEL_AND_PUBLISH_ATTEMPT_MISSING');
 const annotations=publish?await get('/check-runs/'+publish.id+'/annotations'):[];
 const environment=await get('/environments/github-pages',true);
 const branches=await get('/environments/github-pages/deployment-branch-policies',true);
 const report={runId:run.id,head:run.head_sha,publish:publish?{id:publish.id,status:publish.status,conclusion:publish.conclusion}:null,annotations:annotations.map(a=>({level:a.annotation_level,message:a.message})),environment:environment.httpStatus?environment:{deployment_branch_policy:environment.deployment_branch_policy,protection_rules:environment.protection_rules?.map(r=>({type:r.type,prevent_self_review:r.prevent_self_review}))},allowedBranches:branches.httpStatus?branches:branches.branch_policies?.map(p=>({name:p.name,type:p.type}))};
 fs.writeFileSync('staging-public-pages-permission.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 fs.appendFileSync(process.env.GITHUB_OUTPUT,'release_run='+run.id+'\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
