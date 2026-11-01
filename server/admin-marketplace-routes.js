'use strict';
const {writeAdminAudit}=require('./admin-audit');
module.exports=function registerAdminMarketplaceRoutes(app,pool,adminGuard){
 const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(503).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
 app.get('/api/admin/manage/marketplace/services',guard,async(_req,res)=>{
  try{
   const q=await pool.query(`SELECT s.*,b.name AS business_name,b.approval_status,b.is_active AS business_active,
    (SELECT count(*)::int FROM marketplace_appointments a WHERE a.service_id=s.id) AS appointment_count
    FROM marketplace_services s JOIN businesses b ON b.id=s.business_id ORDER BY s.created_at DESC LIMIT 200`);
   const summary=await pool.query("SELECT status,count(*)::int AS count FROM marketplace_appointments GROUP BY status");
   res.json({ok:true,services:q.rows,appointments:summary.rows});
  }catch(e){console.error('admin marketplace list',e);res.status(500).json({error:'MARKETPLACE_UNAVAILABLE'});}
 });
 app.patch('/api/admin/manage/marketplace/services/:id',guard,async(req,res)=>{
  const {hidden,reason=''}=req.body||{};
  if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(req.params.id)||typeof hidden!=='boolean'||typeof reason!=='string'||reason.length>1000||(hidden&&!reason.trim()))return res.status(400).json({error:'INVALID_MODERATION'});
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   // Same lock as booking: a removal cannot race past a waiting booking.
   const lock=await client.query('SELECT b.id FROM businesses b JOIN marketplace_services s ON s.business_id=b.id WHERE s.id=$1 FOR UPDATE OF b',[req.params.id]);
   if(!lock.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'SERVICE_NOT_FOUND'});}
   const q=await client.query('UPDATE marketplace_services SET admin_hidden=$2,moderation_reason=$3 WHERE id=$1 RETURNING *',[req.params.id,hidden,reason.trim()]);
   await writeAdminAudit(client,req,{action:hidden?'marketplace.unpublished':'marketplace.restored',targetType:'marketplace_service',targetId:req.params.id,details:{reason:reason.trim()}});
   await client.query('COMMIT');res.json({ok:true,service:q.rows[0]});
  }catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('admin marketplace moderation',e);res.status(500).json({error:'MODERATION_FAILED'});}
  finally{client.release();}
 });
};
