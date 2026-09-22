const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const {driverId: authenticatedDriverId}=require('./driver-auth-service');
const { validateScanSession } = require('./scan-session-service');
const registerPushRoutes = require('./push-routes');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

module.exports = function registerCallRoutes(app, pool) {
  registerPushRoutes(app, pool);
  async function expireCalls() {
    await pool.query(`UPDATE anonymous_calls SET status='missed', ended_at=NOW() WHERE status='ringing' AND expires_at<=NOW()`);
  }

  async function sendRecipientPush(recipientId, recipientType, data, title, body, ownerId=null) {
    const push=app.locals.heycarPush;
    if(!push)return {owner:{attempted:0,delivered:0},driver:null};

    const ownerTarget=String(ownerId||recipientId||'');
    const ownerSender=push.sendOwner||push.send;
    const ownerResult=ownerTarget&&ownerSender
      ? await ownerSender(ownerTarget,{...data,recipientType:'owner'},title,body)
      : {attempted:0,delivered:0};

    let driverResult=null;
    if(recipientType==='driver'&&String(recipientId)!==ownerTarget&&push.sendDriver){
      driverResult=await push.sendDriver(
        String(recipientId),
        {...data,recipientType:'driver'},
        title,
        body,
      );
    }

    console.log('Call push delivery',{
      callId:String(data.callId||''),
      ownerId:ownerTarget,
      owner:ownerResult||null,
      recipientId:String(recipientId||''),
      recipientType,
      driver:driverResult,
    });

    return {owner:ownerResult||{attempted:0,delivered:0},driver:driverResult};
  }

  async function incomingFor(recipientId, recipientType) {
    await expireCalls();
    const result=await pool.query(
      `SELECT c.id,c.status,c.offer,c.caller_candidates,c.created_at,c.expires_at,c.recipient_type,v.plate
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
    const result=await pool.query(
      `SELECT id,status,offer,caller_candidates,created_at,expires_at,answered_at,ended_at,recipient_type
       FROM anonymous_calls
       WHERE id=$1 AND recipient_user_id=$2 AND recipient_type=$3
       LIMIT 1`,
      [callId,String(recipientId),recipientType]
    );
    return result.rows[0]||null;
  }

  async function updateFor(callId, recipientId, recipientType, body) {
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
           ended_at=CASE WHEN $4 IN ('rejected','ended') THEN NOW() ELSE ended_at END
       WHERE id=$1 AND recipient_user_id=$2 AND recipient_type=$3
       RETURNING id,status,answer,owner_candidates`,
      [callId,String(recipientId),recipientType,nextStatus,answer,candidate]
    );
    return {call:result.rows[0]||null};
  }

  app.post('/api/public/calls', async (req, res) => {
    try {
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
      const scan=await validateScanSession(pool,String(req.headers['x-scan-token']||''),token);
      if(!scan||String(scan.vehicle_id)!==String(vehicle.vehicle_id))return res.status(401).json({error:'SCAN_SESSION_REQUIRED'});

      const activeDriver=await pool.query(
        `SELECT driver_user_id::text AS driver_user_id
         FROM vehicle_active_drivers
         WHERE vehicle_id::text=$1::text
           AND driver_user_id IS NOT NULL
           AND (active_until IS NULL OR active_until>NOW())
         LIMIT 1`,
        [vehicle.vehicle_id]
      );
      const recipientType=activeDriver.rows.length?'driver':'owner';
      const recipientId=activeDriver.rows.length?String(activeDriver.rows[0].driver_user_id):String(vehicle.owner_id);

      const busy=await pool.query(
        `SELECT 1 FROM anonymous_calls
         WHERE recipient_user_id=$1
           AND status IN ('ringing','accepted')
           AND expires_at>NOW()
         LIMIT 1`,
        [recipientId]
      );
      if(busy.rows.length)return res.status(409).json({error:'OWNER_BUSY'});

      const created=await pool.query(
        `INSERT INTO anonymous_calls(qr_token,vehicle_id,owner_id,recipient_user_id,recipient_type)
         VALUES($1,$2,$3,$4,$5)
         RETURNING id,visitor_token,status,expires_at,recipient_type`,
        [token,vehicle.vehicle_id,vehicle.owner_id,recipientId,recipientType]
      );
      const call=created.rows[0];

      try{
        await sendRecipientPush(
          recipientId,
          recipientType,
          {type:'incoming_call',callId:String(call.id),visitorToken:String(call.visitor_token),vehicleId:String(vehicle.vehicle_id),plate:vehicle.plate||'',sentAt:String(Date.now())},
          'Gelen Araç Araması',
          `${vehicle.plate||'Aracınız'} için biri sizi arıyor`,
          String(vehicle.owner_id)
        );
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
    try {
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
         RETURNING id,status,recipient_user_id,recipient_type,owner_id`,
        [req.params.callId,visitorToken,offer,candidate,cancel]
      );
      if(!result.rows.length)return res.status(404).json({error:'CALL_NOT_FOUND'});
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
