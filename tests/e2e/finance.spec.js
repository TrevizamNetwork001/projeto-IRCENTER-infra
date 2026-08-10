const { test, expect, login, assertA11y } = require('./support/fixtures');

test('financeiro usa simulador local e mostra dados sinteticos', async ({ monitoredPage: page }) => {
  await login(page);
  await page.goto('/finance');
  await expect(page.getByRole('heading', { name: 'Financeiro' })).toBeVisible();
  await expect(page.getByText('Simulador local')).toBeVisible();
  await expect(page.getByText('Cliente Teste A', { exact: true }).first()).toBeVisible();
  await page.getByRole('link', { name: 'Ver faturas' }).click();
  await expect(page.getByRole('cell', { name: '08/2026', exact: true })).toBeVisible();
  await page.getByRole('link', { name: /Cliente Teste A/ }).first().click();
  await expect(page.getByText('R$ 199,90').first()).toBeVisible();
  await expect(page.getByText(/fake/i).first()).toBeVisible();
});

test('financeiro passa axe sem severidade bloqueante', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'axe detalhado executado no desktop');
  await login(page);
  await page.goto('/finance');
  await assertA11y(page);
});
