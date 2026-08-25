#!/bin/bash
set -uo pipefail

status=0
output_mode=${1:-machine}
emit() { printf '%s=%s\n' "$1" "$2"; }
warn() { emit "$1" "$2"; (( status < 1 )) && status=1; }
critical() { emit "$1" "$2"; status=2; }

for service in web app queue scheduler documentation-app documentation-queue documentation-scheduler postgres redis; do
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "ircenter-$service" 2>/dev/null || printf missing)
    emit "service_${service//-/_}" "$health"
    [[ "$health" == healthy ]] || critical "critical_service_${service//-/_}" 1
done

disk_used=$(df -P /opt/ircenter | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
emit disk_used_percent "$disk_used"
(( disk_used >= 90 )) && critical disk_critical 1
(( disk_used >= 80 && disk_used < 90 )) && warn disk_warning 1

memory_used=$(awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {printf "%.0f", (total-available)*100/total}' /proc/meminfo)
emit memory_used_percent "$memory_used"
(( memory_used >= 95 )) && critical memory_critical 1
(( memory_used >= 85 && memory_used < 95 )) && warn memory_warning 1

read -r load_1m _ < /proc/loadavg
cpu_count=$(getconf _NPROCESSORS_ONLN)
emit load_1m "$load_1m"
emit cpu_count "$cpu_count"
awk -v load="$load_1m" -v cpus="$cpu_count" 'BEGIN {exit !(load >= cpus * 2)}' && critical cpu_load_critical 1
awk -v load="$load_1m" -v cpus="$cpu_count" 'BEGIN {exit !(load >= cpus && load < cpus * 2)}' && warn cpu_load_warning 1

certificate_path=${CERTIFICATE_PATH:-/opt/ircenter/certbot/conf/live/ircenter.trevizamnetwork.com.br/fullchain.pem}
if openssl x509 -checkend 1209600 -noout -in "$certificate_path" >/dev/null 2>&1; then
    emit certificate_status ok_more_than_14_days
elif openssl x509 -checkend 0 -noout -in "$certificate_path" >/dev/null 2>&1; then
    critical certificate_status expires_within_14_days
else
    critical certificate_status expired_or_unreadable
fi

backup_status=${BACKUP_STATUS_FILE:-/var/lib/ircenter/backup-status.env}
if [[ -r "$backup_status" ]]; then
    backup_at=
    while IFS='=' read -r key value; do
        case "$key" in
            last_backup_at) backup_at=$value; emit "$key" "$value" ;;
            last_backup_status|last_backup_size|checksum_valid) emit "$key" "$value" ;;
        esac
    done < "$backup_status"
    if [[ -n "$backup_at" ]] && backup_epoch=$(date -u -d "$backup_at" +%s 2>/dev/null); then
        backup_age=$(( $(date -u +%s) - backup_epoch ))
        emit backup_age_seconds "$backup_age"
        (( backup_age >= 129600 )) && critical backup_stale_critical 1
        (( backup_age >= 90000 && backup_age < 129600 )) && warn backup_stale_warning 1
    else
        critical backup_timestamp_invalid 1
    fi
else
    critical backup_status missing
fi

restore_status=${RESTORE_STATUS_FILE:-/var/lib/ircenter/restore-status.env}
if [[ -r "$restore_status" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            last_restore_test_at|last_restore_test_status|restore_domains|restore_checksums_valid)
                emit "$key" "$value"
                ;;
        esac
    done < "$restore_status"
else
    warn restore_status missing
fi

failed_jobs=$(docker exec ircenter-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -Atqc "select count(*) from failed_jobs"' sh ircenter 2>/dev/null || printf unknown)
emit failed_jobs "$failed_jobs"
[[ "$failed_jobs" =~ ^[0-9]+$ ]] && (( failed_jobs > 0 )) && warn failed_jobs_warning 1
[[ "$failed_jobs" =~ ^[0-9]+$ ]] || critical failed_jobs_check_error 1

queue_backlog=$(docker exec ircenter-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -Atqc "select count(*) from jobs"' sh ircenter 2>/dev/null || printf unknown)
emit queue_backlog "$queue_backlog"
[[ "$queue_backlog" =~ ^[0-9]+$ ]] && (( queue_backlog >= 100 )) && critical queue_backlog_critical 1
[[ "$queue_backlog" =~ ^[0-9]+$ ]] && (( queue_backlog >= 25 && queue_backlog < 100 )) && warn queue_backlog_warning 1
[[ "$queue_backlog" =~ ^[0-9]+$ ]] || critical queue_backlog_check_error 1

submission_unknown=$(docker exec ircenter-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -Atqc "select count(*) from charges where status='"'"'submission_unknown'"'"'"' sh ircenter_finance 2>/dev/null || printf unknown)
emit finance_submission_unknown "$submission_unknown"
[[ "$submission_unknown" =~ ^[0-9]+$ ]] && (( submission_unknown > 0 )) && warn finance_submission_unknown_warning 1
[[ "$submission_unknown" =~ ^[0-9]+$ ]] || critical finance_submission_unknown_check_error 1

overall=$([[ $status -eq 0 ]] && echo OK || ([[ $status -eq 1 ]] && echo WARNING || echo CRITICAL))
emit overall_status "$overall"
if [[ "$output_mode" == --human ]]; then
    printf 'IRCENTER operacional: %s (0=OK, 1=WARNING, 2=CRITICAL)\n' "$overall"
elif [[ "$output_mode" != machine ]]; then
    printf 'uso: %s [--human]\n' "$0" >&2
    exit 64
fi
exit "$status"
