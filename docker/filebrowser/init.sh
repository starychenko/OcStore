#!/bin/sh
# FileBrowser initialization script
# Creates default admin user if database doesn't exist

DB_PATH="/database/filebrowser.db"

if [ ! -f "$DB_PATH" ]; then
    echo "Initializing FileBrowser database..."
    filebrowser config init --database "$DB_PATH"
    filebrowser config set --database "$DB_PATH" --address 0.0.0.0 --port 80 --root /srv
    filebrowser users add admin admin --database "$DB_PATH" --perm.admin
    echo "Created admin user (login: admin, password: admin)"
fi

exec filebrowser --database "$DB_PATH"
