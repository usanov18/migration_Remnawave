# migration_Remnawave

> 🚚 Remnawave Migration & Bootstrap Toolkit  
> A focused operator repository for moving, restoring, and rebuilding a Remnawave host with less guesswork.

[🇷🇺 Русская версия](#-русская-версия) • [🇬🇧 English Version](#-english-version)

---

## 🇷🇺 Русская версия

[Switch to English](#-english-version)

### ✨ Что это

`migration_Remnawave` — это отдельный toolkit для:

- 🚚 переезда `Remnawave Panel` на новый VPS
- 📦 сборки migration pack с рабочего сервера
- ♻️ восстановления host-side стека на другом сервере
- 🏗 быстрого bootstrap чистого `Remnawave`-хоста

Это **не репозиторий бота**.  
Если вам нужен Telegram admin-layer, используйте:

- 🔗 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 💡 Зачем выделять это в отдельный проект

Во время переезда проблема обычно не в том, чтобы “достать код”.

Настоящая боль в другом:

- что именно нужно архивировать
- какие `.env`, ключи и токены критичны
- в каком порядке поднимать сервисы
- как не забыть `subscription page`, reverse proxy, `MTProto`, `user bot` и локальную ноду

Этот проект нужен, чтобы сделать migration и bootstrap повторяемыми.

### 📚 На чем это основано

Toolkit собран вокруг официальной модели `Remnawave`:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

Для bundled `subscription page` тоже используются официальные upstream-файлы.

### 🧰 Что лежит в репозитории

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — собрать migration pack с текущего сервера
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — развернуть архив на новом сервере
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — поднять чистый Remnawave host с нуля
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — подробный migration guide

### 📍 Фиксированный workspace

Все migration archives и restore staging жестко привязаны к:

```text
/home/alt441/
```

Это значит:

- архивы складываются в `/home/alt441/`
- restore staging тоже живет под `/home/alt441/`
- pre-restore snapshot сохраняется там же

### 🛣 Три основных пути

#### 1. Собрать migration pack с рабочего сервера

На production host:

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

Что войдет в архив:

- `/opt/remnawave`
- `/opt/remnawave/nginx`
- `/opt/remnawave/caddy`
- `/opt/remnawave/subscription`
- `/opt/iris-remnawave`
- `/opt/telemt`
- `/opt/iris_user`
- `/opt/remnanode`
- `/opt/rnexus-site`
- SQL dump Remnawave
- manifest
- restore notes

Результат:

- один `tar.gz` в `/home/alt441/`
- один checksum-файл рядом

#### 2. Восстановить тот же стек на новом сервере

Положите архив в:

```text
/home/alt441/
```

И выполните:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

Скрипт:

- сам найдет самый свежий migration archive
- распакует его в restore staging
- вернет файлы в `/opt/...`
- импортирует базу Remnawave
- поднимет сервисы в правильном порядке

Если меняются IP или домены:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

Если нужно только разложить файлы:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

#### 3. Поднять чистый Remnawave host

Если не нужен старый state, а нужен чистый host по простой схеме:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

Что делает bootstrap:

- скачивает официальный backend compose
- скачивает официальный bundled subscription-page compose
- генерирует безопасные `.env`
- собирает простой `Caddy` reverse proxy
- поднимает `PostgreSQL`, `Redis`, `Remnawave`, optional subscription page и `Caddy`

Если уже есть API token для bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

### 🧭 Что выбирать

Выбирайте `build + restore`, если:

- нужен максимально похожий на старый сервер
- нужна текущая база
- нужны текущие секреты
- нужно сохранить `MTProto`, `user bot`, локальную ноду и bot-side слой

Выбирайте `bootstrap`, если:

- нужен fresh host
- не нужен текущий production state
- нужен чистый `Remnawave` base перед дальнейшей настройкой

### 🧪 Как тестировать на чистом VPS

Если цель — “взять новый VPS и прогнать сценарий руками”, самый понятный путь такой.

#### Вариант A. Проверить fresh bootstrap

1. Подготовить чистый Ubuntu VPS.
2. Клонировать этот репозиторий.
3. Запустить:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

4. Открыть panel domain.
5. Завершить onboarding в `Remnawave`.
6. При желании потом накатить `I.R.I.S.` из bot-репозитория.

#### Вариант B. Проверить реальный переезд

1. Собрать migration pack на старом сервере.
2. Скопировать архив в `/home/alt441/` на новом VPS.
3. Клонировать этот репозиторий на новый VPS.
4. Запустить:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

5. Пройти smoke-check панели, подписок, `MTProto`, `user bot` и локальной ноды.

### ✅ Что проверить после restore

- открывается panel frontend
- открывается subscription page
- отвечает Remnawave API
- принимает подключения `MTProto`
- user bot продолжает работать
- локальная нода поднята, если она была частью старого сервера
- `I.R.I.S.` переподключается, если bot-side файлы входили в архив

### 🔐 Важно

- migration archives содержат секреты, токены и private keys
- храните архив как чувствительный секрет
- checksum-файл лучше держать рядом с архивом
- не оставляйте restore staging на случайных серверах дольше нужного

### 🔗 Связанный проект

Telegram admin-layer и контроль нод находятся здесь:

- [iris-remnawave](https://github.com/usanov18/iris-remnawave)

---

## 🇬🇧 English Version

[Перейти к русской версии](#-русская-версия)

### ✨ What It Is

`migration_Remnawave` is a dedicated toolkit for:

- 🚚 moving `Remnawave Panel` to a new VPS
- 📦 building a migration pack from a live server
- ♻️ restoring the host-side stack onto another server
- 🏗 bootstrapping a clean `Remnawave` host from scratch

This is **not the bot repository**.  
If you need the Telegram admin layer, use:

- 🔗 [iris-remnawave](https://github.com/usanov18/iris-remnawave)

### 💡 Why a Separate Project

During a move, the real problem is rarely "getting the code".

The real pain is:

- knowing what exactly must be archived
- identifying which `.env` files, keys, and tokens matter
- restoring services in the correct order
- not forgetting `subscription page`, reverse proxy, `MTProto`, `user bot`, and the local node

This repository exists to make migration and bootstrap repeatable.

### 📚 What It Is Based On

The toolkit follows the official `Remnawave` model:

- [Quick start](https://docs.rw/docs/learn/quick-start)
- [Environment variables](https://docs.rw/docs/install/environment-variables/)
- [Remnawave Node install](https://docs.rw/docs/install/remnawave-node/)
- [Caddy reverse proxy](https://docs.rw/docs/install/reverse-proxies/caddy/)

Bundled `subscription page` files are also taken from official upstream sources.

### 🧰 What Lives in This Repository

- [`scripts/build-remnawave-migration-pack.sh`](scripts/build-remnawave-migration-pack.sh) — build a migration pack from the current host
- [`scripts/restore-remnawave-migration-pack.sh`](scripts/restore-remnawave-migration-pack.sh) — restore that archive on a new host
- [`scripts/bootstrap-remnawave-host.sh`](scripts/bootstrap-remnawave-host.sh) — deploy a clean Remnawave host from scratch
- [`docs/remnawave-panel-migration.md`](docs/remnawave-panel-migration.md) — detailed migration guide

### 📍 Fixed Workspace

All migration archives and restore staging are pinned to:

```text
/home/alt441/
```

That means:

- archives are written into `/home/alt441/`
- restore staging also lives under `/home/alt441/`
- pre-restore snapshots are stored there as well

### 🛣 Three Main Paths

#### 1. Build a Migration Pack from a Running Host

Run on the production host:

```bash
sudo bash scripts/build-remnawave-migration-pack.sh
```

What goes into the archive:

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
- manifest
- restore notes

Result:

- one `tar.gz` archive in `/home/alt441/`
- one checksum file next to it

#### 2. Restore the Same Stack on a New Host

Place the archive into:

```text
/home/alt441/
```

Then run:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

The script will:

- find the latest migration archive
- extract it into restore staging
- restore files into `/opt/...`
- import the Remnawave database
- start services in the correct order

If IPs or domains change:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh \
  --public-host 203.0.113.10 \
  --admin-domain admin.example.com \
  --subscription-domain sub.example.com \
  --mtproto-host 203.0.113.10
```

If you only want files restored:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh --skip-start
```

#### 3. Bootstrap a Clean Remnawave Host

If you do not need old state and want a clean deployment:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

What the bootstrap does:

- downloads the official backend compose
- downloads the official bundled subscription-page compose
- generates secure `.env` values
- builds a simple `Caddy` reverse proxy
- starts `PostgreSQL`, `Redis`, `Remnawave`, optional subscription page, and `Caddy`

If you already have an API token for the bundled subscription page:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com \
  --subscription-api-token YOUR_REMNAWAVE_API_TOKEN
```

### 🧭 Which Path to Choose

Choose `build + restore` if:

- you want the new host to look like the old one
- you need the current database
- you need the current secrets
- you want to keep `MTProto`, `user bot`, local node, and the bot-side layer

Choose `bootstrap` if:

- you want a fresh host
- you do not need current production state
- you want a clean `Remnawave` base before further setup

### 🧪 How to Test on a Fresh VPS

If your goal is "take a clean VPS and validate the whole flow", the easiest path is this.

#### Option A. Test Fresh Bootstrap

1. Prepare a clean Ubuntu VPS.
2. Clone this repository.
3. Run:

```bash
sudo bash scripts/bootstrap-remnawave-host.sh \
  --panel-domain admin.example.com \
  --subscription-domain sub.example.com
```

4. Open the panel domain.
5. Finish `Remnawave` onboarding.
6. Optionally add `I.R.I.S.` afterward from the bot repository.

#### Option B. Test Real Migration

1. Build a migration pack on the old host.
2. Copy the archive to `/home/alt441/` on the new VPS.
3. Clone this repository on the new VPS.
4. Run:

```bash
sudo bash scripts/restore-remnawave-migration-pack.sh
```

5. Smoke-test panel, subscription page, `MTProto`, `user bot`, and the local node.

### ✅ Post-Restore Smoke Checks

After a restore, verify:

- panel frontend opens
- subscription page opens
- Remnawave API responds
- `MTProto` accepts connections
- user bot still serves users
- local node is up if it belonged to the old host
- `I.R.I.S.` reconnects if bot-side files were included in the archive

### 🔐 Safety Notes

- migration archives contain secrets, tokens, and private keys
- treat the archive as a sensitive secret
- keep the checksum file next to the archive
- do not leave restore staging on disposable hosts longer than necessary

### 🔗 Related Project

Telegram admin-layer and node control live here:

- [iris-remnawave](https://github.com/usanov18/iris-remnawave)
