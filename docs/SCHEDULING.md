# Agenda / Scheduling

## Arquitetura e ativação

O domínio fica em `app/app/Modules/Scheduling` e reutiliza Laravel, Blade, o centro de notificações e a auditoria do IRCENTER. A feature flag permanece desabilitada por padrão (`SCHEDULING_ENABLED=false`). Em ambiente controlado, habilite-a e execute a migration pelo processo normal do ambiente; nenhuma migration é disparada pela aplicação.

As sete tabelas são criadas por `2026_08_29_120000_create_scheduling_tables.php`: tipos, regras, exceptions, appointments, participantes, timeline e entregas de reminders. Não houve migration adicional nesta fase. `ExternalCalendarProvider` continua apenas como ponto de extensão futuro; não há integração Google/Microsoft.

## Disponibilidade e operações

`SlotGenerator` é a única fonte de slots para booking, reagendamento e criação administrativa. Ele combina duração, intervalo, buffers antes/depois, minimum notice, booking horizon, regras semanais, bloqueios, overrides, compromissos ativos e timezone. Agendamentos são limitados a segunda-feira até sexta-feira; sábado e domingo permanecem indisponíveis inclusive diante de override. O calendário público consulta o backend para classificar os dias e possui navegação mensal, loading, vazio, erro, seleção e slots acessíveis.

Booking e criação administrativa bloqueiam o `EventType` com `SELECT ... FOR UPDATE`, recalculam o slot dentro da transação e só então persistem. O reagendamento visual usa o mesmo gerador, ignora somente o próprio appointment durante a revalidação bloqueada, registra o horário anterior, invalida reminders antigos e rotaciona ambos os tokens. Cancelamento é idempotente. O admin pode associar cliente e remover exceptions somente pelo vínculo pai correto; ações mutáveis exigem usuário operator/admin, CSRF e geram auditoria.

## Página pública e compartilhamento

Cada `EventType` usa a URL estável e legível `/agenda/{slug}`. O slug é único, serve como chave da rota e aparece na tela administrativa, que oferece **Ver página pública**. Tipos inativos e slugs inexistentes respondem 404 e nunca chegam ao fluxo de reserva.

O cliente escolhe somente dias classificados pelo backend como disponíveis, consulta os slots reais do `SlotGenerator`, seleciona um horário e usa **Avançar** antes de informar nome, e-mail, telefone opcional e motivo/observação opcional. **Voltar** preserva a seleção enquanto a página permanecer aberta. Empresa existe no schema para uso administrativo, mas não é solicitada aqui. Attendees existem no modelo, porém ainda não estão integrados de forma completa ao booking público e ficam fora desta fase.

A página é light-first, não usa navegação administrativa e reflowa de três áreas no desktop para um fluxo vertical até 320 px. O timezone selecionado controla calendário, slots, contexto, persistência e exibição. Duração, data e hora são sempre recalculadas e validadas no servidor.

## Tokens, notificações e e-mail

Tokens públicos usam 32 bytes aleatórios (256 bits); somente SHA-256 é persistido. Tokens não entram em auditoria ou notificações internas. Os payloads de fila de confirmação/reagendamento carregam os tokens cifrados com a chave da aplicação, nunca em texto puro. Links são validados antes da exibição de cancelar/reagendar.

Novo agendamento, cancelamento e reagendamento geram entradas idempotentes no notification center existente para operadores e administradores, com participante, serviço, data/hora, timezone e cliente quando houver. E-mails Laravel em fila cobrem confirmação, cancelamento, reagendamento e reminders de 24h/1h. Reminders usam chave única `(appointment_id, minutes_before)`; cancelados/passados são ignorados e reagendamento apaga entregas do horário antigo.

A confirmação pública mostra evento, participante principal, data, hora, duração, timezone e ICS. Na navegação imediatamente após criar ou reagendar, a sessão também fornece ações seguras de cancelamento e reagendamento; os mesmos links são enviados por e-mail. IDs internos, observações administrativas e tokens em texto não são exibidos.

## Tempo, ICS e CSV

Appointments são armazenados como instantes UTC (`timestampTz`). Regras são interpretadas no timezone da própria regra; slots são apresentados no timezone solicitado e o timezone escolhido é salvo no appointment. E-mails usam o timezone salvo. ICS usa UTC com sufixo `Z`. Spring-forward normaliza o início de janela inexistente para o primeiro instante válido e não oferece hora inexistente; fall-back produz instantes ISO únicos. Testes cobrem UTC, `America/Sao_Paulo`, `America/New_York`, mudança de dia e transições DST.

ICS escapa quebras de linha e caracteres RFC; CSV neutraliza células iniciadas por `=`, `+`, `-` ou `@`. As rotas públicas preservam rate limit, honeypot e tempo mínimo de formulário; toda mutação web usa CSRF.

## Limitações desta fase

Não há Google Calendar/Meet, Outlook/Microsoft Graph, Calendly, pagamentos, CRM, round-robin, equipes ou videoconferência própria. O `.ics` existente é a única ação de calendário. A Agenda administrativa não foi redesenhada e não foi criado outro motor de disponibilidade.

## Validação

Use `scripts/test-isolated.sh app test tests/Feature/Scheduling tests/Unit/Scheduling` para a matriz específica e `scripts/test-isolated.sh app test` para a suíte completa. O runner usa banco descartável e verifica que caches/containers produtivos não mudaram. `scripts/test-e2e.sh` executa Chromium headless em PostgreSQL/Redis temporários, `MAIL_MAILER=array`, providers fake e guardrails contra hosts produtivos. A corrida de duas requisições públicas independentes ao mesmo slot valida o locking real no PostgreSQL.

O E2E cobre booking, cancelamento, reagendamento visual, criação admin, CRUD essencial de disponibilidade/exception, visões dia/semana/mês, axe, teclado, dark/light e viewports 1440×900, 768×1024 e 390×844. Dados são exclusivamente sintéticos e o ambiente é destruído ao terminar.
# Ativação em produção

Em 30 de agosto de 2026, o módulo foi ativado no ambiente produtivo por meio de
`SCHEDULING_ENABLED=true`. A migration
`2026_08_29_120000_create_scheduling_tables` já estava aplicada no batch 19;
nenhuma migration ou alteração de banco foi executada durante a ativação.

Somente os containers `app`, `queue` e `scheduler` foram recriados para receber
a variável. Todos ficaram healthy e confirmaram a flag no runtime. O painel,
login e `/scheduling` responderam 200, e a suíte visual isolada validou Agenda,
visões diária/semanal/mensal, EventTypes, disponibilidade, exceptions, criação
administrativa, temas claro/escuro e viewports 1440x900, 768x1024 e 390x844.

Durante a operação, o IP do app mudou de `172.18.0.6` para `172.18.0.9`. O
Nginx alcançou automaticamente o novo endereço pelo DNS interno Docker, sem
reload. O procedimento e a evidência estão em `docs/DOCKER_NETWORKING.md`.
