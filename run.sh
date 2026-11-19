#!/usr/bin/env bash
# TaskBoard (Docker three-tier app) - one entry point for every common task.
#
#   ./run.sh                 show help
#   ./run.sh start           create secrets, build, start, wait until healthy
#   ./run.sh e2e             end-to-end test through nginx -> api -> postgres
#   ./run.sh stop            stop (data is kept)
#
# Run "./run.sh help" for the full list.
set -euo pipefail
cd "$(dirname "$0")"

# Use tools installed by ../install.sh (shared ../.venv and ~/.local/bin); nothing to activate.
[[ -x ../.venv/bin/python ]] && PATH="$(cd .. && pwd)/.venv/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"; export PATH

c_ok=$'\e[32m'; c_err=$'\e[31m'; c_dim=$'\e[2m'; c_off=$'\e[0m'
[[ -t 1 && -z "${NO_COLOR:-}" ]] || { c_ok=""; c_err=""; c_dim=""; c_off=""; }
say()  { printf '%s>>%s %s\n' "$c_ok" "$c_off" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
need() { local m=(); for t in "$@"; do command -v "$t" >/dev/null || m+=("$t"); done
         ((${#m[@]} == 0)) || die "missing tool(s): ${m[*]}  (fix: ./run.sh install-deps)"; }
need_docker() {
  need docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 plugin not found ('docker compose')"
  docker info >/dev/null 2>&1 || die "Docker daemon is not running (start Docker Desktop / dockerd)"
}
web_port() { local p; p=$(grep -E '^WEB_PORT=' .env 2>/dev/null | cut -d= -f2); echo "${p:-8080}"; }

doctor() {
  local rc=0
  for t in docker curl python3 pytest ruff hadolint shellcheck; do
    if command -v "$t" >/dev/null; then printf '  %sok%s       %s\n' "$c_ok" "$c_off" "$t"
    else printf '  %smissing%s  %s\n' "$c_err" "$c_off" "$t"; rc=1; fi
  done
  if docker compose version >/dev/null 2>&1; then printf '  %sok%s       docker compose (%s)\n' "$c_ok" "$c_off" "$(docker compose version --short)"
  else printf '  %smissing%s  docker compose v2\n' "$c_err" "$c_off"; rc=1; fi
  docker info >/dev/null 2>&1 && printf '  %sok%s       docker daemon running\n' "$c_ok" "$c_off" \
    || { printf '  %sdown%s     docker daemon\n' "$c_err" "$c_off"; rc=1; }
  printf '\n%sOnly docker + compose + curl are needed to run the app; the rest are for lint/test.%s\n' "$c_dim" "$c_off"
  return $rc
}

usage() {
  cat <<EOF
TaskBoard (Docker three-tier app) - run.sh

Usage: ./run.sh <command> [args]

Run the stack
  install-deps      install every dependency (../install.sh 02)
  doctor            check required tools
  init              create .env and a random DB password secret
  start | up        init + build + start, wait until all services are healthy
  stop  | down      stop the stack (database data is kept)
  restart           restart all services
  status | ps       containers and health
  logs [service]    follow logs (web | api | db)
  open              print the app URL (and open it on macOS)

Operate
  scale [n]         run n API replicas behind nginx (default 3)
  backup            dump PostgreSQL to ./backups
  restore <file>    restore a dump, e.g. backups/taskboard_x.sql.gz
  tools             start the Adminer DB UI on :8081
  shell [service]   shell into a container (default api)
  psql              SQL prompt inside the database

Test
  test              API unit tests (pytest, SQLite in-memory)
  e2e               end-to-end test against the running stack
  lint              ruff + hadolint + shellcheck + compose validation

Clean up
  clean             stop and remove containers + locally built images
  nuke              stop and DELETE the database volume
EOF
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  help|-h|--help) usage ;;
  install-deps)
    [[ -x ../install.sh ]] || die "../install.sh not found: it is in the full portfolio repo (git clone https://github.com/Mian-Basam/devops-portfolio)"
    exec ../install.sh 02 "$@" ;;
  doctor)       doctor ;;
  init)         ./scripts/init.sh ;;
  start|up)
    need_docker; ./scripts/init.sh
    say "building and starting (waits for healthchecks)"
    docker compose up -d --build --wait
    say "TaskBoard is up: http://localhost:$(web_port)" ;;
  stop|down)    need_docker; docker compose down ;;
  restart)      need_docker; docker compose restart ;;
  status|ps)    need_docker; docker compose ps ;;
  logs)         need_docker; docker compose logs -f --tail=50 "$@" ;;
  open)
    url="http://localhost:$(web_port)"; echo "$url"
    command -v open >/dev/null && open "$url" || true ;;
  scale)        need_docker; docker compose up -d --scale api="${1:-3}" --wait ;;
  backup)       need_docker; ./scripts/backup_db.sh ;;
  restore)      need_docker; [[ -n "${1:-}" ]] || die "usage: ./run.sh restore backups/<file>.sql.gz"; ./scripts/restore_db.sh "$1" ;;
  tools)        need_docker; docker compose --profile tools up -d adminer; say "Adminer: http://localhost:8081" ;;
  shell)        need_docker; docker compose exec "${1:-api}" sh ;;
  psql)         need_docker; docker compose exec db psql -U "$(grep -E '^DB_USER=' .env | cut -d= -f2)" ;;
  test)         need pytest; (cd api && pytest -q) ;;
  e2e)          need curl; ./scripts/e2e_test.sh ;;
  lint)
    need ruff hadolint shellcheck docker
    (cd api && ruff check .)
    hadolint api/Dockerfile nginx/Dockerfile
    shellcheck scripts/*.sh run.sh
    docker compose config -q
    say "lint passed" ;;
  clean)        need_docker; docker compose down --rmi local ;;
  nuke)
    need_docker
    read -r -p "This DELETES the database volume. Type 'yes' to continue: " ans
    [[ "$ans" == "yes" ]] || die "aborted"
    docker compose --profile tools down -v ;;
  *)            usage; die "unknown command: $cmd" ;;
esac
