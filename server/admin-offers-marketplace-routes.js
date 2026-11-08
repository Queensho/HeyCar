const {writeAdminAudit}=require('./admin-audit');
module.exports=function(app,pool,guard){
  const wrap=fn=>async(req,res)=>{try{await fn(req,res);}catch(e){console.error('admin marketplace',e);res.status(['22P02','23505','23514'].includes(e.code)?400:500).json({error:'MARKETPLACE_UPDATE_FAILED'});}};
  app.get('/api/admin/manage/offer-reviews',guard,wrap(async(req,res)=>{
    const status=String(req.query.status||'pending');if(!['all','pending','approved','rejected'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    const q=await pool.query(`SELECT r.*,b.name business_name,c.title campaign_title FROM offer_reviews r JOIN business_campaigns c ON c.id=r.campaign_id JOIN businesses b ON b.id=c.business_id WHERE $1='all' OR r.moderation_status=$1 ORDER BY r.updated_at DESC LIMIT 200`,[status]);res.json({ok:true,reviews:q.rows});
  }));
  app.patch('/api/admin/manage/offer-reviews/:id',guard,wrap(async(req,res)=>{
    const status=req.body?.status,note=String(req.body?.note||'').slice(0,2000);
    if(!['approved','rejected','pending'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    // Optimistic version prevents approving text edited after the moderator read it.
    if(!Number.isInteger(req.body?.revision))return res.status(400).json({error:'REVIEW_VERSION_REQUIRED'});
    const q=await pool.query('UPDATE offer_reviews SET moderation_status=$2,moderation_note=$3,reviewed_at=now() WHERE id=$1 AND revision=$4::int RETURNING *',[req.params.id,status,note,req.body.revision]);
    if(!q.rowCount)return res.status(409).json({error:'REVIEW_CHANGED'});
    await writeAdminAudit(pool,req,{action:'offer.review.'+status,targetType:'offer_review',targetId:req.params.id,details:{note}});
    res.json({ok:true,review:q.rows[0]});
  }));
  app.get('/api/admin/manage/offer-categories',guard,wrap(async(_req,res)=>{const q=await pool.query('SELECT * FROM offer_categories ORDER BY sort_order,name');res.json({ok:true,categories:q.rows});}));
  app.post('/api/admin/manage/offer-categories',guard,wrap(async(req,res)=>{
    const name=String(req.body?.name||'').trim();if(!name||name.length>80)return res.status(400).json({error:'INVALID_CATEGORY'});
    const q=await pool.query('INSERT INTO offer_categories(name) VALUES($1) RETURNING *',[name]);await writeAdminAudit(pool,req,{action:'offer.category.create',targetType:'offer_category',targetId:q.rows[0].id,details:{name}});res.status(201).json({ok:true,category:q.rows[0]});
  }));
  app.patch('/api/admin/manage/offer-categories/:id',guard,wrap(async(req,res)=>{
    if(typeof req.body?.isActive!=='boolean')return res.status(400).json({error:'INVALID_CATEGORY'});
    const q=await pool.query('UPDATE offer_categories SET is_active=$2 WHERE id=$1 RETURNING *',[req.params.id,req.body.isActive]);if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});
    await writeAdminAudit(pool,req,{action:'offer.category.update',targetType:'offer_category',targetId:req.params.id,details:{isActive:req.body.isActive}});res.json({ok:true,category:q.rows[0]});
  }));
  app.patch('/api/admin/manage/campaigns/:id/featured',guard,wrap(async(req,res)=>{
    if(typeof req.body?.featured!=='boolean')return res.status(400).json({error:'INVALID_FEATURED'});
    const q=await pool.query(`UPDATE business_campaigns SET is_featured=$2 WHERE id=$1 AND moderation_status='approved' RETURNING id,is_featured`,[req.params.id,req.body.featured]);
    if(!q.rowCount)return res.status(404).json({error:'APPROVED_CAMPAIGN_REQUIRED'});
    await writeAdminAudit(pool,req,{action:'offer.featured.update',targetType:'business_campaign',targetId:req.params.id,details:{featured:req.body.featured}});res.json({ok:true,campaign:q.rows[0]});
  }));
};
