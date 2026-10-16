const test=require('node:test');
const assert=require('node:assert/strict');
const {matchIncidents,distanceMeters}=require('./smart-route-geometry');

const route=[{lat:41.0000,lon:28.0000},{lat:41.0000,lon:28.0200}];
const incident=(id,lon,lat)=>({id,geometry:{type:'Point',coordinates:[lon,lat]}});

test('nearby incident is matched to route geometry',()=>{
 const result=matchIncidents([incident('near',28.0100,41.0002)],route);
 assert.equal(result.available,true);
 assert.equal(result.incidents.length,1);
 assert.equal(result.incidents[0].id,'near');
 assert.ok(result.incidents[0].distanceToRouteMeters<250);
});
test('distant incident is not treated as on route',()=>{
 const result=matchIncidents([incident('far',28.0100,41.0150)],route);
 assert.equal(result.incidents.length,0);
});
test('missing route geometry fails closed',()=>{
 const result=matchIncidents([incident('near',28.0100,41.0002)],[]);
 assert.equal(result.available,false);
 assert.equal(result.reason,'NO_ROUTE_GEOMETRY');
});
test('invalid incident coordinates are ignored',()=>{
 const result=matchIncidents([{id:'invalid',geometry:{coordinates:[500,500]}}],route);
 assert.equal(result.incidents.length,0);
});
test('distance calculation is zero for identical coordinates',()=>{
 assert.equal(distanceMeters(route[0],route[0]),0);
});
