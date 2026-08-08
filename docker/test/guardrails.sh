#!/bin/sh
set -eu

abort() { printf 'ABORTADO: %s\n' "$1" >&2; exit 64; }
require_equal() {
    variable_name="$1"; expected="$2"
    eval "actual=\${$variable_name-}"
    [ "$actual" = "$expected" ] || abort "$variable_name nao e seguro para testing"
}
require_empty() {
    variable_name="$1"
    eval "actual=\${$variable_name-}"
    [ -z "$actual" ] || abort "$variable_name deve estar vazio em testing"
}

require_equal APP_ENV testing
require_equal DB_CONNECTION sqlite
require_equal DB_DATABASE :memory:
require_empty DB_URL
require_equal FINANCE_FISCAL_DB_CONNECTION sqlite
require_equal FINANCE_FISCAL_DB_DATABASE :memory:
require_empty FINANCE_FISCAL_DB_URL
require_equal CACHE_STORE array
require_equal SESSION_DRIVER array
require_equal QUEUE_CONNECTION sync
require_equal MAIL_MAILER array
require_equal REDIS_HOST disabled.invalid
require_empty REDIS_URL
require_equal FINANCE_ENABLED false
require_equal FINANCE_AUTOMATION_ENABLED false
require_equal PAYMENT_PROVIDER fake
require_equal PAYMENT_LIVE_ENABLED false
require_equal PAYMENT_WEBHOOKS_ENABLED false
require_equal FISCAL_ENABLED false
require_equal NFSE_PROVIDER fake
require_equal NFSE_TRANSMISSION_ENABLED false
require_equal NFSE_LIVE_ENABLED false
require_equal EFI_ENVIRONMENT homologation
require_equal APP_URL http://localhost
require_equal IRCENTER_API_URL http://127.0.0.1/testing-disabled
require_empty IRCENTER_API_TOKEN

case "${DB_HOST-}" in ''|localhost|127.0.0.1) ;; *) abort "DB_HOST externo nao e permitido" ;; esac
case "${APP_URL-}${DB_URL-}${REDIS_URL-}${MAIL_URL-}${IRCENTER_API_URL-}" in
    *ircenter.trevizamnetwork.com.br*|*ircenter-postgres*|*ircenter-redis*) abort "referencia de producao detectada" ;;
esac

[ "$PWD" = /workspace/app ] || abort "diretorio de trabalho inesperado"
[ ! -e /opt/ircenter/app ] || abort "workspace produtivo visivel no runner"
[ -w storage ] || abort "storage efemero nao gravavel"
[ -w bootstrap/cache ] || abort "bootstrap/cache efemero nao gravavel"
[ ! -w composer.json ] || abort "codigo da aplicacao esta gravavel"

mkdir -p \
    storage/app/public \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/testing \
    storage/framework/views \
    storage/logs

if [ -z "${APP_KEY-}" ]; then
    APP_KEY="base64:$(php -r 'echo base64_encode(random_bytes(32));')"
    export APP_KEY
fi

action="${1-test}"
shift || true
case "$action" in
    verify)
        printf '%s\n' 'isolation=verified' 'app_env=testing' \
            'database=sqlite-memory' 'cache=array' 'session=array' \
            'queue=sync' 'mail=array' 'network=disabled' \
            'source=read-only' 'runtime-data=ephemeral'
        ;;
    smoke) php artisan about --only=environment ;;
    test) php artisan test --do-not-cache-result "$@" ;;
    *) abort "acao desconhecida; use verify, smoke ou test" ;;
esac
