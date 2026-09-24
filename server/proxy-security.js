function configureTrustedProxy(app) {
  if (!app || typeof app.set !== 'function') return;

  const configured = String(process.env.TRUST_PROXY || '').trim();
  if (configured) {
    const lower = configured.toLowerCase();
    if (lower === 'true') {
      app.set('trust proxy', true);
      return;
    }
    if (lower === 'false') {
      app.set('trust proxy', false);
      return;
    }
    const hops = Number(configured);
    if (Number.isInteger(hops) && hops >= 0) {
      app.set('trust proxy', hops);
      return;
    }
    app.set('trust proxy', configured);
    return;
  }

  // Production API is bound to 127.0.0.1 and reached through the local
  // reverse proxy. Trust only loopback by default, never arbitrary proxies.
  app.set('trust proxy', 'loopback');
}

function requestIp(req) {
  return String(req?.ip || req?.socket?.remoteAddress || '')
    .trim()
    .slice(0, 120) || null;
}

module.exports = { configureTrustedProxy, requestIp };
