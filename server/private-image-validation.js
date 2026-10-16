// Accept only small JPEG, PNG or WebP images, never SVG or executable content.
const signatures={
 'image/jpeg':b=>b.length>=3&&b[0]===0xff&&b[1]===0xd8&&b[2]===0xff,
 'image/png':b=>b.length>=8&&b.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex')),
 'image/webp':b=>b.length>=12&&b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WEBP',
};
function parseImage(body){
 const mime=String(body?.mime||'').toLowerCase();
 const data=body?.data;
 if(!Object.prototype.hasOwnProperty.call(signatures,mime)||typeof data!=='string'||data.length>2800000||!/^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(data))return null;
 const bytes=Buffer.from(data,'base64');
 if(bytes.length<20||bytes.length>2*1024*1024||!signatures[mime](bytes))return null;
 return {bytes,mime};
}
module.exports={parseImage};
