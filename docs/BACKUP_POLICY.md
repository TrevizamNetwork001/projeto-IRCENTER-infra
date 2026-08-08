# Política de backups, segredos e permissões

## Arquitetura aprovada no código

A raiz operacional é `/var/backups/ircenter`, sempre fora de `/opt/ircenter` e de qualquer checkout. O owner recomendado é a conta de serviço exclusiva `ircenter-backup`; o grupo recomendado é o grupo privado homônimo, sem usuários interativos. Diretórios usam `0700`, arquivos usam `0600` e todo processo inicia com `umask 077`.

```text
/var/backups/ircenter/
├── database/
│   ├── app/{daily,weekly,monthly}/
│   └── documentation/{daily,weekly,monthly}/
├── config/
└── encrypted/
```

Backup não é parte do deploy: o checkout, containers de aplicação e usuário do servidor web não recebem acesso de leitura à raiz. É proibido manter dumps, cópias de `.env`, chaves privadas ou material do Certbot junto ao código. `config/` só pode receber exportações deliberadas, revisadas e criptografadas; nunca cópia direta de `.env` em claro.

## Bancos e credenciais

`scripts/backup-ircenter.sh` trata `app` e `documentation` como bancos PostgreSQL explicitamente distintos, mesmo quando compartilham cluster, host e usuário. Os nomes vêm de `APP_DATABASE` e `DOCUMENTATION_DATABASE`; ambos devem ser definidos ao usar o alvo `all`.

A senha nunca é argumento do script. A operação deve fornecer `PGHOST`, `PGPORT`, `PGUSER` e credencial por variável herdada do supervisor, Docker secret ou `PGPASSFILE` externo. Se usado, `.pgpass` deve pertencer à conta de backup e estar em `0600`. Não versionar credenciais nem usar `set -x`. O exemplo contém somente valores ilustrativos não secretos.

## Criptografia

O modo recomendado é `BACKUP_ENCRYPTION=age`, com `AGE_RECIPIENTS_FILE` absoluto, fora do repositório, regular e sem symlink. A chave privada de restauração fica em cofre separado do host e do backup. Se o arquivo de destinatários faltar, o script falha; não há fallback silencioso para texto claro.

O modo `none` existe apenas para uma camada local temporária e controlada. Arquivo `0600` não substitui criptografia em repouso, cópia off-site criptografada nem controle de acesso do storage. Backups destinados a retenção ou transporte devem ser criptografados.

## Retenção

O agendador escolhe `BACKUP_TIER=daily`, `weekly` ou `monthly`. Padrões iniciais: 14 dias diários, 90 dias semanais e 730 dias mensais, configuráveis pelas variáveis `RETENTION_*_DAYS`. A rotina `prune` só considera arquivos regulares, no diretório exato do alvo/tier, com nome gerado pelo script; não segue symlinks nem atravessa filesystem.

Retenção deve rodar somente depois de validar backup, criptografia e cópia externa. Esta fase testou remoção exclusivamente em fixture sob `/tmp`; nenhum backup real foi removido.

## Restauração

Toda restauração exige ticket/aprovação, seleção pelo inventário, hash antes do uso, cópia de trabalho `0600`, ambiente não produtivo para ensaio e registro de tempos/resultados. Para `.age`, descriptografar somente em diretório temporário `0700`, com identidade obtida do cofre. Confirmar banco-alvo e owner antes de `pg_restore`; nunca restaurar automaticamente sobre produção.

Executar teste trimestral de restauração e revisar semestralmente retenção, destinatários de criptografia, acessos e logs.

## Certbot

`compose.yaml` passa a declarar `certbot_conf` e `certbot_www` como volumes Docker nomeados. O Nginx continua vendo `/etc/letsencrypt` e `/var/www/certbot`, e `scripts/renew-certificates.sh` não depende do caminho do host. A mudança só entra no runtime após a migração controlada do runbook; não recriar containers antes disso.
