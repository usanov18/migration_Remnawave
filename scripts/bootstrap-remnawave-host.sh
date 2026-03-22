#!/usr/bin/env bash
set -euo pipefail

PANEL_DOMAIN=""
SUBSCRIPTION_DOMAIN=""
SUBSCRIPTION_API_TOKEN=""
ACME_EMAIL=""
SKIP_DOCKER_INSTALL="0"
SKIP_START="0"
ORIGINAL_ARGS=("$@")

PANEL_DIR="/opt/remnawave"
SUBSCRIPTION_DIR="${PANEL_DIR}/subscription"
CADDY_DIR="${PANEL_DIR}/caddy"

BACKEND_COMPOSE_URL="https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml"
BACKEND_ENV_URL="https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/.env.sample"
SUBSCRIPTION_COMPOSE_URL="https://raw.githubusercontent.com/remnawave/subscription-page/refs/heads/main/docker-compose-prod.yml"
SUBSCRIPTION_ENV_URL="https://raw.githubusercontent.com/remnawave/subscription-page/refs/heads/main/.env.sample"

log() { echo "INFO: $*"; }
warn() { echo "WARN: $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/bootstrap-remnawave-host.sh [options]

Options:
  --panel-domain DOMAIN          Public panel domain, for example admin.example.com
  --subscription-domain DOMAIN   Public subscription domain, for example sub.example.com
  --subscription-api-token TOK   Remnawave API token for bundled subscription page
  --acme-email EMAIL             Optional ACME contact email for Caddy
  --skip-docker-install          Assume Docker is already installed
  --skip-start                   Write files only, do not start services
  --help                         Show this help
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

prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local answer=""
  while [ -z "$answer" ]; do
    read -r -p "${prompt_text}: " answer
  done
  printf -v "$var_name" '%s' "$answer"
}

prompt_optional() {
  local var_name="$1"
  local prompt_text="$2"
  local answer=""
  read -r -p "${prompt_text}: " answer
  printf -v "$var_name" '%s' "$answer"
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

derive_subscription_domain() {
  python3 - "$1" <<'PY'
import sys
value = (sys.argv[1] or "").strip()
if not value:
    print("")
    raise SystemExit
if value.startswith("admin."):
    print("sub." + value[len("admin."):])
else:
    print("sub." + value)
PY
}

gen_secret() {
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
}

gen_hex_secret() {
  python3 -c "import secrets; print(secrets.token_hex(32))"
}

download_file() {
  local url="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  curl -fsSL "$url" -o "$dst"
}

install_docker_stack() {
  require_cmd curl
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return 0
  fi
  log "Installing Docker Engine and Compose plugin"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release git
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --panel-domain)
      PANEL_DOMAIN="${2:-}"
      shift 2
      ;;
    --subscription-domain)
      SUBSCRIPTION_DOMAIN="${2:-}"
      shift 2
      ;;
    --subscription-api-token)
      SUBSCRIPTION_API_TOKEN="${2:-}"
      shift 2
      ;;
    --acme-email)
      ACME_EMAIL="${2:-}"
      shift 2
      ;;
    --skip-docker-install)
      SKIP_DOCKER_INSTALL="1"
      shift
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

if [ "$SKIP_DOCKER_INSTALL" != "1" ]; then
  install_docker_stack
fi

require_cmd docker
require_cmd curl
require_cmd python3

docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is required"

[ -n "$PANEL_DOMAIN" ] || prompt_required PANEL_DOMAIN "Panel domain (for example admin.example.com)"
PANEL_DOMAIN="$(normalize_domain "$PANEL_DOMAIN")"

if [ -z "$SUBSCRIPTION_DOMAIN" ]; then
  SUBSCRIPTION_DOMAIN="$(derive_subscription_domain "$PANEL_DOMAIN")"
fi
SUBSCRIPTION_DOMAIN="$(normalize_domain "$SUBSCRIPTION_DOMAIN")"

if [ -z "$ACME_EMAIL" ]; then
  prompt_optional ACME_EMAIL "Optional ACME email for Caddy (can be left empty)"
fi

mkdir -p "$PANEL_DIR" "$SUBSCRIPTION_DIR" "$CADDY_DIR"

log "Downloading official Remnawave panel files"
download_file "$BACKEND_COMPOSE_URL" "${PANEL_DIR}/docker-compose.yml"
download_file "$BACKEND_ENV_URL" "${PANEL_DIR}/.env.sample"

log "Downloading official bundled subscription page files"
download_file "$SUBSCRIPTION_COMPOSE_URL" "${SUBSCRIPTION_DIR}/docker-compose.yml"
download_file "$SUBSCRIPTION_ENV_URL" "${SUBSCRIPTION_DIR}/.env.sample"

POSTGRES_USER="postgres"
POSTGRES_DB="postgres"
POSTGRES_PASSWORD="$(gen_secret)"
JWT_AUTH_SECRET="$(gen_hex_secret)"
JWT_API_TOKENS_SECRET="$(gen_hex_secret)"
METRICS_USER="metrics"
METRICS_PASS="$(gen_secret)"
PANEL_URL="$(normalize_url "$PANEL_DOMAIN")"

cat > "${PANEL_DIR}/.env" <<EOF
APP_PORT=3000
METRICS_PORT=3001
API_INSTANCES=1
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@remnawave-db:5432/${POSTGRES_DB}
REDIS_HOST=remnawave-redis
REDIS_PORT=6379
JWT_AUTH_SECRET=${JWT_AUTH_SECRET}
JWT_API_TOKENS_SECRET=${JWT_API_TOKENS_SECRET}
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=
TELEGRAM_NOTIFY_USERS_CHAT_ID=
TELEGRAM_NOTIFY_NODES_CHAT_ID=
TELEGRAM_NOTIFY_CRM_CHAT_ID=
TELEGRAM_NOTIFY_USERS_THREAD_ID=
TELEGRAM_NOTIFY_NODES_THREAD_ID=
TELEGRAM_NOTIFY_CRM_THREAD_ID=
FRONT_END_DOMAIN=${PANEL_DOMAIN}
SUB_PUBLIC_DOMAIN=${SUBSCRIPTION_DOMAIN}
SWAGGER_PATH=/docs
SCALAR_PATH=/scalar
IS_DOCS_ENABLED=false
METRICS_USER=${METRICS_USER}
METRICS_PASS=${METRICS_PASS}
WEBHOOK_ENABLED=false
WEBHOOK_URL=
WEBHOOK_SECRET_HEADER=
BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60,80]
NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED=false
NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS=[6,24,48]
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
EOF

SUBSCRIPTION_READY="1"
if [ -z "$SUBSCRIPTION_API_TOKEN" ]; then
  SUBSCRIPTION_READY="0"
  warn "Subscription API token was not provided. Files will be created, but the subscription page will not be started yet."
fi

cat > "${SUBSCRIPTION_DIR}/.env" <<EOF
APP_PORT=3010
REMNAWAVE_PANEL_URL=${PANEL_URL}
REMNAWAVE_API_TOKEN=${SUBSCRIPTION_API_TOKEN:-CHANGE_ME}
CUSTOM_SUB_PREFIX=
CADDY_AUTH_API_TOKEN=
CLOUDFLARE_ZERO_TRUST_CLIENT_ID=
CLOUDFLARE_ZERO_TRUST_CLIENT_SECRET=
MARZBAN_LEGACY_LINK_ENABLED=false
MARZBAN_LEGACY_SECRET_KEY=
MARZBAN_LEGACY_SUBSCRIPTION_VALID_FROM=
EOF

cat > "${CADDY_DIR}/docker-compose.yml" <<'EOF'
services:
  remnawave-caddy:
    image: caddy:2
    container_name: remnawave-caddy
    restart: always
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF

{
  if [ -n "$ACME_EMAIL" ]; then
    echo "{"
    echo "  email ${ACME_EMAIL}"
    echo "}"
    echo
  fi
  echo "${PANEL_DOMAIN} {"
  echo "  encode zstd gzip"
  echo "  reverse_proxy 127.0.0.1:3000"
  echo "}"
  echo
  echo "${SUBSCRIPTION_DOMAIN} {"
  echo "  encode zstd gzip"
  echo "  reverse_proxy 127.0.0.1:3010"
  echo "}"
} > "${CADDY_DIR}/Caddyfile"

if [ "$SKIP_START" = "1" ]; then
  log "Bootstrap files were prepared only"
  log "Panel dir: ${PANEL_DIR}"
  log "Subscription dir: ${SUBSCRIPTION_DIR}"
  log "Caddy dir: ${CADDY_DIR}"
  exit 0
fi

log "Starting Remnawave core stack"
(cd "$PANEL_DIR" && docker compose up -d)

if [ "$SUBSCRIPTION_READY" = "1" ]; then
  log "Starting bundled subscription page"
  (cd "$SUBSCRIPTION_DIR" && docker compose up -d)
else
  warn "Skipping subscription page start until REMNAWAVE_API_TOKEN is filled in ${SUBSCRIPTION_DIR}/.env"
fi

log "Starting Caddy"
(cd "$CADDY_DIR" && docker compose up -d)

cat <<EOF

Bootstrap complete.

Panel URL:
- ${PANEL_URL}

Subscription URL:
- https://${SUBSCRIPTION_DOMAIN}

Panel files:
- ${PANEL_DIR}

Next recommended steps:
1. Open ${PANEL_URL} and complete Remnawave onboarding.
2. If you skipped subscription token, create an API token in Remnawave Settings -> API Tokens and place it into ${SUBSCRIPTION_DIR}/.env.
3. Start the subscription page if needed:
   cd ${SUBSCRIPTION_DIR} && docker compose up -d
4. If you use a local Remnawave Node on the same host, keep this layout in mind:
   - 443 for the panel
   - 2222 for node API/control
   - 2053 as the preferred public port for node client configs
   - 8443 reserved for MTProto if it exists nearby
5. If you use I.R.I.S., deploy it separately only after the panel is healthy:
   - https://github.com/usanov18/iris-remnawave
EOF
