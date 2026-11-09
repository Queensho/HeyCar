const {legacyRolePredicate}=require('./offer-actor-compat');
const crypto = require('node:crypto');
class OfferError extends Error {
  constructor(code, status = 409) { super(code); this.code = code; this.status = status; }
}
const normalizePlate = value => String(value || '').trim().toUpperCase().replace(/\s+/g, '');
async function authorizedVehicle(db, actor, plate, lock = false) {
  if (!actor || !['owner','driver','legacy'].includes(actor.role)) throw new OfferError('AUTH_REQUIRED',401);
  if (actor.role === 'legacy') {
    // Never choose a role by trial order. Ambiguous legacy identity stays private.
    const roles=[];
    for(const role of ['owner','driver']) {
      try { await authorizedVehicle(db,{id:actor.id,role},plate,lock); roles.push(role); }
      catch(e) { if(!['VEHICLE_NOT_OWNED','DRIVER_NOT_AUTHORIZED'].includes(e.code)) throw e; }
    }
    if(roles.length!==1) throw new OfferError('LEGACY_IDENTITY_REQUIRES_REVIEW',409);
    return roles[0];
  }
  const sql = actor.role === 'owner'
    ? `SELECT v.id FROM vehicles v WHERE v.owner_id::text=$1 AND regexp_replace(UPPER(v.plate),'[[:space:]]+','','g')=$2${lock ? ' FOR SHARE OF v' : ''}`
    : `SELECT v.id FROM vehicle_drivers d JOIN vehicles v ON v.id::text=d.vehicle_id::text WHERE d.driver_user_id::text=$1 AND regexp_replace(UPPER(v.plate),'[[:space:]]+','','g')=$2${lock ? ' FOR SHARE OF v,d' : ''}`;
  const q = await db.query(sql, [actor.id, plate]);
  if (!q.rowCount) throw new OfferError(actor.role === 'driver' ? 'DRIVER_NOT_AUTHORIZED' : 'VEHICLE_NOT_OWNED', 403);
  return actor.role;
}
async function campaignLock(db, id) {
  // All issuing/verifying operations acquire campaign, business, then redemption.
  // Read again after waiting for the campaign lock: counters and the wall clock
  // must be fresh even when another transaction held this lock across expiry.
  const locked = await db.query('SELECT id FROM business_campaigns WHERE id=$1 FOR UPDATE', [id]);
  if (!locked.rowCount) throw new OfferError('OFFER_NOT_AVAILABLE', 404);
  await db.query('SELECT b.id FROM businesses b JOIN business_campaigns c ON c.business_id=b.id WHERE c.id=$1 FOR SHARE OF b',[id]);
  const q = await db.query(`SELECT c.*,b.account_id, (c.is_active AND c.moderation_status='approved' AND b.is_active AND b.approval_status='approved' AND clock_timestamp() BETWEEN c.starts_at AND c.ends_at) available
    FROM business_campaigns c JOIN businesses b ON b.id=c.business_id WHERE c.id=$1`, [id]);
  if (!q.rows[0]?.available) throw new OfferError('OFFER_NOT_AVAILABLE', 410);
  return q.rows[0];
}
async function checkLimits(db, c) {
  // Old deployments may have undercounted the cached counter. The completed
  // ledger is authoritative; a larger historical counter remains conservative.
  const q=await db.query(`SELECT count(*)::bigint total,
    count(*) FILTER(WHERE redeemed_at>=date_trunc('day',clock_timestamp()) AND redeemed_at<date_trunc('day',clock_timestamp())+interval '1 day')::bigint daily
    FROM offer_redemptions WHERE campaign_id=$1 AND status='redeemed'`,[c.id]);
  if(c.total_limit!=null&&Math.max(Number(c.redemption_count),Number(q.rows[0].total))>=Number(c.total_limit))throw new OfferError('OFFER_TOTAL_LIMIT_REACHED');
  if(c.daily_limit!=null&&Number(q.rows[0].daily)>=Number(c.daily_limit))throw new OfferError('OFFER_DAILY_LIMIT_REACHED');
}
async function transaction(pool, work) {
  for(let attempt=0;attempt<3;attempt++) {
    const db=await pool.connect();
    try { await db.query('BEGIN'); const result=await work(db); await db.query('COMMIT'); return result; }
    catch(e) {
      await db.query('ROLLBACK').catch(()=>{});
      if(!['40P01','40001'].includes(e.code)||attempt===2) throw e;
    } finally { db.release(); }
  }
}
async function issue(pool, actor, campaignId, rawPlate) {
  if (!actor || !['owner','driver'].includes(actor.role)) throw new OfferError('AUTH_REQUIRED', 401);
  const plate = normalizePlate(rawPlate);
  if (!plate || plate.length > 24) throw new OfferError('PLATE_REQUIRED', 400);
  return transaction(pool, async db => {
    await campaignLock(db, campaignId);
    await authorizedVehicle(db, actor, plate, true);
    const c=await campaignLock(db,campaignId);
    await checkLimits(db, c);
    const old = await db.query(`SELECT r.* FROM offer_redemptions r WHERE r.owner_id=$1 AND ${legacyRolePredicate()} AND r.campaign_id=$3 AND r.status='pending' ORDER BY (r.actor_role=$2) DESC,r.created_at DESC`, [actor.id, actor.role, campaignId]);
    if (old.rowCount) {
      if (old.rows[0].plate !== plate) throw new OfferError('PENDING_VEHICLE_MISMATCH');
      return {redemption: old.rows[0], created: false};
    }
    // 128 bits of entropy; savepoints keep a rare uniqueness collision from
    // aborting the transaction before retrying.
    for (let attempt = 0; attempt < 5; attempt++) {
      await db.query('SAVEPOINT usage_code');
      try {
        const q = await db.query(`INSERT INTO offer_redemptions(owner_id,actor_role,campaign_id,plate,usage_code) VALUES($1,$2,$3,$4,$5) RETURNING *`, [actor.id, actor.role, campaignId, plate, crypto.randomBytes(16).toString('hex').toUpperCase()]);
        return {redemption: q.rows[0], created: true};
      } catch (e) { await db.query('ROLLBACK TO SAVEPOINT usage_code'); if (e.code !== '23505') throw e; }
    }
    throw new OfferError('CODE_GENERATION_FAILED', 503);
  });
}
async function verify(pool, accountId, rawCode, rawPlate) {
  const code = String(rawCode || '').trim().toUpperCase(), plate = normalizePlate(rawPlate);
  if (!code || code.length > 64 || !plate || plate.length > 24) throw new OfferError('CODE_AND_PLATE_REQUIRED', 400);
  return transaction(pool, async db => {
    const found = await db.query(`SELECT r.id,r.campaign_id FROM offer_redemptions r JOIN business_campaigns c ON c.id=r.campaign_id JOIN businesses b ON b.id=c.business_id WHERE b.account_id=$1 AND r.usage_code=$2 AND r.plate=$3`, [accountId, code, plate]);
    if (!found.rowCount) throw new OfferError('CODE_NOT_FOUND', 404);
    const c = await campaignLock(db, found.rows[0].campaign_id);
    const q = await db.query('SELECT * FROM offer_redemptions WHERE id=$1 FOR UPDATE', [found.rows[0].id]);
    const r = q.rows[0];
    if(c.account_id!==accountId) throw new OfferError('CODE_NOT_FOUND',404);
    if (r.status !== 'pending') throw new OfferError('ALREADY_USED');
    await authorizedVehicle(db, {id: r.owner_id, role: r.actor_role}, plate, true);
    await campaignLock(db,c.id);
    await checkLimits(db, c);
    const used = await db.query(`UPDATE offer_redemptions SET status='redeemed',redeemed_at=clock_timestamp(),platform_fee=$2 WHERE id=$1 AND status='pending' RETURNING *`, [r.id, c.platform_fee]);
    if (!used.rowCount) throw new OfferError('ALREADY_USED');
    await db.query(`UPDATE business_campaigns SET redemption_count=GREATEST(redemption_count+1,(SELECT count(*)::int FROM offer_redemptions WHERE campaign_id=$1 AND status='redeemed')),updated_at=clock_timestamp() WHERE id=$1`, [c.id]);
    return used.rows[0];
  });
}
module.exports = {issue, verify, normalizePlate, OfferError, transaction, authorizedVehicle};
