const { test, expect, login } = require('./support/fixtures');

test('viewer nao ve acao administrativa e backend nega rota', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'autorizacao backend coberta uma vez');
  await login(page, 'viewer');
  await page.goto('/clients');
  await expect(page.getByRole('link', { name: 'Novo cliente' })).toHaveCount(0);
  const response = await page.context().request.get('/clients/create', { maxRedirects: 0 });
  expect(response.status()).toBe(403);
});

test('operador acessa leitura mas nao administracao', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'papel intermediario coberto uma vez');
  await login(page, 'operator');
  await page.goto('/clients');
  await expect(page.getByRole('heading', { name: 'Clientes' })).toBeVisible();
  const response = await page.context().request.get('/users', { maxRedirects: 0 });
  expect(response.status()).toBe(403);
});
