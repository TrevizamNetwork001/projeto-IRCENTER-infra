#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
compose="docker compose --project-name ircenter-e2e-tests --file $root_dir/compose.e2e.test.yaml"

expect_rejection() {
    label="$1"
    shift
    if $compose run --rm --no-deps "$@" e2e-runner node -e 'process.exit(0)' >/tmp/ircenter-e2e-guardrail.log 2>&1; then
        printf 'FALHA: guardrail aceitou %s.\n' "$label" >&2
        return 1
    fi
    grep -F 'ABORTADO:' /tmp/ircenter-e2e-guardrail.log >/dev/null
    printf 'OK: guardrail recusou %s.\n' "$label"
}

expect_rejection 'URL produtiva' -e BASE_URL=https://ircenter.trevizamnetwork.com.br
expect_rejection 'APP_ENV=production' -e APP_ENV=production
expect_rejection 'provider live' -e PAYMENT_PROVIDER=efi -e PAYMENT_LIVE_ENABLED=true
expect_rejection 'banco produtivo' -e DB_HOST=ircenter-postgres
expect_rejection 'Redis produtivo' -e REDIS_HOST=ircenter-redis
expect_rejection 'hostname local/proibido' -e BASE_URL=http://127.0.0.1:8080

rm -f /tmp/ircenter-e2e-guardrail.log
