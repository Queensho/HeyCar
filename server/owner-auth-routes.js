const {issueTokens,rotateRefresh,revokeRefresh}=require('./owner-auth-service');
function normalizeTrMobile(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('90') && digits.length === 12) digits = digits.slice(2);
  else if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  if (!/^5\d{9}$/.test(digits)) return null;
  return `+90${digits}`;
}

module.exports = function registerOwnerAuthRoutes(app, pool) {
  app.post('/api/owner/login-phone', async (req, res) => {
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
        const exists = await pool.query('SELECT 1 FROM users WHERE phone = $1 LIMIT 1', [phone]);
        if (!exists.rows.length) return res.status(404).json({ error: 'USER_NOT_FOUND' });
        return res.status(401).json({ error: 'PASSWORD_INVALID' });
      }

      const user = userResult.rows[0];
      if (user.status !== 'active') {
        return res.status(403).json({ error: 'USER_SUSPENDED' });
      }

      const vehiclesResult = await pool.query(
        `SELECT v.id, v.owner_id, v.plate, v.make, v.model, v.color, v.created_at,
                q.token AS qr_token, q.status AS qr_status
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
  app.post('/api/owner/auth/refresh',async(req,res)=>{try{const refreshToken=String(req.body?.refreshToken||'');if(!refreshToken)return res.status(400).json({error:'REFRESH_REQUIRED'});const tokens=await rotateRefresh(pool,refreshToken);if(!tokens)return res.status(401).json({error:'REFRESH_INVALID'});return res.json({ok:true,...tokens});}catch(e){console.error('owner refresh error',e);return res.status(500).json({error:'SERVER_ERROR'});}});
  app.post('/api/owner/auth/logout',async(req,res)=>{try{await revokeRefresh(pool,String(req.body?.refreshToken||''));return res.json({ok:true});}catch(e){return res.status(500).json({error:'SERVER_ERROR'});}});
};
