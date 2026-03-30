# Optional OcStore 2.3 Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional OcStore 2.3 (v2.3.0.2.4) Docker build alongside existing OcStore 3.x, selectable via a single env variable.

**Architecture:** Two separate Dockerfiles (`Dockerfile` for v3, `Dockerfile.v2` for v2.3) sharing one `docker-compose.yml`. Version selected via `DOCKERFILE=Dockerfile.v2` in `.env`. Shared infrastructure (MariaDB, phpMyAdmin, FileBrowser, Nginx config, volumes) unchanged.

**Tech Stack:** Docker, PHP 7.2-FPM (Debian Buster), Nginx, MariaDB 10.6, Supervisor, OPcache, Xdebug 3.1.6

---

### Task 1: Create `docker/php/php.v2.ini`

**Files:**
- Create: `docker/php/php.v2.ini`

This is the PHP configuration for OcStore 2.3 on PHP 7.2. Based on the existing `docker/php/php.ini` but without JIT settings (unavailable in PHP 7.2) and without ionCube section.

- [ ] **Step 1: Create `docker/php/php.v2.ini`**

```ini
; PHP Configuration for OcStore 2.3 (ocStore)
; PHP 7.2 - No JIT support, no ionCube

;--------------------------------------------
; Memory and Execution Limits
;--------------------------------------------
memory_limit = 1G
max_execution_time = 600
max_input_time = 600
max_input_vars = 20000

;--------------------------------------------
; Upload Settings
;--------------------------------------------
upload_max_filesize = 256M
post_max_size = 256M
max_file_uploads = 100

;--------------------------------------------
; Error Handling (Production)
;--------------------------------------------
display_errors = On
display_startup_errors = On
log_errors = On
error_log = /var/log/php/error.log
error_reporting = E_ALL
html_errors = On

;--------------------------------------------
; Security Settings
;--------------------------------------------
expose_php = Off
allow_url_fopen = On
allow_url_include = Off
; Note: exec is needed for OpenCart CLI installer
disable_functions = passthru,shell_exec,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source

;--------------------------------------------
; Session Settings
;--------------------------------------------
session.auto_start = Off
session.use_only_cookies = On
session.use_cookies = On
session.use_trans_sid = Off
session.cookie_httponly = On
session.cookie_secure = On
session.cookie_samesite = Lax
session.gc_maxlifetime = 33600
session.gc_probability = 1
session.gc_divisor = 1000
session.save_handler = files
session.save_path = /var/www/html/system/storage/session

;--------------------------------------------
; Character Encoding
;--------------------------------------------
default_charset = UTF-8
mbstring.language = UTF-8
mbstring.internal_encoding = UTF-8
mbstring.http_input = UTF-8
mbstring.http_output = UTF-8
mbstring.detect_order = auto

;--------------------------------------------
; Date/Time Settings
;--------------------------------------------
date.timezone = Europe/Kyiv

;--------------------------------------------
; OPcache Settings (no JIT in PHP 7.2)
;--------------------------------------------
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 20000
opcache.max_wasted_percentage = 10
opcache.revalidate_freq = 2
opcache.validate_timestamps = 1
opcache.save_comments = 1
opcache.enable_file_override = 1

;--------------------------------------------
; Realpath Cache (Performance)
;--------------------------------------------
realpath_cache_size = 4096K
realpath_cache_ttl = 600

;--------------------------------------------
; Output Buffering
;--------------------------------------------
output_buffering = 4096
implicit_flush = Off

;--------------------------------------------
; Zlib Compression
;--------------------------------------------
zlib.output_compression = On
zlib.output_compression_level = 6

;--------------------------------------------
; cURL Settings
;--------------------------------------------
curl.cainfo = /etc/ssl/certs/ca-certificates.crt

;--------------------------------------------
; GD Settings
;--------------------------------------------
gd.jpeg_ignore_warning = 1

;--------------------------------------------
; Xdebug Settings (only active when XDEBUG_ENABLED=1)
;--------------------------------------------
; Xdebug is disabled by default for performance
; To enable: set environment variable XDEBUG_ENABLED=1
[xdebug]
xdebug.mode = debug,develop
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.idekey = VSCODE
xdebug.log = /var/log/php/xdebug.log
xdebug.log_level = 3
```

Key differences from v3 `php.ini`:
- No JIT section (`opcache.jit`, `opcache.jit_buffer_size`)
- No ionCube section
- `mbstring.internal_encoding`/`http_input`/`http_output` explicitly set (not deprecated in PHP 7.2)
- Comment header references OcStore 2.3 / PHP 7.2

- [ ] **Step 2: Commit**

```bash
git add docker/php/php.v2.ini
git commit -m "feat: add PHP 7.2 config for OcStore 2.3 build"
```

---

### Task 2: Create `docker/entrypoint.v2.sh`

**Files:**
- Create: `docker/entrypoint.v2.sh`
- Reference: `docker/entrypoint.sh` (existing v3 entrypoint)
- Reference: `C:\nextcloud\OpenCart\OcStore\2.3.0.2.4\upload\install\cli_install.php` (v2.3 config format)

This entrypoint follows the same logic as the v3 version but generates v2.3-format `config.php` files. Key differences: no ionCube toggle, no JIT toggle, different config.php constants (has `HTTP_ADMIN`, `DIR_DATABASE`, no `DIR_STORAGE`, no `DIR_SESSION`), fewer storage directories.

- [ ] **Step 1: Create `docker/entrypoint.v2.sh`**

```bash
#!/bin/bash
set -e

# OcStore 2.3 Docker Entrypoint Script
# Fully automated installation and configuration
# Supports redeploys without data loss

echo "=============================================="
echo "  OcStore 2.3 Docker - Automated Setup"
echo "=============================================="
echo "Date: $(date)"
echo ""

# --- Configuration ---
DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_DATABASE="${DB_DATABASE:-opencart}"
DB_USERNAME="${DB_USERNAME:-opencart}"
DB_PREFIX="${DB_PREFIX:-oc_}"
OPENCART_URL="${OPENCART_URL:-http://localhost}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# --- Create directories ---
mkdir -p /var/log/nginx /var/log/php /var/log/supervisor /run/nginx

# --- Initialize html volume (first deploy only) ---
if [ ! -f "/var/www/html/index.php" ]; then
    echo "[0/5] First deploy detected - initializing html volume..."
    if [ -d "/var/www/html-dist" ] && [ -f "/var/www/html-dist/index.php" ]; then
        cp -r /var/www/html-dist/* /var/www/html/
        chown -R www-data:www-data /var/www/html
        echo "      OcStore 2.3 files copied to volume"
    else
        echo "      ERROR: Distribution files not found!"
        exit 1
    fi
else
    echo "[0/5] Existing installation detected - preserving files"
fi

# --- Xdebug toggle (disabled by default) ---
XDEBUG_ENABLED="${XDEBUG_ENABLED:-0}"
XDEBUG_INI="/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini"

if [ "$XDEBUG_ENABLED" = "1" ] || [ "$XDEBUG_ENABLED" = "true" ]; then
    echo "[INFO] Xdebug ENABLED"
    if [ -f "${XDEBUG_INI}.disabled" ]; then
        mv "${XDEBUG_INI}.disabled" "$XDEBUG_INI"
    fi
    touch /var/log/php/xdebug.log
    chown www-data:www-data /var/log/php/xdebug.log
    chmod 666 /var/log/php/xdebug.log
else
    echo "[INFO] Xdebug DISABLED"
    if [ -f "$XDEBUG_INI" ]; then
        mv "$XDEBUG_INI" "${XDEBUG_INI}.disabled"
    fi
fi

# Storage directories (secure location outside webroot)
# OcStore 2.3: no session/ or vendor/ directories
STORAGE_DIRS="cache download logs modification upload"
for dir in $STORAGE_DIRS; do
    mkdir -p "/var/www/storage/$dir"
done

# Image directories
mkdir -p /var/www/html/image/cache /var/www/html/image/catalog

# --- Migrate storage files ---
if [ -d "/var/www/html/system/storage/cache" ] && [ ! "$(ls -A /var/www/storage/cache 2>/dev/null)" ]; then
    echo "[1/5] Migrating storage files..."
    for dir in $STORAGE_DIRS; do
        if [ -d "/var/www/html/system/storage/$dir" ]; then
            cp -r "/var/www/html/system/storage/$dir/"* "/var/www/storage/$dir/" 2>/dev/null || true
        fi
    done
    echo "      Done!"
else
    echo "[1/5] Storage already migrated"
fi

# Set permissions
chown -R www-data:www-data /var/www/storage /var/www/html
chmod -R 777 /var/www/storage

# --- Wait for database ---
echo "[2/5] Waiting for database..."
MAX_TRIES=30
TRIES=0
while [ $TRIES -lt $MAX_TRIES ]; do
    if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
        echo "      Database is ready!"
        break
    fi
    TRIES=$((TRIES + 1))
    sleep 2
done

if [ $TRIES -eq $MAX_TRIES ]; then
    echo "      WARNING: Database not available after $MAX_TRIES attempts"
fi

# Wait a bit more for database to be fully ready
sleep 3

# --- Check if OpenCart is already installed (by checking database tables) ---
check_database_installed() {
    TABLES=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" \
        -e "SHOW TABLES LIKE '${DB_PREFIX}setting';" 2>/dev/null | grep -c "${DB_PREFIX}setting" || echo "0")

    if [ "$TABLES" -gt 0 ]; then
        return 0
    fi
    return 1
}

# --- Generate config.php from environment (OcStore 2.3 format) ---
generate_config() {
    echo "      Generating config.php (OcStore 2.3 format)..."

    cat > /var/www/html/config.php << EOFCONFIG
<?php
// HTTP
define('HTTP_SERVER', '${OPENCART_URL}/');
define('HTTP_ADMIN', '${OPENCART_URL}/admin/');

// HTTPS
define('HTTPS_SERVER', '${OPENCART_URL}/');

// DIR
define('DIR_APPLICATION', '/var/www/html/catalog/');
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_DATABASE', '/var/www/html/system/database/');
define('DIR_LANGUAGE', '/var/www/html/catalog/language/');
define('DIR_TEMPLATE', '/var/www/html/catalog/view/theme/');
define('DIR_CONFIG', '/var/www/html/system/config/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_CACHE', '/var/www/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/storage/download/');
define('DIR_UPLOAD', '/var/www/storage/upload/');
define('DIR_MODIFICATION', '/var/www/storage/modification/');
define('DIR_LOGS', '/var/www/storage/logs/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${DB_HOST}');
define('DB_USERNAME', '${DB_USERNAME}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_DATABASE', '${DB_DATABASE}');
define('DB_PREFIX', '${DB_PREFIX}');
define('DB_PORT', '${DB_PORT}');

// Redis
// define('CACHE_HOSTNAME', 'localhost');
// define('CACHE_PORT', '6379');
// define('CACHE_PREFIX', 'oc_');
?>
EOFCONFIG

    cat > /var/www/html/admin/config.php << EOFADMINCONFIG
<?php
// HTTP
define('HTTP_SERVER', '${OPENCART_URL}/admin/');
define('HTTP_CATALOG', '${OPENCART_URL}/');

// HTTPS
define('HTTPS_SERVER', '${OPENCART_URL}/admin/');
define('HTTPS_CATALOG', '${OPENCART_URL}/');

// DIR
define('DIR_APPLICATION', '/var/www/html/admin/');
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_DATABASE', '/var/www/html/system/database/');
define('DIR_LANGUAGE', '/var/www/html/admin/language/');
define('DIR_TEMPLATE', '/var/www/html/admin/view/template/');
define('DIR_CONFIG', '/var/www/html/system/config/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_CACHE', '/var/www/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/storage/download/');
define('DIR_UPLOAD', '/var/www/storage/upload/');
define('DIR_LOGS', '/var/www/storage/logs/');
define('DIR_MODIFICATION', '/var/www/storage/modification/');
define('DIR_CATALOG', '/var/www/html/catalog/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${DB_HOST}');
define('DB_USERNAME', '${DB_USERNAME}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_DATABASE', '${DB_DATABASE}');
define('DB_PREFIX', '${DB_PREFIX}');
define('DB_PORT', '${DB_PORT}');

// OpenCartForum API
define('OPENCARTFORUM_SERVER', 'https://opencartforum.com/');
?>
EOFADMINCONFIG

    chown www-data:www-data /var/www/html/config.php /var/www/html/admin/config.php
    chmod 644 /var/www/html/config.php /var/www/html/admin/config.php
    echo "      Done!"
}

# --- Auto-install or restore OpenCart ---
echo "[3/5] Checking OcStore 2.3 installation..."

if check_database_installed; then
    echo "      Database has existing OpenCart tables"
    echo "      Skipping installation, regenerating config files..."
    generate_config
else
    echo "      Fresh installation required..."

    if [ -f "/var/www/html/install/cli_install.php" ]; then
        INSTALL_OUTPUT=$(php /var/www/html/install/cli_install.php install \
            --db_driver mysqli \
            --db_hostname "$DB_HOST" \
            --db_username "$DB_USERNAME" \
            --db_password "$DB_PASSWORD" \
            --db_database "$DB_DATABASE" \
            --db_port "$DB_PORT" \
            --db_prefix "$DB_PREFIX" \
            --username "$ADMIN_USERNAME" \
            --password "$ADMIN_PASSWORD" \
            --email "$ADMIN_EMAIL" \
            --http_server "$OPENCART_URL/" \
            2>&1) && INSTALL_SUCCESS=true || INSTALL_SUCCESS=false

        echo "$INSTALL_OUTPUT"

        if [ "$INSTALL_SUCCESS" = true ] && check_database_installed; then
            echo "      Installation successful!"
        else
            echo "      WARNING: Installation may have failed. Check logs above."
        fi
    else
        echo "      WARNING: CLI installer not found"
        echo "      Generating config files anyway..."
        generate_config
    fi
fi

# --- Update storage path in config ---
echo "[4/5] Configuring storage path..."
for config_file in /var/www/html/config.php /var/www/html/admin/config.php; do
    if [ -f "$config_file" ]; then
        # Update storage paths if using old in-webroot location
        sed -i "s|/var/www/html/system/storage/cache/|/var/www/storage/cache/|g" "$config_file"
        sed -i "s|/var/www/html/system/storage/download/|/var/www/storage/download/|g" "$config_file"
        sed -i "s|/var/www/html/system/storage/upload/|/var/www/storage/upload/|g" "$config_file"
        sed -i "s|/var/www/html/system/storage/modification/|/var/www/storage/modification/|g" "$config_file"
        sed -i "s|/var/www/html/system/storage/logs/|/var/www/storage/logs/|g" "$config_file"
    fi
done
echo "      Done!"

# --- Remove install directory ---
echo "[5/5] Security cleanup..."
if [ -d "/var/www/html/install" ]; then
    rm -rf /var/www/html/install
    echo "      Removed install directory"
fi
echo "      Done!"

# --- Final permissions ---
chown -R www-data:www-data /var/www/html /var/www/storage

# --- Summary ---
echo ""
echo "=============================================="
echo "  OcStore 2.3 Setup Complete!"
echo "=============================================="
echo "  Store URL:  $OPENCART_URL"
echo "  Admin URL:  $OPENCART_URL/admin"
echo "  Admin User: $ADMIN_USERNAME"
echo "  Database:   $DB_DATABASE @ $DB_HOST"
echo "=============================================="
echo ""

# Start services
exec "$@"
```

Note on storage path migration: The v2.3 CLI installer writes config with paths like `/var/www/html/system/storage/cache/`. Step [4/5] rewrites these to `/var/www/storage/cache/` so storage stays outside the webroot, matching our Docker volume setup. The `generate_config` function already uses the correct `/var/www/storage/` paths, so this sed replacement only applies when the CLI installer ran.

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x docker/entrypoint.v2.sh
git add docker/entrypoint.v2.sh
git commit -m "feat: add entrypoint for OcStore 2.3 with v2.3 config format"
```

---

### Task 3: Create `Dockerfile.v2`

**Files:**
- Create: `Dockerfile.v2`
- Reference: `Dockerfile` (existing v3 Dockerfile)

This Dockerfile builds the OcStore 2.3 image using PHP 7.2. It follows the same structure as the v3 Dockerfile but uses Debian Buster, installs Xdebug 3.1.6 (last version supporting PHP 7.2), skips ionCube, and downloads from the myopencart/ocStore repo.

- [ ] **Step 1: Create `Dockerfile.v2`**

```dockerfile
# OcStore 2.3 Docker Image
# PHP 7.2-FPM (Debian Buster) + Nginx + All required extensions + Xdebug

FROM php:7.2-fpm-buster AS base

# Install system dependencies and runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    curl \
    unzip \
    git \
    default-mysql-client \
    dnsutils \
    netcat-openbsd \
    # Runtime libraries for PHP extensions
    libpng16-16 \
    libjpeg62-turbo \
    libwebp6 \
    libfreetype6 \
    libzip4 \
    libicu63 \
    libxml2 \
    libonig5 \
    && rm -rf /var/lib/apt/lists/*

# Install build dependencies and PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-webp-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) \
        gd \
        mysqli \
        pdo_mysql \
        zip \
        intl \
        xml \
        mbstring \
        opcache \
        bcmath \
        exif \
    # Install Xdebug (3.1.6 = last version supporting PHP 7.2)
    && pecl install xdebug-3.1.6 \
    && docker-php-ext-enable xdebug \
    # Cleanup build dependencies only
    && apt-get purge -y \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        libonig-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/php \
    && mkdir -p /run/nginx

# Remove default nginx config
RUN rm -f /etc/nginx/sites-enabled/default

# Copy configuration files
COPY docker/nginx/default.conf /etc/nginx/sites-enabled/default
COPY docker/php/php.v2.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Download and extract OcStore 2.3 to distribution directory
ARG OCSTORE_VERSION=2.3.0.2.4
RUN curl -L https://github.com/myopencart/ocStore/archive/refs/tags/v${OCSTORE_VERSION}.zip -o /tmp/ocstore.zip \
    && unzip /tmp/ocstore.zip -d /tmp \
    && mkdir -p /var/www/html-dist \
    && cp -r /tmp/ocStore-${OCSTORE_VERSION}/upload/* /var/www/html-dist/ \
    && rm -rf /tmp/ocstore.zip /tmp/ocStore-${OCSTORE_VERSION}

# Create storage directory structure
# OcStore 2.3: no session/ or vendor/ directories
RUN mkdir -p /var/www/storage/cache \
    && mkdir -p /var/www/storage/download \
    && mkdir -p /var/www/storage/logs \
    && mkdir -p /var/www/storage/modification \
    && mkdir -p /var/www/storage/upload \
    && mkdir -p /var/www/html-dist/system/storage/cache \
    && mkdir -p /var/www/html-dist/system/storage/download \
    && mkdir -p /var/www/html-dist/system/storage/logs \
    && mkdir -p /var/www/html-dist/system/storage/modification \
    && mkdir -p /var/www/html-dist/system/storage/upload \
    && mkdir -p /var/www/html-dist/image/cache \
    && mkdir -p /var/www/html-dist/image/catalog

# Set permissions on distribution directory
RUN chown -R www-data:www-data /var/www/html-dist \
    && chown -R www-data:www-data /var/www/storage \
    && chmod -R 755 /var/www/html-dist \
    && chmod -R 777 /var/www/html-dist/system/storage \
    && chmod -R 777 /var/www/storage \
    && chmod -R 777 /var/www/html-dist/image/cache \
    && chmod -R 777 /var/www/html-dist/image/catalog \
    && touch /var/www/html-dist/config.php && chmod 666 /var/www/html-dist/config.php \
    && touch /var/www/html-dist/admin/config.php && chmod 666 /var/www/html-dist/admin/config.php

# Copy entrypoint script
COPY docker/entrypoint.v2.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

Key differences from v3 `Dockerfile`:
- Base image: `php:7.2-fpm-buster` (not `php:8.1-fpm-bookworm`)
- Library versions: `libwebp6` (not `libwebp7`), `libicu63` (not `libicu72`)
- GD configure: uses `--with-freetype-dir`/`--with-jpeg-dir`/`--with-webp-dir` (PHP 7.2 syntax, changed in PHP 8.0)
- Xdebug: `pecl install xdebug-3.1.6` (pinned version)
- No ionCube Loader installation
- OcStore URL: `myopencart/ocStore` repo, version `2.3.0.2.4`
- No `session/` or `vendor/` storage directories
- Uses `php.v2.ini` and `entrypoint.v2.sh`

- [ ] **Step 2: Commit**

```bash
git add Dockerfile.v2
git commit -m "feat: add Dockerfile for OcStore 2.3 (PHP 7.2)"
```

---

### Task 4: Modify `docker-compose.yml` and `.env.example`

**Files:**
- Modify: `docker-compose.yml:8` (build section)
- Modify: `.env.example:1-9` (add DOCKERFILE variable at top)

- [ ] **Step 1: Update `docker-compose.yml` build section**

Change the `opencart` service build from:

```yaml
    build:
      context: .
      dockerfile: Dockerfile
```

To:

```yaml
    build:
      context: .
      dockerfile: ${DOCKERFILE:-Dockerfile}
```

This is the only change to `docker-compose.yml`. When `DOCKERFILE` is not set, it defaults to `Dockerfile` (v3), preserving existing behavior.

- [ ] **Step 2: Update `.env.example` — add version selection section**

Add at the very top of `.env.example`, before the existing content:

```env
# =============================================
# Версія OcStore
# =============================================
# Dockerfile      = OcStore 3.x (PHP 8.1) — за замовчуванням
# Dockerfile.v2   = OcStore 2.3 (PHP 7.2)
DOCKERFILE=Dockerfile

```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml .env.example
git commit -m "feat: add DOCKERFILE env var for OcStore version selection"
```

---

### Task 5: Build and test OcStore 2.3 image

**Files:** None (verification only)

- [ ] **Step 1: Test that default build (v3) still works**

```bash
docker compose build opencart
```

Expected: Successful build using `Dockerfile` (PHP 8.1, OcStore 3.x). No changes to existing behavior.

- [ ] **Step 2: Test v2.3 build**

Create a test `.env` or override:

```bash
DOCKERFILE=Dockerfile.v2 docker compose build opencart
```

Expected: Successful build using `Dockerfile.v2` (PHP 7.2, OcStore 2.3). Watch for:
- PHP extensions all install successfully
- OcStore 2.3 archive downloads and extracts
- Xdebug 3.1.6 installs
- No errors in build output

- [ ] **Step 3: Test v2.3 container startup**

```bash
DOCKERFILE=Dockerfile.v2 docker compose up -d
docker compose logs -f opencart
```

Expected output should show:
- "OcStore 2.3 Docker - Automated Setup"
- Database connection successful
- Either fresh install or config regeneration
- "OcStore 2.3 Setup Complete!"
- Admin panel accessible at `{OPENCART_URL}/admin`

- [ ] **Step 4: Verify admin panel loads**

Open browser to `{OPENCART_URL}/admin` and verify login page loads. Log in with admin credentials.

- [ ] **Step 5: Clean up test environment**

```bash
docker compose down -v
```
