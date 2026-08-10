# Logging e observabilidade operacional

## Política

Logs técnicos usam UTC e contexto estruturado mínimo. Eles não substituem a
auditoria de domínio nem healthchecks. A política não instala centralização,
monitoramento ou alerta externo nesta fase.

| Ambiente | Canal | Destino | Retenção |
|---|---|---|---|
| Produção | `stack` = `stderr,daily` | Docker e `storage/logs/laravel-*.log` | 30 dias no Laravel |
| Testing | `testing` | `php://stderr` efêmero da stack H1 | vida do runner |
| Local | `stack`/`single` | arquivo local | responsabilidade do ambiente local |

O nível de produção é configurável por `LOG_LEVEL`, com padrão operacional
`warning` no `.env.example`. `LOG_DAILY_DAYS=30` equilibra investigação de
incidentes e consumo de disco; retenção de compliance deve ser decidida em
processo próprio. Logs existentes não são apagados nem reclassificados.

## Sanitização central

Todos os canais operacionais locais (`single`, `daily`, `stderr`, `testing`,
`syslog`, `errorlog`, `slack` e `papertrail`) recebem o processador central
`SensitiveDataRedactor`. Ele percorre contexto aninhado, mensagem, contexto
extra e exceções antes do handler.

São redigidos por chave ou padrão: senhas, confirmação/senha atual, APP_KEY,
tokens, Authorization, Cookie/Set-Cookie, secrets, client_secret, HMAC,
assinatura, chave privada, certificados, DATABASE_URL, POSTGRES_PASSWORD e
Pix copia-e-cola. O valor é substituído por `[REDACTED]`; nunca usar o redactor
como autorização para enviar payload completo ao logger.

Proibido registrar PII, corpo integral de webhook/provider, boleto/linha
digitável, documento, e-mail, payload fiscal ou material criptográfico. Novos
canais precisam declarar o mesmo `tap` antes de uso.

## Correlação e contexto

Cada request recebe UUID v4 gerado internamente. Headers externos não são
aceitos como fonte. O valor entra no contexto como `request_id` e retorna em
`X-Request-ID`. Isso não cria sessão, cookie ou persistência e também se aplica
a liveness/readiness.

Campos preferidos: `request_id`, `operation`, `module`, `provider`, `status`,
`duration_ms`, `queue`, `job`, `job_id`, `attempt` e IDs internos. Evitar IDs
públicos quando o ID interno basta.

## Financeiro e fiscal

Falha incerta de submissão financeira registra `finance.charge.submit`, IDs
internos, provider, método, status técnico e diagnóstico sanitizado. Não registra
idempotency key, checkout, Pix, request/response ou payload do provider. Eventos
de webhook permanecem na auditoria de domínio com IDs/status selecionados; o
payload persistido para rastreabilidade não é emitido no log.

O módulo fiscal ainda não transmite live. Uma futura integração deve registrar
operação, provider, ID interno, resultado e código técnico sanitizado, nunca XML,
certificado, assinatura ou payload fiscal integral.

## Queue e scheduler

Queue registra início e conclusão em `debug`, evitando ruído em produção com
`LOG_LEVEL=warning`. Falha definitiva usa `error` com classe sanitizada, fila,
job ID, tentativa, conexão e duração quando disponível. Argumentos serializados
do job não são registrados.

O scheduler atual registra somente falha (`error`) ou duração igual/superior a
60 segundos (`warning`). Heartbeat stale/morte continuam responsabilidade dos
healthchecks H6; não há log periódico duplicado.

## NGINX e Docker

O formato NGINX usa método + `$uri`, omitindo query string, e correlaciona pelo
`X-Request-ID` devolvido pelo app. Authorization, Cookie e Set-Cookie não fazem
parte do formato. Assets e health interno continuam com access log desativado.

Inspeção H9 encontrou driver Docker `local` para app, queue, scheduler e web,
com `max-size=20m` e `max-file=5`. Essa configuração já limita crescimento por
container, mas pertence ao host/daemon e não foi alterada. Confirmar a mesma
política após deploy; para `json-file`, configurar futuramente `max-size` e
`max-file` em janela própria, nunca editar `daemon.json` sem plano de restart.

## Investigação do restart count da queue

Classificação: **CAUSA NÃO DETERMINADA**.

Metadados read-only observados em 2026-08-10:

- container ID: `f5eb011f3ef48069d03ad38fc75d2b94e7bbe9fc5555ca73957bcd6ff20efb44`;
- restart count: `5`;
- estado atual: `running`;
- `StartedAt`: `2026-07-24T17:59:28.75800507Z`;
- `FinishedAt`: `2026-07-24T17:59:28.508556646Z`;
- `OOMKilled=false`, `ExitCode=0`, `Error=""`;
- restart policy: `unless-stopped`;
- driver: `local`, `max-size=20m`, `max-file=5`.

O estado atual não demonstra OOM, crash, sinal, falha de banco/Redis ou ação
manual nos cinco eventos anteriores. O histórico do Docker disponível não
retornou eventos correlacionáveis, e logs antigos rotacionados não permitem
atribuição segura. H6 melhora detecção futura; causa histórica não deve ser
inferida. Preservar inspect, eventos e logs na próxima ocorrência.

## Alertas futuros

Sem instalar ferramenta nesta fase, considerar críticos: app/queue/scheduler
unhealthy, DB/Redis indisponível, repetição de indisponibilidade de provider,
estado financeiro incerto e falha fiscal. Considerar warning: queue lag/retries,
provider lento, crescimento de disco/log e violações CSP relevantes. Definir
janela, deduplicação e responsável antes de automatizar.

## Documentation-app

O inventário encontrou a configuração Laravel padrão (`stack`/`single`) e
nenhuma regra financeira. Como há trabalho funcional não commitado, nenhum
arquivo foi alterado. Patch isolado futuro deve adotar canal testing efêmero,
stderr/daily em produção, retenção e o mesmo redactor/request ID sem misturar as
alterações atuais.

## Evolução

Uma centralização futura pode consumir stdout/stderr preservando os campos
estruturados. Deve controlar acesso, retenção, criptografia e alertas antes de
ingestão. Não enviar logs a serviço externo sem revisão de privacidade.
