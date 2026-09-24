function requestIp(req){
  const forwarded=String(req?.headers?.['x-forwarded-for']||'').split(',')[0].trim();
  return (forwarded||req?.ip||req?.socket?.remoteAddress||'').toString().slice(0,120)||null;
}

async function tableReady(pool){
  const r=await pool.query("SELECT to_regclass('public.admin_security_events') AS name");
  return Boolean(r.rows[0]?.name);
}

async function logSecurityEvent(pool,req,{eventType,ownerId=null,subject=null,detail={}}){
  try{
    if(!await tableReady(pool))return false;
    await pool.query(
      `INSERT INTO admin_security_events(event_type,owner_id,subject,detail,ip_address)
       VALUES($1,$2,$3,$4::jsonb,$5)`,
      [
        String(eventType||'unknown').slice(0,100),
        ownerId==null?null:String(ownerId).slice(0,120),
        subject==null?null:String(subject).slice(0,240),
        JSON.stringify(detail&&typeof detail==='object'?detail:{}),
        requestIp(req),
      ]
    );
    return true;
  }catch(e){
    console.error('security event log',e);
    return false;
  }
}

module.exports={logSecurityEvent,requestIp,tableReady};
