# OpenCart 3 (OcStore) Docker

Повністю автоматизований Docker-образ для OpenCart 3 (OcStore v3.0.4.1). Задеплоїв — працює. Без ручних кроків.

## Можливості

- **Автоматична інсталяція** — без веб-візарда
- **Автоматичне налаштування storage** — безпечний шлях поза webroot
- **Автоматичне видалення install/** — після успішної інсталяції
- **Все через Environment Variables** — жодних ручних правок
- **Готовий для Coolify** — Traefik labels, правильна структура
- **Середовище для розробки** — Xdebug, ionCube, відображення помилок

## Технології

| Компонент | Версія | Опис |
|-----------|--------|------|
| PHP | 8.1-FPM (Debian Bookworm) | gd, mysqli, zip, intl, opcache, bcmath, exif |
| Xdebug | 3.x | Debug + Develop modes |
| ionCube | Latest | Loader для закодованих модулів |
| Nginx | Debian | SEO URLs, кешування, security headers |
| MariaDB | 10.6 LTS | Оптимізовані налаштування InnoDB |
| phpMyAdmin | Latest | Веб-інтерфейс для БД |

---

## Швидкий старт (Coolify)

### 1. Створити Application

**Resources** → **Add New** → **Private Repository (GitHub)**

### 2. Вибрати Build Pack

**Docker Compose**

### 3. Додати Environment Variables

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

### 4. Налаштувати домени

| Сервіс | Домен |
|--------|-------|
| opencart | shop.yourdomain.com |
| phpmyadmin | pma.yourdomain.com |

### 5. Deploy

Натиснути **Deploy**. Через 3-5 хвилин:
- Магазин: `https://shop.yourdomain.com`
- Адмінка: `https://shop.yourdomain.com/admin`

---

## Локальна розробка

### 1. Клонувати

```bash
git clone https://github.com/starychenko/OcStore.git
cd OcStore
```

### 2. Створити .env

```bash
cp .env.example .env
```

Відредагувати `.env`:

```env
DB_ROOT_PASSWORD=rootpass123
DB_DATABASE=opencart
DB_USERNAME=opencart
DB_PASSWORD=dbpass123
OPENCART_URL=http://localhost:8080
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
ADMIN_EMAIL=admin@localhost.com
```

### 3. Створити docker-compose.override.yml

```yaml
services:
  opencart:
    ports:
      - "8080:80"

  phpmyadmin:
    ports:
      - "8081:80"
```

### 4. Запустити

```bash
docker compose up -d --build
```

### 5. Готово

- **Магазин:** http://localhost:8080
- **Адмінка:** http://localhost:8080/admin
- **phpMyAdmin:** http://localhost:8081

---

## Xdebug (VS Code)

Xdebug вже налаштований і працює. Для підключення VS Code створіть `.vscode/launch.json`:

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

**Налаштування Xdebug:**
- Mode: `debug,develop`
- Port: `9003`
- IDE Key: `VSCODE`
- Host: `host.docker.internal`

---

## ionCube Loader

ionCube Loader встановлений для підтримки закодованих PHP модулів та розширень OpenCart.

Перевірити роботу:
```bash
docker exec ocstore-opencart-1 php -m | grep ionCube
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
| `ADMIN_USERNAME` | `admin` | Логін адміністратора |
| `ADMIN_EMAIL` | `admin@example.com` | Email адміністратора |

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
    │   ├── php.ini             # PHP: OPcache, Xdebug, development settings
    │   └── php-fpm.conf        # PHP-FPM pool
    ├── mariadb/my.cnf          # MariaDB: InnoDB, query cache
    ├── supervisor/supervisord.conf
    └── entrypoint.sh           # Автоматична інсталяція
```

---

## Що відбувається при деплої

```
[1/5] Migrating storage files...     → Копіювання в /var/www/storage/
[2/5] Waiting for database...        → Очікування MariaDB
[3/5] Installing OpenCart...         → CLI інсталяція
[4/5] Configuring storage path...    → Оновлення config.php
[5/5] Security cleanup...            → Видалення /install/
```

Логи видно в Coolify → **Logs** → `opencart`

---

## PHP Налаштування

### Production vs Development

Поточна конфігурація оптимізована для **розробки**:

| Параметр | Значення | Опис |
|----------|----------|------|
| `display_errors` | On | Показувати помилки |
| `error_reporting` | E_ALL | Всі помилки |
| `xdebug.mode` | debug,develop | Відладка + помічники |

### Ліміти

| Параметр | Значення |
|----------|----------|
| `memory_limit` | 512M |
| `max_execution_time` | 300s |
| `upload_max_filesize` | 100M |
| `opcache.memory_consumption` | 256M |

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

### Рекомендації для Production

1. Вимкніть `display_errors` в `php.ini`
2. Змініть `xdebug.mode` на `off` або видаліть Xdebug
3. Використовуйте надійні паролі (12+ символів)
4. Обмежте доступ до phpMyAdmin
5. Регулярно оновлюйте Docker образи

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

# Перевірити Xdebug
docker exec ocstore-opencart-1 php -v
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

### Xdebug не підключається

1. Перевірте, що VS Code слухає порт 9003
2. Перевірте `pathMappings` в `launch.json`
3. Перевірте firewall на хості

### Health check failing (Coolify)

**Причина:** Контейнер ще запускається або є помилка

**Рішення:** Перевірте логи в Coolify → Logs → opencart

---

## Ліцензія

OcStore — [GNU GPL v3.0](https://github.com/ocStore/ocStore/blob/master/license.txt)
