#!/bin/sh
set -eu

case "$PWD" in
    /var/www/html|/var/www/documentation) runtime_root=$PWD ;;
    *) runtime_root=/var/www/html ;;
esac

# Named volumes e tmpfs encobrem os diretórios preparados na imagem.
# Recriar somente a árvore explicitamente gravável, já como UID/GID 33.
install -d -m 0750 \
    "$runtime_root/storage/app/private" \
    "$runtime_root/storage/app/public" \
    "$runtime_root/storage/framework/cache/data" \
    "$runtime_root/storage/framework/sessions" \
    "$runtime_root/storage/framework/testing" \
    "$runtime_root/storage/framework/views" \
    "$runtime_root/storage/logs" \
    "$runtime_root/bootstrap/cache"

exec docker-php-entrypoint "$@"
