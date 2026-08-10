#!/bin/sh
set -eu

role="${1-}"
ttl="${2-}"
case "$role" in
    queue) expected=ircenter-queue-run ;;
    scheduler) expected=ircenter-scheduler-run ;;
    *) printf 'invalid heartbeat role\n' >&2; exit 64 ;;
esac
case "$ttl" in
    ''|*[!0-9]*) printf 'invalid heartbeat ttl\n' >&2; exit 64 ;;
esac

proc_root="${IRCENTER_HEALTHCHECK_PROC_ROOT:-/proc}"
cmdline=$(tr '\000' ' ' < "$proc_root/1/cmdline")
case "$cmdline" in
    *"$expected"*) ;;
    *) printf '%s supervisor unavailable\n' "$role" >&2; exit 1 ;;
esac

heartbeat="storage/app/health/$role-heartbeat"
[ -r "$heartbeat" ] \
    || { printf '%s heartbeat missing\n' "$role" >&2; exit 1; }
timestamp=$(sed -n '1p' "$heartbeat")
case "$timestamp" in
    ''|*[!0-9]*) printf '%s heartbeat invalid\n' "$role" >&2; exit 1 ;;
esac

now=$(date -u +%s)
age=$((now - timestamp))
[ "$age" -ge 0 ] \
    || { printf '%s heartbeat is in the future\n' "$role" >&2; exit 1; }
[ "$age" -le "$ttl" ] \
    || { printf '%s heartbeat stale\n' "$role" >&2; exit 1; }

printf 'healthy\n'
