# Agenda / Scheduling

## Arquitetura e ativação

O domínio fica em `app/app/Modules/Scheduling` e reutiliza Laravel, Blade, o centro de notificações e a auditoria do IRCENTER. A feature flag permanece desabilitada por padrão (`SCHEDULING_ENABLED=false`). Em ambiente controlado, habilite-a e execute a migration pelo processo normal do ambiente; nenhuma migration é disparada pela aplicação.

As sete tabelas são criadas por `2026_08_29_120000_create_scheduling_tables.php`: tipos, regras, exceptions, appointments, participantes, timeline e entregas de reminders. Não houve migration adicional nesta fase. `ExternalCalendarProvider` continua apenas como ponto de extensão futuro; não há integração Google/Microsoft.

## Disponibilidade e operações

`SlotGenerator` é a única fonte de slots para booking, reagendamento e criação administrativa. Ele combina duração, intervalo, buffers antes/depois, minimum notice, booking horizon, regras semanais, bloqueios, overrides, compromissos ativos e timezone. O calendário público consulta o backend para classificar os dias e possui navegação mensal, loading, vazio, erro, seleção e slots acessíveis.

Booking e criação administrativa bloqueiam o `EventType` com `SELECT ... FOR UPDATE`, recalculam o slot dentro da transação e só então persistem. O reagendamento visual usa o mesmo gerador, ignora somente o próprio appointment durante a revalidação bloqueada, registra o horário anterior, invalida reminders antigos e rotaciona ambos os tokens. Cancelamento é idempotente. O admin pode associar cliente e remover exceptions somente pelo vínculo pai correto; ações mutáveis exigem usuário operator/admin, CSRF e geram auditoria.

## Tokens, notificações e e-mail

Tokens públicos usam 32 bytes aleatórios (256 bits); somente SHA-256 é persistido. Tokens não entram em auditoria ou notificações internas. Os payloads de fila de confirmação/reagendamento carregam os tokens cifrados com a chave da aplicação, nunca em texto puro. Links são validados antes da exibição de cancelar/reagendar.

Novo agendamento, cancelamento e reagendamento geram entradas idempotentes no notification center existente para operadores e administradores, com participante, serviço, data/hora, timezone e cliente quando houver. E-mails Laravel em fila cobrem confirmação, cancelamento, reagendamento e reminders de 24h/1h. Reminders usam chave única `(appointment_id, minutes_before)`; cancelados/passados são ignorados e reagendamento apaga entregas do horário antigo.

## Tempo, ICS e CSV

Appointments são armazenados como instantes UTC (`timestampTz`). Regras são interpretadas no timezone da própria regra; slots são apresentados no timezone solicitado e o timezone escolhido é salvo no appointment. E-mails usam o timezone salvo. ICS usa UTC com sufixo `Z`. Spring-forward normaliza o início de janela inexistente para o primeiro instante válido e não oferece hora inexistente; fall-back produz instantes ISO únicos. Testes cobrem UTC, `America/Sao_Paulo`, `America/New_York`, mudança de dia e transições DST.

ICS escapa quebras de linha e caracteres RFC; CSV neutraliza células iniciadas por `=`, `+`, `-` ou `@`. As rotas públicas preservam rate limit, honeypot e tempo mínimo de formulário; toda mutação web usa CSRF.

## Validação

Use `scripts/test-isolated.sh app test tests/Feature/Scheduling tests/Unit/Scheduling` para a matriz específica e `scripts/test-isolated.sh app test` para a suíte completa. O runner usa banco descartável e verifica que caches/containers produtivos não mudaram. `scripts/test-e2e.sh` executa Chromium headless em PostgreSQL/Redis temporários, `MAIL_MAILER=array`, providers fake e guardrails contra hosts produtivos. A corrida de duas requisições públicas independentes ao mesmo slot valida o locking real no PostgreSQL.

O E2E cobre booking, cancelamento, reagendamento visual, criação admin, CRUD essencial de disponibilidade/exception, visões dia/semana/mês, axe, teclado, dark/light e viewports 1440×900, 768×1024 e 390×844. Dados são exclusivamente sintéticos e o ambiente é destruído ao terminar.
