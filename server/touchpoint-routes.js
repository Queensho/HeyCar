const express=require('express');
const rateLimit=require('express-rate-limit');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');

function cleanToken(raw){
  return String(raw||'').trim().toLowerCase();
}

module.exports=function registerTouchpointRoutes(app,pool){
  const nfcLimiter=rateLimit({
    windowMs:60*1000,
    limit:60,
    standardHeaders:'draft-7',
    legacyHeaders:false,
    message:{error:'TOO_MANY_REQUESTS'},
  });

  async function ensureTouchpoint(vehicleId,ownerId,mutate){
    const client=await pool.connect();
    try{
      await client.query('BEGIN');
      const vr=await client.query(
        'SELECT id,owner_id,plate,make,model FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1 FOR UPDATE',
        [vehicleId,ownerId]
      );
      if(!vr.rows.length){
        await client.query('ROLLBACK');
        return null;
      }
      const vehicle=vr.rows[0];

      const pageR=await client.query(
        `INSERT INTO vehicle_pages(vehicle_id,owner_id)
         VALUES($1,$2)
         ON CONFLICT(vehicle_id) DO UPDATE
           SET owner_id=EXCLUDED.owner_id,updated_at=NOW()
         RETURNING id,vehicle_id,owner_id,public_token,status,modules,created_at,updated_at`,
        [vehicle.id,vehicle.owner_id]
      );
      const page=pageR.rows[0];

      const qrR=await client.query(
        `SELECT id,token,status
           FROM qr_tags
          WHERE vehicle_id=$1
          ORDER BY (status='active') DESC,activated_at DESC NULLS LAST,created_at DESC
          LIMIT 1`,
        [vehicle.id]
      );
      const qr=qrR.rows[0]||null;

      let productR=await client.query(
        `SELECT id,vehicle_id,page_id,qr_tag_id,product_type,status,nfc_token,nfc_enabled,nfc_written_at,nfc_rotated_at,created_at,updated_at
           FROM vehicle_products
          WHERE vehicle_id=$1 AND product_type='vehicle_tag' AND status<>'revoked'
          ORDER BY created_at
          LIMIT 1
          FOR UPDATE`,
        [vehicle.id]
      );

      let product;
      if(productR.rows.length){
        productR=await client.query(
          `UPDATE vehicle_products
              SET page_id=$2,
                  qr_tag_id=COALESCE($3,qr_tag_id),
                  status='active',
                  updated_at=NOW()
            WHERE id=$1
            RETURNING id,vehicle_id,page_id,qr_tag_id,product_type,status,nfc_token,nfc_enabled,nfc_written_at,nfc_rotated_at,created_at,updated_at`,
          [productR.rows[0].id,page.id,qr?.id||null]
        );
        product=productR.rows[0];
      }else{
        productR=await client.query(
          `INSERT INTO vehicle_products(vehicle_id,page_id,qr_tag_id,product_type,status)
           VALUES($1,$2,$3,'vehicle_tag','active')
           RETURNING id,vehicle_id,page_id,qr_tag_id,product_type,status,nfc_token,nfc_enabled,nfc_written_at,nfc_rotated_at,created_at,updated_at`,
          [vehicle.id,page.id,qr?.id||null]
        );
        product=productR.rows[0];
      }

      const mutation=typeof mutate==='function'?await mutate(client,{vehicle,page,product,qr}):null;
      await client.query('COMMIT');
      return {vehicle,page,product,qr,mutation};
    }catch(e){
      await client.query('ROLLBACK').catch(()=>{});
      throw e;
    }finally{
      client.release();
    }
  }

  function publicWebBase(){
    const configured=String(process.env.PUBLIC_WEB_URL||'').trim();
    return (configured||'https://www.cepqontag.com').replace(/\/$/,'');
  }

  function publicNfcUrl(token){
    const configured=String(process.env.PUBLIC_API_URL||'').trim().replace(/\/$/,'');
    const base=configured||'https://heycar-api-185-165-46-213.nip.io';
    return `${base}/n/${encodeURIComponent(token)}`;
  }

  app.get('/api/owner/vehicles/:vehicleId/touchpoints',async(req,res)=>{
    const owner=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    if(!vehicleId)return res.status(400).json({error:'VEHICLE_REQUIRED'});
    try{
      const x=await ensureTouchpoint(vehicleId,owner);
      if(!x)return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      return res.json({
        ok:true,
        vehicle:{
          id:x.vehicle.id,
          plate:x.vehicle.plate,
          make:x.vehicle.make,
          model:x.vehicle.model,
        },
        page:{
          id:x.page.id,
          publicToken:x.page.public_token,
          status:x.page.status,
          modules:x.page.modules,
        },
        product:{
          id:x.product.id,
          type:x.product.product_type,
          status:x.product.status,
          qrToken:x.qr?.token||null,
          qrStatus:x.qr?.status||null,
          nfcEnabled:x.product.nfc_enabled===true,
          nfcUrl:publicNfcUrl(x.product.nfc_token),
          nfcWrittenAt:x.product.nfc_written_at,
          nfcRotatedAt:x.product.nfc_rotated_at,
        },
      });
    }catch(e){
      console.error('owner touchpoints',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.post('/api/owner/vehicles/:vehicleId/nfc/confirm',async(req,res)=>{
    const owner=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const x=await ensureTouchpoint(vehicleId,owner,async(client,current)=>{
        const r=await client.query(
          `UPDATE vehicle_products
              SET nfc_enabled=TRUE,nfc_written_at=NOW(),updated_at=NOW()
            WHERE id=$1
            RETURNING nfc_enabled,nfc_written_at`,
          [current.product.id]
        );
        return r.rows[0]||null;
      });
      if(!x)return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      return res.json({
        ok:true,
        nfcEnabled:true,
        nfcWrittenAt:x.mutation?.nfc_written_at||null,
        nfcUrl:publicNfcUrl(x.product.nfc_token),
      });
    }catch(e){
      console.error('nfc confirm',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.post('/api/owner/vehicles/:vehicleId/nfc/rotate',async(req,res)=>{
    const owner=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const x=await ensureTouchpoint(vehicleId,owner,async(client,current)=>{
        const r=await client.query(
          `UPDATE vehicle_products
              SET nfc_token=encode(gen_random_bytes(18),'hex'),
                  nfc_enabled=FALSE,
                  nfc_written_at=NULL,
                  nfc_rotated_at=NOW(),
                  updated_at=NOW()
            WHERE id=$1
            RETURNING nfc_token,nfc_rotated_at`,
          [current.product.id]
        );
        return r.rows[0]||null;
      });
      if(!x)return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      return res.json({
        ok:true,
        nfcEnabled:false,
        nfcUrl:publicNfcUrl(x.mutation.nfc_token),
        nfcRotatedAt:x.mutation.nfc_rotated_at,
      });
    }catch(e){
      console.error('nfc rotate',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/n/:nfcToken',nfcLimiter,async(req,res)=>{
    const token=cleanToken(req.params.nfcToken);
    if(!/^[a-f0-9]{36}$/.test(token))return res.status(404).send('Not found');
    try{
      const r=await pool.query(
        `SELECT p.id AS product_id,p.vehicle_id,p.page_id,q.token AS qr_token
           FROM vehicle_products p
           JOIN vehicle_pages pg ON pg.id=p.page_id AND pg.status='active'
           JOIN qr_tags q ON q.id=p.qr_tag_id AND q.status='active'
          WHERE p.nfc_token=$1
            AND p.nfc_enabled=TRUE
            AND p.status='active'
          LIMIT 1`,
        [token]
      );
      if(!r.rows.length)return res.status(404).send('NFC etiketi aktif değil.');
      const x=r.rows[0];
      await pool.query(
        `INSERT INTO vehicle_touchpoint_events(vehicle_id,page_id,product_id,source,event_type,metadata)
         VALUES($1,$2,$3,'nfc','view',$4::jsonb)`,
        [x.vehicle_id,x.page_id,x.product_id,JSON.stringify({entry:'nfc_redirect'})]
      ).catch(()=>{});
      const target=new URL(publicWebBase());
      target.searchParams.set('tag',String(x.qr_token));
      target.searchParams.set('src','nfc');
      res.set('Cache-Control','no-store');
      return res.redirect(302,target.toString());
    }catch(e){
      console.error('nfc resolve',e);
      return res.status(500).send('Server error');
    }
  });

  app.get('/api/owner/vehicles/:vehicleId/analytics',async(req,res)=>{
    const owner=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    const days=Math.max(1,Math.min(365,Number.parseInt(String(req.query.days||'30'),10)||30));
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const x=await ensureTouchpoint(vehicleId,owner);
      if(!x)return res.status(404).json({error:'VEHICLE_NOT_FOUND'});

      const [scanR,notificationR,callR,dailyR,sourceR]=await Promise.all([
        pool.query(
          `SELECT
             COUNT(*)::int AS scans,
             COUNT(*) FILTER (WHERE source='qr')::int AS qr_scans,
             COUNT(*) FILTER (WHERE source='nfc')::int AS nfc_scans,
             COUNT(DISTINCT visitor_hash) FILTER (WHERE visitor_hash IS NOT NULL)::int AS unique_visitors,
             COUNT(*) FILTER (WHERE suspicious=TRUE)::int AS suspicious
           FROM qr_scan_history
          WHERE vehicle_id=$1
            AND created_at>=NOW()-($2::text||' days')::interval`,
          [x.vehicle.id,days]
        ),
        pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE type<>'call_request')::int AS messages,
             COUNT(*) FILTER (WHERE type='call_request')::int AS call_requests
           FROM vehicle_notifications
          WHERE vehicle_id=$1
            AND created_at>=NOW()-($2::text||' days')::interval`,
          [x.vehicle.id,days]
        ),
        pool.query(
          `SELECT COUNT(*)::int AS calls,
                  COUNT(*) FILTER (WHERE status='accepted')::int AS accepted_calls
             FROM anonymous_calls
            WHERE vehicle_id=$1
              AND created_at>=NOW()-($2::text||' days')::interval`,
          [x.vehicle.id,days]
        ),
        pool.query(
          `SELECT
             d.day::date AS day,
             COALESCE(s.qr,0)::int AS qr,
             COALESCE(s.nfc,0)::int AS nfc,
             COALESCE(s.total,0)::int AS total
           FROM generate_series(
             CURRENT_DATE-($2::int-1),
             CURRENT_DATE,
             INTERVAL '1 day'
           ) d(day)
           LEFT JOIN (
             SELECT created_at::date AS day,
                    COUNT(*) FILTER (WHERE source='qr')::int AS qr,
                    COUNT(*) FILTER (WHERE source='nfc')::int AS nfc,
                    COUNT(*)::int AS total
               FROM qr_scan_history
              WHERE vehicle_id=$1
                AND created_at>=CURRENT_DATE-($2::int-1)
              GROUP BY created_at::date
           ) s ON s.day=d.day::date
           ORDER BY d.day`,
          [x.vehicle.id,days]
        ),
        pool.query(
          `SELECT source,COUNT(*)::int AS count
             FROM qr_scan_history
            WHERE vehicle_id=$1
              AND created_at>=NOW()-($2::text||' days')::interval
            GROUP BY source
            ORDER BY count DESC`,
          [x.vehicle.id,days]
        ),
      ]);

      const scans=scanR.rows[0]||{};
      const notifications=notificationR.rows[0]||{};
      const calls=callR.rows[0]||{};
      const totalScans=Number(scans.scans||0);
      const messages=Number(notifications.messages||0);
      const callCount=Number(calls.calls||0);
      const conversions=messages+callCount;
      const conversionRate=totalScans>0?Number(((conversions/totalScans)*100).toFixed(1)):0;

      return res.json({
        ok:true,
        days,
        page:{id:x.page.id,status:x.page.status},
        product:{
          id:x.product.id,
          type:x.product.product_type,
          nfcEnabled:x.product.nfc_enabled===true,
        },
        summary:{
          scans:totalScans,
          qrScans:Number(scans.qr_scans||0),
          nfcScans:Number(scans.nfc_scans||0),
          uniqueVisitors:Number(scans.unique_visitors||0),
          suspicious:Number(scans.suspicious||0),
          messages,
          calls:callCount,
          acceptedCalls:Number(calls.accepted_calls||0),
          callRequests:Number(notifications.call_requests||0),
          conversions,
          conversionRate,
        },
        sources:sourceR.rows,
        daily:dailyR.rows,
      });
    }catch(e){
      console.error('vehicle touchpoint analytics',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};
