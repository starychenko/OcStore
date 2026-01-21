# OpenCart 3 (OcStore) Docker Image
# PHP 8.1-FPM (Debian Bookworm) + Nginx + All required extensions + Xdebug + ionCube

FROM php:8.1-fpm-bookworm AS base

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
    libwebp7 \
    libfreetype6 \
    libzip4 \
    libicu72 \
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
        --with-freetype \
        --with-jpeg \
        --with-webp \
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
    # Install Xdebug
    && pecl install xdebug \
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

# Install ionCube Loader
RUN curl -o /tmp/ioncube.tar.gz https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
    && tar -xzf /tmp/ioncube.tar.gz -C /tmp \
    && PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');") \
    && cp /tmp/ioncube/ioncube_loader_lin_8.1.so "$PHP_EXT_DIR/ioncube_loader.so" \
    && echo "zend_extension=ioncube_loader.so" > /usr/local/etc/php/conf.d/00-ioncube.ini \
    && rm -rf /tmp/ioncube*

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/php \
    && mkdir -p /run/nginx

# Remove default nginx config
RUN rm -f /etc/nginx/sites-enabled/default

# Copy configuration files
COPY docker/nginx/default.conf /etc/nginx/sites-enabled/default
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Download and extract OcStore to distribution directory
# This allows /var/www/html to be a persistent volume
ARG OCSTORE_VERSION=3.0.4.1
RUN curl -L https://github.com/ocStore/ocStore/archive/refs/tags/v${OCSTORE_VERSION}.zip -o /tmp/ocstore.zip \
    && unzip /tmp/ocstore.zip -d /tmp \
    && mkdir -p /var/www/html-dist \
    && cp -r /tmp/ocStore-${OCSTORE_VERSION}/upload/* /var/www/html-dist/ \
    && rm -rf /tmp/ocstore.zip /tmp/ocStore-${OCSTORE_VERSION}

# Create storage directory structure
# /var/www/storage - secure location outside webroot
RUN mkdir -p /var/www/storage/cache \
    && mkdir -p /var/www/storage/download \
    && mkdir -p /var/www/storage/logs \
    && mkdir -p /var/www/storage/modification \
    && mkdir -p /var/www/storage/session \
    && mkdir -p /var/www/storage/upload \
    && mkdir -p /var/www/html-dist/system/storage/cache \
    && mkdir -p /var/www/html-dist/system/storage/download \
    && mkdir -p /var/www/html-dist/system/storage/logs \
    && mkdir -p /var/www/html-dist/system/storage/modification \
    && mkdir -p /var/www/html-dist/system/storage/session \
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
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
