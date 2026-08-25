# Identidade e MFA

A fundação local inclui TOTP RFC 6238, segredo cifrado pelo Laravel, recovery
codes armazenados somente como hashes, uso único, proteção contra replay por
time-step, confirmação recente de senha e revogação de sessões em banco.

O login realiza o desafio MFA antes de criar a sessão autenticada definitiva.
O desafio tem rate limit, usuário inativo continua bloqueado e recovery code é
invalidado no primeiro uso. Login, logout e operações de segurança são auditados.

`/profile/security` oferece enrollment, confirmação, exibição única e regeneração
dos recovery codes, disable protegido por senha recente e encerramento das outras
sessões sem expor identificadores. `MFA_ENFORCEMENT=false` permanece como default;
nenhum usuário atual será obrigado a ativar MFA nesta release.

A migration `2026_08_25_130000_add_mfa_security_to_users_table.php` passou nos
testes isolados, mas não foi aplicada ao PostgreSQL produtivo. Ela precisa integrar
o gate de deploy futuro, depois de backup e antes do smoke de identidade.
