# Manifesto de release IRCENTER

Status: `DRAFT | APPROVED | DEPLOYED | ROLLED_BACK`

| Campo | Valor |
|---|---|
| Release | `vX.Y.Z` |
| Data/hora UTC | |
| Operador | |
| Infra commit | |
| Core commit | |
| Documentation commit | |
| Core image ID/digest | |
| Documentation image ID/digest | |
| Nginx image digest | |
| PostgreSQL image digest | |
| Redis image digest | |
| Migrations Core | |
| Migrations Finance/Fiscal | |
| Migrations Documentation | |
| Backup Core | caminho + SHA-256, nunca segredo |
| Backup Finance/Fiscal | caminho + SHA-256 |
| Backup Documentation | caminho + SHA-256 |
| Restore test | data + evidência |
| CI run | URL/ID |
| Rollback release | |
| Aprovação | |

## Resultado pós-deploy

- health/readiness:
- smoke autenticado:
- queue/scheduler:
- migrations:
- logs/alertas:
- decisão: `ACCEPT | ROLLBACK`
