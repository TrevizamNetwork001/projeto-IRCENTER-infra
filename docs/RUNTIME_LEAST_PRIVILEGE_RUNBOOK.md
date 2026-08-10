# Runbook de runtime PHP com menor privilégio

Este runbook prepara uma mudança manual futura. Os comandos não foram executados nesta fase. Não aplicar em produção fora de janela aprovada e sem rollback disponível.

## 1. Pré-check

```bash
cd /opt/ircenter
sudo -v
git -c safe.directory=/opt/ircenter status --short
docker compose config --quiet
docker compose ps
docker inspect ircenter-app ircenter-queue ircenter-scheduler ircenter-documentation-app ircenter-documentation-queue ircenter-documentation-scheduler --format '{{.Name}} user={{.Config.User}} mounts={{json .Mounts}}'
```

Registrar branch, imagens, IDs, volumes e portas. Confirmar que o checkout contém a mudança H3. Não modificar ownership do source no host.

## 2. Backup da configuração atual

```bash
RUNTIME_SNAPSHOT=/tmp/ircenter-h3-runtime-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$RUNTIME_SNAPSHOT"
docker compose config > "$RUNTIME_SNAPSHOT/compose.before.yaml"
docker inspect ircenter-app ircenter-queue ircenter-scheduler ircenter-documentation-app ircenter-documentation-queue ircenter-documentation-scheduler > "$RUNTIME_SNAPSHOT/containers.before.json"
```

Guardar o snapshot antes da recriação e mantê-lo até a validação final.

## 3. UID/GID e volumes esperados

O runtime esperado é `www-data`, UID/GID `33:33`, fornecido pela imagem oficial PHP:

```bash
docker compose run --rm --no-deps app id
docker volume inspect ircenter_app_storage ircenter_app_cache ircenter_documentation_storage ircenter_documentation_cache
```

Os quatro volumes recebem somente dados de runtime. Não executar `chown -R` ou `chmod -R` no checkout. Se um volume existente tiver owner incorreto, interromper e usar procedimento limitado ao volume aprovado.

## 4. Preparação de storage/cache

Volumes novos são populados pelos diretórios criados na imagem com modo `0750` e owner `33:33`:

```bash
for volume in ircenter_app_storage ircenter_app_cache ircenter_documentation_storage ircenter_documentation_cache; do
    docker run --rm -v "$volume:/runtime" alpine:3.22 sh -c 'find /runtime -maxdepth 3 -printf "%m %u:%g %p\\n" | sort'
done
```

Se for necessário corrigir um volume vazio, usar somente um container de init apontando para aquele volume e paths listados; nunca montar o source como destino de escrita.

## 5. Alteração e recriação controlada

```bash
docker compose config --quiet
docker compose up -d --no-deps --force-recreate app queue scheduler documentation-app documentation-queue documentation-scheduler
```

Esses comandos são instruções manuais. Não recriar PostgreSQL/Redis nem fazer pull.

## 6. Validação de FPM e usuário

```bash
docker inspect ircenter-app --format '{{.Config.User}}'
docker exec ircenter-app id
docker exec ircenter-app sh -c 'ps -eo uid,gid,user,args | grep "[p]hp-fpm"'
docker exec ircenter-documentation-app id
docker exec ircenter-documentation-app sh -c 'php-fpm -t'
```

O resultado deve mostrar UID 33, nenhum PHP com UID 0 e FPM na porta interna `9000`. O Nginx continua usando `app:9000` e `documentation-app:9000`.

## 7. Validação web, queue e scheduler

```bash
docker exec ircenter-web nginx -t
docker compose logs --no-color --tail=100 app documentation-app queue scheduler documentation-queue documentation-scheduler
docker exec ircenter-app php artisan about --only=environment
docker exec ircenter-documentation-app php artisan about --only=environment
```

Confirmar smoke HTTP, ausência de erro de permissão e que logs, cache, sessões, views compiladas e arquivos gerados ficam somente sob `storage`/`bootstrap/cache`.

## 8. Rollback completo

Se FPM, HTTP, queue, scheduler ou permissões falharem:

```bash
docker compose down --remove-orphans
docker compose -f "$RUNTIME_SNAPSHOT/compose.before.yaml" up -d
docker compose ps
docker exec ircenter-web nginx -t
```

Este rollback também é somente manual. Não apagar volumes nem dados; manter os volumes H3 intactos para análise. Confirmar saúde de FPM, HTTP, queue e scheduler antes de encerrar.

## 9. Encerramento

Guardar configuração Compose, inspeções, evidências de UID 33, smoke HTTP, testes de escrita negativa e resultados das suítes. A mudança só fica implantada após aprovação do responsável pelo host.

## 10. Healthchecks H6 — implantação futura

Não executar fora de janela controlada. Antes do rebuild, confirmar checkout,
estado atual, restart counts e configuração:

```bash
cd /opt/ircenter
git -c safe.directory=/opt/ircenter status --short
docker compose config --quiet
docker compose ps
docker inspect ircenter-app ircenter-queue ircenter-scheduler ircenter-web \
  --format '{{.Name}} id={{.Id}} restart={{.RestartCount}} health={{json .State.Health}}'
```

Gerar o snapshot descrito na seção 2. O deploy controlado da H6 requer rebuild
local da imagem PHP e recriação somente dos serviços afetados:

```bash
docker compose build app queue scheduler documentation-app documentation-queue documentation-scheduler
docker compose up -d --no-deps --force-recreate app documentation-app
docker compose up -d --no-deps --force-recreate queue scheduler documentation-queue documentation-scheduler
docker compose up -d --no-deps --force-recreate web
```

Validar sem imprimir secrets:

```bash
docker compose config --quiet
docker compose ps
docker exec ircenter-web nginx -t
docker inspect --format '{{json .State.Health}}' ircenter-app
docker inspect --format '{{json .State.Health}}' ircenter-web
docker exec ircenter-queue /usr/local/bin/ircenter-heartbeat-healthcheck queue 150
docker exec ircenter-scheduler /usr/local/bin/ircenter-heartbeat-healthcheck scheduler 180
curl -fsS https://HOST/health/ready
```

Esperar pelo menos um ciclo completo de queue e scheduler. Verificar ownership
`33:33`, diretório `0750` e arquivos `0640` sob `storage/app/health`. Não
alterar os heartbeats manualmente em produção.

Se um serviço ficar unhealthy, preservar `docker inspect`, logs e timestamps.
O rollback usa o snapshot da seção 2: restaurar Compose/imagem anteriores e
recriar somente os serviços H6, sem apagar volumes. Validar novamente FPM,
readiness, queue, scheduler e NGINX antes de encerrar a janela.

## 11. Timezone H8 — verificação futura

A implantação da H8 não converte dados. Após rebuild controlado, executar apenas
as verificações read-only documentadas em `docs/TIMEZONE_POLICY.md`: PHP e
Laravel devem reportar UTC, o relógio de negócio deve reportar
`America/Sao_Paulo`, PostgreSQL deve reportar UTC e o scheduler deve mostrar o
timezone explícito de cada tarefa. Em divergência, interromper a janela e
restaurar a imagem/configuração anterior; não corrigir com UPDATE ou ALTER em
produção.
