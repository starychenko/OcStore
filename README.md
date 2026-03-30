# OpenCart (OcStore) Docker

[![OcStore 3](https://img.shields.io/badge/OcStore-v3.0.4.1-blue.svg)](https://github.com/ocStore/ocStore/releases/tag/v3.0.4.1)
[![OcStore 2.3](https://img.shields.io/badge/OcStore-v2.3.0.2.4-blue.svg)](https://github.com/myopencart/ocStore/releases/tag/v2.3.0.2.4)
[![PHP](https://img.shields.io/badge/PHP-8.1%20%7C%207.2-777BB4.svg)](https://www.php.net/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![Coolify](https://img.shields.io/badge/Coolify-Compatible-6B46C1.svg)](https://coolify.io/)
[![License](https://img.shields.io/badge/License-GPL%20v3-green.svg)](LICENSE)

**Production-ready Docker образ для OpenCart (OcStore)**

Підтримує дві версії:
- **OcStore 3.x** (v3.0.4.1) — PHP 8.1, OPcache+JIT, ionCube, Xdebug *(за замовчуванням)*
- **OcStore 2.3** (v2.3.0.2.4) — PHP 7.2, OPcache, Xdebug *(опціонально)*

Задеплоїв &rarr; Працює. Без ручних налаштувань.

## Можливості

| Функція | Опис |
|---------|------|
| **Дві версії OcStore** | v3.0.4.1 (PHP 8.1) та v2.3.0.2.4 (PHP 7.2) |
| **Паралельний запуск** | Обидві версії на одному сервері без конфліктів |
| **Автоматична інсталяція** | Без веб-візарда, все автоматично |
| **Безпечний storage** | Директорія storage поза webroot |
| **Збереження даних** | Модулі, теми, зображення зберігаються при redeploy |
| **Environment Variables** | Всі налаштування через змінні оточення |
| **Coolify Ready** | Traefik labels, health checks, SSL termination |
| **JIT продуктивність** | OPcache + Tracing JIT увімкнено (v3) |
| **Dev інструменти** | Xdebug та ionCube (v3) опціонально |

## Технології

### OcStore 3.x (за замовчуванням)

| Компонент | Версія | Деталі |
|-----------|--------|--------|
| **PHP** | 8.1-FPM | Debian Bookworm, gd, mysqli, zip, intl, bcmath, exif |
| **OPcache** | + JIT | Tracing JIT (1255) для максимальної швидкості |
| **Xdebug** | 3.x | Опціонально, вимкнено (несумісний з JIT) |
| **ionCube** | Latest | Опціонально, вимкнено (несумісний з JIT) |

### OcStore 2.3 (опціонально)

| Компонент | Версія | Деталі |
|-----------|--------|--------|
| **PHP** | 7.2-FPM | Debian Buster, gd, mysqli, zip, intl, bcmath, exif |
| **OPcache** | Без JIT | JIT недоступний в PHP 7.2 |
| **Xdebug** | 3.1.6 | Опціонально, вимкнено |

### Спільне

| Компонент | Версія | Деталі |
|-----------|--------|--------|
| **Nginx** | Latest | SEO URLs, gzip, кешування, security headers, SSL termination |
| **MariaDB** | 10.6 LTS | Оптимізовані налаштування InnoDB |
| **phpMyAdmin** | Latest | Веб-інтерфейс для БД |
| **FileBrowser** | Latest | Веб-файловий менеджер |

---

## Вибір версії OcStore

Кожна версія має **окремий docker-compose файл** з унікальними іменами сервісів:

| | OcStore 3.x | OcStore 2.3 |
|---|---|---|
| **Compose файл** | `docker-compose.yml` | `docker-compose.v2.yml` |
| **Dockerfile** | `Dockerfile` | `Dockerfile.v2` |
| **Сервіси** | `opencart`, `mariadb`, `phpmyadmin`, `filebrowser` | `opencartv2`, `mariadbv2`, `phpmyadminv2`, `filebrowserv2` |
| **Volumes** | `opencart_html`, `opencart_storage` | `opencartv2_html`, `opencartv2_storage` |
| **Traefik** | `traefik.http.services.opencart` | `traefik.http.services.opencartv2` |

> **Чому окремі файли?** Якщо обидві версії працюють на одному сервері, однакові імена сервісів спричиняють конфлікти маршрутизації Traefik. Окремі compose файли повністю ізолюють інстанси.

---

## Швидкий старт

### Деплой на Coolify

#### OcStore 3.x

**1.** Resources &rarr; Add New &rarr; Private Repository (GitHub)

**2.** Build Pack: **Docker Compose**, файл: `docker-compose.yml`

**3.** Environment Variables:

```env
DB_DATABASE=opencart
DB_USERNAME=opencart
DB_PASSWORD=YourSecureDbPassword
DB_ROOT_PASSWORD=YourSecureRootPassword
OPENCART_URL=https://shop.yourdomain.com
ADMIN_USERNAME=admin
ADMIN_PASSWORD=YourSecureAdminPassword
ADMIN_EMAIL=admin@yourdomain.com
```

**4.** Домени:

| Сервіс | Домен |
|--------|-------|
| opencart | shop.yourdomain.com |
| phpmyadmin | pma.yourdomain.com |
| filebrowser | files.yourdomain.com |

**5.** Deploy &rarr; через 3-5 хвилин все працює.

#### OcStore 2.3

**1.** Resources &rarr; Add New &rarr; Private Repository (GitHub)

**2.** Build Pack: **Docker Compose**, файл: `docker-compose.v2.yml`

**3.** Environment Variables (ті ж самі, але з іншим URL та БД):

```env
DB_DATABASE=opencartv2
DB_USERNAME=opencartv2
DB_PASSWORD=YourSecureDbPassword
DB_ROOT_PASSWORD=YourSecureRootPassword
DB_EXTERNAL_PORT=3308
OPENCART_URL=https://shop2.yourdomain.com
ADMIN_USERNAME=admin
ADMIN_PASSWORD=YourSecureAdminPassword
ADMIN_EMAIL=admin@yourdomain.com
```

**4.** Домени:

| Сервіс | Домен |
|--------|-------|
| opencartv2 | shop2.yourdomain.com |
| phpmyadminv2 | pma2.yourdomain.com |
| filebrowserv2 | files2.yourdomain.com |

**5.** Deploy

> **Важливо:** Не використовуйте спеціальні символи `$ # ! @ \` в паролях — вони інтерпретуються shell і обрізаються.

---

### Локальна розробка

```bash
# 1. Клонувати
git clone https://github.com/starychenko/OcStore.git
cd OcStore

# 2. Налаштувати
cp .env.example .env
# Відредагувати .env

# 3. Створити docker-compose.override.yml для портів
cat > docker-compose.override.yml << 'EOF'
services:
  opencart:
    ports:
      - "8080:80"
  phpmyadmin:
    ports:
      - "8081:80"
  filebrowser:
    ports:
      - "8082:8080"
EOF

# 4. Запустити (OcStore 3.x)
docker compose up -d --build

# 4. Або запустити (OcStore 2.3)
docker compose -f docker-compose.v2.yml up -d --build
```

**Посилання:**
- Магазин: http://localhost:8080
- Адмінка: http://localhost:8080/admin
- phpMyAdmin: http://localhost:8081
- FileBrowser: http://localhost:8082 (логін: admin, пароль в логах)

**Приклад `.env` для розробки:**
```env
DB_ROOT_PASSWORD=rootpass123
DB_DATABASE=opencart
DB_USERNAME=opencart
DB_PASSWORD=dbpass123
OPENCART_URL=http://localhost:8080
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
ADMIN_EMAIL=admin@localhost.com
XDEBUG_ENABLED=1
```

---

## Структура проекту

```
OcStore/
├── Dockerfile                  # v3: PHP 8.1-FPM + Nginx + Xdebug + ionCube
├── Dockerfile.v2               # v2.3: PHP 7.2-FPM + Nginx + Xdebug
├── docker-compose.yml          # v3: сервіси opencart, mariadb, etc.
├── docker-compose.v2.yml       # v2.3: сервіси opencartv2, mariadbv2, etc.
├── .env.example                # Приклад змінних
└── docker/
    ├── nginx/default.conf      # Nginx: SEO URLs, кеш, SSL params (спільний)
    ├── php/
    │   ├── php.ini             # v3: OPcache, JIT, Xdebug
    │   ├── php.v2.ini          # v2.3: OPcache (без JIT), Xdebug
    │   ├── php-fpm.conf        # v3: PHP-FPM pool
    │   └── php-fpm.v2.conf     # v2.3: PHP-FPM pool (PHP 7.2 compatible)
    ├── mariadb/my.cnf          # MariaDB: InnoDB, query cache (спільний)
    ├── supervisor/supervisord.conf
    ├── entrypoint.sh           # v3: автоінсталяція + Xdebug/ionCube toggle
    └── entrypoint.v2.sh        # v2.3: автоінсталяція + Xdebug toggle
```

---

## FileBrowser (Файловий менеджер)

FileBrowser надає веб-інтерфейс для управління файлами OpenCart.

### Доступ

| Середовище | URL |
|------------|-----|
| Coolify | `https://files.yourdomain.com` |
| Локально | `http://localhost:8082` |

### Credentials

- **Логін:** `admin`
- **Пароль:** Генерується автоматично при першому запуску

Пароль можна знайти в логах контейнера:
```
User 'admin' initialized with randomly generated password: xPAY_bedXiKZhTS9
```

В Coolify: **Logs** &rarr; **filebrowser**

### Структура файлів

```
/data/
  ├── html/      ← /var/www/html (код OpenCart)
  │   ├── admin/
  │   ├── catalog/
  │   ├── image/
  │   └── system/
  │
  └── storage/   ← /var/www/storage (uploads, cache, logs)
      ├── cache/
      ├── download/
      ├── logs/
      └── upload/
```

### Скидання пароля

Видаліть volume `filebrowser_data` і зробіть redeploy — буде згенеровано новий пароль.

---

## JIT, ionCube та Xdebug

**Тільки OcStore 3.x.** JIT, ionCube та Xdebug несумісні — вони не можуть працювати одночасно. Тому ionCube та Xdebug **вимкнені за замовчуванням** для максимальної продуктивності з JIT.

| Режим | IONCUBE_ENABLED | XDEBUG_ENABLED | JIT | Використання |
|-------|-----------------|----------------|-----|--------------|
| **Production** | `0` | `0` | On | Coolify, продакшн (максимальна швидкість) |
| **ionCube** | `1` | `0` | Off | Закодовані PHP модулі |
| **Development** | `0` | `1` | Off | Локальна розробка з VS Code |

**OcStore 2.3:** JIT недоступний (PHP 7.2). Xdebug працює аналогічно. ionCube не підтримується.

### Увімкнути Xdebug для розробки

Додайте в `.env`:
```env
XDEBUG_ENABLED=1
```

### Налаштування VS Code

Створіть `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Listen for Xdebug",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "pathMappings": {
                "/var/www/html": "${workspaceFolder}"
            }
        }
    ]
}
```

---

## Environment Variables

### Обов'язкові

| Змінна | Опис | Приклад |
|--------|------|---------|
| `DB_PASSWORD` | Пароль користувача БД | `SecurePass123` |
| `DB_ROOT_PASSWORD` | Пароль root БД | `RootPass123` |
| `OPENCART_URL` | URL магазину (з https://) | `https://shop.example.com` |
| `ADMIN_PASSWORD` | Пароль адміністратора | `AdminPass123` |

### Опціональні

| Змінна | За замовчуванням | Опис |
|--------|------------------|------|
| `DB_DATABASE` | `opencart` | Назва бази даних |
| `DB_USERNAME` | `opencart` | Користувач БД |
| `DB_PREFIX` | `oc_` | Префікс таблиць |
| `DB_EXTERNAL_PORT` | `3306` | Зовнішній порт MariaDB |
| `ADMIN_USERNAME` | `admin` | Логін адміністратора |
| `ADMIN_EMAIL` | `admin@example.com` | Email адміністратора |
| `IONCUBE_ENABLED` | `0` | `1` = увімкнути ionCube (вимкне JIT, тільки v3) |
| `XDEBUG_ENABLED` | `0` | `1` = увімкнути Xdebug (вимкне JIT у v3) |

---

## Docker Volumes (Збереження даних)

При редеплої всі дані зберігаються в Docker volumes:

| Volume | Шлях | Що зберігається |
|--------|------|-----------------|
| `opencart_html` | `/var/www/html` | Весь код OpenCart, модулі, теми |
| `opencart_storage` | `/var/www/storage` | Кеш, сесії, логи, завантаження |
| `mariadb_data` | `/var/lib/mysql` | База даних |
| `filebrowser_data` | `/config` | Налаштування та БД FileBrowser |

> Для OcStore 2.3 volumes мають суфікс `v2`: `opencartv2_html`, `opencartv2_storage`, etc.

---

## Що відбувається при деплої

**OcStore 3.x:**
```
[0/5] First deploy detected          → Копіювання OpenCart у volume
[INFO] ionCube Loader DISABLED (JIT enabled for performance)
[INFO] Xdebug DISABLED (JIT enabled for performance)
[1/5] Migrating storage files...     → Копіювання в /var/www/storage/
[2/5] Waiting for database...        → Очікування MariaDB
[3/5] Checking OpenCart installation...
      ├── Database has existing tables → Regenerate config.php
      └── Fresh database → Run CLI installer → Regenerate config.php
[4/5] Configuring storage path...    → Оновлення config.php
[5/5] Security cleanup...            → Видалення /install/
```

**OcStore 2.3:** Аналогічний процес, але без ionCube toggle та JIT.

**При redeploy:** всі файли (модулі, теми, зображення) зберігаються у Docker volumes. Перевстановлення не відбувається.

---

## Безпека

- Storage поза webroot (`/var/www/storage/`)
- Заборонено виконання PHP в `/image/` та `/storage/`
- Закритий доступ до `.tpl`, `.ini`, `.log` файлів
- Security headers (X-Frame-Options, X-Content-Type-Options)
- Небезпечні PHP функції вимкнені
- Xdebug вимкнено за замовчуванням
- SSL termination підтримка для reverse proxy (Coolify/Traefik)

---

## Команди

```bash
# OcStore 3.x
docker compose up -d                    # Запуск
docker compose logs -f opencart         # Логи
docker compose down                     # Зупинка
docker compose down -v                  # Повне видалення з даними
docker compose up -d --build            # Перезбірка

# OcStore 2.3
docker compose -f docker-compose.v2.yml up -d --build
docker compose -f docker-compose.v2.yml logs -f opencartv2
docker compose -f docker-compose.v2.yml down -v

# Діагностика
docker exec ocstore-opencart-1 php -m               # PHP модулі
docker exec ocstore-opencart-1 php -r "var_dump(opcache_get_status()['jit']);"  # JIT статус
docker exec ocstore-opencart-1 php -v | grep -i xdebug  # Xdebug статус
```

---

## Вирішення проблем

### Помилка підключення до БД

**Причина:** Паролі зі спеціальними символами (`$`, `#`, `!`)

**Рішення:** Використовуйте паролі тільки з літер і цифр

### jQuery / CORS помилки в адмінці

**Причина:** Reverse proxy (Coolify/Traefik) терміналить SSL, PHP не знає що з'єднання HTTPS

**Рішення:** Вже вирішено — nginx передає `fastcgi_param HTTPS on` та `SERVER_PORT 443`

### Сайти перемішуються (v3 показує v2.3 і навпаки)

**Причина:** Обидва інстанси використовують однакові Traefik service names

**Рішення:** Використовуйте `docker-compose.v2.yml` для OcStore 2.3 — сервіси мають унікальні імена

### Health check failing (Coolify)

**Причина:** Контейнер ще запускається (до 5 хвилин)

**Рішення:** Зачекайте або перевірте логи в Coolify &rarr; Logs

---

## Ліцензія

Ця Docker конфігурація надається під ліцензією MIT.

OcStore ліцензовано під [GNU GPL v3.0](https://github.com/ocStore/ocStore/blob/master/license.txt).

---

## Внесок

Issues та pull requests вітаються на [GitHub](https://github.com/starychenko/OcStore).
