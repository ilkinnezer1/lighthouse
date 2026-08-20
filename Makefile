MODE ?= local
COMPOSE := docker compose -f docker-compose.dev.yml --profile $(MODE)

PROD_MODE ?= server
PROD_COMPOSE := docker compose -f docker-compose.prod.yml --profile $(PROD_MODE)

.PHONY: env up down restart logs ps psql redis-cli reset clean \
        net prod-build prod-up prod-down prod-restart prod-logs prod-ps

env:
	@test -f .env || (cp .env.example .env && echo "Created .env")

up: env
	$(COMPOSE) up -d
	@sleep 3
	@$(COMPOSE) ps

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

psql:
	$(COMPOSE) exec postgres psql -U $${POSTGRES_USER:-lighthouse} -d $${POSTGRES_DB:-lighthouse_dev}

redis-cli:
	$(COMPOSE) exec redis redis-cli

reset:
	@printf "Wipe all data volumes? Type 'yes' to confirm: "; read confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(COMPOSE) down -v; \
		echo "Volumes wiped."; \
	else \
		echo "Aborted."; \
	fi

clean:
	$(COMPOSE) down

# ---- production ----
# Traefik and the app services need this before the worker's first deploy makes it.
net:
	@docker network inspect lighthouse-public >/dev/null 2>&1 || \
		(docker network create lighthouse-public && echo "Created lighthouse-public")

prod-build: env
	$(PROD_COMPOSE) build

prod-up: env net
	$(PROD_COMPOSE) up -d --build
	@$(PROD_COMPOSE) ps

prod-down:
	$(PROD_COMPOSE) down

prod-restart: prod-down prod-up

prod-logs:
	$(PROD_COMPOSE) logs -f

prod-ps:
	$(PROD_COMPOSE) ps
