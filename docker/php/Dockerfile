FROM php:8.4-fpm-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        libicu-dev \
        libpq-dev \
        libzip-dev \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        intl \
        opcache \
        pcntl \
        pdo_pgsql \
        zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY docker/php/production.ini /usr/local/etc/php/conf.d/zz-ircenter-production.ini

WORKDIR /var/www/html

# Os mounts de runtime populam somente estes diretórios. Eles existem na
# imagem para que named volumes possam herdar owner/modo sem tocar no source.
RUN for root in /var/www/html /var/www/documentation; do \
        install -d -o www-data -g www-data -m 0750 \
            "$root/storage" \
            "$root/storage/app" \
            "$root/storage/app/private" \
            "$root/storage/app/public" \
            "$root/storage/framework" \
            "$root/storage/framework/cache" \
            "$root/storage/framework/cache/data" \
            "$root/storage/framework/sessions" \
            "$root/storage/framework/testing" \
            "$root/storage/framework/views" \
            "$root/storage/logs" \
            "$root/bootstrap" \
            "$root/bootstrap/cache"; \
    done

USER www-data

CMD ["php-fpm"]
