# Architecture

## Components

| Service | Image | Role | Networks | Published port |
|---|---|---|---|---|
| `web` | `taskboard-web` (nginx:1.27-alpine + UI) | Static UI, reverse proxy to API | frontend | 8080 → 80 |
| `api` | `taskboard-api` (python:3.12-slim) | REST API on Gunicorn, 2 workers per container | frontend, backend | none |
| `db` | `postgres:16-alpine` | Persistent storage | backend (internal) | none |
| `adminer` | `adminer:4.8.1` | DB admin UI (profile `tools`, off by default) | frontend, backend | 8081 |

## Request flow

```
1. Browser  GET /                → web serves index.html, app.js, style.css
2. Browser  POST /api/tasks      → web proxies to http://api:8000/api/tasks
3. web      DNS lookup "api"     → Docker embedded DNS (127.0.0.11) returns replica IPs
4. api      INSERT INTO tasks    → db:5432 over the backend network
5. api      201 JSON             → web → browser
```

## Networks

```
frontend (bridge)          backend (bridge, internal: true)
  ├── web                    ├── api
  ├── api                    └── db
  └── adminer*               └── adminer*
```

* `api` is the only service on both networks, so it is the only path to the
  database.
* `internal: true` means the backend network has no gateway. `db` cannot
  reach the internet, and nothing outside Docker can reach `db`.

## Startup sequence

```
db ──(pg_isready OK)──▶ api ──(/api/health 200)──▶ web
```

`depends_on: condition: service_healthy` enforces this order. As a second
safety net, the API retries the database connection 10 times before giving
up. That covers restarts where Compose ordering does not apply, such as when
the DB container restarts on its own.

## Configuration

| Source | Used for |
|---|---|
| `.env` | non-secret settings: ports, names, version, log level |
| `secrets/db_password.txt` | mounted read-only at `/run/secrets/db_password` in `api` and `db` |
| Image `ARG APP_VERSION` | baked into the image and shown in `/api/health` |

## Data

* PostgreSQL data lives in the named volume `taskboard_pgdata`. It survives
  `docker compose down` and container rebuilds.
* `make nuke` (`down -v`) deletes it.
* Backups are logical `pg_dump` files, so they can be restored into a newer
  PostgreSQL major version.
