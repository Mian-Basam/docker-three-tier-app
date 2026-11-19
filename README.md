# TaskBoard: Dockerized Three-Tier Application

[![CI](https://github.com/Mian-Basam/docker-three-tier-app/actions/workflows/ci.yml/badge.svg)](https://github.com/Mian-Basam/docker-three-tier-app/actions)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.27-009639?logo=nginx&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Level](https://img.shields.io/badge/level-basic%20→%20intermediate-blue)

> A task board web application packaged as a **production-style
> multi-container system**: **Nginx** web tier, **Flask/Gunicorn** API
> tier and **PostgreSQL** data tier, orchestrated with **Docker Compose**.
>
> **Portfolio level 2 of 5**: containerization fundamentals.

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Purpose of the project](#2-purpose-of-the-project)
3. [Architecture](#3-architecture)
4. [Features](#4-features)
5. [Tools and technologies](#5-tools-and-technologies)
6. [File structure](#6-file-structure)
7. [How to run: `run.sh`](#7-how-to-run-runsh)
8. [Quick start](#8-quick-start)
9. [Day-to-day operations](#9-day-to-day-operations)
10. [API reference](#10-api-reference)
11. [Testing and CI](#11-testing-and-ci)
12. [Security choices](#12-security-choices)
13. [Skills demonstrated](#13-skills-demonstrated)
14. [Roadmap](#14-roadmap)
15. [Further documentation](#15-further-documentation)

---

## 1. Introduction

**TaskBoard** is a simple to-do board: you add tasks and move them between
**todo**, **doing** and **done**. The application itself is deliberately
small; the real subject of the project is **how it is packaged and run**
with containers.

It is split into three tiers, each in its own container:

| Tier | Container | Technology | Job |
|---|---|---|---|
| Presentation | `web` | Nginx 1.27 | Serves the HTML/CSS/JS UI and proxies `/api/*` to the API |
| Application | `api` | Python 3.12, Flask, SQLAlchemy, Gunicorn | REST API for tasks, health and stats |
| Data | `db` | PostgreSQL 16 | Stores tasks on a persistent volume |

One command (`./run.sh start`) builds the images, creates a random
database password, starts the three containers in the right order and
waits until all of them are healthy.

## 2. Purpose of the project

**Problem it solves.** Running an app on a server by hand ("install
Python, install Postgres, copy files, hope it works") is slow, fragile and
different on every machine. Containers make the environment repeatable,
but only if the images, networks, secrets and data are designed properly.
This project shows how to do that correctly.

**Goals**

| Goal | How the project meets it |
|---|---|
| Package an app into small, secure images | Multi-stage builds, slim base, non-root user, `.dockerignore`, pinned versions |
| Connect services safely | Two networks; the database network is `internal` and the DB port is never published |
| Keep secrets out of images and env vars | DB password is a Docker secret file generated at first start |
| Start reliably | Healthchecks + `depends_on: condition: service_healthy` (db → api → web) |
| Keep data safe | Named volume, `pg_dump` backups with retention, guarded restore |
| Scale | `--scale api=3` behind Nginx with no config change |
| Prove it works | Unit tests, end-to-end test through every tier, linting, CI |

**Who it is for:** anyone learning Docker and Docker Compose beyond
"hello world", and engineers who want a reference layout for a small
production-style containerized service.

**Where it fits:** project 1 taught Linux and scripting; this project
moves the workload into containers. Project 5 reuses the same image
design and deploys it to servers and Kubernetes.

## 3. Architecture

```
                    ┌──────────────────────── frontend network ─────────────────────────┐
  Browser ──:8080──▶│  web (nginx)                       api (gunicorn ×N)              │
                    │  • serves static UI       /api/*   • Flask REST API               │
                    │  • reverse proxy        ────────▶  • /api/health checks DB        │
                    │  • security headers, gzip          • reads DB password from secret│
                    └─────────────────────────────────────────────┬─────────────────────┘
                                                                  │
                    ┌──────────────── backend network (internal: no internet) ──────────┐
                    │                                   db (postgres:16-alpine)         │
                    │                                   • named volume: pgdata          │
                    │                                   • pg_isready healthcheck        │
                    └───────────────────────────────────────────────────────────────────┘
```

* The **database is not reachable from the host or the internet**. It sits
  only on the `internal` backend network.
* Startup order is enforced by **healthchecks**: `db` healthy → `api`
  healthy → `web` starts.
* Nginx resolves `api` through Docker DNS, so `--scale api=3` load-balances
  across replicas with no config change.

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 4. Features

| Area | What is implemented |
|---|---|
| Images | Multi-stage Python build, non-root user (UID 10001), slim base, `.dockerignore`, `HEALTHCHECK` in each image |
| Networking | Two user-defined networks; backend marked `internal`; reverse proxy with timeouts |
| Data | Named volume for PostgreSQL; `pg_dump` backup with retention; guarded restore |
| Secrets | DB password via **Docker secrets** (`/run/secrets/db_password`), never in env vars or images |
| Resilience | `restart: unless-stopped`, DB retry loop on API start, `pool_pre_ping` to recover after DB restarts, CPU/memory limits |
| Scaling | `./run.sh scale 3` runs 3 API replicas behind Nginx |
| Tooling | Optional Adminer UI via Compose **profile**; `run.sh` and `Makefile` for every task |
| Quality | 5 pytest unit tests, end-to-end test script, ruff, hadolint, shellcheck, GitHub Actions |

## 5. Tools and technologies

### Required to run

| Tool | Version | Used for | Install |
|---|---|---|---|
| Docker Engine / Docker Desktop | 24+ | building and running the containers | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose plugin | v2 (`docker compose`) | starting the whole stack | included with Docker Desktop |
| curl | any | end-to-end test | preinstalled |
| Bash | 3.2+ | `run.sh` and scripts | preinstalled |

About **1 GB** free RAM. Ports **8080** (app) and **8081** (Adminer, optional) must be free.

### Required to develop and test

| Tool | Used for | Install |
|---|---|---|
| Python 3.12 + pytest | API unit tests (`./run.sh test`) | `pip install -r api/requirements-dev.txt` |
| ruff | Python lint | included in `requirements-dev.txt` |
| hadolint | Dockerfile lint | `brew install hadolint` |
| ShellCheck | script lint | `brew install shellcheck` / `apt install shellcheck` |

### Technology stack

| Category | Technologies |
|---|---|
| Containers | Docker (multi-stage builds, healthchecks, secrets, networks, volumes), Docker Compose (profiles, scaling, `--wait`) |
| Web tier | Nginx 1.27 (static files, reverse proxy, gzip, security headers) |
| API tier | Python 3.12, Flask 3, Flask-SQLAlchemy, psycopg2, Gunicorn |
| Data tier | PostgreSQL 16 (alpine), `pg_dump` / `psql`, Adminer |
| Front end | HTML, CSS, vanilla JavaScript |
| Scripting | Bash |
| Quality / CI | pytest, ruff, hadolint, ShellCheck, GitHub Actions |

## 6. File structure

```
02-docker-three-tier-app/
├── run.sh                        # ★ single entry point: ./run.sh help
├── docker-compose.yml            # web, api, db (+ adminer profile): networks, volume, secret, healthchecks, limits
├── .env.example                  # template for .env (ports, DB name/user, log level)
├── Makefile                      # make up | down | e2e | scale | backup | ...
├── README.md                     # this document
├── .gitignore                    # ignores .env, secrets, backups
│
├── api/                          # application tier (Python)
│   ├── Dockerfile                # multi-stage build, non-root user, HEALTHCHECK
│   ├── .dockerignore             # keeps tests/caches out of the image
│   ├── wsgi.py                   # Gunicorn entry point
│   ├── app/
│   │   ├── __init__.py           # app factory, DB URL from secret file, DB retry on startup
│   │   ├── db.py                 # SQLAlchemy instance
│   │   ├── models.py             # Task model (title, status, timestamps)
│   │   └── routes.py             # /api/health, /api/tasks, /api/stats
│   ├── tests/
│   │   ├── conftest.py           # test app with in-memory SQLite
│   │   └── test_api.py           # 5 unit tests
│   ├── requirements.txt          # runtime dependencies
│   ├── requirements-dev.txt      # + pytest, ruff
│   └── ruff.toml                 # lint rules
│
├── frontend/public/              # presentation tier content
│   ├── index.html                # board UI
│   ├── style.css
│   └── app.js                    # calls the API, shows health and serving container
│
├── nginx/
│   ├── Dockerfile                # nginx image with the UI baked in
│   └── default.conf              # reverse proxy to api, gzip, security headers, timeouts
│
├── scripts/
│   ├── init.sh                   # creates .env and a random secrets/db_password.txt
│   ├── e2e_test.sh               # tests the full path nginx -> api -> postgres
│   ├── backup_db.sh              # pg_dump + gzip + retention into ./backups
│   └── restore_db.sh             # guarded restore of a dump
│
├── secrets/
│   └── db_password.txt.example   # placeholder; the real file is generated and git-ignored
│
├── docs/
│   ├── ARCHITECTURE.md           # components, request flow, networks, startup sequence
│   ├── DOCKER_CONCEPTS.md        # images, layers, networks, volumes, secrets explained
│   ├── OPERATIONS.md             # deploy, upgrade, scale, backup and restore procedures
│   └── TROUBLESHOOTING.md        # symptom -> cause -> fix
│
└── .github/workflows/ci.yml      # lint, unit tests, stack up, e2e, scale and backup/restore checks
```

## 7. How to run: `run.sh`

`run.sh` is the single entry point for this project. It creates the
`.env` file and DB secret on first start, checks that Docker is running,
and does not need `make`.

| Command | What it does |
|---|---|
| `./run.sh help` | List all commands |
| `./run.sh doctor` | Check Docker, Compose and the test tools |
| `./run.sh init` | Create `.env` and a random DB password secret |
| `./run.sh start` | Init + build + start; waits until every service is healthy |
| `./run.sh status` | Containers and health |
| `./run.sh logs [web\|api\|db]` | Follow logs |
| `./run.sh open` | Print (and on macOS open) the app URL |
| `./run.sh e2e` | End-to-end test through all three tiers |
| `./run.sh test` | API unit tests |
| `./run.sh lint` | ruff + hadolint + ShellCheck + Compose validation |
| `./run.sh scale [n]` | Run *n* API replicas (default 3) |
| `./run.sh backup` | Dump PostgreSQL to `./backups` |
| `./run.sh restore <file>` | Restore a dump |
| `./run.sh tools` | Start the Adminer DB UI on :8081 |
| `./run.sh shell [service]` | Shell inside a container (default `api`) |
| `./run.sh psql` | SQL prompt in the database |
| `./run.sh stop` | Stop the stack (data is kept) |
| `./run.sh clean` | Remove containers and locally built images |
| `./run.sh nuke` | Stop and **delete** the database volume (asks to confirm) |

From the portfolio root you can also run `./run.sh 02 <command>`.

## 8. Quick start

```bash
git clone https://github.com/Mian-Basam/docker-three-tier-app.git
cd docker-three-tier-app

./run.sh doctor     # 1. check Docker is installed and running
./run.sh start      # 2. build and start, waits until healthy
./run.sh status     # 3. all three services should show (healthy)
./run.sh e2e        # 4. end-to-end test
```

Open **http://localhost:8080**. The badge in the header shows API and
database health, and the footer shows which API container served the
request (it changes after `./run.sh scale 3`).

```
$ ./run.sh e2e
PASS  frontend served by nginx
PASS  api reports database healthy
PASS  created task 1
PASS  updated task 1 to done
PASS  task persisted in database
PASS  deleted task 1
all e2e checks passed
```

## 9. Day-to-day operations

| Task | Command |
|---|---|
| Follow logs | `./run.sh logs` or `./run.sh logs api` |
| Shell into a container | `./run.sh shell api` |
| SQL prompt | `./run.sh psql` |
| Scale the API | `./run.sh scale 3` |
| Back up the DB | `./run.sh backup` → `backups/taskboard_YYYYMMDD_HHMMSS.sql.gz` |
| Restore | `./run.sh restore backups/<file>.sql.gz` |
| DB admin UI | `./run.sh tools` → http://localhost:8081 |
| Stop (keep data) | `./run.sh stop` |
| Stop and delete data | `./run.sh nuke` |

Procedures and troubleshooting: [docs/OPERATIONS.md](docs/OPERATIONS.md),
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 10. API reference

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/health` | – | `200` `{status, database, version, container}`; `503` if DB is down |
| GET | `/api/tasks?status=todo` | – | list of tasks (filter optional) |
| POST | `/api/tasks` | `{"title": "..."}` | `201` created task |
| PATCH | `/api/tasks/{id}` | `{"status": "doing"}` and/or `{"title": "..."}` | updated task |
| DELETE | `/api/tasks/{id}` | – | `204` |
| GET | `/api/stats` | – | `{"todo": n, "doing": n, "done": n}` |

Statuses are `todo`, `doing` and `done`. Invalid input returns `400`;
unknown IDs return `404`.

## 11. Testing and CI

| Layer | Tool | What it proves |
|---|---|---|
| Unit | pytest (5 tests, SQLite) | API logic and validation |
| Static | ruff, hadolint, shellcheck, `docker compose config` | Code, Dockerfiles, scripts and Compose file are valid |
| End-to-end | `scripts/e2e_test.sh` | Real request path nginx → api → postgres |
| Resilience | CI job | Scaling to 3 replicas and a backup/restore round trip keep working |

The end-to-end path was also verified outside Docker against PostgreSQL 16
and Nginx: stopping the database makes `/api/health` return **503**, and
the API recovers automatically when the database comes back.

## 12. Security choices

* Containers run as **non-root**.
* The DB password is a **Docker secret file** generated randomly by
  `scripts/init.sh`. It is git-ignored and never appears in
  `docker inspect` output.
* The database network is `internal`, and the DB port is **not published**.
* Nginx adds `X-Frame-Options`, `X-Content-Type-Options` and
  `Referrer-Policy` headers and sets strict proxy timeouts for `/api`.
* Images are pinned to specific versions, not `latest`.

## 13. Skills demonstrated

Docker image design · Compose orchestration · container networking and DNS ·
volumes and data persistence · secrets management · healthchecks and
startup ordering · reverse proxy and load balancing · backup/restore ·
CI with automated end-to-end tests · operational documentation.

## 14. Roadmap

- [ ] TLS termination with a self-signed cert / Let's Encrypt
- [ ] Prometheus metrics endpoint (see Project 4)
- [ ] Database migrations with Alembic
- [ ] Deploy the same images to Kubernetes (see Project 5)

## 15. Further documentation

| Document | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Components, request flow, networks, startup sequence |
| [docs/DOCKER_CONCEPTS.md](docs/DOCKER_CONCEPTS.md) | Images, layers, multi-stage builds, networks, volumes, secrets explained with this repo |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Deploying, upgrading, scaling, backup and restore procedures |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom → cause → fix table |

---

**Author:** Basil Ahtisham · [LinkedIn](https://linkedin.com/in/mianbasil) · [GitHub](https://github.com/Mian-Basam)
