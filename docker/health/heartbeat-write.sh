#!/bin/sh
set -eu

role="${1-}"
case "$role" in
    queue|scheduler) ;;
    *) printf 'invalid heartbeat role\n' >&2; exit 64 ;;
esac

health_dir="storage/app/health"
heartbeat="$health_dir/$role-heartbeat"
temporary="$health_dir/.$role-heartbeat.$$"

install -d -m 0750 "$health_dir"
umask 0027
printf '%s\n' "$(date -u +%s)" > "$temporary"
chmod 0640 "$temporary"
mv -f "$temporary" "$heartbeat"
