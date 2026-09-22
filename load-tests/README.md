# Cepqar load test

k6 tabanlı ilk yük testi. Önce smoke, sonra 1k ve 10k. 50k–1M testleri tek VPS üzerinde doğrudan çalıştırmayın; dağıtık load generator ve izole staging ortamı kullanın.

Örnek:
```bash
BASE_URL=https://... ACCESS_TOKEN=... QR_TOKEN=... PROFILE=smoke k6 run load-tests/cepqar.js
PROFILE=1k k6 run load-tests/cepqar.js
PROFILE=10k k6 run load-tests/cepqar.js
```

Geçiş kriterleri: hata oranı < %1, p95 < 1 sn, p99 < 2 sn. 401 sayacı ayrıca izlenir.

1M hedefi için plan: 1k -> 10k -> 50k -> 100k -> 250k -> 500k -> 1M. 50k ve üzeri için birden fazla yük üretici kullanın; her aşamada API, PostgreSQL, Redis, ağ ve dosya tanımlayıcı limitlerini gözlemleyin.
