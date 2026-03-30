# Optional OcStore 2.3 Build Support

**Date:** 2026-03-30
**Status:** Draft

## Goal

Add optional support for building OcStore 2.3 (v2.3.0.2.4) alongside the existing OcStore 3.x (v3.0.4.1) using the same Docker infrastructure. Version selection via a single env variable.

## Constraints

- Existing v3 files must remain unchanged (except `docker-compose.yml` and `.env.example`)
- OcStore 2.3 requires PHP 5.4+ (we use PHP 7.2 as optimal)
- OcStore 3.x requires PHP 7.3+ (we use PHP 8.1)
- JIT does not exist in PHP 7.2
- ionCube Loader not needed for v2.3
- OcStore 2.3 source: `github.com/myopencart/ocStore` (different repo from v3)

## Architecture

### File Structure

```
├── Dockerfile              # OcStore 3.x (PHP 8.1) — unchanged
├── Dockerfile.v2           # OcStore 2.3 (PHP 7.2) — NEW
├── docker-compose.yml      # Modified: selects Dockerfile via env var
├── .env.example            # Modified: +DOCKERFILE variable
├── docker/
│   ├── entrypoint.sh       # v3 — unchanged
│   ├── entrypoint.v2.sh    # v2.3 — NEW
│   ├── nginx/default.conf  # shared — unchanged
│   ├── php/
│   │   ├── php.ini         # v3 (with JIT) — unchanged
│   │   ├── php.v2.ini      # v2.3 (no JIT) — NEW
│   │   ├── php-fpm.conf    # shared — unchanged
│   └── mariadb/my.cnf      # shared — unchanged
```

### Version Selection Mechanism

In `.env`:
```env
# Default: OcStore 3.x
DOCKERFILE=Dockerfile

# For OcStore 2.3:
DOCKERFILE=Dockerfile.v2
```

In `docker-compose.yml`:
```yaml
opencart:
  build:
    context: .
    dockerfile: ${DOCKERFILE:-Dockerfile}
```

This approach is simple, explicit, and doesn't require shell variable interpolation tricks.

### Shared Infrastructure

The following services are identical for both versions and require no changes:
- MariaDB 10.6 (compatible with both PHP versions)
- phpMyAdmin
- FileBrowser
- All volumes (opencart_storage, opencart_html, mariadb_data, filebrowser_data)
- Nginx config (SEO URLs, caching, security headers)
- MariaDB config (InnoDB optimization)
- PHP-FPM worker pool config

## New Files

### 1. Dockerfile.v2

Base image: `php:7.2-fpm-buster`

Differences from main `Dockerfile`:
- PHP 7.2 base image (Debian Buster, not Bookworm)
- No ionCube Loader installation
- Xdebug version compatible with PHP 7.2 (`pecl install xdebug-3.1.6`)
- OcStore download URL: `github.com/myopencart/ocStore/archive/refs/tags/v2.3.0.2.4.zip`
- Archive extracts to `ocStore-2.3.0.2.4/upload/` (different dir name)
- Fewer storage directories (no `session/`, no `vendor/`)
- No JIT-related OPcache settings
- Uses `php.v2.ini` and `entrypoint.v2.sh`

PHP extensions (same set, all available on PHP 7.2):
- gd, mysqli, pdo_mysql, zip, intl, xml, mbstring, opcache, bcmath, exif

### 2. docker/entrypoint.v2.sh

Same logic flow as `entrypoint.sh`:
1. Initialize html volume from html-dist (first deploy)
2. Toggle Xdebug (no ionCube/JIT toggles)
3. Create storage directories (5 dirs: cache, download, logs, modification, upload)
4. Wait for database
5. Check if installed (same DB check logic)
6. Install via CLI or generate config
7. Remove install directory

Key differences in config generation:

**catalog/config.php (v2.3 format):**
```php
define('HTTP_SERVER', '${OPENCART_URL}/');
define('HTTPS_SERVER', '${OPENCART_URL}/');
define('DIR_APPLICATION', '/var/www/html/catalog/');
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_LANGUAGE', '/var/www/html/catalog/language/');
define('DIR_TEMPLATE', '/var/www/html/catalog/view/theme/');
define('DIR_CONFIG', '/var/www/html/system/config/');
define('DIR_CACHE', '/var/www/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/storage/download/');
define('DIR_LOGS', '/var/www/storage/logs/');
define('DIR_MODIFICATION', '/var/www/storage/modification/');
define('DIR_UPLOAD', '/var/www/storage/upload/');
```
Note: No `DIR_STORAGE` or `DIR_SESSION` constants. Paths are hardcoded. No `HTTP_ADMIN` needed for external storage path.

**admin/config.php (v2.3 format):**
```php
define('HTTP_SERVER', '${OPENCART_URL}/admin/');
define('HTTP_CATALOG', '${OPENCART_URL}/');
define('HTTPS_SERVER', '${OPENCART_URL}/admin/');
define('HTTPS_CATALOG', '${OPENCART_URL}/');
define('DIR_APPLICATION', '/var/www/html/admin/');
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_CATALOG', '/var/www/html/catalog/');
define('DIR_LANGUAGE', '/var/www/html/admin/language/');
define('DIR_TEMPLATE', '/var/www/html/admin/view/template/');
define('DIR_CONFIG', '/var/www/html/system/config/');
define('DIR_CACHE', '/var/www/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/storage/download/');
define('DIR_LOGS', '/var/www/storage/logs/');
define('DIR_MODIFICATION', '/var/www/storage/modification/');
define('DIR_UPLOAD', '/var/www/storage/upload/');
```
Note: Only `OPENCARTFORUM_SERVER` (no `OPENCART_SERVER`).

### 3. docker/php/php.v2.ini

Simplified version of `php.ini`:
- OPcache enabled but without JIT settings (JIT unavailable in PHP 7.2)
- Standard memory/upload limits
- Xdebug config section (same toggle mechanism via .ini rename)
- No ionCube section

## Modified Files

### 1. docker-compose.yml

Single change — add dynamic Dockerfile selection:
```yaml
opencart:
  build:
    context: .
    dockerfile: ${DOCKERFILE:-Dockerfile}
```

### 2. .env.example

Add at the top:
```env
# Version selection
# Dockerfile        = OcStore 3.x (PHP 8.1) — default
# Dockerfile.v2     = OcStore 2.3 (PHP 7.2)
DOCKERFILE=Dockerfile
```

## Storage Path Strategy

Both versions use the same external storage path `/var/www/storage/` (outside webroot). The entrypoint handles the migration from `system/storage/` to `/var/www/storage/` for both versions.

v2.3 storage dirs: cache, download, logs, modification, upload (5)
v3.x storage dirs: cache, download, logs, modification, session, upload + vendor (7)

## Testing

After implementation, verify:
1. `DOCKERFILE=Dockerfile` (default) — OcStore 3.x builds and installs as before
2. `DOCKERFILE=Dockerfile.v2` — OcStore 2.3 builds, installs, admin accessible
3. Switching between versions with fresh volumes works
4. Redeploy-safe behavior preserved for both versions

## Risks

- **PHP 7.2 EOL:** PHP 7.2 reached end-of-life in Nov 2020. No security patches. Acceptable for legacy/migration use cases.
- **Xdebug compatibility:** xdebug 3.1.x is last version supporting PHP 7.2. Must pin version.
- **Debian Buster EOL:** buster LTS ended June 2024. Image still available but no updates. Alternative: use `php:7.2-fpm-stretch` if buster unavailable.
