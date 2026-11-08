#!/usr/bin/env bash
# Run only against a new local PostgreSQL container. Never reads VPS settings.
set -euo pipefail
cd "$(dirname "$0")/../server"
container="heycar-audit-$(date +%s)-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
# The password is a disposable test fixture, not an application credential.
docker run --rm -d --name "$container" \
  -e POSTGRES_PASSWORD=isolated-test-only -e POSTGRES_DB=heycar_test_release \
  -p 127.0.0.1::5432 postgres:16-alpine >/dev/null
for attempt in {1..30}; do
  if docker exec "$container" pg_isready -U postgres -d heycar_test_release >/dev/null 2>&1; then break; fi
  if [[ "$attempt" == 30 ]]; then echo 'Temporary PostgreSQL did not start' >&2; exit 1; fi
  sleep 1
done
port=$(docker port "$container" 5432/tcp)
[[ "$port" =~ ^127\.0\.0\.1:([0-9]+)$ ]] || { echo 'Unsafe PostgreSQL bind' >&2; exit 1; }
export TEST_DATABASE_URL="postgresql://postgres:isolated-test-only@127.0.0.1:${BASH_REMATCH[1]}/heycar_test_release"
npm run check
npm run test:release
