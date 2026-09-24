function firstNonEmpty(...values) {
  for (const value of values) {
    if (value == null) continue;
    const s = String(value).trim();
    if (s) return s;
  }
  return null;
}

function decodeJwtPayload(req) {
  try {
    const raw = String(req.headers?.authorization || '').trim();
    if (!raw.toLowerCase().startsWith('bearer ')) return {};
    const token = raw.slice(7).trim();
    const parts = token.split('.');
    if (parts.length < 2) return {};
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payload + '='.repeat((4 - payload.length % 4) % 4);
    const parsed = JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) { return {}; }
}

async function auditTableReady(db) {
  const r = await db.query("SELECT to_regclass('public.admin_audit_logs') AS name");
  return Boolean(r.rows[0]?.name);
}

async function resolveAdmin(db, req) {
  const source = req.admin || req.user || req.auth || req.adminUser || {};
  const jwt = decodeJwtPayload(req);
  let id = firstNonEmpty(source.id,source.userId,source.user_id,source.sub,jwt.id,jwt.userId,jwt.user_id,jwt.sub,req.headers?.['x-admin-id']);
  let email = firstNonEmpty(source.email,jwt.email,req.headers?.['x-admin-email']);
  let name = firstNonEmpty(source.display_name,source.displayName,source.name,jwt.display_name,jwt.displayName,jwt.name,req.headers?.['x-admin-name']);
  if (id) {
    try {
      const r = await db.query("SELECT id::text AS id,email,display_name FROM users WHERE id::text=$1 AND role='admin' LIMIT 1",[id]);
      if (r.rows.length) { id=String(r.rows[0].id||id); email=firstNonEmpty(r.rows[0].email,email); name=firstNonEmpty(r.rows[0].display_name,name); }
    } catch (_) {}
  } else if (email) {
    try {
      const r = await db.query("SELECT id::text AS id,email,display_name FROM users WHERE LOWER(email)=LOWER($1) AND role='admin' LIMIT 1",[email]);
      if (r.rows.length) { id=String(r.rows[0].id||''); email=firstNonEmpty(r.rows[0].email,email); name=firstNonEmpty(r.rows[0].display_name,name); }
    } catch (_) {}
  }
  return {id:id||null,email:email||null,name:name||null};
}

function requestIp(req) {
  return firstNonEmpty(String(req.headers?.['x-forwarded-for']||'').split(',')[0],req.ip,req.socket?.remoteAddress);
}

async function writeAdminAudit(db, req, entry) {
  try {
    if (!await auditTableReady(db)) return false;
    const actor=await resolveAdmin(db,req);
    const action=String(entry?.action||'').trim().slice(0,120);
    const targetType=String(entry?.targetType||'').trim().slice(0,80);
    if(!action||!targetType)return false;
    const details={
      ...(entry?.details&&typeof entry.details==='object'?entry.details:{}),
      ...(entry?.before!==undefined?{before:entry.before}:{}),
      ...(entry?.after!==undefined?{after:entry.after}:{}),
      ...(entry?.metadata!==undefined?{metadata:entry.metadata}:{}),
    };
    await db.query(
      "INSERT INTO admin_audit_logs (admin_id,admin_email,admin_name,action,target_type,target_id,target_label,details,ip_address,user_agent) VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10)",
      [actor.id,actor.email,actor.name,action,targetType,entry?.targetId==null?null:String(entry.targetId).slice(0,250),entry?.targetLabel==null?null:String(entry.targetLabel).slice(0,500),JSON.stringify(details),requestIp(req),firstNonEmpty(req.headers?.['user-agent'])?.slice(0,600)||null]
    );
    return true;
  } catch(e) { console.error('admin audit write',e); return false; }
}

function registerAdminAuditRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
  app.get('/api/admin/manage/audit',guard,async(req,res)=>{
    try{
      if(!await auditTableReady(pool))return res.status(503).json({error:'ADMIN_AUDIT_MIGRATION_REQUIRED'});
      const limit=Math.max(1,Math.min(200,Number(req.query?.limit||100)));
      const offset=Math.max(0,Number(req.query?.offset||0));
      const action=String(req.query?.action||'').trim();
      const targetType=String(req.query?.targetType||'').trim();
      const admin=String(req.query?.admin||'').trim();
      const target=String(req.query?.target||'').trim();
      const where=[]; const params=[];
      const add=(value,sql)=>{params.push(value);where.push(sql.replace('?', '$'+params.length));};
      if(action&&action!=='all')add(action,'action=?');
      if(targetType&&targetType!=='all')add(targetType,'target_type=?');
      if(admin){params.push('%'+admin+'%');const p='$'+params.length;where.push("(COALESCE(admin_name,'') ILIKE "+p+" OR COALESCE(admin_email,'') ILIKE "+p+")");}
      if(target){params.push('%'+target+'%');const p='$'+params.length;where.push("(COALESCE(target_id,'') ILIKE "+p+" OR COALESCE(target_label,'') ILIKE "+p+")");}
      const whereSql=where.length?'WHERE '+where.join(' AND '):'';
      const count=await pool.query('SELECT COUNT(*)::int AS n FROM admin_audit_logs '+whereSql,params);
      const listParams=params.slice(); listParams.push(limit); const lp='$'+listParams.length; listParams.push(offset); const op='$'+listParams.length;
      const rows=await pool.query("SELECT id,admin_id,admin_email,admin_name,action,target_type,target_id,target_label,details,ip_address,user_agent,created_at FROM admin_audit_logs "+whereSql+" ORDER BY created_at DESC LIMIT "+lp+" OFFSET "+op,listParams);
      const summary=await pool.query("SELECT COUNT(*) FILTER (WHERE created_at>=CURRENT_DATE)::int AS today,COUNT(DISTINCT COALESCE(admin_id,admin_email,admin_name)) FILTER (WHERE created_at>=CURRENT_DATE)::int AS admins_today,COUNT(DISTINCT action)::int AS action_types FROM admin_audit_logs");
      const facets=await pool.query("SELECT ARRAY(SELECT DISTINCT action FROM admin_audit_logs ORDER BY action) AS actions,ARRAY(SELECT DISTINCT target_type FROM admin_audit_logs ORDER BY target_type) AS target_types");
      return res.json({ok:true,total:Number(count.rows[0]?.n||0),summary:summary.rows[0]||{},actions:facets.rows[0]?.actions||[],targetTypes:facets.rows[0]?.target_types||[],items:rows.rows});
    }catch(e){console.error('admin audit list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
}

module.exports={writeAdminAudit,registerAdminAuditRoutes,auditTableReady};
