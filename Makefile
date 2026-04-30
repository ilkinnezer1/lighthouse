COMPOSE := docker compose -f docker-compose.dev.yml

.PHONY: env up down restart logs ps psql redis-cli reset clean

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
