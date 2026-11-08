// Renders every icon in icons.cjs in the watercolour-and-pencil style to a 128 px PNG (out/), writes a contact sheet
// (out/sheet.png) to review them, and builds the colour font godot/assets/fonts/WonderhavenIcons.ttf.
//   node tools/icons/render.cjs
// Needs Playwright with Chromium (the watercolour filters need a real browser) and Python 3 with fontTools.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const { P, ICONS } = require('./icons.cjs');

const OUT = path.join(__dirname, 'out');
const FONT = path.join(__dirname, '..', '..', 'godot', 'assets', 'fonts', 'WonderhavenIcons.ttf');
const SIZE = 128;
const PEN = '#4a3a30';
const VIEW = '4 4 56 56';   // the drawings' 64 box minus a margin: icons fill their em like the emoji they replace

// The filters: a wash that bleeds a little past the line, and a pencil line that wobbles. Fixed seeds, so the same
// drawing always renders the same picture.
const DEFS = `<defs>
<filter id="wash" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" seed="2" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="5" xChannelSelector="R" yChannelSelector="G" result="d"/><feGaussianBlur in="d" stdDeviation="0.7"/></filter>
<filter id="pencil" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="2" seed="7" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="1.3" xChannelSelector="R" yChannelSelector="G"/></filter>
</defs>`;

const isShape = p => ['path', 'circle', 'ellipse', 'rect'].includes(p.t);
function shapeEl(p, attrs) {
  const a = Object.entries(attrs).map(([k, v]) => `${k}="${v}"`).join(' ');
  const rule = p.rule ? ` fill-rule="${p.rule}"` : '';
  switch (p.t) {
    case 'circle': return `<circle cx="${p.cx}" cy="${p.cy}" r="${p.r}" ${a}${rule}/>`;
    case 'ellipse': return `<ellipse cx="${p.cx}" cy="${p.cy}" rx="${p.rx}" ry="${p.ry}" ${a}${rule}/>`;
    case 'rect': return `<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" rx="${p.rx || 1.5}" ${a}${rule}/>`;
    default: return `<path d="${p.d}" ${a}${rule}/>`;
  }
}
function colour(key) {
  if (!(key in P)) throw new Error('no palette colour ' + key);
  return P[key];
}
function svgFor(ic) {
  const wash = ic.parts.filter(isShape).map(p => shapeEl(p, { fill: colour(p.f), opacity: .9 })).join('');
  const lines = ic.parts.map(p => {
    const dash = p.dash ? ` stroke-dasharray="${p.dash}"` : '';
    if (isShape(p)) return shapeEl(p, { fill: 'none', stroke: PEN, 'stroke-width': 2.1, 'stroke-linejoin': 'round', opacity: .9 });
    if (p.t === 'line') return `<path d="${p.d}" fill="none" stroke="${PEN}" stroke-width="${(p.w || 2.2) * .85}" stroke-linecap="round" opacity="${(p.o || 1) * .85}"/>`;
    if (p.t === 'wire') return `<path d="${p.d}" fill="none" stroke="${colour(p.c)}" stroke-width="${p.w}" stroke-linecap="round" stroke-linejoin="round" opacity=".88"${dash}/>`;
    if (p.t === 'hl') return `<path d="${p.d}" fill="#fff" opacity=".55"/>`;
    throw new Error('unknown part ' + p.t + ' in ' + ic.name);
  }).join('');
  const body = `<g filter="url(#wash)" transform="translate(1.2 1.4)">${wash}</g><g filter="url(#pencil)">${lines}</g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${VIEW}" width="${SIZE}" height="${SIZE}">${DEFS}${ic.g ? `<g transform="${ic.g}">${body}</g>` : body}</svg>`;
}
const cpOf = e => e.codePointAt(0);

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const seen = new Set();
  for (const ic of ICONS) {
    const cp = cpOf(ic.e);
    if (seen.has(cp)) throw new Error('two drawings for ' + ic.e);
    seen.add(cp);
  }
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE } });
  const args = [];
  for (const ic of ICONS) {
    const file = path.join(OUT, cpOf(ic.e).toString(16).toUpperCase() + '.png');
    await page.setContent(`<html><body style="margin:0;background:transparent">${svgFor(ic)}</body></html>`);
    await page.locator('svg').screenshot({ path: file, omitBackground: true });
    args.push(cpOf(ic.e).toString(16).toUpperCase() + '=' + file);
  }
  // contact sheet on the game's cream panel colour, large and at HUD size
  const cells = ICONS.map(ic => `<div class="c"><div>${svgFor(ic).replace(`width="${SIZE}" height="${SIZE}"`, 'width="64" height="64"')}</div>
    <div class="s">${svgFor(ic).replace(`width="${SIZE}" height="${SIZE}"`, 'width="22" height="22"')} <b>80</b></div><span>${ic.e} ${ic.name}</span></div>`).join('');
  const sheet = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  await sheet.setContent(`<html><body style="margin:0;background:#fff8ec;font:12px sans-serif;color:#5a3d2b">
    <style>.g{display:grid;grid-template-columns:repeat(10,1fr);gap:10px;padding:14px}.c{display:grid;justify-items:center;gap:3px}
    .s{display:flex;align-items:center;gap:3px;background:#fffdf8;border:2px solid #f1dcbb;border-radius:99px;padding:1px 8px 1px 3px;font-weight:700}
    span{font-size:11px;text-align:center}</style><div class="g">${cells}</div></body></html>`);
  await sheet.screenshot({ path: path.join(OUT, 'sheet.png'), fullPage: true });
  await browser.close();
  execFileSync('python3', [path.join(__dirname, 'build_font.py'), FONT, ...args], { stdio: 'inherit' });
})();
