'use strict';
// Loaded only by the staging patch; production returns before any filesystem work.
module.exports=(app)=>{
 if(process.env.APP_ENV!=='staging'||process.env.PORT!=='8091')return;
 const fs=require('node:fs'),assert=require('node:assert/strict'),express=require('express');
 assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');
 const root=fs.realpathSync('/home/cepqontag-deploy/car-wash-phase4-web/current');
 assert.match(root,/^\/home\/cepqontag-deploy\/car-wash-phase4-web\/releases\/[0-9a-f]{40}$/);
 for(const [prefix,folder] of [['/car-wash-business/','business'],['/car-wash-owner/','owner']]){
  const directory=fs.realpathSync(root+'/'+folder);assert.equal(directory,root+'/'+folder);
  app.use(prefix,(req,res,next)=>{
   res.set('Cache-Control','no-store');res.set('X-Robots-Tag','noindex, nofollow');
   res.set('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self'; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'");next();
  },express.static(directory,{dotfiles:'deny',index:'index.html',redirect:true}));
 }
};
