#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
result=0

scan_repository() {
    repository=$1
    label=$2
    findings=$(git -c safe.directory="$repository" -C "$repository" grep -IlE \
        '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|client_secret[[:space:]]*=[[:space:]]*[^$[:space:]]|access_token[[:space:]]*=[[:space:]]*[^$[:space:]])' \
        -- ':!*.lock' ':!tests/*' ':!tests/**' 2>/dev/null || true)
    if [ -n "$findings" ]; then
        printf 'SECRET_SCAN_%s=FAIL\n' "$label"
        printf '%s\n' "$findings" | sed 's/^/finding_file=/'
        result=1
    else
        printf 'SECRET_SCAN_%s=PASS\n' "$label"
    fi
}

scan_repository "$ROOT_DIR" INFRA
scan_repository "$ROOT_DIR/app" CORE
scan_repository "$ROOT_DIR/documentation-app" DOCUMENTATION
exit "$result"
