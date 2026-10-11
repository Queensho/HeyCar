'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {motorcycleLogoSource}=require('../motorcycle-brand-logo-source');
const {normalizeBrand,logoPayload}=require('../vehicle-brand-logo-service');

test('RKS motorcycle logo has a narrowly allowlisted HTTPS API source',()=>{
  const source=motorcycleLogoSource('RKS','motorcycle');
  assert.ok(source);
  assert.equal(new URL(source.url).protocol,'https:');
  assert.deepEqual(source.allowedHosts,[new URL(source.url).hostname]);
  assert.ok(source.url.endsWith('.png'));
  assert.equal(motorcycleLogoSource('rks','MOTORCYCLE')?.url,source.url);
  assert.equal(motorcycleLogoSource('RKS','car'),null);
  assert.equal(motorcycleLogoSource('RKS',null),null);
  assert.equal(normalizeBrand('RKS'),'rks');
  assert.equal(normalizeBrand('QJ Motor'),'qjmotor');
});

test('Benelli motorcycle emblem uses the real motorcycle manufacturer source',()=>{
  const b=motorcycleLogoSource('Benelli','motorcycle');
  assert.ok(b);
  assert.equal(
    b.url,
    'https://benelli.co.id/front-end/benelli/uploads/logo/benelli_web.png',
  );
  assert.deepEqual(b.allowedHosts,['benelli.co.id']);
  assert.equal(new URL(b.url).protocol,'https:');
  assert.equal(motorcycleLogoSource('Benelli','car'),null);
  assert.equal(motorcycleLogoSource('benelli','MOTORCYCLE')?.url,b.url);
});

test('unknown manufacturers cannot inject arbitrary logo URL via vehicle name',()=>{
  assert.equal(motorcycleLogoSource('Other motorcycle','motorcycle'),null);
  assert.equal(motorcycleLogoSource('https://example.com/evil.png','motorcycle'),null);
  assert.equal(motorcycleLogoSource('', 'motorcycle'),null);
});

test('existing backend returns only its cached ready logo to vehicle cards',()=>{
  const ready=logoPayload({name:'RKS',logo_status:'ready',
    logo_source:'external',logo_url:'https://example.org/managed-logo.png'});
  assert.equal(ready.available,true);
  assert.equal(ready.url,'https://example.org/managed-logo.png');
  assert.equal(logoPayload({name:'RKS',logo_status:'not_found',
    logo_source:'fallback',logo_url:null}).available,false);
  assert.equal(logoPayload({name:'RKS',logo_status:'ready',
    logo_source:'manual',logo_url:'https://example.org/manual.png'}).source,'manual');
});

test('brand service preserves admin manual-logo priority and only accepts verified image bytes',()=>{
  const source=fs.readFileSync(path.join(__dirname,'../vehicle-brand-logo-service.js'),'utf8');
  assert.match(source,/brand\.logo_source==='manual'/);
  assert.match(source,/logo_source<>'manual'/);
  assert.match(source,/fetchImage\(provider\.url,provider\.hosts\)/);
  assert.match(source,/\['image\/png','image\/jpeg','image\/jpg','image\/webp'\]/);
  assert.match(source,/logo_source_url=COALESCE\(\$2,logo_source_url\)/);
});

test('vehicle list, create and edit carry motorcycle type into logo resolver',()=>{
  const source=fs.readFileSync(path.join(__dirname,'../vehicle-management-routes.js'),'utf8');
  assert.match(source,/queueResolve\(pool,v\.make,base,\{vehicleType:v\.vehicle_type\}\)/);
  assert.match(source,/queueResolve\(pool,created\.rows\[0\]\.make,publicBase\(req\),\{vehicleType:created\.rows\[0\]\.vehicle_type\}\)/);
  assert.match(source,/queueResolve\(pool,updated\.rows\[0\]\.make,publicBase\(req\),\{vehicleType:updated\.rows\[0\]\.vehicle_type\}\)/);
});
