#!/usr/bin/env bash
set -euo pipefail

umask 077

readonly DEPLOY_ROOT="/opt/ircenter"
readonly DEFAULT_ALLOWED_ROOT="/var/backups"

log() { printf '[backup-ircenter] %s\n' "$1" >&2; }
die() { log "ERRO: $1"; exit 1; }

require_absolute_path() {
    local value=${1:-}
    local label=$2
    [[ -n "$value" ]] || die "$label nao pode ser vazio"
    [[ "$value" == /* ]] || die "$label deve ser absoluto"
    [[ "$value" != "/" ]] || die "$label nao pode ser /"
    [[ "$value" != *$'\n'* ]] || die "$label contem caractere invalido"
}

normalized_path() { realpath -m -- "$1"; }

assert_no_symlink_components() {
    local path=$1 current="/" component remainder=${1#/}
    while [[ -n "$remainder" ]]; do
        component=${remainder%%/*}
        if [[ "$remainder" == */* ]]; then remainder=${remainder#*/}; else remainder=""; fi
        [[ -n "$component" && "$component" != "." && "$component" != ".." ]] || die "componente de path invalido"
        current="${current%/}/$component"
        [[ ! -L "$current" ]] || die "symlink nao permitido no destino: $current"
    done
}

validate_roots() {
    require_absolute_path "$BACKUP_ROOT" BACKUP_ROOT
    require_absolute_path "$BACKUP_ALLOWED_ROOT" BACKUP_ALLOWED_ROOT
    BACKUP_ROOT=$(normalized_path "$BACKUP_ROOT")
    BACKUP_ALLOWED_ROOT=$(normalized_path "$BACKUP_ALLOWED_ROOT")
    [[ "$BACKUP_ROOT" != "$DEPLOY_ROOT" && "$BACKUP_ROOT" != "$DEPLOY_ROOT/"* ]] || die "destino dentro do deploy e proibido"
    [[ "$BACKUP_ALLOWED_ROOT" != "$DEPLOY_ROOT" && "$BACKUP_ALLOWED_ROOT" != "$DEPLOY_ROOT/"* ]] || die "raiz permitida dentro do deploy e proibida"
    [[ "$BACKUP_ROOT" == "$BACKUP_ALLOWED_ROOT/"* ]] || die "BACKUP_ROOT deve estar estritamente dentro de BACKUP_ALLOWED_ROOT"
    assert_no_symlink_components "$BACKUP_ALLOWED_ROOT"
    assert_no_symlink_components "$BACKUP_ROOT"
}

secure_directory() {
    local directory=$1
    mkdir -p -- "$directory"
    [[ -d "$directory" && ! -L "$directory" ]] || die "diretorio seguro invalido"
    chmod 0700 -- "$directory"
}

validate_tier() {
    case "$BACKUP_TIER" in daily|weekly|monthly) ;; *) die "BACKUP_TIER deve ser daily, weekly ou monthly" ;; esac
}

validate_encryption() {
    case "$BACKUP_ENCRYPTION" in
        none) ;;
        age)
            require_absolute_path "$AGE_RECIPIENTS_FILE" AGE_RECIPIENTS_FILE
            [[ -f "$AGE_RECIPIENTS_FILE" && ! -L "$AGE_RECIPIENTS_FILE" ]] || die "arquivo externo de destinatarios age ausente ou inseguro"
            ;;
        *) die "BACKUP_ENCRYPTION deve ser none ou age" ;;
    esac
}

database_name_for() {
    case "$1" in
        app) printf '%s\n' "${APP_DATABASE:-}" ;;
        documentation) printf '%s\n' "${DOCUMENTATION_DATABASE:-}" ;;
        *) die "alvo de banco desconhecido" ;;
    esac
}

create_database_backup() {
    local target=$1 database directory timestamp final partial encrypted_partial="" encrypted_final=""
    database=$(database_name_for "$target")
    [[ -n "$database" ]] || die "nome do banco ausente para $target"
    [[ "$database" =~ ^[A-Za-z0-9_.-]+$ ]] || die "nome do banco invalido para $target"
    directory="$BACKUP_ROOT/database/$target/$BACKUP_TIER"
    assert_no_symlink_components "$directory"
    secure_directory "$directory"
    timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    final="$directory/ircenter-${target}-${timestamp}.dump"
    partial=$(mktemp -- "$directory/.ircenter-${target}-${timestamp}.partial.XXXXXX")
    chmod 0600 -- "$partial"

    cleanup_partial() {
        [[ -z "$partial" || ! -e "$partial" ]] || rm -f -- "$partial"
        [[ -z "$encrypted_partial" || ! -e "$encrypted_partial" ]] || rm -f -- "$encrypted_partial"
    }
    trap cleanup_partial EXIT
    log "iniciando dump de $target"
    if ! pg_dump --format=custom --file="$partial" --dbname="$database"; then
        rm -f -- "$partial"
        partial=""
        die "pg_dump falhou para $target"
    fi
    chmod 0600 -- "$partial"

    case "$BACKUP_ENCRYPTION" in
        none)
            mv -T -- "$partial" "$final"; partial=""
            log "dump concluido: ${final##*/}"
            ;;
        age)
            encrypted_final="$final.age"
            encrypted_partial=$(mktemp -- "$directory/.ircenter-${target}-${timestamp}.age.partial.XXXXXX")
            chmod 0600 -- "$encrypted_partial"
            if ! age --encrypt --recipients-file "$AGE_RECIPIENTS_FILE" --output "$encrypted_partial" "$partial"; then
                rm -f -- "$encrypted_partial" "$partial"
                encrypted_partial=""; partial=""
                die "criptografia falhou para $target"
            fi
            chmod 0600 -- "$encrypted_partial"
            mv -T -- "$encrypted_partial" "$encrypted_final"; encrypted_partial=""
            rm -f -- "$partial"; partial=""
            log "dump criptografado concluido: ${encrypted_final##*/}"
            ;;
    esac
    trap - EXIT
}

retention_days_for() {
    case "$1" in
        daily) printf '%s\n' "$RETENTION_DAILY_DAYS" ;;
        weekly) printf '%s\n' "$RETENTION_WEEKLY_DAYS" ;;
        monthly) printf '%s\n' "$RETENTION_MONTHLY_DAYS" ;;
    esac
}

prune_target() {
    local target=$1 tier days directory candidate basename
    for tier in daily weekly monthly; do
        days=$(retention_days_for "$tier")
        [[ "$days" =~ ^[0-9]+$ ]] || die "retencao invalida para $tier"
        directory="$BACKUP_ROOT/database/$target/$tier"
        [[ -e "$directory" ]] || continue
        [[ -d "$directory" && ! -L "$directory" ]] || die "diretorio de retencao inseguro"
        assert_no_symlink_components "$directory"
        while IFS= read -r -d '' candidate; do
            [[ "$(dirname -- "$candidate")" == "$directory" ]] || die "candidato fora do diretorio esperado"
            basename=${candidate##*/}
            [[ "$basename" =~ ^ircenter-${target}-[0-9]{8}T[0-9]{6}Z\.dump(\.age)?$ ]] || die "arquivo fora do padrao de retencao"
            rm -f -- "$candidate"
            log "retencao removeu arquivo elegivel: $basename"
        done < <(find -P "$directory" -xdev -maxdepth 1 -type f \( -name "ircenter-${target}-*.dump" -o -name "ircenter-${target}-*.dump.age" \) -mtime "+$days" -print0)
    done
}

main() {
    local action=${1:-} target=${2:-all}
    BACKUP_ROOT=${BACKUP_ROOT:-}
    BACKUP_ALLOWED_ROOT=${BACKUP_ALLOWED_ROOT:-$DEFAULT_ALLOWED_ROOT}
    BACKUP_TIER=${BACKUP_TIER:-daily}
    BACKUP_ENCRYPTION=${BACKUP_ENCRYPTION:-none}
    AGE_RECIPIENTS_FILE=${AGE_RECIPIENTS_FILE:-}
    RETENTION_DAILY_DAYS=${RETENTION_DAILY_DAYS:-14}
    RETENTION_WEEKLY_DAYS=${RETENTION_WEEKLY_DAYS:-90}
    RETENTION_MONTHLY_DAYS=${RETENTION_MONTHLY_DAYS:-730}
    validate_roots
    validate_tier
    validate_encryption
    case "$target" in app|documentation|all) ;; *) die "alvo deve ser app, documentation ou all" ;; esac
    case "$action" in
        backup)
            [[ "$target" == documentation ]] || create_database_backup app
            [[ "$target" == app ]] || create_database_backup documentation
            ;;
        prune)
            [[ "$target" == documentation ]] || prune_target app
            [[ "$target" == app ]] || prune_target documentation
            ;;
        *) die "uso: backup-ircenter.sh {backup|prune} [app|documentation|all]" ;;
    esac
}

main "$@"
