function httpsImage(value){
 if(typeof value!=='string'||value.length>2048||/[\s<>"\\]/.test(value))return false;
 try{const u=new URL(value);return u.protocol==='https:'&&!!u.hostname&&!u.username&&!u.password;}catch(_){return false;}
}
function campaignInput(body, create=false) {
  if(!body||typeof body!=='object'||Array.isArray(body))return false;
  if(create&&(!body.title||!body.startsAt||!body.endsAt))return false;
  for(const [key,max] of [['title',160],['description',8000],['terms',8000],['badge',80]]) {
    if(body[key]!==undefined&&(typeof body[key]!=='string'||body[key].length>max||(key==='title'&&!body[key].trim())))return false;
  }
  for(const key of ['startsAt','endsAt'])if(body[key]!==undefined&&(typeof body[key]!=='string'||!body[key].trim()||!Number.isFinite(Date.parse(body[key]))))return false;
  if(body.startsAt&&body.endsAt&&Date.parse(body.endsAt)<=Date.parse(body.startsAt))return false;
  for(const key of ['dailyLimit','totalLimit'])if(body[key]!=null&&(!Number.isInteger(body[key])||body[key]<1||body[key]>2147483647))return false;
  for(const key of ['regularPrice','offerPrice'])if(body[key]!=null&&(typeof body[key]!=='number'||!Number.isFinite(body[key])||body[key]<0||body[key]>9999999999.99))return false;
  if(body.offerType!==undefined&&!['discount','special_price','gift'].includes(body.offerType))return false;
  if(body.isActive!==undefined&&typeof body.isActive!=='boolean')return false;
  if(body.couponCode!=null&&(typeof body.couponCode!=='string'||body.couponCode.length>80))return false;
  if(body.discountPercent!=null&&(!Number.isInteger(body.discountPercent)||body.discountPercent<1||body.discountPercent>100))return false;
  if(body.imageUrl!=null&&(typeof body.imageUrl!=='string'||body.imageUrl.length>2048||(body.imageUrl!==''&&!body.imageUrl.startsWith('https://'))))return false;
  if(body.regularPrice!=null&&body.offerPrice!=null&&body.offerPrice>body.regularPrice)return false;
  if(body.imageUrl&&!httpsImage(body.imageUrl))return false;
  return true;
}
module.exports={campaignInput,httpsImage};
