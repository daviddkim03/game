const { test, expect } = require('@playwright/test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const html = readFileSync(join(__dirname, '../schedule/index.html'), 'utf8');
const block = (id, day, start, end, label = `Event ${id}`) => ({
  id, day, start, end, label, color: '#5aab3f',
});
const original = [
  block(1, 0, 16, 21, 'Focus'),
  { ...block(2, 0, 21, 22, 'Block'), color: '#888780' },
  { ...block(3, 0, 22, 26, 'maintenance'), color: '#378ADD' },
  block(4, 1, 21, 26, 'Other day'),
];

async function openSchedule(page, blocks = original, cloud = null) {
  page.on('pageerror', error => { throw error; });
  // Exercise the real schedule UI with isolated storage and a local sync stub.
  await page.route('**/*', route => {
    const path = new URL(route.request().url()).pathname;
    if (path === '/schedule/') return route.fulfill({ contentType: 'text/html', body: html });
    if (path === '/firebase-config.js') return route.fulfill({ body: '' });
    if (path === '/firebase-sync.js') return route.fulfill({
      contentType: 'text/javascript',
      body: `
        document.documentElement.classList.remove('firebase-auth-pending');
        window.FirebaseSync = {
          isConfigured: () => true,
          load: async () => (${JSON.stringify(cloud)}),
          subscribe: (page, onData) => { window.receiveSchedule = onData; },
          save: async (page, data) => { window.lastSynced = structuredClone(data); }
        };
      `,
    });
    return route.abort();
  });
  await page.addInitScript(blocks => {
    if (!localStorage.getItem('schedule_v2')) {
      localStorage.setItem('schedule_v2', JSON.stringify({
        blocks, nextId: Math.max(0, ...blocks.map(b => b.id)) + 1, hStart: 6,
      }));
    }
  }, blocks);
  await page.goto('http://schedule.test/schedule/');
  await expect(page.locator('.day-col')).toHaveCount(7);
}

async function stored(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('schedule_v2')).blocks);
}

async function expectSchedule(page, expected) {
  expect(await stored(page)).toEqual(expected);
  expect(await page.evaluate(() => window.lastSynced.blocks)).toEqual(expected);
  await expect(page.locator('.block')).toHaveCount(expected.length);
  for (const b of expected) {
    const el = page.locator(`.block[data-bid="${b.id}"]`);
    await expect(el).toHaveCSS('top', `${b.start * 48}px`);
    await expect(el).toHaveCSS('height', `${(b.end - b.start) * 48 - 2}px`);
    await expect(el.locator('..')).toHaveAttribute('data-day', String(b.day));
    for (const other of expected) {
      if (other.id !== b.id && other.day === b.day) {
        expect(b.end <= other.start || b.start >= other.end).toBe(true);
      }
    }
  }
  expect(new Set(expected.map(b => b.id)).size).toBe(expected.length);
}

async function beginResize(page, id, edge = 'end') {
  const handle = page.locator(`.block[data-bid="${id}"] .block-resize[data-edge="${edge}"]`);
  await handle.scrollIntoViewIfNeeded();
  const rect = await handle.boundingBox();
  await page.mouse.move(rect.x + rect.width / 2, rect.y + rect.height / 2);
  await page.mouse.down();
}

async function resizeTo(page, day, end) {
  const col = await page.locator(`.day-col[data-day="${day}"]`).boundingBox();
  await page.mouse.move(col.x + col.width / 2, col.y + end * 48 - 4, { steps: 8 });
}

async function undo(page) {
  await page.keyboard.press('Control+z');
}

for (const end of [22, 24, 26]) {
  test(`extending to slot ${end} trims or removes covered events and supports undo`, async ({ page }) => {
    await openSchedule(page);
    await page.locator('.sched-body').evaluate(el => { el.scrollTop = 650; });
    await beginResize(page, 1);
    await resizeTo(page, 0, end);
    await expect(page.locator('.block[data-bid="2"]')).toHaveCount(0);
    if (end === 24) {
      await expect(page.locator('.block[data-bid="3"] .block-time')).toHaveText('6:00 PM – 7:00 PM');
    }
    await page.mouse.up();
    const expected = [
      { ...original[0], end },
      ...(end < 26 ? [{ ...original[2], start: end }] : []),
      original[3],
    ];
    await expectSchedule(page, expected);
    await undo(page);
    await expectSchedule(page, original);
  });
}

test('dragging back restores temporarily covered events and commits only the final range', async ({ page }) => {
  await openSchedule(page);
  await page.locator('.sched-body').evaluate(el => { el.scrollTop = 650; });
  await beginResize(page, 1);
  await resizeTo(page, 0, 26);
  await expect(page.locator('.block')).toHaveCount(2);
  await resizeTo(page, 0, 21);
  await expect(page.locator('.block')).toHaveCount(4);
  await resizeTo(page, 0, 24);
  await page.mouse.up();
  const expected = [{ ...original[0], end: 24 }, { ...original[2], start: 24 }, original[3]];
  await expectSchedule(page, expected);
  await page.reload();
  await expectSchedule(page, expected);
});

test('shrinking an event leaves its neighbors untouched', async ({ page }) => {
  await openSchedule(page);
  await beginResize(page, 1);
  await resizeTo(page, 0, 20);
  await page.mouse.up();
  await expectSchedule(page, [{ ...original[0], end: 20 }, ...original.slice(1)]);
  await undo(page);
  await expectSchedule(page, original);
});

test('returning to the original size does not consume an undo step', async ({ page }) => {
  await openSchedule(page);
  await page.locator('.sched-body').evaluate(el => { el.scrollTop = 650; });
  await beginResize(page, 1);
  await resizeTo(page, 0, 24);
  await page.mouse.up();
  await beginResize(page, 1);
  await resizeTo(page, 0, 26);
  await resizeTo(page, 0, 24);
  await page.mouse.up();
  await undo(page);
  await expectSchedule(page, original);
});

test('adding inside another event preserves both uncovered portions', async ({ page }) => {
  const initial = [block(1, 0, 0, 8)];
  await openSchedule(page, initial);
  await page.getByRole('button', { name: '+ Add block' }).click();
  await page.locator('#m-label').fill('New event');
  await page.locator('#m-start').selectOption('2');
  await page.locator('#m-end').selectOption('4');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expectSchedule(page, [
    { ...initial[0], end: 2 },
    { ...initial[0], id: 3, start: 4 },
    block(2, 0, 2, 4, 'New event'),
  ]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('editing a range trims the preceding event and deletes a fully covered event', async ({ page }) => {
  const initial = [block(1, 0, 0, 4), block(2, 0, 4, 6), block(3, 0, 6, 8)];
  await openSchedule(page, initial);
  await page.locator('.block[data-bid="2"] .block-name').dblclick();
  await page.locator('#m-start').selectOption('2');
  await page.locator('#m-end').selectOption('8');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expectSchedule(page, [{ ...initial[0], end: 2 }, { ...initial[1], start: 2, end: 8 }]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('moving across days resolves conflicts only on the destination day', async ({ page }) => {
  const initial = [block(1, 0, 0, 4), block(2, 1, 0, 2), block(3, 1, 2, 6), block(4, 2, 0, 6)];
  await openSchedule(page, initial);
  const source = await page.locator('.block[data-bid="1"]').boundingBox();
  const target = await page.locator('.day-col[data-day="1"]').boundingBox();
  await page.mouse.move(source.x + source.width / 2, source.y + 15);
  await page.mouse.down();
  await page.mouse.move(target.x + target.width / 2, target.y + 15, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], day: 1 }, { ...initial[2], start: 4 }, initial[3]]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('pasting trims overlaps and preserves the copied source', async ({ page }) => {
  const initial = [block(1, 0, 0, 4), block(2, 1, 2, 6)];
  await openSchedule(page, initial);
  await page.locator('.block[data-bid="1"] .block-name').click();
  await page.keyboard.press('Control+c');
  const target = await page.locator('.day-col[data-day="1"]').boundingBox();
  await page.mouse.click(target.x + target.width / 2, target.y + 15);
  await page.keyboard.press('Control+v');
  await expectSchedule(page, [initial[0], { ...initial[1], start: 4 }, { ...initial[0], id: 3, day: 1 }]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('moving near midnight keeps the full event inside the schedule', async ({ page }) => {
  const initial = [block(1, 0, 30, 34), block(2, 1, 34, 36)];
  await openSchedule(page, initial);
  await page.locator('.block[data-bid="1"]').scrollIntoViewIfNeeded();
  const source = await page.locator('.block[data-bid="1"]').boundingBox();
  const target = await page.locator('.day-col[data-day="1"]').boundingBox();
  await page.mouse.move(source.x + source.width / 2, source.y + 15);
  await page.mouse.down();
  await page.mouse.move(target.x + target.width / 2, target.y + 35 * 48 + 15, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], day: 1, start: 32, end: 36 }]);
});

test('the pictured morning resize moves the work label below the extended block', async ({ page }) => {
  const initial = [block(1, 1, 6, 20, 'work'), { ...block(2, 1, 4, 6, 'Block'), color: '#888780' }];
  await openSchedule(page, initial);
  await beginResize(page, 2);
  await resizeTo(page, 1, 9);
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], start: 9 }, { ...initial[1], end: 9 }]);
  await expect(page.locator('.block[data-bid="1"] .block-time')).toHaveText('10:30 AM – 4:00 PM');
});

test('extending the pictured Tuesday block to 11 AM keeps work visible during resize and after reload', async ({ page }, testInfo) => {
  const initial = [
    block(1, 0, 6, 21, 'work'),
    block(2, 1, 6, 20, 'work'),
    block(3, 2, 6, 20, 'work'),
    ...[0, 1, 2].flatMap(day => [
      { ...block(4 + day * 3, day, 0, 2, 'Block'), color: '#888780' },
      { ...block(5 + day * 3, day, 2, 4, 'workout'), color: '#c0392b' },
      { ...block(6 + day * 3, day, 4, 6, 'Block'), color: '#888780' },
    ]),
  ];
  await openSchedule(page, initial);
  await beginResize(page, 9);
  await resizeTo(page, 1, 10);
  const work = page.locator('.block[data-bid="2"]');
  const extended = page.locator('.block[data-bid="9"]');
  await expect(work.locator('.block-time')).toHaveText('11:00 AM – 4:00 PM');
  const workRect = await work.boundingBox();
  const extendedRect = await extended.boundingBox();
  expect(workRect.y).toBeGreaterThanOrEqual(extendedRect.y + extendedRect.height);
  // Check the label is actually exposed, rather than hidden under another block.
  expect(await work.locator('.block-name').evaluate(el => {
    const rect = el.getBoundingClientRect();
    return el.contains(document.elementFromPoint(rect.x + 5, rect.y + rect.height / 2));
  })).toBe(true);
  await page.mouse.up();
  const expected = initial.map(b => b.id === 2 ? { ...b, start: 10 } : b.id === 9 ? { ...b, end: 10 } : b);
  await expectSchedule(page, expected);
  await page.reload();
  await expectSchedule(page, expected);
  await expect(work.locator('.block-time')).toHaveText('11:00 AM – 4:00 PM');
  await page.screenshot({ path: testInfo.outputPath('tuesday-resize.png') });
});

test('previously saved overlaps are repaired when the schedule opens', async ({ page }) => {
  const initial = [block(1, 1, 6, 20, 'work'), { ...block(2, 1, 4, 9, 'Block'), color: '#888780' }];
  await openSchedule(page, initial);
  await expectSchedule(page, [{ ...initial[0], start: 9 }, initial[1]]);
  await expect(page.locator('.block[data-bid="1"] .block-time')).toHaveText('10:30 AM – 4:00 PM');
});

test('dragging the top edge extends upward and trims the preceding event', async ({ page }) => {
  const initial = [block(1, 1, 0, 6), block(2, 1, 6, 20, 'work')];
  await openSchedule(page, initial);
  const source = await page.locator('.block[data-bid="2"]').boundingBox();
  const col = await page.locator('.day-col[data-day="1"]').boundingBox();
  await page.mouse.move(source.x + source.width / 2, source.y + 2);
  await page.mouse.down();
  await page.mouse.move(source.x + source.width / 2, col.y + 4 * 48 + 2, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], end: 4 }, { ...initial[1], start: 4 }]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('upward resizing deletes covered events and restores them when dragged back', async ({ page }) => {
  const initial = [block(1, 0, 0, 2), block(2, 0, 2, 4), block(3, 0, 4, 6)];
  await openSchedule(page, initial);
  await beginResize(page, 3, 'start');
  const col = await page.locator('.day-col[data-day="0"]').boundingBox();
  const x = col.x + col.width / 2;
  await page.mouse.move(x, col.y + 2, { steps: 8 });
  await expect(page.locator('.block')).toHaveCount(1);
  await page.mouse.move(x, col.y + 4 * 48 + 2, { steps: 8 });
  await expect(page.locator('.block')).toHaveCount(3);
  await page.mouse.move(x, col.y + 2 * 48 + 2, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [initial[0], { ...initial[2], start: 2 }]);
  await undo(page);
  await expectSchedule(page, initial);
});

test('the top edge stops at the day boundary and leaves at least thirty minutes', async ({ page }) => {
  const initial = [block(1, 0, 2, 4)];
  await openSchedule(page, initial);
  await beginResize(page, 1, 'start');
  const col = await page.locator('.day-col[data-day="0"]').boundingBox();
  const x = col.x + col.width / 2;
  await page.mouse.move(x, col.y - 20, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], start: 0 }]);
  await beginResize(page, 1, 'start');
  await page.mouse.move(x, col.y + 6 * 48, { steps: 8 });
  await page.mouse.up();
  await expectSchedule(page, [{ ...initial[0], start: 3 }]);
  await expect(page.locator('.block-time')).toHaveText('7:30 AM – 8:00 AM');
});

test('overlaps loaded from cloud are repaired and persisted', async ({ page }) => {
  const incoming = [block(1, 1, 6, 20, 'work'), block(2, 1, 4, 9, 'Block')];
  await openSchedule(page, [], { blocks: incoming, nextId: 3, hStart: 6 });
  await expectSchedule(page, [{ ...incoming[0], start: 9 }, incoming[1]]);
});

test('live sync repairs overlaps including full coverage and split events', async ({ page }) => {
  await openSchedule(page, []);
  const incoming = [block(1, 0, 0, 12), block(2, 0, 4, 6), block(3, 0, 2, 8)];
  await page.evaluate(blocks => window.receiveSchedule({ blocks, nextId: 4, hStart: 6 }), incoming);
  await expectSchedule(page, [
    { ...incoming[0], end: 2 },
    { ...incoming[0], id: 4, start: 8 },
    incoming[2],
  ]);
  const repaired = await stored(page);
  await page.reload();
  await expectSchedule(page, repaired);
});
