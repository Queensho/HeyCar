const fs=require('fs');
const path=require('path');
const dns=require('dns').promises;
const net=require('net');
const crypto=require('crypto');

const NEGATIVE_TTL_MS=7*24*60*60*1000;
const MAX_BYTES=2*1024*1024;
const inflight=new Map();

function normalizeBrand(value){
  return String(value||'').trim().toLocaleLowerCase('tr-TR')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g,'')
    .replace(/ı/g,'i').replace(/[^a-z0-9]+/g,'');
}
function slugify(value){return normalizeBrand(value).replace(/[^a-z0-9]+/g,'-')||'brand';}
function isPrivateIp(ip){
  if(net.isIP(ip)===4){
    const p=ip.split('.').map(Number);
    return p[0]===10||p[0]===127||p[0]===0||p[0]===169&&p[1]===254||p[0]===192&&p[1]===168||p[0]===172&&p[1]>=16&&p[1]<=31;
  }
  if(net.isIP(ip)===6){
    const s=ip.toLowerCase();return s==='::1'||s.startsWith('fc')||s.startsWith('fd')||s.startsWith('fe80:')||s==='::';
  }
  return true;
}
async function assertPublicHttps(raw,allowedHosts=[]){
  const u=new URL(String(raw||''));if(u.protocol!=='https:')throw new Error('HTTPS_REQUIRED');
  if(allowedHosts.length&&!allowedHosts.includes(u.hostname.toLowerCase()))throw new Error('HOST_NOT_ALLOWED');
  const rs=await dns.lookup(u.hostname,{all:true});
  if(!rs.length||rs.some(x=>isPrivateIp(x.address)))throw new Error('PRIVATE_ADDRESS_REJECTED');
  return u;
}
function imageMeta(buf,type){
  if(type==='image/png'&&buf.length>=24&&buf.subarray(1,4).toString()==='PNG')return {ext:'png',width:buf.readUInt32BE(16),height:buf.readUInt32BE(20)};
  if(type==='image/webp'&&buf.length>=16&&buf.subarray(0,4).toString()==='RIFF'&&buf.subarray(8,12).toString()==='WEBP')return {ext:'webp',width:null,height:null};
  if((type==='image/jpeg'||type==='image/jpg')&&buf.length>4&&buf[0]===0xff&&buf[1]===0xd8)return {ext:'jpg',width:null,height:null};
  throw new Error('INVALID_IMAGE');
}
function publicBase(req){
  const proto=String(req?.headers?.['x-forwarded-proto']||req?.protocol||'https').split(',')[0].trim();
  const host=req?.get?.('host');
  return String(process.env.PUBLIC_API_BASE_URL||(host?proto+'://'+host:'https://heycar-api-185-165-46-213.nip.io')).replace(/\/$/,'');
}
async function findBrand(pool,make,{create=true}={}){
  const norm=normalizeBrand(make);if(!norm)return null;
  let q=await pool.query(`SELECT b.* FROM vehicle_brands b LEFT JOIN vehicle_brand_aliases a ON a.brand_id=b.id WHERE b.normalized_name=$1 OR a.normalized_alias=$1 LIMIT 1`,[norm]);
  if(q.rowCount)return q.rows[0];
  if(!create)return null;
  const name=String(make||'').trim().slice(0,100)||'Bilinmeyen';
  q=await pool.query(`INSERT INTO vehicle_brands(name,normalized_name,slug,logo_status,logo_source) VALUES($1,$2,$3,'pending','fallback') ON CONFLICT(normalized_name) DO UPDATE SET updated_at=NOW() RETURNING *`,[name,norm,slugify(name)]);
  return q.rows[0];
}
function logoPayload(row){
  const ready=row&&row.logo_status==='ready'&&/^https:\/\//i.test(String(row.logo_url||''));
  return {url:ready?String(row.logo_url):'',available:Boolean(ready),source:ready?String(row.logo_source||'external'):'fallback',brand:row?String(row.name):''};
}
async function cachedLogo(pool,make){
  try{return logoPayload(await findBrand(pool,make));}catch(e){console.error('brand logo cache lookup',e);return {url:'',available:false,source:'fallback',brand:String(make||'')};}
}
async function fetchImage(url,allowedHosts){
  let current=await assertPublicHttps(url,allowedHosts);
  for(let i=0;i<3;i++){
    const ctrl=new AbortController();const timer=setTimeout(()=>ctrl.abort(),8000);
    let r;try{r=await fetch(current,{redirect:'manual',signal:ctrl.signal,headers:{'User-Agent':'CepQontagVehicleLogo/1.0'}});}finally{clearTimeout(timer);}
    if([301,302,303,307,308].includes(r.status)){
      const loc=r.headers.get('location');if(!loc)throw new Error('BAD_REDIRECT');
      current=await assertPublicHttps(new URL(loc,current).toString(),allowedHosts);continue;
    }
    if(!r.ok)throw new Error('UPSTREAM_'+r.status);
    const type=String(r.headers.get('content-type')||'').split(';')[0].trim().toLowerCase();
    if(!['image/png','image/jpeg','image/jpg','image/webp'].includes(type))throw new Error('INVALID_CONTENT_TYPE');
    const len=Number(r.headers.get('content-length')||0);if(len>MAX_BYTES)throw new Error('IMAGE_TOO_LARGE');
    const ab=await r.arrayBuffer();const buf=Buffer.from(ab);if(!buf.length||buf.length>MAX_BYTES)throw new Error('IMAGE_TOO_LARGE');
    return {buf,type,meta:imageMeta(buf,type),sourceUrl:current.toString()};
  }
  throw new Error('TOO_MANY_REDIRECTS');
}
async function resolveExternal(pool,brand,base){
  if(!brand||brand.logo_source==='manual')return brand;
  if(brand.logo_status==='ready'&&brand.logo_url)return brand;
  if(brand.last_checked_at&&Date.now()-new Date(brand.last_checked_at).getTime()<NEGATIVE_TTL_MS&&['not_found','error'].includes(brand.logo_status))return brand;
  const template=String(process.env.VEHICLE_LOGO_PROVIDER_URL||'').trim();
  if(!template){return brand;}
  const providerKey=String(process.env.VEHICLE_LOGO_API_KEY||'').trim();
  const source=template.replace('{brand}',encodeURIComponent(brand.name)).replace('{slug}',encodeURIComponent(brand.slug)).replace('{key}',encodeURIComponent(providerKey));
  const allowed=String(process.env.VEHICLE_LOGO_ALLOWED_HOSTS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);
  if(!allowed.length)throw new Error('VEHICLE_LOGO_ALLOWED_HOSTS_REQUIRED');
  try{
    const img=await fetchImage(source,allowed);
    const dir=process.env.VEHICLE_BRAND_LOGO_DIR||'/opt/heycar/uploads/vehicle-brands';fs.mkdirSync(dir,{recursive:true});
    const hash=crypto.createHash('sha256').update(img.buf).digest('hex').slice(0,12);
    const file=brand.slug+'-'+hash+'.'+img.meta.ext;fs.writeFileSync(path.join(dir,file),img.buf,{mode:0o644});
    const url=base+'/uploads/vehicle-brands/'+file;
    const q=await pool.query(`UPDATE vehicle_brands SET logo_url=$2,logo_source_url=$3,logo_storage_key=$4,logo_status='ready',logo_source='external',last_checked_at=NOW(),updated_at=NOW() WHERE id=$1 AND logo_source<>'manual' RETURNING *`,[brand.id,url,img.sourceUrl,file]);
    return q.rows[0]||brand;
  }catch(e){
    await pool.query(`UPDATE vehicle_brands SET logo_status='not_found',last_checked_at=NOW(),updated_at=NOW() WHERE id=$1 AND logo_source<>'manual'`,[brand.id]).catch(()=>{});
    throw e;
  }
}
function queueResolve(pool,make,base){
  const key=normalizeBrand(make);if(!key||inflight.has(key))return;
  const p=(async()=>{const b=await findBrand(pool,make);if(b&&b.logo_status!=='ready')await resolveExternal(pool,b,base);})()
    .catch(e=>console.error('vehicle brand logo resolve',key,e.message)).finally(()=>inflight.delete(key));
  inflight.set(key,p);
}
module.exports={normalizeBrand,findBrand,logoPayload,cachedLogo,resolveExternal,queueResolve,publicBase,imageMeta,assertPublicHttps};
