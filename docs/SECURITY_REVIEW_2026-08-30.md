# Revisão de segurança — 2026-08-30

## Escopo

- aplicação principal Laravel (`app/`);
- aplicação de documentação Laravel (`documentation-app/`);
- fluxo de autenticação, MFA e autorização;
- webhooks e API de documentação;
- infraestrutura Docker, Nginx e runbook de deploy;
- integridade dos dois repositórios Git.

Disparada a partir da investigação de um erro 500 no login em produção.

## Causa raiz do incidente original

Migration `2026_08_25_130000_add_mfa_security_to_users_table` nunca havia
sido aplicada neste ambiente. O código de MFA já esperava a tabela
`user_mfa_credentials`, causando `QueryException` no login.

## Correções realizadas

### Bypass de MFA por exceção não tratada

`LoginController::store` regenerava a sessão (autenticando o guard `web` via
`Auth::attempt` dentro de `LoginRequest::authenticate()`) antes de checar
`MfaManager::isEnabled()`. Uma exceção nessa checagem deixava a sessão
autenticada de pé sem o usuário nunca passar pelo desafio de MFA. Corrigido
com fail-closed: logout forçado e invalidação de sessão antes de relançar
qualquer erro na checagem de MFA.

### Força bruta no desafio de MFA

`MfaChallengeController` não tinha rate limit no TOTP nem no código de
recuperação. Adicionado throttle por usuário pendente + IP (5 tentativas/60s)
e por usuário pendente isolado (20 tentativas/15min), fechando também o vetor
de força bruta distribuída por múltiplos IPs.

### Autorização ausente em documentos e dashboard fiscal

`FiscalDocumentController::show`/`authorizeManual` e
`FiscalDashboardController` não checavam role, permitindo que qualquer
usuário autenticado lesse documentos fiscais e dados de faturamento de
qualquer cliente. Adicionado `abort_unless(isAdministrator())` e um novo
middleware `user.administrator`, aplicado a todo o grupo de rotas fiscais e
ao `system-diagnostic`, como camada de defesa em profundidade.

### Força bruta distribuída no login

`LoginRequest` só travava por `email+IP`. Adicionado um segundo rate limit
por conta isolada (20 tentativas/15min), fechando o vetor de força bruta
distribuída contra a mesma conta a partir de múltiplos IPs.

### IDOR no assistente IRR

`IrrWorkflowController::markSent`/`confirm` recebiam `{irrWorkflow}` e
`{step}` da URL sem checar se o step pertence ao workflow informado,
diferente de `updatePrefixPolicy()`, que já fazia essa checagem. Corrigido
com `abort_unless($step->irr_workflow_id === $irrWorkflow->id, 404)`.

### Gap de processo no deploy

O runbook (`docs/HARDENING_DEPLOY_RUNBOOK.md`) proibia migração automática
durante o deploy, mas não tinha nenhum passo formal para aplicar migrations
pendentes manualmente antes de liberar o tráfego — a causa raiz do incidente.
Adicionada a etapa F1 obrigatória e um item de checklist de smoke
correspondente.

## Investigado e descartado (comportamento intencional)

Uma correção inicial restringiu `/finance/*` a administradores, por
analogia ao módulo fiscal. Revertida após `FinanceWebTest`/`InvoiceWebTest`
confirmarem que o papel `viewer` deve enxergar o financeiro em modo
somente leitura (banner "Módulo em modo protegido", ações de escrita
ocultas) — diferente do fiscal, que é admin-only por decisão de produto.

## Confirmado seguro (sem achados)

- Webhook Efí: assinatura validada com `hash_equals` (timing-safe);
  deduplicação de replay por hash de token com `insertOrIgnore` +
  `lockForUpdate`.
- `ApiCredentialService`: hash SHA-256 + `hash_equals` + expiração/revogação.
- `ExternalEndpointGuard` (SSRF): DNS pinning via `CURLOPT_RESOLVE`, bloqueio
  de IPs privados/reservados, sem seguir redirecionamentos.
- Upload de artefato fiscal: nome sanitizado, path baseado em hash SHA-256,
  validação de mime/assinatura de arquivo (PDF/XML).
- Sem `eval()`, `exec()`, `passthru()`, `shell_exec()`, `unserialize()` fora
  de `vendor/` em nenhum dos dois apps.
- Sem senha/token/segredo em log (`Log::info/error/debug/warning`).
- Sem `config/cors.php` em nenhum dos dois apps (CORS não habilitado).
- Controllers de usuários, clientes, ASNs, prefixos, incidentes de
  roteamento, auditoria e integrações externas: autorização consistente
  (`abort_unless(isAdministrator())`/`canOperate()` no controller ou no
  `FormRequest::authorize()`).
- Infraestrutura: sem `docker.sock` montado, sem containers privilegiados,
  apenas portas 80/443 expostas ao host (Postgres/Redis/PHP-FPM só na rede
  interna), `APP_DEBUG=false`, `APP_ENV=production`,
  `SESSION_SECURE_COOKIE=true`.
- Histórico Git (ambos os repositórios): sem `.env`, chaves privadas ou
  segredos commitados.

## Pendente para correção/confirmação futura

Estes dois pontos **não são vulnerabilidades confirmadas em código** — a
implementação em si (comparação de hash, validação de assinatura) está
correta — mas são portas de risco condicionadas a flags de ambiente que
não foram confirmadas nesta revisão (leitura do `.env` de produção não fez
parte do escopo autorizado). Ficam registrados para checagem/decisão
posterior, sem ação de código associada ainda:

1. **Token legado da API de documentação**
   (`documentation.legacy_token_enabled`, ver
   `app/Http/Middleware/AuthenticateDocumentationApi.php` e
   `RequireDocumentationApiScope.php`). Quando ativo, um único hash global
   (`documentation.api_token_hash`) concede acesso a **todos os escopos** da
   API, sem expiração por cliente, e o rate limiter retorna `Limit::none()`
   para esse caminho (`AppServiceProvider.php`). Se a flag estiver ligada em
   produção e o token vazar, o dano é total e sem contenção por throttling.
   **Ação futura sugerida:** confirmar que a flag está `false` em produção;
   se ainda necessária para migração, aplicar throttling explícito ao
   caminho legado e/ou restringir a um conjunto mínimo de escopos em vez de
   bypass total.

2. **Rota legada do webhook Efí sem segredo na URL**
   (`webhook_legacy_route_enabled`, ver
   `app/Http/Middleware/ValidateEfiWebhookCallback.php`). Enquanto ativa
   durante a janela de troca de URL na Efí, qualquer requisição sem segredo
   na URL é aceita nessa rota (o corpo ainda passa pela validação de
   assinatura do provider depois, o que mitiga o risco, mas a camada de
   segredo na URL é pulada). **Ação futura sugerida:** confirmar que a flag
   permanece desligada fora de uma janela controlada de transição de URL, e
   idealmente remover a rota legada assim que a transição for concluída.

Nenhuma outra vulnerabilidade crítica ou alta foi identificada nesta
revisão.
