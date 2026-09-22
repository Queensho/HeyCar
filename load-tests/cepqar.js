import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const BASE_URL = (__ENV.BASE_URL || 'https://heycar-api-185-165-46-213.nip.io').replace(/\/$/, '');
const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || '';
const QR_TOKEN = __ENV.QR_TOKEN || '';
const PROFILE = __ENV.PROFILE || 'smoke';

const failures = new Rate('cepqar_failures');
const auth401 = new Counter('cepqar_401');
const latency = new Trend('cepqar_api_latency', true);

const profiles = {
  smoke: { executor:'constant-vus', vus:10, duration:'30s' },
  '1k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'2m',target:1000},{duration:'3m',target:1000},{duration:'1m',target:0}], gracefulRampDown:'30s' },
  '10k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'5m',target:10000},{duration:'5m',target:10000},{duration:'2m',target:0}], gracefulRampDown:'30s' },
};

export const options = {
  scenarios: { cepqar: profiles[PROFILE] || profiles.smoke },
  thresholds: {
    cepqar_failures: ['rate<0.01'],
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
  },
  discardResponseBodies: true,
};

function record(r) {
  latency.add(r.timings.duration);
  if (r.status === 401) auth401.add(1);
  failures.add(!(r.status >= 200 && r.status < 400));
  return r;
}

export default function () {
  const authHeaders = ACCESS_TOKEN ? { Authorization: `Bearer ${ACCESS_TOKEN}` } : {};
  if (ACCESS_TOKEN) {
    let r = record(http.get(`${BASE_URL}/api/owner/vehicles`, { headers: authHeaders, tags:{endpoint:'vehicles'} }));
    check(r, { 'vehicles ok': x => x.status === 200 });
    r = record(http.get(`${BASE_URL}/api/owner/notifications`, { headers: authHeaders, tags:{endpoint:'notifications'} }));
    check(r, { 'notifications ok': x => x.status === 200 });
    r = record(http.get(`${BASE_URL}/api/owner/calls/incoming`, { headers: authHeaders, tags:{endpoint:'incoming_call'} }));
    check(r, { 'incoming call reachable': x => x.status >= 200 && x.status < 400 });
  }
  if (QR_TOKEN) {
    const r = record(http.post(`${BASE_URL}/api/qr/${encodeURIComponent(QR_TOKEN)}/session`, null, { headers:{'Content-Type':'application/json'}, tags:{endpoint:'qr_session'} }));
    check(r, { 'qr session ok': x => x.status >= 200 && x.status < 300 });
  }
  sleep(Math.random() * 2 + 1);
}
