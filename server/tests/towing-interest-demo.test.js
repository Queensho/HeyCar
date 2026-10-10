'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const register=require('../towing-interest-routes');

function appStub(){
  const routes={};
  const app={};
  for(const method of ['get','post','put','delete']){
    app[method]=(path,...handlers)=>{routes[method.toUpperCase()+' '+path]=handlers;};
  }
  async function invoke(method,path,{body={},query={}}={}){
    const handlers=routes[method+' '+path];
    assert.ok(handlers,'endpoint should be registered: '+path);
    const req={body,query,headers:{}};
    const out={status:200,body:null};
    const res={status(code){out.status=code;return this;},json(value){out.body=value;return this;}};
    for(const handler of handlers){
      let nextWasCalled=false;
      await handler(req,res,()=>{nextWasCalled=true;});
      if(!nextWasCalled)break;
    }
    return out;
  }
  return {app,invoke};
}
test('demo-only public and admin routes do not touch the database',async()=>{
  const before=process.env.TOWING_INTEREST_ENABLED;
  delete process.env.TOWING_INTEREST_ENABLED;
  try{
    let queries=0;
    const pool={query:async()=>{queries++;throw new Error('demo must not query DB');}};
    const {app,invoke}=appStub();
    register(app,pool,(_req,_res,next)=>next());
    const available=await invoke('GET','/api/towing/interest/availability');
    assert.equal(available.status,200);
    assert.equal(available.body.demo,true);
    assert.equal(available.body.mode,'coming_soon');
    const summary=await invoke('GET','/api/admin/manage/towing/interest/summary');
    assert.equal(summary.status,200);
    assert.equal(summary.body.demo,true);
    assert.equal(summary.body.items[0].district,'Avcılar');
    const pilot=await invoke('GET','/api/admin/manage/towing/pilot-regions');
    assert.equal(pilot.body.demo,true);
    const update=await invoke('PUT','/api/admin/manage/towing/pilot-regions',
      {body:{city:'İstanbul',district:'Avcılar',status:'active',providerCapacity:12}});
    assert.equal(update.status,409);
    assert.equal(update.body.error,'TOWING_INTEREST_DEMO_ONLY');
    assert.equal(queries,0);
  }finally{
    if(before===undefined)delete process.env.TOWING_INTEREST_ENABLED;
    else process.env.TOWING_INTEREST_ENABLED=before;
  }
});
test('owner interest requires JWT even in demo mode',async()=>{
  const before=process.env.TOWING_INTEREST_ENABLED;
  delete process.env.TOWING_INTEREST_ENABLED;
  try{
    const {app,invoke}=appStub();
    register(app,{query:async()=>{throw Error('no DB')}},(_req,_res,next)=>next());
    const read=await invoke('GET','/api/owner/towing-interest');
    assert.equal(read.status,401);
    const update=await invoke('PUT','/api/owner/towing-interest',
      {body:{city:'İstanbul',district:'Avcılar',notifyOnLaunch:true}});
    assert.equal(update.status,401);
  }finally{
    if(before===undefined)delete process.env.TOWING_INTEREST_ENABLED;
    else process.env.TOWING_INTEREST_ENABLED=before;
  }
});
