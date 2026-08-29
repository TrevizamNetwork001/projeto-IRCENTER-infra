#!/bin/bash
# Bloqueia a subida da stack se os volumes de banco estiverem vazios/novos
# enquanto existir backup recente disponivel. Existe para nao repetir o
# incidente de 2026-08-29: reboot do host apagou os volumes Docker de
# postgres/redis e a stack teria voltado com um banco novo e vazio se
# ninguem tivesse percebido antes do "docker compose up".
set -euo pipefail
umask 077

readonly BACKUP_ROOT=${BACKUP_ROOT:-/var/backups/ircenter}
readonly COMPOSE_PROJECT=${COMPOSE_PROJECT_NAME:-ircenter}
readonly MIN_CLIENT_ROWS=${MIN_CLIENT_ROWS:-0}
readonly MAX_BACKUP_AGE_HOURS=${MAX_BACKUP_AGE_HOURS:-48}

log() { printf '[check-volume-integrity] %s\n' "$1" >&2; }
fail() {
    log "BLOQUEADO: $1"
    log 'Nao suba a stack as cegas. Restaure o backup mais recente antes de'
    log '"docker compose up", ou confirme explicitamente com FORCE_EMPTY_DB=1'
    log 'se este e realmente um ambiente novo sem dados a preservar.'
    exit 1
}

latest_backup_dir() {
    find "$BACKUP_ROOT/releases" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
        | sort -r | head -n1
}

main() {
    if [[ "${FORCE_EMPTY_DB:-0}" == "1" ]]; then
        log 'FORCE_EMPTY_DB=1: pulando verificacao a pedido do operador.'
        exit 0
    fi

    local latest
    latest=$(latest_backup_dir || true)

    if [[ -z "$latest" ]]; then
        log 'Nenhum backup encontrado em '"$BACKUP_ROOT"'; nada para comparar.'
        exit 0
    fi

    local backup_age_seconds backup_age_hours
    backup_age_seconds=$(( $(date +%s) - $(stat -c %Y "$latest") ))
    backup_age_hours=$(( backup_age_seconds / 3600 ))

    local volume_name="${COMPOSE_PROJECT}_postgres_data"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        if [[ "$backup_age_hours" -le "$MAX_BACKUP_AGE_HOURS" ]]; then
            fail "volume '$volume_name' nao existe e ha backup de menos de ${MAX_BACKUP_AGE_HOURS}h em $latest. Restaure antes de subir."
        fi
        log "volume '$volume_name' nao existe; backup mais recente tem ${backup_age_hours}h (> ${MAX_BACKUP_AGE_HOURS}h). Prosseguindo sem bloqueio automatico."
        exit 0
    fi

    if ! docker ps --format '{{.Names}}' | grep -qx ircenter-postgres; then
        log 'postgres nao esta rodando; nada a validar em runtime agora.'
        exit 0
    fi

    local rows
    rows=$(docker exec ircenter-postgres sh -c \
        'psql -U "$POSTGRES_USER" -d ircenter -tAc "select count(*) from information_schema.tables where table_schema='"'"'public'"'"'"' 2>/dev/null) || rows=""

    if [[ -z "$rows" ]]; then
        log 'nao foi possivel consultar o banco (ainda subindo?); pulando.'
        exit 0
    fi

    if [[ "$rows" -eq 0 && "$backup_age_hours" -le "$MAX_BACKUP_AGE_HOURS" ]]; then
        fail "banco 'ircenter' esta sem tabelas e ha backup de ${backup_age_hours}h em $latest. Restaure antes de liberar trafego."
    fi

    log "OK: banco com $rows tabelas, backup mais recente com ${backup_age_hours}h."
}

main "$@"
