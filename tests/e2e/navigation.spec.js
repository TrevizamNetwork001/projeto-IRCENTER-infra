const { test, expect, login } = require('./support/fixtures');

test('navegacao principal nao possui rotas mortas ou erro 500', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'varredura completa executada uma vez');
  await login(page);
  const paths = ['/dashboard', '/clients', '/autonomous-systems', '/prefixes/ipv4',
    '/prefixes/ipv6', '/irr-assistant', '/irr-objects', '/rpki', '/reports',
    '/routing-incidents', '/finance', '/profile'];
  for (const path of paths) {
    const response = await page.goto(path);
    expect(response.status(), path).toBeLessThan(500);
    await expect(page.locator('main h1').first(), path).toBeVisible();
  }
});

test('skip link move foco ao conteudo principal', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'fluxo de teclado executado uma vez');
  await login(page);
  await page.goto('/dashboard');
  await page.keyboard.press('Tab');
  const skip = page.getByRole('link', { name: 'Ir para o conteúdo principal' });
  await expect(skip).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main-content')).toBeFocused();
});
