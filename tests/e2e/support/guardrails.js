const forbiddenHosts = [
  'ircenter.trevizamnetwork.com.br',
  'ircenter-postgres',
  'ircenter-redis',
  'localhost',
  '127.0.0.1',
  'host.docker.internal',
];

function abort(message) {
  console.error(`ABORTADO: ${message}`);
  process.exit(64);
}

function requireValue(name, allowed) {
  const value = process.env[name] ?? '';
  if (!allowed.includes(value)) abort(`${name}=${value || '<vazio>'} nao e seguro para E2E`);
}

const inspected = [
  process.env.BASE_URL,
  process.env.APP_URL,
  process.env.DB_HOST,
  process.env.DB_DATABASE,
  process.env.REDIS_HOST,
  process.env.FINANCE_FISCAL_DB_HOST,
  process.env.FINANCE_FISCAL_DB_DATABASE,
].filter(Boolean).join(' ').toLowerCase();

for (const host of forbiddenHosts) {
  if (inspected.includes(host)) abort(`hostname/endereco proibido detectado: ${host}`);
}

requireValue('APP_ENV', ['testing', 'e2e']);
requireValue('BASE_URL', ['http://e2e-web:8080']);
requireValue('APP_URL', ['http://e2e-web:8080']);
requireValue('DB_HOST', ['e2e-postgres']);
requireValue('DB_DATABASE', ['ircenter_e2e']);
requireValue('REDIS_HOST', ['e2e-redis']);
requireValue('FINANCE_FISCAL_DB_HOST', ['e2e-postgres']);
requireValue('FINANCE_FISCAL_DB_DATABASE', ['ircenter_e2e_finance']);
requireValue('PAYMENT_PROVIDER', ['fake']);
requireValue('PAYMENT_LIVE_ENABLED', ['false', '0']);
requireValue('PAYMENT_WEBHOOKS_ENABLED', ['false', '0']);
requireValue('NFSE_PROVIDER', ['fake']);
requireValue('NFSE_TRANSMISSION_ENABLED', ['false', '0']);
requireValue('NFSE_LIVE_ENABLED', ['false', '0']);
requireValue('EFI_ENVIRONMENT', ['homologation']);
requireValue('MAIL_MAILER', ['array']);

console.log('guardrails=e2e-safe');
