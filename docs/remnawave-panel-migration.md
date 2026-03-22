# Remnawave Panel Migration Guide

This guide is focused on one thing:

- moving and restoring the `Remnawave` panel stack

It is intentionally centered on:

- `Remnawave`
- `subscription page`
- reverse proxy
- local `Remnawave Node`
- optional `I.R.I.S.` admin-layer

It is **not** a migration project for:

- `MTProto`
- `user bot`

Those services may exist on the same host, but they are treated here only as neighboring services that affect your port layout.

## 1. Fixed Workspace

All generated artifacts live under:

```text
/home/
```

That means:

- the migration archive is created in `/home/`
- the checksum file is created in `/home/`
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

## 2. Practical Port Layout

If panel services and a local node share one host, the most practical layout is:

- `443` — `Remnawave` panel
- `8443` — reserved for `MTProto` if it exists next to the panel
- `2222` — node API / control port
- `2053` — preferred public port for local node client configs

Why `2053` is recommended for local node configs:

- `443` is already occupied by the panel
- `8443` is better kept for `MTProto`
- `2222` is needed by the node itself
- `2053` usually remains the cleanest public port for client-facing node traffic

## 3. The Three Main Scripts

### Build a Migration Archive

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

What it does:

- scans the current host for the panel-side stack
- collects config files and related services
- dumps the `Remnawave` database
- writes a manifest and restore notes
- saves one archive and one checksum file into `/home/`

### Restore an Archive on a New Host

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

Default behavior:

- finds the newest `remnawave_migration_pack_*.tar.gz` in `/home/`
- extracts it under `/home/remnawave-migration-restore/`
- restores files into `/opt/...`
- starts the stack in the correct order

Useful overrides:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

File-only mode:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

### Bootstrap a Clean Host

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

This path is for a fresh server when you do not need the old runtime state.

## 4. What the Archive Collects

The archive is focused on the panel stack and may include:

- `/opt/remnawave/.env`
- `/opt/remnawave/docker-compose.yml`
- `/opt/remnawave/remnawave_db_dump.sql`
- `/opt/remnawave/nginx/*`
- `/opt/remnawave/caddy/*`
- `/opt/remnawave/subscription/*`
- `/opt/iris-remnawave/.env`
- `/opt/iris-remnawave/docker-compose.yml`
- `/opt/iris-remnawave/state/bot_users.db`
- `/opt/iris-remnawave/state/traffic_cache.json`
- `/opt/remnanode/*`
- `/opt/rnexus-site/*`
- `inventory/manifest.json`
- `inventory/docker_ps.txt`
- `inventory/services.txt`
- `inventory/restore_notes.txt`

The manifest stores:

- public host
- panel domain
- subscription domain
- `I.R.I.S.` git remote
- `I.R.I.S.` git commit

## 5. Beginner-Safe Real Migration Flow

### Step 1. Build the Archive on the Old Server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

After that, check `/home/`.

You should see:

```text
/home/remnawave_migration_pack_oldhost_20260323_120000.tar.gz
/home/remnawave_migration_pack_oldhost_20260323_120000.tar.gz.sha256
```

### Step 2. Copy the Files to the New Server

Example:

```bash
scp /home/remnawave_migration_pack_*.tar.gz root@NEW_SERVER_IP:/home/
scp /home/remnawave_migration_pack_*.tar.gz.sha256 root@NEW_SERVER_IP:/home/
```

### Step 3. Prepare the New Server

The new server should have:

- Linux
- Docker Engine
- Docker Compose plugin
- enough RAM and disk
- open public ports for the panel stack

### Step 4. Run Restore on the New Server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/restore-remnawave-migration-pack.sh
```

### Step 5. If the New Host Has a New IP or New Domains

Use restore with overrides:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

## 6. What Restore Changes for You

If you pass overrides, the restore script can automatically update:

### `I.R.I.S.`

- `/opt/iris-remnawave/.env`
  - `PUBLIC_HOST`
  - `REMNAWAVE_URL`
  - `REMNAWAVE_SUB_URL`

### `Remnawave`

- `/opt/remnawave/.env`
  - `FRONT_END_DOMAIN`
  - `SUB_PUBLIC_DOMAIN`

### `subscription page`

- `/opt/remnawave/subscription/.env`
  - `REMNAWAVE_PANEL_URL`

## 7. Startup Order Used by Restore

The restore script starts the stack in this order:

1. `remnawave-db` and `remnawave-redis`
2. SQL import into `Remnawave`
3. `Remnawave` backend
4. bundled `subscription page`
5. reverse proxy (`Caddy` first, otherwise `nginx`)
6. local `Remnawave Node`
7. `I.R.I.S.` and local `ops-agent`

This order is one of the main reasons to use the script instead of restoring everything manually.

## 8. Clean Bootstrap Path

If you only want a fresh official-style base:

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

If you already have an API token for the bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

What bootstrap does:

- installs Docker if needed
- downloads official backend files
- downloads official bundled subscription page files
- generates `.env` files
- prepares a simple `Caddy` reverse proxy
- starts the base stack

## 9. Smoke Checks After Restore

After restore, check in this order:

### Public Front

- the panel opens in a browser
- the subscription page opens in a browser

### API

- the `Remnawave` API responds

### Local Node

- the local node is alive, if it belonged to the old host
- its control/API port `2222` answers correctly
- client-facing configs use `2053` if that is your chosen production layout

### Admin Layer

- `I.R.I.S.` responds in Telegram, if it was part of the old host

## 10. Important Neighbor Notes

`MTProto` and `user bot` are intentionally outside this migration toolkit.

Still, if they live on the same machine, do not forget:

- keep `8443` clean for `MTProto`
- do not let `MTProto` conflict with `443` and `2222`
- re-check user-bot endpoints manually after the move

## 11. Safety Notes

- the archive contains secrets, tokens, and private keys
- treat it as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging longer than needed
- keep the pre-restore snapshot until the move is fully verified

## 12. When to Choose Which Path

Choose `build + restore` if:

- you want the new server to be as close as possible to the old one
- you need the current production database
- you want the current panel stack and local node

Choose `bootstrap` if:

- you want a fresh clean host
- you do not need the old production state
- you want to rebuild from a clean official base
