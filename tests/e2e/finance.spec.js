const { test, expect, login, assertA11y } = require('./support/fixtures');

test('financeiro mostra visao geral e dados sinteticos', async ({ monitoredPage: page }) => {
  await login(page);
  await page.goto('/finance');
  await expect(page.getByRole('heading', { name: 'Visão geral' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Próximas cobranças' })).toBeVisible();
  await expect(page.getByText('Cliente Teste A', { exact: true }).first()).toBeVisible();
  await page.getByRole('link', { name: 'Ver faturas' }).click();
  await expect(page.getByRole('cell', { name: '05/08/2026', exact: true })).toBeVisible();
  await page.getByRole('link', { name: '#1', exact: true }).click();
  await expect(page.getByText('R$ 199,90').first()).toBeVisible();
  await expect(page.getByText(/fake/i).first()).toBeVisible();
});

test('financeiro passa axe sem severidade bloqueante', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'axe detalhado executado no desktop');
  await login(page);
  await page.goto('/finance');
  await assertA11y(page);
});
