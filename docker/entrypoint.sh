#!/bin/sh
set -e

# OpenCart Docker Entrypoint Script
# Handles initialization and configuration

echo "=== OpenCart Docker Entrypoint ==="

# Create log directories if they don't exist
mkdir -p /var/log/nginx
mkdir -p /var/log/php
mkdir -p /var/log/supervisor
mkdir -p /run/nginx

# Ensure storage directories exist with correct permissions
STORAGE_DIRS="
/var/www/html/system/storage/cache
/var/www/html/system/storage/download
/var/www/html/system/storage/logs
/var/www/html/system/storage/modification
/var/www/html/system/storage/session
/var/www/html/system/storage/upload
/var/www/html/image/cache
/var/www/html/image/catalog
"

for dir in $STORAGE_DIRS; do
    mkdir -p "$dir"
    chown -R www-data:www-data "$dir"
    chmod -R 777 "$dir"
done

# Ensure config files exist and are writable
touch /var/www/html/config.php
touch /var/www/html/admin/config.php
chmod 666 /var/www/html/config.php
chmod 666 /var/www/html/admin/config.php

# Wait for database to be ready
if [ -n "$DB_HOST" ]; then
    echo "Waiting for database at $DB_HOST:${DB_PORT:-3306}..."

    MAX_TRIES=30
    TRIES=0

    while [ $TRIES -lt $MAX_TRIES ]; do
        if nc -z "$DB_HOST" "${DB_PORT:-3306}" 2>/dev/null; then
            echo "Database is available!"
            break
        fi

        TRIES=$((TRIES + 1))
        echo "Waiting for database... ($TRIES/$MAX_TRIES)"
        sleep 2
    done

    if [ $TRIES -eq $MAX_TRIES ]; then
        echo "Warning: Could not connect to database after $MAX_TRIES attempts"
    fi
fi

# Set ownership for the entire web root
chown -R www-data:www-data /var/www/html

echo "=== Starting services ==="

# Execute the main command
exec "$@"
