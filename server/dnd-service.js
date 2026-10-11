'use strict';

/**
 * Owner DND is a time-limited Premium feature.
 * It mutes QR message/call push notifications to the OWNER, not drivers,
 * safety/security alerts, or ordinary records retained in the app.
 */
async function isOwnerPremium(pool, ownerId) {
  if (!ownerId) return false;
  const r = await pool.query(
    `SELECT (COALESCE(premium,false)=TRUE
        AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium
       FROM users WHERE id::text=$1 LIMIT 1`,
    [String(ownerId)]
  );
  return r.rows[0]?.premium === true;
}

async function isOwnerDndActive(pool, ownerId) {
  if (!ownerId) return false;
  try {
    const r = await pool.query(
      `SELECT EXISTS(
         SELECT 1 FROM owner_dnd_settings d JOIN users u ON u.id::text=d.owner_id
         WHERE d.owner_id=$1 AND d.active_until>NOW()
           AND COALESCE(u.premium,false)=TRUE
           AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())
       ) AS active`,
      [String(ownerId)]
    );
    return r.rows[0]?.active === true;
  } catch (err) {
    // Table is lazily created by dnd-routes on first GET/PUT.
    // Before anybody activates DND it is safe to treat a missing table as off.
    if (err?.code === '42P01') return false;
    throw err;
  }
}

module.exports={isOwnerPremium,isOwnerDndActive};
