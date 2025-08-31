# n8n + Postgres + Redis + Caddy — Simple Compose (Local by default, Prod via profile)

## What is this?
A compact Docker Compose stack to self-host **n8n** with **PostgreSQL** (persistence), **Redis** (queues), and **Caddy** (automatic HTTPS).  
- **Local by default**: `docker compose up -d` exposes n8n at **http://localhost:5678**.
- **Production via profile**: add `--profile prod` and set `N8N_HOSTNAME` + `ACME_EMAIL` for HTTPS on ports 80/443.
- Single env pattern: `WEBHOOK_URL=${N8N_HOSTNAME:+https://}${N8N_HOSTNAME:-http://localhost:5678}`

## Quick start

### Local (default)
```bash
cp env.example .env
# edit .env: set POSTGRES_PASSWORD and N8N_ENCRYPTION_KEY
docker compose up -d
open http://localhost:5678
```

### Production (HTTPS with Caddy)
```bash
# in .env set:
# N8N_HOSTNAME=your.domain
# ACME_EMAIL=you@example.com
# PRODUCTION=true
docker compose --profile prod up -d
# visit: https://your.domain/
```

## Hostname & Webhook URL pattern
We use a single variable `N8N_HOSTNAME` to drive URLs:
```
WEBHOOK_URL=${N8N_HOSTNAME:+https://}${N8N_HOSTNAME:-http://localhost:5678}
```
- If `N8N_HOSTNAME` is set → `https://<hostname>/`
- If not set → `http://localhost:5678/` (for local)

## Generate N8N_ENCRYPTION_KEY
**macOS/Linux**
```bash
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)" >> .env
```
**Windows PowerShell**
```powershell
$bytes = New-Object byte[] 32
(new-object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes)
$hex = -join ($bytes | ForEach-Object { $_.ToString("x2") })
Add-Content -Path .env -Value ("N8N_ENCRYPTION_KEY=$hex")
```

## Data locations (named volumes)
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

## Backup script & Makefile

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

## Adding a Worker (optional, advanced)
For heavy loads, you can extend `docker-compose.yml` with an `n8n-worker` service. See the README in previous versions for details.
