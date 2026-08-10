# Imagem PHP de runtime — H10 / IRC-011

## Arquitetura

O `docker/php/Dockerfile` possui dois estágios reais. `build` compila as
extensões e instala, a partir de cada `composer.lock`, os vendors de produção
do app e da documentação. `runtime` recomeça da imagem PHP-FPM fixada H7,
instala somente bibliotecas compartilhadas/probes e copia extensões, código e
vendors do builder. O `docker/test/Dockerfile` continua sendo a imagem `test`
H1 independente, com dependências dev e Composer.

O runtime contém simultaneamente `/var/www/html` e `/var/www/documentation`,
portanto app, queue, scheduler e seus equivalentes de documentação continuam
usando exatamente a mesma imagem. Os antigos bind mounts PHP foram removidos:
eles encobriam o `vendor` construído na imagem. O NGINX mantém seus mounts
read-only somente para servir arquivos públicos. Um deploy deve construir a
imagem a partir do mesmo commit que está no checkout do NGINX.

## Inventário e classificação

| Item | Classe | Destino/justificativa |
|---|---|---|
| Composer 2.10.2, Git, unzip | BUILD-ONLY | Resolução/extração pelo Composer; ausentes do runtime |
| `libicu-dev`, `libpq-dev`, `libzip-dev`, compiladores e make transitivos | BUILD-ONLY | Headers e toolchain para extensões |
| Composer e dependências `require-dev` | TEST-ONLY | Permanecem em `docker/test/Dockerfile` |
| PHP 8.4 FPM/CLI | RUNTIME REQUIRED | FPM, Artisan, queue e scheduler |
| `libicu72`, `libpq5`, `libzip4` | RUNTIME REQUIRED | `intl`, `pdo_pgsql` e `zip` |
| `libfcgi-bin` | RUNTIME REQUIRED | `cgi-fcgi`, ping FastCGI real H6 |
| `ca-certificates` | RUNTIME REQUIRED | TLS de integrações PHP/Laravel |
| shell/coreutils da imagem oficial | RUNTIME REQUIRED | wrappers e healthchecks H6 |
| curl | REMOVIDO | nenhum uso em probe, wrapper ou aplicação runtime |
| `$PHPIZE_DEPS`, headers PHP e helpers `docker-php-ext-*` | BUILD-ONLY/REMOVIDO | a imagem FPM oficial os herda; H10 os elimina explicitamente no runtime |
| `mbstring`, `sockets`, `gd`, `xml` | INCERTO/não adicionados | não estavam compilados na imagem anterior; módulos nativos da base não são removidos |

Extensões explícitas preservadas: `bcmath`, `intl`, `opcache`, `pcntl`,
`pdo_pgsql`, `redis` e `zip`. `scripts/check-php-runtime.sh` verifica a lista,
executa `php-fpm -t` e aplica `ldd` a todos os módulos compartilhados.

## Composer, código e permissões

Os dois `composer install` usam `--no-dev --prefer-dist --no-interaction
--no-progress --no-scripts --optimize-autoloader`. Não há `update`; os
lockfiles são copiados antes do source para cache determinístico. Composer,
Git, unzip e toolchain não são copiados ao estágio final.

Código e vendor pertencem a root e têm somente leitura para `www-data`.
Somente volumes/tmpfs sobre `storage` e `bootstrap/cache` são graváveis. O
runtime mantém `USER www-data` (33:33). OPcache e `date.timezone=UTC` continuam
em `production.ini`, sem tuning novo.

O entrypoint, já executado como UID 33, recria apenas a árvore autorizada de
`storage` e `bootstrap/cache`. Isso é necessário porque named volumes e tmpfs
encobrem os diretórios preparados no layer; nenhum source/vendor é alterado.

A extensão PHP `curl` herdada é preservada para compatibilidade de Laravel e
integrações HTTP; o binário `curl` é removido. A remoção não é um purge amplo:
usa exatamente `$PHPIZE_DEPS` declarado pela imagem oficial mais o pacote
`curl`, antes da instalação explícita das bibliotecas runtime.

## Atualização e validação

Sem pull automático:

```bash
./scripts/check-container-images.sh
./scripts/check-build-context.sh
docker compose config --quiet
docker compose -p ircenter-h6-isolated -f compose.healthcheck.test.yaml config --quiet
docker build --pull=false --target runtime -t ircenter-php-runtime:h10 -f docker/php/Dockerfile .
./scripts/check-php-runtime.sh ircenter-php-runtime:h10
./scripts/test-isolated.sh app
./scripts/test-isolated.sh documentation
./scripts/test-healthchecks.sh
```

Para inventário/SBOM sem instalar plataforma, guardar `dpkg-query -W` e
`php -m` via `docker run`. Se BuildKit disponibilizar SBOM nativo no futuro,
gerá-lo na estação autorizada. Dependências privadas futuras devem usar
`RUN --mount=type=secret`; nunca `ARG`, `ENV` ou credencial em layer.

## Rollback

Preservar o ID/tag da imagem anterior. Em janela aprovada, se FPM, HTTP,
queue, scheduler, logs ou permissões falharem, restaurar a referência anterior
e recriar somente os seis serviços PHP. Não remover volumes nem alterar banco.
O procedimento detalhado está no runbook de menor privilégio.
