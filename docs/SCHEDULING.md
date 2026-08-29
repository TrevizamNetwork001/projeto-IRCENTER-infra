# Agenda / Scheduling

O módulo fica em `app/app/Modules/Scheduling` e usa Blade com progressive enhancement. Ele é desabilitado por padrão por `SCHEDULING_ENABLED=false`; quando desabilitado, páginas públicas retornam 404 e o menu administrativo não aparece.

## Domínio e persistência

As tabelas `scheduling_event_types`, `scheduling_availability_rules`, `scheduling_availability_exceptions`, `scheduling_appointments`, `scheduling_appointment_attendees`, `scheduling_appointment_events` e `scheduling_reminder_deliveries` são criadas pela migration `2026_08_29_120000_create_scheduling_tables.php`. O rollback remove somente essas tabelas, na ordem de dependência. Tipos com histórico e agendamentos não são apagados operacionalmente: tipos são desativados e agendamentos cancelados.

Datas de compromissos são persistidas em UTC. Regras carregam seu timezone explicitamente e a interface converte para o timezone escolhido. `SlotGenerator` aplica janelas, overrides/bloqueios, duração, buffers, antecedência, horizonte e conflitos consultando apenas o intervalo relevante.

## Concorrência e segurança

Criação e reagendamento abrem transação e bloqueiam (`SELECT … FOR UPDATE`) a linha do tipo de evento antes de recalcular o slot. Isso serializa reservas do mesmo tipo no PostgreSQL e impede que duas requisições confirmem o mesmo horário. O teste isolado também cobre a revalidação equivalente. Tokens públicos têm 256 bits aleatórios; somente SHA-256 é armazenado. Rate limits, CSRF, honeypot e tempo mínimo de preenchimento protegem as operações públicas. Tokens e dados pessoais não entram na auditoria.

## Rotas e operação

Público: `/agenda/{slug}`, availability JSON, confirmação, cancelamento, reagendamento e ICS. Administração autenticada: `/scheduling`, calendário diário/semanal/mensal, tipos, disponibilidade, exceções, detalhe e CSV. Viewer lê; admin/operator altera. Associação a cliente é sempre manual.

As notificações Laravel implementam confirmação e lembretes em fila. `SendAppointmentReminders` roda a cada minuto pelo scheduler existente e a tabela de entregas torna 24h/1h idempotentes. O centro interno pode ser ampliado futuramente; `ExternalCalendarProvider` prepara Google/Microsoft sem OAuth nesta entrega. Hosts múltiplos e round-robin podem evoluir do `host_user_id` atual.

## Testes e ativação

Execute somente `scripts/test-isolated.sh app test` (ou `app/scripts/test-safe.sh`). O runner usa SQLite em memória, rede desligada e preserva caches/containers produtivos. Antes de ativar, rode a migration no ambiente isolado e então configure `SCHEDULING_ENABLED=true`. Nenhuma migration de produção é executada automaticamente.
