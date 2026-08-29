#!/bin/bash
# Copia (nao sincroniza) os releases de backup para armazenamento off-site
# (Cloudflare R2, compativel com S3) via rclone. Usa "copy", nunca "sync":
# a copia off-site nao pode ser apagada so porque a retencao local removeu
# o arquivo aqui. A retencao off-site e tratada separadamente, com prazo
# mais longo, por retention_offsite_days().
set -euo pipefail
umask 077

readonly BACKUP_ROOT=${BACKUP_ROOT:-/var/backups/ircenter}
readonly RCLONE_CONFIG=${RCLONE_CONFIG:-/etc/ircenter/rclone.conf}
readonly OFFSITE_REMOTE=${OFFSITE_REMOTE:-r2:ircenter-backups}
readonly OFFSITE_RETENTION_DAYS=${OFFSITE_RETENTION_DAYS:-90}
readonly LOCK_FILE=${OFFSITE_LOCK_FILE:-/run/ircenter-backup/offsite-sync.lock}
readonly STATUS_FILE=${OFFSITE_STATUS_FILE:-/var/lib/ircenter/status/offsite-status.env}

log() { printf '[offsite-sync] %s\n' "$1" >&2; }

write_status() {
    local status=$1 status_dir tmp
    status_dir=$(dirname "$STATUS_FILE")
    mkdir -p -- "$status_dir"
    chmod 0755 -- "$status_dir"
    tmp=$(mktemp "$status_dir/.offsite-status.XXXXXX")
    printf 'last_offsite_sync_at=%s\nlast_offsite_status=%s\nremote=%s\nretention_days=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$OFFSITE_REMOTE" "$OFFSITE_RETENTION_DAYS" > "$tmp"
    chmod 0644 "$tmp"
    mv -T -- "$tmp" "$STATUS_FILE"
}

fail() { log "FAIL: $1"; write_status failed; exit 1; }

main() {
    command -v rclone >/dev/null || fail 'rclone nao encontrado'
    [[ -r "$RCLONE_CONFIG" ]] || fail "config do rclone ilegivel: $RCLONE_CONFIG"
    [[ -d "$BACKUP_ROOT/releases" ]] || fail "sem releases em $BACKUP_ROOT"

    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    flock -n 9 || fail 'outra sincronizacao ja esta ativa'

    log "copiando $BACKUP_ROOT/releases para $OFFSITE_REMOTE (copy, sem delecao remota)"
    rclone --config "$RCLONE_CONFIG" copy \
        "$BACKUP_ROOT/releases" "$OFFSITE_REMOTE/releases" \
        --stats-one-line --stats=0 2>&1 \
        || fail 'rclone copy falhou'

    log "aplicando retencao off-site (> ${OFFSITE_RETENTION_DAYS}d)"
    rclone --config "$RCLONE_CONFIG" delete \
        "$OFFSITE_REMOTE/releases" \
        --min-age "${OFFSITE_RETENTION_DAYS}d" 2>&1 \
        || fail 'retencao off-site falhou'

    rclone --config "$RCLONE_CONFIG" rmdirs \
        "$OFFSITE_REMOTE/releases" --leave-root 2>&1 || true

    write_status success
    log 'sincronizacao off-site concluida'
}

main "$@"
