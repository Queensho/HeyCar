import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

const BASE_URL = (__ENV.BASE_URL || 'https://heycar-api-185-165-46-213.nip.io').replace(/\/$/, '');
const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || '';
const TEST_PHONE = __ENV.TEST_PHONE || '';
const TEST_PASSWORD = __ENV.TEST_PASSWORD || '';
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
  discardResponseBodies: false,
};

function record(r) {
  latency.add(r.timings.duration);
  if (r.status === 401) auth401.add(1);
  failures.add(!(r.status >= 200 && r.status < 400));
  return r;
}

export function setup() {
  if (ACCESS_TOKEN) return { token: ACCESS_TOKEN };
  if (!TEST_PHONE || !TEST_PASSWORD) return { token: '' };
  const login = http.post(`${BASE_URL}/api/owner/login-phone`, JSON.stringify({ phone: TEST_PHONE, password: TEST_PASSWORD }), { headers: {'Content-Type':'application/json'}, tags:{endpoint:'setup_login'} });
  check(login, { 'setup login ok': x => x.status === 200 });
  if (login.status !== 200) return { token: '' };
  try { return { token: JSON.parse(login.body).accessToken || '' }; } catch (_) { return { token: '' }; }
}

export default function (data) {
  let token = data?.token || ACCESS_TOKEN;
  const authHeaders = token ? { Authorization: `Bearer ${token}` } : {};
  if (token) {
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
  // Stagger each virtual user so 1k VUs do not synchronize unrealistically.
  sleep(1 + ((exec.vu.idInTest * 37) % 2000) / 1000);
}
