# Estrutura Git do IRCenter

O diretório `/opt/ircenter` contém três repositórios Git independentes. Eles
não são submódulos: cada aplicação mantém histórico e ciclo de entrega
próprios.

| Projeto | Diretório | Remote `origin` | Branch observada em 2026-08-17 |
| --- | --- | --- | --- |
| IRCenter Infraestrutura | `/opt/ircenter` | `https://github.com/empresa/ircenter-infra.git` | `main` |
| IRCenter Core | `/opt/ircenter/app` | `https://github.com/empresa/ircenter.git` | `feat/finance-fiscal-phase1-foundation` |
| Documentação Técnica | `/opt/ircenter/documentation-app` | `https://github.com/empresa/ircenter-documentation.git` | `feat/fase-23-layout-configuracoes` |

## Verificação diária

Execute os comandos separadamente. Consultar somente o repositório raiz não
mostra alterações das aplicações, pois `app/` e `documentation-app/` estão no
`.gitignore` da raiz.

```bash
git -C /opt/ircenter status --short --branch
git -C /opt/ircenter/app status --short --branch
git -C /opt/ircenter/documentation-app status --short --branch
```

Antes de uma entrega, execute também:

```bash
git -C /opt/ircenter diff --check
git -C /opt/ircenter/app diff --check
git -C /opt/ircenter/documentation-app diff --check

git -C /opt/ircenter fsck --full
git -C /opt/ircenter/app fsck --full
git -C /opt/ircenter/documentation-app fsck --full
```

## Remotes e cópia externa

Os três repositórios receberam um remote `origin` em 2026-08-17. Verifique-os
com:

```bash
git -C /opt/ircenter remote -v
git -C /opt/ircenter/app remote -v
git -C /opt/ircenter/documentation-app remote -v
```

Depois de revisar a branch que deve ser publicada:

```bash
git -C <REPOSITORIO> push --set-upstream origin <BRANCH>
```

Tokens, senhas, chaves privadas, arquivos `.env`, certificados, dumps e backups
nunca devem ser adicionados ao repositório.

## Fluxo recomendado

1. Crie uma branch curta a partir da branch principal atualizada.
2. Faça alterações somente no repositório ao qual o arquivo pertence.
3. Execute testes, auditoria de dependências e `git diff --check`.
4. Revise `git diff` para evitar credenciais e artefatos gerados.
5. Crie commits pequenos e identificáveis.
6. Envie a branch ao remote e faça revisão antes de integrar na `main`.
7. Implante um commit ou tag explícita; não implante uma árvore com alterações
   sem commit.

## Dependências e segurança

Para PHP, execute periodicamente em cada aplicação:

```bash
composer audit --locked --no-interaction
```

Para os testes E2E:

```bash
npm audit --package-lock-only
```

O ambiente de produção não contém Composer ou dependências de desenvolvimento.
Use os contêineres de build/teste definidos pelo projeto para auditorias e
testes, mantendo os serviços e bancos produtivos isolados.
