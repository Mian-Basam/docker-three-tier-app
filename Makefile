.PHONY: help init up down restart ps logs test lint e2e scale backup restore tools clean nuke

help:      ## list targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'
init:      ## create .env and DB password secret
	./scripts/init.sh
up: init   ## build and start the stack, wait until healthy
	docker compose up -d --build --wait
	@echo "TaskBoard: http://localhost:$${WEB_PORT:-8080}"
down:      ## stop the stack (data is kept)
	docker compose down
restart:   ## restart all services
	docker compose restart
ps:        ## show containers and health
	docker compose ps
logs:      ## follow logs
	docker compose logs -f --tail=50
lint:      ## ruff + hadolint + shellcheck + compose validation
	cd api && ruff check .
	hadolint api/Dockerfile nginx/Dockerfile
	shellcheck scripts/*.sh
	docker compose config -q
test:      ## API unit tests
	cd api && pytest -q
e2e:       ## end-to-end test against the running stack
	./scripts/e2e_test.sh
scale:     ## run 3 API replicas behind nginx
	docker compose up -d --scale api=3 --wait
backup:    ## dump postgres to ./backups
	./scripts/backup_db.sh
restore:   ## restore: make restore FILE=backups/x.sql.gz
	./scripts/restore_db.sh $(FILE)
tools:     ## start Adminer DB UI on :8081
	docker compose --profile tools up -d adminer
clean:     ## stop and remove containers + images built here
	docker compose down --rmi local
nuke:      ## stop and DELETE the database volume
	docker compose down -v
