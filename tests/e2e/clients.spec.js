const { test, expect, login, assertA11y } = require('./support/fixtures');

test('pesquisa, abre e retorna da ficha sintetica', async ({ monitoredPage: page }) => {
  await login(page);
  await page.goto('/clients');
  const search = page.getByPlaceholder(/Buscar por nome/);
  await search.fill('Cliente Teste A');
  await page.getByRole('button', { name: 'Filtrar' }).click();
  await expect(page.getByRole('link', { name: 'Cliente Teste A', exact: true })).toBeVisible();
  await page.getByRole('link', { name: 'Cliente Teste A', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Cliente Teste A');
  await page.goBack();
  await expect(page.getByRole('heading', { name: 'Clientes' })).toBeVisible();
});

test('cria, valida e edita cliente exclusivamente sintetico', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'mutacao deterministica executada uma vez');
  await login(page);
  await page.goto('/clients/create');
  await page.getByLabel(/Razão social/).fill('Cliente E2E Navegador');
  await page.getByLabel('E-mail').fill('browser@example.test');
  await page.getByLabel('CPF ou CNPJ').fill('123');
  await page.getByRole('button', { name: 'Cadastrar cliente' }).click();
  await expect(page.locator('.field-error')).toBeVisible();
  await page.getByLabel('CPF ou CNPJ').fill('39053344705');
  await page.getByLabel('CEP').fill('01001000');
  await page.getByRole('button', { name: 'Cadastrar cliente' }).click();
  await expect(page.locator('.alert-success')).toContainText('cadastrado');
  await page.getByRole('link', { name: 'Editar' }).click();
  await page.getByLabel('Nome fantasia').fill('Cliente Browser Editado');
  await page.getByRole('button', { name: 'Salvar alterações' }).click();
  await expect(page.locator('.alert-success')).toContainText('atualizado');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Cliente Browser Editado');
});

test('formulario de cliente passa axe e possui labels', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'axe detalhado executado no desktop');
  await login(page);
  await page.goto('/clients/create');
  await assertA11y(page);
  for (const input of await page.locator('input, select, textarea').all()) {
    if (await input.getAttribute('type') === 'hidden') continue;
    await expect(input).toHaveAccessibleName(/.+/);
  }
});
