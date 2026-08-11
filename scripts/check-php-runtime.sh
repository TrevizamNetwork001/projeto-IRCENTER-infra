#!/bin/sh
set -eu

image=${1:-ircenter-php-runtime:h10}

docker run --rm --network none --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --tmpfs /var/www/html/storage:rw,nosuid,size=16m,uid=33,gid=33,mode=0770 \
    --tmpfs /var/www/html/bootstrap/cache:rw,nosuid,size=8m,uid=33,gid=33,mode=0770 \
    --entrypoint sh "$image" -eu -c '
fail() { printf "FALHA: %s\n" "$1" >&2; exit 1; }
[ "$(id -u)" -eq 33 ] || fail "runtime nao executa com UID 33"
[ "$(id -g)" -eq 33 ] || fail "runtime nao executa com GID 33"
for absent in composer git unzip curl gcc cc g++ make cmake; do
    ! command -v "$absent" >/dev/null 2>&1 || fail "$absent presente no runtime"
done
[ ! -e /usr/local/include/php ] || fail "headers PHP presentes no runtime"
[ ! -e /usr/local/bin/phpize ] || fail "phpize presente no runtime"
[ ! -e /usr/local/bin/php-config ] || fail "php-config presente no runtime"
if dpkg-query -W 2>/dev/null | grep -E "^[^[:space:]]*-dev(:[^[:space:]]+)?[[:space:]]" >/dev/null; then
    fail "pacote -dev presente no runtime"
fi
for present in php php-fpm cgi-fcgi; do
    command -v "$present" >/dev/null 2>&1 || fail "$present ausente no runtime"
done
modules=$(php -m)
for module in bcmath curl intl pcntl pdo_pgsql redis zip; do
    printf "%s\n" "$modules" | grep -Fxi "$module" >/dev/null || fail "extensao $module ausente"
done
printf "%s\n" "$modules" | grep -Fxi "Zend OPcache" >/dev/null || fail "extensao opcache ausente"
php-fpm -t >/dev/null 2>&1 || fail "configuracao FPM invalida"
[ "$(php -r "echo ini_get(\"date.timezone\");")" = UTC ] || fail "PHP date.timezone diferente de UTC"
for root in /var/www/html /var/www/documentation; do
    for path in app config routes resources public vendor composer.json; do
        [ ! -w "$root/$path" ] || fail "$root/$path esta gravavel"
    done
done
touch /var/www/html/storage/.h10-write
touch /var/www/html/bootstrap/cache/.h10-write
rm -f /var/www/html/storage/.h10-write /var/www/html/bootstrap/cache/.h10-write
if find /usr/local/lib/php/extensions -type f -name "*.so" -exec ldd {} \; 2>&1 | grep -F "not found"; then
    fail "biblioteca compartilhada ausente"
fi
printf "OK: runtime PHP minimo, UID/GID, extensoes, ldd e filesystem validados.\n"
'
