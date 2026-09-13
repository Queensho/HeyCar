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
    const otpCode = String(req.body.otpCode || '').trim();

    if (!phone) return res.status(400).json({ error: 'INVALID_PHONE' });
    if (otpCode !== '123456') return res.status(400).json({ error: 'OTP_INVALID' });

    try {
      const userResult = await pool.query(
        `SELECT id, email, phone, display_name, role, status, created_at
         FROM users
         WHERE phone = $1
         LIMIT 1`,
        [phone]
      );

      if (!userResult.rows.length) {
        return res.status(404).json({ error: 'USER_NOT_FOUND' });
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

      return res.json({
        ok: true,
        user,
        vehicles: vehiclesResult.rows,
      });
    } catch (error) {
      console.error('owner phone login error', error);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
};
