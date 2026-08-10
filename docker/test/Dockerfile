FROM php:8.4.23-cli-bookworm@sha256:5380a7dd17b978cd14fb2c84cd67ddc47adaf079b240f8138224bbadefae46f7


ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libicu-dev \
        libpq-dev \
        libsqlite3-dev \
        libzip-dev \
        unzip \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath intl pcntl pdo_pgsql pdo_sqlite zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2.10.2@sha256:4d71c3c2109c61d5415544264b59ad4087e4c5b7244481723664138fd36d5040 /usr/bin/composer /usr/local/bin/composer
ARG APPLICATION

WORKDIR /workspace/app
COPY ${APPLICATION}/composer.json ${APPLICATION}/composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-progress --no-scripts
COPY ${APPLICATION}/ ./
RUN find . -type d -exec chmod 0755 {} + \
    && find . -type f -exec chmod 0644 {} + \
    && chmod 0755 artisan \
    && : > .env \
    && chmod 0444 .env
RUN composer dump-autoload --no-interaction --optimize \
    && rm -f bootstrap/cache/*.php \
    && mkdir -p bootstrap/cache storage/app/public \
        storage/framework/cache/data storage/framework/sessions \
        storage/framework/testing storage/framework/views storage/logs \
    && chown -R www-data:www-data bootstrap/cache storage
COPY docker/test/guardrails.sh /usr/local/bin/ircenter-test-guardrails
RUN chmod 0555 /usr/local/bin/ircenter-test-guardrails
USER www-data
ENTRYPOINT ["/usr/local/bin/ircenter-test-guardrails"]
CMD ["test"]
