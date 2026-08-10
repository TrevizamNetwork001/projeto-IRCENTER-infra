FROM php:8.4.23-fpm-bookworm@sha256:c5fb7a0c02f4efe280691910c8b734995fa83598cdcf3115ef5dcb2e4617681c

ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libfcgi-bin \
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

COPY --from=composer:2.10.2@sha256:4d71c3c2109c61d5415544264b59ad4087e4c5b7244481723664138fd36d5040 /usr/bin/composer /usr/local/bin/composer
COPY docker/php/production.ini /usr/local/etc/php/conf.d/zz-ircenter-production.ini
COPY docker/php/health-fpm.conf /usr/local/etc/php-fpm.d/zz-ircenter-health.conf
COPY docker/health/heartbeat-write.sh /usr/local/bin/ircenter-heartbeat-write
COPY docker/health/php-fpm-healthcheck.sh /usr/local/bin/ircenter-php-fpm-healthcheck
COPY docker/health/heartbeat-healthcheck.sh /usr/local/bin/ircenter-heartbeat-healthcheck
COPY docker/health/queue-run.sh /usr/local/bin/ircenter-queue-run
COPY docker/health/scheduler-run.sh /usr/local/bin/ircenter-scheduler-run

RUN chmod 0555 \
        /usr/local/bin/ircenter-heartbeat-write \
        /usr/local/bin/ircenter-php-fpm-healthcheck \
        /usr/local/bin/ircenter-heartbeat-healthcheck \
        /usr/local/bin/ircenter-queue-run \
        /usr/local/bin/ircenter-scheduler-run

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
