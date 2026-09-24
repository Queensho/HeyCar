const TZ = 'Europe/Istanbul';

async function tableExists(pool, tableName) {
  const r = await pool.query('SELECT to_regclass($1) AS name', ['public.' + tableName]);
  return Boolean(r.rows[0]?.name);
}

async function columnExists(pool, tableName, columnName) {
  const r = await pool.query(
    "SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 AND column_name=$2 LIMIT 1",
    [tableName, columnName]
  );
  return Boolean(r.rows.length);
}

module.exports = function registerAdminReportRoutes(app, pool, adminGuard) {
  const guard = typeof adminGuard === 'function'
    ? adminGuard
    : (_req, res) => res.status(500).json({ error: 'ADMIN_GUARD_NOT_CONFIGURED' });

  app.get('/api/admin/manage/reports', guard, async (req, res) => {
    const requested = Number(req.query?.days || 30);
    const days = [7, 30, 90].includes(requested) ? requested : 30;
    const startExpr = "(NOW() AT TIME ZONE '" + TZ + "')::date - ($1::int - 1)";

    try {
      const dateRows = await pool.query(
        "SELECT TO_CHAR(d,'YYYY-MM-DD') AS day " +
        "FROM generate_series(" +
        "(NOW() AT TIME ZONE '" + TZ + "')::date - ($1::int - 1)," +
        "(NOW() AT TIME ZONE '" + TZ + "')::date," +
        "INTERVAL '1 day') d ORDER BY d",
        [days]
      );

      const daily = dateRows.rows.map((x) => ({
        day: x.day,
        activeUsers: 0,
        qrScans: 0,
        notifications: 0,
        calls: 0,
        messages: 0,
        registrations: 0,
        offerRequests: 0,
        offerRedeemed: 0,
      }));
      const byDay = new Map(daily.map((x) => [x.day, x]));

      async function mergeCount(tableName, timeColumn, targetKey) {
        if (!await tableExists(pool, tableName)) return;
        const sql =
          "SELECT TO_CHAR((" + timeColumn + " AT TIME ZONE '" + TZ + "')::date,'YYYY-MM-DD') AS day," +
          " COUNT(*)::int AS n FROM " + tableName +
          " WHERE (" + timeColumn + " AT TIME ZONE '" + TZ + "')::date >= " + startExpr +
          " GROUP BY 1 ORDER BY 1";
        const r = await pool.query(sql, [days]);
        for (const row of r.rows) {
          const target = byDay.get(row.day);
          if (target) target[targetKey] = Number(row.n || 0);
        }
      }

      const activityParts = [];
      const weeklyParts = [];
      const activitySources = [
        ['owner_security_sessions', 'owner_id', 'last_seen_at'],
        ['owner_devices', 'owner_id', 'last_seen_at'],
        ['owner_login_events', 'owner_id', 'created_at'],
        ['driver_auth_sessions', 'driver_id', 'created_at'],
      ];
      for (const [tableName, userColumn, timeColumn] of activitySources) {
        if (!await tableExists(pool, tableName)) continue;
        activityParts.push(
          "SELECT " + userColumn + "::text AS user_id,(" + timeColumn + " AT TIME ZONE '" + TZ + "')::date AS day" +
          " FROM " + tableName +
          " WHERE (" + timeColumn + " AT TIME ZONE '" + TZ + "')::date >= " + startExpr
        );
        weeklyParts.push(
          "SELECT " + userColumn + "::text AS user_id,(" + timeColumn + " AT TIME ZONE '" + TZ + "')::date AS day" +
          " FROM " + tableName +
          " WHERE (" + timeColumn + " AT TIME ZONE '" + TZ + "')::date >= " +
          "(NOW() AT TIME ZONE '" + TZ + "')::date - 6"
        );
      }

      let weeklyActiveUsers = 0;
      if (activityParts.length) {
        const active = await pool.query(
          "SELECT TO_CHAR(day,'YYYY-MM-DD') AS day,COUNT(DISTINCT user_id)::int AS n" +
          " FROM (" + activityParts.join(' UNION ALL ') + ") a GROUP BY day ORDER BY day",
          [days]
        );
        for (const row of active.rows) {
          const target = byDay.get(row.day);
          if (target) target.activeUsers = Number(row.n || 0);
        }

        const wau = await pool.query(
          "SELECT COUNT(DISTINCT user_id)::int AS n FROM (" + weeklyParts.join(' UNION ALL ') + ") a"
        );
        weeklyActiveUsers = Number(wau.rows[0]?.n || 0);
      }

      await mergeCount('qr_scan_history', 'created_at', 'qrScans');
      await mergeCount('vehicle_notifications', 'created_at', 'notifications');
      await mergeCount('anonymous_calls', 'created_at', 'calls');
      await mergeCount('qr_conversation_messages', 'created_at', 'messages');
      await mergeCount('users', 'created_at', 'registrations');

      if (await tableExists(pool, 'offer_redemptions')) {
        const offers = await pool.query(
          "SELECT TO_CHAR((created_at AT TIME ZONE '" + TZ + "')::date,'YYYY-MM-DD') AS day," +
          " COUNT(*)::int AS requests," +
          " COUNT(*) FILTER (WHERE status='redeemed')::int AS redeemed" +
          " FROM offer_redemptions" +
          " WHERE (created_at AT TIME ZONE '" + TZ + "')::date >= " + startExpr +
          " GROUP BY 1 ORDER BY 1",
          [days]
        );
        for (const row of offers.rows) {
          const target = byDay.get(row.day);
          if (target) {
            target.offerRequests = Number(row.requests || 0);
            target.offerRedeemed = Number(row.redeemed || 0);
          }
        }
      }

      const last = daily[daily.length - 1] || {};
      const totals = daily.reduce((a, x) => {
        a.qrScans += x.qrScans;
        a.notifications += x.notifications;
        a.calls += x.calls;
        a.messages += x.messages;
        a.registrations += x.registrations;
        a.offerRequests += x.offerRequests;
        a.offerRedeemed += x.offerRedeemed;
        return a;
      }, {
        qrScans: 0,
        notifications: 0,
        calls: 0,
        messages: 0,
        registrations: 0,
        offerRequests: 0,
        offerRedeemed: 0,
      });

      const business = {
        businesses: 0,
        activeBusinesses: 0,
        campaigns: 0,
        liveCampaigns: 0,
        pendingRedemptions: 0,
        redeemedRedemptions: 0,
        cancelledRedemptions: 0,
        platformFees: 0,
        averageRating: null,
      };
      let topBusinesses = [];
      let topCampaigns = [];

      if (await tableExists(pool, 'businesses')) {
        const b = await pool.query(
          "SELECT COUNT(*)::int AS total,COUNT(*) FILTER (WHERE is_active=TRUE)::int AS active FROM businesses"
        );
        business.businesses = Number(b.rows[0]?.total || 0);
        business.activeBusinesses = Number(b.rows[0]?.active || 0);
      }

      if (await tableExists(pool, 'business_campaigns')) {
        const c = await pool.query(
          "SELECT COUNT(*)::int AS total," +
          " COUNT(*) FILTER (WHERE is_active=TRUE AND starts_at<=NOW() AND ends_at>=NOW())::int AS live" +
          " FROM business_campaigns"
        );
        business.campaigns = Number(c.rows[0]?.total || 0);
        business.liveCampaigns = Number(c.rows[0]?.live || 0);
      }

      if (await tableExists(pool, 'offer_redemptions')) {
        const hasFee = await columnExists(pool, 'offer_redemptions', 'platform_fee');
        const feeSelect = hasFee
          ? "COALESCE(SUM(platform_fee) FILTER (WHERE status='redeemed'),0)::numeric AS fees"
          : "0::numeric AS fees";
        const r = await pool.query(
          "SELECT COUNT(*) FILTER (WHERE status='pending')::int AS pending," +
          " COUNT(*) FILTER (WHERE status='redeemed')::int AS redeemed," +
          " COUNT(*) FILTER (WHERE status='cancelled')::int AS cancelled," +
          " " + feeSelect +
          " FROM offer_redemptions" +
          " WHERE (created_at AT TIME ZONE '" + TZ + "')::date >= " + startExpr,
          [days]
        );
        business.pendingRedemptions = Number(r.rows[0]?.pending || 0);
        business.redeemedRedemptions = Number(r.rows[0]?.redeemed || 0);
        business.cancelledRedemptions = Number(r.rows[0]?.cancelled || 0);
        business.platformFees = Number(r.rows[0]?.fees || 0);

        if (await tableExists(pool, 'business_campaigns') && await tableExists(pool, 'businesses')) {
          const feeExpr = hasFee
            ? "COALESCE(SUM(r.platform_fee) FILTER (WHERE r.status='redeemed'),0)::numeric"
            : "0::numeric";
          const topB = await pool.query(
            "SELECT b.id,b.name,COUNT(r.id)::int AS requests," +
            " COUNT(r.id) FILTER (WHERE r.status='redeemed')::int AS redeemed," +
            " " + feeExpr + " AS platform_fees" +
            " FROM businesses b" +
            " LEFT JOIN business_campaigns c ON c.business_id=b.id" +
            " LEFT JOIN offer_redemptions r ON r.campaign_id=c.id" +
            " AND (r.created_at AT TIME ZONE '" + TZ + "')::date >= " + startExpr +
            " GROUP BY b.id,b.name" +
            " ORDER BY redeemed DESC,requests DESC,b.name ASC LIMIT 8",
            [days]
          );
          topBusinesses = topB.rows;

          const topC = await pool.query(
            "SELECT c.id,c.title,b.name AS business_name,COUNT(r.id)::int AS requests," +
            " COUNT(r.id) FILTER (WHERE r.status='redeemed')::int AS redeemed" +
            " FROM business_campaigns c" +
            " JOIN businesses b ON b.id=c.business_id" +
            " LEFT JOIN offer_redemptions r ON r.campaign_id=c.id" +
            " AND (r.created_at AT TIME ZONE '" + TZ + "')::date >= " + startExpr +
            " GROUP BY c.id,c.title,b.name" +
            " ORDER BY redeemed DESC,requests DESC,c.title ASC LIMIT 8",
            [days]
          );
          topCampaigns = topC.rows;
        }
      }

      if (await tableExists(pool, 'offer_reviews')) {
        const rating = await pool.query(
          "SELECT ROUND(AVG(rating)::numeric,2) AS avg_rating FROM offer_reviews" +
          " WHERE (created_at AT TIME ZONE '" + TZ + "')::date >= " + startExpr,
          [days]
        );
        business.averageRating = rating.rows[0]?.avg_rating == null
          ? null
          : Number(rating.rows[0].avg_rating);
      }

      return res.json({
        ok: true,
        days,
        timezone: TZ,
        summary: {
          dailyActiveUsers: Number(last.activeUsers || 0),
          weeklyActiveUsers,
          ...totals,
        },
        daily,
        business,
        topBusinesses,
        topCampaigns,
      });
    } catch (e) {
      console.error('admin reports', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
};
