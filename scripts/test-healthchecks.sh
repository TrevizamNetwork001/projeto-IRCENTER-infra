#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d -t ircenter-h6-probes.XXXXXX)
cleanup() { rm -rf -- "$fixture"; }
trap cleanup EXIT INT TERM

fail() { printf 'FALHA: %s\n' "$1" >&2; exit 1; }
expect_failure() {
    description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$description"
    fi
}

mkdir -p "$fixture/proc/1" "$fixture/work"
printf 'sh\000/usr/local/bin/ircenter-queue-run\000' \
    > "$fixture/proc/1/cmdline"

cd "$fixture/work"
"$root_dir/docker/health/heartbeat-write.sh" queue
heartbeat=storage/app/health/queue-heartbeat

[ -f "$heartbeat" ] || fail 'heartbeat nao foi criado'
[ "$(stat -c '%a' "$heartbeat")" = 640 ] \
    || fail 'heartbeat nao possui modo 0640'
[ "$(stat -c '%a' storage/app/health)" = 750 ] \
    || fail 'diretorio de heartbeat nao possui modo 0750'
[ -z "$(find storage/app/health -name '.queue-heartbeat.*' -print -quit)" ] \
    || fail 'arquivo temporario atomico permaneceu no diretorio'

IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" queue 150 \
    >/dev/null

rm -f "$heartbeat"
expect_failure 'heartbeat ausente foi aceito' \
    env IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" queue 150

printf 'invalid\n' > "$heartbeat"
expect_failure 'timestamp invalido foi aceito' \
    env IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" queue 150

printf '%s\n' "$(( $(date -u +%s) - 151 ))" > "$heartbeat"
expect_failure 'heartbeat vencido foi aceito' \
    env IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" queue 150

printf '%s\n' "$(( $(date -u +%s) + 30 ))" > "$heartbeat"
expect_failure 'heartbeat futuro foi aceito' \
    env IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" queue 150

printf 'sh\000/usr/local/bin/ircenter-scheduler-run\000' \
    > "$fixture/proc/1/cmdline"
"$root_dir/docker/health/heartbeat-write.sh" scheduler
IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" scheduler 180 \
    >/dev/null

printf 'unrelated-process\000' > "$fixture/proc/1/cmdline"
expect_failure 'supervisor morto foi aceito' \
    env IRCENTER_HEALTHCHECK_PROC_ROOT="$fixture/proc" \
    "$root_dir/docker/health/heartbeat-healthcheck.sh" scheduler 180

printf 'OK: heartbeat atomico, permissoes, TTL e falhas validados.\n'
