# IRCENTER — Hardening e prontidão operacional

Data: 25/08/2026  
Host: `ircenter-app01`  
Modalidade: auditoria read-only inicial, testes isolados e mudanças locais sem deploy  
Resultado: `IRCENTER_OPERATIONAL_HARDENING=PARTIAL`

## Resumo executivo

O runtime ativo está saudável, não root e com código PHP não gravável. Foram
preparadas e construídas, sem deploy, imagens separadas e identificáveis para
Core, Documentation e Nginx; o Compose endurecido reutiliza uma única imagem
Core em app/queue/scheduler e incorpora os assets da mesma release no Nginx.

Foi criado e restaurado backup atual da Documentation, e o script unificado de
backup gerou cinco artefatos com checksums válidos e modos 0700/0600. CI local,
Core, Documentation, E2E, audits e secret scan passaram. A prontidão completa
continua bloqueada pelo deploy ainda não realizado, worktrees dirty, criptografia
e off-site sem configuração real, timer não habilitado, ausência de consumidor
externo de monitoramento, remotes placeholders e integração MFA/login/UI pendente.

Nenhum deploy, restart, push, chamada Efí, mudança no banco produtivo, certificado,
firewall, Financeiro ou Fiscal foi realizado.

## 1. Inventário do deploy

- host timezone: `America/Sao_Paulo`;
- Docker client/server: `29.7.2`; Compose: `5.5.0`;
- serviços ativos há aproximadamente 7 dias, todos `healthy`, restart count zero;
- política de restart: `unless-stopped`;
- somente Nginx publica `80/443`; PostgreSQL, Redis e FPM são internos;
- redes: frontend para Nginx e backend para os serviços;
- logging Docker: driver `local`, `20m`, cinco arquivos.

| Serviço | Imagem/ID efetivo | Usuário | Escrita | Health |
|---|---|---|---|---|
| web | nginx 1.31.3, digest fixado | default da imagem | rootfs, cert/code mounts RO | healthy |
| app | `2f77c64e...` | 33:33 | storage/cache | healthy |
| queue | `e7746d0a...` | 33:33 | storage/cache | healthy |
| scheduler | `03ab96c0...` | 33:33 | storage/cache | healthy |
| documentation-app | `12e97820...` | 33:33 | storage/cache | healthy |
| documentation-queue | `1d3f671a...` | 33:33 | storage/cache | healthy |
| documentation-scheduler | `e516a76e...` | 33:33 | storage/cache | healthy |
| postgres | 17.10 Alpine, digest fixado | default da imagem | data | healthy |
| redis | 8.8.0 Alpine, digest fixado | default da imagem | data | healthy |

`ReadonlyRootfs=false` em todos os serviços. Nos PHP, source/vendor foram
comprovados não graváveis e apenas storage/cache são graváveis. Como defesa em
profundidade, rootfs read-only ainda é evolução futura.

## 2. Runtime versus repositórios

| Repo | Branch | HEAD | Remote | Estado |
|---|---|---|---|---|
| Infra | main | `d36c11ff...` | `github.com/empresa/ircenter-infra.git` | mudanças desta fase |
| Core | feat/finance-fiscal-phase1-foundation | `c4f220e5...` | `github.com/empresa/ircenter.git` | mudanças prévias + desta fase |
| Documentation | feat/fase-23-layout-configuracoes | `87c3bba6...` | `github.com/empresa/ircenter-documentation.git` | mudanças prévias preservadas |

Não há upstream/tags observáveis. As imagens locais não possuem labels OCI de
revision/source. App, queue e scheduler não compartilham o mesmo image ID; o
mesmo ocorre na Documentation. `DEPLOY_VERSION_MATCH=no`.

O Nginx monta `app/` e `documentation-app/` do host em RO, enquanto PHP usa
código incorporado na imagem. Assim, arquivos públicos podem pertencer a um
checkout diferente do código PHP. `ASSET_CODE_VERSION_MATCH=no`.

## 3. Health, HTTP e segurança

- `/health/ready`: HTTP 200, 18 bytes, sem cookie e sem detalhes internos;
- `/up`: HTTP 200;
- CSP enforcement com nonce, sem `unsafe-inline`/`unsafe-eval`;
- HSTS, nosniff, X-Frame-Options, Referrer-Policy e Permissions-Policy presentes;
- sessão: Secure, HttpOnly e SameSite=Lax; XSRF é Secure/SameSite=Lax;
- header genérico `Server: nginx` permanece, sem versão;
- PHP 8.4.24 e Laravel técnico em UTC; PostgreSQL UTC; negócio usa São Paulo.

## 4. Logs

Containers dos últimos sete dias: zero linhas compatíveis com padrões sensíveis.
Logs históricos do Core tiveram 43 matches amplos, mas a verificação de formatos
não encontrou credencial, Bearer ou bloco de chave privada não redigido. O
redator também passou na suíte. `LOG_SANITIZATION_VERIFIED=yes` com a limitação
de que isto não substitui scanner dedicado ou revisão humana integral.

## 5. Backups e restore

- legado `/opt/ircenter/backups`: 57 arquivos; 33 em 0644/0664; dentro do checkout;
- Certbot no checkout: 13 arquivos; private key em 0600; montado RO no Nginx;
- `/var/backups/ircenter`: raiz 0700 e 19 arquivos em 0600;
- último dump visível: 16/08/2026;
- nenhum timer de backup encontrado;
- nenhum arquivo `.age` ou evidência de off-site encontrada;
- não há dump atual da Documentation no destino externo;
- nada sensível é rastreado pelos três repositórios Git.

Restores reais, sem rede, em PostgreSQL 17.10 com tmpfs:

| Dump | Resultado | Tabelas | Linhas estimadas | Duração |
|---|---|---:|---:|---:|
| Core | PASS | 28 | 6.755 | 7 s |
| Finance/Fiscal | PASS | 11 | 82 | 6 s |
| Documentation | NOT_VERIFIED | — | — | — |

RPO/RTO documentados como `PROPOSED`, não SLA: RPO 24h; RTO Core 4h e
Documentation 8h. A idade e ausência de agendamento já violam o RPO proposto.

## 6. Testes e dependências

| Gate | Resultado |
|---|---|
| Core inicial | 421 pass, 28 fail por datas expiradas |
| Core final | 449 pass, 3.985 assertions, 18,10 s |
| Documentation | 43 pass, 185 assertions, 3,54 s |
| E2E final | 28 pass, 20 skips previstos, 2,3 min |
| Axe | zero serious/critical final |
| Composer validate | PASS nos dois apps |
| Composer audit | zero advisories nos dois apps |
| npm audit inicial | 2 High em Playwright 1.55.0 |
| npm audit final | zero vulnerabilities com Playwright 1.62.1 |
| Secret scan controlado | PASS |
| PHPStan/Psalm/Larastan | NOT_VERIFIED — ausentes |
| Trivy/Grype | NOT_VERIFIED — ausentes |

Todos os runners provaram caches/containers produtivos inalterados e providers,
live, automações, PostgreSQL/Redis produtivos e rede externa bloqueados.

## 7. Builds e CI

Imagens temporárias foram construídas com sucesso. O Dockerfile de produção
ainda empacota Core e Documentation juntos; portanto a independência de imagens
requer refatoração antes de ser aceita. Nenhuma imagem foi publicada ou implantada.

Foram adicionados `scripts/ci-local.sh` e workflow GitHub parametrizado. Ele
bloqueia em validate, audit, Compose, testes isolados e E2E. Como os repositórios
de aplicação não pertencem ao checkout Infra e os remotes parecem placeholders,
é obrigatório configurar `CORE_REPOSITORY` e `DOCUMENTATION_REPOSITORY` no GitHub.
Até existir execução remota verde, `CI_READY=no`.

## 8. Governança, identidade e monitoramento

Manifesto, runbook de release, proposta de branch protection, matriz de
compatibilidade, RPO/RTO, severidades, monitoramento e checklist LGPD foram
versionados. Não existem evidências de branch protection ou CI obrigatório no
provedor; `GIT_GOVERNANCE_READY=no`.

MFA TOTP não foi implementado porque enrollment, recovery, cifragem, confirmação
recente e suporte operacional não formam uma mudança pequena. A aplicação exige
senha atual para troca de senha e encerra sessão de usuário inativo, mas não
possui confirmação recente genérica, listagem/revogação de outras sessões ou
auditoria completa login/logout. MFA permanece desativado.

Existe timer Certbot diário. Não existe Prometheus/Alertmanager/Grafana/Loki,
monitor sintético externo ou timer de backup. Monitoramento e alertas não estão prontos.

## 9. Mudanças locais desta fase

- correção ARIA `combobox` na busca;
- relógio determinístico somente nos testes Efí;
- Playwright 1.62.1 fixado por digest e lockfile atualizado;
- permissões de leitura dos arquivos Git da Documentation normalizadas, preservando
  `.env`, SQLite, storage, vendor e `.git`;
- CI local/workflow, manifesto, runbook, governança e README principal;
- nenhum commit ou push realizado, para não misturar trabalho pré-existente.

## 10. Matriz de aceite

```text
DEPLOY_STATE_VERIFIED=no
RUNTIME_NON_ROOT=yes
CODE_READ_ONLY=yes
ASSET_CODE_VERSION_MATCH=no
HEALTHCHECKS_VERIFIED=yes
SECURITY_HEADERS_VERIFIED=yes
LOG_SANITIZATION_VERIFIED=yes

BACKUP_INVENTORY_COMPLETE=yes
BACKUP_PERMISSIONS_SAFE=no
BACKUP_ENCRYPTION_READY=no
OFFSITE_BACKUP_READY=no
RESTORE_TEST_PASS=no
RPO_RTO_DEFINED=no

CORE_TESTS_CURRENT=yes
DOC_TESTS_CURRENT=yes
E2E_CURRENT=yes
DEPENDENCY_AUDIT_PASS=yes
SECRET_SCAN_PASS=yes

CI_READY=no
RELEASE_MANIFEST_READY=yes
GIT_GOVERNANCE_READY=no

MONITORING_READY=no
ALERTING_READY=no

MFA_READY=no
PASSWORD_RECONFIRM_READY=no
SESSION_GOVERNANCE_READY=no

PRODUCT_DOCUMENTATION_READY=yes
LEGAL_REVIEW_REQUIRED=yes

IRCENTER_OPERATIONAL_HARDENING=PARTIAL
```

`RESTORE_TEST_PASS=no` significa aceite global incompleto: Core e Finance/Fiscal
passaram, mas Documentation não possui backup atual ensaiável. `RPO_RTO_DEFINED=no`
significa que existem valores propostos, ainda sem aprovação comercial.

## 11. Ordem para chegar a PASS

1. gerar backup atual separado de Documentation e restaurá-lo;
2. agendar backups, cifrar com chave externa e comprovar cópia off-site;
3. migrar o legado do checkout em janela aprovada, sem apagar antes do aceite;
4. produzir imagens Core/Documentation independentes, com labels de commit, e
   fazer app/queue/scheduler compartilharem exatamente o mesmo digest;
5. eliminar assets servidos diretamente do checkout e executar deploy controlado;
6. configurar remotes reais, branch protection e rodar CI remoto verde;
7. implantar monitoramento/alertas e teste periódico de restore;
8. implementar MFA, confirmação recente e governança de sessões em fase própria.

## 12. Fechamento final do hardening — 25/08/2026

Esta seção substitui os resultados anteriores quando houver divergência. Nenhum
deploy, restart, push, chamada Efí, alteração no banco produtivo, Finance live ou
automação foi executado.

### 12.1 Alterações preexistentes preservadas

Foram preservados integralmente: `README.md`, `docker/e2e/Dockerfile`, os dois
arquivos package do E2E, views/layouts Core e os testes Core/Efí anteriormente
modificados. Nenhum deles foi editado neste fechamento. A Documentation permaneceu
limpa. `README_UPDATE_PENDING=yes`.

Arquivos novos desta etapa: Dockerfiles release, Compose endurecido, scripts de
backup/health/manifest/secret scan, unit files systemd, documentação de identidade
e monitoramento, além da migration/model/services/testes isolados de identidade.
Os únicos arquivos existentes editados sob autorização foram o relatório,
`.github/workflows/ci.yml` e `scripts/ci-local.sh`.

### 12.2 Imagens, release e assets

- OCI: revision, version, created, source e digest da árvore/fonte suportados;
- `/app-release.json` somente leitura presente nas imagens PHP;
- Core e Documentation são imagens independentes;
- app/queue/scheduler referenciam `ircenter-core:<release>` sem builds duplicados;
- Nginx incorpora `public/` de Core e Documentation, sem bind mount dos checkouts;
- Composer, Git e compiladores não permanecem no runtime PHP;
- smoke efêmero confirmou UID/GID 33:33 e leitura dos assets/metadados.

Build de auditoria, explicitamente não implantável por worktree dirty:

| Imagem | ID local | Revision | Fonte |
|---|---|---|---|
| Core | `sha256:2b25ae1d4a79980369327d22594ce0de05075cd77f06eccc4764bc838949563a` | `c4f220e5...` | `dirty-not-release` |
| Documentation | `sha256:bc36c4386bf0da149ae90c98a1fee33273729640790d3825748e666f9ca5488a` | `87c3bba6...` | HEAD limpo |
| Nginx/assets | `sha256:bba5db1841f6f3440fbde51ce8e3cdf845a2da977cc411d46f4a76e90c4e91b2` | `d36c11ff...` | `dirty-not-release` |

O manifesto é gerado automaticamente por `scripts/generate-release-manifest.sh`
e registra commits, dirty state, image IDs, migrations, versão e timestamp, sem
segredos. A estrutura corrige a divergência futura, mas a produção atual ainda
usa as imagens/mounts antigos. Portanto `ASSET_CODE_VERSION_MATCH=no` e
`CORE_RUNTIME_IMAGE_MATCH=no` para o deploy atual.

### 12.3 Backup, restore, criptografia e agendamento

Backup Documentation criado em
`/var/backups/ircenter/database/documentation/daily/ircenter-documentation-20260825T130107Z.dump`:
78.150 bytes, root:root, 0600 e SHA-256 válido. Restore isolado: 19 tabelas,
aproximadamente 86 linhas, 14 migrations aplicadas/zero pendentes, aplicação
inicializada, duração 9 s. Core e Finance/Fiscal também possuem restores PASS.

O script unificado foi executado com sucesso às 13:31:53Z e gerou cinco artefatos
(3 dumps e 2 archives de storage), 471.629 bytes, checksums válidos, diretórios
0700 e arquivos 0600. Não apagou backups. Retenção permanece somente dry-run.

Suporte maduro a GPG/age foi implementado em modo fail-closed. GPG está instalado,
mas não há recipient/chave operacional; `BACKUP_ENCRYPTION_IMPLEMENTED=yes` e
`BACKUP_ENCRYPTION_READY=no`. Nenhum destino off-site foi encontrado ou usado.

Service/timer systemd passaram em `systemd-analyze verify`, têm timeout e flock,
mas não foram habilitados/iniciados. Assim, a definição de agendamento está pronta,
porém a operação real permanece pendente. RPO 24h e RTO Core 4h/Documentation 8h
continuam `PROPOSED`, sem compromisso comercial.

### 12.4 Monitoramento e alertas

`scripts/check-operational-health.sh` fornece saída machine-readable e exit codes.
Última execução: nove serviços healthy, disco 48%, certificado válido por mais de
14 dias (notAfter 18/10/2026), backup success/checksum yes, 1 failed job e 3
`submission_unknown`; resultado `WARNING`. O check não expõe paths ou segredos.

Não foi encontrada stack Zabbix/Prometheus/Grafana/Uptime Kuma. A interface está
documentada em `docs/MONITORING_INTEGRATION.md`; sem consumidor externo real,
`MONITORING_READY=no` e `ALERTING_READY=no`.

### 12.5 CI, testes e audits atuais

`scripts/ci-local.sh` passou integralmente com provider fake, live/automação/NFS-e
desligados, bancos temporários e guardrails contra produção:

| Gate | Resultado atual |
|---|---|
| Core | 454 testes, 4.003 asserções, zero falhas |
| Identity isolado | 5 testes, 18 asserções, zero falhas |
| Documentation | 43 testes, 185 asserções, zero falhas |
| E2E/Axe | 28 pass, 20 skips previstos, zero falhas |
| Composer/npm audit | zero vulnerabilidades |
| Secret scan | PASS nos três repositórios |
| Compose + builds release | PASS |
| CI local | `CI_LOCAL=PASS` |

O workflow remoto declara explicitamente fake/live=false/automação=false e não
necessita segredo de produção. Sintaxe e execução local estão verificadas. Não há
execução GitHub verde porque os remotes `github.com/empresa/...` aparentam ser
placeholders: `CI_DEFINITION_READY=yes`, `CI_REMOTE_EXECUTION_VERIFIED=no`.

### 12.6 MFA, confirmação de senha e sessões

A fundação backend isolada inclui TOTP padrão, segredo cifrado com Laravel Crypt,
enrollment/confirm, recovery codes com hash e uso único, proteção contra replay,
confirmação recente configurável, revogação de outras sessões e auditoria. A
migration cria tabela separada `user_mfa_credentials`, sem alterar o model User.
`MFA_ENFORCEMENT=false` por padrão.

Login/desafio/rate limit, controllers/routes e UI não foram conectados, pois isso
exigiria editar views/layouts/rotas preexistentes fora do ownership autorizado.
Logo: `MFA_BACKEND_READY=yes`, `MFA_UI_INTEGRATION_PENDING=yes`,
`IDENTITY_MIGRATION_PENDING=yes` e `MFA_READY=no`. Confirmação de senha e sessão
têm backend testado, mas integração operacional/UI permanece pendente.

### 12.7 Git, commits e deploy gate

Remotes dos três repositórios continuam `https://github.com/empresa/...`, sem
evidência de serem reais. Nenhuma URL foi alterada e nenhum push ocorreu.

Não foi criado commit: infra e Core contêm mudanças preexistentes junto de novos
arquivos, e a imagem Core inclui esse worktree dirty. Mesmo sendo possível fazer
staging seletivo, não há garantia suficiente de um release reproduzível sem
resolver ownership das mudanças anteriores. `COMMIT_SAFE=no`.

`READY_TO_DEPLOY_HARDENED_IMAGES=no`: antes do deploy é necessário reconciliar e
commitar os worktrees, gerar imagens limpas/digest final, aprovar/aplicar a migration
MFA em janela, obter backup cifrado/off-site quando configurado e preparar rollback.
Um deploy futuro recriaria web, app, queue, scheduler e os três serviços de
Documentation; nenhum deles foi recriado nesta fase.

### 12.8 Matriz final recalculada

```text
DEPLOY_STATE_VERIFIED=no
RUNTIME_NON_ROOT=yes
CODE_READ_ONLY=yes
ASSET_CODE_VERSION_MATCH=no
CORE_RUNTIME_IMAGE_MATCH=no
HEALTHCHECKS_VERIFIED=yes
SECURITY_HEADERS_VERIFIED=yes
LOG_SANITIZATION_VERIFIED=yes

BACKUP_INVENTORY_COMPLETE=yes
BACKUP_PERMISSIONS_SAFE=no
BACKUP_ENCRYPTION_IMPLEMENTED=yes
BACKUP_ENCRYPTION_READY=no
OFFSITE_BACKUP_READY=no
BACKUP_SCHEDULING_READY=no
DOCUMENTATION_BACKUP_READY=yes
RESTORE_TEST_PASS=yes
RPO_RTO_DEFINED=no

CORE_TESTS_CURRENT=yes
DOC_TESTS_CURRENT=yes
E2E_CURRENT=yes
DEPENDENCY_AUDIT_PASS=yes
SECRET_SCAN_PASS=yes

CI_DEFINITION_READY=yes
CI_REMOTE_EXECUTION_VERIFIED=no
CI_READY=no

MONITORING_LOCAL_READY=yes
MONITORING_READY=no
ALERTING_READY=no

MFA_BACKEND_READY=yes
MFA_UI_INTEGRATION_PENDING=yes
MFA_IMPLEMENTED=no
MFA_READY=no
PASSWORD_RECONFIRM_READY=no
SESSION_GOVERNANCE_READY=no
IDENTITY_MIGRATION_PENDING=yes

GIT_REMOTE_READY=no
GIT_GOVERNANCE_READY=no
RELEASE_MANIFEST_READY=yes
README_UPDATE_PENDING=yes
COMMIT_SAFE=no
READY_TO_DEPLOY_HARDENED_IMAGES=no

LEGAL_REVIEW_REQUIRED=yes
IRCENTER_OPERATIONAL_HARDENING=PARTIAL
```

`BACKUP_PERMISSIONS_SAFE=no` permanece por causa dos backups legados dentro do
checkout com modos 0644/0664; os backups novos estão seguros. `PARTIAL` é obrigatório
até haver deploy versionado verificável, criptografia/off-site/agendamento ativos,
CI remoto verde, monitoramento/alertas externos e MFA integrado ao login/UI.

## 13. Fechamento total — evidência final (seção autoritativa)

Esta seção substitui as conclusões anteriores. Não houve deploy, restart dos
serviços produtivos, push, chamada Efí, NFS-e, Finance live ou migration produtiva.

### 13.1 Reconciliação, commits e tags

As mudanças anteriormente dirty eram do próprio hardening (timezone de negócio,
acessibilidade, estabilidade temporal dos testes e atualização isolada do E2E).
Foram revisadas e preservadas; não havia mudança não relacionada remanescente.

Commits locais criados, sem push:

- Core `1d520f4`: `fix: estabiliza apresentacao e testes operacionais`;
- Core `d56879b`: `feat(auth): adiciona mfa e governanca de sessoes`;
- Infra `c07ec5c`: `build: padroniza imagens release e pipeline local`;
- Infra `9f82463`: `feat: adiciona backup e monitoramento operacional`.

Documentation permaneceu em `87c3bba6abef0d74d59fc29a64c311ea05588c18`.
A tag anotada local `ircenter-rc-2026-08-25` foi criada nos três repositórios.

### 13.2 Imagens finais e pre-deploy

| Imagem | ID local | Revision OCI | Runtime |
|---|---|---|---|
| Core | `sha256:2d85c61650c5ae941e0ff8c871283db01dca9c383ab0f98d028e4820946f3dbe` | `d56879b` | `www-data`, sem Composer/Git/GCC/Make/Node/npm |
| Documentation | `sha256:8baf04dd0989416878c975b5be9daa0e89b318948de289b6544abcce26d1ff6a` | `87c3bba6abef0d74d59fc29a64c311ea05588c18` | `www-data`, sem ferramentas de build |
| Nginx/assets | `sha256:51c7d2b2e1001638e7b79ae9a48289019871ff118b2ea994d3daaccccb922d40` | `9f82463` | assets Core/Documentation incorporados e 0444 |

Todas usam version `ircenter-rc-2026-08-25`, build date
`2026-08-25T14:41:19Z`, source local explícito e `/app-release.json` 0444.
O Compose resolvido referencia a mesma imagem Core para app, queue e scheduler;
somente command/health/role diferem. Nginx não monta checkout de assets.

Os containers produtivos continuam nas imagens anteriores. Assim, a release
local é rastreável e consistente, mas `DEPLOY_STATE_VERIFIED=no` até autorização
e deploy futuro. Trivy, Grype e Docker Scout não estão disponíveis;
`IMAGE_SCAN=NOT_VERIFIED` sem instalação invasiva.

### 13.3 Backup, criptografia, retenção e restore

O script oficial integrado cobre três bancos e storages privados, usa umask 077,
flock, fail-closed, manifest sanitizado e SHA-256. Executado como o usuário
`ircenter-backup`, gerou em `20260825T143103Z` cinco artefatos, 473.632 bytes;
diretório 0700, arquivos 0600 e todos os checksums PASS. Backups legados também
foram restringidos para diretórios 0700/arquivos 0600, sem remoção.

GPG foi validado com chave temporária de um dia: encrypt, decrypt, SHA-256
pós-decrypt e `pg_restore --list` PASS. A chave e dumps descriptografados de teste
foram removidos; os backups reais foram preservados. Sem recipient operacional:
`BACKUP_ENCRYPTION_IMPLEMENTED=yes`, `BACKUP_ENCRYPTION_READY=no`.

O service/timer systemd passou em `systemd-analyze verify`, execução manual como
usuário dedicado e está `enabled/active`; próximo trigger observado em
26/08/2026 02:22 -03. Retenção 14/90/730 dias foi validada somente em dry-run;
como a política segue PROPOSED, nenhum backup foi apagado.

Restore isolado final do backup criptografado, em PostgreSQL temporário tmpfs:

| Domínio | Tabelas | Migrations | Contagem básica | Resultado |
|---|---:|---:|---:|---|
| Core | 29 | 27 | 1 usuário | PASS |
| Finance/Fiscal | 19 | 11 | 5 charges | PASS |
| Documentation | 19 | 14 | 1 documento | PASS |

### 13.4 Operação e monitoramento

O failed job é `ProcessEfiPaymentWebhook`, fila default, falho em 16/08/2026;
payload e exception não foram reproduzidos. Classificação: `UNSAFE_TO_RETRY` e
`NEEDS_REVIEW`; não foi reexecutado nem removido.

Os três `submission_unknown` datam de 08/08 e 11/08, sem provider charge id.
Classificação: `HISTORICAL_EXPECTED` e `MANUAL_REVIEW_REQUIRED`; não houve retry,
chamada ao provider ou alteração artificial de status.

O check local cobre serviços, DB/Redis via health, heartbeat, backlog, failed jobs,
backup/restore, certificado, disco, CPU/load, memória e `submission_unknown`, com
saída machine/human e exit 0/1/2. Estado final: WARNING somente pelos registros
históricos acima; backlog zero. Nenhuma stack externa foi encontrada. O adaptador
Zabbix está pronto, mas não instalado sem consumidor.

### 13.5 CI, identidade e migration

`scripts/ci-local.sh` passou com SQLite/bancos temporários, Finance/Fiscal off,
provider fake, live/webhooks/automação off e homologation. Resultado consolidado:

- Core: 459 testes, 4.032 asserções, zero falhas (inclui 10/47 de identidade);
- Documentation: 43 testes, 185 asserções, zero falhas;
- E2E/Axe: 28 pass, 20 skips previstos, zero falhas;
- Composer/npm audits: zero vulnerabilidades;
- secret scan: PASS; Compose/build/runtime smoke: PASS.

O workflow não requer secrets produtivos e replica os flags fail-closed. Sem remote
real e execução remota: `CI_REMOTE_EXECUTION_VERIFIED=no`.

MFA está integrado em `/profile/security` e no login: TOTP, segredo cifrado,
recovery codes hash/uso único, replay resistance, rate limit, usuário inativo,
auditoria, confirmação recente de senha, disable/regeneração protegidos e encerrar
outras sessões sem mostrar IDs. Enforcement permanece false. A migration nova foi
testada isoladamente, mas não aplicada em produção.

### 13.6 Evento de segurança durante a validação

Uma chamada de validação do Compose foi executada sem `--no-env-resolution` e
imprimiu no log da ferramenta valores do `.env` produtivo. Nenhum valor é repetido
neste relatório, não houve envio deliberado a serviço externo e os arquivos não
foram alterados. Por prudência, credenciais das categorias expostas devem ser
rotacionadas de forma controlada; APP_KEY exige plano específico para não perder
dados cifrados. Até essa ação: `READY_TO_DEPLOY_HARDENED_IMAGES=no`.

### 13.7 Matriz final

```text
DEPLOY_STATE_VERIFIED=no
RUNTIME_NON_ROOT=yes
CODE_READ_ONLY=yes
IMAGE_COMMIT_TRACEABILITY=yes
CORE_RUNTIME_IMAGE_MATCH=yes
ASSET_CODE_VERSION_MATCH=yes
HEALTHCHECKS_VERIFIED=yes
SECURITY_HEADERS_VERIFIED=yes
LOG_SANITIZATION_VERIFIED=yes

BACKUP_INVENTORY_COMPLETE=yes
BACKUP_PERMISSIONS_SAFE=yes
DOCUMENTATION_BACKUP_READY=yes
BACKUP_ENCRYPTION_IMPLEMENTED=yes
BACKUP_ENCRYPTION_READY=no
BACKUP_SCHEDULING_READY=yes
BACKUP_TIMER_ENABLED=yes
RETENTION_POLICY_READY=no
OFFSITE_BACKUP_READY=no
RESTORE_TEST_PASS=yes
RPO_RTO_DEFINED=no

CORE_TESTS_CURRENT=yes
DOC_TESTS_CURRENT=yes
E2E_CURRENT=yes
DEPENDENCY_AUDIT_PASS=yes
SECRET_SCAN_PASS=yes
IMAGE_SCAN_PASS=no

CI_LOCAL=yes
CI_DEFINITION_READY=yes
CI_REMOTE_EXECUTION_VERIFIED=no
CI_READY=no

MONITORING_LOCAL_READY=yes
MONITORING_READY=no
ALERTING_READY=no

FAILED_JOB_RECONCILED=yes
SUBMISSION_UNKNOWN_RECONCILED=yes

MFA_BACKEND_READY=yes
MFA_UI_READY=yes
MFA_LOGIN_READY=yes
MFA_READY=yes
PASSWORD_RECONFIRM_READY=yes
SESSION_GOVERNANCE_READY=yes
IDENTITY_MIGRATION_READY=yes

GIT_REMOTE_READY=no
GIT_GOVERNANCE_READY=no
RELEASE_MANIFEST_READY=yes
HARDENING_WORKTREE_CLEAN=yes

LEGAL_REVIEW_REQUIRED=yes
READY_TO_DEPLOY_HARDENED_IMAGES=no
IRCENTER_OPERATIONAL_HARDENING=PARTIAL
```

### BLOQUEADORES TÉCNICOS LOCAIS

Nenhum bloqueador de implementação local permanece. `LOCAL_HARDENING_COMPLETE=yes`.
O image scan está não verificado por ausência de ferramenta local, sem instalação
arbitrária.

### BLOQUEADORES EXTERNOS/OPERACIONAIS

- `OPERATOR_ACTION_REQUIRED=rotate_exposed_credentials_with_app_key_plan`;
- `OPERATOR_ACTION_REQUIRED=configure_backup_encryption_key`;
- `OPERATOR_ACTION_REQUIRED=approve_retention_and_rpo_rto`;
- `EXTERNAL_ACTION_REQUIRED=configure_offsite_destination`;
- `EXTERNAL_ACTION_REQUIRED=configure_real_git_remotes_and_run_remote_ci`;
- `EXTERNAL_ACTION_REQUIRED=connect_monitoring_and_alert_channels`;
- `EXTERNAL_ACTION_REQUIRED=legal_review`;
- `OPERATOR_ACTION_REQUIRED=authorize_identity_migration_and_deploy`.
