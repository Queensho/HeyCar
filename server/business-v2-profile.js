'use strict';
function photo(value,svc){
 if(typeof value!=='string'||value.length>2000)svc.fail('INVALID_PHOTO');
 let u;try{u=new URL(value);}catch(_){svc.fail('INVALID_PHOTO');}
 if(u.protocol!=='https:'||u.username||u.password)svc.fail('INVALID_PHOTO');return value;
}
module.exports=function register({route,pool,svc}){
 const fields='id,name,phone,address,latitude,longitude,description,logo_url,opening_hours';
 route('get','/api/business/car-wash/profile','business',async(req,a)=>{
  const business=(await pool.query(`SELECT ${fields} FROM businesses WHERE id=$1`,[a.id])).rows[0];
  const location=(await pool.query('SELECT photos,published,booking_enabled FROM car_wash_locations WHERE business_id=$1',[a.id])).rows[0];
  return {ok:true,business,location:location||{photos:[],published:false,booking_enabled:false}};
 });
 route('put','/api/business/car-wash/profile','business',async(req,a)=>{
  const b=req.body||{},name=svc.text(b.name);
  for(const [key,max] of [['phone',30],['address',1000],['description',2000]])if(typeof b[key]!=='string'||b[key].length>max)svc.fail('INVALID_INPUT');
  if(b.phone&&!/^\+?[0-9 ()-]{6,30}$/.test(b.phone))svc.fail('INVALID_INPUT');
  const lat=b.latitude,lon=b.longitude;
  if((lat===null)!==(lon===null)||(lat!==null&&(!Number.isFinite(lat)||!Number.isFinite(lon)||lat < -90||lat>90||lon < -180||lon>180)))svc.fail('INVALID_COORDINATES');
  const logo=b.logoUrl===null?null:photo(b.logoUrl,svc);
  if(!Array.isArray(b.photos)||b.photos.length>12)svc.fail('INVALID_PHOTO');b.photos.forEach(p=>photo(p,svc));
  return svc.transaction(pool,async db=>{
   await db.query('INSERT INTO car_wash_locations(business_id) VALUES($1) ON CONFLICT DO NOTHING',[a.id]);await svc.lockLocation(db,a.id);
   await db.query('UPDATE businesses SET name=$2,phone=$3,address=$4,latitude=$5,longitude=$6,description=$7,logo_url=$8,updated_at=now() WHERE id=$1',[a.id,name,b.phone||null,b.address||null,lat,lon,b.description||null,logo]);
   await db.query('UPDATE car_wash_locations SET photos=$2 WHERE business_id=$1',[a.id,JSON.stringify(b.photos)]);
   return {ok:true};
  });
 });
};
