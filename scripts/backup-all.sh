#!/bin/bash
set -euo pipefail
umask 077

readonly BACKUP_ROOT=${BACKUP_ROOT:-/var/backups/ircenter}
readonly BACKUP_TIER=${BACKUP_TIER:-daily}
readonly POSTGRES_CONTAINER=${POSTGRES_CONTAINER:-ircenter-postgres}
readonly CORE_DATABASE=${CORE_DATABASE:-ircenter}
readonly FINANCE_DATABASE=${FINANCE_DATABASE:-ircenter_finance}
readonly DOCUMENTATION_DATABASE=${DOCUMENTATION_DATABASE:-ircenter_documentation}
readonly ENCRYPTION=${BACKUP_ENCRYPTION:-none}
readonly AGE_RECIPIENTS_FILE=${AGE_RECIPIENTS_FILE:-}
readonly GPG_RECIPIENT=${GPG_RECIPIENT:-}
readonly STATUS_FILE=${BACKUP_STATUS_FILE:-/var/lib/ircenter/backup-status.env}
readonly LOCK_FILE=${BACKUP_LOCK_FILE:-/run/lock/ircenter-backup.lock}

log() { printf '[ircenter-backup] %s\n' "$1" >&2; }
fail() { log "FAIL: $1"; write_status failed 0 none; exit 1; }

validate() {
    [[ "$BACKUP_ROOT" == /var/backups/* ]] || fail 'BACKUP_ROOT fora da raiz permitida'
    [[ "$BACKUP_ROOT" != *$'\n'* && ! -L "$BACKUP_ROOT" ]] || fail 'BACKUP_ROOT inseguro'
    [[ "$BACKUP_TIER" =~ ^(daily|weekly|monthly)$ ]] || fail 'tier invalido'
    [[ "$CORE_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Core invalido'
    [[ "$FINANCE_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Finance invalido'
    [[ "$DOCUMENTATION_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Documentation invalido'
    case "$ENCRYPTION" in
        none) ;;
        age)
            command -v age >/dev/null || fail 'age indisponivel'
            [[ "$AGE_RECIPIENTS_FILE" == /* && -f "$AGE_RECIPIENTS_FILE" && ! -L "$AGE_RECIPIENTS_FILE" ]] || fail 'recipients age ausentes'
            ;;
        gpg)
            command -v gpg >/dev/null || fail 'gpg indisponivel'
            [[ -n "$GPG_RECIPIENT" && "$GPG_RECIPIENT" != *$'\n'* ]] || fail 'recipient gpg ausente'
            ;;
        *) fail 'BACKUP_ENCRYPTION invalido' ;;
    esac
}

secure_dir() { mkdir -p -- "$1"; chmod 0700 -- "$1"; }

write_status() {
    local status=$1 size=$2 checksum=$3 status_dir tmp
    status_dir=$(dirname "$STATUS_FILE")
    if [[ ! -d "$status_dir" ]]; then
        mkdir -p -- "$status_dir"
        chmod 0700 -- "$status_dir"
    fi
    [[ ! -L "$status_dir" && -w "$status_dir" ]] || {
        log 'FAIL: diretorio de status inseguro ou sem escrita'
        return 1
    }
    tmp=$(mktemp "$status_dir/.backup-status.XXXXXX")
    printf 'last_backup_at=%s\nlast_backup_status=%s\nlast_backup_size=%s\nchecksum_valid=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$size" "$checksum" > "$tmp"
    chmod 0600 "$tmp"
    mv -T -- "$tmp" "$STATUS_FILE"
}

encrypt_file() {
    local source=$1 target
    case "$ENCRYPTION" in
        none) printf '%s\n' "$source" ;;
        age)
            target="$source.age"
            age --encrypt --recipients-file "$AGE_RECIPIENTS_FILE" --output "$target" "$source"
            chmod 0600 "$target"; rm -f -- "$source"; printf '%s\n' "$target"
            ;;
        gpg)
            target="$source.gpg"
            gpg --batch --yes --encrypt --recipient "$GPG_RECIPIENT" --output "$target" "$source"
            chmod 0600 "$target"; rm -f -- "$source"; printf '%s\n' "$target"
            ;;
    esac
}

dump_database() {
    local label=$1 database=$2 dir=$3 stamp=$4 partial final encrypted
    final="$dir/ircenter-$label-$stamp.dump"
    partial=$(mktemp "$dir/.ircenter-$label-$stamp.partial.XXXXXX")
    if ! docker exec "$POSTGRES_CONTAINER" sh -c \
        'pg_dump --format=custom --no-owner --no-privileges --username="$POSTGRES_USER" --dbname="$1"' sh "$database" > "$partial"; then
        rm -f -- "$partial"; fail "dump $label falhou"
    fi
    [[ -s "$partial" ]] || { rm -f -- "$partial"; fail "dump $label vazio"; }
    chmod 0600 "$partial"; mv -T -- "$partial" "$final"
    encrypted=$(encrypt_file "$final")
    sha256sum "$encrypted" > "$encrypted.sha256"; chmod 0600 "$encrypted.sha256"
    printf '%s\n' "$encrypted"
}

archive_storage() {
    local label=$1 container=$2 root=$3 dir=$4 stamp=$5 partial final encrypted
    final="$dir/ircenter-$label-storage-$stamp.tar.gz"
    partial=$(mktemp "$dir/.ircenter-$label-storage-$stamp.partial.XXXXXX")
    if ! docker exec "$container" tar -C "$root" -czf - storage/app/private storage/app/public > "$partial"; then
        rm -f -- "$partial"; fail "storage $label falhou"
    fi
    [[ -s "$partial" ]] || { rm -f -- "$partial"; fail "storage $label vazio"; }
    chmod 0600 "$partial"; mv -T -- "$partial" "$final"
    encrypted=$(encrypt_file "$final")
    sha256sum "$encrypted" > "$encrypted.sha256"; chmod 0600 "$encrypted.sha256"
    printf '%s\n' "$encrypted"
}

backup_all() {
    local stamp dir manifest total=0 file
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    dir="$BACKUP_ROOT/releases/$BACKUP_TIER/$stamp"
    secure_dir "$BACKUP_ROOT"; secure_dir "$BACKUP_ROOT/releases"
    secure_dir "$BACKUP_ROOT/releases/$BACKUP_TIER"; secure_dir "$dir"
    manifest="$dir/manifest.env"
    : > "$manifest"; chmod 0600 "$manifest"
    for file in \
        "$(dump_database core "$CORE_DATABASE" "$dir" "$stamp")" \
        "$(dump_database finance-fiscal "$FINANCE_DATABASE" "$dir" "$stamp")" \
        "$(dump_database documentation "$DOCUMENTATION_DATABASE" "$dir" "$stamp")" \
        "$(archive_storage core ircenter-app /var/www/html "$dir" "$stamp")" \
        "$(archive_storage documentation ircenter-documentation-app /var/www/documentation "$dir" "$stamp")"
    do
        total=$((total + $(stat -c %s "$file")))
        printf 'artifact=%s|size=%s|sha256=%s\n' "${file##*/}" "$(stat -c %s "$file")" "$(sha256sum "$file" | cut -d' ' -f1)" >> "$manifest"
    done
    printf 'created_at=%s\nencryption=%s\ntier=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ENCRYPTION" "$BACKUP_TIER" >> "$manifest"
    sha256sum "$manifest" > "$manifest.sha256"; chmod 0600 "$manifest.sha256"
    write_status success "$total" yes
    log "backup completo concluido; artifacts=5 bytes=$total"
}

retention_dry_run() {
    local tier days dir count
    for tier in daily weekly monthly; do
        case "$tier" in daily) days=14 ;; weekly) days=90 ;; monthly) days=730 ;; esac
        dir="$BACKUP_ROOT/releases/$tier"
        count=0
        [[ ! -d "$dir" ]] || count=$(find -P "$dir" -mindepth 1 -maxdepth 1 -type d -mtime "+$days" | wc -l)
        printf 'tier=%s retention_days=%s eligible_directories=%s action=none\n' "$tier" "$days" "$count"
    done
}

main() {
    validate
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    flock -n 9 || fail 'outra execucao esta ativa'
    case "${1:-backup}" in
        backup) backup_all ;;
        retention-dry-run) retention_dry_run ;;
        *) fail 'acao deve ser backup ou retention-dry-run' ;;
    esac
}

main "$@"
