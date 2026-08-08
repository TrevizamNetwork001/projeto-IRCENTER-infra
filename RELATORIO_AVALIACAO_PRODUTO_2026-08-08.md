# Relatório de avaliação do produto IRCENTER

Data: 08/08/2026
Modalidade: inspeção somente leitura, sem correções no produto
Escopo: aplicação principal, aplicação de documentação, rotas, testes, configuração Laravel, Docker/NGINX, logs e artefatos operacionais.

## Resumo executivo

O produto apresenta boa cobertura automatizada das regras centrais: a suíte principal concluiu com **242 testes aprovados e 759 asserções**. Autenticação, limitação de tentativas, separação de perfis, CSRF, idempotência financeira e bloqueios para operações de pagamento possuem testes relevantes.

Apesar disso, a avaliação encontrou **1 achado crítico, 3 altos, 5 médios e 3 baixos**. O principal risco é operacional: o script de testes altera o cache de configuração utilizado pela instância de produção. A execução desta avaliação produziu, no mesmo intervalo, erros reais de `No application encryption key has been specified` no log de produção. Também merecem prioridade a presença de backups e cópias de `.env` na árvore operacional, alguns com permissão de leitura ampla, e a execução dos contêineres PHP como root com todo o código montado para escrita.

Nenhuma correção foi aplicada.

## Achados

### IRC-001 — Crítico — Testes podem derrubar ou desestabilizar a produção

**Evidência:** `app/scripts/test-safe.sh` linhas 7–34 move/remove `bootstrap/cache/config.php`. O mesmo diretório da aplicação é montado no contêiner web, no worker e no scheduler (`compose.yaml`, linhas 22–68). Durante a execução dos testes, o log registrou em `2026-08-08 19:41:21` erros de produção informando ausência de `APP_KEY`, seguidos de erro de cabeçalhos já enviados.

**Impacto:** indisponibilidade transitória, falha ao descriptografar sessões/cookies, respostas 500 e risco de concorrência com workers e scheduler. O nome `test-safe.sh` transmite uma garantia que o isolamento atual não entrega.

**Recomendação:** classificar como bloqueador de produção. Executar testes em contêiner/imagem e filesystem independentes, sem bind mount do runtime produtivo e sem manipular caches de produção.

### IRC-002 — Alto — Backups e segredos operacionais coexistem com o deploy

**Evidência:** a pasta `backups/` contém dumps SQL, dumps financeiros e diversas cópias de ambiente, por exemplo `app-env-before-efi-*`, `application.env` e `infra.env`. A árvore `certbot/conf` também contém chaves privadas ACME e TLS.

**Impacto:** uma leitura indevida do host, do workspace, de uma cópia de suporte ou de um pacote de deploy pode expor dados pessoais/financeiros, credenciais de banco, integrações e material criptográfico. A concentração aumenta o raio de impacto de um incidente.

**Recomendação:** separar backups e segredos do diretório da aplicação, usar armazenamento cifrado e política explícita de retenção/acesso, e manter certificados em volume/secret dedicado.

### IRC-003 — Alto — Dumps de banco possuem permissão ampla de leitura

**Evidência:** diversos dumps estão com modo `0644` ou `0664`, incluindo `ircenter-after-fase6-20260723-212549.sql`, `ircenter-before-fase-10-20260724-122404.sql` e dumps da aplicação de documentação.

**Impacto:** qualquer usuário local ou processo com acesso ao filesystem pode ler dados desses backups. Isso é especialmente relevante porque o produto administra clientes, documentos, contatos e informações financeiras.

**Recomendação:** restringir permissões e ownership, cifrar os arquivos e auditar se houve cópia ou exposição anterior.

### IRC-004 — Alto — Contêineres PHP rodam como root sobre código gravável

**Evidência:** `docker/php/Dockerfile` não define `USER`. Em `compose.yaml`, aplicação, filas, scheduler e documentação recebem bind mounts graváveis de toda a aplicação (linhas 29–30, 42–43, 60–61, 77–78, 93–94 e 109–110).

**Impacto:** uma vulnerabilidade de execução de código na aplicação ou em uma dependência pode alterar fontes, configurações e artefatos persistentes no host, facilitando persistência e movimento lateral.

**Recomendação:** executar com usuário sem privilégios, tornar o código somente leitura e liberar escrita apenas para diretórios estritamente necessários.

### IRC-005 — Médio — Endpoint público de prontidão revela a topologia interna

**Evidência:** `GET /health/ready` é público e retorna nominalmente `database` e `redis`, seus estados e timestamp. A resposta observada foi `{"status":"ready","checks":{"application":true,"database":true,"redis":true},...}`.

**Impacto:** facilita reconhecimento da arquitetura e permite acompanhar falhas parciais dos serviços internos. O endpoint ainda cria cookies de sessão e XSRF, comportamento desnecessário para health checks e gerador de carga/estado.

**Recomendação:** expor publicamente apenas estado agregado e evitar middleware de sessão; reservar o diagnóstico detalhado para rede ou autenticação administrativa.

### IRC-006 — Médio — Falta Content-Security-Policy

**Evidência:** a resposta HTTPS possui HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` e COOP, mas não possui `Content-Security-Policy`. O middleware `SecurityHeaders` termina sem definir CSP (`app/app/Http/Middleware/SecurityHeaders.php`, linhas 17–47).

**Impacto:** reduz a defesa em profundidade contra XSS, injeção de recursos e carregamento de conteúdo não autorizado.

**Recomendação:** mapear os recursos utilizados pelas telas e implantar CSP restritiva, inicialmente em modo report-only.

### IRC-007 — Médio — Serviços de aplicação não possuem healthcheck Docker

**Evidência:** apenas PostgreSQL e Redis têm `healthcheck`. O NGINX depende de `app` com `condition: service_started`, que confirma início do processo, não prontidão. Filas, scheduler e os três serviços da documentação também não têm verificação de saúde.

**Impacto:** o stack pode aparecer como ativo enquanto PHP-FPM, filas ou agendamentos estão sem funcionar. Reinícios e deploys podem servir 502 ou manter automações silenciosamente paradas.

**Recomendação:** adicionar healthchecks adequados a cada tipo de processo e monitorar atraso de fila e execução do scheduler.

### IRC-008 — Médio — Imagens de infraestrutura usam tags flutuantes

**Evidência:** `nginx:alpine`, `certbot/certbot:latest` e o estágio `composer:2` não estão fixados por versão/digest.

**Impacto:** reconstruções em datas diferentes podem produzir stacks diferentes, introduzir regressões ou mudanças incompatíveis e dificultar rollback/auditoria.

**Recomendação:** fixar versões/digests e adotar rotina controlada de atualização e validação.

### IRC-009 — Médio — Fuso horário do produto está em UTC

**Evidência:** `artisan about` no contêiner de produção informou timezone `UTC`, embora a operação esteja em `America/Sao_Paulo` e o locale seja `pt_BR`.

**Impacto:** datas exibidas, competências, vencimentos, auditoria e agendamentos podem divergir em três horas do horário esperado pelo usuário. Em módulos financeiro e fiscal, transições próximas da meia-noite merecem atenção especial.

**Recomendação:** definir formalmente a política de timezone (armazenamento versus apresentação) e criar testes de fronteira de dia/mês e horário de verão histórico.

### IRC-010 — Baixo — Logs de produção acumulam erros antigos e de teste

**Evidência:** os logs atuais reúnem falhas antigas de migrations, views, Vite, comandos manuais e entradas com ambiente `testing`, além de erros recentes. Não há, no material inspecionado, evidência de centralização, alerta ou separação operacional.

**Impacto:** aumenta ruído, dificulta detectar incidentes reais e pode reter dados contextuais por tempo excessivo.

**Recomendação:** separar logs por ambiente, definir retenção, centralizar eventos e alertar por taxa/severidade.

### IRC-011 — Baixo — Imagem de runtime inclui ferramentas desnecessárias

**Evidência:** a imagem PHP de produção instala `git`, `curl`, `unzip` e Composer e usa a mesma imagem para runtime, fila e scheduler.

**Impacto:** aumenta superfície de ataque, tamanho da imagem e quantidade de componentes a atualizar.

**Recomendação:** usar build multiestágio e manter no runtime apenas bibliotecas e binários necessários.

### IRC-012 — Baixo — Ausência de evidência de testes de navegador e acessibilidade

**Evidência:** a suíte principal cobre recursos HTTP e domínio, mas não foram encontrados testes E2E de navegador, auditoria automatizada de acessibilidade ou regressão visual da aplicação principal. A aplicação de documentação tem testes visuais de topologia, mas isso não cobre os fluxos principais do IRCENTER.

**Impacto:** problemas de JavaScript, layout responsivo, navegação por teclado, contraste e integração real entre telas podem passar mesmo com toda a suíte PHP verde.

**Recomendação:** cobrir fluxos críticos (login, clientes, incidentes, faturas e cobranças) em navegador e incorporar verificações WCAG.

## Pontos positivos observados

- Produção está com `APP_DEBUG=off` e HTTPS redirecionado com HSTS.
- Cookies de sessão observados usam `Secure`, `HttpOnly` e `SameSite=Lax` (o cookie XSRF, por finalidade, não é HttpOnly).
- Login possui rate limit por combinação de e-mail e IP e regenera a sessão.
- A API de documentação exige token e possui throttle.
- PostgreSQL e Redis não publicam portas diretamente no host.
- O módulo financeiro possui testes de idempotência, estados incertos, reconciliação, auditoria e bloqueio de operação live.
- O repositório Git interno de `app` não rastreia `.env`, banco SQLite nem logs; apenas os respectivos `.gitignore` aparecem rastreados.

## Limitações da avaliação

- Não foi realizado teste de invasão, carga ou varredura externa da internet.
- Não foram usados dados de acesso para percorrer telas autenticadas; a avaliação funcional baseou-se no código e na suíte automatizada.
- A suíte da aplicação de documentação não foi executada para evitar repetir o risco de interferência no cache compartilhado identificado em IRC-001.
- Não foi validada restauração real dos backups nem sua existência fora deste host.
- Uma suíte verde confirma os cenários escritos, não elimina falhas em cenários ausentes.

## Ordem sugerida de tratamento

1. Isolar completamente a execução de testes (IRC-001).
2. Retirar, cifrar e restringir backups/segredos (IRC-002 e IRC-003).
3. Reduzir privilégios e escrita dos contêineres (IRC-004).
4. Ajustar observabilidade e saúde operacional (IRC-005, IRC-007 e IRC-010).
5. Endurecer browser/runtime e reprodutibilidade (IRC-006, IRC-008 e IRC-011).
6. Formalizar timezone e ampliar testes de experiência (IRC-009 e IRC-012).
