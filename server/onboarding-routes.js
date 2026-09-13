function normalizeTrMobile(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('90') && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }
  if (!/^5\d{9}$/.test(digits)) return null;
  return `+90${digits}`;
}

module.exports = function registerOnboardingRoutes(app, pool) {
  app.post('/api/onboarding/register', async (req, res) => {
    const phone = normalizeTrMobile(req.body.phone);
    const displayName = String(req.body.displayName || '').trim();
    const emailRaw = String(req.body.email || '').trim().toLowerCase();
    const email = emailRaw || null;
    const password = String(req.body.password || '');
    const otpCode = String(req.body.otpCode || '').trim();
    const plate = String(req.body.plate || '').trim().toUpperCase();
    const make = String(req.body.make || '').trim();
    const model = String(req.body.model || '').trim();
    const color = String(req.body.color || '').trim();

    if (!phone) {
      return res.status(400).json({ error: 'INVALID_PHONE' });
    }
    if (otpCode !== '123456') {
      return res.status(400).json({ error: 'OTP_INVALID' });
    }
    if (!displayName || password.length < 6 || !plate || !make) {
      return res.status(400).json({ error: 'INVALID_INPUT' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const phoneExists = await client.query(
        'SELECT 1 FROM users WHERE phone = $1 LIMIT 1',
        [phone]
      );
      if (phoneExists.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'PHONE_EXISTS' });
      }

      if (email) {
        const exists = await client.query(
          'SELECT 1 FROM users WHERE lower(email) = $1 LIMIT 1',
          [email]
        );
        if (exists.rows.length) {
          await client.query('ROLLBACK');
          return res.status(409).json({ error: 'EMAIL_EXISTS' });
        }
      }

      const userResult = await client.query(
        `INSERT INTO users (email, phone, display_name, password_hash, role, status)
         VALUES ($1, $2, $3, crypt($4, gen_salt('bf', 12)), 'user', 'active')
         RETURNING id, email, phone, display_name, role, status, created_at`,
        [email, phone, displayName, password]
      );

      const user = userResult.rows[0];

      const vehicleResult = await client.query(
        `INSERT INTO vehicles (owner_id, plate, make, model, color)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, owner_id, plate, make, model, color, created_at`,
        [user.id, plate, make, model || null, color || null]
      );

      await client.query('COMMIT');

      return res.status(201).json({
        ok: true,
        user,
        vehicle: vehicleResult.rows[0],
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('onboarding register error', error);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client.release();
    }
  });
};
