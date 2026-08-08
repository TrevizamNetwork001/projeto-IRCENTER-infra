# Testes isolados

As suites do IRCENTER devem ser executadas exclusivamente pela stack efemera de
testes. E proibido executar PHPUnit, `artisan test`, `composer test` ou limpeza de
cache diretamente nos filesystems usados pelos containers de producao.

## Comandos

```sh
./scripts/test-isolated.sh app
./scripts/test-isolated.sh documentation
```

Use `verify` para validar as barreiras sem Laravel e `smoke` para executar apenas
`artisan about` dentro do runner, por exemplo:

```sh
./scripts/test-isolated.sh app verify
./scripts/test-isolated.sh app smoke
./scripts/test-isolated.sh documentation verify
./scripts/test-isolated.sh documentation smoke
```

## Garantias

- o codigo e copiado para a imagem, sem bind mount das aplicacoes;
- o root filesystem e somente leitura;
- `storage` e `bootstrap/cache` sao `tmpfs` efemeros;
- a rede do container e desabilitada;
- banco e SQLite `:memory:`;
- cache e sessao usam `array`, fila usa `sync` e mail usa `array`;
- a chave e gerada dentro de cada container;
- `.env`, cache, storage, vendor e `.git` produtivos nao entram no build;
- caches e containers produtivos sao comparados antes e depois.

## Guard rails e novos servicos

O entrypoint aborta antes do Laravel quando ambiente, banco, cache, sessao, fila,
mail, Redis, URLs ou providers financeiros/fiscais divergem dos valores seguros.
Hosts produtivos conhecidos sao bloqueados e a ausencia de rede e uma segunda
barreira. Novos servicos devem reutilizar `test-service`, permanecer sem rede e
bind mounts, usar dados efemeros e ampliar os guard rails antes do uso.
