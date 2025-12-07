.PHONY: up down logs migrate shell build restart clean

# Docker Compose commands
up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

build:
	docker compose build

restart:
	docker compose restart

# Django management commands
migrate:
	docker compose exec web python manage.py migrate

makemigrations:
	docker compose exec web python manage.py makemigrations

shell:
	docker compose exec web bash

createsuperuser:
	docker compose exec web python manage.py createsuperuser

collectstatic:
	docker compose exec web python manage.py collectstatic --noinput

# Development commands
dev:
	docker compose up

dev-logs:
	docker compose up --build

# Cleanup
clean:
	docker compose down -v
	docker system prune -f

# Status
status:
	docker compose ps

# Database
db-shell:
	docker compose exec postgres psql -U postgres -d soulsupport

# Redis
redis-cli:
	docker compose exec redis redis-cli

