#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TARGET="${1-}"
[ -n "$TARGET" ] || { printf 'Destino obrigatorio.\n' >&2; exit 64; }
shift
ACTION="${1-test}"
[ "$#" -eq 0 ] || shift
case "$TARGET" in
    app) SERVICE=app-test ;;
    documentation) SERVICE=documentation-test ;;
    *) printf 'Uso: %s {app|documentation} [verify|smoke|test] [argumentos PHPUnit]\n' "$0" >&2; exit 64 ;;
esac
case "$ACTION" in verify|smoke|test) ;; *) printf 'Acao invalida.\n' >&2; exit 64 ;; esac

SNAPSHOT_DIR=$(mktemp -d -t ircenter-test-isolation.XXXXXX)
BEFORE_FILES="$SNAPSHOT_DIR/files.before"
AFTER_FILES="$SNAPSHOT_DIR/files.after"
BEFORE_CONTAINERS="$SNAPSHOT_DIR/containers.before"
AFTER_CONTAINERS="$SNAPSHOT_DIR/containers.after"
LOG_OFFSETS="$SNAPSHOT_DIR/logs.before"
cleanup() { rm -rf -- "$SNAPSHOT_DIR"; }
trap cleanup EXIT INT TERM

snapshot_files() {
    output="$1"; : > "$output"
    for file in \
        "$ROOT_DIR/app/bootstrap/cache/config.php" \
        "$ROOT_DIR/documentation-app/bootstrap/cache/config.php" \
        "$ROOT_DIR/documentation-app/bootstrap/cache/packages.php" \
        "$ROOT_DIR/documentation-app/bootstrap/cache/routes-v7.php" \
        "$ROOT_DIR/documentation-app/bootstrap/cache/services.php"
    do
        if [ -f "$file" ]; then
            stat -c '%n|present|%i|%s|%Y' "$file" >> "$output"
            sha256sum "$file" >> "$output"
        else
            printf '%s|absent\n' "$file" >> "$output"
        fi
    done
}

snapshot_containers() {
    output="$1"; : > "$output"
    for container in ircenter-app ircenter-queue ircenter-scheduler \
        ircenter-documentation-app ircenter-documentation-queue \
        ircenter-documentation-scheduler ircenter-web
    do
        docker inspect --format '{{.Name}}|{{.Id}}|{{.State.Status}}|{{.RestartCount}}' \
            "$container" >> "$output" 2>/dev/null \
            || printf '/%s|not-found\n' "$container" >> "$output"
    done
}

snapshot_log_offsets() {
    : > "$LOG_OFFSETS"
    find "$ROOT_DIR/app/storage/logs" "$ROOT_DIR/documentation-app/storage/logs" \
        -maxdepth 1 -type f -name '*.log' -printf '%p|%s\n' 2>/dev/null \
        | sort > "$LOG_OFFSETS"
}

check_new_app_key_errors() {
    while IFS='|' read -r log_file old_size; do
        [ -f "$log_file" ] || continue
        new_size=$(stat -c '%s' "$log_file")
        [ "$new_size" -le "$old_size" ] && continue
        if tail -c "+$((old_size + 1))" "$log_file" \
            | grep -Fq 'No application encryption key has been specified'; then
            printf 'FALHA: novo erro de APP_KEY detectado em log produtivo.\n' >&2
            exit 66
        fi
    done < "$LOG_OFFSETS"
    printf 'OK: nenhum novo erro de APP_KEY em logs produtivos.\n'
}

compare_snapshot() {
    kind="$1"; before="$2"; after="$3"
    if ! cmp -s "$before" "$after"; then
        printf 'FALHA: metadados de %s produtivos mudaram.\n' "$kind" >&2
        diff -u "$before" "$after" >&2 || true
        exit 65
    fi
    printf 'OK: %s produtivos inalterados.\n' "$kind"
}

snapshot_files "$BEFORE_FILES"
snapshot_containers "$BEFORE_CONTAINERS"
snapshot_log_offsets
if docker compose --project-name ircenter-isolated-tests \
    --file "$ROOT_DIR/compose.test.yaml" \
    run --rm --build --no-deps "$SERVICE" "$ACTION" "$@"; then
    RUN_STATUS=0
else
    RUN_STATUS=$?
fi
snapshot_files "$AFTER_FILES"
snapshot_containers "$AFTER_CONTAINERS"
compare_snapshot caches "$BEFORE_FILES" "$AFTER_FILES"
compare_snapshot containers "$BEFORE_CONTAINERS" "$AFTER_CONTAINERS"
check_new_app_key_errors

exit "$RUN_STATUS"
