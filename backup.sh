#!/usr/bin/env bash
# Backup script for n8n stack (Postgres + n8n_data) using Docker
# - Creates BOTH a logical Postgres dump (pg_dump) and volume tarballs
# - Works with Docker Compose v2 ("docker compose") or v1 ("docker-compose")
#
# Usage:
#   bash backup.sh [--output ./backups] [--include-caddy] [--no-snapshot] [--no-pgdump] [--label note]
#
# Examples:
#   bash backup.sh
#   bash backup.sh --output ~/n8n-backups --include-caddy --label nightly
#
# Notes:
# - pg_dump requires the postgres container to be running and env vars set in Compose (.env).
# - Volume snapshots do not require containers to be running but are point-in-time filesystem copies.
set -euo pipefail

OUT_DIR="./backups"
INCLUDE_CADDY=false
DO_SNAPSHOT=true
DO_PGDUMP=true
LABEL="manual"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o) OUT_DIR="$2"; shift 2;;
    --include-caddy) INCLUDE_CADDY=true; shift;;
    --no-snapshot) DO_SNAPSHOT=false; shift;;
    --no-pgdump) DO_PGDUMP=false; shift;;
    --label) LABEL="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--output DIR] [--include-caddy] [--no-snapshot] [--no-pgdump] [--label note]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

timestamp() { date +"%Y%m%d-%H%M%S"; }
TS="$(timestamp)"

mkdir -p "$OUT_DIR"

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

# Helper to snapshot a named volume to tar.gz
snapshot_volume() {
  local VOL="$1"
  local OUT="$2"
  echo "-> Snapshotting volume '${VOL}' to ${OUT}"
  docker run --rm -v "${VOL}:/data" -v "$(pwd)":/host alpine sh -c "tar czf /host/${OUT} -C /data ."
}

# 1) Postgres logical dump (preferred for DB integrity)
if $DO_PGDUMP; then
  echo "==> Postgres pg_dump (logical backup)"
  if $COMPOSE ps postgres >/dev/null 2>&1; then
    :
  else
    echo "Postgres container not found via Compose. Ensure you're in the compose directory."
    exit 1
  fi
  # Dump using env from the running container (.env provides POSTGRES_USER/DB)
  PG_OUT="${OUT_DIR}/postgres_pgdump_${TS}_${LABEL}.sql.gz"
  echo "-> Writing ${PG_OUT}"
  # -T: no TTY; pipe to gzip on host
  $COMPOSE exec -T postgres sh -lc 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip -c > "${PG_OUT}"
fi

# 2) Volume snapshots (filesystem copies)
if $DO_SNAPSHOT; then
  echo "==> Volume snapshots (tar.gz)"
  snapshot_volume "postgres_data" "${OUT_DIR}/postgres_data_${TS}_${LABEL}.tar.gz"
  snapshot_volume "n8n_data"      "${OUT_DIR}/n8n_data_${TS}_${LABEL}.tar.gz"
  if $INCLUDE_CADDY; then
    snapshot_volume "caddy_data"   "${OUT_DIR}/caddy_data_${TS}_${LABEL}.tar.gz"
  fi
fi

echo "==> Done."
echo "Backups saved in: ${OUT_DIR}"
echo "Files:"
ls -lh "${OUT_DIR}" | awk '{print "   "$9"  "$5}' || true

cat <<'TIP'

Restore tips:
  # Restore a volume snapshot (example for postgres_data)
  docker volume create postgres_data
  docker run --rm -v postgres_data:/data -v "$(pwd)":/host alpine     sh -c "cd /data && tar xzf /host/path/to/postgres_data_YYYYMMDD-HHMMSS_label.tar.gz"

  # Restore n8n_data similarly
  docker volume create n8n_data
  docker run --rm -v n8n_data:/data -v "$(pwd)":/host alpine     sh -c "cd /data && tar xzf /host/path/to/n8n_data_YYYYMMDD-HHMMSS_label.tar.gz"

  # Restore from pg_dump (SQL) into a running postgres container:
  gzip -dc path/to/postgres_pgdump_YYYYMMDD-HHMMSS_label.sql.gz |     $COMPOSE exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
TIP
