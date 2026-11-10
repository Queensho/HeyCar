'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const projectId='cepqontag-staging';
function privateJson(file,{root='/home/cepqontag-deploy/staging-secrets'}={}){
 assert.ok(file&&path.isAbsolute(file),'PRIVATE_FILE_REQUIRED');const real=fs.realpathSync(file);
 assert.equal(real,file,'SECRET_SYMLINK_REFUSED');assert.equal(path.dirname(real),fs.realpathSync(root),'SECRET_DIRECTORY_REQUIRED');
 const st=fs.statSync(real);assert.ok(st.isFile()&&(st.mode&0o077)===0,'SECRET_MODE_0600_REQUIRED');return JSON.parse(fs.readFileSync(real,'utf8'));
}
function loadPolicy(env=process.env,options={}){
 assert.equal(env.APP_ENV,'staging');assert.equal(env.PORT,'8091');assert.equal(env.CEPQONTAG_QA_PUSH_REGISTRATION,'true');
 assert.ok(['1','true','yes','on'].includes(String(env.STAGING_DISABLE_EXTERNAL_SERVICES).trim().toLowerCase()),'MAIN_SUPPRESSION_MUST_REMAIN_ON');
 const p=privateJson(env.CEPQONTAG_QA_PUSH_ALLOWLIST_FILE,options);assert.equal(p.projectId,projectId);
 for(const k of ['owners','businesses'])assert.ok(Array.isArray(p[k])&&p[k].length<=100&&p[k].every(id=>/^[0-9a-f-]{36}$/i.test(id)));
 assert.ok(Number.isFinite(Date.parse(p.notBefore))&&Date.parse(p.notBefore)<=Date.now());
 assert.ok(Date.parse(p.expiresAt)>Date.now()&&Date.parse(p.expiresAt)-Date.parse(p.notBefore)<=31*86400000,'QA_WINDOW_INVALID');return p;
}
function createAdminSender(env=process.env,options={}){
 loadPolicy(env,options);if(env.CEPQONTAG_QA_PUSH_SEND_ENABLED!=='true'||!env.CEPQONTAG_QA_FIREBASE_ADMIN_FILE)return null;
 const account=privateJson(env.CEPQONTAG_QA_FIREBASE_ADMIN_FILE,options);assert.equal(account.project_id,projectId);assert.equal(account.type,'service_account');
 assert.ok(account.client_email.endsWith('@'+projectId+'.iam.gserviceaccount.com'));assert.ok(account.private_key.startsWith('-----BEGIN PRIVATE KEY-----'));
 const loader=options.loader||(env.CEPQONTAG_QA_ADMIN_SDK_ROOT?require('node:module').createRequire('/home/cepqontag-deploy/qa-firebase-runtime/package.json'):require);
 if(env.CEPQONTAG_QA_ADMIN_SDK_ROOT)assert.equal(env.CEPQONTAG_QA_ADMIN_SDK_ROOT,'/home/cepqontag-deploy/qa-firebase-runtime');
 const {initializeApp,cert,getApps}=loader('firebase-admin/app');const {getMessaging}=loader('firebase-admin/messaging');
 const name='cepqontag-qa-staging';const app=getApps().find(a=>a.name===name)||initializeApp({projectId,credential:cert(account)},name);
 assert.equal(app.options.projectId,projectId);return {send:message=>getMessaging(app).send(message)};
}
function createWebSender(env=process.env,options={}){
 loadPolicy(env,options);if(!env.CEPQONTAG_QA_VAPID_FILE)return null;
 const keys=privateJson(env.CEPQONTAG_QA_VAPID_FILE,options);assert.equal(keys.projectId,projectId);assert.equal(keys.purpose,'staging-qa-only');
 const crypto=require('node:crypto'),ec=crypto.createECDH('prime256v1');ec.setPrivateKey(Buffer.from(keys.privateKey,'base64url'));
 assert.ok(ec.getPublicKey().equals(Buffer.from(keys.publicKey,'base64url')));assert.match(keys.subject,/^(mailto:|https:\/\/)/);
 const webpush=options.webpush||require('web-push');
 return {publicKey:keys.publicKey,send:(subscription,payload)=>webpush.sendNotification(subscription,JSON.stringify(payload),{vapidDetails:{subject:keys.subject,publicKey:keys.publicKey,privateKey:keys.privateKey},TTL:300})};
}
module.exports={projectId,privateJson,loadPolicy,createAdminSender,createWebSender};
