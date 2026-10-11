const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const {driverId: authenticatedDriverId}=require('./driver-auth-service');
const { validateScanSession } = require('./scan-session-service');
const registerPushRoutes = require('./push-routes');
const {getAppSettings}=require('./app-settings-service');
const {enforcePublicRequest}=require('./security-service');
const {isOwnerDndActive}=require('./dnd-service');
const {sendCallPush}=require('./call-push-routing');
const {selectReachableCallRecipient}=require('./call-recipient-selection');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

module.exports = function registerCallRoutes(app, pool) {
  const pushService=registerPushRoutes(app, pool);
  async function expireCalls() {
    await pool.query(`UPDATE anonymous_calls SET status=CASE WHEN status='ringing' THEN 'missed' ELSE 'ended' END, ended_at=COALESCE(ended_at,NOW()) WHERE status IN ('ringing','accepted') AND expires_at<=NOW()`);
  }

  async function sendRecipientPush(recipientId,recipientType,data,title,body,ownerId=null) {
    return sendCallPush({
      pool,
      push:pushService||app.locals.heycarPush,
      recipientId,recipientType,data,title,body,ownerId,
      isOwnerDndActive,
    });
  }

  async function incomingFor(recipientId, recipientType) {
    if(recipientType==='owner'&&await isOwnerDndActive(pool,recipientId))return null;
    await expireCalls();
    const result=await pool.query(
      `SELECT c.id,c.status,c.offer,c.caller_candidates,c.created_at,c.expires_at,
              c.recipient_type,c.vehicle_id,v.plate,v.make,v.model
       FROM anonymous_calls c
       LEFT JOIN vehicles v ON v.id=c.vehicle_id
       WHERE c.recipient_user_id=$1 AND c.recipient_type=$2
         AND c.status='ringing' AND c.expires_at>NOW()
       ORDER BY c.created_at DESC
       LIMIT 1`,
      [String(recipientId),recipientType]
    );
    return result.rows[0]||null;
  }

  async function statusFor(callId, recipientId, recipientType) {
    await expireCalls();
    const result=await pool.query(
      `SELECT c.id,c.status,c.offer,c.caller_candidates,c.created_at,c.expires_at,
              c.answered_at,c.ended_at,c.recipient_type,c.vehicle_id,
              v.plate,v.make,v.model
       FROM anonymous_calls c
       LEFT JOIN vehicles v ON v.id=c.vehicle_id
       WHERE c.id=$1 AND c.recipient_user_id=$2 AND c.recipient_type=$3
       LIMIT 1`,
      [callId,String(recipientId),recipientType]
    );
    return result.rows[0]||null;
  }

  async function updateFor(callId, recipientId, recipientType, body) {
    await expireCalls();
    const action=String((body&&body.action)||'').trim();
    const nextStatus=action==='accept'?'accepted':action==='reject'?'rejected':action==='end'?'ended':null;
    const answer=body&&body.answer?JSON.stringify(body.answer):null;
    const candidate=body&&body.candidate?JSON.stringify(body.candidate):null;
    if(!nextStatus&&!candidate)return {error:'INVALID_ACTION'};

    const result=await pool.query(
      `UPDATE anonymous_calls
       SET status=COALESCE($4,status),
           answer=COALESCE($5::jsonb,answer),
           owner_candidates=CASE WHEN $6::jsonb IS NULL THEN owner_candidates ELSE owner_candidates || jsonb_build_array($6::jsonb) END,
           answered_at=CASE WHEN $4='accepted' THEN COALESCE(answered_at,NOW()) ELSE answered_at END,
           expires_at=CASE WHEN $4='accepted' THEN GREATEST(expires_at,NOW()+INTERVAL '2 hours') ELSE expires_at END,
           ended_at=CASE WHEN $4 IN ('rejected','ended') THEN NOW() ELSE ended_at END
       WHERE id=$1 AND recipient_user_id=$2 AND recipient_type=$3
         AND expires_at>NOW()
         AND (($4='accepted' AND status='ringing') OR ($4='rejected' AND status='ringing') OR ($4='ended' AND status IN ('ringing','accepted')) OR ($4 IS NULL AND status IN ('ringing','accepted')))
       RETURNING id,status,answer,owner_candidates`,
      [callId,String(recipientId),recipientType,nextStatus,answer,candidate]
    );
    return {call:result.rows[0]||null};
  }

  app.post('/api/public/calls', async (req, res) => {
    try {
      const runtime=await getAppSettings(pool);
      if(runtime.features?.calls===false)return res.status(503).json({error:'CALLS_FEATURE_DISABLED'});
      const token=normalizeToken(req.body&&(req.body.qrToken||req.body.token));
      if(!token)return res.status(400).json({error:'TOKEN_REQUIRED'});

      const qr=await pool.query(
        `SELECT q.vehicle_id,v.owner_id,v.plate
         FROM qr_tags q
         JOIN vehicles v ON v.id=q.vehicle_id
         WHERE q.token=$1 AND q.status='active'
         LIMIT 1`,
        [token]
      );
      if(!qr.rows.length)return res.status(404).json({error:'ACTIVE_QR_NOT_FOUND'});

      const vehicle=qr.rows[0];
      const security=await enforcePublicRequest(pool,token,req);
      if(!security.ok)return res.status(security.status).json({error:security.error});
      const scan=await validateScanSession(pool,String(req.headers['x-scan-token']||''),token);
      if(!scan||String(scan.vehicle_id)!==String(vehicle.vehicle_id))return res.status(401).json({error:'SCAN_SESSION_REQUIRED'});
      const rate=await pool.query(`WITH lock_key AS (SELECT pg_advisory_xact_lock(hashtextextended($1,0))), recent AS (SELECT COUNT(*)::int AS n FROM anonymous_call_attempts,lock_key WHERE scan_session_hash=$1 AND attempted_at>NOW()-INTERVAL '10 minutes'), inserted AS (INSERT INTO anonymous_call_attempts(scan_session_hash) SELECT $1 FROM lock_key,recent WHERE recent.n<5 RETURNING 1) SELECT n,(SELECT COUNT(*) FROM inserted)::int AS accepted FROM recent`,[scan.token_hash||'']);
      if(Number(rate.rows[0]?.accepted||0)!==1)return res.status(429).json({error:'CALL_RATE_LIMITED'});
      if(Number(rate.rows[0]?.attempts||0)>5)return res.status(429).json({error:'CALL_RATE_LIMITED'});

      const recipient=await selectReachableCallRecipient(pool,vehicle.vehicle_id,vehicle.owner_id,{
        webPushEnabled:Boolean(process.env.WEB_PUSH_VAPID_PUBLIC_KEY&&process.env.WEB_PUSH_VAPID_PRIVATE_KEY),
      });
      const recipientType=recipient.recipientType;
      const recipientId=recipient.recipientId;
      // An owner who enabled DND cannot be rung; active drivers remain reachable.
      if(recipientType==='owner'&&await isOwnerDndActive(pool,vehicle.owner_id)){
        return res.status(409).json({error:'OWNER_DND_ACTIVE'});
      }

      await expireCalls();
      let created;
      try{
        created=await pool.query(
          `INSERT INTO anonymous_calls(qr_token,vehicle_id,owner_id,recipient_user_id,recipient_type,scan_session_hash)
           VALUES($1,$2,$3,$4,$5,$6)
           RETURNING id,visitor_token,status,expires_at,recipient_type`,
          [token,vehicle.vehicle_id,vehicle.owner_id,recipientId,recipientType,scan.token_hash||null]
        );
      }catch(e){
        if(e&&e.code==='23505'&&String(e.constraint||'')==='uq_anonymous_calls_active_recipient'){
          return res.status(409).json({error:'OWNER_BUSY'});
        }
        throw e;
      }
      const call=created.rows[0];

      try{
        const dispatched=await sendRecipientPush(
          recipientId,
          recipientType,
          {type:'incoming_call',callId:String(call.id),visitorToken:String(call.visitor_token),vehicleId:String(vehicle.vehicle_id),plate:vehicle.plate||'',sentAt:String(Date.now())},
          'Gelen Araç Araması',
          `${vehicle.plate||'Aracınız'} için biri sizi arıyor`,
          String(vehicle.owner_id)
        );
        // Response metadata must reflect the authoritative DB recipient too.
        if(dispatched.routedTo==='owner')call.recipient_type='owner';
      }catch(err){
        console.error('incoming call push',err);
      }

      return res.status(201).json({ok:true,call,plate:vehicle.plate});
    } catch(e) {
      console.error('call create',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/public/calls/:callId', async (req,res) => {
    const callId=String(req.params.callId||'');
    if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(callId)) {
      return res.status(400).json({error:'INVALID_CALL_ID'});
    }
    try {
      await expireCalls();
      const visitorToken=String(req.headers['x-visitor-token']||'').trim();
      if(!visitorToken)return res.status(401).json({error:'VISITOR_TOKEN_REQUIRED'});
      const result=await pool.query(
        `SELECT id,status,answer,owner_candidates,expires_at,answered_at,ended_at
         FROM anonymous_calls
         WHERE id=$1 AND visitor_token::text=$2
         LIMIT 1`,
        [req.params.callId,visitorToken]
      );
      if(!result.rows.length)return res.status(404).json({error:'CALL_NOT_FOUND'});
      return res.json({ok:true,call:result.rows[0]});
    } catch(e) {
      console.error('call public status',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/public/calls/:callId', async (req,res) => {
    const callId=String(req.params.callId||'');
    if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(callId)) {
      return res.status(400).json({error:'INVALID_CALL_ID'});
    }
    await expireCalls();
    try {
      const visitorToken=String(req.headers['x-visitor-token']||'').trim();
      if(!visitorToken)return res.status(401).json({error:'VISITOR_TOKEN_REQUIRED'});
      const offer=req.body&&req.body.offer?JSON.stringify(req.body.offer):null;
      const candidate=req.body&&req.body.candidate?JSON.stringify(req.body.candidate):null;
      const cancel=req.body&&req.body.action==='cancel';
      const result=await pool.query(
        `UPDATE anonymous_calls
         SET offer=COALESCE($3::jsonb,offer),
             caller_candidates=CASE WHEN $4::jsonb IS NULL THEN caller_candidates ELSE caller_candidates || jsonb_build_array($4::jsonb) END,
             status=CASE WHEN $5 THEN 'cancelled' ELSE status END,
             ended_at=CASE WHEN $5 THEN NOW() ELSE ended_at END
         WHERE id=$1 AND visitor_token::text=$2
         AND expires_at>NOW()
         AND status IN ('ringing','accepted')
       RETURNING id,status,recipient_user_id,recipient_type,owner_id`,
        [req.params.callId,visitorToken,offer,candidate,cancel]
      );
      if(!result.rows.length)return res.status(409).json({error:'CALL_NOT_ACTIVE'});
      const call=result.rows[0];
      if(cancel){
        sendRecipientPush(
          call.recipient_user_id,
          call.recipient_type,
          {type:'incoming_call_cancelled',callId:String(call.id)},
          'Arama sona erdi',
          'Arayan kişi aramayı kapattı',
          String(call.owner_id||'')
        ).catch(err=>console.error('incoming call cancel push',err));
      }
      return res.json({ok:true,call});
    } catch(e) {
      console.error('call public update',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/owner/calls/incoming', async (req,res) => {
    try {
      const ownerId=authenticatedOwnerId(req);
      if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
      return res.json({ok:true,call:await incomingFor(ownerId,'owner')});
    } catch(e) {
      console.error('incoming owner call',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/owner/calls/:callId', async (req,res) => {
    try {
      const ownerId=authenticatedOwnerId(req);
      if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
      const call=await statusFor(req.params.callId,ownerId,'owner');
      if(!call)return res.status(404).json({error:'CALL_NOT_FOUND'});
      return res.json({ok:true,call});
    } catch(e) {
      console.error('owner call status',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/owner/calls/:callId', async (req,res) => {
    try {
      const ownerId=authenticatedOwnerId(req);
      if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
      const result=await updateFor(req.params.callId,ownerId,'owner',req.body);
      if(result.error)return res.status(400).json({error:result.error});
      if(!result.call)return res.status(404).json({error:'CALL_NOT_FOUND'});
      return res.json({ok:true,call:result.call});
    } catch(e) {
      console.error('owner call update',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/driver/calls/incoming', async (req,res) => {
    try {
      const driverId=authenticatedDriverId(req);
      if(!driverId)return res.status(401).json({error:'DRIVER_REQUIRED'});
      return res.json({ok:true,call:await incomingFor(driverId,'driver')});
    } catch(e) {
      console.error('incoming driver call',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/driver/calls/:callId', async (req,res) => {
    try {
      const driverId=authenticatedDriverId(req);
      if(!driverId)return res.status(401).json({error:'DRIVER_REQUIRED'});
      const call=await statusFor(req.params.callId,driverId,'driver');
      if(!call)return res.status(404).json({error:'CALL_NOT_FOUND'});
      return res.json({ok:true,call});
    } catch(e) {
      console.error('driver call status',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/driver/calls/:callId', async (req,res) => {
    try {
      const driverId=authenticatedDriverId(req);
      if(!driverId)return res.status(401).json({error:'DRIVER_REQUIRED'});
      const result=await updateFor(req.params.callId,driverId,'driver',req.body);
      if(result.error)return res.status(400).json({error:result.error});
      if(!result.call)return res.status(404).json({error:'CALL_NOT_FOUND'});
      return res.json({ok:true,call:result.call});
    } catch(e) {
      console.error('driver call update',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};
