'use strict';
const LIMIT=2500000;
function decodeBusinessImage(raw){
 if(typeof raw!=='string')return {error:'INVALID_IMAGE',status:400};
 const match=raw.match(/^data:image\/(jpeg|jpg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$/);
 if(!match||match[2].length%4!==0)return {error:'INVALID_IMAGE',status:400};
 if(match[2].length>4*Math.ceil(LIMIT/3))return {error:'IMAGE_TOO_LARGE',status:413};
 const buffer=Buffer.from(match[2],'base64');
 if(buffer.length>LIMIT)return {error:'IMAGE_TOO_LARGE',status:413};
 if(buffer.toString('base64')!==match[2])return {error:'INVALID_IMAGE',status:400};
 const ext=match[1]==='jpeg'?'jpg':match[1];
 const valid=ext==='jpg'?buffer.length>=3&&buffer[0]===255&&buffer[1]===216&&buffer[2]===255:
  ext==='png'?buffer.length>=24&&buffer.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))&&buffer.toString('ascii',12,16)==='IHDR'&&buffer.readUInt32BE(16)>0&&buffer.readUInt32BE(20)>0&&buffer.readUInt32BE(16)*buffer.readUInt32BE(20)<=40000000:
  buffer.length>=12&&buffer.toString('ascii',0,4)==='RIFF'&&buffer.toString('ascii',8,12)==='WEBP';
 return valid?{buffer,ext}:{error:'INVALID_IMAGE',status:400};
}
module.exports={decodeBusinessImage};
