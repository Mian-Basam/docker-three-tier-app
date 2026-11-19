# Docker Concepts, Explained with This Repo

## Image vs container

An **image** is a read-only template (layers of files plus metadata). A
**container** is a running instance of an image with its own writable
layer. `taskboard-api:local` is one image; `make scale` runs three
containers from it.

## Layers and caching

Each `Dockerfile` instruction creates a layer. Docker reuses cached
layers until something changes. That is why `api/Dockerfile` copies
`requirements.txt` and installs dependencies **before** copying the code:

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt   # cached unless requirements change
COPY app/ app/                        # code changes only rebuild from here
```

## Multi-stage builds

The first stage builds a virtualenv. The final stage copies only `/venv`
and the app code, so build tools and pip caches never reach the
production image. The result is a smaller image with fewer packages to
patch.

## Non-root users

```dockerfile
RUN useradd --system --uid 10001 --no-create-home app
USER app
```

If an attacker gets code execution in the container, they are not root.

## Healthchecks

`HEALTHCHECK` lets Docker report `healthy` / `unhealthy` for a container.
Compose uses this for `depends_on: condition: service_healthy`, and
`docker compose up --wait` blocks until every service is healthy. Check it
with:

```bash
docker inspect --format '{{json .State.Health}}' taskboard-api-1 | jq
```

## Networks and DNS

On a user-defined network, containers reach each other **by service name**
(`db`, `api`). Docker's embedded DNS server at `127.0.0.11` answers these
lookups. When a service has several replicas, the name resolves to all of
their IPs.

```bash
docker compose exec web nslookup api
```

## Volumes

| Type | Example | Use |
|---|---|---|
| Named volume | `pgdata:/var/lib/postgresql/data` | Persistent data managed by Docker |
| Bind mount | `./nginx/default.conf:/etc/nginx/...` | Inject files from the host (dev) |
| tmpfs | `tmpfs: /tmp` | In-memory scratch space |

```bash
docker volume ls
docker volume inspect taskboard_pgdata
```

## Secrets

Environment variables appear in `docker inspect` and process listings.
Compose **secrets** are mounted as files under `/run/secrets/`. PostgreSQL
supports `POSTGRES_PASSWORD_FILE`, and the API reads `DB_PASSWORD_FILE`.

## Compose profiles

Services with `profiles: [tools]` only start when asked:
`docker compose --profile tools up -d`. This keeps optional tooling such
as Adminer out of normal runs.

## Restart policies

| Policy | Behaviour |
|---|---|
| `no` | never restart |
| `on-failure` | restart only on non-zero exit |
| `always` | always, including after daemon restart |
| `unless-stopped` | like `always`, but respects a manual `docker stop` |

## Resource limits

```yaml
deploy:
  resources:
    limits: { cpus: "0.50", memory: 256M }
```

The kernel kills the container if it exceeds the memory limit (OOM), and
throttles it if it exceeds the CPU limit. Watch usage with `docker stats`.
