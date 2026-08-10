const { test, expect, login, credentials } = require('./support/fixtures');

test('visitante e redirecionado e login invalido exibe erro', async ({ monitoredPage: page }) => {
  await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/login$/);
  await page.getByLabel('E-mail').fill('invalido@e2e.example.test');
  await page.getByLabel('Senha', { exact: true }).fill('senha-incorreta');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page.getByRole('alert')).toContainText('credenciais');
});

test('login cria sessao, navega e logout encerra acesso', async ({ monitoredPage: page }) => {
  const before = await page.context().cookies();
  await login(page, 'admin');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Visão geral do ambiente');
  const after = await page.context().cookies();
  expect(after.find(cookie => cookie.name.includes('session'))?.value)
    .not.toBe(before.find(cookie => cookie.name.includes('session'))?.value);
  await page.getByRole('button', { name: /Administrador E2E/ }).click();
  await page.getByRole('menuitem', { name: 'Sair' }).click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto('/clients');
  await expect(page).toHaveURL(/\/login$/);
});

test('login por teclado mantem ordem e foco visivel', async ({ monitoredPage: page }) => {
  const [email, password] = credentials.admin;
  await page.goto('/login');
  await expect(page.getByLabel('E-mail')).toBeFocused();
  await page.keyboard.type(email);
  await page.keyboard.press('Tab');
  await expect(page.getByLabel('Senha', { exact: true })).toBeFocused();
  await page.keyboard.type(password);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('button', { name: 'Entrar' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/dashboard$/);
});
