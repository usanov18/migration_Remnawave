# Remnawave Panel Migration Guide

This guide is written for the common real-world layout where one main host carries:

- `Remnawave Panel`
- `PostgreSQL + Redis`
- bundled `subscription page`
- reverse proxy (`nginx` or `Caddy`)
- `MTProto`
- `user bot`
- optional local `Remnawave Node`
- optional `I.R.I.S.` admin-layer

The goal of this guide is simple:

- make migration predictable
- keep all generated artifacts in one obvious place
- give a beginner-safe order of actions

## 1. Fixed Workspace

All generated migration artifacts are kept under:

```text
/home/
```

In practice, that means:

- the migration archive appears in `/home/`
- the checksum file appears in `/home/`
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore safety snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

You do not need to edit the scripts to change this path.

## 2. The Three Main Scripts

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
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
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

## 3. What the Archive Collects

The current migration archive is designed around the real production layout and may include:

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
- `/opt/telemt/*`
- `/opt/iris_user/.env`
- `/opt/iris_user/docker-compose.yml`
- `/opt/iris_user/data/bot.db`
- `/opt/remnanode/*`
- `/opt/rnexus-site/*`
- `inventory/manifest.json`
- `inventory/docker_ps.txt`
- `inventory/services.txt`
- `inventory/restore_notes.txt`

The manifest also stores:

- public host
- panel domain
- subscription domain
- MTProto public host
- `I.R.I.S.` git remote
- `I.R.I.S.` git commit

That allows restore to bring back the same bot-side revision if the bot was part of the old host.

## 4. Easiest Real Migration Flow

This is the safest beginner flow.

### Step 1. Build the Archive on the Old Server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

After the script finishes, look inside `/home/`.

You should see something like:

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
- enough RAM and disk for your stack
- open ports for your public services

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
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

## 5. What Restore Changes for You

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

### `MTProto`

- `/opt/telemt/config.toml`
  - `public_host`

### `user bot`

- `/opt/iris_user/.env`
  - `MTPROXY_URL`

## 6. Startup Order Used by the Restore Script

The restore script brings the stack back in this order:

1. `remnawave-db` and `remnawave-redis`
2. SQL import into `Remnawave`
3. `Remnawave` backend
4. bundled subscription page
5. reverse proxy (`Caddy` first, otherwise `nginx`)
6. `MTProto`
7. `user bot`
8. local `Remnawave Node`
9. `I.R.I.S.` and local `ops-agent`

This order is one of the main reasons to use the script instead of restoring everything manually.

## 7. Clean Bootstrap Path

If you do not want to move the old state and only want a clean official-style base:

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

## 8. Smoke Checks After Restore

After restore, check these items in order:

### Public Front

- the panel opens in a browser
- the subscription page opens in a browser

### API

- the `Remnawave` API responds

### Supporting Services

- `MTProto` accepts connections
- the user bot still works
- the local node is alive, if it belonged to the old host

### Admin Layer

- `I.R.I.S.` responds in Telegram, if it was part of the old server

## 9. Safety Notes

- the archive contains secrets, tokens, and private keys
- treat it as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging on random servers longer than needed
- keep the pre-restore snapshot until you are sure the move is complete

## 10. When to Choose Which Path

Choose `build + restore` if:

- you want the new server to be as close as possible to the old one
- you need the current production database
- you want to preserve the current supporting services

Choose `bootstrap` if:

- you want a fresh clean host
- you do not need the old production state
- you want to rebuild carefully from an official base
