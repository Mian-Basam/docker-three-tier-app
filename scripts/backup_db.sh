#!/usr/bin/env bash
# Dump the PostgreSQL database from the running stack.
#   ./scripts/backup_db.sh [backup_dir] [keep]
set -Eeuo pipefail
cd "$(dirname "$0")/.."
DIR="${1:-backups}"; KEEP="${2:-7}"
DB_USER="${DB_USER:-taskboard}"; DB_NAME="${DB_NAME:-taskboard}"
mkdir -p "$DIR"
file="$DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"

docker compose exec -T db pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists \
  | gzip > "$file.partial"
mv "$file.partial" "$file"
gzip -t "$file"
echo "backup written: $file ($(du -h "$file" | cut -f1))"

find "$DIR" -name "${DB_NAME}_*.sql.gz" -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2- \
  | tail -n +$((KEEP + 1)) | xargs -r rm -v
