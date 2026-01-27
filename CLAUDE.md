# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OcStore is a fully automated Docker-based deployment for OpenCart 3 (v3.0.4.1). It provides production-ready infrastructure with Coolify-compatible configuration.

**Stack:** PHP 8.1-FPM (Debian), Nginx, MariaDB 10.6, Supervisor, OPcache+JIT, Xdebug (optional), ionCube Loader, FileBrowser

## Build & Run Commands

```bash
# Local development
cp .env.example .env
docker compose up -d --build

# View logs
docker compose logs -f opencart

# Rebuild after changes
docker compose up -d --build

# Full cleanup (removes data)
docker compose down -v

# Check PHP extensions
docker exec ocstore-opencart-1 php -m

# Check JIT status
docker exec ocstore-opencart-1 php -r "var_dump(opcache_get_status()['jit']);"

# Execute command in container
docker exec -it ocstore-opencart-1 bash
```

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Docker Compose                               │
├─────────────────┬─────────────────┬───────────────┬──────────────────┤
│   opencart      │    mariadb      │  phpmyadmin   │   filebrowser    │
│   (PHP+Nginx)   │    (Database)   │   (DB UI)     │  (File Manager)  │
│   Port 80       │    Port 3306    │   Port 80     │   Port 8080      │
│                 │    (internal)   │               │                  │
└────────┬────────┴────────┬────────┴───────────────┴────────┬─────────┘
         │                 │                                  │
    Volumes:          Volume:                            Volumes:
    - opencart_storage    - mariadb_data                 - opencart_html:/data/html
    - opencart_html                                      - opencart_storage:/data/storage
                                                         - filebrowser_data:/config
```

**Container Initialization Flow** (`docker/entrypoint.sh`):
1. Toggle Xdebug based on `XDEBUG_ENABLED` env var
2. Create storage directories (`/var/www/storage/`)
3. Wait for database (30 attempts × 2s)
4. Check if OpenCart installed (query `{DB_PREFIX}setting` table)
   - If tables exist → regenerate config.php only (no reinstall)
   - If fresh → run CLI installer
5. Generate `config.php` files with env vars
6. Remove `/install/` directory for security

**Key Paths:**
- `/var/www/html/` - webroot (OpenCart files)
- `/var/www/storage/` - user data outside webroot (secure)
- `/var/www/html/image/` - product images

## Configuration Files

| File | Purpose |
|------|---------|
| `Dockerfile` | PHP 8.1-FPM image with extensions |
| `docker-compose.yml` | Service definitions, health checks |
| `docker/entrypoint.sh` | Auto-install, config generation, Xdebug toggle |
| `docker/nginx/default.conf` | SEO URLs, caching, security headers |
| `docker/php/php.ini` | OPcache, JIT, Xdebug settings |
| `docker/php/php-fpm.conf` | Worker pool configuration |
| `docker/mariadb/my.cnf` | InnoDB optimization |

## Environment Variables

**Required:** `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `OPENCART_URL`, `ADMIN_PASSWORD`

**Optional:** `DB_DATABASE=opencart`, `DB_USERNAME=opencart`, `DB_PREFIX=oc_`, `ADMIN_USERNAME=admin`, `ADMIN_EMAIL=admin@example.com`, `XDEBUG_ENABLED=0`

**Important:** No special shell characters (`$`, `#`, `!`, `@`, `` ` ``, `\`) in passwords - they get interpreted by shell.

## Xdebug vs JIT

Xdebug and JIT are incompatible. Xdebug is **disabled by default** for production performance.

| XDEBUG_ENABLED | Xdebug | JIT | Use Case |
|----------------|--------|-----|----------|
| `0` (default) | Off | On | Production |
| `1` | On | Off | Development debugging |

## Key Behaviors

- **Redeploy-safe:** Script checks DB for existing tables before reinstalling
- **Auto-install:** No web wizard needed, uses OpenCart CLI installer
- **Health check:** 300s start period to allow initialization
- **Storage:** Moved outside webroot to `/var/www/storage/`

## Coolify Deployment

1. Docker Compose build pack
2. Set environment variables in Coolify UI
3. Configure domains:
   - `opencart` → shop.example.com
   - `phpmyadmin` → pma.example.com
   - `filebrowser` → files.example.com
4. Deploy - fully automated in 3-5 minutes

## FileBrowser

- **Image:** `hurlenko/filebrowser`
- **Internal port:** 8080
- **Credentials:** admin / (random password in logs)
- **Volumes:** Shares `opencart_html` and `opencart_storage` with OpenCart container
- **Access in container:** `/data/html` and `/data/storage`
