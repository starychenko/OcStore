# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OcStore is a fully automated Docker-based deployment for OpenCart (OcStore). Supports two versions via separate docker-compose files:

- **OcStore 3.x** (v3.0.4.1) — `docker-compose.yml`, PHP 8.1-FPM, OPcache+JIT, ionCube, Xdebug
- **OcStore 2.3** (v2.3.0.2.4) — `docker-compose.v2.yml`, PHP 7.2-FPM, OPcache, Xdebug

Production-ready infrastructure with Coolify-compatible configuration. Both versions can run simultaneously on the same server without conflicts.

**Stack (v3):** PHP 8.1-FPM (Debian Bookworm), Nginx, MariaDB 10.6, Supervisor, OPcache+JIT, Xdebug (optional), ionCube Loader, FileBrowser
**Stack (v2.3):** PHP 7.2-FPM (Debian Buster), Nginx, MariaDB 10.6, Supervisor, OPcache, Xdebug (optional), FileBrowser

## Build & Run Commands

```bash
# Local development (OcStore 3.x — default)
cp .env.example .env
docker compose up -d --build

# Local development (OcStore 2.3)
cp .env.example .env
docker compose -f docker-compose.v2.yml up -d --build

# View logs
docker compose logs -f opencart       # v3
docker compose -f docker-compose.v2.yml logs -f opencartv2  # v2.3

# Rebuild after changes
docker compose up -d --build

# Full cleanup (removes data)
docker compose down -v

# Check PHP extensions
docker exec ocstore-opencart-1 php -m

# Check JIT status (v3 only)
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

**v2.3 uses separate service/volume names:** `opencartv2`, `mariadbv2`, `filebrowserv2`, `phpmyadminv2`, `opencartv2_html`, etc. This prevents Traefik routing conflicts when both versions run on the same server.

**Container Initialization Flow** (`docker/entrypoint.sh` for v3, `docker/entrypoint.v2.sh` for v2.3):
1. Toggle Xdebug based on `XDEBUG_ENABLED` env var (v3 also toggles ionCube)
2. Create storage directories (`/var/www/storage/`)
3. Wait for database (30 attempts x 2s)
4. Check if OpenCart installed (query `{DB_PREFIX}setting` table)
   - If tables exist -> regenerate config.php only (no reinstall)
   - If fresh -> run CLI installer, then regenerate config.php
5. Generate `config.php` files with env vars (v2.3 uses different config format)
6. Remove `/install/` directory for security

**Key Paths:**
- `/var/www/html/` - webroot (OpenCart files)
- `/var/www/storage/` - user data outside webroot (secure)
- `/var/www/html/image/` - product images

## Configuration Files

| File | Purpose |
|------|---------|
| `Dockerfile` | OcStore 3.x -- PHP 8.1-FPM image with extensions |
| `Dockerfile.v2` | OcStore 2.3 -- PHP 7.2-FPM image with extensions |
| `docker-compose.yml` | v3: service definitions (opencart, mariadb, etc.) |
| `docker-compose.v2.yml` | v2.3: service definitions (opencartv2, mariadbv2, etc.) |
| `docker/entrypoint.sh` | v3: auto-install, config generation, Xdebug/ionCube toggle |
| `docker/entrypoint.v2.sh` | v2.3: auto-install, v2.3 config format, Xdebug toggle |
| `docker/nginx/default.conf` | SEO URLs, caching, security headers, HTTPS/SSL params (shared) |
| `docker/php/php.ini` | v3: OPcache, JIT, Xdebug settings |
| `docker/php/php.v2.ini` | v2.3: OPcache (no JIT), Xdebug settings |
| `docker/php/php-fpm.conf` | v3: Worker pool configuration |
| `docker/php/php-fpm.v2.conf` | v2.3: Worker pool configuration (PHP 7.2 compatible) |
| `docker/mariadb/my.cnf` | InnoDB optimization (shared) |

## Environment Variables

**Required:** `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `OPENCART_URL`, `ADMIN_PASSWORD`

**Optional:** `DB_DATABASE=opencart`, `DB_USERNAME=opencart`, `DB_PREFIX=oc_`, `ADMIN_USERNAME=admin`, `ADMIN_EMAIL=admin@example.com`, `XDEBUG_ENABLED=0`

**Important:** No special shell characters (`$`, `#`, `!`, `@`, `` ` ``, `\`) in passwords - they get interpreted by shell.

## Xdebug vs JIT

Xdebug and JIT are incompatible (v3 only -- v2.3 has no JIT). Xdebug is **disabled by default** for production performance.

**OcStore 3.x:**

| XDEBUG_ENABLED | Xdebug | JIT | Use Case |
|----------------|--------|-----|----------|
| `0` (default) | Off | On | Production |
| `1` | On | Off | Development debugging |

**OcStore 2.3:** JIT unavailable (PHP 7.2). Xdebug toggle works the same way. No ionCube support.

## Key Behaviors

- **Redeploy-safe:** Script checks DB for existing tables before reinstalling
- **Auto-install:** No web wizard needed, uses OpenCart CLI installer
- **Health check:** 300s start period to allow initialization
- **Storage:** Moved outside webroot to `/var/www/storage/`
- **SSL termination:** Nginx passes HTTPS/443 params to PHP for reverse proxy compatibility

## Coolify Deployment

### OcStore 3.x
1. Docker Compose build pack, file: `docker-compose.yml`
2. Set environment variables in Coolify UI
3. Configure domains: `opencart` -> shop.example.com, `phpmyadmin` -> pma.example.com, `filebrowser` -> files.example.com
4. Deploy

### OcStore 2.3
1. Docker Compose build pack, file: `docker-compose.v2.yml`
2. Set environment variables in Coolify UI
3. Configure domains: `opencartv2` -> shop2.example.com, `phpmyadminv2` -> pma2.example.com, `filebrowserv2` -> files2.example.com
4. Deploy

**Both can run on the same server** -- service names and volumes are fully isolated.

## FileBrowser

- **Image:** `hurlenko/filebrowser`
- **Internal port:** 8080
- **Credentials:** admin / (random password in logs)
- **Volumes:** Shares html and storage volumes with OpenCart container
- **Access in container:** `/data/html` and `/data/storage`
