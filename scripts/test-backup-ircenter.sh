#!/usr/bin/env bash
set -euo pipefail

umask 077

readonly SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
readonly BACKUP_SCRIPT="$SCRIPT_DIR/backup-ircenter.sh"
TEST_ROOT=$(mktemp -d /tmp/ircenter-backup-test.XXXXXX)
readonly TEST_ROOT

cleanup() {
    [[ "$TEST_ROOT" == /tmp/ircenter-backup-test.* && -d "$TEST_ROOT" && ! -L "$TEST_ROOT" ]] || return 1
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT
fail() { printf 'FALHA: %s\n' "$1" >&2; exit 1; }

assert_fails() {
    if "$@" >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"; then
        fail "comando deveria falhar"
    fi
}

mkdir -m 0700 "$TEST_ROOT/bin" "$TEST_ROOT/allowed"
cat >"$TEST_ROOT/bin/pg_dump" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
output=""
for argument in "$@"; do
    case "$argument" in --file=*) output=${argument#--file=} ;; esac
done
[[ -n "$output" ]]
if [[ "${FAKE_PG_DUMP_FAIL:-0}" == 1 ]]; then
    printf 'falha ficticia\n' >&2
    exit 12
fi
printf 'fixture sem dados reais\n' >"$output"
FAKE
chmod 0700 "$TEST_ROOT/bin/pg_dump"

export PATH="$TEST_ROOT/bin:$PATH"
export BACKUP_ALLOWED_ROOT="$TEST_ROOT/allowed"
export BACKUP_ROOT="$TEST_ROOT/allowed/ircenter"
export APP_DATABASE=app_fixture
export DOCUMENTATION_DATABASE=documentation_fixture
export BACKUP_TIER=daily
export DATABASE_URL=IR_CENTER_TEST_MARKER_9f41

"$BACKUP_SCRIPT" backup all >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
[[ $(stat -c %a "$BACKUP_ROOT") == 700 ]] || fail "raiz nao esta 0700"
while IFS= read -r directory; do
    [[ $(stat -c %a "$directory") == 700 ]] || fail "diretorio nao esta 0700"
done < <(find "$BACKUP_ROOT" -type d)
while IFS= read -r file; do
    [[ $(stat -c %a "$file") == 600 ]] || fail "arquivo nao esta 0600"
done < <(find "$BACKUP_ROOT" -type f)
[[ -z $(find "$BACKUP_ROOT" -perm /0077 -print -quit) ]] || fail "permissao de grupo/world detectada"
if rg -F "$DATABASE_URL" "$TEST_ROOT/stdout" "$TEST_ROOT/stderr" >/dev/null; then
    fail "dado sensivel apareceu nos logs"
fi

assert_fails env BACKUP_ROOT= BACKUP_ALLOWED_ROOT="$TEST_ROOT/allowed" "$BACKUP_SCRIPT" backup app
assert_fails env BACKUP_ROOT=/ BACKUP_ALLOWED_ROOT="$TEST_ROOT/allowed" "$BACKUP_SCRIPT" backup app
assert_fails env BACKUP_ROOT=/opt/ircenter/backups BACKUP_ALLOWED_ROOT=/opt "$BACKUP_SCRIPT" backup app
assert_fails env BACKUP_ROOT="$TEST_ROOT/outside" BACKUP_ALLOWED_ROOT="$TEST_ROOT/allowed" "$BACKUP_SCRIPT" backup app
before_count=$(find "$BACKUP_ROOT" -type f | wc -l)
assert_fails env BACKUP_ENCRYPTION=age AGE_RECIPIENTS_FILE= "$BACKUP_SCRIPT" backup app
after_count=$(find "$BACKUP_ROOT" -type f | wc -l)
[[ "$before_count" == "$after_count" ]] || fail "falha de criptografia deixou plaintext"

mkdir -m 0700 "$TEST_ROOT/real-target"
ln -s "$TEST_ROOT/real-target" "$TEST_ROOT/allowed/link"
assert_fails env BACKUP_ROOT="$TEST_ROOT/allowed/link/ircenter" "$BACKUP_SCRIPT" backup app

before_count=$(find "$BACKUP_ROOT" -type f | wc -l)
assert_fails env FAKE_PG_DUMP_FAIL=1 "$BACKUP_SCRIPT" backup app
after_count=$(find "$BACKUP_ROOT" -type f | wc -l)
[[ "$before_count" == "$after_count" ]] || fail "cleanup alterou contagem de arquivos ($before_count -> $after_count)"
[[ -z $(find "$BACKUP_ROOT" -name '*.partial.*' -print -quit) ]] || fail "arquivo parcial encontrado"

old_file="$BACKUP_ROOT/database/app/daily/ircenter-app-20000101T000000Z.dump"
keep_file="$BACKUP_ROOT/database/app/daily/manual-note.txt"
printf 'antigo\n' >"$old_file"
printf 'preservar\n' >"$keep_file"
chmod 0600 "$old_file" "$keep_file"
touch -d '30 days ago' "$old_file" "$keep_file"
RETENTION_DAILY_DAYS=14 "$BACKUP_SCRIPT" prune app >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
[[ ! -e "$old_file" ]] || fail "retencao nao removeu fixture elegivel"
[[ -e "$keep_file" ]] || fail "retencao removeu arquivo fora do padrao"

printf 'OK: fixtures de backup seguro validadas em /tmp\n'
