# Auditoria de segurança de backups — 2026-08-08

Escopo: metadados de `/opt/ircenter/backups`, sem leitura de conteúdo. Data no fuso `America/Sao_Paulo`. Tipos: `f` arquivo regular. Classificações podem ser cumulativas.

## Resumo quantitativo

- 54 arquivos regulares e 4 diretórios (incluindo a raiz).
- Modos dos arquivos: 22 em `0600`, 27 em `0644`, 4 em `0664` e 1 em `0750`.
- 26 dumps (`.sql`, `.sql.gz` ou `.dump`) e 9 artefatos com nome relacionado a ambiente/configuração.
- 31 arquivos têm leitura de grupo/world (`0644`/`0664`) e aguardam revisão e correção pontual.
- A contagem conhecida de modos totalizava 53 porque não incluía o script `test-safe.sh` em `0750`.
- A árvore Certbot foi contada sem expor paths internos: 17 diretórios, 13 arquivos regulares e 4 symlinks; ela é `MATERIAL SENSÍVEL` e aguarda migração controlada.

## Inventário

| Path | Tipo | Modo | Owner:group | Bytes | Data | Classificação |
|---|---:|---:|---|---:|---|---|
| `backups/app-env-before-efi-20260808-091612` | f | 0600 | root:root | 1389 | 2026-08-08 09:16:12 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/app-env-before-efi-web-hml-20260808-143311` | f | 0600 | ircenter:www-data | 1586 | 2026-08-08 11:52:17 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/app-env-before-finance-20260807-184910` | f | 0600 | root:root | 881 | 2026-08-07 18:49:11 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/app-env-before-finance-fake-20260808-115216` | f | 0600 | ircenter:www-data | 1587 | 2026-08-08 09:31:56 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-after-fase6-20260723-212233.sql` | f | 0644 | root:root | 75727 | 2026-07-23 21:22:34 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-after-fase6-20260723-212549.sql` | f | 0644 | root:root | 76760 | 2026-07-23 21:25:50 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-documentation-db-20260724-151648.sql` | f | 0600 | root:root | 122088 | 2026-07-24 15:16:49 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-fase-10-20260724-122404.sql` | f | 0644 | root:root | 102214 | 2026-07-24 12:24:05 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-fase-12-20260724-132856.sql` | f | 0644 | root:root | 116775 | 2026-07-24 13:28:57 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-fase-7-20260723-215329.sql` | f | 0644 | root:root | 77662 | 2026-07-23 21:53:30 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-fase-8-20260724-105800.sql` | f | 0644 | root:root | 80459 | 2026-07-24 10:58:00 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-fase-9-20260724-114312.sql` | f | 0644 | root:root | 84721 | 2026-07-24 11:43:13 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-before-test-cleanup-20260724-144218.sql` | f | 0600 | root:root | 119784 | 2026-07-24 14:42:19 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-core-before-phase2c-20260807-193436.sql.gz` | f | 0644 | root:root | 83611 | 2026-08-07 19:34:37 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-core-before-phase2c-20260807-193436.sql.gz.sha256` | f | 0644 | root:root | 140 | 2026-08-07 19:34:37 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-before-fase-16-20260724-181926.sql` | f | 0600 | root:root | 20902 | 2026-07-24 18:19:27 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-before-fase-17-20260731-113313.sql` | f | 0600 | ircenter:ircenter | 36564 | 2026-07-31 11:33:13 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-before-fase-18-20260731-144747.sql` | f | 0664 | ircenter:ircenter | 37164 | 2026-07-31 14:47:48 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-before-fase-20-20260731-163139.sql` | f | 0664 | ircenter:ircenter | 51235 | 2026-07-31 16:31:40 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-before-fase-23-20260731-180731.sql` | f | 0664 | ircenter:ircenter | 59644 | 2026-07-31 18:07:32 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-documentation-v1-final-20260731-171310.sql` | f | 0664 | ircenter:ircenter | 59608 | 2026-07-31 17:13:11 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-efi-web-hml-20260808-143311.sql.gz` | f | 0600 | root:root | 4434 | 2026-08-08 14:33:12 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-enable-fake-20260808-115216.sql.gz` | f | 0600 | root:root | 3568 | 2026-08-08 11:52:17 | MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase2a-20260807-185821.sql.gz` | f | 0644 | root:root | 1236 | 2026-08-07 18:58:22 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase2a-20260807-185821.sql.gz.sha256` | f | 0644 | root:root | 143 | 2026-08-07 18:58:22 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase2b-20260807-191205.sql.gz` | f | 0644 | root:root | 1986 | 2026-08-07 19:12:05 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase2b-20260807-191205.sql.gz.sha256` | f | 0644 | root:root | 143 | 2026-08-07 19:12:05 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3a-20260807-194117.sql.gz` | f | 0644 | root:root | 2459 | 2026-08-07 19:41:18 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3a-20260807-194117.sql.gz.sha256` | f | 0644 | root:root | 143 | 2026-08-07 19:41:18 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3b-20260807-194938.sql.gz` | f | 0644 | root:root | 2803 | 2026-08-07 19:49:39 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3b-20260807-194938.sql.gz.sha256` | f | 0644 | root:root | 143 | 2026-08-07 19:49:39 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3b2-20260807-203405.sql.gz` | f | 0644 | root:root | 2941 | 2026-08-07 20:34:06 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/ircenter-finance-before-phase3b2-20260807-203405.sql.gz.sha256` | f | 0644 | root:root | 144 | 2026-08-07 20:34:06 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/nginx-before-documentation-assets-20260724-163756.conf` | f | 0600 | root:root | 2486 | 2026-07-24 16:37:56 | REVISAR MANUALMENTE; MOVER PARA BACKUP EXTERNO |
| `backups/nginx-before-documentation-fix-20260724-161933.conf` | f | 0644 | root:root | 2137 | 2026-07-24 16:19:34 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/nginx-before-documentation-route-20260724-160820.conf` | f | 0600 | root:root | 1331 | 2026-07-24 16:08:20 | REVISAR MANUALMENTE; MOVER PARA BACKUP EXTERNO |
| `backups/nginx-before-documentation-upstream-fix-20260724-162236.conf` | f | 0644 | root:root | 2485 | 2026-07-24 16:22:36 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/compose-before-documentation-20260724-153333.yaml` | f | 0600 | root:root | 2657 | 2026-07-24 15:33:33 | REVISAR MANUALMENTE; MOVER PARA BACKUP EXTERNO |
| `backups/pre-efi-homologation-smoke-20260808T154508-0300.application.env` | f | 0600 | ircenter:www-data | 1585 | 2026-08-08 14:33:12 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/pre-efi-homologation-smoke-20260808T154508-0300.infrastructure.env` | f | 0600 | ircenter:ircenter | 141 | 2026-07-20 18:10:32 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/pre-efi-homologation-smoke-20260808T154508-0300.ircenter_finance.dump` | f | 0644 | root:root | 42617 | 2026-08-08 15:45:25 | CORRIGIR PERMISSÃO; MOVER PARA BACKUP EXTERNO |
| `backups/pre-phase1-safety-20260807-182122.sql.gz` | f | 0600 | root:root | 81017 | 2026-08-07 18:21:24 | MOVER PARA BACKUP EXTERNO |
| `backups/pre-phase1-safety-20260807-182122.sql.gz.sha256` | f | 0600 | root:root | 129 | 2026-08-07 18:21:24 | MOVER PARA BACKUP EXTERNO |
| `backups/phase1-test-hardening-20260807-182931/bootstrap.php` | f | 0600 | ircenter:ircenter | 711 | 2026-07-24 14:47:26 | REVISAR MANUALMENTE |
| `backups/phase1-test-hardening-20260807-182931/composer.json` | f | 0644 | ircenter:ircenter | 2883 | 2026-05-25 20:11:52 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/AppServiceProvider.php` | f | 0644 | ircenter:ircenter | 1712 | 2026-07-24 14:36:03 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/database.php` | f | 0644 | ircenter:ircenter | 6876 | 2026-05-25 20:11:52 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/env.example` | f | 0644 | ircenter:ircenter | 1235 | 2026-07-24 14:23:28 | CORRIGIR PERMISSÃO; MATERIAL SENSÍVEL; REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/phpunit.xml` | f | 0644 | ircenter:ircenter | 1322 | 2026-07-24 14:47:42 | CORRIGIR PERMISSÃO; REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/test-safe.sh` | f | 0750 | ircenter:ircenter | 991 | 2026-07-24 14:47:58 | REVISAR MANUALMENTE |
| `backups/phase1b-foundation-20260807-183805/tests-bootstrap.php` | f | 0600 | ircenter:ircenter | 1211 | 2026-08-07 18:29:31 | REVISAR MANUALMENTE |
| `backups/phase4b9_20260808_163113_-03/app.env.backup` | f | 0600 | root:root | 1585 | 2026-08-08 16:31:38 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/phase4b9_20260808_163113_-03/infra.env.backup` | f | 0600 | root:root | 141 | 2026-08-08 16:31:38 | MATERIAL SENSÍVEL; MOVER PARA BACKUP EXTERNO |
| `backups/phase4b9_20260808_163113_-03/ircenter_finance.dump` | f | 0600 | root:root | 42827 | 2026-08-08 16:31:39 | MOVER PARA BACKUP EXTERNO |

## Estado

Nenhum item foi alterado. `OK` significa apenas que o modo atual não amplia leitura; ainda assim, todos os dumps e materiais sensíveis dentro do deploy aguardam migração. IRC-002 fica **CORRIGIDO NO CÓDIGO / AGUARDA MIGRAÇÃO CONTROLADA NO HOST**. IRC-003 fica **CORRIGIDO NO CÓDIGO / AGUARDA CHMOD CONTROLADO NO HOST** após aprovação dos testes e commits desta fase.
