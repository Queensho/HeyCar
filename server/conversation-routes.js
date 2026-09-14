module.exports = function registerConversationRoutes(app, pool) {
  app.post('/api/qr/:token/conversations', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const notificationId = String(req.body?.notificationId || '').trim();
    const guestToken = String(req.body?.guestToken || '').trim().slice(0, 200);
    if (!token || !notificationId || !guestToken) return res.status(400).json({ error: 'INVALID_REQUEST' });
    try {
      const q = await pool.query(
        `SELECT n.id, n.vehicle_id
           FROM vehicle_notifications n
          WHERE n.id = $1 AND n.qr_token = $2
          LIMIT 1`,
        [notificationId, token]
      );
      if (!q.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const c = await pool.query(
        `INSERT INTO qr_conversations (vehicle_id, qr_token, notification_id, guest_token)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (notification_id) DO UPDATE SET updated_at = NOW()
         RETURNING id, guest_token, created_at`,
        [q.rows[0].vehicle_id, token, notificationId, guestToken]
      );
      const initial = String(req.body?.message || '').trim().slice(0, 1000);
      if (initial) {
        const exists = await pool.query(
          `SELECT 1 FROM qr_conversation_messages WHERE conversation_id = $1 LIMIT 1`,
          [c.rows[0].id]
        );
        if (!exists.rows.length) {
          await pool.query(
            `INSERT INTO qr_conversation_messages (conversation_id, sender, message)
             VALUES ($1, 'guest', $2)`,
            [c.rows[0].id, initial]
          );
        }
      }
      return res.status(201).json({ ok: true, conversation: c.rows[0] });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/qr/:token/conversations/:id', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const id = String(req.params.id || '').trim();
    const guestToken = String(req.headers['x-guest-token'] || '').trim();
    if (!guestToken) return res.status(401).json({ error: 'GUEST_REQUIRED' });
    try {
      const c = await pool.query(
        `SELECT id FROM qr_conversations WHERE id = $1 AND qr_token = $2 AND guest_token = $3 LIMIT 1`,
        [id, token, guestToken]
      );
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const m = await pool.query(
        `SELECT id, sender, message, created_at
           FROM qr_conversation_messages
          WHERE conversation_id = $1
          ORDER BY created_at ASC`,
        [id]
      );
      return res.json({ ok: true, messages: m.rows });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/qr/:token/conversations/:id/messages', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const id = String(req.params.id || '').trim();
    const guestToken = String(req.headers['x-guest-token'] || '').trim();
    const message = String(req.body?.message || '').trim().slice(0, 1000);
    if (!guestToken || !message) return res.status(400).json({ error: 'INVALID_REQUEST' });
    try {
      const c = await pool.query(
        `SELECT id FROM qr_conversations WHERE id = $1 AND qr_token = $2 AND guest_token = $3 LIMIT 1`,
        [id, token, guestToken]
      );
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const m = await pool.query(
        `INSERT INTO qr_conversation_messages (conversation_id, sender, message)
         VALUES ($1, 'guest', $2)
         RETURNING id, sender, message, created_at`,
        [id, message]
      );
      await pool.query(`UPDATE qr_conversations SET updated_at = NOW() WHERE id = $1`, [id]);
      return res.status(201).json({ ok: true, message: m.rows[0] });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/owner/notifications/:notificationId/conversation', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const notificationId = String(req.params.notificationId || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const c = await pool.query(
        `SELECT c.id
           FROM qr_conversations c
           JOIN vehicles v ON v.id = c.vehicle_id
          WHERE c.notification_id = $1 AND v.owner_id = $2
          LIMIT 1`,
        [notificationId, ownerId]
      );
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      return res.json({ ok: true, conversationId: c.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/owner/conversations/:id', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const id = String(req.params.id || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const c = await pool.query(
        `SELECT c.id
           FROM qr_conversations c
           JOIN vehicles v ON v.id = c.vehicle_id
          WHERE c.id = $1 AND v.owner_id = $2 LIMIT 1`,
        [id, ownerId]
      );
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const m = await pool.query(
        `SELECT id, sender, message, created_at
           FROM qr_conversation_messages
          WHERE conversation_id = $1
          ORDER BY created_at ASC`,
        [id]
      );
      return res.json({ ok: true, messages: m.rows });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/owner/conversations/:id/messages', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const id = String(req.params.id || '').trim();
    const message = String(req.body?.message || '').trim().slice(0, 1000);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!message) return res.status(400).json({ error: 'MESSAGE_REQUIRED' });
    try {
      const c = await pool.query(
        `SELECT c.id
           FROM qr_conversations c
           JOIN vehicles v ON v.id = c.vehicle_id
          WHERE c.id = $1 AND v.owner_id = $2 LIMIT 1`,
        [id, ownerId]
      );
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const m = await pool.query(
        `INSERT INTO qr_conversation_messages (conversation_id, sender, message)
         VALUES ($1, 'owner', $2)
         RETURNING id, sender, message, created_at`,
        [id, message]
      );
      await pool.query(`UPDATE qr_conversations SET updated_at = NOW() WHERE id = $1`, [id]);
      return res.status(201).json({ ok: true, message: m.rows[0] });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
};
