#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/home"
RESTORE_ROOT="${OUT_DIR}/remnawave-migration-restore"
ORIGINAL_ARGS=("$@")

ARCHIVE_PATH=""
PUBLIC_HOST_OVERRIDE=""
ADMIN_DOMAIN_OVERRIDE=""
SUBSCRIPTION_DOMAIN_OVERRIDE=""
MTPROXY_HOST_OVERRIDE=""
SKIP_START="0"

log() { echo "INFO: $*"; }
warn() { echo "WARN: $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/restore-remnawave-migration-pack.sh [options]

Options:
  --archive PATH               Explicit archive path. Default: latest /home/remnawave_migration_pack_*.tar.gz
  --public-host VALUE          Override PUBLIC_HOST for I.R.I.S.
  --admin-domain VALUE         Override Remnawave panel domain
  --subscription-domain VALUE  Override subscription page domain
  --mtproto-host VALUE         Override MTProto public host
  --skip-start                 Restore files only, do not start services
  --help                       Show this help
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

normalize_domain() {
  python3 - "$1" <<'PY'
import re
import sys
value = (sys.argv[1] or "").strip()
if not value:
    print("")
    raise SystemExit
value = re.sub(r"^[a-z]+://", "", value, flags=re.IGNORECASE)
value = value.strip().strip("/")
print(value)
PY
}

normalize_url() {
  python3 - "$1" <<'PY'
import re
import sys
value = (sys.argv[1] or "").strip()
if not value:
    print("")
    raise SystemExit
if not re.match(r"^[a-z]+://", value, flags=re.IGNORECASE):
    value = "https://" + value
print(value.rstrip("/"))
PY
}

read_env_value() {
  local file_path="$1"
  local key="$2"
  if [ ! -f "$file_path" ]; then
    return 0
  fi
  grep -E "^${key}=" "$file_path" | tail -n1 | cut -d'=' -f2- | sed "s/^['\"]//; s/['\"]$//" || true
}

upsert_env_key() {
  local file_path="$1"
  local key="$2"
  local value="$3"
  ENV_FILE_PATH="$file_path" ENV_KEY="$key" ENV_VALUE="$value" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["ENV_FILE_PATH"])
path.parent.mkdir(parents=True, exist_ok=True)
key = os.environ["ENV_KEY"]
value = os.environ.get("ENV_VALUE", "")

lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
prefix = f"{key}="
for idx, line in enumerate(lines):
    if line.startswith(prefix):
        lines[idx] = f"{prefix}{value}"
        break
else:
    lines.append(f"{prefix}{value}")

path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")
PY
}

replace_toml_key() {
  local file_path="$1"
  local key="$2"
  local value="$3"
  [ -f "$file_path" ] || return 0
  TOML_FILE_PATH="$file_path" TOML_KEY="$key" TOML_VALUE="$value" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["TOML_FILE_PATH"])
key = os.environ["TOML_KEY"]
value = os.environ["TOML_VALUE"]

lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
prefix = f"{key}"
done = False
for idx, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith(prefix) and "=" in stripped:
        indent = line[: len(line) - len(line.lstrip(" "))]
        lines[idx] = f'{indent}{key} = "{value}"'
        done = True
        break
if not done:
    lines.append(f'{key} = "{value}"')
path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")
PY
}

rewrite_mtproxy_url() {
  local file_path="$1"
  local new_host="$2"
  [ -f "$file_path" ] || return 0
  MTPROXY_ENV_FILE="$file_path" MTPROXY_NEW_HOST="$new_host" python3 - <<'PY'
import os
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

path = Path(os.environ["MTPROXY_ENV_FILE"])
new_host = os.environ["MTPROXY_NEW_HOST"]
lines = path.read_text(encoding="utf-8").splitlines()

for idx, line in enumerate(lines):
    if not line.startswith("MTPROXY_URL="):
        continue
    value = line.split("=", 1)[1].strip().strip('"').strip("'")
    try:
        parts = urlsplit(value)
        query = dict(parse_qsl(parts.query, keep_blank_values=True))
        query["server"] = new_host
        new_value = urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))
        lines[idx] = f"MTPROXY_URL={new_value}"
    except Exception:
        pass
    break

path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")
PY
}

stash_existing_path() {
  local src="$1"
  local rel="$2"
  [ -e "$src" ] || return 0
  local dst="${PRE_RESTORE_DIR}/${rel}"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    return 0
  fi
  cp -a "$src" "$dst"
}

restore_tree() {
  local rel="$1"
  local dst="$2"
  local src="${WORK_DIR}/${rel}"
  [ -d "$src" ] || return 0
  stash_existing_path "$dst" "$rel"
  mkdir -p "$dst"
  cp -a "${src}/." "${dst}/"
}

restore_file() {
  local rel="$1"
  local dst="$2"
  local src="${WORK_DIR}/${rel}"
  [ -f "$src" ] || return 0
  stash_existing_path "$dst" "$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

manifest_read() {
  local key="$1"
  local default_value="${2:-}"
  MANIFEST_PATH="$MANIFEST_PATH" MANIFEST_KEY="$key" MANIFEST_DEFAULT="$default_value" python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["MANIFEST_PATH"])
default = os.environ.get("MANIFEST_DEFAULT", "")
if not path.exists():
    print(default)
    raise SystemExit

payload = json.loads(path.read_text(encoding="utf-8"))
value = payload
for part in os.environ["MANIFEST_KEY"].split("."):
    if isinstance(value, dict):
        value = value.get(part, "")
    else:
        value = ""
        break
print(value or default)
PY
}

wait_for_container_healthy() {
  local container_name="$1"
  local attempts="${2:-40}"
  local delay="${3:-3}"
  local status=""
  local i=0
  for ((i=1; i<=attempts; i++)); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_name" 2>/dev/null || true)"
    if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
      return 0
    fi
    sleep "$delay"
  done
  warn "Container ${container_name} did not become healthy in time (last status: ${status:-unknown})"
  return 1
}

clone_or_prepare_iris_repo() {
  local repo_remote="$1"
  local repo_commit="$2"
  if [ -d /opt/iris-remnawave/.git ]; then
    log "I.R.I.S. repo already present at /opt/iris-remnawave"
    return 0
  fi
  [ -n "$repo_remote" ] || {
    warn "I.R.I.S. git remote is missing in manifest; restore will rely only on archived config files"
    return 0
  }
  log "Cloning I.R.I.S. repo from ${repo_remote}"
  rm -rf /opt/iris-remnawave
  git clone "$repo_remote" /opt/iris-remnawave
  if [ -n "$repo_commit" ]; then
    git -C /opt/iris-remnawave checkout "$repo_commit" || warn "Could not checkout ${repo_commit}; keeping default branch state"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive)
      ARCHIVE_PATH="${2:-}"
      shift 2
      ;;
    --public-host)
      PUBLIC_HOST_OVERRIDE="${2:-}"
      shift 2
      ;;
    --admin-domain)
      ADMIN_DOMAIN_OVERRIDE="${2:-}"
      shift 2
      ;;
    --subscription-domain)
      SUBSCRIPTION_DOMAIN_OVERRIDE="${2:-}"
      shift 2
      ;;
    --mtproto-host)
      MTPROXY_HOST_OVERRIDE="${2:-}"
      shift 2
      ;;
    --skip-start)
      SKIP_START="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

ensure_root "${ORIGINAL_ARGS[@]}"

require_cmd bash
require_cmd tar
require_cmd docker
require_cmd python3
require_cmd git
require_cmd hostname
require_cmd date

mkdir -p "$OUT_DIR" "$RESTORE_ROOT"

if [ -z "$ARCHIVE_PATH" ]; then
  ARCHIVE_PATH="$(ls -1t "${OUT_DIR}"/remnawave_migration_pack_*.tar.gz 2>/dev/null | head -n1 || true)"
fi
[ -n "$ARCHIVE_PATH" ] || die "Migration archive not found in ${OUT_DIR}. Copy remnawave_migration_pack_*.tar.gz into /home/ or pass --archive PATH"
[ -f "$ARCHIVE_PATH" ] || die "Archive does not exist: ${ARCHIVE_PATH}"

STAMP="$(date -u +%Y%m%d_%H%M%S)"
WORK_DIR="${RESTORE_ROOT}/${STAMP}"
PRE_RESTORE_DIR="${OUT_DIR}/pre-restore-snapshot_${STAMP}"
mkdir -p "$WORK_DIR" "$PRE_RESTORE_DIR"

log "Extracting ${ARCHIVE_PATH} into ${WORK_DIR}"
tar -xzf "$ARCHIVE_PATH" -C "$WORK_DIR"

MANIFEST_PATH="${WORK_DIR}/inventory/manifest.json"
OLD_PUBLIC_HOST="$(manifest_read public_host)"
OLD_ADMIN_DOMAIN="$(manifest_read admin_domain)"
OLD_SUB_DOMAIN="$(manifest_read sub_domain)"
OLD_MTPROXY_HOST="$(manifest_read mtproxy_host)"
IRIS_REPO_REMOTE="$(manifest_read git.remote)"
IRIS_REPO_COMMIT="$(manifest_read git.commit)"

clone_or_prepare_iris_repo "$IRIS_REPO_REMOTE" "$IRIS_REPO_COMMIT"

restore_tree "remnawave" "/opt/remnawave"
restore_tree "telemt" "/opt/telemt"
restore_tree "iris_user" "/opt/iris_user"
restore_tree "remnanode" "/opt/remnanode"
restore_tree "rnexus-site" "/opt/rnexus-site"

restore_file "iris-remnawave/.env" "/opt/iris-remnawave/.env"
restore_file "iris-remnawave/docker-compose.yml" "/opt/iris-remnawave/docker-compose.yml"
restore_file "iris-remnawave/state/bot_users.db" "/opt/iris-remnawave/state/bot_users.db"
restore_file "iris-remnawave/state/traffic_cache.json" "/opt/iris-remnawave/state/traffic_cache.json"

ADMIN_DOMAIN_FINAL="$(normalize_domain "${ADMIN_DOMAIN_OVERRIDE:-$OLD_ADMIN_DOMAIN}")"
SUB_DOMAIN_FINAL="$(normalize_domain "${SUBSCRIPTION_DOMAIN_OVERRIDE:-$OLD_SUB_DOMAIN}")"
PUBLIC_HOST_FINAL="${PUBLIC_HOST_OVERRIDE:-$OLD_PUBLIC_HOST}"
MTPROXY_HOST_FINAL="${MTPROXY_HOST_OVERRIDE:-$OLD_MTPROXY_HOST}"
[ -n "$MTPROXY_HOST_FINAL" ] || MTPROXY_HOST_FINAL="$PUBLIC_HOST_FINAL"

if [ -n "$ADMIN_DOMAIN_FINAL" ]; then
  upsert_env_key "/opt/remnawave/.env" "FRONT_END_DOMAIN" "$ADMIN_DOMAIN_FINAL"
  upsert_env_key "/opt/remnawave/subscription/.env" "REMNAWAVE_PANEL_URL" "$(normalize_url "$ADMIN_DOMAIN_FINAL")"
  upsert_env_key "/opt/iris-remnawave/.env" "REMNAWAVE_URL" "$(normalize_url "$ADMIN_DOMAIN_FINAL")"
fi

if [ -n "$SUB_DOMAIN_FINAL" ]; then
  upsert_env_key "/opt/remnawave/.env" "SUB_PUBLIC_DOMAIN" "$SUB_DOMAIN_FINAL"
  upsert_env_key "/opt/iris-remnawave/.env" "REMNAWAVE_SUB_URL" "$(normalize_url "$SUB_DOMAIN_FINAL")"
fi

if [ -n "$PUBLIC_HOST_FINAL" ]; then
  upsert_env_key "/opt/iris-remnawave/.env" "PUBLIC_HOST" "$PUBLIC_HOST_FINAL"
fi

if [ -n "$MTPROXY_HOST_FINAL" ]; then
  replace_toml_key "/opt/telemt/config.toml" "public_host" "$MTPROXY_HOST_FINAL"
  rewrite_mtproxy_url "/opt/iris_user/.env" "$MTPROXY_HOST_FINAL"
fi

if [ "$SKIP_START" = "1" ]; then
  log "Restore finished in file-only mode"
  log "Archive: ${ARCHIVE_PATH}"
  log "Restore dir: ${WORK_DIR}"
  log "Pre-restore snapshot: ${PRE_RESTORE_DIR}"
  exit 0
fi

if [ -f /opt/remnawave/docker-compose.yml ]; then
  log "Starting Remnawave database and Redis"
  (cd /opt/remnawave && docker compose up -d remnawave-db remnawave-redis)
  wait_for_container_healthy "remnawave-db" 50 3 || true

  if [ -f /opt/remnawave/remnawave_db_dump.sql ]; then
    DB_USER="$(read_env_value /opt/remnawave/.env POSTGRES_USER)"
    DB_NAME="$(read_env_value /opt/remnawave/.env POSTGRES_DB)"
    DB_PASS="$(read_env_value /opt/remnawave/.env POSTGRES_PASSWORD)"
    DB_USER="${DB_USER:-postgres}"
    DB_NAME="${DB_NAME:-postgres}"
    DB_PASS="${DB_PASS:-postgres}"
    log "Restoring Remnawave database dump"
    docker exec -e "PGPASSWORD=${DB_PASS}" remnawave-db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;" >/dev/null
    docker exec -i -e "PGPASSWORD=${DB_PASS}" remnawave-db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < /opt/remnawave/remnawave_db_dump.sql >/dev/null
  else
    warn "Remnawave DB dump is missing; panel will start without imported state"
  fi

  log "Starting Remnawave backend"
  (cd /opt/remnawave && docker compose up -d remnawave)
fi

if [ -f /opt/remnawave/subscription/docker-compose.yml ]; then
  log "Starting subscription page"
  (cd /opt/remnawave/subscription && docker compose up -d)
fi

if [ -f /opt/remnawave/caddy/docker-compose.yml ]; then
  log "Starting Caddy reverse proxy"
  (cd /opt/remnawave/caddy && docker compose up -d)
elif [ -f /opt/remnawave/nginx/docker-compose.yml ]; then
  log "Starting Nginx reverse proxy"
  (cd /opt/remnawave/nginx && docker compose up -d)
fi

if [ -f /opt/telemt/docker-compose.yml ]; then
  log "Starting MTProto"
  (cd /opt/telemt && docker compose up -d)
fi

if [ -f /opt/iris_user/docker-compose.yml ]; then
  log "Starting user bot"
  (cd /opt/iris_user && docker compose up -d)
fi

if [ -f /opt/remnanode/docker-compose.yml ]; then
  log "Starting local Remnawave Node"
  (cd /opt/remnanode && docker compose up -d)
fi

if [ -f /opt/iris-remnawave/docker-compose.yml ]; then
  log "Starting I.R.I.S. admin-layer"
  (cd /opt/iris-remnawave && docker compose up -d --build)
  if [ -f /opt/iris-remnawave/ops-agent/install.sh ]; then
    (cd /opt/iris-remnawave && bash ops-agent/install.sh) || warn "Local ops-agent reinstall failed"
  fi
fi

log "Restore finished successfully"
log "Archive: ${ARCHIVE_PATH}"
log "Restore dir: ${WORK_DIR}"
log "Pre-restore snapshot: ${PRE_RESTORE_DIR}"

cat <<EOF

Next checks:
1. Open the panel domain in a browser.
2. Open the subscription page.
3. Confirm Remnawave API answers.
4. Confirm MTProto accepts connections.
5. Confirm the user bot still works.
6. Reconnect I.R.I.S. if this host also carries the bot.

Artifacts created during restore:
- restore staging: ${WORK_DIR}
- pre-restore snapshot: ${PRE_RESTORE_DIR}
EOF
