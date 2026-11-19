# Troubleshooting

Start with `docker compose ps`: it shows each container's state and health.

| Symptom | Likely cause | How to confirm | Fix |
|---|---|---|---|
| `make up` hangs at "Waiting" | A healthcheck never passes | `docker compose ps`; `docker inspect --format '{{json .State.Health}}' <container>` | Read the healthcheck output; usually a config or credentials problem |
| `api` restarting in a loop | Cannot connect to DB / wrong password | `docker compose logs api` shows `database not ready` or `password authentication failed` | Check `secrets/db_password.txt`. If you changed it after the volume was created, the DB still has the old password (see OPERATIONS → rotating) |
| Browser shows **502 Bad Gateway** | nginx cannot reach `api` | `docker compose logs web` shows `connect() failed` | Is `api` healthy? Are both on the `frontend` network? |
| Header badge says **DB unreachable** | `/api/health` returns 503 | `curl -i localhost:8080/api/health` | `docker compose logs db`; disk full? volume permissions? |
| `port is already allocated` | Something else uses 8080 | `ss -ltnp \| grep 8080` | Set `WEB_PORT=8090` in `.env` |
| Data gone after restart | Used `down -v` or the volume name changed | `docker volume ls` | Restore from backup; use `make down`, not `make nuke` |
| Changes to code not visible | Old image still running | `docker compose images` | `docker compose up -d --build` |
| `api` container OOM-killed | Exceeds 256M limit | `docker inspect <c> --format '{{.State.OOMKilled}}'` | Raise the limit or reduce Gunicorn workers |
| Slow first request after scale | New replica still warming | `docker compose ps` health column | Wait for `healthy`; use `--wait` |

## Useful commands

```bash
docker compose exec api python -c "import socket; print(socket.gethostbyname('db'))"   # DNS from inside
docker compose exec web wget -qO- http://api:8000/api/health                            # bypass the browser
docker compose exec db pg_isready -U taskboard
docker stats --no-stream
docker network inspect taskboard_backend | jq '.[0].Containers'
```
