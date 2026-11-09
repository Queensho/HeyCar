// This command must never silently skip either PostgreSQL suite.
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path');
if(!['127.0.0.1','localhost','::1'].includes(process.env.DB_HOST)||!/_test$|_matrix$/.test(process.env.DB_NAME||'')){
 console.error('Release tests require an explicitly configured local disposable *_test or *_matrix database');process.exit(1);
}
const root=path.resolve(__dirname,'..');
const files=fs.readdirSync(path.join(root,'tests')).filter(f=>f.endsWith('.test.js')).map(f=>path.join(root,'tests',f));
const r=spawnSync(process.execPath,['--test','--test-reporter=tap',...files],{env:{...process.env,MARKETPLACE_PG_TEST:'1'},cwd:root,encoding:'utf8',maxBuffer:16*1024*1024});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');
if(r.status!==0||!/^# skipped 0$/m.test(r.stdout||'')){console.error('Release tests failed or skipped required coverage');process.exit(1);}
