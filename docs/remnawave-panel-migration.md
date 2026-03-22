# Remnawave Panel Migration Guide

This guide is written for the current production pattern where one main host carries:

- `Remnawave Panel`
- `PostgreSQL + Redis`
- bundled `subscription page`
- reverse proxy (`nginx` or `Caddy`)
- `I.R.I.S.` as the admin layer
- local `ops-agent` and node registrar
- `MTProto`
- `user bot`
- optional local `Remnawave Node`

The goal is simple:

- make migration predictable
- keep paths fixed
- remove guesswork during restore

## Fixed Migration Workspace

The host-side migration scripts use one fixed operator workspace:

```text
/home/alt441/
```

That means:

- migration archives are built into `/home/alt441/`
- restore staging also happens under `/home/alt441/`
- pre-restore safety snapshots are stored there too

## Scripts

### Build a Migration Pack

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

What it does:

- scans the current host for the panel-side stack
- dumps the Remnawave database
- collects panel-side config and related services
- writes a manifest and restore notes
- saves one archive and one checksum file into `/home/alt441/`

### Restore a Migration Pack

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

Default behavior:

- finds the newest `remnawave_migration_pack_*.tar.gz` in `/home/alt441/`
- extracts it under `/home/alt441/remnawave-migration-restore/`
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

## What the Migration Pack Collects

The current migration pack is designed around the real host layout and includes:

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

- current public host
- panel domain
- subscription domain
- MTProto public host
- `I.R.I.S.` git remote
- `I.R.I.S.` git commit

That allows restore to bring back the same bot-side code revision if the repo is not already present on the target host.

## What Changes During a Move

### If Only the Host Changes

Usually the most important adjustments are:

- `/opt/iris-remnawave/.env`
  - `PUBLIC_HOST`
  - `REMNAWAVE_URL`
  - `REMNAWAVE_SUB_URL`
- `/opt/remnawave/.env`
  - `FRONT_END_DOMAIN`
  - `SUB_PUBLIC_DOMAIN`
- `/opt/remnawave/subscription/.env`
  - `REMNAWAVE_PANEL_URL`
- `/opt/telemt/config.toml`
  - `public_host`
- `/opt/iris_user/.env`
  - `MTPROXY_URL`

The restore script can update these values automatically through flags.

### If the MTProto IP Changes

This is a special case.

MTProto and the user bot are usually tied to the public MTProto host:

- `telemt/config.toml -> public_host`
- `iris_user/.env -> MTPROXY_URL`

If the MTProto public IP changes:

- old `tg://proxy` links become stale
- the user bot must be updated to hand out the new endpoint

### If Domains Change

Domains affect three layers:

- Remnawave backend `.env`
- subscription page `.env`
- reverse proxy config (`nginx` or `Caddy`)

The restore script updates the main env files, but you should still smoke-test the public frontends after the move.

## Recommended New Host Baseline

For a comfortable move target, use at least:

- Ubuntu 22.04+ or a similar Linux host
- Docker Engine
- Docker Compose plugin
- at least `4 GB RAM`
- open ports:
  - `80/tcp`
  - `443/tcp`
  - `8443/tcp` if MTProto is on the same host
  - `9910/tcp` for local `ops-agent`
  - `9921/tcp` if you use node auto-registration

Recommended before migration:

- reduce DNS TTL for the panel and subscription domains
- make sure SSH and sudo are ready
- decide whether the new host will also carry:
  - MTProto
  - user bot
  - local node
  - static site assets

## Recommended Restore Order

### 1. Put the Archive on the New Host

Copy the migration archive into:

```text
/home/alt441/
```

### 2. Run the Restore Script

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

### 3. What the Script Starts

The restore script brings the stack back in this order:

1. `remnawave-db` and `remnawave-redis`
2. Remnawave SQL import
3. `remnawave`
4. bundled subscription page
5. reverse proxy (`Caddy` first, otherwise `nginx`)
6. `telemt`
7. `user bot`
8. local `remnanode`
9. `I.R.I.S.` and local `ops-agent`

### 4. Smoke Checks After Restore

Check:

- panel frontend opens
- subscription page opens
- Remnawave API answers
- `I.R.I.S.` answers in Telegram
- MTProto accepts connections
- user bot still serves clients
- the operations screen in the bot sees the host correctly

## When to Use Clean Bootstrap Instead

If you do not want an exact copy and only need a clean official-style base, use:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh
```

This is the right choice when:

- you are building a fresh panel host from scratch
- you do not need current production DB state
- you want a clean Remnawave + Caddy base before adding the bot

Use migration restore instead when you want the new host to look like the old one.

## Safety Notes

- migration archives contain secrets, tokens, and private keys
- treat them as sensitive secrets
- keep both the archive and the checksum file
- do not leave unpacked restore staging on random hosts longer than needed
