# Deploy controlado do hardening IRC-001 a IRC-012

Este runbook é um plano. Ele não autoriza deploy, pull, rebuild, recreate, migração, alteração de permissões ou acesso a integrações live. A execução exige janela aprovada, operador identificado e registro externo das evidências.

## Princípios e referências obrigatórias

- Não usar um `docker compose up -d` indiscriminado.
- Não executar migrations automaticamente. O entrypoint atual (`docker/php/runtime-entrypoint.sh`) não migra schema. Os comandos `migrate:fresh --force` de `compose.e2e.test.yaml` pertencem exclusivamente ao banco descartável E2E.
- Antes da janela, registrar em local externo ao checkout: commit da infraestrutura e dos dois aplicativos; conteúdo efetivo e checksum do Compose anterior; IDs/digests das imagens anteriores; nomes e opções dos mounts/volumes anteriores; configuração NGINX anterior; caminhos anteriores de Certbot e backups; permissões/owners anteriores; variáveis obrigatórias presentes (sem registrar valores).
- Garantir que todas as imagens novas e anteriores já estejam disponíveis localmente. Rollback não pode depender de download.
- Não misturar a migração de Certbot nem de backups com o recreate PHP/web. Cada uma exige janela própria.
- Não executar operação financeira/fiscal real durante validação. Manter providers live e transmissão fiscal desabilitados.

## Checkpoint 0 — GO/NO-GO global

GO somente se backup aprovado estiver confirmado e restaurável, referências anteriores estiverem registradas, imagens nova e anterior estiverem locais, quatro Compose validarem, suítes isoladas e E2E estiverem verdes, secrets/config obrigatórios existirem, storage/cache estiverem preparados e não houver migration inesperada.

NO-GO diante de imagem ausente, configuração inválida, PostgreSQL/Redis não healthy, `nginx -t` falho, FPM/queue/scheduler falho, erro de APP_KEY, migration não planejada, secret/config ausente, backup não confirmado ou ausência de uma referência de rollback.

## Etapas de deploy

### A — Pré-check e backup

1. Congelar escopo e registrar commits, imagens, Compose, mounts, volumes, configuração e estado/health/restart count.
2. Confirmar backup aprovado e teste de restauração previamente concluído; não mover os backups antigos nesta etapa.
3. Validar espaço em disco, certificados vigentes, banco/Redis healthy e ausência de incidente ativo.
4. Checkpoint: GO somente com o Checkpoint 0 integralmente satisfeito.

Rollback: nenhuma mudança aplicada; encerrar a janela.

### B — Preparar diretórios e permissões externas

1. Criar/preparar somente os diretórios writable de `storage` e `bootstrap/cache`, com UID/GID 33:33 e modos aprovados.
2. Não alterar dumps antigos, Certbot nem código-fonte nesta etapa.
3. Validar escrita como UID 33 e ausência de escrita em source/vendor.

Rollback: restaurar mounts, owners e modos previamente registrados, um caminho por vez; não aplicar mudança recursiva ampla.

### C — Disponibilizar/buildar imagens pinadas

1. Conferir tags e digests contra `docs/CONTAINER_IMAGE_POLICY.md`.
2. Construir a imagem PHP do commit aprovado sem substituir/remover a imagem anterior.
3. Executar `scripts/check-container-images.sh`, `scripts/check-build-context.sh` e `scripts/check-php-runtime.sh` na imagem candidata.
4. Checkpoint: NO-GO se digest divergir, imagem anterior não estiver local ou scanner falhar.

Rollback: remover a candidata somente depois da janela; manter/selecionar a imagem anterior já local.

### D — Validar stack isolada

Executar suítes PHP, stack H6 e E2E contra a candidata, com providers fake, rede isolada e bancos descartáveis. Validar 317 testes PHP, 1.074 asserções, Playwright sem falhas, Axe serious/critical zero e CSP violations zero.

Rollback: remover somente os recursos do projeto isolado.

### E — Preparar volumes writable

1. Confirmar volumes nomeados de storage e tmpfs de cache.
2. Confirmar que a aplicação não depende de conteúdo efêmero do cache anterior.
3. Checkpoint: GO somente se app e documentation conseguirem criar/remover fixture inócua em storage/cache como 33:33.

Rollback: recolocar a definição e os mounts anteriores registrados; preservar o volume anterior até aceite final.

### F — Recreate controlado dos serviços PHP

1. Recriar em blocos pequenos, começando por app/documentation-app e só depois queue/scheduler de cada aplicação.
2. Não executar `php artisan migrate --force` nem scripts Composer que migrem banco.
3. Aguardar healthcheck de cada serviço antes do próximo.
4. Validar UID/GID 33:33, filesystem read-only e extensões/runtime.

Rollback: parar apenas o bloco afetado, restaurar imagem/Compose/mounts/volumes/configuração anteriores e recriar esse bloco com a imagem anterior local.

### G — Recreate controlado do web/NGINX

1. Executar e aprovar `nginx -t` antes da troca.
2. Recriar somente `web` após FPMs healthy.
3. Manter os mounts Certbot anteriores nesta janela.

Rollback: restaurar imagem e configuração NGINX anteriores já registradas e recriar somente `web`.

### H a L — Validações operacionais

- H: postgres, redis, app, queue, scheduler, documentation-app, documentation-queue, documentation-scheduler e web healthy.
- I: `/up`, `/health/ready`, `/login`, login autorizado, dashboard, clientes, Financeiro com live desabilitado e documentation.
- J: heartbeat e execução controlada de queue/scheduler, sem gerar cobrança ou emissão fiscal.
- K: `request_id`, stderr/daily, retenção 30 dias e sanitização; não truncar logs.
- L: PHP/Laravel UTC e `BUSINESS_TIMEZONE=America/Sao_Paulo`, sem converter timestamps históricos.

Rollback: qualquer falha bloqueante aciona rollback do último bloco alterado; falha transversal aciona retorno coordenado de PHP e web ao conjunto anterior.

### M — Observar CSP Report-Only

Manter `Content-Security-Policy-Report-Only`; não ativar enforcement. Observar somente os mecanismos já existentes e registrar violações por rota/navegador.

Rollback: restaurar a configuração anterior do middleware/header se houver regressão funcional; não “corrigir” removendo outras proteções sem análise.

### N — Migrar Certbot em janela própria

Executar somente após inventário, cópia verificável, permissões alvo e rollback aprovados. Validar renovação em modo seguro, leitura pelo NGINX e cadeia HTTPS antes de retirar o path anterior.

Rollback: restaurar mounts e paths Certbot anteriores, que devem permanecer intactos durante a janela.

### O — Migrar backups em janela própria

Seguir `docs/BACKUP_MIGRATION_RUNBOOK.md`. Corrigir individualmente dumps antigos, migrar para raiz externa permitida, verificar criptografia/checksums/restauração e somente então decidir sobre a origem.

Rollback: manter paths e arquivos anteriores intactos até aceite; reverter configuração ao destino anterior registrado. Nunca depender de mover de volta um único exemplar.

## Smoke pós-deploy futuro

- [ ] `/up` responde com sucesso.
- [ ] `/health/ready` responde 200 e `{"status":"ready"}` sem cookie/detalhes internos.
- [ ] `/login`, login real autorizado e logout funcionam.
- [ ] Dashboard, clientes, Financeiro e documentation carregam.
- [ ] Financeiro/fiscal mostram estado live desabilitado; nenhuma chamada live ocorre.
- [ ] Queue e scheduler mantêm heartbeat.
- [ ] Todos os nove serviços estão healthy e sem restart inesperado.
- [ ] `X-Request-ID` e logs sanitizados aparecem nos canais esperados.
- [ ] PHP/Laravel estão em UTC e regra de negócio em America/Sao_Paulo.
- [ ] HTTPS e certificados continuam válidos.
- [ ] CSP permanece Report-Only e violações são registradas.
- [ ] Não existe novo erro de APP_KEY.

## Observação pós-deploy

Janela recomendada: 60 minutos de acompanhamento contínuo após o último recreate, seguida de revisões em 4 e 24 horas usando apenas os mecanismos existentes. Verificar health, restart counts, queue, scheduler, 5xx, logs, CSP violations, erros de permissão, storage/cache, NGINX/FPM e conectividade PostgreSQL/Redis. Qualquer erro crescente, perda de heartbeat, 5xx persistente, falha de escrita ou restart loop é NO-GO e deve acionar o rollback do bloco relacionado.
