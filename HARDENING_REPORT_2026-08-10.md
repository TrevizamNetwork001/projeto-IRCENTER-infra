# Relatório final de homologação do hardening — 2026-08-10

## 1. Resumo executivo

A Fase H12 homologou, sem deploy, as correções de IRC-001 a IRC-012 originadas na avaliação de 2026-08-08. Todas as validações obrigatórias executáveis localmente passaram. O resultado é **H12 CONCLUÍDA**, com dois achados corrigidos integralmente e dez correções de código aguardando ações controladas de host, rebuild, deploy ou observação. Produção permaneceu inalterada.

Baseline: infraestrutura `8c5d97a45c5141efb051f85330f2fca967ae335d`; aplicação `caf4d9c8ceb6a55203bce5e8279ee40dbb704320`; documentation `602f934d8ef4163bdf36f66480840a6f5fc54f4d`. O trabalho pendente da documentation-app foi preservado.

## 2. Origem

Origem: `RELATORIO_AVALIACAO_PRODUTO_2026-08-08.md`. Escopo: homologação final do hardening, sem desenvolvimento funcional e sem alterações de dados, infraestrutura produtiva, integrações financeiras/fiscais ou CSP enforcement.

## 3. Matriz final IRC-001 a IRC-012

| Achado | Severidade original | Descrição resumida | Correção implementada | Commit(s) | Validação H12 | Status atual | Pendência operacional |
|---|---|---|---|---|---|---|---|
| IRC-001 | Crítico | Testes podiam afetar produção | Runner copia código, usa env/key/banco/cache/storage efêmeros, rede e providers bloqueados | infra `13c81c7`; app `df5786d`, `fa51f43` | App 275/891; documentation 42/183; caches e containers antes/depois idênticos | CORRIGIDO | Nenhuma |
| IRC-002 | Alto | Backups/segredos junto ao deploy | Script confinado, política, exemplo e runbook de migração | infra `fcff021`; app `91fd818` | Fixtures somente em `/tmp`, destino interno/symlink recusados, criptografia fail-closed | CORRIGIDO NO CÓDIGO / AGUARDA MIGRAÇÃO CONTROLADA NO HOST | Migrar backups e Certbot em janelas próprias |
| IRC-003 | Alto | Dumps com leitura ampla | `umask 077`, dirs 0700, arquivos 0600 e auditoria | infra `fcff021` | Modos de fixtures aprovados; auditoria mantém 31 arquivos antigos group/world-readable, incluindo dumps | CORRIGIDO NO CÓDIGO / AGUARDA MIGRAÇÃO CONTROLADA NO HOST | `chmod` individual e verificado dos artefatos antigos |
| IRC-004 | Alto | PHP root/source gravável | Runtime 33:33, read-only, volumes/tmpfs writable mínimos | infra `205a050`, `37c28df` | App/documentation UID/GID 33:33; source/vendor não graváveis; storage/cache graváveis; FPM/queue/scheduler H6 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO | Preparar volumes e recriar serviços PHP por bloco |
| IRC-005 | Médio | Readiness público detalhado/stateful | Resposta mínima e diagnóstico protegido | app `a6207c0` | 200 `ready`; DB indisponível 503; testes provam corpo `unavailable`, ausência de sessão/detalhes e proteção do diagnóstico | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO | Smoke HTTP/autorização pós-deploy |
| IRC-006 | Médio | Ausência de CSP | CSP Report-Only com nonce por request e atributos bloqueados | app `680c786`, `7177ea8` | Header observado; sem unsafe-eval/unsafe-inline/wildcard; E2E sem violações | CORRIGIDO NO CÓDIGO / AGUARDA OBSERVAÇÃO EM PRODUÇÃO | Observar Report-Only; não ativar enforcement |
| IRC-007 | Médio | Ausência de healthchecks | Healthchecks de DB, Redis, FPM, workers e NGINX | infra `e4623fb` | Nove serviços H6 healthy; stale/missing/future heartbeat recusados; queue/scheduler mortos e FPM/DB indisponíveis detectados | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO | Recreate e observar health/restarts |
| IRC-008 | Médio | Imagens flutuantes | Tags concretas e digests SHA-256 completos | infra `d67b1cc`, `8c5d97a` | Scanner passou nos quatro Compose e Dockerfiles | CORRIGIDO NO CÓDIGO / AGUARDA REBUILD CONTROLADO | Garantir imagens nova/anterior locais e rebuildar |
| IRC-009 | Médio | Timezone não formalizado | Runtime/Laravel UTC e business timezone explícita | infra `0aa6a80`; app `5164d65` | Virada de mês/ano, DST histórico, DATE/TIMESTAMP e round-trip UTC/local passaram | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO | Definir/validar BUSINESS_TIMEZONE sem converter histórico |
| IRC-010 | Baixo | Logging/observabilidade | testing separado; stderr,daily; 30 dias; request ID; redaction | infra `d7ea970`; app `97369ca` | PHPUnit validou configuração, marcadores sensíveis e exception sanitizada | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO | Validar canais, retenção e request ID pós-deploy |
| IRC-011 | Baixo | Ferramentas desnecessárias no runtime | Multi-stage e remoção de ferramentas/headers de build | infra `29de85d` | Scanner passou: UID/GID, binários ausentes, módulos, FPM, UTC, ldd e FS; 189.863.874 bytes/118 pacotes | CORRIGIDO NO CÓDIGO / AGUARDA REBUILD CONTROLADO | Rebuild e manter imagem anterior local |
| IRC-012 | Baixo | Sem E2E/acessibilidade | Playwright Chromium, Axe e reporter de segurança | infra `8c5d97a`; app `caf4d9c` | 28 passed, 20 skipped intencionalmente, 0 failed; Axe serious/critical 0; console/page/CSP/external 0 | CORRIGIDO | E2E pós-deploy futuro |

## 4. Commits relacionados

Infraestrutura: `13c81c7`, `fcff021`, `205a050`, `e4623fb`, `d67b1cc`, `0aa6a80`, `d7ea970`, `29de85d`, `37c28df`, `8c5d97a`. Aplicação: `df5786d`, `fa51f43`, `91fd818`, `a6207c0`, `680c786`, `7177ea8`, `5164d65`, `97369ca`, `caf4d9c`.

## 5. Evidências e testes executados

| Validação | Resultado |
|---|---|
| `./scripts/test-isolated.sh app` | 275 testes, 891 asserções; caches/containers/logs produtivos inalterados |
| `./scripts/test-isolated.sh documentation` | 42 testes, 183 asserções; caches/containers/logs produtivos inalterados |
| Total PHPUnit | 317 testes, 1.074 asserções, zero falhas |
| `./scripts/test-e2e.sh` | 28 passed, 20 skipped, zero falhas, 2,2 min |
| Backup | Fixtures `/tmp` aprovadas |
| Heartbeat/H6 | Testes estáticos e stack isolada aprovados |
| Imagens/build/runtime | Scanners aprovados |
| Compose | Quatro arquivos aprovados; produção renderizada com `--no-env-resolution` para não ler `.env` real |

O primeiro disparo isolado foi recusado pelo Compose ao tentar abrir `.env`; nenhuma stack foi criada e as salvaguardas provaram estado produtivo inalterado. A execução válida usou `COMPOSE_DISABLE_ENV_FILE=1`.

## 6. E2E e acessibilidade

Chromium headless, um worker, viewports 1440x900, 768x1024 e 390x844. Desktop executa a cobertura funcional completa; tablet/mobile executam autenticação/teclado, clientes, financeiro fake e responsividade. Os 20 skips são intencionais pela matriz `test.skip` fora do projeto desktop, evitando repetir fluxos não dependentes de viewport. Axe executou nas páginas cobertas com serious=0 e critical=0. O reporter encerrou sem console errors inesperados, page errors, CSP violations ou requests externos inesperados.

## 7. Segurança de containers e runtime

H6 confirmou postgres, redis, app, queue, scheduler, documentation-app, documentation-queue, documentation-scheduler e web healthy. App e documentation executaram como 33:33; source/vendor não graváveis e storage/cache graváveis. Alteração de source foi recusada. NGINX→FPM→Laravel retornou readiness 200. Com DB parado houve 503; com FPM parado, 504 e healthcheck web falho. O runtime não contém Composer, Git, unzip, curl, gcc/g++, make/cmake, phpize/php-config, headers ou pacotes `-dev`; módulos esperados, libfcgi, FPM e ldd passaram. Tamanho observado: 189.863.874 bytes; 118 pacotes.

## 8. Backups e segredos

O teste confinado comprovou umask 077, diretórios 0700, arquivos 0600, recusa de destino dentro de `/opt/ircenter`, recusa de escape/symlink, criptografia sem plaintext residual e retenção limitada ao padrão. Nenhum backup real foi lido, movido ou alterado. A auditoria quantitativa permanece: 54 arquivos, 31 group/world-readable, 26 dumps e árvore Certbot com 17 diretórios, 13 arquivos e 4 symlinks. A migração e o chmod individual continuam pendentes.

## 9. CSP e readiness

CSP permanece exclusivamente `Content-Security-Policy-Report-Only`: sem `unsafe-eval`, `unsafe-inline` ou wildcard global; nonce por request; `script-src-attr 'none'` e `style-src-attr 'none'`. E2E: zero violações. Readiness expõe somente `{"status":"ready"}`/`{"status":"unavailable"}`, sem Set-Cookie, XSRF, session, database, redis, timestamp, hostname, version ou exception. `/system-diagnostic` exige autenticação e administração.

## 10. Imagens, timezone e logging

Todas as referências externas possuem tag concreta e digest completo; nenhuma `latest`, `nginx:alpine` ou `composer:2` genérica. PHP e Laravel usam UTC; regra de negócio usa America/Sao_Paulo. Testes cobriram competência, viradas, DST histórico, DATE/TIMESTAMP e idempotência. Logging de teste é separado; produção declara `stderr,daily`, retenção 30 dias, request ID e redaction. Marcadores fictícios para password, Authorization/Bearer, tokens, HMAC, DATABASE_URL, POSTGRES_PASSWORD, Pix copia-e-cola e private key não vazaram; exceptions mantiveram tipo/mensagem sanitizada observável.

## 11. Scanners e limitações

Passaram: backup, heartbeat, imagens Docker, build context, runtime PHP, guardrails E2E e reporter de segurança E2E. `shellcheck` não está instalado e não houve acesso à internet para instalá-lo; os scripts executados passaram pelo interpretador. O scanner de segredos foi limitado a arquivos versionados/relevantes e nunca abriu `.env`, dumps, backups, certificados ou private keys. Alguns arquivos/objetos Git da documentation-app têm permissão de leitura negada ao usuário homologador; a suíte Docker ainda passou e o estado conhecido foi obtido sem chmod/chown.

## 12. Pendências operacionais consolidadas

| Item | Origem | Necessita | Risco | Janela | Validação | Rollback |
|---|---|---|---|---|---|---|
| Migração de backups | IRC-002 | Destino externo permitido, criptografia e restore | Perda/exposição | Própria | checksum, modos, restore | manter paths anteriores intactos |
| chmod individual dos dumps antigos | IRC-003 | Inventário e aprovação por arquivo | Indisponibilidade/acesso indevido | Backups | modos e owner por item | restaurar modo/owner registrado |
| Migração Certbot | IRC-002 | Paths/mounts e renovação testados | HTTPS indisponível | Própria | cadeia, leitura NGINX, renovação | mounts/paths anteriores |
| Rebuild imagem PHP | IRC-008/011 | Imagens pinadas nova e anterior locais | Runtime incompatível | Deploy | scanner runtime/ldd/FPM | imagem anterior local |
| Volumes storage/cache | IRC-004 | UID/GID 33:33 e mounts corretos | Erros de permissão | Deploy | fixture writable | mounts/volumes anteriores |
| Containers não-root | IRC-004 | Recreate PHP por bloco | Falha de escrita/startup | Deploy | id, source RO, health | Compose/imagem anteriores |
| Healthchecks | IRC-007 | Recreate e observação | Restart/indisponibilidade | Deploy | nove healthy e probes | definições anteriores |
| Imagens pinadas | IRC-008 | Disponibilidade local/digests | Pull/rebuild falho | Pré-deploy | scanner e inspect | digests anteriores locais |
| BUSINESS_TIMEZONE | IRC-009 | Variável America/Sao_Paulo | Datas de negócio incorretas | Deploy | smoke temporal | configuração anterior |
| Logging | IRC-010 | Canais/permissões/retenção | Perda ou vazamento de logs | Deploy | request ID/redaction | config anterior |
| CSP Report-Only | IRC-006 | Observação sem enforcement | Regressão de frontend | Pós-deploy | zero violações esperadas | middleware/header anterior |
| E2E pós-deploy | IRC-012 | Janela/autorização e dados controlados | Efeito real se mal configurado | Pós-deploy | guardrails + matriz | interromper, sem mutação |

## 13. Riscos residuais

- Backups, dumps e Certbot antigos continuam no host e exigem migração controlada.
- Código corrigido ainda não está em produção; imagens PHP exigem rebuild/recreate.
- CSP precisa de observação Report-Only antes de qualquer decisão futura de enforcement.
- A documentation-app mantém trabalho da Fase 23. CSP própria, E2E próprio e integração dessa fase são evoluções separadas e não reabrem IRC-012 do app principal.
- A validação pós-deploy e a observação operacional ainda não ocorreram.

## 14. Plano de deploy e rollback

O plano único está em `docs/HARDENING_DEPLOY_RUNBOOK.md`: A pré-check/backup; B diretórios/permissões; C imagens pinadas; D stack isolada; E volumes; F PHP por blocos; G NGINX; H healthchecks; I HTTP/auth; J workers; K logging; L timezone; M CSP; N Certbot em janela própria; O backups em janela própria.

Rollback é definido por bloco e exige previamente imagem, Compose, mounts, volumes, configuração, NGINX, Certbot e paths de backup anteriores. Nenhum rollback depende de download. O startup produtivo não deve executar migration automática nem `php artisan migrate --force` cego.

## 15. Conclusão

| Achado | Resultado conclusivo |
|---|---|
| IRC-001 | CORRIGIDO |
| IRC-002 | CORRIGIDO NO CÓDIGO / AGUARDA MIGRAÇÃO CONTROLADA NO HOST |
| IRC-003 | CORRIGIDO NO CÓDIGO / AGUARDA MIGRAÇÃO CONTROLADA NO HOST |
| IRC-004 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO |
| IRC-005 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO |
| IRC-006 | CORRIGIDO NO CÓDIGO / AGUARDA OBSERVAÇÃO EM PRODUÇÃO |
| IRC-007 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO |
| IRC-008 | CORRIGIDO NO CÓDIGO / AGUARDA REBUILD CONTROLADO |
| IRC-009 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO |
| IRC-010 | CORRIGIDO NO CÓDIGO / AGUARDA DEPLOY CONTROLADO |
| IRC-011 | CORRIGIDO NO CÓDIGO / AGUARDA REBUILD CONTROLADO |
| IRC-012 | CORRIGIDO |

Nenhum deploy, push, pull produtivo, restart/recreate produtivo, alteração de `.env`, PostgreSQL, Redis, backup real, Certbot real, dado de cliente ou integração live foi realizado.
