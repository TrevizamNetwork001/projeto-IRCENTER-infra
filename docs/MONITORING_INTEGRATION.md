# Integração de monitoramento

O host não possui consumidor externo confirmado. Nenhuma stack foi instalada.

`scripts/check-operational-health.sh` produz pares `chave=valor` sem secrets e
usa exit code 0 para OK, 1 para WARNING e 2 para CRITICAL. Ele cobre containers,
health, disco, CPU/load, memória, certificado, idade/status do backup, backlog,
failed jobs e `submission_unknown`. Heartbeats de queue/scheduler fazem parte
dos healthchecks. `--human` acrescenta um resumo legível sem retirar os pares
machine-readable.

Há um adaptador versionado em `ops/zabbix/ircenter-userparameters.conf`. Ele não
foi instalado porque nenhum Zabbix Agent foi encontrado. O mesmo check pode ser
consumido por outro agente sem alteração de contrato.

Severidades: indisponibilidade, check ilegível, backup vencido, disco crítico e
certificado expirado/próximo são CRITICAL; failed jobs, backlog moderado e
`submission_unknown` são WARNING. O consumidor deve deduplicar por chave e só
notificar após duas coletas consecutivas, exceto indisponibilidade de app/DB.

Qualquer Zabbix agent, Prometheus exporter, Uptime Kuma ou supervisor pode
executar o check localmente e encaminhar somente os valores. O consumidor deve
alertar imediatamente em exit 2 e aplicar janela/deduplicação em exit 1.

Ainda faltam destino, credencial, canal de alerta, responsáveis e escalonamento.
Até essa configuração existir: `MONITORING_READY=no` e `ALERTING_READY=no`.
