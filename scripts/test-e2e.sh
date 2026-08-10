#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
project=ircenter-e2e-tests
compose="docker compose --project-name $project --file $root_dir/compose.e2e.test.yaml"
snapshot_dir=$(mktemp -d -t ircenter-e2e-isolation.XXXXXX)
before="$snapshot_dir/containers.before"
after="$snapshot_dir/containers.after"
status=0

snapshot_production() {
    output="$1"
    : > "$output"
    for container in ircenter-app ircenter-queue ircenter-scheduler \
        ircenter-documentation-app ircenter-documentation-queue \
        ircenter-documentation-scheduler ircenter-web ircenter-postgres ircenter-redis
    do
        docker inspect --format '{{.Name}}|{{.Id}}|{{.State.Status}}|{{.RestartCount}}' \
            "$container" >> "$output" 2>/dev/null \
            || printf '/%s|not-found\n' "$container" >> "$output"
    done
}

cleanup() {
    $compose down --volumes --remove-orphans >/dev/null 2>&1 || true
    snapshot_production "$after"
    if ! cmp -s "$before" "$after"; then
        printf 'FALHA: metadados dos containers produtivos mudaram durante E2E.\n' >&2
        diff -u "$before" "$after" >&2 || true
        status=65
    else
        printf 'OK: IDs, status e restart count produtivos inalterados.\n'
    fi
    rm -rf -- "$snapshot_dir"
    exit "$status"
}
trap cleanup EXIT INT TERM

snapshot_production "$before"
install -d -m 0777 "$root_dir/tests/e2e/artifacts"
find "$root_dir/tests/e2e/artifacts" -mindepth 1 ! -name .gitignore -delete

$compose build e2e-init e2e-runner
"$root_dir/scripts/test-e2e-guardrails.sh"
$compose up -d e2e-web

if $compose run --rm --no-deps e2e-runner npm test; then
    :
else
    status=$?
fi

exit "$status"
