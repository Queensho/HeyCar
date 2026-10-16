// Traffic-aware route preview. Provider credentials stay on the backend.
const https = require('https');
function getJson(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: 8000 }, res => {
      let body = '';
      res.on('data', chunk => {
        body += chunk;
        if (body.length > 250000) req.destroy(new Error('RESPONSE_TOO_LARGE'));
      });
      res.on('end', () => {
        if (res.statusCode !== 200) return reject(new Error('PROVIDER_HTTP_' + res.statusCode));
        try { resolve(JSON.parse(body)); } catch (_) { reject(new Error('INVALID_RESPONSE')); }
      });
    });
    req.on('timeout', () => req.destroy(new Error('PROVIDER_TIMEOUT')));
    req.on('error', reject);
  });
}
function valid(p) {
  return p && Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lon))
    && Math.abs(Number(p.lat)) <= 90 && Math.abs(Number(p.lon)) <= 180;
}
async function preview(route, db) {
  const key = String(process.env.TOMTOM_API_KEY || '').trim();
  if (!key) return { available: false, reason: 'NOT_CONFIGURED' };
  const points = [route.origin, ...(Array.isArray(route.waypoints) ? route.waypoints : []), route.destination];
  if (points.length > 10 || points.some(p => !valid(p))) return { available: false, reason: 'INVALID_COORDINATES' };
  const locations = points.map(p => Number(p.lat).toFixed(6) + ',' + Number(p.lon).toFixed(6)).join(':');
  const url = new URL('https://api.tomtom.com/routing/1/calculateRoute/' + locations + '/json');
  url.searchParams.set('key', key);
  url.searchParams.set('traffic', 'true');
  url.searchParams.set('routeType', 'fastest');
  url.searchParams.set('travelMode', 'car');
  const cap = Math.max(0, Math.min(1000, Number(process.env.TOMTOM_MONTHLY_ROUTING_BUDGET || 100) || 0));
  if (!db || !cap) return { available: false, reason: 'BUDGET_UNAVAILABLE' };
  try {
    const budget = await db.query(`INSERT INTO smart_route_provider_usage(provider,service,month_utc,requests)
      VALUES('tomtom','routing',$1,1)
      ON CONFLICT(provider,service,month_utc) DO UPDATE SET requests=smart_route_provider_usage.requests+1,updated_at=NOW()
      WHERE smart_route_provider_usage.requests < $2 RETURNING requests`, [new Date().toISOString().slice(0,7), cap]);
    if (!budget.rowCount) return { available: false, reason: 'LOCAL_BUDGET_EXHAUSTED' };
  } catch (_) { return { available: false, reason: 'BUDGET_UNAVAILABLE' }; }
  try {
    const data = await getJson(url);
    const routeData = data.routes && data.routes[0];
    if (!routeData || !routeData.summary) return { available: false, reason: 'NO_ROUTE' };
    const summary = routeData.summary;
    const geometry = (routeData.legs || []).flatMap(leg => leg.points || [])
      .map(p => ({ lat: p.latitude, lon: p.longitude }));
    if (!Number.isFinite(Number(summary.lengthInMeters)) || !Number.isFinite(Number(summary.travelTimeInSeconds)) ||
        geometry.length < 2 || geometry.some(p => !valid(p))) return { available: false, reason: 'INVALID_PROVIDER_RESPONSE' };
    if (geometry.length > 12000) return { available: false, reason: 'ROUTE_TOO_LARGE' };
    return { available: true, provider: 'tomtom', distanceMeters: summary.lengthInMeters,
      travelTimeSeconds: summary.travelTimeInSeconds,
      trafficDelaySeconds: summary.trafficDelayInSeconds == null ? null : summary.trafficDelayInSeconds,
      geometry, checkedAt: new Date().toISOString(), trafficAware: true,
      travelModeUsed: 'car' };
  } catch (e) {
    console.error('TomTom routing failed:', e.message);
    return { available: false, reason: e.message === 'PROVIDER_HTTP_429' ? 'PROVIDER_RATE_LIMIT' : 'PROVIDER_UNAVAILABLE' };
  }
}
module.exports = { preview };
