'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const Module=require('node:module');

const filename=path.resolve(__dirname,'../app-builder-routes.js');
const compiled=new Module(filename,module);
compiled.filename=filename;
compiled.paths=Module._nodeModulePaths(path.dirname(filename));
// Export a pure validator only in this test, without altering the production module.
compiled._compile(fs.readFileSync(filename,'utf8')+'\nmodule.exports._validateConfig=validateConfig;',filename);
const validate=compiled.exports._validateConfig;

function input(titleColor='#FFFFFF'){
 return {
  schemaVersion:1,theme:{},home:{components:[]},
  services:[{
   id:'towing',title:'Çekici',subtitle:'Canlı takip',action:'OPEN_TOWING',
   titleTextColor:titleColor,subtitleTextColor:'#FFFFFF',badgeTextColor:'#FFFFFF',
   badgeText:'Yakında',backgroundToken:'primary',
  }],quickActions:[],banners:[],
 };
}
test('service heading, description and badge colors survive draft and publish validation',()=>{
 const first=validate(input());
 const draft=validate(JSON.parse(JSON.stringify(first)));
 const published=validate(JSON.parse(JSON.stringify(draft)));
 for(const row of [first.services[0],draft.services[0],published.services[0]]){
  assert.equal(row.titleTextColor,'#FFFFFF');
  assert.equal(row.subtitleTextColor,'#FFFFFF');
  assert.equal(row.badgeTextColor,'#FFFFFF');
  assert.equal(row.title,'Çekici');
 }
});
test('invalid service text colors reject instead of silently falling back to black',()=>{
 assert.throws(()=>validate(input('#FFFFFFFF')),/INVALID_TEXT_COLOR/);
});
test('legacy services without explicit colors retain theme defaults',()=>{
 const old=input();
 delete old.services[0].titleTextColor;
 delete old.services[0].subtitleTextColor;
 delete old.services[0].badgeTextColor;
 const row=validate(old).services[0];
 assert.equal(Object.hasOwn(row,'titleTextColor'),false);
 assert.equal(Object.hasOwn(row,'subtitleTextColor'),false);
 assert.equal(Object.hasOwn(row,'badgeTextColor'),false);
});
