const { chromium } = require('playwright');

const TARGET_URL = 'http://console.ai.local/ai/route/config?type=aiRoute&name=doubao';
const TOKEN = process.env.CONSOLE_TOKEN;

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });
  await page.addInitScript((token) => {
    window.localStorage.setItem('token', token);
  }, TOKEN);
  await page.goto(TARGET_URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForSelector('table', { timeout: 30000 });
  const rows = await page.locator('tbody tr').evaluateAll((trs) => trs.map((tr) => tr.innerText));
  console.log(JSON.stringify(rows, null, 2));
  const row = rows.find((text) => text.includes('ai-statistics')) || '';
  console.log('ROW>>>', row);
  await page.screenshot({ path: '/tmp/ai-route-doubao-plugin-page.png', fullPage: true });
  await browser.close();
})();
