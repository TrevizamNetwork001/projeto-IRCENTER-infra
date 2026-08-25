# Governança, continuidade e monitoramento

## Git e release

- proteger `main`, exigir pull request, CI verde e ao menos uma revisão;
- bloquear force push e exclusão de branches protegidas;
- usar tags SemVer e changelog por release;
- definir CODEOWNERS reais antes de habilitar aprovação automática;
- migrations são forward-only por padrão e exigem revisão de lock, duração e rollback;
- publicar matriz Infra/Core/Documentation no manifesto de cada release;
- nenhum dos três repositórios pode ser promovido isoladamente sem compatibilidade registrada.

## RPO/RTO propostos

Não constituem SLA ou compromisso contratual.

| Componente | RPO proposto | RTO proposto |
|---|---:|---:|
| Core e Finance/Fiscal | 24 horas | 4 horas |
| Documentation | 24 horas | 8 horas |
| Configuração operacional | por release | 4 horas |

Status: `PROPOSED`. Negócio e operação devem aprovar ou substituir estes valores.

## Arquitetura de monitoramento proposta

Não instalar produto sem decisão operacional. Uma opção simples é Prometheus + Alertmanager para métricas, Blackbox Exporter para HTTPS/certificado, cAdvisor/node_exporter para host/containers e Loki para logs. O destino de alertas e o responsável de plantão precisam ser definidos antes da ativação.

Severidades:

- `INFO`: mudança de estado recuperada, deploy e execução bem-sucedida;
- `WARNING`: HTTP 429 elevado, backlog, integração repetidamente falha, CSP relevante e `submission_unknown` financeiro;
- `CRITICAL`: app/DB indisponível, queue parada, scheduler stale, backup falho, certificado próximo da expiração ou disco crítico.

Cobertura mínima: app, DB, Redis, queue/scheduler heartbeat, failed jobs, backlog, HTTP 500/429, certificado, disco, RAM, CPU, backup, integrações repetidas e CSP. O monitor de backup deve publicar apenas data/status/tamanho/checksum, última cópia off-site e último restore test.

## LGPD — lacunas para revisão

- política de privacidade e termos;
- base legal e finalidade por categoria de dado;
- exportação, correção, anonimização e exclusão;
- retenção de dados, auditoria, logs e backups;
- inventário de operadores/suboperadores;
- atendimento a titulares e resposta a incidentes;
- controle de acesso e evidência de consentimento quando aplicável.

`LEGAL_REVIEW_REQUIRED=yes`. Este checklist não é parecer jurídico.

## Identidade

MFA TOTP, recovery codes de uso único, senha recente, desafio de login, auditoria
e encerramento das outras sessões estão implementados. A obrigatoriedade continua
desligada. Ativar enforcement exige migration produtiva aprovada, plano de
recuperação, comunicação e ao menos dois administradores validados.
