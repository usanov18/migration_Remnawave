# migration_Remnawave

> 🚚 Remnawave Migration & Bootstrap Toolkit  
> A focused operator project for moving, restoring, and rebuilding a Remnawave host without guesswork.

[🇷🇺 Русская версия](#-русская-версия) • [🇬🇧 English Version](#-english-version)

---

## 🇷🇺 Русская версия

[Switch to English](#-english-version)

### ✨ Что это

`migration_Remnawave` — это отдельный проект для:

- 🚚 переезда `Remnawave Panel` на новый VPS
- 📦 сборки migration archive со старого сервера
- ♻️ восстановления панели на новом сервере
- 🏗️ быстрого bootstrap чистого `Remnawave` host

Это **не проект для MTProto** и **не проект для user bot**.  
Они могут жить рядом на том же сервере, но этот toolkit сознательно сфокусирован на:

- `Remnawave`
- `subscription page`
- reverse proxy
- локальной `Remnawave Node`
- `I.R.I.S.` как admin-layer, если он живет на том же хосте

Если нужен Telegram admin-layer:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 🎯 Для кого

Репозиторий собран так, чтобы им смог воспользоваться даже неподготовленный оператор.

Вам не нужно помнить:

- какие папки реально критичны для панели
- в каком порядке поднимать сервисы
- где должен лежать archive
- какие домены и env нужно проверить после restore

Скрипты и документация закрывают это за вас.

### 📚 На чем основано решение

Toolkit собран вокруг официальной модели `Remnawave`:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

### 🧰 Что лежит в репозитории

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — собрать archive со старого сервера
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — развернуть archive на новом сервере
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — поднять чистый Remnawave host
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — подробный guide

### 📍 Фиксированный workspace

Все build/restore артефакты живут здесь:

```text
/home/
```

Это значит:

- archive складывается в `/home/`
- checksum лежит рядом в `/home/`
- restore staging живет в `/home/remnawave-migration-restore/`
- pre-restore snapshot живет в `/home/pre-restore-snapshot_<timestamp>/`

### 🧭 Базовая схема портов

Если панель и локальная нода живут на одном хосте, удобно держать такую схему:

- `443` — панель `Remnawave`
- `8443` — оставить под `MTProto`, если он соседний сервис на этом же сервере
- `2222` — API / control порт ноды
- `2053` — предпочтительный внешний порт для конфигов локальной ноды

Почему `2053`:

- `443` уже нужен панели
- `8443` лучше оставить под `MTProto`
- `2222` нужен самой ноде как служебный порт
- `2053` обычно остается самым удобным и чистым вариантом для клиентских node-конфигов

### 🚀 Самый простой сценарий для новичка

#### Вариант A. Перевезти текущую панель как есть

#### 1. На старом сервере

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

После этого в `/home/` появятся:

- `remnawave_migration_pack_<host>_<timestamp>.tar.gz`
- `remnawave_migration_pack_<host>_<timestamp>.tar.gz.sha256`

#### 2. Скопировать archive на новый сервер

```bash
scp /home/remnawave_migration_pack_*.tar.gz root@NEW_SERVER_IP:/home/
scp /home/remnawave_migration_pack_*.tar.gz.sha256 root@NEW_SERVER_IP:/home/
```

#### 3. На новом сервере

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/restore-remnawave-migration-pack.sh
```

Скрипт сам:

- найдет свежий archive в `/home/`
- распакует его
- разложит файлы в `/opt/...`
- импортирует базу `Remnawave`
- поднимет сервисы в правильном порядке

#### 4. Если меняются IP или домены

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

#### 5. Если сначала нужен сухой прогон

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

### 🏗️ Вариант B. Поднять чистый Remnawave host

Если старый state не нужен:

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

Если уже есть API token для bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

### 🧠 Что делает каждый скрипт

#### `build-remnawave-migration-pack.sh`

Собирает archive в `/home/`.

В archive входят:

- `Remnawave`
- `subscription page`
- reverse proxy (`nginx` / `Caddy`)
- локальная `Remnawave Node`
- `I.R.I.S.`, если он часть того же хоста
- SQL dump
- manifest и restore notes

#### `restore-remnawave-migration-pack.sh`

Берет archive из `/home/` и восстанавливает стек.

Порядок запуска:

1. база и Redis
2. импорт SQL
3. backend `Remnawave`
4. `subscription page`
5. reverse proxy
6. локальная node
7. `I.R.I.S.`, если была частью архива

#### `bootstrap-remnawave-host.sh`

Чистый fresh-install путь:

- ставит Docker при необходимости
- качает официальный backend compose
- качает официальный bundled subscription page compose
- генерирует `.env`
- поднимает базовый стек

### ✅ Что проверить после restore

- панель открывается
- открывается subscription page
- отвечает `Remnawave API`
- локальная node жива, если она была частью старого хоста
- `I.R.I.S.` снова отвечает, если он был частью старого хоста

### 📌 Что важно помнить про соседние сервисы

`MTProto` и `user bot` не входят в migration toolkit этого проекта.

Но если они живут рядом на том же сервере, не забудьте руками проверить:

- что `8443` не занят чем-то лишним
- что `MTProto` не конфликтует с портами панели и ноды
- что user bot по-прежнему смотрит на правильные panel/subscription/mtproxy endpoints

### 🔐 Важно

- archive содержит секреты, токены и private keys
- храните его как чувствительный секрет
- checksum лучше хранить рядом
- не держите restore staging дольше нужного

### 📖 Дальше

Если нужен более подробный operator guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)

---

## 🇬🇧 English Version

[Перейти к русской версии](#-русская-версия)

### ✨ What This Is

`migration_Remnawave` is a dedicated project for:

- 🚚 moving a live `Remnawave Panel` to a new VPS
- 📦 building a migration archive from the old server
- ♻️ restoring the panel stack on a new server
- 🏗️ bootstrapping a clean `Remnawave` host

This is **not an MTProto project** and **not a user-bot project**.  
Those services may live next to the panel on the same host, but this toolkit is intentionally focused on:

- `Remnawave`
- `subscription page`
- reverse proxy
- local `Remnawave Node`
- `I.R.I.S.` as an admin-layer if it lives on the same host

If you need the Telegram admin-layer:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 🎯 Who This Is For

This repository is designed so even a less experienced operator can follow it.

You do not need to remember:

- which folders are actually critical for the panel
- which services should start first
- where the archive should live
- which domains and env values must be checked after restore

The scripts and docs handle that structure for you.

### 📚 What It Is Based On

The toolkit follows the official `Remnawave` model:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

### 🧰 What Lives in This Repository

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — build an archive from the old host
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — restore that archive on a new host
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — bootstrap a clean Remnawave host
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — detailed guide

### 📍 Fixed Workspace

All build/restore artifacts live here:

```text
/home/
```

That means:

- the archive is written into `/home/`
- the checksum file is stored next to it
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

### 🧭 Base Port Layout

If the panel and a local node share the same host, this is a practical layout:

- `443` — `Remnawave` panel
- `8443` — keep reserved for `MTProto` if it is a neighboring service on the same host
- `2222` — node API / control port
- `2053` — preferred external port for local node client configs

Why `2053`:

- `443` is already needed by the panel
- `8443` is best kept for `MTProto`
- `2222` is needed by the node itself
- `2053` is usually the cleanest remaining public port for client-facing node configs

### 🚀 Easiest Beginner Path

#### Option A. Move the current panel as-is

#### 1. On the old server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

After that, `/home/` will contain:

- `remnawave_migration_pack_<host>_<timestamp>.tar.gz`
- `remnawave_migration_pack_<host>_<timestamp>.tar.gz.sha256`

#### 2. Copy the archive to the new server

```bash
scp /home/remnawave_migration_pack_*.tar.gz root@NEW_SERVER_IP:/home/
scp /home/remnawave_migration_pack_*.tar.gz.sha256 root@NEW_SERVER_IP:/home/
```

#### 3. On the new server

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/restore-remnawave-migration-pack.sh
```

The script will:

- find the newest archive in `/home/`
- extract it
- restore files into `/opt/...`
- import the `Remnawave` database
- start services in the correct order

#### 4. If IP or domains change

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

#### 5. If you want a dry run first

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

### 🏗️ Option B. Bootstrap a clean Remnawave host

If you do not need the old state:

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

### 🧠 What Each Script Does

#### `build-remnawave-migration-pack.sh`

Builds an archive into `/home/`.

The archive contains:

- `Remnawave`
- `subscription page`
- reverse proxy (`nginx` / `Caddy`)
- local `Remnawave Node`
- `I.R.I.S.`, if it is part of the same host
- SQL dump
- manifest and restore notes

#### `restore-remnawave-migration-pack.sh`

Takes the archive from `/home/` and restores the stack.

Startup order:

1. database and Redis
2. SQL import
3. `Remnawave` backend
4. `subscription page`
5. reverse proxy
6. local node
7. `I.R.I.S.`, if it was part of the archive

#### `bootstrap-remnawave-host.sh`

Clean fresh-install path:

- installs Docker if needed
- downloads the official backend compose
- downloads the official bundled subscription page compose
- generates `.env`
- starts the base stack

### ✅ What to Check After Restore

- the panel opens
- the subscription page opens
- the `Remnawave API` responds
- the local node is alive if it belonged to the old host
- `I.R.I.S.` responds again if it was part of the old host

### 📌 What to Remember About Neighbor Services

`MTProto` and `user bot` are out of scope for this toolkit.

But if they live on the same server, still check manually:

- that `8443` stays reserved and clean for `MTProto`
- that `MTProto` does not conflict with panel and node ports
- that the user bot still points to the correct panel/subscription/mtproxy endpoints

### 🔐 Important

- the archive contains secrets, tokens, and private keys
- treat it as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging longer than needed

### 📖 Next

If you want a more detailed operator guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)
