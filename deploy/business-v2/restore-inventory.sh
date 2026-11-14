#!/usr/bin/env bash
# Read-only inventory of an isolated restore and the repository's migration files.
# This does NOT prove schema equivalence and never records a baseline.
set -euo pipefail
DB="${1:-heycar_restore_check_v2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ ! "$DB" =~ ^heycar_restore_check_[a-zA-Z0-9_]*$ ]]; then
  echo "REFUSED: only heycar_restore_check_* databases are accepted" >&2
  exit 2
fi
if [[ ! -d "$ROOT/server/migrations" ]]; then
  echo "Missing server/migrations" >&2
  exit 2
fi
echo "=== Local migration file inventory (no database writes) ==="
python3 - "$ROOT/server/migrations" <<'PY'
import collections, pathlib, re, sys
files=sorted(p.name for p in pathlib.Path(sys.argv[1]).glob('*.sql') if re.match(r'^\d{3}_.+\.sql$',p.name))
by_number=collections.defaultdict(list)
for name in files:
    by_number[int(name[:3])].append(name)
print('total_files:',len(files))
print('through_127:',sum(int(x[:3])<=127 for x in files))
print('missing_numbers_001_127:',[i for i in range(1,128) if i not in by_number])
print('duplicate_numbers:',{k:v for k,v in sorted(by_number.items()) if len(v)>1})
print('latest_files:',files[-10:])
PY
echo "=== Restore database inventory (read-only) ==="
sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -d "$DB" <<'SQL'
BEGIN READ ONLY;
SELECT current_database() AS database;
SELECT count(*) AS public_tables FROM pg_tables WHERE schemaname='public';
SELECT count(*) AS public_sequences FROM pg_sequences WHERE schemaname='public';
SELECT to_regclass('public.schema_migrations') AS tracking_table;
SELECT count(*) AS public_functions FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
SELECT count(*) AS public_triggers FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal;
ROLLBACK;
SQL
echo "NOT VERIFIED: migration 001-127 effects and checksums against a clean reference."
echo "DO NOT run --baseline-through or npm run migrate based on this inventory alone."
