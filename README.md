# n8n Self-host with Postgres + Redis + Caddy — Docker Compose

[![Watch the video](https://img.youtube.com/vi/_ozDuDA2BZ0/0.jpg)](https://www.youtube.com/watch?v=_ozDuDA2BZ0&t=1072s)
**▶️ [Watch a full walkthrough on YouTube](https://www.youtube.com/watch?v=_ozDuDA2BZ0&t=1072s)**

## Overview
A compact Docker Compose stack to self-host **n8n** with **PostgreSQL** (persistence), **Redis** (queues), and **Caddy** (automatic HTTPS).  
- **SearXNG** - Added SearXNG for AI search meta data.
- **Local by default**: `docker compose up -d` exposes n8n at **http://localhost:5678**.
- **Production via profile**: add `--profile prod` and set `N8N_HOSTNAME` + `ACME_EMAIL` for HTTPS on ports 80/443.

![Self Host N8N](/n8n-self-host-postgres.png?raw=true "Self Host N8N")

## Why Create This Docker Repo

We use **n8n** both internally and with our clients. Frequently we need a fast, reliable way to spin up a self-hosted instance—whether for our own development, or to hand off to a client’s IT team for their developers or production environment.

This repo provides a **ready-to-use Docker Compose setup** that follows a consistent, secure pattern:

- **PostgreSQL** for durable workflow and credential storage  
- **Redis** for queueing and caching  
- **Caddy** for automatic HTTPS, so n8n can be exposed safely on a production server (internally or on the internet)  

By standardizing on this stack, we make it simple to install, secure, and share n8n environments across teams.

## Who This Is For

- **Developers** — who want a quick local n8n environment with PostgreSQL + Redis behind it.  
- **IT / DevOps teams** — who need a secure, repeatable way to deploy n8n into production with SSL built-in.  
- **Clients & partners** — who prefer a hand-off setup that “just works” without needing to piece together Postgres, Redis, and HTTPS manually.  


## Quick Start

### Local (default)
```bash
git clone https://github.com/jimiz12/n8n-docker-postgresql.git
cp env.example .env
# edit .env: set POSTGRES_PASSWORD and N8N_ENCRYPTION_KEY
docker compose up -d
open http://localhost:5678
```

### Production (HTTPS with Caddy)
```bash
git clone https://github.com/jimiz12/n8n-docker-postgresql.git
cp env.example .env
# in .env set:
# N8N_HOSTNAME=your.domain
# ACME_EMAIL=you@example.com
# PRODUCTION=true
docker compose --profile prod up -d
# visit: https://your.domain/
```

## Requirements
- Docker
- Docker Compose
- (Optional) Make

## Generate N8N_ENCRYPTION_KEY and SEARXNG_SECRET
**macOS/Linux**
```bash
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)" >> .env
echo "SEARXNG_SECRET=$(openssl rand -hex 32)" >> .env
```
**Windows PowerShell**
```powershell
$bytes = New-Object byte[] 32
(new-object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes)
$hex = -join ($bytes | ForEach-Object { $_.ToString("x2") })
Add-Content -Path .env -Value ("N8N_ENCRYPTION_KEY=$hex")
```


## Viewing Logs

To view logs for specific services, use Docker Compose:

```bash
docker compose logs -f n8n
docker compose logs -f caddy
```

- `-f` tails the logs (like `tail -f`).
- Replace `n8n` or `caddy` with any service name from your `docker-compose.yml`.


## Data Locations (Named Volumes)
- Postgres → `postgres_data`
- Redis → `redis_data`
- n8n → `n8n_data`
- Caddy (certs/config) → `caddy_data`, `caddy_config` (prod only)

## Backup & Restore (examples)
Backup Postgres:
```bash
docker run --rm -v postgres_data:/data -v "$PWD":/backup alpine   sh -c "tar czf /backup/postgres_data-backup.tgz -C /data ."
```
Backup n8n:
```bash
docker run --rm -v n8n_data:/data -v "$PWD":/backup alpine   sh -c "tar czf /backup/n8n_data-backup.tgz -C /data ."
```
Restore:
```bash
docker volume create postgres_data
docker run --rm -v postgres_data:/data -v "$PWD":/backup alpine   sh -c "cd /data && tar xzf /backup/postgres_data-backup.tgz"
docker volume create n8n_data
docker run --rm -v n8n_data:/data -v "$PWD":/backup alpine   sh -c "cd /data && tar xzf /backup/n8n_data-backup.tgz"
```

## Backup Script & Makefile

This repo also includes a helper **backup.sh** script and **Makefile**.

### backup.sh
Run it to back up Postgres (both pg_dump and volume snapshots) and n8n_data:
```bash
chmod +x backup.sh
./backup.sh --output ./backups --include-caddy --label nightly
```

Options:
- `--output DIR` (default `./backups`)
- `--include-caddy` (also snapshot Caddy certs/config)
- `--no-pgdump` / `--no-snapshot` (toggle methods)
- `--label note` (append a label to filenames)

### Makefile shortcut
Use the included Makefile target for a quick backup:
```bash
make backup
```

This runs:
```bash
bash backup.sh --output ./backups --include-caddy --label manual
```

## Adding a Worker (Optional, Advanced)
For heavy loads, you can extend `docker-compose.yml` with an `n8n-worker` service.

### Example snippet:
```yaml
n8n-worker:
  image: n8nio/n8n:latest
  command: ["n8n", "worker"]
  environment:
    EXECUTIONS_MODE: queue
    DB_TYPE: postgresdb
    DB_POSTGRESDB_HOST: postgres
    DB_POSTGRESDB_PORT: 5432
    DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
    DB_POSTGRESDB_USER: ${POSTGRES_USER}
    DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
    QUEUE_BULL_REDIS_HOST: redis
    QUEUE_BULL_REDIS_PORT: 6379
    QUEUE_BULL_REDIS_DB: ${REDIS_DB:-0}
    QUEUE_BULL_REDIS_PASSWORD: ${REDIS_PASSWORD:-}
    N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
    GENERIC_TIMEZONE: ${GENERIC_TIMEZONE:-America/Detroit}
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
  networks: [app]
  restart: unless-stopped
```

Run workers alongside your main `n8n`:
```bash
docker compose up -d n8n-worker
docker compose up -d --scale n8n-worker=3
```

### Ubuntu Commands:
```bash
# Common prereqs (Ubuntu 24.04)
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
# Install Docker using the official repo:
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```