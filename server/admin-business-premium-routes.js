const {writeAdminAudit}=require('./admin-audit');

async function tableExists(pool,name){
  const r=await pool.query('SELECT to_regclass($1) AS name',['public.'+name]);
  return Boolean(r.rows[0]?.name);
}
function actor(req){
  return {
    id:String(req.headers?.['x-admin-id']||'').trim()||null,
    email:String(req.headers?.['x-admin-email']||'').trim()||null,
    name:String(req.headers?.['x-admin-name']||'').trim()||null,
  };
}
function num(v){
  if(v===null||v===undefined||v==='')return null;
  const n=Number(v);
  return Number.isFinite(n)?n:null;
}
function isoOrNull(v){
  if(v===null||v===undefined||v==='')return null;
  const d=new Date(v);
  return Number.isNaN(d.getTime())?null:d.toISOString();
}

module.exports=function registerAdminBusinessPremiumRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  app.get('/api/admin/manage/businesses',guard,async(req,res)=>{
    const status=String(req.query?.status||'all').trim();
    try{
      const r=await pool.query(
        `SELECT b.id,b.account_id,b.name,b.category,b.phone,b.address,b.latitude,b.longitude,
                b.opening_hours,b.description,b.logo_url,b.is_active,b.approval_status,b.admin_note,
                b.reviewed_at,b.reviewed_by,b.created_at,b.updated_at,a.email,
                COUNT(DISTINCT c.id)::int AS campaign_count,
                COUNT(DISTINCT c.id) FILTER(WHERE c.moderation_status='pending')::int AS pending_campaigns,
                COUNT(DISTINCT red.id) FILTER(WHERE red.status='redeemed')::int AS redeemed_count,
                COALESCE(SUM(red.platform_fee) FILTER(WHERE red.status='redeemed'),0)::numeric AS platform_fees
           FROM businesses b
           JOIN business_accounts a ON a.id=b.account_id
           LEFT JOIN business_campaigns c ON c.business_id=b.id
           LEFT JOIN offer_redemptions red ON red.campaign_id=c.id
          WHERE ($1='all')
             OR ($1='inactive' AND b.is_active=FALSE)
             OR ($1 IN ('pending','approved','rejected') AND b.approval_status=$1)
          GROUP BY b.id,a.email
          ORDER BY CASE b.approval_status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,b.created_at DESC
          LIMIT 300`,
        [status]
      );
      const s=await pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER(WHERE approval_status='pending')::int AS pending,
                COUNT(*) FILTER(WHERE approval_status='approved')::int AS approved,
                COUNT(*) FILTER(WHERE approval_status='rejected')::int AS rejected,
                COUNT(*) FILTER(WHERE is_active=FALSE)::int AS inactive
           FROM businesses`
      );
      res.json({ok:true,status,summary:s.rows[0]||{},items:r.rows});
    }catch(e){console.error('admin businesses',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/businesses/:businessId',guard,async(req,res)=>{
    const id=String(req.params.businessId||'').trim();
    const body=req.body||{};
    const approval=body.approvalStatus;
    if(approval!==undefined&&!['pending','approved','rejected'].includes(String(approval)))return res.status(400).json({error:'INVALID_APPROVAL_STATUS'});
    try{
      const before=await pool.query('SELECT * FROM businesses WHERE id::text=$1 LIMIT 1',[id]);
      if(!before.rowCount)return res.status(404).json({error:'BUSINESS_NOT_FOUND'});
      const reviewed=approval!==undefined&&String(approval)!=='pending';
      const a=actor(req);
      const q=await pool.query(
        `UPDATE businesses SET
           name=COALESCE($2,name),
           category=COALESCE($3,category),
           phone=CASE WHEN $4::boolean THEN $5 ELSE phone END,
           address=CASE WHEN $6::boolean THEN $7 ELSE address END,
           latitude=CASE WHEN $8::boolean THEN $9 ELSE latitude END,
           longitude=CASE WHEN $10::boolean THEN $11 ELSE longitude END,
           opening_hours=CASE WHEN $12::boolean THEN $13 ELSE opening_hours END,
           description=CASE WHEN $14::boolean THEN $15 ELSE description END,
           logo_url=CASE WHEN $16::boolean THEN $17 ELSE logo_url END,
           is_active=COALESCE($18,is_active),
           approval_status=COALESCE($19,approval_status),
           admin_note=CASE WHEN $20::boolean THEN $21 ELSE admin_note END,
           reviewed_at=CASE WHEN $22::boolean THEN NOW() WHEN $19='pending' THEN NULL ELSE reviewed_at END,
           reviewed_by=CASE WHEN $22::boolean THEN $23 WHEN $19='pending' THEN NULL ELSE reviewed_by END,
           updated_at=NOW()
         WHERE id::text=$1 RETURNING *`,
        [
          id,
          body.name==null?null:String(body.name).trim()||null,
          body.category==null?null:String(body.category).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'phone'),body.phone==null?null:String(body.phone).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'address'),body.address==null?null:String(body.address).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'latitude'),num(body.latitude),
          Object.prototype.hasOwnProperty.call(body,'longitude'),num(body.longitude),
          Object.prototype.hasOwnProperty.call(body,'openingHours'),body.openingHours==null?null:String(body.openingHours).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'description'),body.description==null?null:String(body.description).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'logoUrl'),body.logoUrl==null?null:String(body.logoUrl).trim()||null,
          typeof body.isActive==='boolean'?body.isActive:null,
          approval===undefined?null:String(approval),
          Object.prototype.hasOwnProperty.call(body,'adminNote'),body.adminNote==null?null:String(body.adminNote).trim().slice(0,1500),
          reviewed,
          a.email||a.name||a.id||'admin'
        ]
      );
      if(String(approval)==='rejected'||body.isActive===false){
        await pool.query('UPDATE business_campaigns SET is_active=FALSE,updated_at=NOW() WHERE business_id=$1',[q.rows[0].id]);
      }
      await writeAdminAudit(pool,req,{
        action:String(approval)==='approved'?'business.approved':String(approval)==='rejected'?'business.rejected':body.isActive===false?'business.deactivated':body.isActive===true?'business.activated':'business.updated',
        targetType:'business',targetId:id,targetLabel:q.rows[0].name,before:before.rows[0],after:q.rows[0]
      });
      res.json({ok:true,business:q.rows[0]});
    }catch(e){console.error('admin business update',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/business-campaigns',guard,async(req,res)=>{
    const status=String(req.query?.status||'all').trim();
    try{
      const r=await pool.query(
        `SELECT c.*,b.name AS business_name,b.approval_status AS business_approval,b.is_active AS business_active,
                b.logo_url AS business_logo,b.address AS business_address,
                (SELECT COUNT(*)::int FROM offer_redemptions red WHERE red.campaign_id=c.id AND red.status='redeemed') AS redeemed_count,
                (SELECT COUNT(*)::int FROM offer_redemptions red WHERE red.campaign_id=c.id AND red.status='pending') AS pending_redemptions,
                (SELECT COALESCE(SUM(red.platform_fee),0)::numeric FROM offer_redemptions red WHERE red.campaign_id=c.id AND red.status='redeemed') AS earned_platform_fee,
                (SELECT ROUND(AVG(rv.rating)::numeric,2) FROM offer_reviews rv WHERE rv.campaign_id=c.id) AS rating
           FROM business_campaigns c
           JOIN businesses b ON b.id=c.business_id
          WHERE ($1='all')
             OR ($1='inactive' AND c.is_active=FALSE)
             OR ($1 IN ('pending','approved','rejected') AND c.moderation_status=$1)
          ORDER BY CASE c.moderation_status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,c.created_at DESC
          LIMIT 400`,
        [status]
      );
      const s=await pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER(WHERE moderation_status='pending')::int AS pending,
                COUNT(*) FILTER(WHERE moderation_status='approved')::int AS approved,
                COUNT(*) FILTER(WHERE moderation_status='rejected')::int AS rejected,
                COUNT(*) FILTER(WHERE is_active=FALSE)::int AS inactive
           FROM business_campaigns`
      );
      res.json({ok:true,status,summary:s.rows[0]||{},items:r.rows});
    }catch(e){console.error('admin campaigns',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/business-campaigns/:campaignId',guard,async(req,res)=>{
    const id=String(req.params.campaignId||'').trim(),body=req.body||{};
    const moderation=body.moderationStatus;
    if(moderation!==undefined&&!['pending','approved','rejected'].includes(String(moderation)))return res.status(400).json({error:'INVALID_MODERATION_STATUS'});
    try{
      const before=await pool.query(`SELECT c.*,b.approval_status AS business_approval,b.is_active AS business_active FROM business_campaigns c JOIN businesses b ON b.id=c.business_id WHERE c.id::text=$1 LIMIT 1`,[id]);
      if(!before.rowCount)return res.status(404).json({error:'CAMPAIGN_NOT_FOUND'});
      if(String(moderation)==='approved'&&(before.rows[0].business_approval!=='approved'||before.rows[0].business_active!==true))return res.status(409).json({error:'BUSINESS_NOT_APPROVED'});
      const start=body.startsAt===undefined?undefined:isoOrNull(body.startsAt);
      const end=body.endsAt===undefined?undefined:isoOrNull(body.endsAt);
      if(body.startsAt!==undefined&&!start)return res.status(400).json({error:'INVALID_START_DATE'});
      if(body.endsAt!==undefined&&!end)return res.status(400).json({error:'INVALID_END_DATE'});
      const reviewed=moderation!==undefined&&String(moderation)!=='pending';
      const a=actor(req);
      const q=await pool.query(
        `UPDATE business_campaigns SET
          title=COALESCE($2,title),
          description=CASE WHEN $3::boolean THEN $4 ELSE description END,
          badge=CASE WHEN $5::boolean THEN $6 ELSE badge END,
          coupon_code=CASE WHEN $7::boolean THEN $8 ELSE coupon_code END,
          starts_at=COALESCE($9,starts_at),
          ends_at=COALESCE($10,ends_at),
          daily_limit=CASE WHEN $11::boolean THEN $12 ELSE daily_limit END,
          total_limit=CASE WHEN $13::boolean THEN $14 ELSE total_limit END,
          offer_type=COALESCE($15,offer_type),
          regular_price=CASE WHEN $16::boolean THEN $17 ELSE regular_price END,
          offer_price=CASE WHEN $18::boolean THEN $19 ELSE offer_price END,
          discount_percent=CASE WHEN $20::boolean THEN $21 ELSE discount_percent END,
          platform_fee=COALESCE($22,platform_fee),
          image_url=CASE WHEN $23::boolean THEN $24 ELSE image_url END,
          is_active=COALESCE($25,is_active),
          moderation_status=COALESCE($26,moderation_status),
          admin_note=CASE WHEN $27::boolean THEN $28 ELSE admin_note END,
          reviewed_at=CASE WHEN $29::boolean THEN NOW() WHEN $26='pending' THEN NULL ELSE reviewed_at END,
          reviewed_by=CASE WHEN $29::boolean THEN $30 WHEN $26='pending' THEN NULL ELSE reviewed_by END,
          updated_at=NOW()
         WHERE id::text=$1 RETURNING *`,
        [
          id,body.title==null?null:String(body.title).trim()||null,
          Object.prototype.hasOwnProperty.call(body,'description'),body.description==null?'':String(body.description),
          Object.prototype.hasOwnProperty.call(body,'badge'),body.badge==null?'':String(body.badge),
          Object.prototype.hasOwnProperty.call(body,'couponCode'),body.couponCode==null?null:String(body.couponCode).trim()||null,
          start||null,end||null,
          Object.prototype.hasOwnProperty.call(body,'dailyLimit'),body.dailyLimit==null?null:Number(body.dailyLimit),
          Object.prototype.hasOwnProperty.call(body,'totalLimit'),body.totalLimit==null?null:Number(body.totalLimit),
          body.offerType==null?null:String(body.offerType),
          Object.prototype.hasOwnProperty.call(body,'regularPrice'),num(body.regularPrice),
          Object.prototype.hasOwnProperty.call(body,'offerPrice'),num(body.offerPrice),
          Object.prototype.hasOwnProperty.call(body,'discountPercent'),body.discountPercent==null?null:Number(body.discountPercent),
          num(body.platformFee),
          Object.prototype.hasOwnProperty.call(body,'imageUrl'),body.imageUrl==null?null:String(body.imageUrl).trim()||null,
          typeof body.isActive==='boolean'?body.isActive:null,
          moderation===undefined?null:String(moderation),
          Object.prototype.hasOwnProperty.call(body,'adminNote'),body.adminNote==null?null:String(body.adminNote).trim().slice(0,1500),
          reviewed,a.email||a.name||a.id||'admin'
        ]
      );
      if(String(moderation)==='rejected')await pool.query('UPDATE business_campaigns SET is_active=FALSE WHERE id=$1',[q.rows[0].id]);
      if(String(moderation)==='approved'&&body.isActive===undefined)await pool.query('UPDATE business_campaigns SET is_active=TRUE WHERE id=$1',[q.rows[0].id]);
      const final=await pool.query('SELECT * FROM business_campaigns WHERE id=$1',[q.rows[0].id]);
      await writeAdminAudit(pool,req,{
        action:String(moderation)==='approved'?'campaign.approved':String(moderation)==='rejected'?'campaign.rejected':body.isActive===false?'campaign.unpublished':'campaign.updated',
        targetType:'business_campaign',targetId:id,targetLabel:final.rows[0].title,before:before.rows[0],after:final.rows[0]
      });
      res.json({ok:true,campaign:final.rows[0]});
    }catch(e){console.error('admin campaign update',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/offer-revenue',guard,async(req,res)=>{
    const days=[7,30,90,365].includes(Number(req.query?.days))?Number(req.query.days):30;
    try{
      const summary=await pool.query(
        `SELECT COUNT(*) FILTER(WHERE r.status='redeemed' AND r.redeemed_at>=NOW()-($1::text||' days')::interval)::int AS redeemed,
                COUNT(*) FILTER(WHERE r.status='pending' AND r.created_at>=NOW()-($1::text||' days')::interval)::int AS pending,
                COUNT(*) FILTER(WHERE r.status='cancelled' AND r.created_at>=NOW()-($1::text||' days')::interval)::int AS cancelled,
                COALESCE(SUM(r.platform_fee) FILTER(WHERE r.status='redeemed' AND r.redeemed_at>=NOW()-($1::text||' days')::interval),0)::numeric AS platform_fees,
                COUNT(DISTINCT c.business_id) FILTER(WHERE r.status='redeemed' AND r.redeemed_at>=NOW()-($1::text||' days')::interval)::int AS businesses_with_usage
           FROM offer_redemptions r
           JOIN business_campaigns c ON c.id=r.campaign_id`,
        [days]
      );
      const daily=await pool.query(
        `SELECT TO_CHAR(d.day,'YYYY-MM-DD') AS day,
                COALESCE(x.redeemed,0)::int AS redeemed,
                COALESCE(x.fees,0)::numeric AS platform_fees
           FROM generate_series(CURRENT_DATE-($1::int-1),CURRENT_DATE,INTERVAL '1 day') d(day)
           LEFT JOIN (
             SELECT redeemed_at::date AS day,COUNT(*)::int AS redeemed,COALESCE(SUM(platform_fee),0)::numeric AS fees
               FROM offer_redemptions
              WHERE status='redeemed' AND redeemed_at>=CURRENT_DATE-($1::int-1)
              GROUP BY redeemed_at::date
           ) x ON x.day=d.day::date
          ORDER BY d.day`,
        [days]
      );
      const businesses=await pool.query(
        `SELECT b.id,b.name,b.category,b.logo_url,
                COUNT(r.id) FILTER(WHERE r.status='redeemed')::int AS redeemed,
                COUNT(r.id) FILTER(WHERE r.status='pending')::int AS pending,
                COALESCE(SUM(r.platform_fee) FILTER(WHERE r.status='redeemed'),0)::numeric AS platform_fees
           FROM businesses b
           LEFT JOIN business_campaigns c ON c.business_id=b.id
           LEFT JOIN offer_redemptions r ON r.campaign_id=c.id
             AND ((r.status='redeemed' AND r.redeemed_at>=NOW()-($1::text||' days')::interval)
               OR (r.status<>'redeemed' AND r.created_at>=NOW()-($1::text||' days')::interval))
          GROUP BY b.id
         HAVING COUNT(r.id)>0
          ORDER BY platform_fees DESC,redeemed DESC LIMIT 100`,
        [days]
      );
      const items=await pool.query(
        `SELECT r.id,r.owner_id,r.plate,r.usage_code,r.status,r.platform_fee,r.created_at,r.redeemed_at,
                c.id AS campaign_id,c.title AS campaign_title,b.id AS business_id,b.name AS business_name
           FROM offer_redemptions r
           JOIN business_campaigns c ON c.id=r.campaign_id
           JOIN businesses b ON b.id=c.business_id
          WHERE r.created_at>=NOW()-($1::text||' days')::interval
          ORDER BY r.created_at DESC LIMIT 300`,
        [days]
      );
      res.json({ok:true,days,summary:summary.rows[0]||{},daily:daily.rows,businesses:businesses.rows,items:items.rows});
    }catch(e){console.error('admin offer revenue',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/premium-users',guard,async(req,res)=>{
    const filter=String(req.query?.filter||'all');
    try{
      const r=await pool.query(
        `SELECT u.id,u.email,u.phone,u.display_name,u.status,u.created_at,
                COALESCE(u.premium,false) AS premium_flag,u.premium_expires_at,
                (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS premium,
                (SELECT COUNT(*)::int FROM premium_history ph WHERE ph.user_id=u.id::text) AS history_count
           FROM users u
          WHERE u.role<>'admin'
            AND (($1='all')
              OR ($1='premium' AND COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW()))
              OR ($1='expired' AND COALESCE(u.premium,false)=TRUE AND u.premium_expires_at<=NOW())
              OR ($1='standard' AND COALESCE(u.premium,false)=FALSE))
          ORDER BY premium DESC,u.premium_expires_at NULLS LAST,u.created_at DESC
          LIMIT 500`,
        [filter]
      );
      const s=await pool.query(
        `SELECT
          COUNT(*) FILTER(WHERE role<>'admin')::int AS total,
          COUNT(*) FILTER(WHERE role<>'admin' AND COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW()))::int AS premium,
          COUNT(*) FILTER(WHERE role<>'admin' AND COALESCE(premium,false)=TRUE AND premium_expires_at<=NOW())::int AS expired,
          COUNT(*) FILTER(WHERE role<>'admin' AND COALESCE(premium,false)=FALSE)::int AS standard
         FROM users`
      );
      res.json({ok:true,filter,summary:s.rows[0]||{},items:r.rows});
    }catch(e){console.error('admin premium users',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/premium-users/:userId/history',guard,async(req,res)=>{
    try{
      const r=await pool.query('SELECT * FROM premium_history WHERE user_id=$1 ORDER BY created_at DESC LIMIT 200',[String(req.params.userId)]);
      res.json({ok:true,items:r.rows});
    }catch(e){console.error('premium history',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/premium-users/:userId',guard,async(req,res)=>{
    const userId=String(req.params.userId||'').trim();
    const action=String(req.body?.action||'').trim();
    if(!['activate','extend','cancel','adjust'].includes(action))return res.status(400).json({error:'INVALID_ACTION'});
    const client=await pool.connect();
    try{
      await client.query('BEGIN');
      const before=await client.query('SELECT id,display_name,email,phone,COALESCE(premium,false) AS premium,premium_expires_at FROM users WHERE id::text=$1 FOR UPDATE',[userId]);
      if(!before.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'USER_NOT_FOUND'});}
      const prev=before.rows[0];
      let nextPremium=prev.premium===true,nextExpiry=prev.premium_expires_at;
      const days=Number(req.body?.days||0);
      const explicitExpiry=Object.prototype.hasOwnProperty.call(req.body||{},'expiresAt')?isoOrNull(req.body.expiresAt):undefined;
      if(action==='activate'){
        nextPremium=true;
        nextExpiry=explicitExpiry===undefined?(days>0?new Date(Date.now()+days*86400000).toISOString():null):explicitExpiry;
      }else if(action==='extend'){
        if(!Number.isFinite(days)||days<=0){await client.query('ROLLBACK');return res.status(400).json({error:'DAYS_REQUIRED'});}
        const base=prev.premium_expires_at&&new Date(prev.premium_expires_at)>new Date()?new Date(prev.premium_expires_at):new Date();
        nextPremium=true;nextExpiry=new Date(base.getTime()+days*86400000).toISOString();
      }else if(action==='cancel'){
        nextPremium=false;nextExpiry=new Date().toISOString();
      }else{
        nextPremium=req.body?.premium===true;
        nextExpiry=explicitExpiry===undefined?prev.premium_expires_at:explicitExpiry;
        if(!nextPremium&&nextExpiry===null)nextExpiry=new Date().toISOString();
      }
      const updated=await client.query('UPDATE users SET premium=$2,premium_expires_at=$3 WHERE id::text=$1 RETURNING id,display_name,email,phone,premium,premium_expires_at',[userId,nextPremium,nextExpiry]);
      const a=actor(req);
      const historyAction=action==='activate'?'activated':action==='extend'?'extended':action==='cancel'?'cancelled':'adjusted';
      await client.query(
        `INSERT INTO premium_history(user_id,action,previous_premium,previous_expires_at,new_premium,new_expires_at,source,admin_id,admin_email,note)
         VALUES($1,$2,$3,$4,$5,$6,'admin',$7,$8,$9)`,
        [userId,historyAction,prev.premium,prev.premium_expires_at,nextPremium,nextExpiry,a.id,a.email,String(req.body?.note||'').trim().slice(0,1000)||null]
      );
      await writeAdminAudit(client,req,{
        action:action==='activate'?'premium.activated':action==='extend'?'premium.extended':action==='cancel'?'premium.cancelled':'premium.adjusted',
        targetType:'user',targetId:userId,targetLabel:prev.display_name||prev.email||prev.phone||userId,before:prev,after:updated.rows[0],metadata:{days:Number.isFinite(days)?days:null,note:req.body?.note||null}
      });
      await client.query('COMMIT');
      res.json({ok:true,user:updated.rows[0]});
    }catch(e){
      try{await client.query('ROLLBACK');}catch(_){}
      console.error('admin premium update',e);res.status(500).json({error:'SERVER_ERROR'});
    }finally{client.release();}
  });
};
