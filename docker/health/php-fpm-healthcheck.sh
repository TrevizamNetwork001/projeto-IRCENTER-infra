#!/bin/sh
set -eu

cmdline=$(tr '\000' ' ' < /proc/1/cmdline)
case "$cmdline" in
    *php-fpm*) ;;
    *) printf 'php-fpm master unavailable\n' >&2; exit 1 ;;
esac

php-fpm -t >/dev/null 2>&1 \
    || { printf 'php-fpm configuration invalid\n' >&2; exit 1; }

fpm_response=$(
    SCRIPT_NAME=/fpm-ping \
    SCRIPT_FILENAME=/fpm-ping \
    REQUEST_METHOD=GET \
    timeout 4 cgi-fcgi -bind -connect 127.0.0.1:9000 2>/dev/null
) || { printf 'php-fpm ping failed\n' >&2; exit 1; }
printf '%s' "$fpm_response" | grep -Fq 'pong' \
    || { printf 'php-fpm ping invalid\n' >&2; exit 1; }

php artisan about --only=environment --no-ansi >/dev/null 2>&1 \
    || { printf 'laravel bootstrap failed\n' >&2; exit 1; }

printf 'healthy\n'
