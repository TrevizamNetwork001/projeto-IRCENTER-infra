#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ignore=$root_dir/.dockerignore
dockerfile=$root_dir/docker/php/Dockerfile
failed=0
fail() { printf 'VIOLACAO: %s\n' "$1" >&2; failed=1; }
require_pattern() {
    grep -Fx -- "$1" "$ignore" >/dev/null 2>&1 || fail ".dockerignore nao cobre: $1"
}
for pattern in '.git' '**/.git' '.env' '**/.env' '**/backups' '**/certbot' \
    '**/storage' '**/vendor' '**/node_modules' '**/*.sql' '**/*.dump' \
    '**/*.log' '**/*.pem' '**/*.key' '**/*.p12' '**/*.pfx'; do
    require_pattern "$pattern"
done
if grep -Ein '^[[:space:]]*(ARG|ENV)[[:space:]].*(password|passwd|token|secret|private[_-]?key|auth)' "$dockerfile"; then
    fail 'possivel credencial declarada em ARG/ENV no Dockerfile PHP'
fi
if grep -Ein 'COPY[[:space:]].*(\.env|storage|backups?|certbot|\.pem|\.key|\.p12|\.pfx)' "$dockerfile"; then
    fail 'Dockerfile copia artefato sensivel explicitamente'
fi
[ "$failed" -eq 0 ] || exit 1
printf 'OK: exclusoes sensiveis e Dockerfile sem credenciais persistentes.\n'
