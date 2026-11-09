#!/usr/bin/env bash
# Local Docker only; no VPS, .env, existing database, baseline or deployment.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name="heycar-marketplace-test-$$-$RANDOM"
container_started=false
local_docker() {
 env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH \
  docker --host=unix:///var/run/docker.sock "$@"
}
cleanup() { if [ "$container_started" = true ]; then local_docker rm -f "$container_name" >/dev/null; fi; }
trap cleanup EXIT
local_docker info >/dev/null
local_docker run --detach --name "$container_name" --publish 127.0.0.1::5432 \
 --env POSTGRES_PASSWORD=isolated-marketplace-test --env POSTGRES_DB=heycar_marketplace_test \
 postgres:16-alpine >/dev/null
container_started=true
for attempt in $(seq 1 60); do
 if local_docker exec "$container_name" pg_isready -U postgres -d heycar_marketplace_test >/dev/null 2>&1; then break; fi
 if [ "$attempt" -eq 60 ]; then echo 'Local PostgreSQL readiness failed' >&2; exit 1; fi
 sleep 1
done
export DB_HOST=127.0.0.1 DB_NAME=heycar_marketplace_test DB_USER=postgres DB_PASSWORD=isolated-marketplace-test
DB_PORT="$(local_docker port "$container_name" 5432/tcp | sed -n 's/^127\.0\.0\.1://p')"
export DB_PORT
export DATABASE_URL="postgresql://postgres:isolated-marketplace-test@127.0.0.1:$DB_PORT/$DB_NAME"
export NODE_ENV=test APP_ENV=test STAGING_DISABLE_EXTERNAL_SERVICES=true SMART_ROUTE_SCAN_ENABLED=false
local_docker exec "$container_name" psql -U postgres -d "$DB_NAME" -v ON_ERROR_STOP=1 \
 -c 'CREATE ROLE heycar_user; CREATE ROLE cepqontag_staging;' >/dev/null
cd "$repo_root/server"
npm run check
npm run migrate
npm run migrate # Tracked rerun verifies all SHA256 checksums; no SQL replay.
npm run test:release
