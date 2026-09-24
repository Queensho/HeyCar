const express=require('express');
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {writeAdminAudit}=require('./admin-audit');

const CATEGORIES=new Set([
  'technical','qr','vehicle','notifications_calls','offers','premium_payment','account_security','other'
]);
const MIME_EXT={
  'image/jpeg':'jpg',
  'image/png':'png',
  'image/webp':'webp',
};

function clean(v,max=2000){return String(v==null?'':v).trim().slice(0,max);}
function adminActor(req){return clean(req.headers?.['x-admin-email']||req.headers?.['x-admin-name']||req.headers?.['x-admin-id']||'admin',240);}
function safeAttachmentName(raw){
  const name=path.basename(String(raw||''));
  return /^[a-f0-9-]+\.(jpg|jpeg|png|webp)$/i.test(name)?name:null;
}

module.exports=function registerSupportRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});
  const owner=req=>authenticatedOwnerId(req);
  const uploadDir=process.env.SUPPORT_UPLOAD_DIR||'/opt/heycar/uploads/support';
  try{fs.mkdirSync(uploadDir,{recursive:true});}catch(e){console.error('support upload dir',e);}

  async function ticketForOwner(ticketId,ownerId){
    const r=await pool.query('SELECT * FROM support_tickets WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',[String(ticketId),String(ownerId)]);
    return r.rows[0]||null;
  }

  app.get('/api/owner/support-tickets',async(req,res)=>{
    const ownerId=owner(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const r=await pool.query(
        `SELECT t.id,t.category,t.message,t.status,t.admin_reply,t.replied_at,t.replied_by,
                t.resolved_at,t.created_at,t.updated_at,
                COUNT(a.id)::int AS attachment_count
           FROM support_tickets t
           LEFT JOIN support_ticket_attachments a ON a.ticket_id=t.id
          WHERE t.owner_id::text=$1
          GROUP BY t.id
          ORDER BY t.updated_at DESC,t.created_at DESC
          LIMIT 100`,
        [ownerId]
      );
      return res.json({ok:true,items:r.rows});
    }catch(e){console.error('owner support list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/support-tickets',express.json(),async(req,res)=>{
    const ownerId=owner(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const category=clean(req.body?.category,60);
    const message=clean(req.body?.message,2000);
    if(!CATEGORIES.has(category))return res.status(400).json({error:'INVALID_CATEGORY'});
    if(message.length<10)return res.status(400).json({error:'MESSAGE_TOO_SHORT'});
    try{
      const recent=await pool.query(
        `SELECT COUNT(*)::int AS n
           FROM support_tickets
          WHERE owner_id::text=$1 AND created_at>NOW()-INTERVAL '10 minutes'`,
        [ownerId]
      );
      if(Number(recent.rows[0]?.n||0)>=5)return res.status(429).json({error:'TOO_MANY_SUPPORT_TICKETS'});
      const r=await pool.query(
        `INSERT INTO support_tickets(owner_id,category,message,status)
         VALUES($1,$2,$3,'open')
         RETURNING *`,
        [ownerId,category,message]
      );
      return res.status(201).json({ok:true,ticket:r.rows[0]});
    }catch(e){console.error('owner support create',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post(
    '/api/owner/support-tickets/:ticketId/attachment',
    express.raw({type:['image/jpeg','image/png','image/webp'],limit:'5mb'}),
    async(req,res)=>{
      const ownerId=owner(req);
      if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
      const ticketId=clean(req.params.ticketId,40);
      const mime=String(req.headers['content-type']||'').split(';')[0].trim().toLowerCase();
      const ext=MIME_EXT[mime];
      if(!ext)return res.status(415).json({error:'UNSUPPORTED_IMAGE'});
      const bytes=Buffer.isBuffer(req.body)?req.body:Buffer.from(req.body||[]);
      if(!bytes.length)return res.status(400).json({error:'EMPTY_IMAGE'});
      if(bytes.length>5*1024*1024)return res.status(413).json({error:'IMAGE_TOO_LARGE'});
      try{
        const ticket=await ticketForOwner(ticketId,ownerId);
        if(!ticket)return res.status(404).json({error:'TICKET_NOT_FOUND'});
        const existing=await pool.query('SELECT id FROM support_ticket_attachments WHERE ticket_id=$1 LIMIT 1',[ticket.id]);
        if(existing.rows.length)return res.status(409).json({error:'ATTACHMENT_ALREADY_EXISTS'});
        const fileName=crypto.randomUUID()+'.'+ext;
        const filePath=path.join(uploadDir,fileName);
        await fs.promises.writeFile(filePath,bytes,{flag:'wx'});
        try{
          const saved=await pool.query(
            `INSERT INTO support_ticket_attachments(ticket_id,owner_id,file_name,mime_type,size_bytes)
             VALUES($1,$2,$3,$4,$5)
             RETURNING id,ticket_id,mime_type,size_bytes,created_at`,
            [ticket.id,ownerId,fileName,mime,bytes.length]
          );
          await pool.query('UPDATE support_tickets SET updated_at=NOW() WHERE id=$1',[ticket.id]);
          return res.status(201).json({ok:true,attachment:saved.rows[0]});
        }catch(e){
          await fs.promises.unlink(filePath).catch(()=>{});
          throw e;
        }
      }catch(e){console.error('support attachment upload',e);return res.status(500).json({error:'SERVER_ERROR'});}
    }
  );

  app.get('/api/owner/support-tickets/:ticketId/attachment',async(req,res)=>{
    const ownerId=owner(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const r=await pool.query(
        `SELECT a.file_name,a.mime_type
           FROM support_ticket_attachments a
           JOIN support_tickets t ON t.id=a.ticket_id
          WHERE t.id::text=$1 AND t.owner_id::text=$2
          ORDER BY a.created_at ASC LIMIT 1`,
        [clean(req.params.ticketId,40),ownerId]
      );
      if(!r.rows.length)return res.status(404).end();
      const name=safeAttachmentName(r.rows[0].file_name);
      if(!name)return res.status(404).end();
      res.type(r.rows[0].mime_type);
      return res.sendFile(path.join(uploadDir,name));
    }catch(e){console.error('owner support attachment get',e);return res.status(500).end();}
  });

  app.get('/api/admin/manage/support-tickets',guard,async(req,res)=>{
    const status=clean(req.query?.status||'open',30);
    if(!['all','open','in_review','answered','resolved'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    try{
      const params=[];
      let where='';
      if(status!=='all'){params.push(status);where='WHERE t.status=$1';}
      const r=await pool.query(
        `SELECT t.id,t.owner_id,t.category,t.message,t.status,t.admin_reply,t.replied_at,t.replied_by,
                t.resolved_at,t.created_at,t.updated_at,
                u.display_name,u.phone,u.email,
                COUNT(a.id)::int AS attachment_count
           FROM support_tickets t
           LEFT JOIN users u ON u.id::text=t.owner_id::text
           LEFT JOIN support_ticket_attachments a ON a.ticket_id=t.id
           ${where}
          GROUP BY t.id,u.id
          ORDER BY CASE t.status WHEN 'open' THEN 0 WHEN 'in_review' THEN 1 WHEN 'answered' THEN 2 ELSE 3 END,
                   t.updated_at DESC
          LIMIT 300`,
        params
      );
      const s=await pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER(WHERE status='open')::int AS open,
                COUNT(*) FILTER(WHERE status='in_review')::int AS in_review,
                COUNT(*) FILTER(WHERE status='answered')::int AS answered,
                COUNT(*) FILTER(WHERE status='resolved')::int AS resolved,
                COUNT(*) FILTER(WHERE created_at>=CURRENT_DATE)::int AS today
           FROM support_tickets`
      );
      return res.json({ok:true,status,summary:s.rows[0]||{},items:r.rows});
    }catch(e){console.error('admin support list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/support-tickets/:ticketId/attachment',guard,async(req,res)=>{
    try{
      const r=await pool.query(
        `SELECT file_name,mime_type
           FROM support_ticket_attachments
          WHERE ticket_id::text=$1
          ORDER BY created_at ASC LIMIT 1`,
        [clean(req.params.ticketId,40)]
      );
      if(!r.rows.length)return res.status(404).end();
      const name=safeAttachmentName(r.rows[0].file_name);
      if(!name)return res.status(404).end();
      res.type(r.rows[0].mime_type);
      return res.sendFile(path.join(uploadDir,name));
    }catch(e){console.error('admin support attachment get',e);return res.status(500).end();}
  });

  app.patch('/api/admin/manage/support-tickets/:ticketId',guard,express.json(),async(req,res)=>{
    const id=clean(req.params.ticketId,40);
    const status=clean(req.body?.status,30);
    const reply=clean(req.body?.adminReply,3000);
    if(!['open','in_review','answered','resolved'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    if(status==='answered'&&!reply)return res.status(400).json({error:'REPLY_REQUIRED'});
    try{
      const before=await pool.query('SELECT * FROM support_tickets WHERE id::text=$1 LIMIT 1',[id]);
      if(!before.rows.length)return res.status(404).json({error:'TICKET_NOT_FOUND'});
      const actor=adminActor(req);
      const q=await pool.query(
        `UPDATE support_tickets
            SET status=$2,
                admin_reply=CASE WHEN $3::boolean THEN $4 ELSE admin_reply END,
                replied_at=CASE WHEN $3::boolean THEN NOW() ELSE replied_at END,
                replied_by=CASE WHEN $3::boolean THEN $5 ELSE replied_by END,
                resolved_at=CASE WHEN $2='resolved' THEN NOW() WHEN $2<>'resolved' THEN NULL ELSE resolved_at END,
                updated_at=NOW()
          WHERE id::text=$1
          RETURNING *`,
        [id,status,reply.length>0,reply||null,actor]
      );
      const updated=q.rows[0];
      await writeAdminAudit(pool,req,{
        action:status==='in_review'?'support.in_review':status==='answered'?'support.answered':status==='resolved'?'support.resolved':'support.reopened',
        targetType:'support_ticket',
        targetId:id,
        targetLabel:'Destek #'+id,
        before:before.rows[0],
        after:updated,
      });

      if((status==='answered'||status==='resolved')&&app.locals.heycarPush?.sendOwner){
        const title=status==='answered'?'Destek talebin yanıtlandı':'Destek talebin çözüldü';
        const body=reply||'Cepqar destek talebin güncellendi.';
        app.locals.heycarPush.sendOwner(
          String(updated.owner_id),
          {type:'support_ticket',sourceType:'support_ticket',ticketId:String(updated.id),status:String(updated.status)},
          title,
          body.slice(0,300)
        ).catch(e=>console.error('support push',e));
      }

      return res.json({ok:true,ticket:updated});
    }catch(e){console.error('admin support update',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
