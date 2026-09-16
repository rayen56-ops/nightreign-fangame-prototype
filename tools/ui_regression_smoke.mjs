import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const fatals = [];
page.on('console', msg => {
  const text = msg.text();
  console.log(`UIQA ${msg.type()}: ${text}`);
  if (msg.type() === 'error' && /SCRIPT ERROR|Parse Error|Compile Error|RuntimeError|abort\(/i.test(text)) fatals.push(text);
});
page.on('pageerror', error => fatals.push(`PAGEERROR: ${error.message}`));

await page.goto('http://127.0.0.1:4173/game/?qa=1', { waitUntil: 'domcontentloaded', timeout: 30000 });
const canvas = page.locator('canvas');
await canvas.waitFor({ state: 'visible', timeout: 30000 });
await canvas.click({ position: { x: 100, y: 100 }, force: true });
await page.waitForFunction(() => window.__nightreignQA?.ready === true, null, { timeout: 30000 });

// Controls must be reachable from the documented ? shortcut.
await page.keyboard.press('Shift+/');
await page.waitForFunction(() => window.__nightreignControlsQA?.visible === true, null, { timeout: 5000 });
await page.screenshot({ path: 'artifacts/web-qa/controls-guide.png', fullPage: true });
await page.keyboard.press('Escape');
await page.waitForFunction(() => window.__nightreignControlsQA?.visible === false, null, { timeout: 5000 });

// F8 is a QA-only hook that opens the same game-over modal used by real deaths.
await page.keyboard.press('F8');
await page.waitForFunction(() => window.__nightreignGameOverQA?.visible === true, null, { timeout: 5000 });
await page.screenshot({ path: 'artifacts/web-qa/game-over-recoverable.png', fullPage: true });

// Enter must retry instead of leaving a dead canvas behind.
await page.evaluate(() => { window.__nightreignQA = null; });
await page.keyboard.press('Enter');
await page.waitForFunction(() => window.__nightreignGameOverQA?.visible === false, null, { timeout: 5000 });
await page.waitForFunction(() => window.__nightreignQA?.ready === true, null, { timeout: 30000 });
const retried = await page.evaluate(() => ({ ...window.__nightreignQA }));
if (!retried.player_actor_visible || retried.turn !== 1) {
  throw new Error(`Retry did not create a fresh playable run: ${JSON.stringify(retried)}`);
}

// Esc must return through the menu path without freezing the Web build.
await page.keyboard.press('F8');
await page.waitForFunction(() => window.__nightreignGameOverQA?.visible === true, null, { timeout: 5000 });
await page.evaluate(() => {
  window.__nightreignMenuQA = null;
  window.__nightreignQA = null;
});
await page.keyboard.press('Escape');
await page.waitForFunction(() => window.__nightreignMenuQA?.ready === true, null, { timeout: 10000 });
await page.waitForFunction(() => window.__nightreignQA?.ready === true, null, { timeout: 30000 });
await page.screenshot({ path: 'artifacts/web-qa/game-over-main-menu-recovery.png', fullPage: true });

if (fatals.length) throw new Error(`Fatal browser errors: ${JSON.stringify(fatals)}`);
console.log('UI_REGRESSION_PASS controls=reachable retry=playable main-menu=playable');
await browser.close();
