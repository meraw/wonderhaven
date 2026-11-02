// Quick screenshot helper: node scripts/shot.mjs out.png [waitMs] [script-js]
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const out = process.argv[2] || 'shot.png', wait = Number(process.argv[3] || 4000), js = process.argv[4] || '';
const server = spawn(process.execPath, ['scripts/serve.mjs'], { env: { ...process.env, PORT: '5191' }, stdio: 'ignore' });
await new Promise(r => setTimeout(r, 600));
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 760 } });
const logs = [];
page.on('console', m => logs.push(`${m.type()}: ${m.text()}`));
page.on('pageerror', e => logs.push(`pageerror: ${e.message}`));
await page.goto('http://localhost:5191/');
await page.waitForTimeout(wait);
if (js) { console.log(await page.evaluate(js)); await page.waitForTimeout(1500); }
await page.screenshot({ path: out });
console.log(logs.slice(0, 30).join('\n'));
await browser.close(); server.kill();
