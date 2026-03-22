# Remnawave Panel Migration Guide

This guide is intentionally centered around:

- `Remnawave Panel`
- `PostgreSQL / Redis`
- `subscription page`
- reverse proxy
- local `Remnawave Node`

It does **not** migrate:

- `I.R.I.S.`
- `MTProto`
- `user bot`

Those are treated as adjacent services and should be deployed or verified separately after the panel stack is healthy.

If you use `I.R.I.S.`, deploy it later from:

- [iris-remnawave](https://github.com/usanov18/iris-remnawave)

## 1. Fixed Workspace

All generated migration artifacts live under:

```text
/home/
```

That means:

- the migration archive is created in `/home/`
- the checksum file is created in `/home/`
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

## 2. Recommended Port Layout

If the panel and the local node share one host, this is the practical layout:

- `443` — `Remnawave` panel
- `8443` — reserve for `MTProto` if it exists next to the panel
- `2222` — node API / control port
- `2053` — preferred public port for local node client configs

Why `2053` is recommended:

- `443` is already occupied by the panel
- `8443` is better left for `MTProto`
- `2222` is needed by the node itself
- `2053` is usually the cleanest remaining public port for client-facing node traffic

## 3. Main Scripts

### Build a Migration Archive

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

What it does:

- scans the current host for panel-side services
- collects the panel config and related files
- exports a `Remnawave` SQL dump
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
- starts the panel stack in the correct order

Useful overrides:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

File-only mode:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

Use file-only mode if you want to:

- review files before launching containers
- edit `.env` manually
- verify proxy and node configs first

### Bootstrap a Clean Host

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

This is **not** migration.  
It is the clean-host path for a new `Remnawave` installation when you do not need the old runtime state.

## 4. What the Archive Collects

The archive is focused only on the panel stack and may include:

- `/opt/remnawave/.env`
- `/opt/remnawave/docker-compose.yml`
- `/opt/remnawave/remnawave_db_dump.sql`
- `/opt/remnawave/nginx/*`
- `/opt/remnawave/caddy/*`
- `/opt/remnawave/subscription/*`
- `/opt/remnanode/*`
- `/opt/rnexus-site/*`
- `inventory/manifest.json`
- `inventory/docker_ps.txt`
- `inventory/services.txt`
- `inventory/restore_notes.txt`

## 5. Beginner-Safe Real Migration Flow

### Step 1. Build the Archive on the Old Server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

After that, look inside `/home/`.

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

### Step 5. If the New Host Uses New Domains

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

### Step 6. If You Want to Inspect Before Start

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

This mode is useful when you want to:

- verify restored files in `/opt/`
- edit `.env`
- compare old and new domains before startup

## 6. What Restore Changes For You

If you pass overrides, the restore script can update:

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

This startup order is one of the main reasons to use the script instead of doing everything by hand.

## 8. Clean Bootstrap Path

If you want a fresh official-style panel base:

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

- the local node is alive if it belonged to the old host
- its control/API port `2222` answers correctly
- client-facing configs use `2053` if that is your production layout

## 10. What to Do After the Panel Is Healthy

After the panel stack is stable, handle adjacent services separately:

- deploy `I.R.I.S.` from [iris-remnawave](https://github.com/usanov18/iris-remnawave) only after the panel is healthy
- verify `MTProto` manually and keep `8443` free for it if that is your layout
- verify `user bot` manually

This separation is intentional and keeps the migration path clean.

## 11. Safety Notes

- the archive contains secrets, tokens, and private keys
- treat it as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging longer than needed
- keep the pre-restore snapshot until the move is fully verified

## 12. When to Choose Which Path

Choose `build + restore` if:

- you want the new server to be as close as possible to the old panel host
- you need the current production database
- you want the current panel stack and local node

Choose `bootstrap` if:

- you want a fresh clean host
- you do not need the old production state
- you want to rebuild from a clean official base
