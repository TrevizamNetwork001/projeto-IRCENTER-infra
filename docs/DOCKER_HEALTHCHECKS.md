# Healthchecks Docker do IRCENTER

## Escopo e significado

Os healthchecks verificam a condição mínima para cada processo cumprir seu
papel. Eles não substituem métricas, alertas, tracing, testes de jornada ou a
investigação histórica de reinícios.

| Serviço | Probe | Intervalo | Timeout | Tentativas | Start period |
|---|---|---:|---:|---:|---:|
| `postgres` | `pg_isready` no banco configurado | 10 s | 5 s | 10 | 20 s |
| `redis` | `redis-cli ping` | 10 s | 5 s | 10 | 10 s |
| `app` | ping FastCGI + configuração FPM + bootstrap Laravel | 30 s | 10 s | 3 | 40 s |
| `documentation-app` | ping FastCGI + configuração FPM + bootstrap Laravel | 30 s | 10 s | 3 | 40 s |
| `queue` | supervisor correto + heartbeat de ciclo responsivo | 30 s | 5 s | 3 | 30 s |
| `documentation-queue` | supervisor correto + heartbeat de ciclo responsivo | 30 s | 5 s | 3 | 30 s |
| `scheduler` | supervisor correto + heartbeat após `schedule:run` | 30 s | 5 s | 3 | 90 s |
| `documentation-scheduler` | supervisor correto + heartbeat técnico | 30 s | 5 s | 3 | 90 s |
| `web` | HTTP local NGINX → FPM → `/health/ready` | 30 s | 5 s | 3 | 60 s |

## FPM e Laravel

`ircenter-php-fpm-healthcheck` exige simultaneamente:

1. PID 1 identificado como PHP-FPM;
2. configuração aceita por `php-fpm -t`;
3. resposta `pong` do endpoint interno nativo do FPM na porta 9000;
4. bootstrap mínimo via `php artisan about --only=environment`.

O ping FastCGI usa `cgi-fcgi`, fornecido pelo pacote mínimo `libfcgi-bin`. Ele
não cria sessão ou cookie, não consulta a internet e não executa uma rota de
negócio. O bootstrap do Artisan não consulta banco nem dispara jobs.

## Queue

O wrapper `ircenter-queue-run` executa `queue:work` em ciclos de no máximo 60
segundos. O heartbeat só é renovado depois que o ciclo retorna com sucesso. Um
job travado impede o retorno e deixa o arquivo vencer; uma saída com erro
encerra o container para que a política `unless-stopped` possa atuar.

- arquivo: `storage/app/health/queue-heartbeat`;
- TTL: **150 segundos**;
- conteúdo: um único timestamp Unix UTC;
- nenhuma mensagem é publicada e nenhum job sintético é criado.

## Scheduler

O wrapper `ircenter-scheduler-run` chama `schedule:run` a cada 60 segundos e
renova o heartbeat somente após retorno bem-sucedido. Isso detecta processo
morto, execução travada e falhas repetidas sem escrever em tabelas de negócio.
As tarefas Laravel continuam respeitando suas frequências; no app principal a
tarefa operacional permanece a cada cinco minutos.

- arquivo: `storage/app/health/scheduler-heartbeat`;
- TTL: **180 segundos**;
- documentation scheduler: heartbeat técnico, mesmo sem tarefa periódica
  relevante, sem inventar trabalho de negócio.

Os arquivos são escritos atomicamente por `www-data`, com diretório `0750`,
arquivo `0640`, `umask 0027` e rename no mesmo filesystem. Queue e scheduler
compartilham o volume de storage da respectiva aplicação, mas usam nomes
distintos.

## NGINX e readiness

O NGINX possui listener apenas interno em `127.0.0.1:8080`. O probe usa o
`wget` já presente no BusyBox da imagem Alpine e exige HTTP 200 com o corpo
exato `{"status":"ready"}`. O caminho valida:

```text
NGINX → app:9000 → Laravel → PostgreSQL + Redis
```

Não há porta 8080 publicada, TLS público, hostname externo ou dependência da
internet. HTTP 503, falha FastCGI ou corpo inesperado tornam `web` unhealthy.

## Dependências

```text
postgres healthy ─┬─→ app healthy ────────────────┐
redis healthy ────┘                                ├─→ web healthy
postgres healthy ───→ documentation-app healthy ──┘

postgres + redis healthy ─→ queue / scheduler
postgres healthy ─────────→ documentation-queue / documentation-scheduler
```

Não existem ciclos. Queue e scheduler não dependem do NGINX.

## Testes e falhas controladas

`compose.healthcheck.test.yaml` usa nome de projeto explicitamente isolado,
rede `internal`, source read-only, tmpfs para banco/storage/cache e credenciais
descartáveis. Não publica portas nem monta volumes produtivos.

As validações H6 confirmaram:

- sete serviços de aplicação simultaneamente healthy;
- FPM morto: container `exited` e web `unhealthy` por falha FastCGI;
- Redis indisponível: readiness 503 e web `unhealthy`;
- heartbeat de queue vencido: `unhealthy`;
- heartbeat de scheduler vencido: `unhealthy`;
- queue e scheduler mortos: `exited` com código 137 e recuperação saudável;
- NGINX/FPM real, source read-only e PHP executado como UID/GID 33.

Um container morto fica `exited`, não `unhealthy`, porque o Docker não executa
healthchecks em containers parados. Ambos são estados de falha operacional e
devem gerar alerta.

## Investigação

```bash
docker compose ps
docker inspect --format '{{json .State.Health}}' ircenter-app
docker inspect --format '{{json .State.Health}}' ircenter-web
docker compose logs --no-color --tail=100 app web queue scheduler
docker exec ircenter-queue sh -c 'date -u +%s; cat storage/app/health/queue-heartbeat'
docker exec ircenter-scheduler sh -c 'date -u +%s; cat storage/app/health/scheduler-heartbeat'
```

Não imprimir ambiente completo. O `RestartCount=5` observado anteriormente no
queue produtivo é anterior à H6. Esta fase melhora a detecção futura; a causa
histórica pertence à observabilidade/H9 ou a uma análise separada.
