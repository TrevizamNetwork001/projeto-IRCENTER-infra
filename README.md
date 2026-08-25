# IRCENTER

O IRCENTER é uma plataforma interna para operação de clientes, recursos de rede,
IRR/RPKI, incidentes, documentação técnica e processos administrativos. O Core,
a Documentação e a infraestrutura possuem ciclos Git independentes, mas formam
uma única release operacional.

## Arquitetura

- `app/`: Core Laravel, incluindo rede, clientes, auditoria e módulos Finance/Fiscal;
- `documentation-app/`: aplicação Laravel de documentação e topologias;
- `docker/` e `compose.yaml`: Nginx, PHP-FPM, workers, PostgreSQL e Redis;
- `scripts/`: runners isolados, backup, healthchecks e validações;
- `docs/`: políticas e runbooks operacionais.

Perfis do Core: administrador, operador e visualizador. A aplicação de
Documentação possui administração, edição e visualização próprias.

## Desenvolvimento e testes

Nunca execute PHPUnit diretamente neste checkout operacional. Use runners
efêmeros, sem rede de providers e com SQLite em memória:

```sh
COMPOSE_DISABLE_ENV_FILE=1 ./scripts/test-isolated.sh app test
COMPOSE_DISABLE_ENV_FILE=1 ./scripts/test-isolated.sh documentation test
COMPOSE_DISABLE_ENV_FILE=1 ./scripts/test-e2e.sh
```

O gate local completo é `./scripts/ci-local.sh`. Ele mantém pagamentos fake,
live e automações desligados.

## Operação

- deploy e rollback: `docs/RELEASE_RUNBOOK.md`;
- manifesto: `docs/RELEASE_MANIFEST_TEMPLATE.md`;
- backups: `docs/BACKUP_POLICY.md` e `docs/BACKUP_MIGRATION_RUNBOOK.md`;
- observabilidade: `docs/LOGGING_OBSERVABILITY_RUNBOOK.md`;
- governança, RPO/RTO e alertas: `docs/OPERATIONAL_GOVERNANCE.md`.

O readiness público é `/health/ready`; detalhes ficam no diagnóstico
administrativo. Banco e Redis não devem publicar portas no host.

## Integrações e limites

Integrações externas devem passar pelo controle SSRF. Pagamentos live,
automação financeira e transmissão NFS-e permanecem desativados salvo release
específica e aprovada. O módulo fiscal atual é manual assistido: não emite,
assina, transmite ou cancela NFS-e oficialmente.

## Segurança e troubleshooting

Não versionar `.env`, dumps, certificados, tokens ou logs. Antes de investigar,
preserve request ID, estado dos containers e logs sanitizados. Consulte os
runbooks em `docs/` antes de rebuild, restart, migration, restore ou renovação
de certificados.

## Organização dos repositórios

As aplicações em `app/` e `documentation-app/` são repositórios Git
independentes e não fazem parte deste histórico. Dados persistentes, arquivos de
ambiente, backups, logs, certificados e segredos também não são versionados.

Alterações neste repositório não implicam deploy automático. Build, recriação de
containers, reinício de serviços e mudanças no host devem seguir runbook e
aprovação operacional.
