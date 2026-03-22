# migration_Remnawave

`migration_Remnawave` is a focused operator toolkit for moving, restoring, and fast-bootstrapping a Remnawave installation.

This repository is intentionally separate from the bot project.

Use it when your task is one of these:

- move a production Remnawave panel to a new VPS
- collect the current panel-side stack into a portable archive
- restore the panel-side stack onto another host
- deploy a clean Remnawave host on a fresh VPS with as little manual work as possible

If your task is "run the Telegram admin bot", use the separate repository:

- [iris-remnawave](https://github.com/usanov18/iris-remnawave)

## What This Repository Contains

- host-side migration pack builder
- host-side migration restore script
- clean Remnawave host bootstrap script
- structured migration guide
- fixed operator workspace at `/home/alt441/`

## Why This Exists

The main pain during a move is rarely "get the code".

The real pain is:

- remembering what exactly must be archived
- knowing which secrets and env files matter
- restoring services in the right order
- not forgetting panel-adjacent pieces like subscription page, reverse proxy, MTProto, user bot, or local node

This toolkit removes that guesswork and makes the move repeatable.

## Official Remnawave References

This toolkit is built around the official Remnawave installation model:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

Bundled subscription page files are also taken from the official upstream subscription-page repository.

## Repository Layout

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) - collect the current host into one migration archive
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) - restore the archive onto a new host
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) - deploy a clean Remnawave panel host from scratch
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) - deeper migration and restore guide

## Fixed Operator Workspace

All migration archives and restore staging are pinned to:

```text
/home/alt441/
```

This keeps the process deterministic.

It means:

- build output goes to `/home/alt441/`
- restore staging also happens under `/home/alt441/`
- pre-restore snapshots are saved there too

## The Three Main Paths

### 1. Build a Migration Pack from a Running Host

Use this on the current production host:

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

What it collects:

- `/opt/remnawave`
- `/opt/remnawave/nginx`
- `/opt/remnawave/caddy`
- `/opt/remnawave/subscription`
- `/opt/iris-remnawave`
- `/opt/telemt`
- `/opt/iris_user`
- `/opt/remnanode`
- `/opt/rnexus-site`
- Remnawave SQL dump
- manifest and restore notes

What you get:

- one `tar.gz` archive in `/home/alt441/`
- one checksum file next to it

### 2. Restore the Same Environment on a New Host

Put the archive onto the new server in:

```text
/home/alt441/
```

Then run:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

The script:

- finds the newest migration archive
- extracts it into restore staging
- restores files into `/opt/...`
- imports the Remnawave database
- starts services in the correct order

Override mode is available when IP or domains change:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

File-only mode is also available:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

### 3. Bootstrap a Clean Remnawave Host

Use this when you are not restoring old state and just want a fresh, official-style deployment:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

What it does:

- downloads the official Remnawave backend compose
- downloads the official bundled subscription-page compose
- generates secure `.env` values
- builds a simple Caddy reverse proxy config
- starts PostgreSQL, Redis, Remnawave, optional subscription page, and Caddy

If you already have an API token for the bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

## Which Path Should You Choose

Choose `build + restore` when:

- you want the new server to look like the old one
- you need current DB state
- you need current secrets
- you want MTProto, user bot, local node, and the bot-side layer preserved

Choose `bootstrap` when:

- you want a fresh host
- you do not need current production state
- you want a clean Remnawave base and will add the rest later

## Fresh VPS Test Plan

If your goal is "I want to take a clean VPS and test the whole flow", this is the simplest path.

### Option A. Test Fresh Bootstrap

1. Prepare a clean VPS with Ubuntu.
2. Clone this repository.
3. Run:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

4. Open the panel domain.
5. Complete Remnawave onboarding.
6. Optionally add `I.R.I.S.` from the bot repository afterward.

### Option B. Test Real Migration

1. Build a migration pack on the old host.
2. Copy the archive to the clean VPS under `/home/alt441/`.
3. Clone this repository on the clean VPS.
4. Run:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

5. Smoke-test panel, subscription page, MTProto, user bot, and local node.

## Recommended Post-Restore Smoke Checks

After a restore, confirm:

- panel frontend opens
- subscription page opens
- Remnawave API responds
- MTProto accepts connections
- user bot still serves users
- local node is up if it was part of the old host
- `I.R.I.S.` reconnects if bot-side files were included in the archive

## Safety Notes

- migration archives contain secrets, tokens, and private keys
- treat them as sensitive secrets
- keep the checksum file together with the archive
- do not leave unpacked restore staging on disposable hosts longer than needed

## Related Project

Telegram admin-layer and node control live here:

- [iris-remnawave](https://github.com/usanov18/iris-remnawave)
