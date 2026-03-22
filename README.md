# migration_Remnawave

> 🚚 Remnawave Migration & Bootstrap Toolkit  
> A focused operator project for moving, restoring, and rebuilding a Remnawave host with minimal guesswork.

[🇷🇺 Русская версия](#-русская-версия) • [🇬🇧 English Version](#-english-version)

---

## 🇷🇺 Русская версия

[Switch to English](#-english-version)

### ✨ Что это

`migration_Remnawave` — это отдельный проект для тех случаев, когда вам нужно:

- 🚚 перевезти текущую панель `Remnawave` на новый VPS
- 📦 собрать migration archive со старого сервера
- ♻️ развернуть этот архив на новом сервере
- 🏗️ поднять чистый `Remnawave` host с нуля по простой схеме

Это **не Telegram-бот** и не admin-layer.  
Если вам нужен именно бот, используйте:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 🎯 Для кого

Этот репозиторий собран так, чтобы с ним справился даже оператор без глубокой подготовки.

Вам не нужно помнить:

- какие именно папки критичны для переезда
- в каком порядке поднимать сервисы
- где держать archive и restore staging
- что еще кроме панели входит в production host

Скрипты берут это на себя.

### 📚 На чем основано решение

Toolkit собран вокруг официальной модели `Remnawave`:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

Bundled `subscription page` тоже поднимается по официальной upstream-модели.

### 🧰 Что лежит в репозитории

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — собрать archive со старого сервера
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — развернуть archive на новом сервере
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — поднять чистый Remnawave host
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — подробный operator guide

### 📍 Фиксированный workspace

Все build/restore артефакты теперь живут в одном простом месте:

```text
/home/
```

Это значит:

- archive складывается в `/home/`
- checksum лежит рядом в `/home/`
- restore staging живет в `/home/remnawave-migration-restore/`
- pre-restore snapshot живет в `/home/pre-restore-snapshot_<timestamp>/`

Это сделано специально: путь нейтральный и предсказуемый почти на любом Linux VPS.

### 🚀 Самый простой сценарий для новичка

#### Вариант A. Перевезти текущую панель как есть

Это основной сценарий, если у вас уже есть рабочий production host.

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

Пример:

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

- найдет самый свежий archive в `/home/`
- распакует его
- разложит файлы обратно в `/opt/...`
- импортирует базу `Remnawave`
- поднимет сервисы в правильном порядке

#### 4. Если меняется IP или домены

Используйте restore с overrides:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

#### 5. Если хотите сначала только разложить файлы

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

Это удобно для сухого прогона перед реальным запуском сервисов.

### 🏗️ Второй простой сценарий

#### Вариант B. Поднять чистый Remnawave host с нуля

Если старый state не нужен, а нужен просто новый чистый VPS:

```bash
git clone https://github.com/usanov18/migration_Remnawave.git
cd migration_Remnawave
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

Если у вас уже есть API token для bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

Bootstrap сам:

- ставит Docker, если его нет
- скачивает официальный backend compose
- скачивает официальный bundled subscription page compose
- генерирует рабочие `.env`
- поднимает `PostgreSQL`, `Redis`, `Remnawave`
- поднимает простой `Caddy`

### 🧠 Что именно делает каждый скрипт

#### `build-remnawave-migration-pack.sh`

Собирает host-side migration archive и кладет его в `/home/`.

Обычно туда входят:

- `Remnawave`
- `subscription page`
- reverse proxy (`nginx` / `Caddy`)
- `MTProto`
- `user bot`
- локальная `Remnawave Node`
- `I.R.I.S.` admin-layer, если он живет на том же хосте
- SQL dump базы
- manifest и restore notes

#### `restore-remnawave-migration-pack.sh`

Берет archive из `/home/` и восстанавливает стек на новом сервере.

Подъем идет в правильном порядке:

1. база и Redis
2. импорт SQL
3. backend `Remnawave`
4. subscription page
5. reverse proxy
6. `MTProto`
7. `user bot`
8. локальная node
9. `I.R.I.S.`, если была частью архива

#### `bootstrap-remnawave-host.sh`

Это не migration, а чистый fresh-install путь.  
Он нужен, когда вы хотите:

- новый VPS
- официальный базовый layout
- минимальную ручную настройку

### ✅ Что проверить после restore

- панель открывается в браузере
- открывается subscription page
- отвечает `Remnawave API`
- работает `MTProto`
- user bot жив
- если бот был частью старого хоста, `I.R.I.S.` снова отвечает

### 🔐 Важно

- migration archive содержит секреты, токены и private keys
- храните его как чувствительный секрет
- checksum-файл лучше хранить рядом
- не оставляйте restore staging на случайных серверах дольше, чем нужно

### 🧭 Что выбрать

Выбирайте `build + restore`, если:

- нужен максимально похожий новый сервер
- нужна текущая база
- нужны текущие сервисы и окружение

Выбирайте `bootstrap`, если:

- нужен новый чистый VPS
- старое состояние не нужно
- хотите сначала поднять базу, а потом накатить свое окружение

### 📖 Дальше

Если нужен более подробный, спокойный, пошаговый guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)

---

## 🇬🇧 English Version

[Перейти к русской версии](#-русская-версия)

### ✨ What This Is

`migration_Remnawave` is a dedicated project for cases where you need to:

- 🚚 move a live `Remnawave` panel to a new VPS
- 📦 build a migration archive from the old host
- ♻️ restore that archive on a new server
- 🏗️ bootstrap a clean `Remnawave` host from scratch

This is **not the Telegram bot** and not the admin-layer.  
If you need the bot, use:

- 🤖 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 🎯 Who This Is For

This repository is written so even a less experienced operator can follow it.

You do not need to remember:

- which folders are critical for migration
- which services must be started first
- where archives and restore staging should live
- which supporting services belong to the panel host

The scripts handle that structure for you.

### 📚 What It Is Based On

The toolkit follows the official `Remnawave` model:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

The bundled `subscription page` is also prepared from official upstream files.

### 🧰 What Lives in This Repository

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — build an archive from the old host
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — restore that archive on a new host
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — bootstrap a clean Remnawave host
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — detailed operator guide

### 📍 Fixed Workspace

All generated migration artifacts now live in one predictable place:

```text
/home/
```

That means:

- archives are written into `/home/`
- checksum files are stored next to them
- restore staging lives in `/home/remnawave-migration-restore/`
- pre-restore snapshots live in `/home/pre-restore-snapshot_<timestamp>/`

This is intentionally simple and works well on almost any Linux VPS.

### 🚀 Easiest Beginner Path

#### Option A. Move the current panel as-is

This is the main path if you already have a live production host.

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

Example:

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
- restore files back into `/opt/...`
- import the `Remnawave` database
- start services in the correct order

#### 4. If the IP or domains change

Use restore with overrides:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

#### 5. If you want a file-only dry run first

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

This is useful when you want to inspect files before starting services.

### 🏗️ Second Easy Path

#### Option B. Bootstrap a clean Remnawave host from scratch

If you do not need the old state and only want a fresh VPS:

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

Bootstrap will:

- install Docker if needed
- download the official backend compose
- download the official bundled subscription page compose
- generate working `.env` files
- start `PostgreSQL`, `Redis`, `Remnawave`
- start a simple `Caddy` reverse proxy

### 🧠 What Each Script Does

#### `build-remnawave-migration-pack.sh`

Builds a host-side migration archive and places it in `/home/`.

That archive usually contains:

- `Remnawave`
- `subscription page`
- reverse proxy (`nginx` / `Caddy`)
- `MTProto`
- `user bot`
- local `Remnawave Node`
- `I.R.I.S.`, if it lives on the same host
- SQL dump
- manifest and restore notes

#### `restore-remnawave-migration-pack.sh`

Takes the archive from `/home/` and restores the stack on the new host.

Startup order is handled for you:

1. database and Redis
2. SQL import
3. `Remnawave` backend
4. subscription page
5. reverse proxy
6. `MTProto`
7. `user bot`
8. local node
9. `I.R.I.S.`, if it was part of the archive

#### `bootstrap-remnawave-host.sh`

This is not migration. It is the clean fresh-install path.  
Use it when you want:

- a brand new VPS
- an official-style base layout
- minimal manual setup

### ✅ What to Check After Restore

- panel opens in a browser
- subscription page opens
- `Remnawave API` responds
- `MTProto` works
- user bot is alive
- if the bot was part of the old host, `I.R.I.S.` responds again

### 🔐 Important

- the migration archive contains secrets, tokens, and private keys
- treat it as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging on random hosts longer than necessary

### 🧭 Which Path to Choose

Choose `build + restore` if:

- you want the new host to look like the old one
- you need the current database
- you want the current services and runtime state

Choose `bootstrap` if:

- you want a fresh clean VPS
- you do not need the old state
- you want a clean base before layering your own setup on top

### 📖 Next

If you want a calmer and more detailed operator guide:

- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md)
