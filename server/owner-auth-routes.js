const {issueTokens,rotateRefresh,revokeRefresh,ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {issueRecoveryCode,recoverPassword,verifyPassword,deleteAccount}=require('./account-lifecycle-service');
const {logSecurityEvent}=require('./security-event-log');
const { configureTrustedProxy } = require('./proxy-security');
const rateLimit=require('express-rate-limit');
function normalizeTrMobile(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('90') && digits.length === 12) digits = digits.slice(2);
  else if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  if (!/^5\d{9}$/.test(digits)) return null;
  return `+90${digits}`;
}

module.exports = function registerOwnerAuthRoutes(app, pool) {
  configureTrustedProxy(app);
  const loginLimiter=rateLimit({
    windowMs:15*60*1000,
    limit:10,
    standardHeaders:'draft-7',
    legacyHeaders:false,
    skipSuccessfulRequests:true,
    message:{error:'TOO_MANY_ATTEMPTS'},
  });
  app.post('/api/owner/login-phone', loginLimiter, async (req, res) => {
    const phone = normalizeTrMobile(req.body.phone);
    const password = String(req.body.password || '');

    if (!phone) return res.status(400).json({ error: 'INVALID_PHONE' });
    if (password.length < 6) return res.status(400).json({ error: 'PASSWORD_INVALID' });

    try {
      const userResult = await pool.query(
        `SELECT id, email, phone, display_name, role, status, created_at
         FROM users
         WHERE phone = $1
           AND password_hash = crypt($2, password_hash)
         LIMIT 1`,
        [phone, password]
      );

      if (!userResult.rows.length) {
        const exists = await pool.query('SELECT id::text AS id FROM users WHERE phone = $1 LIMIT 1', [phone]);
        await logSecurityEvent(pool,req,{
          eventType:'failed_login',
          ownerId:exists.rows[0]?.id||null,
          subject:phone,
          detail:{reason:exists.rows.length?'password_invalid':'user_not_found'}
        });
        return res.status(401).json({ error: 'INVALID_CREDENTIALS' });
      }

      const user = userResult.rows[0];
      if (user.status !== 'active') {
        return res.status(403).json({ error: 'USER_SUSPENDED' });
      }

      const vehiclesResult = await pool.query(
        `SELECT v.id, v.owner_id, v.plate, v.make, v.model, v.color, v.created_at,
                q.token AS qr_token, q.status AS qr_status, q.scan_secret AS qr_scan_secret
         FROM vehicles v
         LEFT JOIN qr_tags q ON q.vehicle_id = v.id
         WHERE v.owner_id = $1
         ORDER BY v.created_at DESC`,
        [user.id]
      );

      const tokens=await issueTokens(pool,user.id);
      return res.json({ok:true,user,vehicles:vehiclesResult.rows,...tokens});
    } catch (error) {
      console.error('owner phone/password login error', error);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
  app.post('/api/account/recover',async(req,res)=>{try{
    const mode=String(req.body?.mode||'owner');
    const out=await recoverPassword(pool,{phone:req.body?.phone,recoveryCode:req.body?.recoveryCode,newPassword:req.body?.newPassword,mode});
    if(!out.ok){
      if(out.error==='RECOVERY_RATE_LIMITED'){
        await logSecurityEvent(pool,req,{eventType:'recovery_rate_limited',subject:String(req.body?.phone||''),detail:{mode}});
      }
      const status=out.error==='RECOVERY_RATE_LIMITED'?429:out.error==='INVALID_INPUT'?400:401;
      return res.status(status).json({error:out.error});
    }
    return res.json({ok:true});
  }catch(e){console.error('account recovery error',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.patch('/api/owner/account/profile',async(req,res)=>{
    const ownerId=authenticatedOwnerId(req);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const displayName=String(req.body?.displayName||'').trim().replace(/\s+/g,' ').slice(0,120);
    const phone=normalizeTrMobile(req.body?.phone);
    const emailRaw=String(req.body?.email||'').trim().toLowerCase();
    const email=emailRaw||null;
    if(displayName.length<2)return res.status(400).json({error:'DISPLAY_NAME_REQUIRED'});
    if(!phone)return res.status(400).json({error:'INVALID_PHONE'});
    if(email&&(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>240))return res.status(400).json({error:'INVALID_EMAIL'});
    try{
      const duplicate=await pool.query(
        `SELECT id::text AS id,
                CASE WHEN phone=$2 THEN 'PHONE_IN_USE' ELSE 'EMAIL_IN_USE' END AS error
           FROM users
          WHERE id::text<>$1
            AND (phone=$2 OR ($3::text IS NOT NULL AND lower(email)=$3))
          LIMIT 1`,
        [ownerId,phone,email]
      );
      if(duplicate.rows.length)return res.status(409).json({error:duplicate.rows[0].error});
      const updated=await pool.query(
        `UPDATE users
            SET display_name=$2,phone=$3,email=$4
          WHERE id::text=$1 AND status='active'
          RETURNING id,email,phone,display_name,role,status,created_at`,
        [ownerId,displayName,phone,email]
      );
      if(!updated.rows.length)return res.status(404).json({error:'USER_NOT_FOUND'});
      return res.json({ok:true,user:updated.rows[0]});
    }catch(e){
      if(e&&e.code==='23505'){
        const detail=String(e.detail||'').toLowerCase();
        return res.status(409).json({error:detail.includes('email')?'EMAIL_IN_USE':'PHONE_IN_USE'});
      }
      console.error('owner profile update error',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
  app.post('/api/owner/account/recovery-code',async(req,res)=>{try{const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});const code=await issueRecoveryCode(pool,ownerId);return res.json({ok:true,recoveryCode:code});}catch(e){console.error('owner recovery code error',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.delete('/api/owner/account',async(req,res)=>{try{const ownerId=authenticatedOwnerId(req);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});const password=String(req.body?.password||'');if(password.length<6)return res.status(400).json({error:'PASSWORD_REQUIRED'});if(!await verifyPassword(pool,ownerId,password))return res.status(401).json({error:'PASSWORD_INVALID'});const out=await deleteAccount(pool,ownerId,{mode:'owner'});if(!out.ok)return res.status(out.error==='USER_NOT_FOUND'?404:409).json({error:out.error});return res.json({ok:true});}catch(e){console.error('owner account delete error',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.post('/api/owner/auth/refresh',async(req,res)=>{try{const refreshToken=String(req.body?.refreshToken||'');if(!refreshToken)return res.status(400).json({error:'REFRESH_REQUIRED'});const tokens=await rotateRefresh(pool,refreshToken);if(!tokens)return res.status(401).json({error:'REFRESH_INVALID'});return res.json({ok:true,...tokens});}catch(e){console.error('owner refresh error',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.post('/api/owner/auth/logout',async(req,res)=>{try{await revokeRefresh(pool,String(req.body?.refreshToken||''));return res.json({ok:true});}catch(e){return res.status(500).json({error:'SERVER_ERROR'});}});
};
