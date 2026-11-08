const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path');
require('./tests/test-database').testDatabaseUrl();
const files=['tests','.'].flatMap(dir=>fs.readdirSync(path.join(__dirname,dir)).filter(f=>f.endsWith('.test.js')).map(f=>path.join(__dirname,dir,f)));
const result=spawnSync(process.execPath,['--test','--test-reporter=tap',...files],{cwd:__dirname,env:{...process.env,NODE_ENV:'test',APP_ENV:'staging',STAGING_DISABLE_EXTERNAL_SERVICES:'true'},encoding:'utf8',maxBuffer:20*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
if(result.error)console.error(result.error.message);
process.exit(result.status===0&&/^# skipped 0$/m.test(result.stdout)?0:1);
