# Runbook de release

## Antes

1. Confirmar árvore limpa e commits aprovados nos três repositórios.
2. Executar CI obrigatório e registrar o run no manifesto.
3. Produzir backups separados de Core, Finance/Fiscal e Documentation.
4. Validar SHA-256 e restaurar os dumps em bancos temporários.
5. Listar migrations pendentes e revisar reversibilidade.
6. Registrar imagens novas e anteriores por digest; não depender de pull no rollback.
7. Aprovar janela, operador, comunicação e critério de aborto.

## Deploy

1. Antes de qualquer build, marcar a imagem atual de cada serviço de Core
   (app, queue, scheduler) com tag própria: `<serviço>:rollback-<commit-atual>`.
   Com containerd snapshotter, rebuildar a mesma tag (`:latest`) recicla o
   manifesto da imagem antiga assim que nenhuma tag mais aponta pra ela — o
   digest antigo deixa de existir no image store, mesmo com o container
   ainda rodando nele. Sem essa tag prévia, não sobra para onde reverter
   depois do recreate.
2. Construir uma imagem identificada para Core e outra para Documentation.
   Core inclui `app`, `queue` e `scheduler` — cada um tem tag própria no
   compose (build por serviço, não compartilhado); buildar só `app` deixa
   `queue` e `scheduler` no código antigo mesmo depois de "recriados" no
   passo 4.
3. Aplicar migrations explicitamente no banco correto, sem migration automática no entrypoint.
4. Recriar serviços por bloco: Core, workers, Documentation e por último Nginx.
5. Não recriar PostgreSQL/Redis quando a release não exigir mudança nesses serviços.

Para este RC, a migration de identidade cria somente `user_mfa_credentials`.
Aplicá-la explicitamente depois do backup e antes de recriar Core. Serviços a
recriar no deploy futuro: app, queue, scheduler, documentation-app,
documentation-queue, documentation-scheduler e web. PostgreSQL e Redis ficam.

## Depois

1. Confirmar todos os healthchecks e `/health/ready`.
2. Executar smoke de login, autorização, clientes e documentação.
3. Confirmar heartbeat de queue/scheduler, jobs falhos e backlog.
4. Conferir headers, versão das imagens, mounts e logs sem dados sensíveis.
5. Preencher o manifesto e encerrar a janela somente após observação.

## Rollback

1. Parar a progressão da release e preservar evidências.
2. Reapontar para os digests anteriores registrados.
3. Reverter migration somente quando houver procedimento revisado e seguro.
4. Restore é último recurso, exige aprovação própria e nunca ocorre sobre produção sem confirmação do alvo.
5. Repetir health, smoke e observação antes de encerrar.

O rollback deve reapontar para os três IDs/digests anteriores registrados no
manifesto. Não executar `down` da migration de MFA se já houver enrollment; nesse
caso, restaurar a imagem anterior mantendo a tabela compatível e revisar depois.
