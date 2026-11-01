'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {decodeBusinessImage}=require('../business-image');
const data=(type,buf)=>'data:image/'+type+';base64,'+buf.toString('base64');
test('rejects executable content disguised as a supported image type',()=>{
 for(const mime of ['png','jpeg','webp'])assert.equal(decodeBusinessImage(data(mime,Buffer.from('<svg onload="alert(1)"></svg>'))).error,'INVALID_IMAGE');
});
test('enforces canonical base64, MIME signature and upload size',()=>{
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
 assert.equal(decodeBusinessImage(data('png',png)).ext,'png');
 assert.equal(decodeBusinessImage(data('jpeg',png)).error,'INVALID_IMAGE');
 assert.equal(decodeBusinessImage('data:image/png;base64,!!!!').status,400);
 assert.equal(decodeBusinessImage(data('png',Buffer.alloc(2500001))).status,413);
});
