#!/bin/sh
set -e

# OpenCart Docker Entrypoint Script
# Handles initialization and configuration

echo "=== OpenCart Docker Entrypoint ==="
echo "=== Diagnostic Information ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""
echo "=== Database Configuration ==="
echo "DB_HOST: ${DB_HOST:-not set}"
echo "DB_PORT: ${DB_PORT:-3306}"
echo "DB_DATABASE: ${DB_DATABASE:-not set}"
echo "DB_USERNAME: ${DB_USERNAME:-not set}"
echo "DB_PASSWORD: ${DB_PASSWORD:+***SET***}"
echo "DB_PASSWORD length: ${#DB_PASSWORD} characters"
echo ""
echo "=== Network Diagnostics ==="

# DNS resolution test
if [ -n "$DB_HOST" ]; then
    echo "Resolving $DB_HOST..."
    if nslookup "$DB_HOST" 2>/dev/null; then
        echo "DNS resolution: OK"
    elif getent hosts "$DB_HOST" 2>/dev/null; then
        echo "DNS resolution via getent: OK"
        getent hosts "$DB_HOST"
    else
        echo "DNS resolution: FAILED"
        echo "Trying ping..."
        ping -c 1 "$DB_HOST" 2>&1 || echo "Ping failed"
    fi
fi

echo ""

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
        echo "WARNING: Could not connect to database port after $MAX_TRIES attempts"
    else
        # Test actual MySQL connection
        echo ""
        echo "=== Testing MySQL Connection ==="
        if command -v mysql >/dev/null 2>&1; then
            echo "Testing connection with provided credentials..."
            if mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" 2>&1; then
                echo "MySQL connection: SUCCESS"
            else
                echo "MySQL connection: FAILED"
                echo "Trying without password..."
                if mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USERNAME" -e "SELECT 1;" "$DB_DATABASE" 2>&1; then
                    echo "Connection WITHOUT password: SUCCESS"
                    echo "!!! DATABASE HAS NO PASSWORD SET !!!"
                else
                    echo "Connection without password also failed"
                fi
                echo ""
                echo "Trying as root..."
                mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u root -p"${DB_ROOT_PASSWORD:-}" -e "SELECT User, Host FROM mysql.user;" 2>&1 || echo "Root connection failed"
            fi
        else
            echo "mysql client not installed, skipping connection test"
        fi
    fi
fi

# Set ownership for the entire web root
chown -R www-data:www-data /var/www/html

echo "=== Starting services ==="

# Execute the main command
exec "$@"
