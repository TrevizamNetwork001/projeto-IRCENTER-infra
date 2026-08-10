const { test: base, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

const credentials = {
  admin: ['admin@e2e.example.test', 'E2e-Admin-2026!'],
  operator: ['operator@e2e.example.test', 'E2e-Operator-2026!'],
  viewer: ['viewer@e2e.example.test', 'E2e-Viewer-2026!'],
};

const test = base.extend({
  monitoredPage: async ({ page }, use, testInfo) => {
    const errors = [];
    const csp = [];
    page.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
    page.on('console', message => {
      if (message.type() !== 'error') return;
      const text = message.text();
      // Chromium registra a navegação deliberada para a página 404 como
      // console.error; somente essa mensagem exata e nesse caminho é esperada.
      if (page.url().endsWith('/pagina-e2e-inexistente')
        && /^Failed to load resource: the server responded with a status of 404 \(Not Found\)$/.test(text)) {
        return;
      }
      if (/content security policy|refused to/i.test(text)) csp.push(text);
      else errors.push(`console.error: ${text}`);
    });
    await page.route('**/*', async route => {
      const url = new URL(route.request().url());
      if (url.hostname === 'e2e-web') return route.continue();
      if (url.hostname === 'viacep.com.br' || url.hostname.endsWith('.viacep.com.br')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({
          cep: '01001-000', logradouro: 'Praça E2E', bairro: 'Centro de Testes',
          localidade: 'São Paulo', uf: 'SP', erro: false,
        }) });
      }
      errors.push(`request externo bloqueado: ${url.href}`);
      return route.abort('blockedbyclient');
    });
    await use(page);
    await testInfo.attach('csp-observations', { body: Buffer.from(JSON.stringify(csp)), contentType: 'application/json' });
    await testInfo.attach('console-errors', { body: Buffer.from(JSON.stringify(errors)), contentType: 'application/json' });
    expect(errors, 'erros JavaScript/console ou requests externos').toEqual([]);
    expect(csp, 'violacoes CSP observadas').toEqual([]);
  },
});

async function login(page, role = 'admin') {
  const [email, password] = credentials[role];
  await page.goto('/login');
  await page.getByLabel('E-mail').fill(email);
  await page.getByLabel('Senha', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
}

async function assertA11y(page) {
  const results = await new AxeBuilder({ page }).analyze();
  const blocking = results.violations.filter(v => ['serious', 'critical'].includes(v.impact));
  expect(blocking, blocking.map(v => `${v.id}: ${v.help}`).join('\n')).toEqual([]);
}

module.exports = { test, expect, login, assertA11y, credentials };
