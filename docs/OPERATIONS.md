# Operations Guide

## First deployment on a server

```bash
sudo apt-get install -y docker.io docker-compose-v2 make
git clone https://github.com/Mian-Basam/docker-three-tier-app.git /opt/taskboard
cd /opt/taskboard
make up
make e2e
```

## Upgrading to a new version

```bash
git pull
APP_VERSION=1.2.0 docker compose up -d --build --wait   # rebuilds and recreates changed services only
make e2e
```

Compose recreates only services whose image or config changed. The
database container and volume are untouched.

**Rollback:** check out the previous tag and run the same command.

```bash
git checkout v1.1.0 && APP_VERSION=1.1.0 docker compose up -d --build --wait
```

## Scaling

```bash
docker compose up -d --scale api=3 --wait
docker compose ps api
for i in $(seq 6); do curl -s localhost:8080/api/health | jq -r .container; done   # different container IDs
```

Do **not** scale `db`: PostgreSQL replication needs dedicated setup.

## Backups

```bash
make backup                    # backups/taskboard_20261117_020000.sql.gz, keeps 7
./scripts/backup_db.sh /mnt/nfs/backups 30   # custom location and retention
```

Schedule nightly with cron:

```
30 2 * * * cd /opt/taskboard && ./scripts/backup_db.sh /var/backups/taskboard 14 >> /var/log/taskboard-backup.log 2>&1
```

## Restore

```bash
make restore FILE=backups/taskboard_20261117_020000.sql.gz
```

The script verifies the gzip, asks you to type the database name, stops
the API during the restore so nothing writes mid-way, then starts it again.

**Test restores regularly.** A backup you have never restored is not a
backup. CI performs a backup → restore → e2e round trip on every push.

## Logs

```bash
docker compose logs -f api            # follow
docker compose logs --since 30m web   # time window
docker compose logs api | grep ERROR
```

Each container's logs are rotated by the Docker daemon. Set rotation in
`/etc/docker/daemon.json`:

```json
{ "log-driver": "json-file", "log-opts": { "max-size": "20m", "max-file": "5" } }
```

## Rotating the DB password

1. `docker compose exec db psql -U taskboard -c "ALTER USER taskboard PASSWORD 'new-value';"`
2. Write `new-value` to `secrets/db_password.txt`.
3. `docker compose up -d --force-recreate api`.

## Clean up disk space

```bash
docker system df                 # what uses space
docker image prune -f            # dangling images
docker builder prune -f          # build cache
```
