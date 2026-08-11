FROM php:8.4.23-fpm-bookworm@sha256:c5fb7a0c02f4efe280691910c8b734995fa83598cdcf3115ef5dcb2e4617681c AS build

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1

# Compiladores, headers e ferramentas de resolucao existem somente neste stage.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libcurl4-openssl-dev \
        libicu-dev \
        libpq-dev \
        libzip-dev \
        unzip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        curl \
        intl \
        opcache \
        pcntl \
        pdo_pgsql \
        zip \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2.10.2@sha256:4d71c3c2109c61d5415544264b59ad4087e4c5b7244481723664138fd36d5040 /usr/bin/composer /usr/local/bin/composer

WORKDIR /build/app
COPY app/composer.json app/composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress \
        --no-scripts --optimize-autoloader
COPY app/ ./

WORKDIR /build/documentation
COPY documentation-app/composer.json documentation-app/composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress \
        --no-scripts --optimize-autoloader
COPY documentation-app/ ./

FROM php:8.4.23-fpm-bookworm@sha256:c5fb7a0c02f4efe280691910c8b734995fa83598cdcf3115ef5dcb2e4617681c AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Somente bibliotecas compartilhadas e o probe FastCGI H6 permanecem.
RUN apt-get update \
    && apt-get purge -y --auto-remove \
        $PHPIZE_DEPS \
        curl \
        libc6-dev \
        linux-libc-dev \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libfcgi-bin \
        libcurl4 \
        libicu72 \
        libpq5 \
        libzip4 \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /usr/local/include/php \
        /usr/src/php* \
    && rm -f \
        /usr/local/bin/docker-php-ext-configure \
        /usr/local/bin/docker-php-ext-enable \
        /usr/local/bin/docker-php-ext-install \
        /usr/local/bin/docker-php-source \
        /usr/local/bin/php-config \
        /usr/local/bin/phpize

COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY docker/php/production.ini /usr/local/etc/php/conf.d/zz-ircenter-production.ini
COPY docker/php/health-fpm.conf /usr/local/etc/php-fpm.d/zz-ircenter-health.conf
COPY docker/health/heartbeat-write.sh /usr/local/bin/ircenter-heartbeat-write
COPY docker/health/php-fpm-healthcheck.sh /usr/local/bin/ircenter-php-fpm-healthcheck
COPY docker/health/heartbeat-healthcheck.sh /usr/local/bin/ircenter-heartbeat-healthcheck
COPY docker/health/queue-run.sh /usr/local/bin/ircenter-queue-run
COPY docker/health/scheduler-run.sh /usr/local/bin/ircenter-scheduler-run
COPY docker/php/runtime-entrypoint.sh /usr/local/bin/ircenter-runtime-entrypoint
COPY docker/php/normalize-compiled-views.sh /usr/local/bin/ircenter-normalize-compiled-views
COPY --from=build /build/app/ /var/www/html/
COPY --from=build /build/documentation/ /var/www/documentation/

RUN chmod 0555 \
        /usr/local/bin/ircenter-heartbeat-write \
        /usr/local/bin/ircenter-php-fpm-healthcheck \
        /usr/local/bin/ircenter-heartbeat-healthcheck \
        /usr/local/bin/ircenter-queue-run \
        /usr/local/bin/ircenter-scheduler-run \
        /usr/local/bin/ircenter-normalize-compiled-views \
        /usr/local/bin/ircenter-runtime-entrypoint \
    && find /var/www/html /var/www/documentation -xdev -type d -exec chmod 0755 {} + \
    && find /var/www/html /var/www/documentation -xdev -type f -exec chmod 0644 {} + \
    && chmod 0755 /var/www/html/artisan /var/www/documentation/artisan \
    && for root in /var/www/html /var/www/documentation; do \
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

WORKDIR /var/www/html
USER www-data
ENTRYPOINT ["/usr/local/bin/ircenter-runtime-entrypoint"]
CMD ["php-fpm"]
