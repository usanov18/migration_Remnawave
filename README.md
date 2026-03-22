# migration_Remnawave

> 🚚 Remnawave Migration & Bootstrap Toolkit  
> Focused on the panel, its core dependencies, and the local node.

[🇷🇺 Русская версия](#-русская-версия) • [🇬🇧 English Version](#-english-version)

---

## 🇷🇺 Русская версия

[Switch to English](#-english-version)

### ✨ Что это

`migration_Remnawave` — это отдельный toolkit для двух понятных задач:

- 🚚 перевезти текущую `Remnawave Panel` на новый VPS
- 🏗️ быстро поднять чистый `Remnawave` host с нуля

Главный фокус проекта:

- `Remnawave Panel`
- `PostgreSQL / Redis`
- `subscription page`
- reverse proxy
- локальная `Remnawave Node`

### 🎯 Что здесь главное

Этот репозиторий специально **не пытается быть “всем сразу”**.  
Он нужен именно для того, чтобы:

- сохранить состояние панели
- перенести ее зависимости
- не потерять локальную ноду
- быстро восстановить рабочий стек на новом сервере

### 🚫 Что сюда не входит

В этот migration flow **не входят**:

- `I.R.I.S.`
- `MTProto`
- `user bot`

Почему так:

- при реальной миграции панели ботов лучше не тащить архивом
- их надежнее и чище раскатывать отдельно, уже после того как панель полностью жива
- это уменьшает риск смешать panel migration с соседними сервисами

Если вам нужен `I.R.I.S.` после переезда панели:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 📚 На что опирается toolkit

Toolkit собран вокруг официальной документации `Remnawave`:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

### 🧰 Что есть в репозитории

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — собрать migration archive со старого сервера
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — восстановить archive на новом сервере
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — поднять чистый `Remnawave` host с нуля
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — подробный operator guide

### 📍 Где живут архивы и staging

Toolkit специально использует простой и универсальный workspace:

```text
/home/
```

Это значит:

- migration archive складывается в `/home/`
- checksum лежит рядом в `/home/`
- restore staging живет в `/home/remnawave-migration-restore/`
- pre-restore snapshot сохраняется в `/home/pre-restore-snapshot_<timestamp>/`

### 🔌 Рекомендуемая схема портов

Если панель и локальная нода живут на одном хосте, лучше сразу держать такую схему:

- `443` — панель `Remnawave`
- `8443` — оставить под `MTProto`, если он есть рядом
- `2222` — служебный/API порт ноды
- `2053` — предпочтительный внешний порт для клиентских конфигов локальной ноды

Почему это удобно:

- `443` уже нужен панели
- `8443` лучше не занимать, если у вас рядом есть `MTProto`
- `2222` нужен самой ноде
- `2053` обычно остается самым спокойным и практичным публичным портом для node-конфигов

## 🚀 Быстрый старт для новичка

### Сценарий 1. Перевезти текущую панель на новый сервер

#### Шаг 1. На старом сервере собрать archive

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

После этого в `/home/` появятся:

- `remnawave_migration_pack_<host>_<timestamp>.tar.gz`
- `remnawave_migration_pack_<host>_<timestamp>.tar.gz.sha256`

#### Шаг 2. Перенести archive на новый сервер

Пример:

```bash
scp /home/remnawave_migration_pack_*.tar.gz root@NEW_SERVER_IP:/home/
scp /home/remnawave_migration_pack_*.tar.gz.sha256 root@NEW_SERVER_IP:/home/
```

#### Шаг 3. На новом сервере развернуть archive

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/restore-remnawave-migration-pack.sh
```

Что сделает скрипт:

- найдет свежий archive в `/home/`
- распакует его в staging
- восстановит файлы панели в `/opt/...`
- поднимет базу и Redis
- импортирует SQL dump
- поднимет backend `Remnawave`
- поднимет `subscription page`
- поднимет reverse proxy
- поднимет локальную `Remnawave Node`, если она была частью старого хоста

#### Шаг 4. Если на новом сервере будут другие домены

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

#### Шаг 5. Если сначала хотите просто разложить файлы

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

Это удобно, если вы хотите:

- сначала проверить содержимое
- руками поправить `.env`
- отдельно посмотреть конфиги proxy или node

### Сценарий 2. Поднять панель с нуля на чистом VPS

Если старое состояние не нужно, используйте bootstrap:

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

Если у вас уже есть API token для встроенной subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

Что делает bootstrap:

- ставит Docker при необходимости
- забирает актуальный `Remnawave`
- подготавливает `.env`
- подготавливает встроенную `subscription page`
- подготавливает `Caddy`
- запускает базовый panel stack

## 🧠 Что делает каждый скрипт

### `build-remnawave-migration-pack.sh`

Собирает migration archive только из panel-side контура:

- `Remnawave`
- `subscription page`
- reverse proxy
- локальная `Remnawave Node`
- SQL dump базы
- manifest
- restore notes

### `restore-remnawave-migration-pack.sh`

Восстанавливает panel-side контур в правильном порядке:

1. `remnawave-db` и `remnawave-redis`
2. импорт SQL
3. backend `Remnawave`
4. `subscription page`
5. reverse proxy
6. локальная `Remnawave Node`

### `bootstrap-remnawave-host.sh`

Готовит чистую базу для нового сервера:

- Docker
- `Remnawave`
- `subscription page`
- `Caddy`

## ✅ Что проверить после restore

Проверяйте именно в таком порядке:

1. Открывается панель в браузере.
2. Открывается subscription page.
3. Отвечает `Remnawave API`.
4. Если на старом хосте была локальная нода — она тоже поднялась.
5. Node control/API отвечает на `2222`.
6. Клиентские node-конфиги используют `2053`, если это ваша production-схема.

## 📌 Что делать после того, как панель ожила

Когда панель, subscription page и локальная нода уже подтвержденно работают:

- при необходимости отдельно раскатить `I.R.I.S.` из [iris-remnawave](https://github.com/usanov18/iris-remnawave)
- отдельно проверить `MTProto`
- отдельно проверить `user bot`

Это намеренное разделение.  
Сначала панель и нода. Потом соседние сервисы.

## 🔐 Важно

- archive содержит токены, ключи и чувствительные конфиги
- храните его как секрет
- checksum лучше хранить рядом
- restore staging не стоит оставлять дольше нужного
- pre-restore snapshot удаляйте только после полного подтверждения переезда

## 📖 Подробнее

Полный пошаговый guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)

---

## 🇬🇧 English Version

[Перейти к русской версии](#-русская-версия)

### ✨ What This Is

`migration_Remnawave` is a dedicated toolkit for two clear jobs:

- 🚚 move a live `Remnawave Panel` to a new VPS
- 🏗️ bootstrap a clean `Remnawave` host from scratch

Main focus:

- `Remnawave Panel`
- `PostgreSQL / Redis`
- `subscription page`
- reverse proxy
- local `Remnawave Node`

### 🎯 What This Repo Is Really About

This repository is intentionally **not trying to migrate everything at once**.  
Its job is to help you:

- preserve the panel state
- move the panel dependencies
- keep the local node
- restore a working production stack on a new server

### 🚫 What Is Out of Scope

This migration flow does **not** include:

- `I.R.I.S.`
- `MTProto`
- `user bot`

Why:

- during a real panel migration, bots are better redeployed separately
- it is cleaner and safer to restore them only after the panel is healthy
- this keeps panel migration isolated from adjacent services

If you need `I.R.I.S.` after the panel move:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 📚 What This Toolkit Is Based On

The toolkit follows official `Remnawave` documentation:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

### 🧰 What Lives in This Repository

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — build a migration archive on the old host
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — restore that archive on the new host
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — bootstrap a clean `Remnawave` host
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — detailed operator guide

### 📍 Where Artifacts Live

The toolkit uses a simple fixed workspace:

```text
/home/
```

That means:

- the migration archive is created in `/home/`
- the checksum file is created next to it
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

### 🔌 Recommended Port Layout

If the panel and the local node share one host, this layout is the practical one:

- `443` — `Remnawave` panel
- `8443` — best reserved for `MTProto` if it exists on the same host
- `2222` — node service/API port
- `2053` — preferred public port for local node client configs

Why `2053`:

- `443` is already used by the panel
- `8443` is best left for `MTProto`
- `2222` is required by the node itself
- `2053` usually remains the cleanest public port for client-facing node configs

## 🚀 Beginner-Friendly Start

### Scenario 1. Move the current panel to a new server

#### Step 1. Build the archive on the old host

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/build-remnawave-migration-pack.sh
```

After that, `/home/` will contain:

- `remnawave_migration_pack_<host>_<timestamp>.tar.gz`
- `remnawave_migration_pack_<host>_<timestamp>.tar.gz.sha256`

#### Step 2. Copy the archive to the new host

Example:

```bash
scp /home/remnawave_migration_pack_*.tar.gz root@NEW_SERVER_IP:/home/
scp /home/remnawave_migration_pack_*.tar.gz.sha256 root@NEW_SERVER_IP:/home/
```

#### Step 3. Restore the archive on the new host

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/restore-remnawave-migration-pack.sh
```

The script will:

- find the newest archive in `/home/`
- extract it into staging
- restore panel files into `/opt/...`
- start database and Redis
- import the SQL dump
- start the `Remnawave` backend
- start the `subscription page`
- start the reverse proxy
- start the local `Remnawave Node` if it belonged to the old host

#### Step 4. If the new host uses different domains

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com
```

#### Step 5. If you want file-only restore first

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

This is useful when you want to:

- inspect the extracted files first
- edit `.env` manually
- review proxy or node configs before starting containers

### Scenario 2. Bootstrap a clean panel from scratch

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

What bootstrap does:

- installs Docker when needed
- downloads the current `Remnawave`
- prepares `.env`
- prepares the bundled `subscription page`
- prepares `Caddy`
- starts the base panel stack

## 🧠 What Each Script Does

### `build-remnawave-migration-pack.sh`

Builds a migration archive that contains only panel-side components:

- `Remnawave`
- `subscription page`
- reverse proxy
- local `Remnawave Node`
- SQL dump
- manifest
- restore notes

### `restore-remnawave-migration-pack.sh`

Restores the panel-side stack in the correct order:

1. `remnawave-db` and `remnawave-redis`
2. SQL import
3. `Remnawave` backend
4. `subscription page`
5. reverse proxy
6. local `Remnawave Node`

### `bootstrap-remnawave-host.sh`

Prepares a clean base for a new server:

- Docker
- `Remnawave`
- `subscription page`
- `Caddy`

## ✅ What To Check After Restore

Check in this exact order:

1. The panel opens in a browser.
2. The subscription page opens.
3. The `Remnawave API` responds.
4. If the old host had a local node, it is up as well.
5. The node service/API responds on `2222`.
6. Client-facing node configs use `2053` if that is your production layout.

## 📌 What To Do After The Panel Is Healthy

Once the panel, subscription page, and local node are confirmed healthy:

- deploy `I.R.I.S.` separately from [iris-remnawave](https://github.com/usanov18/iris-remnawave) if needed
- verify `MTProto` separately
- verify `user bot` separately

This separation is intentional.  
Panel and node first. Adjacent services after that.

## 🔐 Important

- the archive contains tokens, keys, and sensitive configs
- treat it as a secret
- keep the checksum file next to it
- do not leave restore staging longer than needed
- remove the pre-restore snapshot only after the migration is fully verified

## 📖 More Details

Full step-by-step operator guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)
