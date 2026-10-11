'use strict';

// A verified motorcycle-specific image source, used by the existing cached
// brand-logo API. Never fetch arbitrary URLs from users/vehicle records.
// RKS's mark is not present in the car-logos-dataset used by car brands.
// Future manufacturers can be added here after verifying the actual image.
// Manual logos uploaded from admin always take precedence.
const sources=Object.freeze({
  rks: Object.freeze({
    url:'https://rksmoto.com/upload/1724395399-66c82f8797f76.png',
    allowedHosts:Object.freeze(['rksmoto.com']),
  }),
});

function motorcycleLogoSource(make,vehicleType){
  if(String(vehicleType||'').trim().toLowerCase()!=='motorcycle')return null;
  const normalized=String(make||'').trim().toLocaleLowerCase('tr-TR')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g,'')
    .replace(/ı/g,'i').replace(/[^a-z0-9]+/g,'');
  return sources[normalized]||null;
}

module.exports={motorcycleLogoSource};
