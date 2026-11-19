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
echo "restore complete"
