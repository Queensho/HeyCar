// Extends the existing business and authenticated owner/driver APIs.
module.exports = function registerMarketplace(app, pool, {auth, offerActor}) {
  const wrap = fn => async (req,res) => {try {await fn(req,res);} catch(e) {console.error('marketplace',e);res.status(e.code==='22P02'?400:500).json({error:e.code==='22P02'?'INVALID_ID':'SERVER_ERROR'});}};
  const publicBusiness = `b.is_active AND b.approval_status='approved'`;
  app.get('/api/offers/categories',wrap(async(_req,res)=>{
    const q=await pool.query('SELECT id,name FROM offer_categories WHERE is_active ORDER BY sort_order,name');res.json({ok:true,categories:q.rows});
  }));
  app.get('/api/offers/discover',wrap(async(req,res)=>{
    const hasLocation=req.query.lat!=null&&req.query.lon!=null;
    if((req.query.lat!=null)!==(req.query.lon!=null))return res.status(400).json({error:'INVALID_LOCATION'});
    const lat=Number(req.query.lat),lon=Number(req.query.lon);
    if(hasLocation&&(!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180))return res.status(400).json({error:'INVALID_LOCATION'});
    const {getAppSettings}=require('./app-settings-service');
    if((await getAppSettings(pool)).features?.offers===false)return res.status(503).json({error:'OFFERS_FEATURE_DISABLED'});
    const q=String(req.query.q||'').trim().slice(0,120),category=String(req.query.category||'').slice(0,80),city=String(req.query.city||'').trim().slice(0,100);
    const rows=await pool.query(`SELECT c.id,c.title,c.description,c.terms,c.badge,c.starts_at,c.ends_at,c.image_url,c.offer_type,c.regular_price,c.offer_price,c.discount_percent,c.is_featured,
      b.id business_id,b.name,b.category,b.address,b.phone,b.opening_hours,b.logo_url,b.latitude,b.longitude,b.vehicle_types,
      stats.rating,COALESCE(stats.review_count,0) review_count,
      CASE WHEN $1::float8 IS NULL OR b.latitude IS NULL OR b.longitude IS NULL THEN NULL ELSE 6371000*2*asin(sqrt(LEAST(1.0,power(sin(radians(b.latitude-$1)/2),2)+cos(radians($1))*cos(radians(b.latitude))*power(sin(radians(b.longitude-$2)/2),2)))) END distance_m
      FROM businesses b LEFT JOIN business_campaigns c ON c.business_id=b.id AND c.is_active AND c.moderation_status='approved' AND now() BETWEEN c.starts_at AND c.ends_at
      LEFT JOIN LATERAL(SELECT round(avg(r.rating)::numeric,1) rating,count(*)::int review_count FROM offer_reviews r JOIN business_campaigns rc ON rc.id=r.campaign_id JOIN offer_redemptions rr ON rr.id=r.redemption_id AND rr.status='redeemed' WHERE rc.business_id=b.id AND r.moderation_status='approved') stats ON true
      WHERE ${publicBusiness}
      AND ($3='' OR b.name ILIKE '%'||$3||'%' OR c.title ILIKE '%'||$3||'%' OR c.description ILIKE '%'||$3||'%' OR EXISTS(SELECT 1 FROM business_services s WHERE s.business_id=b.id AND s.is_active AND s.name ILIKE '%'||$3||'%'))
      AND ($4='' OR EXISTS (SELECT 1 FROM unnest(regexp_split_to_array(b.category,'\\s*,\\s*')) AS cat WHERE cat ILIKE $4))
      AND ($5='' OR (b.city ILIKE '%'||$5||'%' OR b.district ILIKE '%'||$5||'%' OR b.address ILIKE '%'||$5||'%'))
      ORDER BY distance_m NULLS LAST,c.is_featured DESC,c.created_at DESC LIMIT 100`,[hasLocation?lat:null,hasLocation?lon:null,q,category,city]);
    res.json({ok:true,offers:rows.rows});
  }));
  app.get('/api/offers/history',wrap(async(req,res)=>{
    const actor=offerActor(req);if(!actor)return res.status(401).json({error:'AUTH_REQUIRED'});
    const q=await pool.query(`SELECT r.*,c.title,c.ends_at,b.name,b.address,rv.rating review_rating,rv.comment review_comment,rv.moderation_status review_status,
      CASE WHEN r.status='pending' AND (clock_timestamp()>c.ends_at OR NOT c.is_active OR c.moderation_status<>'approved' OR NOT b.is_active OR b.approval_status<>'approved') THEN 'expired' ELSE r.status END display_status
      FROM offer_redemptions r JOIN business_campaigns c ON c.id=r.campaign_id JOIN businesses b ON b.id=c.business_id LEFT JOIN offer_reviews rv ON rv.redemption_id=r.id
      WHERE r.owner_id=$1 AND r.actor_role=$2 ORDER BY r.created_at DESC LIMIT 100`,[actor.id,actor.role]);res.json({ok:true,redemptions:q.rows});
  }));
  app.post('/api/offers/businesses/:businessId/favorite',wrap(async(req,res)=>{
    const actor=offerActor(req);if(!actor)return res.status(401).json({error:'AUTH_REQUIRED'});
    const q=await pool.query(`INSERT INTO offer_business_favorites(owner_id,actor_role,business_id) SELECT $1,$2,id FROM businesses b WHERE b.id=$3 AND ${publicBusiness} ON CONFLICT(owner_id,actor_role,business_id) DO UPDATE SET business_id=EXCLUDED.business_id RETURNING business_id`,[actor.id,actor.role,req.params.businessId]);
    if(!q.rowCount)return res.status(404).json({error:'BUSINESS_NOT_FOUND'});res.json({ok:true,favorite:true});
  }));
  app.delete('/api/offers/businesses/:businessId/favorite',wrap(async(req,res)=>{
    const actor=offerActor(req);if(!actor)return res.status(401).json({error:'AUTH_REQUIRED'});
    const db=await pool.connect();try{await db.query('BEGIN');
      await db.query('DELETE FROM offer_business_favorites WHERE owner_id=$1 AND actor_role=$2 AND business_id=$3',[actor.id,actor.role,req.params.businessId]);
      await db.query(`DELETE FROM offer_favorites f USING business_campaigns c WHERE f.campaign_id=c.id AND f.owner_id=$1 AND f.actor_role IN ($2,'legacy') AND c.business_id=$3`,[actor.id,actor.role,req.params.businessId]);
      await db.query('COMMIT');res.json({ok:true,favorite:false});
    }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
  }));
  app.get('/api/offers/saved',wrap(async(req,res)=>{
    const actor=offerActor(req);if(!actor)return res.status(401).json({error:'AUTH_REQUIRED'});
    const q=await pool.query(`WITH saved AS (
      SELECT business_id,created_at FROM offer_business_favorites WHERE owner_id=$1 AND actor_role=$2
      UNION SELECT c.business_id,f.created_at FROM offer_favorites f JOIN business_campaigns c ON c.id=f.campaign_id WHERE f.owner_id=$1 AND f.actor_role IN ($2,'legacy'))
      SELECT DISTINCT ON(b.id) c.id,c.title,c.description,c.terms,c.badge,c.starts_at,c.ends_at,c.image_url,b.id business_id,b.name,b.address,b.category,b.logo_url,b.opening_hours
      FROM saved f JOIN businesses b ON b.id=f.business_id LEFT JOIN LATERAL(SELECT * FROM business_campaigns c WHERE c.business_id=b.id AND c.moderation_status='approved' ORDER BY (c.is_active AND now() BETWEEN c.starts_at AND c.ends_at) DESC,c.ends_at DESC LIMIT 1)c ON true
      WHERE ${publicBusiness} ORDER BY b.id,f.created_at DESC`,[actor.id,actor.role]);res.json({ok:true,offers:q.rows});
  }));
  app.get('/api/offers/businesses/:businessId',wrap(async(req,res)=>{
    const b=await pool.query(`SELECT b.id,b.name,b.category,b.phone,b.address,b.latitude,b.longitude,b.opening_hours,b.description,b.logo_url,b.gallery_urls,b.vehicle_types,b.approval_status FROM businesses b WHERE b.id=$1 AND ${publicBusiness}`,[req.params.businessId]);
    if(!b.rowCount)return res.status(404).json({error:'BUSINESS_NOT_FOUND'});
    const id=req.params.businessId;
    const [services,campaigns,reviews,rating]=await Promise.all([
      pool.query('SELECT * FROM business_services WHERE business_id=$1 AND is_active ORDER BY name',[id]),
      pool.query(`SELECT id,title,description,terms,badge,image_url,starts_at,ends_at,regular_price,offer_price,is_active,(is_active AND now() BETWEEN starts_at AND ends_at) available FROM business_campaigns WHERE business_id=$1 AND moderation_status='approved' ORDER BY ends_at DESC`,[id]),
      pool.query(`SELECT r.rating,r.comment,r.created_at FROM offer_reviews r JOIN offer_redemptions rr ON rr.id=r.redemption_id AND rr.status='redeemed' JOIN business_campaigns c ON c.id=r.campaign_id WHERE c.business_id=$1 AND r.moderation_status='approved' ORDER BY r.created_at DESC LIMIT 50`,[id]),
      pool.query(`SELECT round(avg(r.rating)::numeric,1) rating,count(*)::int review_count FROM offer_reviews r JOIN offer_redemptions rr ON rr.id=r.redemption_id AND rr.status='redeemed' JOIN business_campaigns c ON c.id=r.campaign_id WHERE c.business_id=$1 AND r.moderation_status='approved'`,[id])
    ]);
    res.json({ok:true,business:b.rows[0],services:services.rows,campaigns:campaigns.rows,reviews:reviews.rows,rating:rating.rows[0].rating,reviewCount:rating.rows[0].review_count});
  }));
  app.get('/api/business/services',wrap(async(req,res)=>{
    const account=await auth(req,res);if(!account)return;
    const q=await pool.query('SELECT s.* FROM business_services s JOIN businesses b ON b.id=s.business_id WHERE b.account_id=$1 ORDER BY s.name',[account]);res.json({ok:true,services:q.rows});
  }));
  app.post('/api/business/services',wrap(async(req,res)=>{
    const account=await auth(req,res);if(!account)return;
    const name=String(req.body?.name||'').trim(),price=Number(req.body?.price);
    if(!name||name.length>120||req.body?.price==null||!Number.isFinite(price)||price<0||price>9999999999)return res.status(400).json({error:'INVALID_SERVICE'});
    const q=await pool.query('INSERT INTO business_services(business_id,name,price) SELECT id,$2,$3 FROM businesses WHERE account_id=$1 RETURNING *',[account,name,price]);res.status(201).json({ok:true,service:q.rows[0]});
  }));
  app.patch('/api/business/services/:id',wrap(async(req,res)=>{
    const account=await auth(req,res);if(!account)return;
    const name=String(req.body?.name||'').trim(),price=req.body?.price;
    if(!name||name.length>120||typeof price!=='number'||!Number.isFinite(price)||price<0||price>9999999999)return res.status(400).json({error:'INVALID_SERVICE'});
    const q=await pool.query('UPDATE business_services s SET name=$3,price=$4 FROM businesses b WHERE s.business_id=b.id AND b.account_id=$1 AND s.id=$2 RETURNING s.*',[account,req.params.id,name,price]);
    if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true,service:q.rows[0]});
  }));
  app.delete('/api/business/services/:id',wrap(async(req,res)=>{
    const account=await auth(req,res);if(!account)return;
    const q=await pool.query('DELETE FROM business_services s USING businesses b WHERE s.business_id=b.id AND b.account_id=$1 AND s.id=$2 RETURNING s.id',[account,req.params.id]);if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true});
  }));
  app.patch('/api/business/profile-media',wrap(async(req,res)=>{
    const account=await auth(req,res);if(!account)return;
    const gallery=req.body?.galleryUrls,types=req.body?.vehicleTypes;
    if(!Array.isArray(gallery)||gallery.length>12||gallery.some(x=>typeof x!=='string'||x.length>2048||!x.startsWith('https://'))||!Array.isArray(types)||!types.length||types.some(x=>!['car','motorcycle','commercial','truck'].includes(x)))return res.status(400).json({error:'INVALID_PROFILE'});
    const q=await pool.query('UPDATE businesses SET gallery_urls=$2::jsonb,vehicle_types=$3,updated_at=now() WHERE account_id=$1 RETURNING gallery_urls,vehicle_types',[account,JSON.stringify(gallery),types]);res.json({ok:true,business:q.rows[0]});
  }));
};
