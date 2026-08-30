const { test, expect, login, assertA11y } = require('./support/fixtures');

async function nextWeekday(page) {
  return page.evaluate(() => {
    const date = new Date(); date.setDate(date.getDate() + 2);
    while ([0, 6].includes(date.getDay())) date.setDate(date.getDate() + 1);
    return date.toISOString().slice(0, 10);
  });
}

test('booking público completo pelo calendário visual', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'mutação pública coberta uma vez; responsividade coberta separadamente');
  await page.goto('/agenda/consultoria-e2e');
  await expect(page.getByRole('heading', { name: 'Consultoria E2E' })).toBeVisible();
  const date = await nextWeekday(page);
  await page.locator(`[data-date="${date}"]`).click();
  await page.getByRole('button', { name: 'Selecionar 09:00' }).click();
  await page.getByLabel('Nome').fill('Booking Browser E2E');
  await page.getByLabel('E-mail').fill('booking-browser@example.test');
  await page.waitForTimeout(2100);
  await page.getByRole('button', { name: 'Confirmar agendamento' }).click();
  await expect(page.getByRole('heading', { name: 'Agendamento confirmado' })).toBeVisible();
});

test('cancelamento público por token seguro', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'token de uso único coberto uma vez');
  await page.goto('/agenda/agendamento/cancel-e2e/cancelar?token=' + 'a'.repeat(64));
  await page.getByRole('button', { name: 'Confirmar cancelamento' }).click();
  await expect(page.getByRole('heading', { name: 'Agendamento cancelado' })).toBeVisible();
});

test('reagendamento público usa calendário e slots', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'token rotacionado coberto uma vez');
  await page.goto('/agenda/agendamento/reschedule-e2e/reagendar?token=' + 'b'.repeat(64));
  await expect(page.getByRole('heading', { name: 'Escolha o novo horário' })).toBeVisible();
  const date = await nextWeekday(page);
  await page.locator(`[data-date="${date}"]`).click();
  await page.getByRole('button', { name: 'Selecionar 11:00' }).click();
  await page.getByRole('button', { name: 'Confirmar novo horário' }).click();
  await expect(page.getByRole('heading', { name: 'Agendamento confirmado' })).toBeVisible();
});

test('admin cria agendamento e gerencia exception', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'mutação administrativa coberta uma vez');
  await login(page);
  await page.goto('/scheduling/create');
  const date = await nextWeekday(page);
  await page.getByLabel('Tipo de agendamento').selectOption({ index: 1 });
  await page.getByLabel('Data').fill(date);
  await page.getByRole('button', { name: '12:00' }).click();
  await page.getByLabel('Participante').fill('Admin Browser E2E');
  await page.getByLabel('E-mail').fill('admin-booking@example.test');
  await page.getByRole('button', { name: 'Criar agendamento' }).click();
  await expect(page.getByRole('heading', { name: 'Admin Browser E2E' })).toBeVisible();
  await page.goto('/scheduling/event-types');
  await page.getByRole('link', { name: 'Disponibilidade', exact: true }).click();
  await page.getByLabel('Data').fill(date);
  await page.getByLabel('Motivo').fill('Bloqueio E2E');
  await page.getByRole('button', { name: 'Cadastrar exceção' }).click();
  page.once('dialog', dialog => dialog.accept());
  await page.getByRole('button', { name: 'Remover' }).last().click();
  await expect(page.getByRole('status')).toContainText('removida');
});

test('agenda passa axe, temas, breakpoints e visões', async ({ monitoredPage: page }, testInfo) => {
  await page.goto('/agenda/consultoria-e2e');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.getByRole('button', { name: 'Alternar tema claro e escuro' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1)).toBe(true);
  if (testInfo.project.name === 'desktop') await assertA11y(page);
  await login(page);
  for (const view of ['day', 'week', 'month']) {
    await page.goto('/scheduling/calendar/' + view);
    await expect(page.locator('.calendar-grid')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1)).toBe(true);
  }
});

test('duas reservas PostgreSQL concorrentes confirmam somente uma', async ({ monitoredPage: page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'concorrência real coberta uma vez');
  await page.goto('/agenda/consultoria-e2e');
  const date = await nextWeekday(page);
  await page.locator(`[data-date="${date}"]`).click();
  const slotButton = page.getByRole('button', { name: 'Selecionar 15:00' });
  await expect(slotButton).toBeVisible();
  await slotButton.click();
  const csrf = await page.locator('input[name="_token"]').first().inputValue();
  const body = suffix => ({ _token: csrf, timezone: 'America/Sao_Paulo', guest_name: `Race ${suffix}`, guest_email: `race-${suffix}@example.test`, form_started_at: Math.floor(Date.now()/1000)-3 });
  const selectedStart = await page.locator('#selected-start').inputValue();
  const [a,b] = await Promise.all(['a','b'].map(suffix => page.request.post('/agenda/consultoria-e2e', { form: { ...body(suffix), start: selectedStart }, maxRedirects: 0 })));
  expect([a.status(),b.status()].filter(status => status === 302)).toHaveLength(2);
  await login(page); await page.goto('/scheduling?search=Race');
  await expect(page.locator('tbody tr')).toHaveCount(1);
});
