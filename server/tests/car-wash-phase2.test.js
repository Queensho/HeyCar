const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

// Car wash is retired from the running API. Historical migrations and records
// intentionally remain in place so no existing user data is destroyed.
test('car wash routes and scheduler are not registered by the server',()=>{
  const source=fs.readFileSync(path.join(__dirname,'../server.js'),'utf8');
  for(const name of ['registerCarWashRoutes','registerCarWashBookingRoutes','startCarWashNotifications']){
    assert.equal(source.includes(name+'('),false,name+' must not be called');
  }

});

test('historical car wash migrations remain available for existing data',()=>{
  for(const file of ['126_car_wash_catalog.sql','127_car_wash_bookings.sql']){
    assert.equal(fs.existsSync(path.join(__dirname,'../migrations',file)),true);
  }
});
