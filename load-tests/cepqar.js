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
const WORKLOAD = (__ENV.WORKLOAD || 'stress').toLowerCase();
const TOKEN_POOL = (__ENV.ACCESS_TOKENS || '').split(',').map(x => x.trim()).filter(Boolean);

const failures = new Rate('cepqar_failures');
const auth401 = new Counter('cepqar_401');
const latency = new Trend('cepqar_api_latency', true);

const profiles = {
  smoke: { executor:'constant-vus', vus:10, duration:'30s' },
  '1k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'2m',target:1000},{duration:'3m',target:1000},{duration:'1m',target:0}], gracefulRampDown:'30s' },
  '2k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'2m',target:2000},{duration:'3m',target:2000},{duration:'1m',target:0}], gracefulRampDown:'30s' },
  '5k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'3m',target:5000},{duration:'4m',target:5000},{duration:'1m',target:0}], gracefulRampDown:'30s' },
  '10k': { executor:'ramping-vus', startVUs:0, stages:[{duration:'5m',target:10000},{duration:'5m',target:10000},{duration:'2m',target:0}], gracefulRampDown:'30s' },
};

export const options = {
  scenarios: { cepqar: profiles[PROFILE] || profiles.smoke },
  thresholds: {
    cepqar_failures: ['rate<0.01'],
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    'http_req_duration{endpoint:vehicles}': ['p(95)<1000'],
    'http_req_duration{endpoint:notifications}': ['p(95)<1000'],
    'http_req_duration{endpoint:incoming_call}': ['p(95)<1000'],
  },
  discardResponseBodies: true,
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
  const login = http.post(`${BASE_URL}/api/owner/login-phone`, JSON.stringify({ phone: TEST_PHONE, password: TEST_PASSWORD }), { headers: {'Content-Type':'application/json'}, tags:{endpoint:'setup_login'}, responseType:'text' });
  check(login, { 'setup login ok': x => x.status === 200 });
  if (login.status !== 200) return { token: '' };
  try { return { token: JSON.parse(login.body).accessToken || '' }; } catch (_) { return { token: '' }; }
}

export default function (data) {
  const pooled = TOKEN_POOL.length ? TOKEN_POOL[(exec.vu.idInTest - 1) % TOKEN_POOL.length] : '';
  const token = pooled || data?.token || ACCESS_TOKEN;
  const authHeaders = token ? { Authorization: `Bearer ${token}` } : {};
  const realistic = WORKLOAD === 'realistic';
  const iter = exec.vu.iterationInScenario;

  if (token) {
    // Stress mode intentionally hammers all endpoints every loop.
    // Realistic mode mirrors the app after the push-first call change:
    // vehicles ~30s, notifications ~15s, incoming-call HTTP only as a rare recovery check.
    if (!realistic || iter % 15 === 0) {
      const r = record(http.get(`${BASE_URL}/api/owner/vehicles`, { headers: authHeaders, tags:{endpoint:'vehicles'} }));
      check(r, { 'vehicles ok': x => x.status === 200 });
    }
    if (!realistic || iter % 8 === 0) {
      const r = record(http.get(`${BASE_URL}/api/owner/notifications`, { headers: authHeaders, tags:{endpoint:'notifications'} }));
      check(r, { 'notifications ok': x => x.status === 200 });
    }
    if (!realistic || iter === 0 || iter % 60 === 0) {
      const r = record(http.get(`${BASE_URL}/api/owner/calls/incoming`, { headers: authHeaders, tags:{endpoint:'incoming_call'} }));
      check(r, { 'incoming call reachable': x => x.status >= 200 && x.status < 400 });
    }
  }
  if (QR_TOKEN && (!realistic || iter % 30 === 0)) {
    const r = record(http.post(`${BASE_URL}/api/qr/${encodeURIComponent(QR_TOKEN)}/session`, null, { headers:{'Content-Type':'application/json'}, tags:{endpoint:'qr_session'} }));
    check(r, { 'qr session ok': x => x.status >= 200 && x.status < 300 });
  }
  // Stagger each virtual user so large VU counts do not synchronize unrealistically.
  sleep(1 + ((exec.vu.idInTest * 37) % 2000) / 1000);
}
