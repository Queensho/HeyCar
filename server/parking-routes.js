const express = require('express');
module.exports = function registerParkingRoutes(app, pool) {
  const geoCache = new Map();
  app.get('/api/parking/nearby', async (req, res) => {
    const lat = Number(req.query.lat), lon = Number(req.query.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 85 || Math.abs(lon) > 180)
      return res.status(400).json({ error: 'INVALID_LOCATION' });
    const apiKey = String(process.env.GEOAPIFY_API_KEY || '').trim();
    if (!apiKey) return res.status(503).json({ error: 'GEOAPIFY_NOT_CONFIGURED' });
    const key = `${lat.toFixed(2)},${lon.toFixed(2)}`, cached = geoCache.get(key);
    if (cached && Date.now() - cached.at < 15 * 60 * 1000) return res.json({ ok:true, source:'geoapify', cached:true, places:cached.places });
    try {
      const url = new URL('https://api.geoapify.com/v2/places');
      url.searchParams.set('categories', 'parking');
      url.searchParams.set('filter', `circle:${lon},${lat},4000`);
      url.searchParams.set('bias', `proximity:${lon},${lat}`);
      url.searchParams.set('limit', '100');
      url.searchParams.set('apiKey', apiKey);
      const mallUrl = new URL('https://api.geoapify.com/v2/places');
      mallUrl.searchParams.set('categories', 'commercial.shopping_mall');
      mallUrl.searchParams.set('filter', `circle:${lon},${lat},4000`);
      mallUrl.searchParams.set('bias', `proximity:${lon},${lat}`);
      mallUrl.searchParams.set('limit', '40');
      mallUrl.searchParams.set('apiKey', apiKey);
      const opts = { headers:{ Accept:'application/json', 'User-Agent':'Cepqar/1.0' }, signal:AbortSignal.timeout(9000) };
      const [response, mallResponse] = await Promise.all([fetch(url, opts), fetch(mallUrl, { ...opts, signal:AbortSignal.timeout(9000) })]);
      if (!response.ok) return res.status(502).json({ error:'GEOAPIFY_ERROR' });
      const data = await response.json(), features = Array.isArray(data.features) ? data.features : [];
      const mallData = mallResponse.ok ? await mallResponse.json() : { features:[] };
      const malls = (Array.isArray(mallData.features) ? mallData.features : []).map(f => {
        const x=f.properties||{}, q=f.geometry?.coordinates||[];
        return Number.isFinite(q[0]) && Number.isFinite(q[1])
          ? { lon:q[0], lat:q[1], name:String(x.name||x.address_line1||'AVM') } : null;
      }).filter(Boolean);
      const meters = (a,b,c,d) => {
        const r=6371000, p=Math.PI/180, d1=(c-a)*p, d2=(d-b)*p;
        const h=Math.sin(d1/2)**2 + Math.cos(a*p)*Math.cos(c*p)*Math.sin(d2/2)**2;
        return 2*r*Math.asin(Math.sqrt(h));
      };
      const places = features.map(f => {
        const x=f.properties||{}, coords=f.geometry?.coordinates||[];
        if (!Number.isFinite(coords[0]) || !Number.isFinite(coords[1])) return null;
        const cats=Array.isArray(x.categories)?x.categories:[];
        let nearestMall=null, nearestMallDistance=800;
        for (const mall of malls) {
          const d=meters(coords[1],coords[0],mall.lat,mall.lon);
          if (d <= nearestMallDistance) { nearestMall=mall; nearestMallDistance=d; }
        }
        const rawName=String(x.name || x.address_line1 || 'İsimsiz otopark');
        const tags = {
          name: nearestMall && (!x.name || /^\\d+[. ]|sokak|cadde/i.test(rawName)) ? `${nearestMall.name} Otoparkı` : rawName,
          'addr:full': String(x.formatted || x.address_line2 || ''),
          ...(x.opening_hours ? { opening_hours:String(x.opening_hours) } : {}),
          ...(x.fee === true ? { fee:'yes' } : x.fee === false ? { fee:'no' } : {}),
          ...(cats.some(v=>String(v).includes('multi_storey')) ? { parking:'multi-storey' } :
              cats.some(v=>String(v).includes('underground')) ? { parking:'underground' } : { parking:'surface' }),
          ...(nearestMall || cats.some(v=>String(v).includes('shopping_mall')) ? { 'cepqar:mall':'yes', ...(nearestMall ? {'cepqar:mall_name':nearestMall.name} : {}) } : {}),
          ...(cats.some(v=>String(v).includes('wheelchair')) ? { wheelchair:'yes' } : {}),
          ...(cats.some(v=>String(v).includes('charging')) ? { charging_station:'yes' } : {}),
          'cepqar:source':'geoapify'
        };
        return { id:`geoapify/${String(x.place_id||'').replace(/[^A-Za-z0-9_-]/g,'')}`, latitude:coords[1], longitude:coords[0], tags };
      }).filter(Boolean);
      geoCache.set(key,{at:Date.now(),places});
      if (geoCache.size>30) geoCache.delete(geoCache.keys().next().value);
      res.json({ok:true,source:'geoapify',cached:false,places});
    } catch(e) {
      console.error('Geoapify parking:', e.message);
      res.status(502).json({error:'GEOAPIFY_UNAVAILABLE'});
    }
  });
  const owner = req => String(req.headers['x-owner-id'] || '').trim();
  const fields = 'area,floor,spot,note,parking_name,latitude,longitude,osm_id,started_at,updated_at';
  async function owns(req, res) {
    const o = owner(req), v = String(req.params.vehicleId || '');
    if (!o) { res.status(401).json({ error: 'OWNER_REQUIRED' }); return null; }
    const r = await pool.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1', [v, o]);
    if (!r.rows.length) { res.status(403).json({ error: 'FORBIDDEN' }); return null; }
    return String(r.rows[0].id);
  }
  app.get('/api/vehicles/:vehicleId/parking', async (req, res) => {
    try {
      const v = await owns(req, res); if (!v) return;
      const r = await pool.query(`SELECT ${fields} FROM vehicle_parking_locations WHERE vehicle_id=$1 AND owner_id=$2 LIMIT 1`, [v, owner(req)]);
      res.json({ ok: true, parking: r.rows[0] || null });
    } catch (e) { console.error(e); res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
  app.put('/api/vehicles/:vehicleId/parking', express.json(), async (req, res) => {
    try {
      const v = await owns(req, res); if (!v) return;
      const body = req.body || {};
      const area = String(body.area || '').trim().slice(0, 40), floor = String(body.floor || '').trim().slice(0, 20);
      const spot = String(body.spot || '').trim().slice(0, 30), note = String(body.note || '').trim().slice(0, 180);
      const hasLocation = ['parking_name', 'latitude', 'longitude', 'osm_id'].some(k => Object.hasOwn(body, k));
      const name = String(body.parking_name || '').trim().slice(0, 200), osmId = String(body.osm_id || '').trim();
      const lat = body.latitude, lon = body.longitude;
      if (hasLocation && (!name || typeof lat !== 'number' || typeof lon !== 'number' ||
          !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180 ||
          !/^(?:(?:node|way|relation)\/\d+|geoapify\/[A-Za-z0-9_-]+)$/.test(osmId) || osmId.length > 80)) {
        return res.status(400).json({ error: 'INVALID_PARKING_LOCATION' });
      }
      if (!hasLocation && !area && !floor && !spot) {
        const existing = await pool.query('SELECT 1 FROM vehicle_parking_locations WHERE vehicle_id=$1 AND owner_id=$2 AND latitude IS NOT NULL', [v, owner(req)]);
        if (!existing.rows.length) return res.status(400).json({ error: 'PARKING_FIELDS_REQUIRED' });
      }
      const r = await pool.query(`INSERT INTO vehicle_parking_locations
        (vehicle_id,owner_id,area,floor,spot,note,parking_name,latitude,longitude,osm_id,started_at,updated_at)
        VALUES($1,$2,$3,$4,$5,$6,$8,$9,$10,$11,CASE WHEN $7 THEN NOW() ELSE NULL END,NOW())
        ON CONFLICT(vehicle_id) DO UPDATE SET owner_id=EXCLUDED.owner_id,
          area=EXCLUDED.area,floor=EXCLUDED.floor,spot=EXCLUDED.spot,note=EXCLUDED.note,
          parking_name=CASE WHEN $7 THEN EXCLUDED.parking_name ELSE vehicle_parking_locations.parking_name END,
          latitude=CASE WHEN $7 THEN EXCLUDED.latitude ELSE vehicle_parking_locations.latitude END,
          longitude=CASE WHEN $7 THEN EXCLUDED.longitude ELSE vehicle_parking_locations.longitude END,
          osm_id=CASE WHEN $7 THEN EXCLUDED.osm_id ELSE vehicle_parking_locations.osm_id END,
          started_at=CASE WHEN $7 THEN NOW() ELSE vehicle_parking_locations.started_at END,
          updated_at=NOW() RETURNING ${fields}`,
        [v, owner(req), area, floor, spot, note, hasLocation, hasLocation ? name : null,
          hasLocation ? lat : null, hasLocation ? lon : null, hasLocation ? osmId : null]);
      res.json({ ok: true, parking: r.rows[0] });
    } catch (e) { console.error(e); res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
  app.delete('/api/vehicles/:vehicleId/parking', async (req, res) => {
    try {
      const v = await owns(req, res); if (!v) return;
      await pool.query('DELETE FROM vehicle_parking_locations WHERE vehicle_id=$1 AND owner_id=$2', [v, owner(req)]);
      res.json({ ok: true });
    } catch (e) { console.error(e); res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
};
