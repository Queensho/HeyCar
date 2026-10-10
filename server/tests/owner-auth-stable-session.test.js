'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const auth=require('../owner-auth-service');

const ownerId='10000000-0000-4000-8000-000000000001';
const sessionId='10000000-0000-4000-8000-000000000004';
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const sessionDb=()=>{
  const state={ownerStatus:'active',securityVersion:1,session:null,inserts:0,updates:0};
  const query=async (sql,args=[])=>{
    if(sql==='BEGIN'||sql==='COMMIT'||sql==='ROLLBACK')return {rows:[],rowCount:0};
    if(sql.includes('COALESCE(p.security_version'))
      return {rows:[{status:state.ownerStatus,security_version:state.securityVersion}],rowCount:1};
    if(sql.includes('INSERT INTO owner_auth_sessions')){
      assert.equal(args[0],ownerId);
      assert.equal(state.session,null,'refresh must not create a new session');
      state.inserts++;
      state.session={id:sessionId,owner_id:ownerId,refreshHash:args[1],revoked:false,expires:Date.now()+86400000};
      return {rows:[{id:sessionId}],rowCount:1};
    }
    if(sql.includes('SELECT s.id,s.owner_id FROM owner_auth_sessions')){
      const row=state.session;
      return row&&!row.revoked&&row.refreshHash===args[0]&&row.expires>Date.now()&&state.ownerStatus==='active'
        ?{rows:[{id:row.id,owner_id:row.owner_id}],rowCount:1}
        :{rows:[],rowCount:0};
    }
    if(sql.includes('UPDATE owner_auth_sessions SET refresh_token_hash=')){
      const row=state.session;
      if(!row||row.id!==args[0]||row.owner_id!==args[2]||row.revoked)
        return {rows:[],rowCount:0};
      row.refreshHash=args[1];
      row.expires=Date.now()+86400000;
      state.updates++;
      return {rows:[{id:row.id}],rowCount:1};
    }
    if(sql.includes('UPDATE owner_auth_sessions SET revoked_at=now() WHERE refresh_token_hash=')){
      if(state.session&&state.session.refreshHash===args[0])state.session.revoked=true;
      return {rows:[],rowCount:state.session?.revoked?1:0};
    }
    throw Error('Unexpected SQL: '+sql);
  };
  return {state,db:{query,connect:async()=>({query,release(){}})}};
};

test('owner refresh rotates secret without revoking the active JWT session',async()=>{
  const previous=process.env.OWNER_AUTH_SECRET;
  process.env.OWNER_AUTH_SECRET='session-stability-regression-secret-long-enough';
  try{
    const {db,state}=sessionDb();
    const first=await auth.issueTokens(db,ownerId);
    const payload=auth.verify(first.accessToken);
    assert.equal(payload.sid,sessionId);
    assert.equal(state.inserts,1);
    assert.equal(state.session.revoked,false);
    const second=await auth.rotateRefresh(db,first.refreshToken);
    assert.ok(second);
    assert.equal(auth.verify(second.accessToken).sid,sessionId);
    assert.equal(auth.verify(first.accessToken).sid,sessionId,'in-flight JWT still points to active session');
    assert.equal(state.session.revoked,false);
    assert.equal(state.inserts,1,'refresh must not create another session');
    assert.equal(state.updates,1);
    assert.equal(state.session.refreshHash,hash(second.refreshToken));
    assert.notEqual(first.refreshToken,second.refreshToken,'refresh secrets must change');
    assert.equal(await auth.rotateRefresh(db,first.refreshToken),null,'old refresh secret cannot replay');
    const third=await auth.rotateRefresh(db,second.refreshToken);
    assert.ok(third);
    assert.equal(auth.verify(third.accessToken).sid,sessionId);
    assert.equal(state.inserts,1);
    assert.equal(state.updates,2);
    await auth.revokeRefresh(db,third.refreshToken);
    assert.equal(state.session.revoked,true);
    assert.equal(await auth.rotateRefresh(db,third.refreshToken),null,'logout still revokes the session');
  }finally{
    if(previous===undefined)delete process.env.OWNER_AUTH_SECRET;
    else process.env.OWNER_AUTH_SECRET=previous;
  }
});
