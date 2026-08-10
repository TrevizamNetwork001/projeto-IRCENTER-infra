# Política de imagens de container

## Regra

Imagens externas ativas em Compose e Dockerfiles devem usar versão explícita e
digest SHA-256. São proibidos `latest`, tags genéricas como `nginx:alpine` e
referências somente por major como `composer:2`.

Tags facilitam leitura e revisão; o digest determina os bytes efetivamente
usados. Artefatos locais `ircenter-*` são exceção porque são gerados pelo build
declarado no próprio repositório e não são obtidos de registry.

## Inventário H7

| Componente | Referência fixada | Evidência local | Motivo |
|---|---|---|---|
| NGINX | `nginx:1.31.3-alpine@sha256:4a7307…1752` | NGINX 1.31.3, Alpine 3.24.1 | Mesma imagem validada em H6 |
| Certbot | `certbot/certbot:v5.7.0@sha256:34ee91…95b4` | `certbot 5.7.0` | Remove `latest`; nenhuma renovação executada |
| PHP-FPM | `php:8.4.23-fpm-bookworm@sha256:c5fb7a…681c` | PHP 8.4.23 | Preserva PHP 8.4 e Debian Bookworm |
| PHP CLI de testes | `php:8.4.23-cli-bookworm@sha256:5380a7…46f7` | Build H1 local | Mesma versão PHP da produção |
| Composer | `composer:2.10.2@sha256:4d71c3…5040` | Composer 2.10.2 | Apenas estágio de build; lockfiles intactos |
| PostgreSQL | `postgres:17.10-alpine@sha256:742f40…2193` | PostgreSQL 17.10 | Sem mudança de major ou formato de dados |
| Redis | `redis:8.8.0-alpine@sha256:9d3171…7005` | Redis 8.8.0 | Mesmos bytes do container validado |

Os digests completos ficam nos arquivos de configuração, sem abreviação.
`alpine:3.22` aparece apenas em comandos manuais dos runbooks H2/H3. É uma tag
de minor parcialmente fixada, não integra uma stack ativa e não foi executada
na H7. Sua evolução para tag de patch + digest exige seleção e pull controlados.

As imagens `ircenter-app-test:h1`, `ircenter-documentation-test:h1` e
`ircenter-php-healthcheck:h6` são nomes locais de saída de builds definidos nos
respectivos Compose. Elas não representam dependências flutuantes de registry.

## Auditoria

Executar antes de commit ou release:

```bash
./scripts/check-container-images.sh
docker compose config --quiet
docker compose -p ircenter-h6-isolated -f compose.healthcheck.test.yaml config --quiet
```

O scanner é somente leitura, não consulta registry e falha para `latest`, tags
genéricas conhecidas, digest inválido ou imagem externa ativa sem digest.

## Atualização controlada e CVEs

Não atualizar automaticamente. Para corrigir CVE ou adotar nova versão:

1. registrar versão, advisory e referência atualmente implantada;
2. consultar o registry e release notes em estação/janela autorizada;
3. obter o digest oficial para a arquitetura necessária;
4. alterar tag e digest juntos;
5. validar scanner, Compose, build e suítes isoladas;
6. validar healthchecks e NGINX/FPM na stack H6;
7. revisar mudanças de configuração, extensões e formato de dados;
8. aprovar deploy antes de pull/rebuild no host.

Atualizações de segurança não autorizam salto automático de major. PostgreSQL
jamais deve ser iniciado contra o volume real com nova major sem plano próprio.
Composer não deve executar `update` durante troca de imagem.

## Rollback

Antes do deploy, guardar a referência tag+digest anterior e os IDs implantados.
Testar a nova referência isoladamente, fazer deploy controlado e validar health.
Em falha, restaurar as referências anteriores e recriar somente os serviços
afetados. Não apagar volumes, alterar dados ou executar migrations como parte
do rollback de imagens.

## Pendências de validação

Os pins correspondem a metadados e versões locais já utilizados. Não houve
pull na H7. A disponibilidade das novas combinações de tag legível + digest no
registry e rebuild completo ficam como **VALIDAÇÃO PENDENTE DE PULL
CONTROLADO**. O digest impede mudança silenciosa mesmo se uma tag for movida.
