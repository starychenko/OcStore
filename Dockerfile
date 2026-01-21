# OpenCart 3 (OcStore) Docker Image
# PHP 8.1-FPM + Nginx + All required extensions

FROM php:8.1-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    libpng \
    libjpeg-turbo \
    libwebp \
    freetype \
    libzip \
    icu \
    libxml2 \
    oniguruma \
    unzip \
    git \
    mysql-client \
    bind-tools

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    libxml2-dev \
    oniguruma-dev \
    $PHPIZE_DEPS \
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
    && apk del .build-deps

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/php \
    && mkdir -p /run/nginx

# Copy configuration files
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Download and extract OcStore
ARG OCSTORE_VERSION=3.0.4.1
RUN curl -L https://github.com/ocStore/ocStore/archive/refs/tags/v${OCSTORE_VERSION}.zip -o /tmp/ocstore.zip \
    && unzip /tmp/ocstore.zip -d /tmp \
    && cp -r /tmp/ocStore-${OCSTORE_VERSION}/upload/* /var/www/html/ \
    && rm -rf /tmp/ocstore.zip /tmp/ocStore-${OCSTORE_VERSION}

# Create storage directory structure (both locations for OpenCart compatibility)
# /var/www/html/system/storage - default location
# /var/www/storage - location after OpenCart "move storage" recommendation
RUN mkdir -p /var/www/html/system/storage/cache \
    && mkdir -p /var/www/html/system/storage/download \
    && mkdir -p /var/www/html/system/storage/logs \
    && mkdir -p /var/www/html/system/storage/modification \
    && mkdir -p /var/www/html/system/storage/session \
    && mkdir -p /var/www/html/system/storage/upload \
    && mkdir -p /var/www/storage/cache \
    && mkdir -p /var/www/storage/download \
    && mkdir -p /var/www/storage/logs \
    && mkdir -p /var/www/storage/modification \
    && mkdir -p /var/www/storage/session \
    && mkdir -p /var/www/storage/upload \
    && mkdir -p /var/www/html/image/cache \
    && mkdir -p /var/www/html/image/catalog

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/www/storage \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/system/storage \
    && chmod -R 777 /var/www/storage \
    && chmod -R 777 /var/www/html/image/cache \
    && chmod -R 777 /var/www/html/image/catalog \
    && chmod 666 /var/www/html/config.php 2>/dev/null || touch /var/www/html/config.php && chmod 666 /var/www/html/config.php \
    && chmod 666 /var/www/html/admin/config.php 2>/dev/null || touch /var/www/html/admin/config.php && chmod 666 /var/www/html/admin/config.php

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
