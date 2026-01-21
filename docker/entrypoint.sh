#!/bin/bash
set -e

# OpenCart Docker Entrypoint Script
# Fully automated installation and configuration
# Supports redeploys without data loss

echo "=============================================="
echo "  OpenCart Docker - Automated Setup"
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

# --- Xdebug toggle (disabled by default for JIT compatibility) ---
XDEBUG_ENABLED="${XDEBUG_ENABLED:-0}"
XDEBUG_INI="/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini"

if [ "$XDEBUG_ENABLED" = "1" ] || [ "$XDEBUG_ENABLED" = "true" ]; then
    echo "[INFO] Xdebug ENABLED (JIT will be disabled)"
    # Ensure xdebug is enabled
    if [ -f "${XDEBUG_INI}.disabled" ]; then
        mv "${XDEBUG_INI}.disabled" "$XDEBUG_INI"
    fi
    # Create xdebug log file
    touch /var/log/php/xdebug.log
    chown www-data:www-data /var/log/php/xdebug.log
    chmod 666 /var/log/php/xdebug.log
else
    echo "[INFO] Xdebug DISABLED (JIT enabled for performance)"
    # Disable xdebug by renaming config
    if [ -f "$XDEBUG_INI" ]; then
        mv "$XDEBUG_INI" "${XDEBUG_INI}.disabled"
    fi
fi

# Storage directories (secure location outside webroot)
STORAGE_DIRS="cache download logs modification session upload"
for dir in $STORAGE_DIRS; do
    mkdir -p "/var/www/storage/$dir"
done

# Image directories
mkdir -p /var/www/html/image/cache /var/www/html/image/catalog

# --- Migrate storage files ---
if [ -d "/var/www/html/system/storage/vendor" ] && [ ! -d "/var/www/storage/vendor" ]; then
    echo "[1/5] Migrating storage files..."
    cp -r /var/www/html/system/storage/* /var/www/storage/
    echo "      Done!"
else
    echo "[1/5] Storage already migrated"
fi

# Set permissions
chown -R www-data:www-data /var/www/storage /var/www/html
chmod -R 777 /var/www/storage
[ -d "/var/www/storage/vendor" ] && chmod -R 755 /var/www/storage/vendor

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
    # Check if setting table exists in database
    TABLES=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" \
        -e "SHOW TABLES LIKE '${DB_PREFIX}setting';" 2>/dev/null | grep -c "${DB_PREFIX}setting" || echo "0")

    if [ "$TABLES" -gt 0 ]; then
        return 0  # Database has OpenCart tables
    fi
    return 1  # No OpenCart tables found
}

# --- Generate config.php from environment ---
generate_config() {
    echo "      Generating config.php..."

    cat > /var/www/html/config.php << EOFCONFIG
<?php
// HTTP
define('HTTP_SERVER', '${OPENCART_URL}/');

// HTTPS
define('HTTPS_SERVER', '${OPENCART_URL}/');

// DIR
define('DIR_APPLICATION', '/var/www/html/catalog/');
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_STORAGE', '/var/www/storage/');
define('DIR_LANGUAGE', DIR_APPLICATION . 'language/');
define('DIR_TEMPLATE', DIR_APPLICATION . 'view/theme/');
define('DIR_CONFIG', DIR_SYSTEM . 'config/');
define('DIR_CACHE', DIR_STORAGE . 'cache/');
define('DIR_DOWNLOAD', DIR_STORAGE . 'download/');
define('DIR_LOGS', DIR_STORAGE . 'logs/');
define('DIR_MODIFICATION', DIR_STORAGE . 'modification/');
define('DIR_SESSION', DIR_STORAGE . 'session/');
define('DIR_UPLOAD', DIR_STORAGE . 'upload/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${DB_HOST}');
define('DB_USERNAME', '${DB_USERNAME}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_DATABASE', '${DB_DATABASE}');
define('DB_PORT', '${DB_PORT}');
define('DB_PREFIX', '${DB_PREFIX}');
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
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_STORAGE', '/var/www/storage/');
define('DIR_CATALOG', '/var/www/html/catalog/');
define('DIR_LANGUAGE', DIR_APPLICATION . 'language/');
define('DIR_TEMPLATE', DIR_APPLICATION . 'view/template/');
define('DIR_CONFIG', DIR_SYSTEM . 'config/');
define('DIR_CACHE', DIR_STORAGE . 'cache/');
define('DIR_DOWNLOAD', DIR_STORAGE . 'download/');
define('DIR_LOGS', DIR_STORAGE . 'logs/');
define('DIR_MODIFICATION', DIR_STORAGE . 'modification/');
define('DIR_SESSION', DIR_STORAGE . 'session/');
define('DIR_UPLOAD', DIR_STORAGE . 'upload/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${DB_HOST}');
define('DB_USERNAME', '${DB_USERNAME}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_DATABASE', '${DB_DATABASE}');
define('DB_PORT', '${DB_PORT}');
define('DB_PREFIX', '${DB_PREFIX}');

// OpenCart API
define('OPENCART_SERVER', 'https://www.opencart.com/');
EOFADMINCONFIG

    chown www-data:www-data /var/www/html/config.php /var/www/html/admin/config.php
    chmod 644 /var/www/html/config.php /var/www/html/admin/config.php
    echo "      Done!"
}

# --- Auto-install or restore OpenCart ---
echo "[3/5] Checking OpenCart installation..."

if check_database_installed; then
    echo "      Database has existing OpenCart tables"
    echo "      Skipping installation, regenerating config files..."
    generate_config
else
    echo "      Fresh installation required..."

    if [ -f "/var/www/html/install/cli_install.php" ]; then
        # Run CLI installer
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
        # Update storage path if using old location
        if grep -q "DIR_SYSTEM . 'storage/'" "$config_file" 2>/dev/null; then
            sed -i "s|define('DIR_STORAGE', DIR_SYSTEM . 'storage/')|define('DIR_STORAGE', '/var/www/storage/')|g" "$config_file"
            echo "      Updated: $config_file"
        fi
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
echo "  Setup Complete!"
echo "=============================================="
echo "  Store URL:  $OPENCART_URL"
echo "  Admin URL:  $OPENCART_URL/admin"
echo "  Admin User: $ADMIN_USERNAME"
echo "  Database:   $DB_DATABASE @ $DB_HOST"
echo "=============================================="
echo ""

# Start services
exec "$@"
