.PHONY: up prod down logs backup

up:
	docker compose up -d

prod:
	docker compose --profile prod up -d

down:
	docker compose down

logs:
	docker compose logs -f

backup:
	bash backup.sh --output ./backups --include-caddy --label manual
