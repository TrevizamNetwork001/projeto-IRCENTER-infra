# Rede Docker e resolução dinâmica do app

## Visão geral

O IRCENTER publica o painel por um container Nginx (`web`). O Nginx e o
PHP-FPM (`app`) compartilham a rede Compose `backend`; nessa rede, o DNS
embutido do Docker disponibiliza o nome de serviço `app`. O tráfego segue:

```text
cliente
  |
  v
Nginx (web)
  |
  v
DNS interno Docker (127.0.0.11)
  |
  v
app:9000
  |
  v
PHP-FPM / Laravel
```

PostgreSQL e Redis permanecem serviços independentes na mesma rede de backend.
Nenhum endereço IP de container é configurado manualmente.

## Problema original e causa raiz

Em 30 de agosto de 2026, durante a ativação controlada da Agenda, o serviço
`app` foi recriado e mudou de `172.18.0.4` para `172.18.0.6`. Embora a
configuração usasse `fastcgi_pass app:9000`, o hostname sem variável era
resolvido quando o Nginx carregava a configuração. Os workers continuaram
tentando o IP antigo e o painel respondeu 502. Um `nginx -s reload` refez a
resolução e restaurou o serviço.

A Agenda foi revertida e permaneceu desabilitada. Nenhuma migration foi
executada e nenhum dado do banco foi alterado. O incidente demonstrou que usar
o hostname, isoladamente, não garantia nova resolução após a troca de IP.

## Solução adotada

Os pontos FastCGI do painel e do healthcheck interno usam:

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
set $app_upstream app:9000;
fastcgi_pass $app_upstream;
```

O endereço `127.0.0.11` é o resolver embutido do Docker presente no container
`web`. O nome `app` é o alias de rede criado pelo Compose. O uso da variável em
`fastcgi_pass`, suportado pelo Nginx 1.31.3 em uso, faz a resolução ocorrer em
runtime e respeitar o TTL configurado. `ipv6=off` limita a consulta ao endereço
IPv4 utilizado pela rede atual.

A arquitetura PHP-FPM/FastCGI, as redes, aliases, portas, imagens e serviços do
Compose não foram alterados. IP estático não é necessário.

## Validação

Antes de aplicar uma mudança, valide a configuração efetiva:

```bash
docker compose config --quiet
docker exec ircenter-web nginx -t
docker exec ircenter-web getent hosts app
```

Após um reload controlado, valide o painel, login e readiness por HTTP/HTTPS.
Consulte apenas os logs recentes necessários e confirme a ausência de novos
erros `connect() failed` e respostas 502.

O teste definitivo consiste em recriar somente o app, sem reload posterior do
Nginx:

```bash
docker compose up -d --no-deps --force-recreate app
docker compose ps app web
```

Aguarde o app ficar healthy. Confirme seu IP atual com `docker inspect`, valide
`/health/ready` e `/login`, e repita a recriação. Mudanças de IP não devem exigir
reload do Nginx; após até 10 segundos de TTL e a recuperação do PHP-FPM, o
painel deve voltar a responder normalmente.

## Troubleshooting de 502

1. Execute `docker compose ps` e confirme `web` e `app` healthy.
2. Consulte o IP e os aliases atuais com `docker inspect ircenter-app`.
3. Dentro de `web`, execute `getent hosts app` e confirme que o DNS retorna o
   IP atual.
4. Execute `docker exec ircenter-web nginx -t`.
5. Use `docker exec ircenter-web nginx -T` para conferir a configuração efetiva.
6. Examine logs recentes de `web` e `app`, sem publicar cabeçalhos, tokens ou
   variáveis de ambiente.
7. Confirme conectividade FastCGI e aguarde o TTL de 10 segundos após uma troca.

Não substitua o nome de serviço por IP efêmero ou estático sem uma limitação
técnica comprovada e um plano explícito de IPAM.

## Rollback

O arquivo é versionado em `docker/nginx/conf.d/default.conf`. Para rollback,
restaure somente os blocos alterados a partir do commit anterior, então execute:

```bash
docker exec ircenter-web nginx -t
docker exec ircenter-web nginx -s reload
```

Nunca faça reload se `nginx -t` falhar. Depois, valide readiness, login e painel.
O rollback antigo volta a exigir reload manual do Nginx sempre que o IP do app
mudar, portanto deve ser usado apenas para recuperação emergencial.

## Procedimento operacional e boas práticas

- Use sempre o nome de serviço `app` na rede `backend`.
- Não dependa do IP efêmero retornado por `docker inspect`.
- Não publique portas adicionais nem altere firewall para comunicação interna.
- Valide DNS, Compose e Nginx antes de aplicar mudanças.
- Recrie somente o serviço necessário; não use `docker compose down`.
- Não recrie PostgreSQL ou Redis durante testes do upstream.
- Mantenha o resolver restrito ao upstream interno e não adicione DNS externo.
- Registre IPs apenas como evidência de teste, nunca como configuração.
