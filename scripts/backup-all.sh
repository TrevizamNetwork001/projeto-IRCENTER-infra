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
readonly STATUS_FILE=${BACKUP_STATUS_FILE:-/var/lib/ircenter/status/backup-status.env}
readonly HISTORY_FILE=${BACKUP_HISTORY_FILE:-/var/lib/ircenter/status/backup-history.log}
readonly HISTORY_MAX_LINES=${BACKUP_HISTORY_MAX_LINES:-60}
readonly LOCK_FILE=${BACKUP_LOCK_FILE:-/run/lock/ircenter-backup.lock}
readonly RETENTION_DAILY_DAYS=${RETENTION_DAILY_DAYS:-14}
readonly RETENTION_WEEKLY_DAYS=${RETENTION_WEEKLY_DAYS:-90}
readonly RETENTION_MONTHLY_DAYS=${RETENTION_MONTHLY_DAYS:-730}

log() { printf '[ircenter-backup] %s\n' "$1" >&2; }
fail() { log "FAIL: $1"; write_status failed 0 none; append_history failed 0 none; exit 1; }

validate() {
    [[ "$BACKUP_ROOT" == /var/backups/* ]] || fail 'BACKUP_ROOT fora da raiz permitida'
    [[ "$BACKUP_ROOT" != *$'\n'* && ! -L "$BACKUP_ROOT" ]] || fail 'BACKUP_ROOT inseguro'
    [[ "$BACKUP_TIER" =~ ^(daily|weekly|monthly)$ ]] || fail 'tier invalido'
    [[ "$CORE_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Core invalido'
    [[ "$FINANCE_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Finance invalido'
    [[ "$DOCUMENTATION_DATABASE" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'database Documentation invalido'
    [[ "$RETENTION_DAILY_DAYS" =~ ^[0-9]+$ && "$RETENTION_DAILY_DAYS" -ge 1 && "$RETENTION_DAILY_DAYS" -le 3650 ]] || fail 'RETENTION_DAILY_DAYS invalido'
    [[ "$RETENTION_WEEKLY_DAYS" =~ ^[0-9]+$ && "$RETENTION_WEEKLY_DAYS" -ge 1 && "$RETENTION_WEEKLY_DAYS" -le 3650 ]] || fail 'RETENTION_WEEKLY_DAYS invalido'
    [[ "$RETENTION_MONTHLY_DAYS" =~ ^[0-9]+$ && "$RETENTION_MONTHLY_DAYS" -ge 1 && "$RETENTION_MONTHLY_DAYS" -le 3650 ]] || fail 'RETENTION_MONTHLY_DAYS invalido'
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

# O diretorio de status (nao o de backups) e 0755: contem somente
# metadados nao sensiveis (horario, status, tamanho, tier) para leitura
# pela aplicacao web via bind mount read-only. Nunca coloque aqui dump,
# manifest de release ou qualquer conteudo de backup real.
prepare_status_dir() {
    local status_dir=$1
    if [[ ! -d "$status_dir" ]]; then
        mkdir -p -- "$status_dir"
        chmod 0755 -- "$status_dir"
    fi
    [[ ! -L "$status_dir" && -w "$status_dir" ]] || {
        log 'FAIL: diretorio de status inseguro ou sem escrita'
        return 1
    }
}

write_status() {
    local status=$1 size=$2 checksum=$3 status_dir tmp
    status_dir=$(dirname "$STATUS_FILE")
    prepare_status_dir "$status_dir" || return 1
    tmp=$(mktemp "$status_dir/.backup-status.XXXXXX")
    printf 'last_backup_at=%s\nlast_backup_status=%s\nlast_backup_size=%s\nchecksum_valid=%s\nretention_daily_days=%s\nretention_weekly_days=%s\nretention_monthly_days=%s\nencryption=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$size" "$checksum" \
        "$RETENTION_DAILY_DAYS" "$RETENTION_WEEKLY_DAYS" "$RETENTION_MONTHLY_DAYS" "$ENCRYPTION" > "$tmp"
    chmod 0644 "$tmp"
    mv -T -- "$tmp" "$STATUS_FILE"
}

append_history() {
    local status=$1 size=$2 checksum=$3 status_dir tmp
    status_dir=$(dirname "$HISTORY_FILE")
    prepare_status_dir "$status_dir" || return 1
    [[ -f "$HISTORY_FILE" ]] || : > "$HISTORY_FILE"
    tmp=$(mktemp "$status_dir/.backup-history.XXXXXX")
    {
        printf 'at=%s tier=%s status=%s size=%s checksum_valid=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BACKUP_TIER" "$status" "$size" "$checksum"
        cat -- "$HISTORY_FILE" 2>/dev/null
    } | head -n "$HISTORY_MAX_LINES" > "$tmp"
    chmod 0644 "$tmp"
    mv -T -- "$tmp" "$HISTORY_FILE"
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
    append_history success "$total" yes
    log "backup completo concluido; artifacts=5 bytes=$total"
}

retention_days_for_tier() {
    case "$1" in
        daily) printf '%s' "$RETENTION_DAILY_DAYS" ;;
        weekly) printf '%s' "$RETENTION_WEEKLY_DAYS" ;;
        monthly) printf '%s' "$RETENTION_MONTHLY_DAYS" ;;
    esac
}

retention_eligible_dirs() {
    local tier=$1 days dir
    days=$(retention_days_for_tier "$tier")
    dir="$BACKUP_ROOT/releases/$tier"
    [[ -d "$dir" ]] || return 0
    find -P "$dir" -mindepth 1 -maxdepth 1 -type d -mtime "+$days"
}

retention_dry_run() {
    local tier days count
    for tier in daily weekly monthly; do
        days=$(retention_days_for_tier "$tier")
        count=$(retention_eligible_dirs "$tier" | wc -l)
        printf 'tier=%s retention_days=%s eligible_directories=%s action=none\n' "$tier" "$days" "$count"
    done
}

retention_apply() {
    local tier days removed release
    for tier in daily weekly monthly; do
        days=$(retention_days_for_tier "$tier")
        removed=0
        while IFS= read -r release; do
            [[ -n "$release" ]] || continue
            # so remove diretorios dentro de BACKUP_ROOT/releases/<tier>,
            # nunca um symlink ou caminho fora da raiz de backups.
            [[ "$release" == "$BACKUP_ROOT/releases/$tier/"* ]] || continue
            [[ ! -L "$release" ]] || continue
            rm -rf -- "$release"
            removed=$((removed + 1))
        done < <(retention_eligible_dirs "$tier")
        printf 'tier=%s retention_days=%s removed_directories=%s action=deleted\n' "$tier" "$days" "$removed"
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
        retention-apply) retention_apply ;;
        *) fail 'acao deve ser backup, retention-dry-run ou retention-apply' ;;
    esac
}

main "$@"
