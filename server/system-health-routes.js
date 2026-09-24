const os = require('os');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

const runtime = globalThis.__cepqarSystemHealthRuntime || {
  startedAt: new Date().toISOString(),
  errors: [],
  captureInstalled: false,
};
globalThis.__cepqarSystemHealthRuntime = runtime;

function safeText(value) {
  if (value instanceof Error) return value.message || value.name || 'Error';
  if (typeof value === 'string') return value;
  try { return JSON.stringify(value); } catch (_) { return String(value); }
}

function installErrorCapture() {
  if (runtime.captureInstalled) return;
  runtime.captureInstalled = true;
  const original = console.error.bind(console);
  console.error = (...args) => {
    try {
      const message = args.map(safeText).join(' ').replace(/\s+/g, ' ').slice(0, 1200);
      runtime.errors.unshift({ at: new Date().toISOString(), message });
      if (runtime.errors.length > 50) runtime.errors.length = 50;
    } catch (_) {}
    original(...args);
  };
}

installErrorCapture();

async function diskUsage() {
  try {
    const { stdout } = await execFileAsync('df', ['-Pk', '/'], { timeout: 2500 });
    const lines = String(stdout || '').trim().split(/\r?\n/);
    const cols = (lines[lines.length - 1] || '').trim().split(/\s+/);
    if (cols.length < 6) throw new Error('DF_PARSE_FAILED');
    const totalKb = Number(cols[1] || 0);
    const usedKb = Number(cols[2] || 0);
    const freeKb = Number(cols[3] || 0);
    const percent = Number(String(cols[4] || '').replace('%', ''));
    return {
      ok: true,
      totalBytes: totalKb * 1024,
      usedBytes: usedKb * 1024,
      freeBytes: freeKb * 1024,
      usedPercent: Number.isFinite(percent) ? percent : null,
      mount: cols[5] || '/',
    };
  } catch (e) {
    return { ok: false, error: safeText(e) };
  }
}

async function findLatestBackup() {
  const configured = [
    process.env.HEYQAR_BACKUP_DIR,
    process.env.BACKUP_DIR,
    '/opt/heycar/backups',
    '/var/backups/heycar',
  ].filter(Boolean);

  const extensions = ['.sql', '.dump', '.backup', '.gz', '.tgz', '.tar', '.zip'];
  let chosenDir = null;
  let latest = null;

  for (const dir of configured) {
    try {
      const st = await fs.promises.stat(dir);
      if (!st.isDirectory()) continue;
      if (!chosenDir) chosenDir = dir;
      const names = await fs.promises.readdir(dir);
      for (const name of names) {
        const full = path.join(dir, name);
        let fileStat;
        try { fileStat = await fs.promises.stat(full); } catch (_) { continue; }
        if (!fileStat.isFile()) continue;
        const lower = name.toLowerCase();
        if (!extensions.some((ext) => lower.endsWith(ext))) continue;
        if (!latest || fileStat.mtimeMs > latest.mtimeMs) {
          latest = {
            name,
            path: full,
            sizeBytes: fileStat.size,
            mtimeMs: fileStat.mtimeMs,
            modifiedAt: fileStat.mtime.toISOString(),
          };
        }
      }
    } catch (_) {}
  }

  if (!chosenDir) {
    return {
      status: 'not_configured',
      configured: false,
      directory: null,
      latest: null,
      ageHours: null,
      expectedHours: Number(process.env.BACKUP_EXPECTED_HOURS || 24),
    };
  }

  if (!latest) {
    return {
      status: 'missing',
      configured: true,
      directory: chosenDir,
      latest: null,
      ageHours: null,
      expectedHours: Number(process.env.BACKUP_EXPECTED_HOURS || 24),
    };
  }

  const ageHours = Math.max(0, (Date.now() - latest.mtimeMs) / 3600000);
  const expectedHours = Math.max(1, Number(process.env.BACKUP_EXPECTED_HOURS || 24));
  return {
    status: ageHours <= expectedHours * 1.5 ? 'healthy' : ageHours <= expectedHours * 3 ? 'warning' : 'stale',
    configured: true,
    directory: chosenDir,
    latest,
    ageHours: Number(ageHours.toFixed(1)),
    expectedHours,
  };
}

async function postgresHealth(pool) {
  const started = Date.now();
  try {
    const r = await pool.query(
      `SELECT NOW() AS server_time,
              current_database() AS database_name,
              pg_database_size(current_database())::bigint AS database_size`
    );
    const latencyMs = Date.now() - started;
    return {
      ok: true,
      status: latencyMs < 250 ? 'healthy' : latencyMs < 1000 ? 'warning' : 'slow',
      latencyMs,
      database: r.rows[0]?.database_name || null,
      databaseSizeBytes: Number(r.rows[0]?.database_size || 0),
      serverTime: r.rows[0]?.server_time || null,
    };
  } catch (e) {
    return { ok: false, status: 'down', latencyMs: Date.now() - started, error: safeText(e) };
  }
}

function systemdShowValue(raw) {
  return String(raw || '').trim();
}

function systemdTimestampToIso(raw) {
  const value = systemdShowValue(raw);
  if (!value || value === 'n/a' || value === '0') return null;
  const normalized = value.replace(/^[A-Za-z]{3}\s+/, '');
  const ms = Date.parse(normalized);
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

async function reminderSchedulerHealth(pool) {
  let timer = {
    installed: false,
    active: false,
    enabled: false,
    lastTriggerAt: null,
    nextRunAt: null,
    error: null,
  };

  try {
    const { stdout } = await execFileAsync(
      'systemctl',
      ['show','cepqar-reminders.timer','--property=LoadState','--property=ActiveState','--property=UnitFileState','--property=LastTriggerUSec','--property=NextElapseUSecRealtime','--no-pager'],
      { timeout: 2500 }
    );
    const props = {};
    for (const line of String(stdout || '').split(/\r?\n/)) {
      const idx = line.indexOf('=');
      if (idx <= 0) continue;
      props[line.slice(0, idx)] = line.slice(idx + 1);
    }
    timer = {
      installed: props.LoadState === 'loaded',
      active: props.ActiveState === 'active',
      enabled: props.UnitFileState === 'enabled',
      lastTriggerAt: systemdTimestampToIso(props.LastTriggerUSec),
      nextRunAt: systemdTimestampToIso(props.NextElapseUSecRealtime),
      error: null,
    };
  } catch (e) {
    timer.error = safeText(e);
  }

  let latest = null;
  let history = [];
  try {
    const exists = await pool.query("SELECT to_regclass('public.vehicle_reminder_job_runs') AS name");
    if (!exists.rows[0]?.name) {
      return {
        status: 'not_configured',
        timer,
        lastRun: null,
        recentRuns: [],
        nextRunAt: timer.nextRunAt,
      };
    }
    const r = await pool.query(
      `SELECT id,source,status,started_at,finished_at,eligible_count,created_notifications,
              duplicate_skips,push_attempted,push_delivered,error
         FROM vehicle_reminder_job_runs
        ORDER BY started_at DESC LIMIT 8`
    );
    history = r.rows;
    latest = history[0] || null;
  } catch (e) {
    return {
      status: 'warning',
      timer,
      lastRun: null,
      recentRuns: [],
      nextRunAt: timer.nextRunAt,
      error: safeText(e),
    };
  }

  let status = 'ready';
  if (!timer.installed || !timer.active || !timer.enabled) {
    status = 'warning';
  } else if (latest?.status === 'failed') {
    status = 'warning';
  } else if (latest?.status === 'success') {
    const finished = latest.finished_at ? new Date(latest.finished_at).getTime() : 0;
    status = finished && Date.now() - finished <= 36 * 3600000 ? 'healthy' : 'warning';
  }

  return {
    status,
    timer,
    lastRun: latest,
    recentRuns: history,
    nextRunAt: timer.nextRunAt,
  };
}

async function pushHealth(app, pool) {
  const push = app.locals.heycarPush;
  let tokenCounts = { owner: 0, driver: 0 };
  try {
    const check = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM owner_push_tokens WHERE active=TRUE) AS owner,
         (SELECT COUNT(*)::int FROM driver_push_tokens WHERE active=TRUE) AS driver`
    );
    tokenCounts = {
      owner: Number(check.rows[0]?.owner || 0),
      driver: Number(check.rows[0]?.driver || 0),
    };
  } catch (_) {}

  let snapshot = {};
  try {
    if (push && typeof push.getHealth === 'function') snapshot = push.getHealth() || {};
    else if (push && push.health && typeof push.health === 'object') snapshot = { ...push.health };
  } catch (_) {}

  const registered = Boolean(push && (typeof push.sendOwner === 'function' || typeof push.send === 'function'));
  const configured = Boolean(
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    process.env.FIREBASE_SERVICE_ACCOUNT_FILE
  );
  const lastAttempted = Number(snapshot.lastAttempted || 0);
  const lastDelivered = Number(snapshot.lastDelivered || 0);

  let status = 'not_configured';
  if (configured && registered) {
    if (snapshot.lastFailureAt && (!snapshot.lastSuccessAt || new Date(snapshot.lastFailureAt) > new Date(snapshot.lastSuccessAt))) {
      status = 'warning';
    } else if (snapshot.lastSuccessAt) {
      status = 'healthy';
    } else {
      status = 'ready';
    }
  }

  return {
    status,
    configured,
    registered,
    activeOwnerTokens: tokenCounts.owner,
    activeDriverTokens: tokenCounts.driver,
    lastAttemptAt: snapshot.lastAttemptAt || null,
    lastSuccessAt: snapshot.lastSuccessAt || null,
    lastFailureAt: snapshot.lastFailureAt || null,
    lastAttempted,
    lastDelivered,
    lastError: snapshot.lastError || null,
  };
}

function systemMetrics() {
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = Math.max(0, totalMem - freeMem);
  const cores = Math.max(1, os.cpus()?.length || 1);
  const load = os.loadavg();
  const mem = process.memoryUsage();
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    release: os.release(),
    cpuCores: cores,
    load1: Number(load[0].toFixed(2)),
    load5: Number(load[1].toFixed(2)),
    load15: Number(load[2].toFixed(2)),
    cpuLoadPercent: Number(Math.min(999, (load[0] / cores) * 100).toFixed(1)),
    totalMemoryBytes: totalMem,
    usedMemoryBytes: usedMem,
    freeMemoryBytes: freeMem,
    memoryUsedPercent: Number(((usedMem / Math.max(1, totalMem)) * 100).toFixed(1)),
    processRssBytes: mem.rss,
    processHeapUsedBytes: mem.heapUsed,
  };
}

module.exports = function registerSystemHealthRoutes(app, pool, adminGuard) {
  const guard = typeof adminGuard === 'function'
    ? adminGuard
    : (_req, res) => res.status(500).json({ error: 'ADMIN_GUARD_NOT_CONFIGURED' });

  app.get('/api/admin/manage/system-health', guard, async (_req, res) => {
    const requestedAt = new Date().toISOString();
    const [postgres, disk, backup, firebase, reminders] = await Promise.all([
      postgresHealth(pool),
      diskUsage(),
      findLatestBackup(),
      pushHealth(app, pool),
      reminderSchedulerHealth(pool),
    ]);

    const metrics = systemMetrics();
    const uptimeSeconds = Math.floor(process.uptime());
    const api = {
      status: 'up',
      pid: process.pid,
      node: process.version,
      uptimeSeconds,
      startedAt: new Date(Date.now() - uptimeSeconds * 1000).toISOString(),
    };

    const lastError = runtime.errors[0] || null;
    const recentErrors = runtime.errors.slice(0, 10);

    const critical = !postgres.ok || !disk.ok || (disk.usedPercent != null && disk.usedPercent >= 95);
    const warning = !critical && (
      metrics.memoryUsedPercent >= 90 ||
      metrics.cpuLoadPercent >= 90 ||
      (disk.usedPercent != null && disk.usedPercent >= 85) ||
      firebase.status === 'warning' ||
      firebase.status === 'not_configured' ||
      postgres.status === 'slow' ||
      backup.status === 'stale' ||
      backup.status === 'missing' ||
      backup.status === 'not_configured' ||
      reminders.status === 'warning' ||
      reminders.status === 'not_configured'
    );

    return res.json({
      ok: true,
      requestedAt,
      overall: critical ? 'critical' : warning ? 'warning' : 'healthy',
      api,
      postgres,
      firebase,
      system: metrics,
      disk,
      backup,
      reminders,
      lastError,
      recentErrors,
    });
  });
};
