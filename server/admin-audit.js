function firstNonEmpty(...values) {
  for (const value of values) {
    if (value == null) continue;
    const s = String(value).trim();
    if (s) return s;
  }
  return null;
}

function decodeJwtPayload(req) {
  try {
    const raw = String(req.headers?.authorization || '').trim();
    if (!raw.toLowerCase().startsWith('bearer ')) return {};
    const token = raw.slice(7).trim();
    const parts = token.split('.');
    if (parts.length < 2) return {};
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payload + '='.repeat((4 - payload.length % 4) % 4);
    const parsed = JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

async function auditTableReady(pool) {
  const r = await pool.query("SELECT to_regclass('public.admin_audit_log') AS name");
  return Boolean(r.rows[0]?.name);
}

async function resolveAdmin(pool, req) {
  const source = req.admin || req.user || req.auth || req.adminUser || {};
  const jwt = decodeJwtPayload(req);
  let id = firstNonEmpty(
    source.id, source.userId, source.user_id, source.sub,
    jwt.id, jwt.userId, jwt.user_id, jwt.sub,
    req.headers?.['x-admin-id']
  );
  let email = firstNonEmpty(source.email, jwt.email, req.headers?.['x-admin-email']);
  let name = firstNonEmpty(
    source.display_name, source.displayName, source.name,
    jwt.display_name, jwt.displayName, jwt.name,
    req.headers?.['x-admin-name']
  );

  if (id) {
    try {
      const r = await pool.query(
        "SELECT id::text AS id,email,display_name FROM users WHERE id::text=$1 AND role='admin' LIMIT 1",
        [id]
      );
      if (r.rows.length) {
        id = String(r.rows[0].id || id);
        email = firstNonEmpty(r.rows[0].email, email);
        name = firstNonEmpty(r.rows[0].display_name, name);
      }
    } catch (_) {}
  } else if (email) {
    try {
      const r = await pool.query(
        "SELECT id::text AS id,email,display_name FROM users WHERE LOWER(email)=LOWER($1) AND role='admin' LIMIT 1",
        [email]
      );
      if (r.rows.length) {
        id = String(r.rows[0].id || '');
        email = firstNonEmpty(r.rows[0].email, email);
        name = firstNonEmpty(r.rows[0].display_name, name);
      }
    } catch (_) {}
  }

  return { id: id || null, email: email || null, name: name || null };
}

function safeJson(value) {
  if (value == null) return null;
  try {
    return JSON.parse(JSON.stringify(value));
  } catch (_) {
    return { value: String(value) };
  }
}

async function writeAdminAudit(pool, req, entry) {
  try {
    if (!await auditTableReady(pool)) return false;
    const actor = await resolveAdmin(pool, req);
    const action = String(entry?.action || '').trim().slice(0, 120);
    const targetType = String(entry?.targetType || '').trim().slice(0, 80);
    if (!action || !targetType) return false;

    await pool.query(
      "INSERT INTO admin_audit_log " +
      "(admin_id,admin_email,admin_name,action,target_type,target_id,target_label,before_state,after_state,metadata) " +
      "VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9::jsonb,$10::jsonb)",
      [
        actor.id,
        actor.email,
        actor.name,
        action,
        targetType,
        entry?.targetId == null ? null : String(entry.targetId).slice(0, 250),
        entry?.targetLabel == null ? null : String(entry.targetLabel).slice(0, 500),
        entry?.before == null ? null : JSON.stringify(safeJson(entry.before)),
        entry?.after == null ? null : JSON.stringify(safeJson(entry.after)),
        JSON.stringify(safeJson(entry?.metadata || {})),
      ]
    );
    return true;
  } catch (e) {
    console.error('admin audit write', e);
    return false;
  }
}

function registerAdminAuditRoutes(app, pool, adminGuard) {
  const guard = typeof adminGuard === 'function'
    ? adminGuard
    : (_req, res) => res.status(500).json({ error: 'ADMIN_GUARD_NOT_CONFIGURED' });

  app.get('/api/admin/manage/audit', guard, async (req, res) => {
    try {
      if (!await auditTableReady(pool)) {
        return res.status(503).json({ error: 'ADMIN_AUDIT_MIGRATION_REQUIRED' });
      }

      const limit = Math.max(1, Math.min(200, Number(req.query?.limit || 100)));
      const offset = Math.max(0, Number(req.query?.offset || 0));
      const action = String(req.query?.action || '').trim();
      const targetType = String(req.query?.targetType || '').trim();
      const admin = String(req.query?.admin || '').trim();

      const where = [];
      const params = [];
      const add = (value, clause) => {
        params.push(value);
        where.push(clause.replace('?', '$' + params.length));
      };

      if (action && action !== 'all') add(action, 'action=?');
      if (targetType && targetType !== 'all') add(targetType, 'target_type=?');
      if (admin) {
        params.push('%' + admin + '%');
        const p = '$' + params.length;
        where.push("(COALESCE(admin_name,'') ILIKE " + p + " OR COALESCE(admin_email,'') ILIKE " + p + ")");
      }

      const whereSql = where.length ? 'WHERE ' + where.join(' AND ') : '';
      const count = await pool.query(
        'SELECT COUNT(*)::int AS n FROM admin_audit_log ' + whereSql,
        params
      );

      const listParams = params.slice();
      listParams.push(limit);
      const limitParam = '$' + listParams.length;
      listParams.push(offset);
      const offsetParam = '$' + listParams.length;

      const rows = await pool.query(
        "SELECT id,admin_id,admin_email,admin_name,action,target_type,target_id,target_label," +
        "before_state,after_state,metadata,created_at " +
        "FROM admin_audit_log " + whereSql +
        " ORDER BY created_at DESC LIMIT " + limitParam + " OFFSET " + offsetParam,
        listParams
      );

      const facets = await pool.query(
        "SELECT " +
        "ARRAY(SELECT DISTINCT action FROM admin_audit_log ORDER BY action) AS actions," +
        "ARRAY(SELECT DISTINCT target_type FROM admin_audit_log ORDER BY target_type) AS target_types"
      );

      return res.json({
        ok: true,
        total: Number(count.rows[0]?.n || 0),
        items: rows.rows,
        actions: facets.rows[0]?.actions || [],
        targetTypes: facets.rows[0]?.target_types || [],
      });
    } catch (e) {
      console.error('admin audit list', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
}

module.exports = { writeAdminAudit, registerAdminAuditRoutes, auditTableReady };
