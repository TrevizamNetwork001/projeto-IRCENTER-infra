# Revisão de segurança — 2026-08-17

## Escopo

- aplicação principal Laravel;
- aplicação de documentação Laravel;
- infraestrutura Docker e Nginx;
- dependências PHP e Node;
- configuração efetiva não secreta de produção;
- integridade dos três repositórios Git.

## Correções realizadas

### Encerramento de sessão de usuário inativo

A aplicação principal passou a executar o middleware `user.active` depois da
autenticação e antes da verificação de troca obrigatória de senha. Se uma conta
autenticada for desativada, a próxima requisição:

- encerra a autenticação;
- invalida a sessão;
- regenera o token CSRF;
- redireciona para o login com mensagem explícita.

Foi incluído teste de regressão para impedir que esse comportamento seja
removido acidentalmente.

### Dependências vulneráveis

Os lockfiles das duas aplicações foram atualizados:

| Pacote | Versão anterior | Versão corrigida |
| --- | --- | --- |
| `guzzlehttp/guzzle` | `7.15.1` | `7.15.3` |
| `guzzlehttp/promises` | `2.5.1` | `2.5.2` |
| `league/commonmark` | `2.8.3` | `2.10.0` |

Após a atualização, `composer audit --locked` retornou zero alertas nas duas
aplicações. `npm audit` também retornou zero alertas para os testes E2E.

## Controles confirmados

- ambiente Laravel definido como `production`;
- modo de depuração desativado;
- URL pública HTTPS;
- cookie de sessão `Secure` e `HttpOnly`;
- sessão criptografada e `SameSite=Lax`;
- Content Security Policy com nonce;
- HSTS no Nginx;
- tokens e rotas legadas desativados;
- segredos do webhook removidos do log de acesso;
- `.env`, certificados, dumps e backups ignorados pelo Git;
- runtime sem Composer, compiladores ou dependências de desenvolvimento;
- serviços executados como usuário sem privilégios.

## Validação

- suíte isolada principal: 441 testes e 3.953 verificações após a inclusão da
  regressão de sessão;
- suíte isolada de documentação: 43 testes e 185 verificações;
- auditoria Composer: zero vulnerabilidades conhecidas;
- auditoria npm: zero vulnerabilidades conhecidas;
- `git diff --check`: sem erros;
- caches e contêineres produtivos preservados durante os testes.

## Repositórios externos

Os três repositórios receberam remotes `origin` separados para Core,
Documentação Técnica e Infraestrutura. Consulte `docs/GIT_REPOSITORIES.md`
antes da publicação. A configuração local do remote não implica que os commits
tenham sido enviados; autenticação e `push` devem ser validados separadamente.

Nenhuma revisão de segurança garante ausência absoluta de defeitos futuros.
Novas vulnerabilidades podem ser divulgadas depois desta data; auditorias e
atualizações devem fazer parte da rotina de entrega.
