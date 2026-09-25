const crypto=require('crypto');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {requestIp}=require('./proxy-security');

module.exports=function registerQrSecurityRoutes(app,pool,pushService){
  let ready=false;
  const geoCache=new Map();

  async function ensureSchema(){
    if(ready)return;
    await pool.query(`
      CREATE TABLE IF NOT EXISTS qr_scan_history (
        id BIGSERIAL PRIMARY KEY,
        qr_token TEXT NOT NULL,
        vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
        owner_id TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS visitor_hash TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS scan_session_hash TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS city TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS region TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS country TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS location_source TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS suspicious BOOLEAN NOT NULL DEFAULT FALSE;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS suspicion_reason TEXT;
      ALTER TABLE qr_scan_history ADD COLUMN IF NOT EXISTS alerted_at TIMESTAMPTZ;
      CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_visitor_created
        ON qr_scan_history(vehicle_id,visitor_hash,created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_suspicious
        ON qr_scan_history(vehicle_id,suspicious,created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_qr_scan_history_scan_session
        ON qr_scan_history(scan_session_hash)
        WHERE scan_session_hash IS NOT NULL;
    `);
    ready=true;
  }

  function cleanHeader(v){
    const s=String(v||'').trim();
    if(!s)return '';
    try{return decodeURIComponent(s.replace(/\+/g,' ')).slice(0,120);}catch(_){return s.slice(0,120);}
  }

  function headerLocation(req){
    const city=cleanHeader(req.headers['cf-ipcity']||req.headers['x-vercel-ip-city']||req.headers['x-geo-city']);
    const region=cleanHeader(req.headers['cf-region']||req.headers['x-vercel-ip-country-region']||req.headers['x-geo-region']);
    const country=cleanHeader(req.headers['cf-ipcountry']||req.headers['x-vercel-ip-country']||req.headers['x-geo-country']);
    return {city,region,country,source:(city||region||country)?'edge_header':''};
  }

  function normalizeIp(raw){
    let ip=String(raw||'').trim();
    if(ip.startsWith('::ffff:'))ip=ip.slice(7);
    if(ip.includes(','))ip=ip.split(',')[0].trim();
    return ip;
  }

  function isPublicIp(ip){
    if(!ip||ip==='::1'||ip==='127.0.0.1')return false;
    if(/^10\./.test(ip)||/^192\.168\./.test(ip)||/^169\.254\./.test(ip))return false;
    const m=ip.match(/^172\.(\d+)\./);
    if(m&&Number(m[1])>=16&&Number(m[1])<=31)return false;
    if(/^fc/i.test(ip)||/^fd/i.test(ip)||/^fe80:/i.test(ip))return false;
    return true;
  }

  function visitorHash(ip){
    if(!ip)return null;
    const salt=String(process.env.QR_SECURITY_HASH_SALT||process.env.OWNER_AUTH_SECRET||process.env.SESSION_SECRET||'cepqar-qr-security');
    return crypto.createHash('sha256').update(`${salt}|${ip}`).digest('hex');
  }

  async function lookupIp(ip){
    if(!isPublicIp(ip))return null;
    const cached=geoCache.get(ip);
    if(cached&&cached.expires>Date.now())return cached.value;
    const controller=new AbortController();
    const timer=setTimeout(()=>controller.abort(),1600);
    try{
      const r=await fetch(`https://ipwho.is/${encodeURIComponent(ip)}`,{signal:controller.signal,headers:{accept:'application/json'}});
      if(!r.ok)return null;
      const d=await r.json();
      if(d?.success===false)return null;
      const value={
        city:String(d?.city||'').slice(0,120),
        region:String(d?.region||'').slice(0,120),
        country:String(d?.country_code||d?.country||'').slice(0,80),
        source:'ip_lookup',
      };
      if(!value.city&&!value.region&&!value.country)return null;
      geoCache.set(ip,{value,expires:Date.now()+6*60*60*1000});
      if(geoCache.size>500)geoCache.delete(geoCache.keys().next().value);
      return value;
    }catch(_){return null;}finally{clearTimeout(timer);}
  }

  async function enrichLocation(id,ip){
    const loc=await lookupIp(ip);
    if(!loc)return;
    await pool.query(
      `UPDATE qr_scan_history
          SET city=COALESCE(NULLIF(city,''),$2),
              region=COALESCE(NULLIF(region,''),$3),
              country=COALESCE(NULLIF(country,''),$4),
              location_source=COALESCE(NULLIF(location_source,''),$5)
        WHERE id=$1`,
      [id,loc.city||null,loc.region||null,loc.country||null,loc.source]
    ).catch(()=>{});
  }

  async function abuseAlertsEnabled(ownerId){
    try{
      const r=await pool.query('SELECT COALESCE(qr_abuse_protection,TRUE) enabled FROM owner_privacy_settings WHERE owner_id=$1 LIMIT 1',[String(ownerId)]);
      return r.rows.length?r.rows[0].enabled!==false:true;
    }catch(_){return true;}
  }

  async function recordScan({qr,req,scanSessionHash}){
    await ensureSchema();
    const ip=normalizeIp(requestIp(req));
    const hash=visitorHash(ip);
    const loc=headerLocation(req);
    const ins=await pool.query(
      `INSERT INTO qr_scan_history(
        qr_token,vehicle_id,owner_id,visitor_hash,scan_session_hash,city,region,country,location_source
      ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
      RETURNING id,created_at`,
      [qr.token,qr.vehicle_id,String(qr.owner_id),hash,scanSessionHash||null,loc.city||null,loc.region||null,loc.country||null,loc.source||null]
    );
    const row=ins.rows[0];
    if(!loc.city&&!loc.region&&isPublicIp(ip))enrichLocation(row.id,ip).catch(()=>{});

    const counts=await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE created_at>=NOW()-INTERVAL '10 minutes')::int AS vehicle_10m,
         COUNT(*) FILTER (
           WHERE created_at>=NOW()-INTERVAL '10 minutes'
             AND visitor_hash IS NOT NULL
             AND visitor_hash=$2
         )::int AS visitor_10m
       FROM qr_scan_history
       WHERE vehicle_id=$1`,
      [qr.vehicle_id,hash]
    );
    const vehicle10=Number(counts.rows[0]?.vehicle_10m||0);
    const visitor10=Number(counts.rows[0]?.visitor_10m||0);
    let reason='';
    if(hash&&visitor10>=6)reason='same_visitor_burst';
    else if(vehicle10>=20)reason='vehicle_scan_burst';

    if(reason){
      await pool.query(
        'UPDATE qr_scan_history SET suspicious=TRUE,suspicion_reason=$2 WHERE id=$1',
        [row.id,reason]
      );
      const recentAlert=await pool.query(
        `SELECT 1 FROM qr_scan_history
          WHERE vehicle_id=$1 AND alerted_at IS NOT NULL
            AND created_at>=NOW()-INTERVAL '30 minutes'
          LIMIT 1`,
        [qr.vehicle_id]
      );
      if(!recentAlert.rows.length&&await abuseAlertsEnabled(qr.owner_id)){
        await pool.query('UPDATE qr_scan_history SET alerted_at=NOW() WHERE id=$1',[row.id]);
        const body=reason==='same_visitor_burst'
          ? `${qr.plate||'Aracınız'} QR kodu aynı ağdan kısa sürede ${visitor10} kez okutuldu.`
          : `${qr.plate||'Aracınız'} QR kodu son 10 dakikada ${vehicle10} kez okutuldu.`;
        pushService?.sendOwner?.(
          String(qr.owner_id),
          {type:'qr_security_alert',sourceType:'qr_security',vehicleId:String(qr.vehicle_id),plate:String(qr.plate||''),eventId:`qr-security-${row.id}`},
          'Şüpheli QR hareketi',
          body
        ).catch(e=>console.error('qr security push',e));
      }
    }
    return {id:row.id,suspicious:Boolean(reason),reason};
  }

  app.get('/api/owner/vehicles/:vehicleId/qr-security',async(req,res)=>{
    const owner=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    if(!vehicleId)return res.status(400).json({error:'VEHICLE_REQUIRED'});
    try{
      await ensureSchema();
      const owned=await pool.query('SELECT id,plate,make,model FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',[vehicleId,owner]);
      if(!owned.rows.length)return res.status(404).json({error:'VEHICLE_NOT_FOUND'});
      const [stats,communications,recent,hours]=await Promise.all([
        pool.query(
          `SELECT
             COUNT(*)::int AS total,
             COUNT(*) FILTER (WHERE created_at>=CURRENT_DATE)::int AS today,
             COUNT(*) FILTER (WHERE created_at>=NOW()-INTERVAL '7 days')::int AS last_7_days,
             COUNT(*) FILTER (WHERE created_at>=NOW()-INTERVAL '30 days')::int AS last_30_days,
             COUNT(DISTINCT visitor_hash) FILTER (WHERE visitor_hash IS NOT NULL AND created_at>=NOW()-INTERVAL '30 days')::int AS unique_visitors_30_days,
             COUNT(*) FILTER (WHERE suspicious=TRUE AND created_at>=NOW()-INTERVAL '24 hours')::int AS suspicious_24h
           FROM qr_scan_history WHERE vehicle_id::text=$1`,
          [vehicleId]
        ),
        pool.query(
          `SELECT
             (SELECT COUNT(*)::int FROM vehicle_notifications
               WHERE vehicle_id::text=$1 AND qr_token IS NOT NULL AND type<>'call_request') AS messages,
             (SELECT COUNT(*)::int FROM anonymous_calls
               WHERE vehicle_id::text=$1) AS calls`,
          [vehicleId]
        ),
        pool.query(
          `SELECT id,created_at,city,region,country,suspicious,suspicion_reason
             FROM qr_scan_history
            WHERE vehicle_id::text=$1
            ORDER BY created_at DESC
            LIMIT 60`,
          [vehicleId]
        ),
        pool.query(
          `SELECT EXTRACT(HOUR FROM created_at AT TIME ZONE 'Europe/Istanbul')::int AS hour,
                  COUNT(*)::int AS count
             FROM qr_scan_history
            WHERE vehicle_id::text=$1
              AND created_at>=NOW()-INTERVAL '30 days'
            GROUP BY 1
            ORDER BY count DESC,hour ASC
            LIMIT 6`,
          [vehicleId]
        ),
      ]);
      return res.json({
        ok:true,
        vehicle:owned.rows[0],
        summary:{...stats.rows[0],...communications.rows[0]},
        recentScans:recent.rows,
        busyHours:hours.rows,
        privacy:{exactLocationStored:false,rawIpStored:false,locationIsApproximate:true},
      });
    }catch(e){
      console.error('qr security history',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  return {recordScan,ensureSchema};
};
