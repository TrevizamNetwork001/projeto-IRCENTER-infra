const { test, expect, login } = require('./support/fixtures');

test('tema claro e escuro persiste apos recarregar', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'persistencia completa coberta no desktop');
  await page.goto('/login');
  await page.getByRole('button', { name: 'Alternar tema claro e escuro' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await login(page);
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await page.getByRole('button', { name: 'Alternar tema' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});
