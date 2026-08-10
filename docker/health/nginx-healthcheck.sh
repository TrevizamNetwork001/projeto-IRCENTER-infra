#!/bin/sh
set -eu

body=$(wget -q -T 4 -O - http://127.0.0.1:8080/health/ready) \
    || { printf 'readiness request failed\n' >&2; exit 1; }
[ "$body" = '{"status":"ready"}' ] \
    || { printf 'readiness response invalid\n' >&2; exit 1; }

printf 'healthy\n'
