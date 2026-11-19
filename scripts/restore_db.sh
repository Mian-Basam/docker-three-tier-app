#!/usr/bin/env bash
# Restore a dump created by backup_db.sh into the running stack.
#   ./scripts/restore_db.sh backups/taskboard_20261117_020000.sql.gz
set -Eeuo pipefail
cd "$(dirname "$0")/.."
FILE="${1:?usage: restore_db.sh <dump.sql.gz>}"
DB_USER="${DB_USER:-taskboard}"; DB_NAME="${DB_NAME:-taskboard}"
[[ -f "$FILE" ]] || { echo "no such file: $FILE" >&2; exit 1; }
gzip -t "$FILE"

read -r -p "This will OVERWRITE database '$DB_NAME'. Type the database name to continue: " ans
[[ "$ans" == "$DB_NAME" ]] || { echo "aborted"; exit 1; }

echo "stopping api to avoid writes during restore"
docker compose stop api
gunzip -c "$FILE" | docker compose exec -T db psql -v ON_ERROR_STOP=1 -q -U "$DB_USER" -d "$DB_NAME"
docker compose start api
# "start" returns before the API is ready; wait until every api replica is healthy
# (not "up --wait", which would reset a scaled-out service back to 1 replica)
for _ in $(seq 60); do
  health=$(docker compose ps api --format '{{.Health}}')
  [[ -n "$health" ]] && ! grep -qv '^healthy$' <<<"$health" && break
  sleep 1
done
grep -qv '^healthy$' <<<"$health" && { echo "api did not become healthy after restore" >&2; exit 1; }
echo "restore complete"
