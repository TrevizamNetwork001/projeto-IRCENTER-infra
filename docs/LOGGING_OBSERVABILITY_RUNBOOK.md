# Runbook de logging e observabilidade

## Pré-check read-only

```bash
cd /opt/ircenter
git -c safe.directory=/opt/ircenter status --short
docker compose config --quiet
docker compose ps
docker inspect ircenter-app ircenter-queue ircenter-scheduler ircenter-web \
  --format '{{.Name}} restart={{.RestartCount}} health={{json .State.Health}} log={{.HostConfig.LogConfig.Type}} options={{json .HostConfig.LogConfig.Config}}'
```

Não imprimir environment, headers, payloads ou configuração completa contendo
secrets. Não truncar arquivos de log.

## Consulta por serviço e request ID

```bash
docker compose logs --no-color --since=30m app
docker compose logs --no-color --since=30m queue
docker compose logs --no-color --since=30m scheduler
docker compose logs --no-color --since=30m web
docker compose logs --no-color --since=30m app | grep -F 'REQUEST_ID_VALIDADO'
```

Substituir o marcador somente por UUID obtido de `X-Request-ID`. Não pesquisar
por senha, token, e-mail, documento ou payload. Para NGINX, o request ID aparece
como `request_id="..."`; query string não integra o formato H9.

## Investigação de queue, scheduler e unhealthy

```bash
docker inspect ircenter-queue --format '{{json .State.Health}} restart={{.RestartCount}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{json .State.Error}}'
docker inspect ircenter-scheduler --format '{{json .State.Health}} restart={{.RestartCount}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{json .State.Error}}'
docker compose logs --no-color --since=30m queue | grep -E 'Job falhou|job_id|attempt'
docker compose logs --no-color --since=30m scheduler | grep -E 'Tarefa agendada (falhou|excedeu)'
```

Correlacionar por `job_id`, classe, fila e tentativa. Não copiar payload
serializado do job. Para unhealthy, preservar `docker inspect`, timestamps,
restart count e logs antes de qualquer recreate; consultar também os probes H6.

## Crescimento e rotação

```bash
docker system df
docker inspect ircenter-app --format '{{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
docker exec ircenter-app sh -c 'du -h -d 1 storage/logs 2>/dev/null'
```

O último comando mostra somente tamanho, não conteúdo. Produção espera daily por
30 dias e driver Docker `local` com limites. Não executar logrotate, apagar logs
ou editar `daemon.json` durante investigação. Para adotar `json-file`, preparar
separadamente `max-size`/`max-file`, validar impacto e janela de restart do daemon.

## Deploy e validação futura

Após aprovação, snapshotar referências anteriores, rebuildar/recriar apenas os
serviços afetados e validar:

```bash
docker compose config --quiet
docker exec ircenter-web nginx -t
docker compose ps
curl -fsSI https://HOST/up | grep -i '^X-Request-ID:'
```

Gerar uma requisição sem dado sensível, localizar o UUID no app e NGINX e
confirmar que health não cria cookie. Validar falha sintética somente em ambiente
isolado. Não inserir marcadores secretos em produção.

## Rollback

Restaurar commit/imagem e configuração anteriores e recriar somente app, queue,
scheduler e web na janela aprovada. Não apagar logs: preservá-los para análise.
Confirmar healthchecks, `nginx -t`, request HTTP e consumo normal da queue.
