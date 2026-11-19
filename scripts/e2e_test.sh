#!/usr/bin/env bash
# End-to-end test through nginx -> api -> postgres.
#   ./scripts/e2e_test.sh [base_url]
set -Eeuo pipefail
BASE="${1:-http://localhost:8080}"
json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
check() {  # check "description" command...
  local desc="$1"; shift
  if "$@"; then echo "PASS  $desc"; else echo "FAIL  $desc" >&2; exit 1; fi
}

check "frontend served by nginx" \
  bash -c "curl -fsS '$BASE/' | grep -q '<title>TaskBoard</title>'"
check "api reports database healthy" \
  bash -c "[[ \$(curl -fsS '$BASE/api/health' | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"database\"])') == True ]]"

id=$(curl -fsS -X POST "$BASE/api/tasks" -H 'Content-Type: application/json' -d '{"title":"e2e task"}' | json "['id']")
echo "PASS  created task $id"

status=$(curl -fsS -X PATCH "$BASE/api/tasks/$id" -H 'Content-Type: application/json' -d '{"status":"done"}' | json "['status']")
check "updated task $id to done" test "$status" = "done"
check "task persisted in database" \
  bash -c "curl -fsS '$BASE/api/tasks?status=done' | grep -q 'e2e task'"
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/tasks/$id")
check "deleted task $id" test "$code" = 204
echo "all e2e checks passed"
