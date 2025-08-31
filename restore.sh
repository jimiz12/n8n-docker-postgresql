#!/usr/bin/env bash
# Restore script for n8n stack (Postgres + n8n_data) using Docker volumes and pg_dump SQL backups.
#
# Usage:
#   bash restore.sh --volume postgres_data --file backups/postgres_data_xxx.tar.gz
#   bash restore.sh --pgdump backups/postgres_pgdump_xxx.sql.gz
#
# Options:
#   --volume NAME    Name of Docker volume to restore into (must exist or will be created)
#   --file PATH      Path to a .tar.gz snapshot created by backup.sh
#   --pgdump PATH    Path to a .sql.gz file from pg_dump
#
# Examples:
#   bash restore.sh --volume postgres_data --file backups/postgres_data_20240501-nightly.tar.gz
#   bash restore.sh --volume n8n_data --file backups/n8n_data_20240501-nightly.tar.gz
#   bash restore.sh --pgdump backups/postgres_pgdump_20240501-nightly.sql.gz
#
# Notes:
# - For pg_dump restores, the postgres container must be running and .env vars set (POSTGRES_USER/DB).
# - For volume restores, the target volume will be created if it does not exist.
set -euo pipefail

VOLUME=""
FILE=""
PGDUMP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volume) VOLUME="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --pgdump) PGDUMP="$2"; shift 2;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# //'; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# Detect docker compose command
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
  else
    echo "ERROR: Docker Compose not found. Install Docker Desktop or docker-compose."; exit 1
  fi
else
  echo "ERROR: docker not found in PATH."; exit 1
fi

if [[ -n "$FILE" && -n "$VOLUME" ]]; then
  echo "==> Restoring volume '$VOLUME' from snapshot $FILE"
  docker volume create "$VOLUME" >/dev/null
  docker run --rm -v "$VOLUME":/data -v "$(pwd)":/host alpine     sh -c "cd /data && tar xzf /host/$FILE"
  echo "Restore complete for $VOLUME."
elif [[ -n "$PGDUMP" ]]; then
  echo "==> Restoring Postgres database from dump $PGDUMP"
  gzip -dc "$PGDUMP" | $COMPOSE exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
  echo "pg_dump restore complete."
else
  echo "ERROR: must specify either --volume NAME with --file PATH, or --pgdump PATH"
  exit 1
fi
