import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';

const BASE_URL = 'http://127.0.0.1:8080';
const OUTPUT_DIR = '/home/cloudyi/code/aigateway-group/output/playwright/console-smoke';
const ROUTES = [
  { path: '/dashboard', name: 'dashboard' },
  { path: '/service-source', name: 'service-source' },
  { path: '/service', name: 'service' },
  { path: '/route', name: 'route' },
  { path: '/domain', name: 'domain' },
  { path: '/tls-certificate', name: 'tls-certificate' },
  { path: '/consumer', name: 'consumer' },
  { path: '/plugin', name: 'plugin' },
  { path: '/system', name: 'system' },
  { path: '/user/changePassword', name: 'change-password' },
  { path: '/ai/provider', name: 'ai-provider' },
  { path: '/ai/model-assets', name: 'ai-model-assets' },
  { path: '/ai/agent-catalog', name: 'ai-agent-catalog' },
  { path: '/ai/route', name: 'ai-route' },
  { path: '/ai/quota', name: 'ai-quota' },
  { path: '/ai/sensitive', name: 'ai-sensitive' },
  { path: '/ai/dashboard', name: 'ai-dashboard' },
  { path: '/mcp/list', name: 'mcp-list' },
];

const SAFE_BUTTON_RE = /(new|create|add|detail|details|view|edit|config|configure|preview|import|export|download|upload|test|debug|sync|refresh|search|filter|模板|新建|新增|创建|详情|查看|编辑|配置|导入|导出|下载|上传|测试|调试|同步|刷新|搜索|筛选)/i;
const BLOCK_BUTTON_RE = /(delete|remove|destroy|submit|save|confirm|publish|unpublish|reset|restore|logout|log out|登录|退出|删除|移除|销毁|提交|保存|确认|发布|下线|重置|恢复)/i;
const CLOSE_BUTTON_RE = /^(cancel|close|返回|取消|关闭)$/i;

function installPlaywright() {
  const tmp = fsSyncMkdir();
  execSync('npm init -y >/dev/null 2>&1', { cwd: tmp, stdio: 'ignore' });
  execSync('npm install playwright@1.55.0 >/dev/null 2>&1', { cwd: tmp, stdio: 'ignore' });
  const require = createRequire(import.meta.url);
  return require(path.join(tmp, 'node_modules/playwright'));
}

function fsSyncMkdir() {
  return execSync('mktemp -d', { encoding: 'utf8' }).trim();
}

function cleanText(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function unique(items) {
  return [...new Set(items.filter(Boolean))];
}

async function ensureOutput() {
  await fs.mkdir(OUTPUT_DIR, { recursive: true });
}

async function waitForPageSettled(page, timeout = 6000) {
  await Promise.race([
    page.waitForLoadState('networkidle', { timeout }).catch(() => null),
    page.waitForTimeout(1200),
  ]);
  await page.waitForTimeout(800);
}

async function closeTransientUi(page) {
  const closeButtons = page.getByRole('button').filter({ hasText: CLOSE_BUTTON_RE });
  if (await closeButtons.count()) {
    await closeButtons.first().click({ timeout: 1500 }).catch(() => null);
    await page.waitForTimeout(400);
  }
  await page.keyboard.press('Escape').catch(() => null);
  await page.waitForTimeout(200);
}

async function collectSummary(page) {
  const title = await page.title();
  const bodyText = cleanText(await page.locator('body').innerText().catch(() => ''));
  const headings = unique(await page.locator('h1, h2, h3, .page-section__title, .ant-page-header-heading-title').evaluateAll((nodes) =>
    nodes.map((node) => (node.textContent || '').trim()),
  ).catch(() => []));
  const buttons = unique(await page.getByRole('button').evaluateAll((nodes) =>
    nodes.map((node) => (node.innerText || '').trim()),
  ).catch(() => []));
  const tabs = unique(await page.getByRole('tab').evaluateAll((nodes) =>
    nodes.map((node) => (node.textContent || '').trim()),
  ).catch(() => []));
  return {
    title,
    bodySnippet: bodyText.slice(0, 800),
    headings,
    buttons,
    tabs,
  };
}

async function clickTabs(page, routeResult) {
  const tabs = page.getByRole('tab');
  const count = Math.min(await tabs.count(), 6);
  for (let i = 0; i < count; i += 1) {
    const tab = tabs.nth(i);
    const label = cleanText(await tab.innerText().catch(() => `tab-${i}`));
    if (!label) continue;
    let ok = true;
    let errorMessage = '';
    await tab.click({ timeout: 2000 }).catch((error) => {
      ok = false;
      errorMessage = error.message;
    });
    if (!ok) {
      routeResult.interactions.push({ type: 'tab', label, ok: false, error: errorMessage });
      continue;
    }
    await waitForPageSettled(page, 2500);
    routeResult.interactions.push({ type: 'tab', label, ok: true, url: page.url() });
  }
}

async function clickSafeButtons(page, routeResult) {
  const buttons = page.locator('main.app-shell__content button');
  const count = await buttons.count();
  const seen = new Set();
  let clicked = 0;

  for (let i = 0; i < count && clicked < 4; i += 1) {
    const button = buttons.nth(i);
    const visible = await button.isVisible().catch(() => false);
    if (!visible) {
      continue;
    }
    const label = cleanText(await button.innerText().catch(() => ''));
    if (!label || seen.has(label) || !SAFE_BUTTON_RE.test(label) || BLOCK_BUTTON_RE.test(label)) {
      continue;
    }
    seen.add(label);
    const disabled = await button.isDisabled().catch(() => true);
    if (disabled) {
      routeResult.interactions.push({ type: 'button', label, ok: false, error: 'disabled' });
      continue;
    }
    const beforeUrl = page.url();
    const beforeDialogs = await page.locator('.ant-modal-root:visible, .ant-drawer:visible').count().catch(() => 0);
    try {
      await button.click({ timeout: 2500 });
      await waitForPageSettled(page, 3000);
      const afterUrl = page.url();
      const afterDialogs = await page.locator('.ant-modal-root:visible, .ant-drawer:visible').count().catch(() => 0);
      routeResult.interactions.push({
        type: 'button',
        label,
        ok: true,
        routeChanged: afterUrl !== beforeUrl,
        dialogOpened: afterDialogs > beforeDialogs,
        url: afterUrl,
      });
      await closeTransientUi(page);
      clicked += 1;
    } catch (error) {
      routeResult.interactions.push({ type: 'button', label, ok: false, error: error.message });
    }
  }
}

async function inspectRoute(page, route) {
  const routeResult = {
    path: route.path,
    name: route.name,
    url: '',
    summary: {},
    interactions: [],
    consoleErrors: [],
    requestIssues: [],
    pageErrors: [],
    screenshot: '',
    status: 'ok',
  };

  const consoleErrors = [];
  const requestIssues = [];
  const pageErrors = [];
  const onConsole = (msg) => {
    if (['error', 'warning'].includes(msg.type())) {
      consoleErrors.push(`${msg.type()}: ${msg.text()}`);
    }
  };
  const onResponse = (response) => {
    if (response.status() >= 400) {
      requestIssues.push(`${response.status()} ${response.request().method()} ${response.url()}`);
    }
  };
  const onRequestFailed = (request) => {
    requestIssues.push(`FAILED ${request.method()} ${request.url()} ${request.failure()?.errorText || 'unknown error'}`);
  };
  const onPageError = (error) => {
    pageErrors.push(error.message);
  };

  page.on('console', onConsole);
  page.on('response', onResponse);
  page.on('requestfailed', onRequestFailed);
  page.on('pageerror', onPageError);

  try {
    await page.goto(`${BASE_URL}${route.path}`, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await waitForPageSettled(page);
    routeResult.url = page.url();
    routeResult.summary = await collectSummary(page);
    await clickTabs(page, routeResult);
    await clickSafeButtons(page, routeResult);
    routeResult.summary = await collectSummary(page);
    routeResult.screenshot = path.join(OUTPUT_DIR, `${route.name}.png`);
    await page.screenshot({ path: routeResult.screenshot, fullPage: true });
  } catch (error) {
    routeResult.status = 'error';
    routeResult.interactions.push({ type: 'route', label: route.path, ok: false, error: error.message });
  } finally {
    page.removeListener('console', onConsole);
    page.removeListener('response', onResponse);
    page.removeListener('requestfailed', onRequestFailed);
    page.removeListener('pageerror', onPageError);
  }

  routeResult.consoleErrors = unique(consoleErrors).slice(0, 20);
  routeResult.requestIssues = unique(requestIssues).slice(0, 30);
  routeResult.pageErrors = unique(pageErrors).slice(0, 20);
  if (routeResult.requestIssues.length || routeResult.pageErrors.length) {
    routeResult.status = routeResult.status === 'error' ? 'error' : 'issues';
  }
  return routeResult;
}

async function login(page) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.getByPlaceholder('Username').fill('admin');
  await page.getByPlaceholder('Password').fill('admin');
  await page.getByRole('button', { name: 'Login' }).click();
  await page.waitForURL(/dashboard|init/, { timeout: 15000 });
  await waitForPageSettled(page);
}

async function main() {
  await ensureOutput();
  const { chromium } = installPlaywright();
  const browser = await chromium.launch({
    headless: true,
    executablePath: '/usr/bin/google-chrome',
    args: ['--no-sandbox'],
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
    locale: 'en-US',
  });
  const page = await context.newPage();

  const result = {
    startedAt: new Date().toISOString(),
    baseUrl: BASE_URL,
    routes: [],
  };

  try {
    await login(page);
    await page.close();
    for (const route of ROUTES) {
      console.log(`[route] ${route.path}`);
      const routePage = await context.newPage();
      try {
        result.routes.push(await inspectRoute(routePage, route));
      } finally {
        await routePage.close().catch(() => null);
      }
    }
  } finally {
    await browser.close();
  }

  const summary = {
    total: result.routes.length,
    errors: result.routes.filter((item) => item.status === 'error').length,
    issues: result.routes.filter((item) => item.status === 'issues').length,
    ok: result.routes.filter((item) => item.status === 'ok').length,
  };
  result.summary = summary;
  result.finishedAt = new Date().toISOString();

  await fs.writeFile(path.join(OUTPUT_DIR, 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
