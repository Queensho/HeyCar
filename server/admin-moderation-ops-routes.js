const {writeAdminAudit}=require('./admin-audit');

async function tableExists(pool,name){
  const r=await pool.query('SELECT to_regclass($1) AS name',['public.'+name]);
  return Boolean(r.rows[0]?.name);
}
async function columnExists(pool,table,column){
  const r=await pool.query(
    "SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 AND column_name=$2 LIMIT 1",
    [table,column]
  );
  return Boolean(r.rows.length);
}
function maskKey(raw){
  const s=String(raw||'').trim();
  if(!s)return null;
  if(s.length<=10)return s.slice(0,3)+'•••';
  return s.slice(0,6)+'••••'+s.slice(-4);
}
function actorLabel(req){
  const a=req.admin||req.user||{};
  return String(a.email||a.display_name||a.name||a.id||'admin').slice(0,240);
}

module.exports=function registerAdminModerationOpsRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'?adminGuard:(_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  async function moderationReady(){
    return await tableExists(pool,'message_reports')
      && await columnExists(pool,'message_reports','status')
      && await columnExists(pool,'message_reports','admin_note')
      && await columnExists(pool,'anonymous_calls','scan_session_hash');
  }

  app.get('/api/admin/manage/moderation/reports',guard,async(req,res)=>{
    const status=String(req.query?.status||'pending').trim();
    const allowed=['all','pending','in_review','resolved','dismissed'];
    if(!allowed.includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    try{
      if(!await moderationReady())return res.status(503).json({error:'MODERATION_MIGRATION_REQUIRED'});
      const params=[];
      let where='';
      if(status!=='all'){params.push(status);where='WHERE r.status=$1';}
      const rows=await pool.query(
        `SELECT r.id,r.conversation_id,r.message_id,r.reporter_type,r.reason,r.status,
                r.admin_note,r.created_at,r.reviewed_at,r.reviewed_by,
                c.vehicle_id,c.qr_token,c.status AS conversation_status,c.created_at AS conversation_created_at,
                c.updated_at AS conversation_updated_at,c.scan_session_hash,
                v.plate,v.owner_id,u.display_name AS owner_name,u.phone AS owner_phone,
                m.sender AS reported_sender,m.message AS reported_message,m.created_at AS reported_message_at,
                (SELECT COUNT(*)::int FROM qr_conversation_messages cm WHERE cm.conversation_id=c.id) AS message_count,
                (SELECT COUNT(*)::int FROM message_reports rr WHERE rr.conversation_id=c.id) AS report_count
           FROM message_reports r
           LEFT JOIN qr_conversations c ON c.id=r.conversation_id
           LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
           LEFT JOIN users u ON u.id::text=v.owner_id::text
           LEFT JOIN qr_conversation_messages m ON m.id=r.message_id
           ${where}
          ORDER BY
            CASE r.status WHEN 'pending' THEN 0 WHEN 'in_review' THEN 1 ELSE 2 END,
            r.created_at DESC
          LIMIT 200`,
        params
      );
      const items=rows.rows.map(x=>({
        ...x,
        visitor_key:maskKey(x.scan_session_hash),
        scan_session_hash:undefined,
        reported_message_preview:x.reported_message?String(x.reported_message).slice(0,180):null,
        reported_message:undefined,
      }));
      const summary=await pool.query(
        `SELECT
           COUNT(*) FILTER(WHERE status='pending')::int AS pending,
           COUNT(*) FILTER(WHERE status='in_review')::int AS in_review,
           COUNT(*) FILTER(WHERE status='resolved')::int AS resolved,
           COUNT(*) FILTER(WHERE status='dismissed')::int AS dismissed,
           COUNT(*) FILTER(WHERE created_at>=CURRENT_DATE)::int AS today
         FROM message_reports`
      );
      return res.json({ok:true,status,summary:summary.rows[0]||{},items});
    }catch(e){console.error('admin moderation reports',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/admin/manage/moderation/reports/:reportId',guard,async(req,res)=>{
    const reportId=String(req.params.reportId||'').trim();
    try{
      if(!await moderationReady())return res.status(503).json({error:'MODERATION_MIGRATION_REQUIRED'});
      const r=await pool.query(
        `SELECT r.id,r.conversation_id,r.message_id,r.reporter_type,r.reason,r.status,
                r.admin_note,r.created_at,r.reviewed_at,r.reviewed_by,
                c.vehicle_id,c.qr_token,c.status AS conversation_status,c.created_at AS conversation_created_at,
                c.updated_at AS conversation_updated_at,c.closed_at,c.scan_session_hash,
                v.plate,v.owner_id,u.display_name AS owner_name,u.phone AS owner_phone,
                m.sender AS reported_sender,m.message AS reported_message,m.created_at AS reported_message_at
           FROM message_reports r
           LEFT JOIN qr_conversations c ON c.id=r.conversation_id
           LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
           LEFT JOIN users u ON u.id::text=v.owner_id::text
           LEFT JOIN qr_conversation_messages m ON m.id=r.message_id
          WHERE r.id::text=$1 LIMIT 1`,
        [reportId]
      );
      if(!r.rows.length)return res.status(404).json({error:'REPORT_NOT_FOUND'});
      const report=r.rows[0];
      let transcript=[],relatedReports=[],visitorConversations=[],visitorCalls=[];
      if(report.conversation_id){
        const m=await pool.query(
          `SELECT id,sender,message,created_at
             FROM qr_conversation_messages
            WHERE conversation_id=$1
            ORDER BY created_at ASC
            LIMIT 500`,
          [report.conversation_id]
        );
        transcript=m.rows;
        const rr=await pool.query(
          `SELECT id,reporter_type,reason,status,created_at,reviewed_at
             FROM message_reports
            WHERE conversation_id=$1
            ORDER BY created_at DESC`,
          [report.conversation_id]
        );
        relatedReports=rr.rows;
      }
      const hash=String(report.scan_session_hash||'');
      if(hash){
        const vc=await pool.query(
          `SELECT c.id,c.qr_token,c.status,c.created_at,c.updated_at,v.plate,
                  COUNT(m.id)::int AS message_count,
                  COUNT(DISTINCT r.id)::int AS report_count
             FROM qr_conversations c
             LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
             LEFT JOIN qr_conversation_messages m ON m.conversation_id=c.id
             LEFT JOIN message_reports r ON r.conversation_id=c.id
            WHERE c.scan_session_hash=$1
            GROUP BY c.id,c.qr_token,c.status,c.created_at,c.updated_at,v.plate
            ORDER BY c.created_at DESC LIMIT 30`,
          [hash]
        );
        visitorConversations=vc.rows;
        const calls=await pool.query(
          `SELECT c.id,c.qr_token,c.status,c.recipient_type,c.created_at,c.answered_at,c.ended_at,c.expires_at,v.plate
             FROM anonymous_calls c
             LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
            WHERE c.scan_session_hash=$1
            ORDER BY c.created_at DESC LIMIT 30`,
          [hash]
        );
        visitorCalls=calls.rows;
      }
      return res.json({
        ok:true,
        report:{...report,visitor_key:maskKey(report.scan_session_hash),scan_session_hash:undefined},
        transcript,
        relatedReports,
        visitorHistory:{conversations:visitorConversations,calls:visitorCalls},
      });
    }catch(e){console.error('admin moderation report detail',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/admin/manage/moderation/reports/:reportId',guard,async(req,res)=>{
    const reportId=String(req.params.reportId||'').trim();
    const status=String(req.body?.status||'').trim();
    const note=String(req.body?.adminNote||'').trim().slice(0,1000);
    const closeConversation=req.body?.closeConversation===true;
    const blockSession=req.body?.blockSession===true;
    if(!['pending','in_review','resolved','dismissed'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
    const client=await pool.connect();
    try{
      if(!await moderationReady()){client.release();return res.status(503).json({error:'MODERATION_MIGRATION_REQUIRED'});}
      await client.query('BEGIN');
      const before=await client.query(
        `SELECT r.*,c.status AS conversation_status,c.scan_session_hash,c.vehicle_id,c.qr_token,
                v.owner_id,v.plate
           FROM message_reports r
           LEFT JOIN qr_conversations c ON c.id=r.conversation_id
           LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
          WHERE r.id::text=$1
          FOR UPDATE OF r`,
        [reportId]
      );
      if(!before.rows.length){await client.query('ROLLBACK');return res.status(404).json({error:'REPORT_NOT_FOUND'});}
      const row=before.rows[0];
      const updated=await client.query(
        `UPDATE message_reports
            SET status=$1,admin_note=$2,
                reviewed_at=CASE WHEN $1='pending' THEN NULL ELSE NOW() END,
                reviewed_by=CASE WHEN $1='pending' THEN NULL ELSE $3 END
          WHERE id::text=$4
          RETURNING *`,
        [status,note||null,actorLabel(req),reportId]
      );

      if(row.conversation_id&&blockSession){
        await client.query(
          `UPDATE qr_conversations
              SET status='blocked',closed_at=COALESCE(closed_at,NOW()),updated_at=NOW()
            WHERE id=$1`,
          [row.conversation_id]
        );
        if(row.scan_session_hash){
          await client.query(
            `UPDATE qr_scan_sessions SET blocked=TRUE WHERE token_hash=$1`,
            [row.scan_session_hash]
          );
        }
      }else if(row.conversation_id&&closeConversation){
        await client.query(
          `UPDATE qr_conversations
              SET status='closed',closed_at=COALESCE(closed_at,NOW()),updated_at=NOW()
            WHERE id=$1 AND status<>'blocked'`,
          [row.conversation_id]
        );
      }

      await writeAdminAudit(client,req,{
        action:status==='resolved'?'complaint.resolved':status==='dismissed'?'complaint.dismissed':status==='in_review'?'complaint.in_review':'complaint.reopened',
        targetType:'message_report',
        targetId:reportId,
        targetLabel:row.plate||row.qr_token||reportId,
        before:row,
        after:updated.rows[0],
        metadata:{adminNote:note||null,closeConversation,blockSession},
      });
      if(blockSession){
        await writeAdminAudit(client,req,{
          action:'complaint.session_blocked',
          targetType:'conversation',
          targetId:row.conversation_id,
          targetLabel:row.plate||row.qr_token||String(row.conversation_id),
          metadata:{reportId},
        });
      }else if(closeConversation){
        await writeAdminAudit(client,req,{
          action:'complaint.conversation_closed',
          targetType:'conversation',
          targetId:row.conversation_id,
          targetLabel:row.plate||row.qr_token||String(row.conversation_id),
          metadata:{reportId},
        });
      }
      await client.query('COMMIT');
      return res.json({ok:true,report:updated.rows[0]});
    }catch(e){
      try{await client.query('ROLLBACK');}catch(_){}
      console.error('admin moderation report update',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }finally{client.release();}
  });

  app.get('/api/admin/manage/communications',guard,async(req,res)=>{
    const requested=Number(req.query?.hours||24);
    const hours=[24,168,720].includes(requested)?requested:24;
    try{
      if(!await moderationReady())return res.status(503).json({error:'MODERATION_MIGRATION_REQUIRED'});
      const calls=await pool.query(
        `SELECT c.id,c.qr_token,c.status,c.recipient_type,c.created_at,c.answered_at,c.ended_at,c.expires_at,
                c.scan_session_hash,v.plate,v.owner_id,
                ou.display_name AS owner_name,
                ru.display_name AS recipient_name,ru.phone AS recipient_phone,
                CASE WHEN c.answered_at IS NOT NULL AND c.ended_at IS NOT NULL
                     THEN GREATEST(0,EXTRACT(EPOCH FROM (c.ended_at-c.answered_at))::int)
                     ELSE NULL END AS duration_seconds
           FROM anonymous_calls c
           LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
           LEFT JOIN users ou ON ou.id::text=v.owner_id::text
           LEFT JOIN users ru ON ru.id::text=c.recipient_user_id::text
          WHERE c.created_at>=NOW()-($1::text||' hours')::interval
          ORDER BY c.created_at DESC LIMIT 250`,
        [hours]
      );

      const conversations=await pool.query(
        `SELECT c.id,c.qr_token,c.status,c.created_at,c.updated_at,c.closed_at,c.scan_session_hash,
                v.plate,v.owner_id,u.display_name AS owner_name,u.phone AS owner_phone,
                COUNT(DISTINCT m.id)::int AS message_count,
                COUNT(DISTINCT r.id)::int AS report_count,
                MAX(m.created_at) AS last_message_at
           FROM qr_conversations c
           LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
           LEFT JOIN users u ON u.id::text=v.owner_id::text
           LEFT JOIN qr_conversation_messages m ON m.conversation_id=c.id
           LEFT JOIN message_reports r ON r.conversation_id=c.id
          WHERE c.created_at>=NOW()-($1::text||' hours')::interval
          GROUP BY c.id,c.qr_token,c.status,c.created_at,c.updated_at,c.closed_at,c.scan_session_hash,
                   v.plate,v.owner_id,u.display_name,u.phone
          ORDER BY c.updated_at DESC LIMIT 250`,
        [hours]
      );

      const callItems=calls.rows.map(x=>({...x,visitor_key:maskKey(x.scan_session_hash),scan_session_hash:undefined}));
      const conversationItems=conversations.rows.map(x=>({...x,visitor_key:maskKey(x.scan_session_hash),scan_session_hash:undefined}));

      const visitorMap=new Map();
      function visitor(hash){
        if(!hash)return null;
        let v=visitorMap.get(hash);
        if(!v){
          v={visitor_key:maskKey(hash),conversation_count:0,message_count:0,report_count:0,call_count:0,failed_call_count:0,first_seen:null,last_seen:null};
          visitorMap.set(hash,v);
        }
        return v;
      }
      for(const x of conversations.rows){
        const v=visitor(x.scan_session_hash);if(!v)continue;
        v.conversation_count++;
        v.message_count+=Number(x.message_count||0);
        v.report_count+=Number(x.report_count||0);
        const at=new Date(x.created_at);
        if(!v.first_seen||at<new Date(v.first_seen))v.first_seen=x.created_at;
        if(!v.last_seen||at>new Date(v.last_seen))v.last_seen=x.created_at;
      }
      for(const x of calls.rows){
        const v=visitor(x.scan_session_hash);if(!v)continue;
        v.call_count++;
        if(['missed','rejected','cancelled'].includes(String(x.status)))v.failed_call_count++;
        const at=new Date(x.created_at);
        if(!v.first_seen||at<new Date(v.first_seen))v.first_seen=x.created_at;
        if(!v.last_seen||at>new Date(v.last_seen))v.last_seen=x.created_at;
      }
      const visitors=[...visitorMap.values()].sort((a,b)=>new Date(b.last_seen)-new Date(a.last_seen)).slice(0,150);

      const callSummary={total:0,ringing:0,accepted:0,ended:0,missed:0,rejected:0,cancelled:0,failed:0};
      for(const x of calls.rows){
        callSummary.total++;
        const s=String(x.status||'');
        if(Object.prototype.hasOwnProperty.call(callSummary,s))callSummary[s]++;
        if(['missed','rejected','cancelled'].includes(s))callSummary.failed++;
      }
      const conversationSummary={
        total:conversations.rows.length,
        active:conversations.rows.filter(x=>x.status==='active').length,
        closed:conversations.rows.filter(x=>x.status==='closed').length,
        blocked:conversations.rows.filter(x=>x.status==='blocked').length,
        reported:conversations.rows.filter(x=>Number(x.report_count||0)>0).length,
        messages:conversations.rows.reduce((n,x)=>n+Number(x.message_count||0),0),
        anonymousVisitors:visitors.length,
      };
      return res.json({ok:true,hours,summary:{calls:callSummary,conversations:conversationSummary},calls:callItems,conversations:conversationItems,visitors});
    }catch(e){console.error('admin communications',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
