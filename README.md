# OpenCart 3 (OcStore) Docker

Docker-образ для OpenCart 3 (OcStore v3.0.4.1) з оптимізованими налаштуваннями для production.

## Технології

| Компонент | Версія | Опис |
|-----------|--------|------|
| PHP | 8.1-FPM | З усіма необхідними розширеннями |
| Nginx | Alpine | Веб-сервер з оптимізованою конфігурацією |
| MariaDB | 10.6 LTS | База даних з оптимізованими налаштуваннями |
| phpMyAdmin | Latest | Веб-інтерфейс для керування БД |

## Швидкий старт (локально)

### 1. Клонувати репозиторій

```bash
git clone https://github.com/starychenko/OcStore.git
cd OcStore
```

### 2. Створити .env файл

```bash
cp .env.example .env
```

Відредагувати `.env`:
```env
DB_ROOT_PASSWORD=your_secure_root_password
DB_DATABASE=opencart
DB_USERNAME=opencart
DB_PASSWORD=your_secure_password
OPENCART_URL=http://localhost:8080
ADMIN_EMAIL=admin@example.com
```

### 3. Створити docker-compose.override.yml (для локальної розробки)

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
docker compose up -d
```

### 5. Відкрити в браузері

- **OpenCart:** http://localhost:8080
- **phpMyAdmin:** http://localhost:8081

### 6. Встановити OpenCart

При встановленні вказати:

| Поле | Значення |
|------|----------|
| DB Host | `mariadb` |
| DB User | значення з `DB_USERNAME` |
| DB Password | значення з `DB_PASSWORD` |
| DB Name | значення з `DB_DATABASE` |
| DB Prefix | `oc_` |

---

## Деплой через Coolify

### 1. Додати репозиторій в Coolify

1. **Resources** → **Add New** → **Application**
2. Вибрати **Docker Compose**
3. Підключити GitHub репозиторій

### 2. Налаштувати Environment Variables

В розділі **Environment Variables** додати:

```
DB_ROOT_PASSWORD=надійний_пароль_root
DB_DATABASE=opencart
DB_USERNAME=opencart
DB_PASSWORD=надійний_пароль_користувача
OPENCART_URL=https://shop.yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com
```

### 3. Налаштувати домени

В розділі **Domains**:

| Сервіс | Домен |
|--------|-------|
| `opencart` | `shop.yourdomain.com` |
| `phpmyadmin` | `pma.yourdomain.com` |

### 4. Deploy

Натиснути **Deploy**. Coolify автоматично:
- Збілдить Docker образ
- Налаштує SSL сертифікати (Let's Encrypt)
- Запустить всі сервіси

---

## Структура проекту

```
OcStore/
├── Dockerfile                  # PHP 8.1-FPM + Nginx + OcStore
├── docker-compose.yml          # Основна конфігурація для Coolify
├── .env.example                # Приклад змінних середовища
├── .gitignore
├── .dockerignore
└── docker/
    ├── nginx/
    │   └── default.conf        # Nginx конфігурація
    ├── php/
    │   ├── php.ini             # PHP налаштування
    │   └── php-fpm.conf        # PHP-FPM pool конфігурація
    ├── mariadb/
    │   └── my.cnf              # MariaDB оптимізація
    ├── supervisor/
    │   └── supervisord.conf    # Керування процесами
    └── entrypoint.sh           # Скрипт ініціалізації
```

---

## PHP розширення

Встановлені розширення:

- `gd` — обробка зображень
- `mysqli` — з'єднання з MySQL/MariaDB
- `pdo_mysql` — PDO драйвер
- `zip` — робота з архівами
- `intl` — інтернаціоналізація
- `xml` — парсинг XML
- `mbstring` — багатобайтові рядки
- `opcache` — кешування PHP коду
- `bcmath` — математичні операції
- `exif` — метадані зображень
- `curl` — HTTP запити
- `openssl` — шифрування

---

## Оптимізації

### PHP (php.ini)

| Параметр | Значення | Опис |
|----------|----------|------|
| `memory_limit` | 512M | Ліміт пам'яті |
| `max_execution_time` | 300 | Час виконання скрипта |
| `upload_max_filesize` | 100M | Максимальний розмір завантаження |
| `opcache.memory_consumption` | 256M | Пам'ять для OPcache |
| `opcache.max_accelerated_files` | 10000 | Кількість закешованих файлів |

### MariaDB (my.cnf)

| Параметр | Значення | Опис |
|----------|----------|------|
| `innodb_buffer_pool_size` | 1G | Буфер InnoDB (налаштувати під RAM) |
| `query_cache_size` | 64M | Кеш запитів |
| `max_connections` | 150 | Максимум з'єднань |
| `innodb_flush_log_at_trx_commit` | 2 | Баланс швидкості/надійності |

### Nginx

- Gzip стиснення
- Кешування статичних файлів (1 рік)
- Security headers (X-Frame-Options, X-Content-Type-Options)
- SEO URLs для OpenCart

---

## Безпека

### Захищено

- Заборонено виконання PHP в `/image/` та `/system/storage/`
- Закритий доступ до `.tpl`, `.ini`, `.log`, `.sql` файлів
- Закритий доступ до `/system/` та `/vendor/` директорій
- Вимкнені небезпечні PHP функції (exec, shell_exec, etc.)
- Security headers в Nginx

### Рекомендації

1. **Змініть паролі** — використовуйте надійні паролі (16+ символів)
2. **Обмежте phpMyAdmin** — в production використовуйте IP whitelist або basic auth
3. **Після встановлення** — видаліть папку `/install/`
4. **Оновлення** — регулярно оновлюйте OcStore та Docker образи

---

## Команди

### Запуск
```bash
docker compose up -d
```

### Зупинка
```bash
docker compose down
```

### Перегляд логів
```bash
docker compose logs -f opencart
docker compose logs -f mariadb
```

### Перезбірка образу
```bash
docker compose up -d --build
```

### Видалення з даними
```bash
docker compose down -v
```

---

## Вирішення проблем

### OpenCart показує помилку підключення до БД

Перевірте що MariaDB запущена і healthy:
```bash
docker compose ps
```

Перевірте credentials в `.env` та налаштуваннях OpenCart.

### Помилка прав доступу

Зайдіть в контейнер і виправте права:
```bash
docker compose exec opencart sh
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 777 /var/www/html/system/storage
```

### Повільна робота

1. Збільшіть `innodb_buffer_pool_size` в `docker/mariadb/my.cnf`
2. Перевірте що OPcache увімкнений
3. Увімкніть Redis для сесій (опціонально)

---

## Ліцензія

OcStore поширюється під ліцензією [GNU General Public License v3.0](https://github.com/ocStore/ocStore/blob/master/license.txt).
