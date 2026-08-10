const { test, expect, login } = require('./support/fixtures');

test('layout nao tem overflow global e acoes permanecem alcancaveis', async ({ monitoredPage: page }, testInfo) => {
  await login(page);
  for (const path of ['/dashboard', '/clients', '/clients/create', '/finance']) {
    await page.goto(path);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
    expect(overflow, `${path} em ${testInfo.project.name}`).toBe(false);
    await expect(page.locator('main')).toBeVisible();
  }
  if (testInfo.project.name !== 'desktop') {
    const menu = page.getByRole('button', { name: 'Abrir menu principal' });
    await expect(menu).toBeVisible();
    await menu.click();
    await expect(page.getByRole('link', { name: 'Clientes' })).toBeVisible();
  }
});
