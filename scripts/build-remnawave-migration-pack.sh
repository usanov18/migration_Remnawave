#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/home/alt441"
STAGE_ROOT="${OUT_DIR}/remnawave-migration-build"
ORIGINAL_ARGS=("$@")

log() { echo "INFO: $*"; }
warn() { echo "WARN: $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/build-remnawave-migration-pack.sh

Builds a host-side Remnawave migration pack into /home/alt441/.
EOF
}

ensure_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    exec sudo bash "$0" "$@"
  fi
  die "Run as root or install sudo first"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"
}

pick_existing_dir() {
  local marker="${1:-}"
  shift || true
  local candidate=""
  for candidate in "$@"; do
    [ -n "$candidate" ] || continue
    if [ -n "$marker" ]; then
      [ -f "${candidate}/${marker}" ] && { printf '%s\n' "$candidate"; return 0; }
    else
      [ -d "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
    fi
  done
  return 1
}

find_service_container() {
  local service_name="$1"
  local fallback_name="$2"
  local found=""
  found="$(docker ps -a --filter "label=com.docker.compose.service=${service_name}" --format '{{.Names}}' | head -n1 || true)"
  printf '%s\n' "${found:-$fallback_name}"
}

container_mount_source() {
  local container_name="$1"
  local destination="$2"
  local payload=""
  payload="$(docker inspect "$container_name" 2>/dev/null || true)"
  [ -n "$payload" ] || return 1
  python3 - "$destination" "$payload" <<'PY'
import json
import sys

destination = sys.argv[1]
payload = json.loads(sys.argv[2])
item = payload[0] if payload else {}
for mount in item.get("Mounts") or []:
    if str(mount.get("Destination") or "").strip() == destination:
        src = str(mount.get("Source") or "").strip()
        if src:
            print(src)
            raise SystemExit(0)
raise SystemExit(1)
PY
}

copy_file_if_exists() {
  local src="$1"
  local rel="$2"
  [ -n "$src" ] || return 1
  if [ -f "$src" ]; then
    mkdir -p "${STAGE_DIR}/$(dirname "$rel")"
    cp -a "$src" "${STAGE_DIR}/${rel}"
    return 0
  fi
  return 1
}

copy_tree_if_exists() {
  local src="$1"
  local rel="$2"
  [ -n "$src" ] || return 1
  if [ -d "$src" ]; then
    mkdir -p "${STAGE_DIR}/${rel}"
    cp -a "${src}/." "${STAGE_DIR}/${rel}/"
    return 0
  fi
  return 1
}

read_env_value() {
  local file_path="$1"
  local key="$2"
  if [ ! -f "$file_path" ]; then
    return 0
  fi
  grep -E "^${key}=" "$file_path" | tail -n1 | cut -d'=' -f2- | sed "s/^['\"]//; s/['\"]$//" || true
}

host_from_url() {
  python3 - "$1" <<'PY'
import re
import sys

value = (sys.argv[1] or "").strip()
value = re.sub(r"^[a-z]+://", "", value, flags=re.IGNORECASE)
print(value.split("/", 1)[0].strip())
PY
}

telemt_public_host() {
  local path="$1"
  [ -f "$path" ] || return 0
  python3 - "$path" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw.strip()
    if line.startswith("public_host") and "=" in line:
        print(line.split("=", 1)[1].strip().strip('"').strip("'"))
        break
PY
}

telemt_proxy_secret() {
  local container_name="$1"
  docker exec "$container_name" sh -lc 'cat /run/telemt/proxy-secret' 2>/dev/null || true
}

db_container_env_json() {
  local container_name="$1"
  local payload=""
  payload="$(docker inspect "$container_name" 2>/dev/null || true)"
  [ -n "$payload" ] || {
    echo '{}'
    return 0
  }
  python3 - "$payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
item = payload[0] if payload else {}
env = {}
for raw in item.get("Config", {}).get("Env") or []:
    if "=" in raw:
        key, value = raw.split("=", 1)
        env[key] = value
print(json.dumps(env))
PY
}

json_field() {
  local json_payload="$1"
  local field_name="$2"
  python3 - "$json_payload" "$field_name" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1] or "{}")
print(str(payload.get(sys.argv[2], "")))
PY
}

write_text_file() {
  local rel="$1"
  shift
  mkdir -p "${STAGE_DIR}/$(dirname "$rel")"
  cat > "${STAGE_DIR}/${rel}" <<EOF
$*
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

ensure_root "${ORIGINAL_ARGS[@]}"

require_cmd docker
require_cmd python3
require_cmd tar
require_cmd sha256sum
require_cmd hostname
require_cmd date
require_cmd git

mkdir -p "$OUT_DIR"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
HOST_SHORT="$(hostname -s 2>/dev/null || hostname)"
STAGE_DIR="${STAGE_ROOT}/${TIMESTAMP}"
ARCHIVE_PATH="${OUT_DIR}/remnawave_migration_pack_${HOST_SHORT}_${TIMESTAMP}.tar.gz"
SHA_PATH="${ARCHIVE_PATH}.sha256"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
IRIS_DIR="$(pick_existing_dir docker-compose.yml /opt/iris-remnawave /opt/iris /srv/iris-remnawave || true)"
REMNAWAVE_DIR="$(pick_existing_dir docker-compose.yml /opt/remnawave /srv/remnawave || true)"
NGINX_DIR="$(pick_existing_dir docker-compose.yml /opt/remnawave/nginx /srv/remnawave/nginx || true)"
CADDY_DIR="$(pick_existing_dir docker-compose.yml /opt/remnawave/caddy /srv/remnawave/caddy || true)"
SUBSCRIPTION_DIR="$(pick_existing_dir docker-compose.yml /opt/remnawave/subscription /srv/remnawave/subscription || true)"
TELEMT_DIR="$(pick_existing_dir docker-compose.yml /opt/telemt /srv/telemt || true)"
USER_BOT_DIR="$(pick_existing_dir docker-compose.yml /opt/iris_user /srv/iris_user || true)"
REMNANODE_DIR="$(pick_existing_dir docker-compose.yml /opt/remnanode /srv/remnanode || true)"

NGINX_CONTAINER="$(find_service_container remnawave-nginx remnawave-nginx)"
SITE_DIR="$(container_mount_source "$NGINX_CONTAINER" /var/www/rnexus 2>/dev/null || true)"
[ -n "$SITE_DIR" ] || SITE_DIR="$(pick_existing_dir "" /opt/rnexus-site /srv/rnexus-site || true)"

USER_BOT_CONTAINER="$(find_service_container vpn_bot vpn_bot)"
USER_BOT_DATA_DIR="$(container_mount_source "$USER_BOT_CONTAINER" /app/data 2>/dev/null || true)"
[ -n "$USER_BOT_DATA_DIR" ] || USER_BOT_DATA_DIR="/var/lib/docker/volumes/iris_user_bot_data/_data"

TELEMT_CONTAINER="$(find_service_container telemt telemt)"

IRIS_ENV="${IRIS_DIR}/.env"
REMNAWAVE_ENV="${REMNAWAVE_DIR}/.env"
SUB_ENV="${SUBSCRIPTION_DIR}/.env"
TELEMT_CFG="${TELEMT_DIR}/config.toml"

PUBLIC_HOST="$(read_env_value "$IRIS_ENV" PUBLIC_HOST)"
ADMIN_DOMAIN="$(host_from_url "$(read_env_value "$IRIS_ENV" REMNAWAVE_URL)")"
[ -n "$ADMIN_DOMAIN" ] || ADMIN_DOMAIN="$(read_env_value "$REMNAWAVE_ENV" FRONT_END_DOMAIN)"
SUB_DOMAIN="$(host_from_url "$(read_env_value "$IRIS_ENV" REMNAWAVE_SUB_URL)")"
[ -n "$SUB_DOMAIN" ] || SUB_DOMAIN="$(host_from_url "$(read_env_value "$SUB_ENV" REMNAWAVE_PANEL_URL)")"
[ -n "$SUB_DOMAIN" ] || SUB_DOMAIN="$(read_env_value "$REMNAWAVE_ENV" SUB_PUBLIC_DOMAIN)"
MTPROXY_HOST="$(telemt_public_host "$TELEMT_CFG")"
[ -n "$MTPROXY_HOST" ] || MTPROXY_HOST="$PUBLIC_HOST"
REPO_REMOTE="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
REPO_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)"

log "Building migration pack in ${ARCHIVE_PATH}"

copy_file_if_exists "${IRIS_DIR}/.env" "iris-remnawave/.env" || true
copy_file_if_exists "${IRIS_DIR}/docker-compose.yml" "iris-remnawave/docker-compose.yml" || true
copy_file_if_exists "${IRIS_DIR}/state/bot_users.db" "iris-remnawave/state/bot_users.db" || true
copy_file_if_exists "${IRIS_DIR}/state/traffic_cache.json" "iris-remnawave/state/traffic_cache.json" || true

copy_file_if_exists "${REMNAWAVE_DIR}/.env" "remnawave/.env" || true
copy_file_if_exists "${REMNAWAVE_DIR}/docker-compose.yml" "remnawave/docker-compose.yml" || true
copy_file_if_exists "${REMNAWAVE_DIR}/compose.yml" "remnawave/compose.yml" || true
copy_tree_if_exists "${NGINX_DIR}" "remnawave/nginx" || true
copy_tree_if_exists "${CADDY_DIR}" "remnawave/caddy" || true
copy_tree_if_exists "${SUBSCRIPTION_DIR}" "remnawave/subscription" || true
copy_tree_if_exists "${TELEMT_DIR}" "telemt" || true
copy_file_if_exists "${USER_BOT_DIR}/docker-compose.yml" "iris_user/docker-compose.yml" || true
copy_file_if_exists "${USER_BOT_DIR}/.env" "iris_user/.env" || true
copy_file_if_exists "${USER_BOT_DATA_DIR}/bot.db" "iris_user/data/bot.db" || true
copy_tree_if_exists "${REMNANODE_DIR}" "remnanode" || true
copy_tree_if_exists "${SITE_DIR}" "rnexus-site" || true

PROXY_SECRET="$(telemt_proxy_secret "$TELEMT_CONTAINER" || true)"
if [ -n "$PROXY_SECRET" ] && [ "$PROXY_SECRET" != "NO_PROXY_SECRET" ]; then
  write_text_file "telemt/proxy-secret" "$PROXY_SECRET"
fi

DB_CONTAINER="$(find_service_container remnawave-db remnawave-db)"
DB_ENV_JSON="$(db_container_env_json "$DB_CONTAINER" 2>/dev/null || echo '{}')"
DB_NAME="$(json_field "$DB_ENV_JSON" POSTGRES_DB)"
DB_USER="$(json_field "$DB_ENV_JSON" POSTGRES_USER)"
DB_PASS="$(json_field "$DB_ENV_JSON" POSTGRES_PASSWORD)"
DB_DUMP_STATUS="missing"

if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
  mkdir -p "${STAGE_DIR}/remnawave"
  if docker exec -e "PGPASSWORD=${DB_PASS}" "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "${STAGE_DIR}/remnawave/remnawave_db_dump.sql" 2>/dev/null; then
    DB_DUMP_STATUS="ok"
  else
    warn "Postgres dump failed for ${DB_CONTAINER}"
    rm -f "${STAGE_DIR}/remnawave/remnawave_db_dump.sql"
    DB_DUMP_STATUS="failed"
  fi
else
  warn "Postgres credentials not found from ${DB_CONTAINER}"
fi

docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "${STAGE_DIR}/inventory/docker_ps.txt" || true
systemctl --no-pager --type=service --state=running 2>/dev/null | egrep 'ops-agent|iris-node-registrar|docker|nginx|warp|telemt' > "${STAGE_DIR}/inventory/services.txt" || true

export MANIFEST_PATH="${STAGE_DIR}/inventory/manifest.json"
export MANIFEST_HOSTNAME="$HOST_SHORT"
export MANIFEST_CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export MANIFEST_PUBLIC_HOST="${PUBLIC_HOST}"
export MANIFEST_ADMIN_DOMAIN="${ADMIN_DOMAIN}"
export MANIFEST_SUB_DOMAIN="${SUB_DOMAIN}"
export MANIFEST_MTPROXY_HOST="${MTPROXY_HOST}"
export MANIFEST_REPO_DIR="${REPO_DIR}"
export MANIFEST_IRIS_DIR="${IRIS_DIR}"
export MANIFEST_REMNAWAVE_DIR="${REMNAWAVE_DIR}"
export MANIFEST_NGINX_DIR="${NGINX_DIR}"
export MANIFEST_CADDY_DIR="${CADDY_DIR}"
export MANIFEST_SUBSCRIPTION_DIR="${SUBSCRIPTION_DIR}"
export MANIFEST_TELEMT_DIR="${TELEMT_DIR}"
export MANIFEST_USER_BOT_DIR="${USER_BOT_DIR}"
export MANIFEST_REMNANODE_DIR="${REMNANODE_DIR}"
export MANIFEST_SITE_DIR="${SITE_DIR}"
export MANIFEST_DB_DUMP_STATUS="${DB_DUMP_STATUS}"
export MANIFEST_REPO_REMOTE="${REPO_REMOTE}"
export MANIFEST_REPO_COMMIT="${REPO_COMMIT}"

python3 - <<'PY'
import json
import os
from pathlib import Path

manifest = {
    "created_at_utc": os.environ.get("MANIFEST_CREATED_AT", ""),
    "host": os.environ.get("MANIFEST_HOSTNAME", ""),
    "backup_type": "remnawave-migration-pack-host-script",
    "public_host": os.environ.get("MANIFEST_PUBLIC_HOST", ""),
    "admin_domain": os.environ.get("MANIFEST_ADMIN_DOMAIN", ""),
    "sub_domain": os.environ.get("MANIFEST_SUB_DOMAIN", ""),
    "mtproxy_host": os.environ.get("MANIFEST_MTPROXY_HOST", ""),
    "paths": {
        "repo": os.environ.get("MANIFEST_REPO_DIR", ""),
        "iris": os.environ.get("MANIFEST_IRIS_DIR", ""),
        "remnawave": os.environ.get("MANIFEST_REMNAWAVE_DIR", ""),
        "nginx": os.environ.get("MANIFEST_NGINX_DIR", ""),
        "caddy": os.environ.get("MANIFEST_CADDY_DIR", ""),
        "subscription": os.environ.get("MANIFEST_SUBSCRIPTION_DIR", ""),
        "telemt": os.environ.get("MANIFEST_TELEMT_DIR", ""),
        "user_bot": os.environ.get("MANIFEST_USER_BOT_DIR", ""),
        "remnanode": os.environ.get("MANIFEST_REMNANODE_DIR", ""),
        "site": os.environ.get("MANIFEST_SITE_DIR", ""),
    },
    "git": {
        "remote": os.environ.get("MANIFEST_REPO_REMOTE", ""),
        "commit": os.environ.get("MANIFEST_REPO_COMMIT", ""),
    },
    "components": {
        "iris": "ok" if os.environ.get("MANIFEST_IRIS_DIR") else "missing",
        "remnawave": "ok" if os.environ.get("MANIFEST_REMNAWAVE_DIR") else "missing",
        "nginx": "ok" if os.environ.get("MANIFEST_NGINX_DIR") else "missing",
        "caddy": "ok" if os.environ.get("MANIFEST_CADDY_DIR") else "missing",
        "subscription": "ok" if os.environ.get("MANIFEST_SUBSCRIPTION_DIR") else "missing",
        "mtproto": "ok" if os.environ.get("MANIFEST_TELEMT_DIR") else "missing",
        "user_bot": "ok" if os.environ.get("MANIFEST_USER_BOT_DIR") else "missing",
        "remnanode": "ok" if os.environ.get("MANIFEST_REMNANODE_DIR") else "missing",
        "site": "ok" if os.environ.get("MANIFEST_SITE_DIR") else "missing",
        "db_dump": os.environ.get("MANIFEST_DB_DUMP_STATUS", "missing"),
    },
}

path = Path(os.environ["MANIFEST_PATH"])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat > "${STAGE_DIR}/inventory/restore_notes.txt" <<EOF
Remnawave Panel Migration Pack
==============================

Archive path:
- ${ARCHIVE_PATH}

Hardcoded operator workspace:
- archive output: /home/alt441/
- restore staging: /home/alt441/remnawave-migration-restore/

Current environment:
- panel host: ${HOST_SHORT}
- panel public host: ${PUBLIC_HOST:-n/a}
- panel domain: ${ADMIN_DOMAIN:-n/a}
- subscription domain: ${SUB_DOMAIN:-n/a}
- mtproto public host: ${MTPROXY_HOST:-n/a}
- iris repo remote: ${REPO_REMOTE:-n/a}
- iris repo commit: ${REPO_COMMIT:-n/a}

Recommended restore order:
1. Prepare a new Linux host with Docker Engine and docker compose plugin.
2. Copy the archive into /home/alt441/.
3. Run: sudo bash scripts/restore-remnawave-migration-pack.sh
4. If public IP changes, update:
   - /opt/iris-remnawave/.env -> PUBLIC_HOST
   - /opt/telemt/config.toml -> public_host
   - /opt/iris_user/.env -> MTPROXY_URL
5. If domains change, update:
   - /opt/remnawave/.env -> FRONT_END_DOMAIN, SUB_PUBLIC_DOMAIN
   - /opt/remnawave/subscription/.env -> REMNAWAVE_PANEL_URL
   - reverse proxy config in /opt/remnawave/nginx or /opt/remnawave/caddy

Smoke checks after restore:
- panel frontend opens
- subscription page opens
- Remnawave API responds
- I.R.I.S. answers in Telegram
- MTProto accepts connections
- user bot still serves clients
EOF

tar -czf "$ARCHIVE_PATH" -C "$STAGE_DIR" .
sha256sum "$ARCHIVE_PATH" > "$SHA_PATH"

log "Migration pack created"
log "Archive: $ARCHIVE_PATH"
log "Checksum: $SHA_PATH"
log "Staging dir: $STAGE_DIR"
