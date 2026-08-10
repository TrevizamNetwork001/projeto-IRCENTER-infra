#!/bin/sh
set -eu

/usr/local/bin/ircenter-heartbeat-write scheduler
cycle_seconds="${IRCENTER_SCHEDULER_CYCLE_SECONDS:-60}"
case "$cycle_seconds" in
    ''|*[!0-9]*) printf 'invalid scheduler cycle\n' >&2; exit 64 ;;
esac

while :; do
    started=$(date -u +%s)
    php artisan schedule:run --no-interaction &
    scheduler_pid=$!
    trap 'kill -TERM "$scheduler_pid" 2>/dev/null || true; wait "$scheduler_pid" 2>/dev/null || true; exit 143' TERM INT
    wait "$scheduler_pid"
    scheduler_status=$?
    trap - TERM INT
    [ "$scheduler_status" -eq 0 ] || exit "$scheduler_status"
    /usr/local/bin/ircenter-heartbeat-write scheduler

    finished=$(date -u +%s)
    elapsed=$((finished - started))
    delay=$((cycle_seconds - elapsed))
    [ "$delay" -le 0 ] || sleep "$delay"
done
