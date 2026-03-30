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
