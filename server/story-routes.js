const express=require('express');
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {writeAdminAudit}=require('./admin-audit');

const ACTION_TYPES=new Set(['NONE','IN_APP_PAGE','SERVICE','OPPORTUNITY','EXTERNAL_URL']);
const AUDIENCES=new Set(['all','pro','non_pro','qr_active','qr_inactive']);
const STATUSES=new Set(['draft','scheduled','published','inactive']);
const BADGES=new Set(['none','new','discount','count','custom','pro']);
const IN_APP_TARGETS=new Set(['premium','services','vehicles','notifications','settings','qr_security','maintenance','parking','offers']);
const SERVICE_TARGETS=new Set(['towing','valet','roadside_help','parking','maintenance','offers']);

function clean(v,max=500){return String(v==null?'':v).trim().slice(0,max);}
function nullable(v,max=500){const x=clean(v,max);return x||null;}
function intValue(v,fallback=0){const n=Number(v);return Number.isFinite(n)?Math.trunc(n):fallback;}
function boolValue(v,fallback=false){return v===undefined?fallback:v===true;}
function validHttps(v){try{const u=new URL(String(v||''));return u.protocol==='https:';}catch(_){return false;}}
function mediaUrl(v){
  const x=nullable(v,1600);
  if(!x)return null;
  if(!validHttps(x)||!x.includes('/uploads/promos/'))return null;
  return x;
}
function actionValid(type,target){
  if(type==='NONE')return !target;
  if(type==='IN_APP_PAGE')return IN_APP_TARGETS.has(String(target||''));
  if(type==='SERVICE')return SERVICE_TARGETS.has(String(target||''));
  if(type==='OPPORTUNITY')return /^[A-Za-z0-9_-]{1,120}$/.test(String(target||''));
  if(type==='EXTERNAL_URL')return validHttps(target);
  return false;
}
function derivedStatus(row){
  const now=Date.now();
  const start=new Date(row.starts_at).getTime();
  const end=row.ends_at?new Date(row.ends_at).getTime():null;
  if(row.status==='inactive')return 'inactive';
  if(row.status==='draft')return 'draft';
  if(end&&end<=now)return 'expired';
  if(start>now)return 'scheduled';
  return 'live';
}
function categoryPayload(row){
  return {
    id:String(row.id),
    slug:String(row.slug||''),
    name:String(row.name||''),
    icon:String(row.icon||'campaign'),
    sortOrder:Number(row.sort_order||0),
    isActive:row.is_active===true,
    createdAt:row.created_at,
    updatedAt:row.updated_at,
  };
}
function storyPayload(row){
  const opens=Number(row.opens||0), clicks=Number(row.clicks||0);
  return {
    id:String(row.id),
    title:String(row.title||''),
    subtitle:String(row.subtitle||''),
    thumbnailUrl:String(row.thumbnail_url||''),
    contentImageUrl:String(row.content_image_url||''),
    badgeType:String(row.badge_type||'none'),
    badgeText:String(row.badge_text||''),
    ctaEnabled:row.cta_enabled===true,
    ctaText:String(row.cta_text||''),
    actionType:String(row.action_type||'NONE'),
    actionTarget:String(row.action_target||''),
    categoryId:row.category_id?String(row.category_id):null,
    categorySlug:String(row.category_slug||''),
    categoryName:String(row.category_name||''),
    categoryIcon:String(row.category_icon||'campaign'),
    audienceType:String(row.audience_type||'all'),
    targetCountry:String(row.target_country||'TR'),
    targetCity:String(row.target_city||''),
    targetDistrict:String(row.target_district||''),
    sortOrder:Number(row.sort_order||0),
    startsAt:row.starts_at,
    endsAt:row.ends_at,
    status:String(row.status||'draft'),
    displayStatus:derivedStatus(row),
    viewed:row.viewed_at!=null,
    opened:row.opened_at!=null,
    clicked:row.clicked_at!=null,
    analytics:{
      impressions:Number(row.impressions||0),
      uniqueViews:Number(row.unique_views||0),
      opens,
      clicks,
      ctr:opens>0?Number(((clicks/opens)*100).toFixed(1)):0,
    },
    createdAt:row.created_at,
    updatedAt:row.updated_at,
  };
}
function normalizeInput(body,old){
  const source=old||{};
  const title=body.title===undefined?String(source.title||''):clean(body.title,100);
  const subtitle=body.subtitle===undefined?String(source.subtitle||''):clean(body.subtitle,220);
  const thumb=body.thumbnailUrl===undefined?String(source.thumbnail_url||''):String(body.thumbnailUrl||'').trim();
  const content=body.contentImageUrl===undefined?String(source.content_image_url||''):String(body.contentImageUrl||'').trim();
  const badgeType=body.badgeType===undefined?String(source.badge_type||'none'):String(body.badgeType||'none');
  const badgeText=body.badgeText===undefined?String(source.badge_text||''):clean(body.badgeText,40);
  const ctaEnabled=body.ctaEnabled===undefined?source.cta_enabled===true:body.ctaEnabled===true;
  const ctaText=body.ctaText===undefined?String(source.cta_text||''):clean(body.ctaText,60);
  const actionType=body.actionType===undefined?String(source.action_type||'NONE'):String(body.actionType||'NONE').toUpperCase();
  const actionTarget=body.actionTarget===undefined?String(source.action_target||''):clean(body.actionTarget,1000);
  const categoryId=body.categoryId===undefined?(source.category_id?String(source.category_id):null):nullable(body.categoryId,80);
  const audienceType=body.audienceType===undefined?String(source.audience_type||'all'):String(body.audienceType||'all');
  const targetCountry=body.targetCountry===undefined?String(source.target_country||'TR'):clean(body.targetCountry||'TR',8).toUpperCase();
  const targetCity=body.targetCity===undefined?nullable(source.target_city,100):nullable(body.targetCity,100);
  const targetDistrict=body.targetDistrict===undefined?nullable(source.target_district,100):nullable(body.targetDistrict,100);
  const sortOrder=body.sortOrder===undefined?Number(source.sort_order||0):intValue(body.sortOrder,0);
  const status=body.status===undefined?String(source.status||'draft'):String(body.status||'draft');
  const startsAt=body.startsAt===undefined?new Date(source.starts_at||Date.now()):new Date(body.startsAt||Date.now());
  const endsAt=body.endsAt===undefined?(source.ends_at?new Date(source.ends_at):null):(body.endsAt?new Date(body.endsAt):null);
  const thumbnailUrl=mediaUrl(thumb);
  const contentImageUrl=mediaUrl(content);
  if(!title||!thumbnailUrl||!contentImageUrl)return {error:'REQUIRED_FIELDS_MISSING'};
  if(!BADGES.has(badgeType)||!AUDIENCES.has(audienceType)||!STATUSES.has(status)||!ACTION_TYPES.has(actionType))return {error:'INVALID_ENUM'};
  if(ctaEnabled&&!ctaText)return {error:'CTA_TEXT_REQUIRED'};
  if(!actionValid(actionType,actionTarget||null))return {error:'INVALID_ACTION_TARGET'};
  if(Number.isNaN(startsAt.getTime())||(endsAt&&Number.isNaN(endsAt.getTime()))||(endsAt&&endsAt<=startsAt))return {error:'INVALID_DATE_RANGE'};
  if(targetDistrict&&!targetCity)return {error:'CITY_REQUIRED_FOR_DISTRICT'};
  return {value:{title,subtitle,thumbnailUrl,contentImageUrl,badgeType,badgeText,ctaEnabled,ctaText,actionType,actionTarget:actionTarget||null,categoryId,audienceType,targetCountry,targetCity,targetDistrict,sortOrder,status,startsAt,endsAt}};
}

module.exports=function registerStoryRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
  const owner=req=>authenticatedOwnerId(req);
  const uploadDir=process.env.PROMO_UPLOAD_DIR||'/opt/heycar/uploads/promos';
  try{fs.mkdirSync(uploadDir,{recursive:true});}catch(e){console.error('story upload dir',e);}

  app.get('/api/owner/stories',async(req,res)=>{
    const ownerId=owner(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const city=clean(req.query?.city,100);
      const district=clean(req.query?.district,100);
      const ctx=await pool.query(
        "SELECT (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS premium,"+
        " EXISTS(SELECT 1 FROM vehicles v JOIN qr_tags q ON q.vehicle_id=v.id AND q.status='active' WHERE v.owner_id::text=u.id::text) AS qr_active "+
        "FROM users u WHERE u.id::text=$1 LIMIT 1",[ownerId]
      );
      if(!ctx.rowCount)return res.status(404).json({error:'OWNER_NOT_FOUND'});
      const premium=ctx.rows[0].premium===true, qrActive=ctx.rows[0].qr_active===true;
      const q=await pool.query(
        "SELECT s.*,c.slug category_slug,c.name category_name,c.icon category_icon,"+
        " st.viewed_at,st.opened_at,st.clicked_at "+
        "FROM stories s LEFT JOIN story_categories c ON c.id=s.category_id "+
        "LEFT JOIN story_user_state st ON st.story_id=s.id AND st.owner_id::text=$1 "+
        "WHERE s.status IN ('published','scheduled') AND s.starts_at<=NOW() AND (s.ends_at IS NULL OR s.ends_at>NOW()) "+
        "AND (c.id IS NULL OR c.is_active=TRUE) "+
        "AND (s.audience_type='all' OR (s.audience_type='pro' AND $2::boolean) OR (s.audience_type='non_pro' AND NOT $2::boolean) "+
        " OR (s.audience_type='qr_active' AND $3::boolean) OR (s.audience_type='qr_inactive' AND NOT $3::boolean)) "+
        "AND (s.target_city IS NULL OR ($4<>'' AND lower(s.target_city)=lower($4))) "+
        "AND (s.target_district IS NULL OR ($5<>'' AND lower(s.target_district)=lower($5))) "+
        "ORDER BY s.sort_order ASC,c.sort_order ASC,s.created_at ASC",
        [ownerId,premium,qrActive,city,district]
      );
      return res.json({ok:true,items:q.rows.map(storyPayload)});
    }catch(e){console.error('owner stories list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  async function stateEvent(req,res,kind){
    const ownerId=owner(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const storyId=clean(req.params.id,80);
    try{
      const exists=await pool.query(
        "SELECT 1 FROM stories WHERE id::text=$1 AND status IN ('published','scheduled') AND starts_at<=NOW() AND (ends_at IS NULL OR ends_at>NOW()) LIMIT 1",
        [storyId]
      );
      if(!exists.rowCount)return res.status(404).json({error:'STORY_NOT_FOUND'});
      if(kind==='impression'){
        await pool.query(
          "INSERT INTO story_user_state(story_id,owner_id,first_impression_at,last_impression_at,impression_count,updated_at) "+
          "VALUES($1,$2,NOW(),NOW(),1,NOW()) "+
          "ON CONFLICT(story_id,owner_id) DO UPDATE SET "+
          "first_impression_at=COALESCE(story_user_state.first_impression_at,NOW()),"+
          "impression_count=story_user_state.impression_count + CASE WHEN story_user_state.last_impression_at IS NULL OR story_user_state.last_impression_at<NOW()-INTERVAL '30 minutes' THEN 1 ELSE 0 END,"+
          "last_impression_at=CASE WHEN story_user_state.last_impression_at IS NULL OR story_user_state.last_impression_at<NOW()-INTERVAL '30 minutes' THEN NOW() ELSE story_user_state.last_impression_at END,updated_at=NOW()",
          [storyId,ownerId]
        );
      }else{
        const col=kind==='view'?'viewed_at':kind==='open'?'opened_at':'clicked_at';
        await pool.query(
          "INSERT INTO story_user_state(story_id,owner_id,"+col+",updated_at) VALUES($1,$2,NOW(),NOW()) "+
          "ON CONFLICT(story_id,owner_id) DO UPDATE SET "+col+"=COALESCE(story_user_state."+col+",NOW()),updated_at=NOW()",
          [storyId,ownerId]
        );
      }
      return res.json({ok:true});
    }catch(e){console.error('story state event',kind,e);return res.status(500).json({error:'SERVER_ERROR'});}
  }
  app.post('/api/owner/stories/:id/impression',(req,res)=>stateEvent(req,res,'impression'));
  app.post('/api/owner/stories/:id/view',(req,res)=>stateEvent(req,res,'view'));
  app.post('/api/owner/stories/:id/open',(req,res)=>stateEvent(req,res,'open'));
  app.post('/api/owner/stories/:id/click',(req,res)=>stateEvent(req,res,'click'));

  app.put('/api/admin/manage/stories/media/:kind',guard,express.raw({type:'application/octet-stream',limit:'3mb'}),async(req,res)=>{
    try{
      const kind=String(req.params.kind||'content');
      if(!['thumbnail','content'].includes(kind))return res.status(400).json({error:'INVALID_MEDIA_KIND'});
      const mime=String(req.headers['x-file-type']||'').toLowerCase();
      const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':mime==='image/jpeg'||mime==='image/jpg'?'jpg':'';
      if(!ext)return res.status(400).json({error:'INVALID_IMAGE_TYPE'});
      const buf=Buffer.isBuffer(req.body)?req.body:Buffer.alloc(0);
      if(!buf.length||buf.length>3*1024*1024)return res.status(413).json({error:'IMAGE_TOO_LARGE'});
      const name='story-'+kind+'-'+crypto.randomUUID()+'.'+ext;
      fs.writeFileSync(path.join(uploadDir,name),buf,{mode:0o644});
      const proto=String(req.headers['x-forwarded-proto']||req.protocol||'https').split(',')[0].trim();
      const host=req.get('host');
      const base=String(process.env.PUBLIC_API_BASE_URL||(host?proto+'://'+host:'https://heycar-api-185-165-46-213.nip.io')).replace(/\/$/,'');
      return res.status(201).json({ok:true,url:base+'/uploads/promos/'+name});
    }catch(e){console.error('story media upload',e);return res.status(500).json({error:'UPLOAD_FAILED'});}
  });

  app.get('/api/admin/manage/story-categories',guard,async(_req,res)=>{
    try{
      const q=await pool.query('SELECT * FROM story_categories ORDER BY sort_order,name');
      return res.json({ok:true,items:q.rows.map(categoryPayload)});
    }catch(e){console.error('story category list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
  app.post('/api/admin/manage/story-categories',guard,async(req,res)=>{
    try{
      const name=clean(req.body?.name,80), slug=clean(req.body?.slug,80).toLowerCase().replace(/[^a-z0-9-]+/g,'-');
      const icon=clean(req.body?.icon||'campaign',40), sortOrder=intValue(req.body?.sortOrder,0);
      if(!name||!slug)return res.status(400).json({error:'INVALID_INPUT'});
      const q=await pool.query(
        'INSERT INTO story_categories(slug,name,icon,sort_order,is_active) VALUES($1,$2,$3,$4,$5) RETURNING *',
        [slug,name,icon,sortOrder,req.body?.isActive!==false]
      );
      await writeAdminAudit(pool,req,{action:'story_category.created',targetType:'story_category',targetId:q.rows[0].id,targetLabel:name,after:categoryPayload(q.rows[0])});
      return res.status(201).json({ok:true,item:categoryPayload(q.rows[0])});
    }catch(e){if(e?.code==='23505')return res.status(409).json({error:'CATEGORY_SLUG_EXISTS'});console.error('story category create',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
  app.patch('/api/admin/manage/story-categories/:id',guard,async(req,res)=>{
    try{
      const old=await pool.query('SELECT * FROM story_categories WHERE id::text=$1 LIMIT 1',[req.params.id]);
      if(!old.rowCount)return res.status(404).json({error:'CATEGORY_NOT_FOUND'});
      const x=old.rows[0];
      const name=req.body?.name===undefined?x.name:clean(req.body.name,80);
      const icon=req.body?.icon===undefined?x.icon:clean(req.body.icon,40);
      const sortOrder=req.body?.sortOrder===undefined?x.sort_order:intValue(req.body.sortOrder,0);
      const active=req.body?.isActive===undefined?x.is_active:req.body.isActive===true;
      if(!name)return res.status(400).json({error:'INVALID_INPUT'});
      const q=await pool.query('UPDATE story_categories SET name=$2,icon=$3,sort_order=$4,is_active=$5,updated_at=NOW() WHERE id::text=$1 RETURNING *',[req.params.id,name,icon,sortOrder,active]);
      await writeAdminAudit(pool,req,{action:'story_category.updated',targetType:'story_category',targetId:q.rows[0].id,targetLabel:name,before:categoryPayload(x),after:categoryPayload(q.rows[0])});
      return res.json({ok:true,item:categoryPayload(q.rows[0])});
    }catch(e){console.error('story category update',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/stories',guard,async(_req,res)=>{
    try{
      const q=await pool.query(
        "SELECT s.*,c.slug category_slug,c.name category_name,c.icon category_icon,"+
        " COALESCE(a.impressions,0)::bigint impressions,COALESCE(a.unique_views,0)::bigint unique_views,COALESCE(a.opens,0)::bigint opens,COALESCE(a.clicks,0)::bigint clicks "+
        "FROM stories s LEFT JOIN story_categories c ON c.id=s.category_id "+
        "LEFT JOIN LATERAL (SELECT COALESCE(SUM(st.impression_count),0) impressions,COUNT(*) FILTER(WHERE st.viewed_at IS NOT NULL) unique_views,COUNT(*) FILTER(WHERE st.opened_at IS NOT NULL) opens,COUNT(*) FILTER(WHERE st.clicked_at IS NOT NULL) clicks FROM story_user_state st WHERE st.story_id=s.id) a ON TRUE "+
        "ORDER BY s.sort_order,s.created_at"
      );
      const cats=await pool.query('SELECT * FROM story_categories ORDER BY sort_order,name');
      return res.json({ok:true,items:q.rows.map(storyPayload),categories:cats.rows.map(categoryPayload)});
    }catch(e){console.error('admin story list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/admin/manage/stories',guard,async(req,res)=>{
    try{
      const parsed=normalizeInput(req.body||{},null);
      if(parsed.error)return res.status(400).json({error:parsed.error});
      const v=parsed.value;
      const q=await pool.query(
        "INSERT INTO stories(title,subtitle,thumbnail_url,content_image_url,badge_type,badge_text,cta_enabled,cta_text,action_type,action_target,category_id,audience_type,target_country,target_city,target_district,sort_order,starts_at,ends_at,status,created_by) "+
        "VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20) RETURNING *",
        [v.title,v.subtitle||null,v.thumbnailUrl,v.contentImageUrl,v.badgeType,v.badgeText||null,v.ctaEnabled,v.ctaText||null,v.actionType,v.actionTarget,v.categoryId,v.audienceType,v.targetCountry,v.targetCity,v.targetDistrict,v.sortOrder,v.startsAt,v.endsAt,v.status,String(req.admin?.id||req.user?.id||'admin')]
      );
      await writeAdminAudit(pool,req,{action:'story.created',targetType:'story',targetId:q.rows[0].id,targetLabel:v.title,after:storyPayload(q.rows[0])});
      return res.status(201).json({ok:true,item:storyPayload(q.rows[0])});
    }catch(e){if(e?.code==='23503')return res.status(400).json({error:'INVALID_CATEGORY'});console.error('story create',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/stories/:id',guard,async(req,res)=>{
    try{
      const oldQ=await pool.query('SELECT * FROM stories WHERE id::text=$1 LIMIT 1',[req.params.id]);
      if(!oldQ.rowCount)return res.status(404).json({error:'STORY_NOT_FOUND'});
      const old=oldQ.rows[0], parsed=normalizeInput(req.body||{},old);
      if(parsed.error)return res.status(400).json({error:parsed.error});
      const v=parsed.value;
      const q=await pool.query(
        "UPDATE stories SET title=$2,subtitle=$3,thumbnail_url=$4,content_image_url=$5,badge_type=$6,badge_text=$7,cta_enabled=$8,cta_text=$9,action_type=$10,action_target=$11,category_id=$12,audience_type=$13,target_country=$14,target_city=$15,target_district=$16,sort_order=$17,starts_at=$18,ends_at=$19,status=$20,updated_at=NOW() WHERE id::text=$1 RETURNING *",
        [req.params.id,v.title,v.subtitle||null,v.thumbnailUrl,v.contentImageUrl,v.badgeType,v.badgeText||null,v.ctaEnabled,v.ctaText||null,v.actionType,v.actionTarget,v.categoryId,v.audienceType,v.targetCountry,v.targetCity,v.targetDistrict,v.sortOrder,v.startsAt,v.endsAt,v.status]
      );
      await writeAdminAudit(pool,req,{action:'story.updated',targetType:'story',targetId:q.rows[0].id,targetLabel:v.title,before:storyPayload(old),after:storyPayload(q.rows[0])});
      return res.json({ok:true,item:storyPayload(q.rows[0])});
    }catch(e){if(e?.code==='23503')return res.status(400).json({error:'INVALID_CATEGORY'});console.error('story update',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.delete('/api/admin/manage/stories/:id',guard,async(req,res)=>{
    try{
      const q=await pool.query('DELETE FROM stories WHERE id::text=$1 RETURNING id,title',[req.params.id]);
      if(!q.rowCount)return res.status(404).json({error:'STORY_NOT_FOUND'});
      await writeAdminAudit(pool,req,{action:'story.deleted',targetType:'story',targetId:q.rows[0].id,targetLabel:q.rows[0].title});
      return res.json({ok:true});
    }catch(e){console.error('story delete',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/admin/manage/stories/reorder',guard,async(req,res)=>{
    const ids=Array.isArray(req.body?.ids)?req.body.ids.map(x=>clean(x,80)).filter(Boolean):[];
    if(!ids.length||ids.length>200)return res.status(400).json({error:'INVALID_ORDER'});
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      for(let i=0;i<ids.length;i++)await db.query('UPDATE stories SET sort_order=$2,updated_at=NOW() WHERE id::text=$1',[ids[i],(i+1)*10]);
      await db.query('COMMIT');
      await writeAdminAudit(pool,req,{action:'story.reordered',targetType:'story',targetId:'bulk',metadata:{ids}});
      return res.json({ok:true});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('story reorder',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });
};
