#!/bin/bash
# Disparado pelo APT (DPkg::Pre-Invoke) antes de qualquer instalacao/upgrade
# de pacote. Garante que nunca exista mais de MAX_AGE_MINUTES sem um backup
# fresco antes de uma atualizacao que pode terminar em reboot (kernel,
# docker-ce, containerd.io). Nao bloqueia o apt em caso de falha: perder uma
# janela de patch de seguranca por causa de um backup e pior do que aceitar
# o risco e alertar.
set -uo pipefail
umask 077

readonly STATUS_FILE=${BACKUP_STATUS_FILE:-/var/lib/ircenter/backup-status.env}
readonly MAX_AGE_MINUTES=${PRE_UPGRADE_BACKUP_MAX_AGE_MINUTES:-60}
readonly LOG_TAG='[pre-upgrade-snapshot]'

log() { printf '%s %s\n' "$LOG_TAG" "$1" >&2; }

last_backup_epoch() {
    [[ -f "$STATUS_FILE" ]] || { echo 0; return; }
    local ts
    ts=$(grep -oE '^last_backup_at=.*' "$STATUS_FILE" | cut -d= -f2-)
    [[ -n "$ts" ]] || { echo 0; return; }
    date -u -d "$ts" +%s 2>/dev/null || echo 0
}

main() {
    if ! command -v docker >/dev/null 2>&1; then
        exit 0
    fi

    local last age_minutes now
    last=$(last_backup_epoch)
    now=$(date -u +%s)
    age_minutes=$(( (now - last) / 60 ))

    if [[ "$last" -gt 0 && "$age_minutes" -lt "$MAX_AGE_MINUTES" ]]; then
        log "backup com ${age_minutes}min, dentro do limite de ${MAX_AGE_MINUTES}min. Nada a fazer."
        exit 0
    fi

    log "backup ausente ou com mais de ${MAX_AGE_MINUTES}min (idade=${age_minutes}min). Disparando snapshot antes do apt continuar."

    if systemctl start ircenter-backup.service 2>>/var/log/ircenter/pre-upgrade-snapshot.log; then
        log 'snapshot concluido com sucesso.'
    else
        log 'AVISO: snapshot falhou ou nao pode ser disparado; prosseguindo com o apt mesmo assim.'
    fi

    exit 0
}

main "$@"
