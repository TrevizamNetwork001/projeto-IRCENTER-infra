# E2E, responsividade e acessibilidade

## Arquitetura

A H11 adiciona navegador real à suíte PHPUnit. O fluxo é Playwright Chromium →
NGINX → PHP-FPM → Laravel → PostgreSQL/Redis no projeto Docker isolado
`ircenter-e2e-tests`. A rede é `internal`, não publica portas e não possui rota
para a Internet. PostgreSQL, Redis, `storage` e caches usam `tmpfs`; o cleanup
remove todo estado ao final.

O runner usa `mcr.microsoft.com/playwright:v1.55.0-noble` com digest fixado,
Node 22.18.0, Playwright/Chromium 1.55.0 e `@axe-core/playwright` 4.10.2. O
lockfile fixa dependências transitivas. Node e browser nunca entram no PHP de
produção.

## Guardrails e dados

É proibido usar URL, `.env`, banco, Redis, contas, dados ou secrets produtivos.
O runner aborta antes do browser se ambiente/base URL/banco/Redis divergirem da
stack E2E, se provider não for `fake`, se uma flag live estiver ativa ou se o
mailer puder enviar mensagens. Testes negativos provam recusa de URL produtiva,
`APP_ENV=production`, provider live, banco/Redis produtivos e host proibido.

O comando principal registra somente ID, status e restart count dos containers
produtivos antes/depois e falha se houver alteração.

`Database\\Seeders\\E2eSeeder` é determinístico e idempotente: cria Admin,
Operador e Viewer E2E, clientes fictícios, contrato, fatura e cobrança `fake`.
E-mails usam `example.test`/`example.invalid`. Financeiro mantém live, webhooks e
automação desligados; Efí fica em homologação sem credenciais. Fiscal está
desativado e não possui UI completa a cobrir. ViaCEP é interceptado; qualquer
outro request externo inesperado falha o teste.

## Cobertura

As specs cobrem login válido/inválido, sessão, rota protegida, logout, papéis e
negação backend 403; pesquisa, abertura, validação, criação e edição de cliente;
dashboard, menu, módulos técnicos, perfil e Financeiro existente com dados fake.

Cada página falha em `pageerror`, `console.error` inesperado ou request externo.
CSP Report-Only é coletada separadamente e deve ter zero violação. O relatório
fica em `tests/e2e/artifacts/browser-security.json`.

A única exceção de console é a mensagem nativa e exata que o Chromium produz ao
navegar deliberadamente para `/pagina-e2e-inexistente`; ela só é aceita nesse
caminho durante a verificação da página 404. Erros JavaScript continuam falhando.

Tema dark/light e persistência em `localStorage` são testados. Viewports:
desktop 1440×900, tablet 768×1024 e mobile 390×844. São verificados overflow,
tabelas roláveis, formulários, ações e menu móvel. Não há modal real no fluxo,
portanto nenhum modal artificial foi criado.

## Axe, semântica, teclado e foco

Axe roda em login, dashboard, clientes, formulário de cliente, Financeiro e
erro 404. `serious` e `critical` falham; `moderate` permanece visível para
avaliação, sem allowlist global. Também são validados idioma, title, landmarks,
headings, nomes acessíveis e labels.

O login é percorrido com Tab/Enter. A aplicação oferece skip link, foco visível
e menu mobile com `aria-expanded`; o skip link move foco ao `main`. Menus
existentes devolvem foco ao botão ao fechar com Escape.

## Execução e artefatos

```sh
./scripts/test-e2e.sh
```

O script constrói imagens, testa guardrails, migra os bancos, semeia fixtures,
espera healthchecks, roda Playwright e sempre limpa via `trap`. Screenshots e
traces ficam somente em falha; vídeo está desativado. Artefatos são gitignored.

Para novo teste, importe os helpers de `support/fixtures.js`, use roles/labels e
não crie allowlist genérica de console, CSP ou axe.

## CI futura e documentation-app

CI requer Docker/Compose, imagens fixadas disponíveis, cerca de 8 GB livres,
4 GB de RAM e timeout de 20 minutos. Após cache das imagens/dependências, a
execução não usa Internet. Nenhum serviço de CI foi configurado nesta fase.

O foco obrigatório é o app principal. O trabalho local não commitado da
`documentation-app` foi preservado; E2E próprio fica para fase futura após a
estabilização daquele repositório.
