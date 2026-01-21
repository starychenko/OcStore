# OpenCart 3 (OcStore) Docker

[![OcStore](https://img.shields.io/badge/OcStore-v3.0.4.1-blue.svg)](https://github.com/ocStore/ocStore/releases/tag/v3.0.4.1)
[![PHP](https://img.shields.io/badge/PHP-8.1--FPM-777BB4.svg)](https://www.php.net/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![Coolify](https://img.shields.io/badge/Coolify-Compatible-6B46C1.svg)](https://coolify.io/)
[![License](https://img.shields.io/badge/License-GPL%20v3-green.svg)](LICENSE)

**Production-ready Docker образ для OpenCart 3 (OcStore v3.0.4.1)**

Задеплоїв → Працює. Без ручних налаштувань.

## Можливості

| Функція | Опис |
|---------|------|
| **Автоматична інсталяція** | Без веб-візарда, все автоматично |
| **Безпечний storage** | Директорія storage поза webroot |
| **Збереження даних** | Модулі, теми, зображення зберігаються при redeploy |
| **Environment Variables** | Всі налаштування через змінні оточення |
| **Coolify Ready** | Traefik labels, health checks |
| **JIT продуктивність** | OPcache + Tracing JIT увімкнено |
| **Dev інструменти** | Xdebug та ionCube опціонально |

## Технології

| Компонент | Версія | Деталі |
|-----------|--------|--------|
| **PHP** | 8.1-FPM | Debian Bookworm, gd, mysqli, zip, intl, bcmath, exif |
| **OPcache** | + JIT | Tracing JIT (1255) для максимальної швидкості |
| **Nginx** | Latest | SEO URLs, gzip, кешування, security headers |
| **MariaDB** | 10.6 LTS | Оптимізовані налаштування InnoDB |
| **Xdebug** | 3.x | Опціонально, вимкнено (несумісний з JIT) |
| **ionCube** | Latest | Опціонально, вимкнено (несумісний з JIT) |
| **phpMyAdmin** | Latest | Веб-інтерфейс для БД |

---

## Швидкий старт

### Деплой на Coolify

**1. Створити Application**

**Resources** → **Add New** → **Private Repository (GitHub)**

**2. Вибрати Build Pack:** Docker Compose

**3. Додати Environment Variables**

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

> **Важливо:** Не використовуйте спеціальні символи `$ # ! @ \` в паролях — вони інтерпретуються shell і обрізаються.

**4. Налаштувати домени**

| Сервіс | Домен |
|--------|-------|
| opencart | shop.yourdomain.com |
| phpmyadmin | pma.yourdomain.com |

**5. Deploy** → Натиснути **Deploy**. Через 3-5 хвилин:
- Магазин: `https://shop.yourdomain.com`
- Адмінка: `https://shop.yourdomain.com/admin`

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
EOF

# 4. Запустити
docker compose up -d --build
```

**Посилання:**
- Магазин: http://localhost:8080
- Адмінка: http://localhost:8080/admin
- phpMyAdmin: http://localhost:8081

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

## JIT, ionCube та Xdebug

**JIT, ionCube та Xdebug несумісні** — вони не можуть працювати одночасно. Тому ionCube та Xdebug **вимкнені за замовчуванням** для максимальної продуктивності з JIT.

| Режим | IONCUBE_ENABLED | XDEBUG_ENABLED | JIT | Використання |
|-------|-----------------|----------------|-----|--------------|
| **Production** | `0` | `0` | On | Coolify, продакшн (максимальна швидкість) |
| **ionCube** | `1` | `0` | Off | Закодовані PHP модулі |
| **Development** | `0` | `1` | Off | Локальна розробка з VS Code |

### Увімкнути ionCube для закодованих модулів

Додайте в `.env`:
```env
IONCUBE_ENABLED=1
```

> **Увага:** ionCube вимкне JIT. Використовуйте тільки якщо у вас є закодовані PHP модулі.

### Увімкнути Xdebug для розробки

Додайте в `.env`:
```env
XDEBUG_ENABLED=1
```

Або в Coolify Environment Variables (тільки якщо потрібна відладка на сервері).

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

**Параметри Xdebug:**
- Mode: `debug,develop`
- Port: `9003`
- IDE Key: `VSCODE`
- Host: `host.docker.internal`

---

## ionCube Loader

ionCube Loader **вимкнений за замовчуванням** для сумісності з JIT. Увімкніть його тільки якщо у вас є закодовані PHP модулі.

Увімкнути:
```env
IONCUBE_ENABLED=1
```

Перевірити роботу (після увімкнення):
```bash
docker exec ocstore-opencart-1 php -m | grep ionCube
```

> **Важливо:** ionCube та JIT несумісні. Якщо вам потрібен JIT для максимальної продуктивності — не вмикайте ionCube.

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
| `ADMIN_USERNAME` | `admin` | Логін адміністратора |
| `ADMIN_EMAIL` | `admin@example.com` | Email адміністратора |
| `IONCUBE_ENABLED` | `0` | `1` = увімкнути ionCube (вимкне JIT) |
| `XDEBUG_ENABLED` | `0` | `1` = увімкнути Xdebug (вимкне JIT) |

---

## Структура проекту

```
OcStore/
├── Dockerfile                  # PHP 8.1-FPM (Debian) + Nginx + Xdebug + ionCube
├── docker-compose.yml          # Production конфігурація
├── .env.example                # Приклад змінних
└── docker/
    ├── nginx/default.conf      # Nginx: SEO URLs, кеш, безпека
    ├── php/
    │   ├── php.ini             # PHP: OPcache, JIT, Xdebug
    │   └── php-fpm.conf        # PHP-FPM pool
    ├── mariadb/my.cnf          # MariaDB: InnoDB, query cache
    ├── supervisor/supervisord.conf
    └── entrypoint.sh           # Автоматична інсталяція + Xdebug toggle
```

---

## Docker Volumes (Збереження даних)

При редеплої всі дані зберігаються в Docker volumes:

| Volume | Шлях | Що зберігається |
|--------|------|-----------------|
| `opencart_html` | `/var/www/html` | Весь код OpenCart, модулі, теми |
| `opencart_storage` | `/var/www/storage` | Кеш, сесії, логи, завантаження |
| `mariadb_data` | `/var/lib/mysql` | База даних |

**Це означає:**
- ✅ Встановлені модулі зберігаються
- ✅ Завантажені зображення зберігаються
- ✅ Теми та кастомізації зберігаються
- ✅ База даних зберігається
- ✅ Налаштування OpenCart зберігаються

**Перший деплой:** OpenCart копіюється з образу в volume.
**Наступні деплої:** Файли у volume не перезаписуються.

---

## Що відбувається при деплої

```
[0/5] First deploy detected          → Копіювання OpenCart у volume
      (або: Existing installation detected - preserving files)
[INFO] ionCube Loader DISABLED (JIT enabled for performance)
[INFO] Xdebug DISABLED (JIT enabled for performance)
[1/5] Migrating storage files...     → Копіювання в /var/www/storage/
[2/5] Waiting for database...        → Очікування MariaDB
[3/5] Checking OpenCart installation...
      ├── Database has existing tables → Regenerate config.php
      └── Fresh database → Run CLI installer
[4/5] Configuring storage path...    → Оновлення config.php
[5/5] Security cleanup...            → Видалення /install/
```

**При redeploy:** всі файли (модулі, теми, зображення) зберігаються у Docker volumes. Перевстановлення не відбувається.

Логи видно в Coolify → **Logs** → `opencart`

---

## PHP Налаштування

### OPcache + JIT

| Параметр | Значення | Опис |
|----------|----------|------|
| `opcache.enable` | 1 | OPcache увімкнено |
| `opcache.jit` | 1255 | Tracing JIT (найшвидший) |
| `opcache.jit_buffer_size` | 128M | Буфер для JIT |
| `opcache.memory_consumption` | 256M | Пам'ять для кешу |

### Ліміти

| Параметр | Значення |
|----------|----------|
| `memory_limit` | 512M |
| `max_execution_time` | 300s |
| `upload_max_filesize` | 100M |

### MariaDB

| Параметр | Значення |
|----------|----------|
| `innodb_buffer_pool_size` | 1G |
| `query_cache_size` | 64M |
| `max_connections` | 150 |

### Nginx

- Gzip стиснення
- Статичний кеш 1 рік
- Security headers
- SEO URLs

---

## Безпека

### Включено

- Storage поза webroot (`/var/www/storage/`)
- Заборонено виконання PHP в `/image/` та `/storage/`
- Закритий доступ до `.tpl`, `.ini`, `.log` файлів
- Security headers (X-Frame-Options, X-Content-Type-Options)
- Небезпечні PHP функції вимкнені
- Xdebug вимкнено за замовчуванням

### Рекомендації для Production

1. Не вмикайте `XDEBUG_ENABLED=1` на продакшні
2. Використовуйте надійні паролі (12+ символів)
3. Обмежте доступ до phpMyAdmin
4. Регулярно оновлюйте Docker образи

---

## Команди

```bash
# Запуск
docker compose up -d

# Перегляд логів
docker compose logs -f opencart

# Зупинка
docker compose down

# Повне видалення (з даними)
docker compose down -v

# Перезбірка
docker compose up -d --build

# Перевірити PHP модулі
docker exec ocstore-opencart-1 php -m

# Перевірити JIT статус
docker exec ocstore-opencart-1 php -r "var_dump(opcache_get_status()['jit']);"

# Перевірити Xdebug
docker exec ocstore-opencart-1 php -v | grep -i xdebug
```

---

## Бенчмарк

Перевірити продуктивність сервера:

```bash
# TTFB (Time To First Byte)
curl -w "TTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" -o /dev/null -s https://your-domain.com/

# PHP benchmark
docker exec ocstore-opencart-1 php -r "\$s=microtime(1);for(\$i=0;\$i<1000000;\$i++){}echo 'Loop 1M: '.round((microtime(1)-\$s)*1000).'ms'.PHP_EOL;"

# Disk I/O
docker exec ocstore-opencart-1 dd if=/dev/zero of=/tmp/test bs=1M count=100 oflag=direct 2>&1 | tail -1
```

---

## Вирішення проблем

### Помилка підключення до БД

**Причина:** Паролі зі спеціальними символами (`$`, `#`, `!`)

**Рішення:** Використовуйте паролі тільки з літер і цифр

### Білий екран / 500 помилка

**Причина:** Неправильний шлях storage або помилка PHP

**Рішення:** Перевірте логи `docker compose logs opencart`

### phpMyAdmin не працює

**Логін:** користувач `opencart` або `root` з відповідними паролями

### JIT показує Disabled

**Причина:** Увімкнений ionCube або Xdebug (несумісні з JIT)

**Рішення:** Переконайтесь що обидва вимкнені:
```env
IONCUBE_ENABLED=0
XDEBUG_ENABLED=0
```

Або просто не вказуйте ці змінні (за замовчуванням = 0)

### Xdebug не підключається

1. Перевірте що `XDEBUG_ENABLED=1` в `.env`
2. Перевірте що VS Code слухає порт 9003
3. Перевірте `pathMappings` в `launch.json`

### Health check failing (Coolify)

**Причина:** Контейнер ще запускається (до 5 хвилин)

**Рішення:** Зачекайте або перевірте логи в Coolify → Logs → opencart

### Дані втрачаються при redeploy

**Це виправлено.** Всі дані зберігаються в Docker volumes:
- `/var/www/html` — модулі, теми, код
- `/var/www/storage` — кеш, сесії, завантаження
- База даних — окремий volume

Модулі та налаштування не втрачаються при редеплої.

---

## Ліцензія

Ця Docker конфігурація надається під ліцензією MIT.

OcStore ліцензовано під [GNU GPL v3.0](https://github.com/ocStore/ocStore/blob/master/license.txt).

---

## Внесок

Issues та pull requests вітаються на [GitHub](https://github.com/starychenko/OcStore).
