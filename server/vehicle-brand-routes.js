const express=require('express');
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const {writeAdminAudit}=require('./admin-audit');
const {findBrand,logoPayload,resolveExternal,publicBase,imageMeta,normalizeBrand}=require('./vehicle-brand-logo-service');

function clean(v,n=160){return String(v==null?'':v).trim().slice(0,n);}
module.exports=function registerVehicleBrandRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
  const dir=process.env.VEHICLE_BRAND_LOGO_DIR||'/opt/heycar/uploads/vehicle-brands';
  try{fs.mkdirSync(dir,{recursive:true});}catch(e){console.error('vehicle brand logo dir',e);}

  app.get('/uploads/vehicle-brands/:name',(req,res)=>{
    const name=path.basename(clean(req.params.name,180));
    if(!/^[a-z0-9-]+-[a-f0-9]{12}\.(png|jpg|webp)$/i.test(name))return res.status(404).end();
    return res.sendFile(path.join(dir,name));
  });

  app.get('/api/vehicle-brands',async(_req,res)=>{
    try{
      const q=await pool.query(`SELECT id,name,normalized_name,logo_url,logo_status,logo_source FROM vehicle_brands ORDER BY name`);
      return res.json({ok:true,brands:q.rows.map(x=>({id:x.id,name:x.name,normalizedName:x.normalized_name,brandLogo:logoPayload(x)}))});
    }catch(e){console.error('vehicle brands',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/vehicle-brands',guard,async(_req,res)=>{
    try{
      const q=await pool.query(`SELECT b.*,COALESCE(json_agg(a.alias ORDER BY a.alias) FILTER(WHERE a.id IS NOT NULL),'[]') aliases FROM vehicle_brands b LEFT JOIN vehicle_brand_aliases a ON a.brand_id=b.id GROUP BY b.id ORDER BY b.name`);
      return res.json({ok:true,brands:q.rows.map(x=>({...x,brandLogo:logoPayload(x)}))});
    }catch(e){console.error('admin brands',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/admin/vehicle-brands/:id/logo',guard,express.raw({type:'application/octet-stream',limit:'2mb'}),async(req,res)=>{
    try{
      const old=await pool.query('SELECT * FROM vehicle_brands WHERE id::text=$1 LIMIT 1',[req.params.id]);if(!old.rowCount)return res.status(404).json({error:'BRAND_NOT_FOUND'});
      const mime=clean(req.headers['x-file-type'],60).toLowerCase(),buf=Buffer.isBuffer(req.body)?req.body:Buffer.alloc(0);
      if(!buf.length||buf.length>2*1024*1024)return res.status(413).json({error:'IMAGE_TOO_LARGE'});
      const meta=imageMeta(buf,mime),hash=crypto.createHash('sha256').update(buf).digest('hex').slice(0,12),file=old.rows[0].slug+'-'+hash+'.'+meta.ext;
      fs.writeFileSync(path.join(dir,file),buf,{mode:0o644});
      const url=publicBase(req)+'/uploads/vehicle-brands/'+file;
      const q=await pool.query(`UPDATE vehicle_brands SET logo_url=$2,logo_source_url=NULL,logo_storage_key=$3,logo_status='ready',logo_source='manual',last_checked_at=NOW(),updated_at=NOW() WHERE id::text=$1 RETURNING *`,[req.params.id,url,file]);
      await writeAdminAudit(pool,req,{action:'vehicle_brand.logo_manual',targetType:'vehicle_brand',targetId:q.rows[0].id,targetLabel:q.rows[0].name});
      return res.json({ok:true,brand:{...q.rows[0],brandLogo:logoPayload(q.rows[0])}});
    }catch(e){console.error('manual brand logo',e);return res.status(400).json({error:e.message||'INVALID_IMAGE'});}
  });

  app.post('/api/admin/vehicle-brands/:id/resolve',guard,async(req,res)=>{
    try{
      const q=await pool.query('SELECT * FROM vehicle_brands WHERE id::text=$1 LIMIT 1',[req.params.id]);if(!q.rowCount)return res.status(404).json({error:'BRAND_NOT_FOUND'});
      if(q.rows[0].logo_source==='manual')return res.status(409).json({error:'MANUAL_LOGO_PROTECTED'});
      await pool.query(`UPDATE vehicle_brands SET logo_status='pending',last_checked_at=NULL WHERE id::text=$1`,[req.params.id]);
      const b=await findBrand(pool,q.rows[0].name),resolved=await resolveExternal(pool,b,publicBase(req));
      await writeAdminAudit(pool,req,{action:'vehicle_brand.logo_resolved',targetType:'vehicle_brand',targetId:b.id,targetLabel:b.name});
      return res.json({ok:true,brand:{...resolved,brandLogo:logoPayload(resolved)}});
    }catch(e){console.error('resolve brand logo',e);return res.status(502).json({error:e.message||'LOGO_RESOLVE_FAILED'});}
  });

  app.post('/api/admin/vehicle-brands/:id/aliases',guard,async(req,res)=>{
    try{
      const alias=clean(req.body?.alias,100),norm=normalizeBrand(alias);if(!norm)return res.status(400).json({error:'ALIAS_REQUIRED'});
      const q=await pool.query(`INSERT INTO vehicle_brand_aliases(brand_id,alias,normalized_alias) SELECT id,$2,$3 FROM vehicle_brands WHERE id::text=$1 ON CONFLICT(normalized_alias) DO UPDATE SET brand_id=EXCLUDED.brand_id,alias=EXCLUDED.alias RETURNING *`,[req.params.id,alias,norm]);
      if(!q.rowCount)return res.status(404).json({error:'BRAND_NOT_FOUND'});
      await writeAdminAudit(pool,req,{action:'vehicle_brand.alias_saved',targetType:'vehicle_brand',targetId:req.params.id,targetLabel:alias});
      return res.json({ok:true,alias:q.rows[0]});
    }catch(e){console.error('brand alias',e);return res.status(400).json({error:'ALIAS_SAVE_FAILED'});}
  });
};
