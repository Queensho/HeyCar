'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validateStagingEnvironment}=require('../staging-safety');
test('staging refuses production DB, port and enabled external services',()=>{
 const safe={APP_ENV:'staging',DB_NAME:'heycar_staging',PORT:'8091',STAGING_DISABLE_EXTERNAL_SERVICES:'1'};
 validateStagingEnvironment(safe);
 for(const changes of [{DB_NAME:'heycar'},{PORT:'8090'},{STAGING_DISABLE_EXTERNAL_SERVICES:'0'}])assert.throws(()=>validateStagingEnvironment({...safe,...changes}));
 validateStagingEnvironment({APP_ENV:'production'});
});
