# Runbook de migração de backups e Certbot

Este documento é para execução manual posterior. Não colar blocos inteiros sem revisar variáveis e saída. Não apagar origem antes da confirmação formal.

## 1. Pré-check e registro

```bash
sudo -v
sudo test -d /opt/ircenter/backups
sudo find /opt/ircenter/backups -xdev -printf '%y\t%m\t%u\t%g\t%s\t%TY-%Tm-%TdT%TH:%TM:%TS%Tz\t%p\n' | sudo tee /root/ircenter-backups-before.tsv >/dev/null
sudo sh -c 'cd /opt/ircenter/backups && find . -xdev -type f -exec sha256sum -- {} +' | sudo tee /root/ircenter-backups-before.sha256 >/dev/null
```

Revisar a lista, owners e processos/agendadores que escrevem em `backups/`. Confirmar que nenhum produtor depende de group write. Registrar janela, operador, espaço disponível e destino montado. Os arquivos `0644`/`0664` devem ser confirmados individualmente a partir do TSV.

## 2. Conta e diretório seguro

```bash
sudo groupadd --system ircenter-backup
sudo useradd --system --gid ircenter-backup --home-dir /var/backups/ircenter --shell /usr/sbin/nologin ircenter-backup
sudo install -d -o ircenter-backup -g ircenter-backup -m 0700 /var/backups/ircenter
sudo install -d -o ircenter-backup -g ircenter-backup -m 0700 /var/backups/ircenter/database/app
sudo install -d -o ircenter-backup -g ircenter-backup -m 0700 /var/backups/ircenter/database/documentation
sudo install -d -o ircenter-backup -g ircenter-backup -m 0700 /var/backups/ircenter/config /var/backups/ircenter/encrypted
```

Se conta/grupo já existirem, parar e validar UID/GID/finalidade; não recriar às cegas.

## 3. Cópia controlada e validação

Prefira cópia preservando a origem, não `mv` inicial:

```bash
sudo rsync -a --numeric-ids --no-links /opt/ircenter/backups/ /var/backups/ircenter/quarantine-import/
sudo find /var/backups/ircenter/quarantine-import -xdev -type d -exec chmod 0700 -- {} +
sudo find /var/backups/ircenter/quarantine-import -xdev -type f -exec chmod 0600 -- {} +
sudo find /var/backups/ircenter/quarantine-import -xdev -exec chown ircenter-backup:ircenter-backup -- {} +
sudo sh -c 'cd /var/backups/ircenter/quarantine-import && find . -xdev -type f -exec sha256sum -- {} +' | sudo tee /root/ircenter-backups-after.sha256 >/dev/null
sudo diff -u /root/ircenter-backups-before.sha256 /root/ircenter-backups-after.sha256
```

Gere manifests relativos em ambas as árvores e use `diff -u`; diferenças de hash ou contagem bloqueiam a migração. Classifique manualmente cópias de ambiente e configurações em quarentena: criptografe antes de retenção e não as coloque em `database/`.

## 4. Correção pontual dos modos atuais

Não usar `chmod -R`. Primeiro gere e aprove a lista exata:

```bash
sudo find /opt/ircenter/backups -xdev -type f \( -perm 0644 -o -perm 0664 \) -printf '%m\t%u\t%g\t%p\n' | sudo tee /root/ircenter-dumps-mode-review.tsv
```

Depois de confirmar lista, owner e ausência de dependência de group write, aplique arquivo a arquivo:

```bash
sudo chmod 0600 -- '/opt/ircenter/backups/CAMINHO_CONFIRMADO_1'
sudo chmod 0600 -- '/opt/ircenter/backups/CAMINHO_CONFIRMADO_2'
```

Não gerar `xargs chmod` diretamente da árvore sem revisão. Registrar estado anterior e resultado de `stat` para cada path.

## 5. Credencial e agendamento futuro

Instalar o script versionado com owner root e modo `0755`. Fornecer configuração por arquivo externo `0600` e credenciais pelo supervisor, Docker secrets ou `PGPASSFILE` `0600`. Usar `BACKUP_ROOT=/var/backups/ircenter`, `BACKUP_ALLOWED_ROOT=/var/backups` e `BACKUP_ENCRYPTION=age`. Executar primeiro contra bancos de teste e validar restauração.

## 6. Migração do Certbot

O Compose preparado usa os volumes nomeados `certbot_conf` e `certbot_www`. Em janela separada:

```bash
cd /opt/ircenter
docker compose config
docker volume create ircenter_certbot_conf
docker volume create ircenter_certbot_www
docker compose stop web certbot
docker run --rm -v /opt/ircenter/certbot/conf:/source:ro -v ircenter_certbot_conf:/destination alpine:3.22 sh -c 'test -z "$(find /destination -mindepth 1 -print -quit)" && cp -a /source/. /destination/'
docker run --rm -v /opt/ircenter/certbot/www:/source:ro -v ircenter_certbot_www:/destination alpine:3.22 sh -c 'test -z "$(find /destination -mindepth 1 -print -quit)" && cp -a /source/. /destination/'
docker run --rm -v ircenter_certbot_conf:/data:ro alpine:3.22 find /data -printf '%y\t%m\t%u\t%g\t%s\t%p\n'
docker compose up -d --no-deps web
docker exec ircenter-web nginx -t
```

Os volumes têm nomes externos determinísticos no Compose. Os comandos preservam links e modos e não exibem conteúdo. Compare o inventário de path/tipo/tamanho antes/depois e o certificado efetivamente servido. Inicie Certbot somente após `nginx -t` e a validação HTTPS.

Não remover `/opt/ircenter/certbot/conf` nem `/opt/ircenter/certbot/www` nesta etapa. Renovação deve ser ensaiada somente após o Nginx servir o certificado existente pelos volumes novos.

## 7. Rollback

Se hash, inventário, `nginx -t`, certificado servido ou teste de restauração falhar: interromper a mudança, manter origens intactas, restaurar o Compose aprovado anterior, recriar apenas os serviços autorizados apontando para os bind mounts originais e registrar evidências. Não modificar os dados copiados até concluir análise.

## 8. Validação final e retirada da origem

Confirmar: diretórios `0700`; arquivos `0600`; owner/grupo exclusivos; ausência de symlink inesperado; hashes e contagens; backup novo criptografado; restauração em teste; Nginx válido; renovação Certbot; monitoramento e agendamento. Manter a origem em quarentena somente-leitura pelo prazo aprovado. A exclusão exige aprovação posterior específica e não faz parte deste runbook.
