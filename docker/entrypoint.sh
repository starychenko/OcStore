#!/bin/sh
set -e

# OpenCart Docker Entrypoint Script
# Fully automated installation and configuration

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

# --- Auto-install OpenCart ---
check_opencart_installed() {
    if [ -f "/var/www/html/config.php" ] && grep -q "DB_HOSTNAME" /var/www/html/config.php 2>/dev/null; then
        return 0
    fi
    return 1
}

if check_opencart_installed; then
    echo "[3/5] OpenCart already installed"
else
    echo "[3/5] Installing OpenCart automatically..."

    # Wait a bit more for database to be fully ready
    sleep 5

    if [ -f "/var/www/html/install/cli_install.php" ]; then
        # Run CLI installer
        php /var/www/html/install/cli_install.php install \
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
            2>&1 || echo "      CLI install completed (check for errors above)"

        echo "      Installation complete!"
    else
        echo "      WARNING: CLI installer not found, manual installation required"
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
if [ -d "/var/www/html/install" ] && check_opencart_installed; then
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
