#!/bin/sh
set -eu

/usr/local/bin/ircenter-heartbeat-write queue
max_time="${IRCENTER_QUEUE_CYCLE_SECONDS:-60}"
case "$max_time" in
    ''|*[!0-9]*) printf 'invalid queue cycle\n' >&2; exit 64 ;;
esac

while :; do
    php artisan queue:work \
        --sleep=3 \
        --tries=3 \
        --timeout=90 \
        --max-time="$max_time" \
        --no-interaction &
    worker_pid=$!
    trap 'kill -TERM "$worker_pid" 2>/dev/null || true; wait "$worker_pid" 2>/dev/null || true; exit 143' TERM INT
    wait "$worker_pid"
    worker_status=$?
    trap - TERM INT
    [ "$worker_status" -eq 0 ] || exit "$worker_status"
    /usr/local/bin/ircenter-heartbeat-write queue
done
