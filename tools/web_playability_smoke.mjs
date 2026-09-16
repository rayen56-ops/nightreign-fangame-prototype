import { chromium, firefox } from 'playwright';

for (const [name, browserType] of [['chromium', chromium], ['firefox', firefox]]) {
  const browser = await browserType.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const fatals = [];
  const failed = [];
  const consoleLines = [];

  page.on('console', m => {
    const t = m.text();
    consoleLines.push(`[${m.type()}] ${t}`);
    console.log(`${name} CONSOLE ${m.type()}: ${t}`);
    if (m.type() === 'error' && /SCRIPT ERROR|Parse Error|Compile Error|RuntimeError|WebAssembly.*failed|abort\(/i.test(t)) fatals.push(t);
  });
  page.on('pageerror', e => {
    fatals.push(`PAGEERROR: ${e.message}`);
    console.log(`${name} PAGEERROR: ${e.message}`);
  });
  page.on('requestfailed', r => {
    const line = `${r.url()} :: ${r.failure()?.errorText ?? 'unknown'}`;
    failed.push(line);
    console.log(`${name} REQUESTFAILED: ${line}`);
  });

  await page.goto('http://127.0.0.1:4173/game/?qa=1', { waitUntil: 'domcontentloaded', timeout: 30000 });
  const canvas = page.locator('canvas');
  await canvas.waitFor({ state: 'visible', timeout: 30000 });
  await canvas.click({ position: { x: 100, y: 100 } });

  try {
    await page.waitForFunction(() => window.__nightreignQA?.ready === true, null, { timeout: 15000 });
  } catch (error) {
    const diagnostic = await page.evaluate(() => ({
      url: location.href,
      title: document.title,
      active: document.activeElement ? `${document.activeElement.tagName}#${document.activeElement.id || ''}` : null,
      menuQA: window.__nightreignMenuQA ?? null,
      gameQA: window.__nightreignQA ?? null,
      canvas: (() => {
        const c = document.querySelector('canvas');
        if (!c) return null;
        const r = c.getBoundingClientRect();
        return { width: r.width, height: r.height, internalWidth: c.width, internalHeight: c.height };
      })(),
      text: document.body?.innerText?.slice(0, 1000) ?? '',
    }));
    console.log(name, 'QA_READY_TIMEOUT_DIAGNOSTIC', JSON.stringify(diagnostic));
    console.log(name, 'CONSOLE_TAIL', JSON.stringify(consoleLines.slice(-80)));
    await page.screenshot({ path: `artifacts/web-qa/${name}-qa-ready-timeout.png`, fullPage: true });
    await browser.close();
    throw error;
  }

  const box = await canvas.boundingBox();
  const initial = await page.evaluate(() => ({ ...window.__nightreignQA }));
  console.log(name, 'READY', initial, 'canvas', box);
  if (!box || box.width < 500 || box.height < 280) throw new Error(`${name}: invalid canvas ${JSON.stringify(box)}`);
  if (!initial.player_actor_visible) throw new Error(`${name}: player actor not visible`);
  if (!Array.isArray(initial.walkable) || initial.walkable.length === 0) throw new Error(`${name}: spawn has no legal egress ${JSON.stringify(initial)}`);

  await page.keyboard.press('x');
  await page.waitForFunction(t => window.__nightreignQA?.turn > t, initial.turn, { timeout: 5000 });
  const afterWait = await page.evaluate(() => ({ ...window.__nightreignQA }));
  if (afterWait.turn !== initial.turn + 1) throw new Error(`${name}: wait did not consume exactly one turn`);

  let moved = false;
  for (const key of afterWait.walkable) {
    const before = await page.evaluate(() => ({ ...window.__nightreignQA }));
    await page.keyboard.press(key);
    try {
      await page.waitForFunction(s => {
        const q = window.__nightreignQA;
        return q && (q.x !== s.x || q.y !== s.y);
      }, before, { timeout: 3000 });
      const after = await page.evaluate(() => ({ ...window.__nightreignQA }));
      if (after.turn !== before.turn + 1) throw new Error(`${name}: move did not consume exactly one turn`);
      console.log(name, 'MOVE_OK', key, before, after);
      moved = true;
      break;
    } catch (e) {
      console.log(name, 'MOVE_ATTEMPT_FAILED', key, String(e));
    }
  }

  if (!moved) throw new Error(`${name}: no legal movement changed player position`);
  if (fatals.length) throw new Error(`${name}: fatal console errors ${JSON.stringify(fatals)}`);
  if (failed.some(x => /\.wasm|\.pck/i.test(x))) throw new Error(`${name}: WASM/PCK network failure ${JSON.stringify(failed)}`);
  await page.screenshot({ path: `artifacts/web-qa/${name}-playable.png`, fullPage: true });
  await browser.close();
}

console.log('T0_BROWSER_PLAYABILITY_PASS');
