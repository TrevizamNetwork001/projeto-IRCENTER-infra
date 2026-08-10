# Política de timezone e calendário de negócio

## Política

O IRCENTER usa três camadas temporais distintas:

- **timestamp técnico e persistência:** UTC;
- **calendário de negócio:** timezone IANA configurado em
  `BUSINESS_TIMEZONE`, com padrão `America/Sao_Paulo`;
- **apresentação:** conversão explícita para o timezone de negócio, salvo regra
  documentada diferente.

Laravel (`config('app.timezone')`), PHP (`date.timezone`) e sessões PostgreSQL
devem permanecer em UTC. Mudar o timezone global não é uma correção aceitável
para regras locais e nenhum registro histórico deve ser convertido por esta
política.

## DATE e TIMESTAMP

`DATE` representa um dia do calendário e não um instante. Competência,
vencimento e emissão sem hora permanecem `DATE`:

```text
competence_month = 2026-08-01
due_on            = 2026-08-20
issued_on         = 2026-08-10
```

Esses valores não recebem conversão UTC. Já `created_at`, `updated_at`,
`paid_at`, recebimento de webhook, autorização, rejeição e auditoria são
instantes técnicos e devem ser armazenados de forma inequívoca em UTC:

```text
TIMESTAMP UTC: 2026-08-20T15:00:00Z
DISPLAY:       20/08/2026 12:00 America/Sao_Paulo
```

Timestamps oficiais recebidos de provedores preservam o instante e o offset
de origem; dados brutos necessários à rastreabilidade não são reinterpretados.

## Código de negócio

`App\Support\BusinessClock` é a fonte de `now`, `today` e limites de mês para
regras financeiras. Ele usa `CarbonImmutable` e valida o timezone IANA no boot;
configuração inválida impede a aplicação de iniciar. A competência mensal e a
chave de idempotência são derivadas do mês informado no calendário de negócio,
nunca do mês UTC corrente. Vencimentos permanecem date-only.

O módulo fiscal ainda não possui transmissão live nem regra temporal própria.
Quando uma regra for criada, datas de serviço/competência sem hora devem usar
DATE; autorização e rejeição devem usar timestamp com instante preservado.

## Scheduler, logs e auditoria

A tarefa atual de sincronização operacional é técnica e declara UTC
explicitamente. Toda futura tarefa diária ou mensal financeira/fiscal deve
declarar `->timezone(config('business.timezone'))`. O timezone precisa ser
definido na tarefa: a frequência do cron, por si só, não expressa calendário de
negócio.

Logs e auditoria permanecem em UTC. A interface pode converter timestamps por
meio do `BusinessClock`; models não devem mudar globalmente o timezone de seus
casts.

## Horário de verão

Usar sempre `America/Sao_Paulo`, nunca offset fixo. A base IANA representa o
histórico brasileiro, inclusive `-02:00` durante o horário de verão de 2018 e
`-03:00` em períodos atuais. Os testes congelam o relógio em fronteiras de
dia, mês, ano e fevereiro bissexto.

## Inventário H8

- `now()` em autenticação, notificações, auditoria, webhooks, integrações e
  workflows: timestamps técnicos UTC;
- `created_at`/`updated_at` e expiração de locks: comparação técnica UTC;
- competência, `issued_on` e `due_on`: calendário/date-only;
- validação de vencimento Efí: compara DATE contra o dia do negócio;
- reconciliação de cobrança: janela técnica em torno de `created_at`, sem usar
  “hoje”;
- views financeiras: competência, emissão e vencimento já formatam DATE sem
  conversão;
- demais views: timestamps devem migrar gradualmente para o formatter explícito
  quando forem tocadas, sem alterar casts globais;
- documentation-app: timestamps internos UTC; nenhuma regra financeira e
  nenhum bug concreto que justifique tocar seu trabalho pendente na H8.

## Práticas proibidas

- usar offset fixo para representar São Paulo;
- trocar o timezone global para corrigir regra local;
- converter `DATE` para UTC;
- usar `now()` implícito para determinar competência;
- armazenar hora local sem offset como timestamp técnico;
- converter timestamps históricos em massa;
- executar regra diária/mensal de negócio sem timezone explícito.

## Verificação e implantação futura

Não aplicar automaticamente no host. Em janela controlada, após checkout e
rebuild, verificar sem alterar dados:

```bash
docker exec ircenter-app php -r 'echo date_default_timezone_get(), PHP_EOL;'
docker exec ircenter-app php artisan tinker --execute="dump(config('app.timezone')); dump(config('business.timezone'));"
docker exec ircenter-app php artisan schedule:list
docker exec ircenter-postgres psql -U "$DB_USERNAME" -d "$DB_DATABASE" -c 'SHOW timezone;'
```

Resultados esperados: PHP e Laravel em `UTC`, negócio em
`America/Sao_Paulo`, scheduler técnico em UTC e PostgreSQL em UTC. Não usar os
comandos acima com credenciais literais em histórico compartilhado.

Rollback: restaurar a imagem/configuração anterior e recriar apenas os serviços
afetados. Não executar UPDATE, ALTER DATABASE/ROLE, migrations de conversão ou
mudança de timestamps como rollback.
