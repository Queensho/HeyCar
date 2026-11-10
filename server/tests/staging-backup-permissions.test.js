const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {hardenStagingBackups,backupRoot}=require('../../deploy/firebase-staging/harden-backups.cjs');
function fixture(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'staging-backup-mode-')),dir=temp+'/20261110085136695-ee3e15672f39';fs.mkdirSync(dir);fs.writeFileSync(dir+'/heycar_staging.dump','KEEP_TEST_DATA');fs.chmodSync(dir+'/heycar_staging.dump',0o664);
 let changes=0;const local=p=>temp+p.slice(backupRoot.length),wrapped={existsSync:p=>fs.existsSync(local(p)),lstatSync:p=>fs.lstatSync(local(p)),realpathSync:p=>fs.realpathSync(local(p)).replace(temp,backupRoot),readdirSync:p=>fs.readdirSync(local(p)),chmodSync:(p,mode)=>{changes++;fs.chmodSync(local(p),mode);}};
 return {temp,dir,wrapped,changes:()=>changes,close:()=>fs.rmSync(temp,{recursive:true,force:true})};
}
test('staging backup hardening preserves content and restricts exact known paths',()=>{
 const f=fixture();try{const r=hardenStagingBackups({environment:'staging',database:'heycar_staging',fs:f.wrapped});assert.equal(r.files,1);assert.equal(fs.statSync(f.dir+'/heycar_staging.dump').mode&0o777,0o600);assert.equal(fs.statSync(f.dir).mode&0o777,0o700);assert.equal(fs.readFileSync(f.dir+'/heycar_staging.dump','utf8'),'KEEP_TEST_DATA');}finally{f.close();}
});
test('production database and arbitrary directories are refused before filesystem access',()=>{
 for(const args of [{environment:'production',database:'heycar_staging'},{environment:'staging',database:'production'},{environment:'staging',database:'heycar_staging',directory:'/var/production'}])assert.throws(()=>hardenStagingBackups({...args,fs:{existsSync:()=>{assert.fail('MUST_NOT_ACCESS');}}}));
});
test('backup symlink aborts the whole plan before chmod and leaves content untouched',()=>{
 const f=fixture();try{fs.symlinkSync(f.dir+'/heycar_staging.dump',f.dir+'/staging.env');assert.throws(()=>hardenStagingBackups({environment:'staging',database:'heycar_staging',fs:f.wrapped}));assert.equal(f.changes(),0);assert.equal(fs.statSync(f.dir+'/heycar_staging.dump').mode&0o777,0o664);}finally{f.close();}
});
