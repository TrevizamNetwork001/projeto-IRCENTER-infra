const { test, expect, login, assertA11y } = require('./support/fixtures');

test('login possui semantica e axe sem serious ou critical', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'axe detalhado executado no desktop');
  await page.goto('/login');
  await expect(page.locator('html')).toHaveAttribute('lang', 'pt-BR');
  await expect(page).toHaveTitle(/IRCENTER/);
  await expect(page.getByRole('main')).toBeVisible();
  await expect(page.getByRole('heading', { level: 2 })).toBeVisible();
  await assertA11y(page);
});

test('dashboard, clientes e erro 404 passam axe', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'axe detalhado executado no desktop');
  await login(page);
  for (const path of ['/dashboard', '/clients', '/pagina-e2e-inexistente']) {
    await page.goto(path);
    await assertA11y(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'pt-BR');
    await expect(page).not.toHaveTitle(/^IRCENTER$/);
  }
});
