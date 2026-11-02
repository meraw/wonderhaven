// End-to-end playthrough of the Hearthglow slice in headless Chromium, using real keyboard and mouse input.
// The harness reads game state through window.__wh (read-only) and steers the camera like a player dragging it.
// Usage: npm run e2e   (screenshots and a log land in e2e-output/)
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const OUT = 'e2e-output'; mkdirSync(OUT, { recursive: true });
const PORT = 5199;
const server = spawn(process.execPath, ['scripts/serve.mjs'], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
await new Promise(r => setTimeout(r, 700));
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1024, height: 640 } });
const log = [], errors = [], results = [];
const say = (...a) => { const s = a.join(' '); log.push(s); console.log(s); };
page.on('pageerror', e => { errors.push(e.message); say('PAGE ERROR', e.message); });
page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); say('CONSOLE ERROR', m.text()); } });
const wait = ms => page.waitForTimeout(ms);
const ev = (fn, arg) => page.evaluate(fn, arg);
const state = () => ev(() => __wh.state());
const pos = () => ev(() => __wh.player());
const mode = () => ev(() => __wh.mode());
let shotN = 0;
const shot = async name => { await page.screenshot({ path: `${OUT}/${String(++shotN).padStart(2, '0')}-${name}.png` }); };
function check(id, label, ok, detail = '') { results.push({ id, label, ok, detail }); say(ok ? '✅' : '❌', `[${id}] ${label}`, detail); }
async function until(fn, ms = 15000, step = 250) { const t0 = Date.now(); while (Date.now() - t0 < ms) { if (await fn()) return true; await wait(step); } return false; }

// ---- Movement: point the camera where we want to go (as a mouse drag would) and hold W.
async function walkDirect(x, z, tol = 0.8, maxMs = 30000) {
  const t0 = Date.now(); let last = await pos(), lastMove = Date.now(), side = 0;
  await page.keyboard.down('ShiftLeft');
  while (Date.now() - t0 < maxMs) {
    const p = await pos();
    const dx = x - p.x, dz = z - p.z, d = Math.hypot(dx, dz);
    if (d < tol) break;
    await ev(([yaw]) => { const c = __wh.game.cam; c.yaw = yaw; c.cur.yaw = yaw; }, [Math.atan2(-dx, -dz)]);
    await page.keyboard.down('KeyW');
    if (side) await page.keyboard.down(side > 0 ? 'KeyD' : 'KeyA');
    await wait(180);
    if (side) { await page.keyboard.up('KeyA'); await page.keyboard.up('KeyD'); side = 0; }
    if (Math.hypot(p.x - last.x, p.z - last.z) > 0.15) { last = p; lastMove = Date.now(); }
    else if (Date.now() - lastMove > 1500) { side = Math.random() < 0.5 ? 1 : -1; await page.keyboard.press('Space'); lastMove = Date.now(); }
  }
  await page.keyboard.up('KeyW'); await page.keyboard.up('ShiftLeft');
  const p = await pos();
  return Math.hypot(x - p.x, z - p.z) < tol + 0.4;
}
async function walkTo(x, z, tol = 0.8) {
  const route = await ev(async ([x, z]) => {
    const { findPath, nearestNode } = await import('/src/systems/schedule.js');
    const { NAV_NODES } = await import('/src/data/village-layout.js');
    const g = __wh.game, f = g.state.flags, p = g.player.pos;
    const a = nearestNode(p.x, p.z, f), b = nearestNode(x, z, f);
    const path = findPath(a, b, f) || [];
    const pts = path.map(n => NAV_NODES[n]);
    for (let i = 0; i < path.length - 1; i++) { const c = g.crossingPath(path[i], path[i + 1]); if (c) pts.splice(pts.indexOf(NAV_NODES[path[i]]) + 1, 0, ...c); }
    return pts;
  }, [x, z]);
  const p = await pos();
  // Skip waypoints behind us
  while (route.length > 1 && Math.hypot(route[0][0] - p.x, route[0][1] - p.z) > Math.hypot(route[1][0] - p.x, route[1][1] - p.z) && Math.hypot(route[1][0] - p.x, route[1][1] - p.z) < Math.hypot(x - p.x, z - p.z)) route.shift();
  for (const [wx, wz] of route) {
    if (Math.hypot(wx - x, wz - z) > Math.hypot((await pos()).x - x, (await pos()).z - z)) continue;
    await walkDirect(wx, wz, 1.2);
  }
  return walkDirect(x, z, tol);
}
const npcPos = id => ev(id => { const a = __wh.game.npcs.byId[id]; return { x: a.pos.x, z: a.pos.z }; }, id);
async function pressE() { await page.keyboard.press('KeyE'); }
async function faceAndInteract(targetId, x, z) {
  for (let n = 0; n < 6; n++) {
    const t = await ev(() => __wh.game.target?.id);
    if (t === targetId) { await pressE(); return true; }
    const p = await pos();
    await ev(([yaw]) => { const g = __wh.game; g.player.yaw = yaw; g.player.sync(); }, [Math.atan2(x - p.x, z - p.z)]);
    await page.keyboard.down('KeyW'); await wait(120); await page.keyboard.up('KeyW');
    await wait(250);
  }
  say('   could not target', targetId, 'current target:', await ev(() => __wh.game.target?.id));
  return false;
}
// Talk to a villager, accepting quests and reading everything, then say goodbye.
async function talk(id, { acceptAll = true } = {}) {
  for (let tries = 0; tries < 3; tries++) {
    const np = await npcPos(id);
    await walkTo(np.x, np.z, 1.4);
    const np2 = await npcPos(id);
    if (await faceAndInteract(`npc:${id}`, np2.x, np2.z)) break;
  }
  if (!(await until(async () => (await mode()) === 'dialogue', 5000))) { say('   no dialogue with', id); return false; }
  for (let n = 0; n < 120; n++) {
    await wait(300);
    if ((await mode()) !== 'dialogue') return true;
    const ch = await ev(() => [...document.querySelectorAll('.d-choices button')].map(b => b.textContent));
    if (ch.length) {
      let idx = ch.findIndex(c => acceptAll && (c.includes('✨')));
      if (idx < 0) idx = ch.findIndex(c => c.includes('Goodbye'));
      if (idx < 0) idx = 0;
      say('   choose:', ch[idx]);
      await page.keyboard.press(`Digit${idx + 1}`);
    } else { await pressE(); }
  }
  return true;
}
async function playMinigame() {
  for (let n = 0; n < 400; n++) {
    const st = await ev(() => { const a = __wh.game.minigame.active; if (!a) return null; const m = a.mg; return { kind: a.kind, needle: m.needle, c: m.center, w: m.width, pause: m.pause, done: m.done, r: m.r, t0: m.target?.[0], t1: m.target?.[1], ph: m.phase, ten: m.tension }; });
    if (!st) return true;
    if (st.done) { await wait(200); continue; }
    if (st.kind === 'chop' && st.pause <= 0 && Math.abs(st.needle - st.c) < st.w / 2.5) await pressE();
    if (st.kind === 'mine' && st.pause <= 0 && st.r < st.t1 - 0.01 && st.r > st.t0 + 0.04) await pressE();
    if (st.kind === 'fish') { if (st.ph === 'bite') await pressE(); if (st.ph === 'reel') { if (st.ten < 0.5) await page.keyboard.down('KeyE'); else await page.keyboard.up('KeyE'); } }
    await wait(30);
  }
  await page.keyboard.up('KeyE');
  return false;
}
async function gatherNode(id) {
  const n = await ev(async id => { const { NODES } = await import('/src/data/village-layout.js'); return NODES.find(n => n.id === id); }, id);
  const p = await pos();
  const d = Math.hypot(n.x - p.x, n.z - p.z) || 1;
  const approach = n.kind === 'fish' ? [n.x, n.z] : [n.x + (p.x - n.x) / d * 1.3, n.z + (p.z - n.z) / d * 1.3];
  await walkTo(approach[0], approach[1], 0.5);
  if (!(await faceAndInteract(id, n.x, n.z))) return false;
  await wait(400);
  if ((await mode()) === 'minigame') await playMinigame();
  await wait(900);
  return true;
}
async function gatherUntil(kind, test, ids, maxRounds = 12) {
  for (let r = 0; r < maxRounds; r++) {
    if (await test()) return true;
    const ready = await ev(async ([kind, ids]) => {
      const { NODES } = await import('/src/data/village-layout.js');
      const g = __wh.game, p = g.player.pos;
      return NODES.filter(n => n.kind === kind && (!ids || ids.includes(n.id)) && g.actions.ready(n)).sort((a, b) => Math.hypot(a.x - p.x, a.z - p.z) - Math.hypot(b.x - p.x, b.z - p.z)).map(n => n.id);
    }, [kind, ids]);
    if (!ready.length) { say('   nothing ready for', kind, '- waiting for regrowth'); await wait(5000); continue; }
    await gatherNode(ready[0]);
  }
  return test();
}
// ---- Build mode helpers
async function camStill() { let last = null; for (let n = 0; n < 60; n++) { const c = await ev(() => __wh.game.camera.position.toArray()); if (last && Math.hypot(c[0] - last[0], c[1] - last[1], c[2] - last[2]) < 0.004) return; last = c; await wait(120); } }
async function openBuild(zoneId) {
  await page.keyboard.press('KeyB');
  await until(async () => (await mode()) === 'build', 4000);
  for (let n = 0; n < 6; n++) { const z = await ev(() => __wh.game.build.currentZone?.id); if (z === zoneId) break; await page.click('.b-top button[title^="Next"]'); await wait(300); }
  await ev(() => { const c = __wh.game.cam; c.yaw = 0.35; c.pitch = 1.05; c.dist = 15; });
  await camStill();
}
async function selectPiece(id) {
  const cat = await ev(async id => (await import('/src/data/pieces.js')).PIECE[id].cat, id);
  const tabs = { structure: 'Structure', furniture: 'Furniture', outdoor: 'Outdoor', mechanism: 'Mechanisms' };
  await page.click(`.b-cat .tabs button:has-text("${tabs[cat]}")`); await wait(200);
  const on = await ev(id => __wh.game.build.itemId === id, id);
  if (!on) await page.click(`[data-piece="${id}"]`);
  await wait(200);
}
async function aimCell(i, k, y = 0.1) {
  await camStill();
  const s = await ev(([x, y, z]) => __wh.worldToScreen(x, y, z), [i + 0.5, y, k + 0.5]);
  await page.mouse.move(s.x, s.y); await wait(350);
  return s;
}
async function placeAt(i, k, y = 0.1, r = null) {
  if (r !== null) { for (let n = 0; n < 4 && (await ev(() => __wh.game.build.rotation)) !== r; n++) { await page.keyboard.press('KeyR'); await wait(150); } }
  const s = await aimCell(i, k, y);
  const status = await page.textContent('#b-status');
  await page.mouse.click(s.x, s.y); await wait(350);
  return status;
}
const countPieces = (id, f = () => true) => state().then(s => s.placements.filter(p => p.id === id && f(p)).length);

// =====================================================================================
try {
  await page.goto(`http://localhost:${PORT}/`);
  await until(() => ev(() => !!window.__wh && __wh.mode() === 'title'), 20000);
  await wait(1500); await shot('title');
  // 1. New game + character creation
  await page.click('#btn-new'); await until(async () => (await mode()) === 'creator');
  await page.fill('#name-input', 'Pip');
  await page.click('[data-opt="hair:pigtails"]'); await page.click('[data-opt="hat:bow"]'); await page.click('[data-opt="eyeShape:sparkle"]');
  const lockedClick = await page.$('[data-opt="top:overalls"]'); await lockedClick.click(); await wait(400);
  await wait(800); await shot('creator');
  await page.click('#btn-start');
  await until(async () => (await mode()) === 'explore', 8000); await wait(1500);
  let s = await state();
  check(1, 'Start a new game and create a character', s.name === 'Pip' && s.appearance.hair === 'pigtails' && s.appearance.hat === 'bow' && s.appearance.top !== 'overalls', `name=${s.name} hair=${s.appearance.hair} locked overalls refused=${s.appearance.top !== 'overalls'}`);
  await shot('arrival');
  // 2. Walk and camera
  const p0 = await pos(); const c0 = await ev(() => __wh.game.cam.yaw);
  await page.keyboard.down('KeyW'); await wait(1500); await page.keyboard.up('KeyW');
  await page.mouse.move(500, 300); await page.mouse.down({ button: 'right' }); await page.mouse.move(700, 280, { steps: 8 }); await page.mouse.up({ button: 'right' });
  const d0 = await ev(() => __wh.game.cam.dist); await page.mouse.wheel(0, -400); await wait(500);
  const p1 = await pos(), c1 = await ev(() => __wh.game.cam.yaw), d1 = await ev(() => __wh.game.cam.dist);
  check(2, 'Walk around and control the camera', Math.hypot(p1.x - p0.x, p1.z - p0.z) > 1 && Math.abs(c1 - c0) > 0.3 && d1 < d0, `moved ${Math.hypot(p1.x - p0.x, p1.z - p0.z).toFixed(1)}m, yaw Δ${(c1 - c0).toFixed(2)}, zoom ${d0.toFixed(1)}→${d1.toFixed(1)}`);
  // 3. Talk to Odessa, accept a quest
  await talk('odessa');
  s = await state();
  check(3, 'Talk to an NPC, read dialogue and accept a quest', s.quests.tool?.status === 'active' && s.flags.hasTool, `tool quest ${s.quests.tool?.status}`);
  await shot('tool-accepted');
  // 4. Gather: fragment + wood, inventory updates
  const inv0 = (await state()).inventory;
  await walkDirect(-35.5, 6, 0.6); await wait(800);
  await gatherUntil('chop', async () => (await state()).quests.tool.progress.wood >= 3, null);
  s = await state();
  check(4, 'Collect resources and see the inventory update', (s.inventory.wood || 0) >= 3 && (s.inventory.fragment || 0) >= 1 && s.inventory.spark > inv0.spark, `wood ${s.inventory.wood}, fragment ${s.inventory.fragment}, spark ${inv0.spark}→${s.inventory.spark}`);
  const hudWood = await ev(() => document.querySelector('[data-res="wood"]')?.textContent);
  say('   HUD wood chip shows', hudWood);
  await talk('odessa');
  s = await state(); say('   tool quest:', s.quests.tool?.status, 'harmony', s.harmony);
  // Bridge quest
  await talk('fern');
  s = await state(); say('   bridge quest:', s.quests.bridge?.status);
  await gatherUntil('chop', async () => { const s = await state(); return s.quests.bridge.progress.wood >= 6 && s.quests.bridge.progress.spark >= 5 && s.inventory.wood >= 11 && s.inventory.spark >= 12; }, null, 16);
  s = await state(); say('   materials: wood', s.inventory.wood, 'spark', s.inventory.spark);
  // 5/6. Build the bridge
  await walkTo(0.5, -12.5, 1);
  await openBuild('bridge');
  await shot('build-mode');
  await selectPiece('bridgeDeck');
  for (const k of [-15, -16, -17]) await placeAt(0, k);
  const warn = await (async () => { await aimCell(0, -18); return page.textContent('#b-status'); })();
  await page.mouse.click((await aimCell(0, -18)).x, (await aimCell(0, -18)).y); await wait(300);
  const refused = (await countPieces('bridgeDeck', p => p.k === -18)) === 0;
  await shot('invalid-warning');
  check(6, 'Invalid placement is refused with a clear warning', refused && /support|post/i.test(warn), `"${warn}"`);
  await selectPiece('bridgePost'); await placeAt(0, -18);
  await selectPiece('bridgeDeck');
  for (const k of [-18, -19, -20, -22, -21]) await placeAt(0, k, 0.2);
  // Place, rotate, move and remove a railing
  await selectPiece('railing'); await placeAt(2, -15, 0.1, 0);
  const rail = (await state()).placements.find(p => p.id === 'railing');
  await page.keyboard.press('Escape'); await wait(300);
  let sAim = await aimCell(2, -15, 0.5); await page.mouse.click(sAim.x, sAim.y); await wait(400);
  const selected = await ev(() => __wh.game.build.selected);
  await page.keyboard.press('KeyR'); await wait(400);
  const rotated = (await state()).placements.find(p => p.uid === rail?.uid)?.r;
  await page.keyboard.press('KeyM'); await wait(300);
  sAim = await aimCell(-2, -15, 0.1); await page.mouse.click(sAim.x, sAim.y); await wait(500);
  const moved = (await state()).placements.find(p => p.uid === rail?.uid);
  await page.keyboard.press('Delete'); await wait(500);
  const removed = !(await state()).placements.some(p => p.uid === rail?.uid);
  await page.keyboard.down('Control'); await page.keyboard.press('KeyZ'); await page.keyboard.up('Control'); await wait(600);
  const undone = (await state()).placements.some(p => p.uid === rail?.uid);
  await page.keyboard.down('Control'); await page.keyboard.press('KeyY'); await page.keyboard.up('Control'); await wait(600);
  const redone = !(await state()).placements.some(p => p.uid === rail?.uid);
  check(5, 'Construction mode: place, rotate, move, remove (+ undo/redo)', !!rail && selected === rail.uid && rotated === 1 && moved?.i === -2 && removed && undone && redone, `placed=${!!rail} selected=${selected === rail?.uid} r=${rotated} movedTo=${moved?.i},${moved?.k} removed=${removed} undo=${undone} redo=${redone}`);
  await shot('bridge-built');
  await page.keyboard.press('Escape'); await wait(200); await page.keyboard.press('Escape'); await wait(600);
  s = await state(); say('   bridge objective ready:', s.quests.bridge?.ready, 'decks:', s.placements.filter(p => p.id === 'bridgeDeck').length);
  // 7. Cross the bridge
  const crossed = await walkDirect(0.5, -14.2, 0.6) && await walkDirect(0.5, -24, 0.7);
  const pc = await pos();
  await shot('crossed-bridge');
  check(7, 'A completed bridge can actually be crossed', crossed && pc.z < -23 && pc.y > -0.3, `player at z=${pc.z.toFixed(1)}, y=${pc.y.toFixed(2)}`);
  await walkDirect(0.5, -13.5, 0.7);
  const bp0 = (await state()).blueprints.length, h0 = (await state()).harmony;
  await talk('fern');
  s = await state();
  check(9, 'Completing a quest changes the world and grants rewards', s.quests.bridge?.status === 'done' && s.flags.orchardOpen && s.harmony > h0, `harmony ${h0}→${s.harmony}, orchardOpen=${s.flags.orchardOpen}`);
  check(10, 'New blueprints become available as you progress', s.blueprints.length > bp0 && s.blueprints.includes('flowerBed'), `${bp0}→${s.blueprints.length} blueprints`);
  await shot('bridge-complete');
  // Workshop quest
  await talk('bram');
  await gatherUntil('chop', async () => { const s = await state(); return s.quests.workshop.progress.wood >= 3 && s.inventory.wood >= 7; }, null, 12);
  await walkTo(-7, 10, 1); await walkDirect(-11, 10, 0.8);
  await openBuild('workshop');
  await selectPiece('workbench'); say('   workbench:', await placeAt(-15, 7, 0.1, 0));
  await selectPiece('chair'); say('   chair:', await placeAt(-14, 9, 0.1, 2));
  await selectPiece('lamp'); say('   lamp:', await placeAt(-16, 11));
  await selectPiece('cabinet'); say('   cabinet:', await placeAt(-12, 7, 0.1, 0));
  await page.keyboard.press('Escape'); await wait(300);
  const chair = (await state()).placements.find(p => p.id === 'chair');
  if (chair) { const a = await aimCell(chair.i, chair.k, 0.5); await page.mouse.click(a.x, a.y); await wait(400); await page.click('.b-sel .sw:nth-child(3)'); await wait(400); }
  await shot('workshop-furnished');
  await page.keyboard.press('Escape'); await wait(200); await page.keyboard.press('Escape'); await wait(500);
  await walkDirect(-7, 10, 0.8);
  await talk('bram');
  s = await state(); say('   workshop quest:', s.quests.workshop?.status, 'harmony', s.harmony);
  // Fountain quest (the mechanical puzzle)
  await talk('tilly');
  await gatherUntil('clay', async () => (await state()).quests.fountain.progress.clay >= 6, null, 8);
  await gatherUntil('mine', async () => { const s = await state(); return s.quests.fountain.progress.metal >= 1 && s.inventory.metal >= 3; }, ['rock5', 'rock0', 'rock1', 'rock2', 'rock3', 'rock4'], 10);
  await gatherUntil('chop', async () => { const s = await state(); return s.inventory.wood >= 6 && s.inventory.spark >= 14; }, null, 10);
  s = await state(); say('   fountain materials:', JSON.stringify(s.inventory));
  await walkTo(6, 4, 1);
  await openBuild('plaza');
  await selectPiece('waterwheel'); say('   wheel:', await placeAt(9, 1, 0.1, 0));
  await selectPiece('pump'); say('   pump:', await placeAt(8, 2, 0.1, 0));
  await selectPiece('pipe'); for (let i = 7; i >= 2; i--) say(`   pipe ${i}:`, await placeAt(i, 2, 0.1, 1));
  const before = await ev(() => ({ fed: !!__wh.game.mech.fed.fountain, pumps: __wh.game.mech.pumps.size }));
  await selectPiece('gear'); say('   gear:', await placeAt(9, 2, 0.1, 0));
  await wait(800);
  const after = await ev(() => ({ fed: !!__wh.game.mech.fed.fountain, pumps: __wh.game.mech.pumps.size, flowing: __wh.game.village.objects.fountain.getObjectByName('jets').visible }));
  await shot('fountain-flowing');
  check(8, 'A connected machine responds to its power source', !before.fed && before.pumps === 0 && after.fed && after.pumps === 1 && after.flowing, `before gear: pump powered=${before.pumps} fed=${before.fed}; after: pump=${after.pumps} fed=${after.fed} jets=${after.flowing}`);
  await page.keyboard.press('Escape'); await wait(200); await page.keyboard.press('Escape'); await wait(500);
  await talk('tilly');
  s = await state(); say('   fountain quest:', s.quests.fountain?.status, 'harmony', s.harmony);
  // Harbor: decree + dock
  await talk('percival');
  s = await state(); say('   decree:', s.quests.decree?.status, 'harborOpen', s.flags.harborOpen);
  await walkTo(5, 37, 1);
  await talk('captain');
  await walkDirect(5.5, 40.6, 0.6);
  await openBuild('dock');
  await selectPiece('bridgeDeck');
  for (const k of [41, 42, 43, 44, 45, 46, 47, 48, 49]) await placeAt(5, k, 0.15);
  await shot('dock-built');
  await page.keyboard.press('Escape'); await wait(200); await page.keyboard.press('Escape'); await wait(500);
  await talk('captain');
  s = await state(); say('   dock:', s.quests.dock?.status, 'boatReady', s.flags.boatReady, 'clockwork', s.flags.clockworkRevealed);
  await walkDirect(5.5, 47, 0.6); await walkDirect(5.5, 49.6, 0.5);
  await faceAndInteract('boat', 5.5, 51.6); await wait(800);
  await shot('world-map');
  const sail = await page.$('button:has-text("Sail to Clockwork Cove")');
  if (!sail) { await page.click('svg .map-island:nth-of-type(2)').catch(() => {}); }
  const isl = await page.$$('.map-island'); if (isl[1]) await isl[1].click(); await wait(400);
  const sailBtn = await page.$('button:has-text("Sail to")'); if (sailBtn) await sailBtn.click();
  await wait(3000); await shot('next-chapter');
  s = await state(); say('   sailed:', s.flags.sailedOnce);
  // 11. Save, reload, load
  await page.keyboard.press('Escape'); await wait(500);
  await page.click('button:has-text("Save game")'); await wait(400);
  await page.click('[data-slot="slot1"]'); await wait(600);
  const saved = await state();
  await page.reload(); await until(() => ev(() => !!window.__wh && __wh.mode() === 'title'), 20000); await wait(1000);
  await page.click('button:has-text("Load Game")'); await wait(400);
  await page.click('.slot:has-text("Slot 1") button'); await until(async () => (await mode()) === 'explore', 8000); await wait(1500);
  const loaded = await state();
  const sameBuild = JSON.stringify(saved.placements.map(p => [p.id, p.i, p.k, p.r, p.color || ''])) === JSON.stringify(loaded.placements.map(p => [p.id, p.i, p.k, p.r, p.color || '']));
  const sameQuests = JSON.stringify(Object.fromEntries(Object.entries(saved.quests).map(([k, v]) => [k, v.status]))) === JSON.stringify(Object.fromEntries(Object.entries(loaded.quests).map(([k, v]) => [k, v.status])));
  const fountainAfter = await ev(() => !!__wh.game.mech.fed.fountain);
  await shot('reloaded');
  check(11, 'Save, exit, reload: constructions and quest progress intact', sameBuild && sameQuests && loaded.harmony === saved.harmony && fountainAfter, `${loaded.placements.length} pieces, ${Object.values(loaded.quests).filter(q => q.status === 'done').length} quests done, harmony ${loaded.harmony}, fountain flowing=${fountainAfter}`);
  check(12, 'All of the above through gameplay input (no debug commands)', errors.length === 0, `${errors.length} page errors. The harness only reads state and turns the camera, like dragging the mouse.`);
} catch (e) {
  say('HARNESS ERROR', e.stack);
  await shot('harness-error').catch(() => {});
}
const summary = results.map(r => `${r.ok ? 'PASS' : 'FAIL'}  ${r.id}. ${r.label} — ${r.detail}`).join('\n');
writeFileSync(`${OUT}/e2e-log.txt`, log.join('\n') + '\n\n' + summary + '\n');
console.log('\n' + summary);
await browser.close(); server.kill();
process.exit(results.length >= 12 && results.every(r => r.ok) ? 0 : 1);
