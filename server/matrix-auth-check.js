const assert=require('node:assert/strict');
const jwt=require('jsonwebtoken');
const ownerAuth=require('./owner-auth-service');
const driverAuth=require('./driver-auth-service');
const {createAdminGuard}=require('./admin-auth-routes');

async function main(){
  const ownerId='10000000-0000-4000-8000-000000000001';
  const driverId='10000000-0000-4000-8000-000000000002';
  const adminId='10000000-0000-4000-8000-000000000003';

  const sessionDb={
    async query(){return {rows:[],rowCount:1};},
  };

  const ownerTokens=await ownerAuth.issueTokens(sessionDb,ownerId);
  const driverTokens=await driverAuth.issueTokens(sessionDb,driverId);

  const reqWith=token=>({headers:{authorization:'Bearer '+token}});

  assert.equal(ownerAuth.ownerId(reqWith(ownerTokens.accessToken)),ownerId);
  assert.equal(driverAuth.driverId(reqWith(driverTokens.accessToken)),driverId);
  assert.equal(ownerAuth.ownerId(reqWith(driverTokens.accessToken)),'');
  assert.equal(driverAuth.driverId(reqWith(ownerTokens.accessToken)),'');

  const adminToken=jwt.sign(
    {sub:adminId,email:'admin@matrix.test',role:'admin'},
    process.env.JWT_SECRET,
    {algorithm:'HS256',expiresIn:'5m'}
  );

  const adminDb={
    async query(_sql,args){
      assert.equal(String(args[0]),adminId);
      return {rows:[{id:adminId,email:'admin@matrix.test',display_name:'Matrix Admin',role:'admin',status:'active'}]};
    },
  };

  const guard=createAdminGuard(adminDb);

  async function runGuard(token){
    return await new Promise((resolve,reject)=>{
      const req=reqWith(token);
      const res={
        statusCode:200,
        status(code){this.statusCode=code;return this;},
        json(body){resolve({next:false,status:this.statusCode,body,req});},
      };
      try{
        const p=guard(req,res,()=>resolve({next:true,status:200,req}));
        if(p&&typeof p.catch==='function')p.catch(reject);
      }catch(e){reject(e);}
    });
  }

  const adminOk=await runGuard(adminToken);
  assert.equal(adminOk.next,true);
  assert.equal(String(adminOk.req.admin.id),adminId);

  const ownerRejected=await runGuard(ownerTokens.accessToken);
  assert.equal(ownerRejected.next,false);
  assert.equal(ownerRejected.status,401);

  const driverRejected=await runGuard(driverTokens.accessToken);
  assert.equal(driverRejected.next,false);
  assert.equal(driverRejected.status,401);

  assert.equal(ownerAuth.ownerId(reqWith(adminToken)),'');
  assert.equal(driverAuth.driverId(reqWith(adminToken)),'');

  console.log('MATRIX_TOKEN_ROLE_ISOLATION_OK');
}

main().catch(e=>{console.error(e);process.exit(1);});
