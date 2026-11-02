// Menu panels: bag, quest journal, Kingdom Harmony, world map, notice board, pause, settings, saves, controls.
import { $, el, toast, banner, fade } from './dom.js';
import { RESOURCES, RESOURCE_ORDER } from '../data/resources.js';
import { QUESTS, QUEST } from '../data/quests.js';
import { NPC, NPCS } from '../data/npcs.js';
import { PIECE, PIECES } from '../data/pieces.js';
import { ISLANDS } from '../data/islands.js';
import { HARMONY_UNLOCKS, nextUnlock } from '../data/harmony.js';
import { LABELS, LOCKED_CLOTHES } from '../data/appearance.js';
import { DEFAULT_BINDINGS, ACTION_LABELS, keyLabel, rebind } from '../core/bindings.js';
import { SLOTS, AUTOSAVE, saveMeta } from '../systems/save.js';

export class Panels {
  constructor(game) { this.game = game; this.current = null; }
  get s() { return this.game.state; }
  open(name, title, build) {
    const root = $('panel'); root.innerHTML = '';
    const panel = el('div', { class: 'panel' }, el('h2', {}, title), el('button', { class: 'close small', onclick: () => this.close() }, '✕ Close'));
    const body = el('div'); panel.append(body); root.append(panel);
    build(body);
    root.hidden = false;
    root.onclick = e => { if (e.target === root) this.close(); };
    this.current = name;
    this.game.setMode('menu');
    this.game.sfx('open');
  }
  close() {
    if (!this.current) return;
    $('panel').hidden = true; this.current = null;
    this.game.setMode('explore');
    this.game.sfx('close');
  }
  toggle(name, fn) { if (this.current === name) this.close(); else fn(); }
  update() {
    const input = this.game.input;
    if (!this.current) return;
    if (input.pressed('pause')) { this.close(); return; }
    const map = { inventory: 'inventory', journal: 'journal', map: 'map', progress: 'progress' };
    for (const [action, name] of Object.entries(map)) if (input.pressed(action) && this.current === name) this.close();
  }

  inventory() {
    this.open('inventory', '🎒 Your Bag', body => {
      const grid = el('div', { class: 'grid' });
      for (const id of RESOURCE_ORDER) { const r = RESOURCES[id]; grid.append(el('div', { class: 'item', 'data-res': id }, el('div', { class: 'big' }, r.icon), el('div', { class: 'n' }, String(this.s.inventory[id] || 0)), el('small', {}, r.name))); }
      body.append(grid);
      const bp = this.s.blueprints.length, outfits = Object.keys(LOCKED_CLOTHES).filter(c => this.s.lockedClothesOwned.includes(c)).length;
      body.append(el('h3', {}, 'Collection'), el('div', { class: 'row' },
        el('span', { class: 'reward' }, `📐 ${bp} / ${PIECES.length} blueprints`), el('span', { class: 'reward' }, `👗 ${outfits} / ${Object.keys(LOCKED_CLOTHES).length} special outfits`),
        el('span', { class: 'reward' }, `🐟 ${this.s.stats.fish} fish caught`), el('span', { class: 'reward' }, `💎 ${this.s.stats.treasures} treasures`), el('span', { class: 'reward' }, `🔨 ${this.s.stats.placed} pieces built`)));
      body.append(el('h3', {}, 'Friends'), el('div', { class: 'grid' }, NPCS.filter(n => this.s.relationships[n.id]).map(n => el('div', { class: 'item' }, el('div', {}, n.name), el('small', {}, n.title), el('div', { style: { color: '#ff6f91' } }, '♥'.repeat(this.s.relationships[n.id].hearts) || '♡')))));
    });
  }
  journal(tab = 'active') {
    this.open('journal', '📜 Quest Journal', body => {
      const e = this.game.story.engine;
      const tabs = el('div', { class: 'tabs' });
      const list = el('div');
      const show = t => {
        tab = t; [...tabs.children].forEach(b => b.classList.toggle('on', b.dataset.t === t)); list.innerHTML = '';
        let qs = [];
        if (t === 'active') qs = e.active();
        if (t === 'optional') qs = QUESTS.filter(q => !q.main && e.canOffer(q.id));
        if (t === 'done') qs = e.done();
        if (!qs.length) list.append(el('p', { style: { fontWeight: 700, color: '#8a6a50' } }, t === 'active' ? 'No active quests. Look for villagers with a ! over their heads.' : t === 'optional' ? 'No new side quests right now — keep exploring!' : 'Nothing completed yet. Every journey starts with a single plank.'));
        for (const q of qs) list.append(this.questCard(q, t));
      };
      for (const [t, label] of [['active', 'Active'], ['optional', 'Available side quests'], ['done', 'Completed']]) tabs.append(el('button', { class: 'small', 'data-t': t, onclick: () => show(t) }, label));
      body.append(tabs, list); show(tab);
    });
  }
  questCard(q, t) {
    const e = this.game.story.engine, done = t === 'done';
    const card = el('div', { class: `qcard ${done ? 'done' : ''}` },
      el('div', { class: 'giver' }, `${q.main ? '★ Main story · ' : ''}From ${NPC[q.giver].name}`), el('h4', {}, q.title), el('p', {}, q.description));
    if (t === 'active') {
      const ready = e.isReady(q.id);
      card.append(el('ul', { class: 'track', style: { border: 'none', boxShadow: 'none', padding: 0, background: 'none' } }, el('ul', {}, q.objectives.filter(o => !o.final || ready).map(o => {
        const st = e.objective(q.id, o);
        return el('li', { class: st.done ? 'done' : '' }, `${o.text}${st.need > 1 && !st.done && o.kind !== 'harmony' ? ` (${st.have}/${st.need})` : o.kind === 'harmony' && !st.done ? ` (${this.s.harmony}/${o.value})` : ''}`);
      }))));
      card.append(el('div', { class: 'row', style: { marginTop: '6px' } }, el('button', { class: `small ${this.s.tracked === q.id ? 'primary' : ''}`, onclick: () => { this.s.tracked = q.id; this.game.renderTracker(); this.close(); toast(`Tracking “${q.title}”`); } }, this.s.tracked === q.id ? '📍 Tracking' : '📍 Track')));
    }
    if (t === 'optional') card.append(el('div', { class: 'giver' }, `Talk to ${NPC[q.giver].name} to start.`));
    const r = q.rewards || {};
    card.append(el('div', { class: 'rewards' }, r.harmony ? el('span', { class: 'reward' }, `💖 ${r.harmony}`) : null,
      Object.entries(r.items || {}).map(([k, n]) => el('span', { class: 'reward' }, `${RESOURCES[k].icon} ${n}`)),
      (r.blueprints || []).map(b => el('span', { class: 'reward' }, `📐 ${PIECE[b].name}`)), (r.clothes || []).map(c => el('span', { class: 'reward' }, `👗 ${LABELS[c]}`))));
    return card;
  }
  progress() {
    this.open('progress', '💖 Kingdom Harmony', body => {
      const h = this.s.harmony, nx = nextUnlock(h);
      body.append(el('div', { class: 'harmony-big' }, el('span', {}, `${h}`), el('span', { class: 'hbar' }, el('i', { style: { width: `${nx ? Math.min(100, h / nx.at * 100) : 100}%` } })), el('span', { style: { fontSize: '16px', whiteSpace: 'nowrap' } }, nx ? `Next: ${nx.title} at ${nx.at}` : 'Every milestone reached!')));
      body.append(el('p', { style: { fontWeight: 700, color: '#8a6a50' } }, 'Harmony grows when you help villagers, finish quests, build something new for the first time and restore the island.'));
      for (const u of HARMONY_UNLOCKS) body.append(el('div', { class: `unlock ${h >= u.at ? 'got' : ''}` }, el('span', { style: { fontSize: '22px' } }, h >= u.at ? '🌟' : '🔒'), el('div', {}, el('div', {}, u.title), el('small', { style: { color: '#8a6a50', fontWeight: 700 } }, u.desc)), el('span', { class: 'need' }, h >= u.at ? 'Unlocked' : `${u.at} Harmony`)));
    });
  }
  noticeBoard() {
    this.open('board', '📌 Village Notice Board', body => {
      const e = this.game.story.engine;
      const offers = QUESTS.filter(q => e.canOffer(q.id));
      if (!offers.length) body.append(el('p', { style: { fontWeight: 700 } }, 'No new requests posted. Hearthglow is feeling cozy!'));
      for (const q of offers) body.append(el('div', { class: 'qcard' }, el('div', { class: 'giver' }, `Posted by ${NPC[q.giver].name}`), el('h4', {}, q.title), el('p', {}, q.description)));
      body.append(el('h3', {}, 'Tips'), el('p', { style: { fontWeight: 700, color: '#8a6a50' } }, 'Villagers with a gold ! have a request. A green ★ means you can report back. Your tool hums near buried treasure.'));
    });
  }
  map(fromBoat = false) {
    this.open('map', '🗺️ Wonderhaven', body => {
      const s = this.s, info = el('div', { class: 'map-info' }, fromBoat ? 'Where shall we sail? Pick an island.' : 'Click an island to learn about it.');
      const svgNS = 'http://www.w3.org/2000/svg';
      const svg = document.createElementNS(svgNS, 'svg'); svg.setAttribute('viewBox', '0 0 800 500');
      const mk = (tag, attrs, parent = svg) => { const n = document.createElementNS(svgNS, tag); for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v); parent.append(n); return n; };
      mk('rect', { x: 0, y: 0, width: 800, height: 500, fill: '#7fd0ec' });
      for (let n = 0; n < 40; n++) { const x = (n * 137) % 780 + 10, y = (n * 89) % 480 + 10; mk('path', { d: `M${x} ${y} q 8 -6 16 0 q 8 6 16 0`, stroke: '#a9e4f5', 'stroke-width': 3, fill: 'none', 'stroke-linecap': 'round' }); }
      const hg = ISLANDS[0];
      for (const isl of ISLANDS) {
        const revealed = isl.built || (isl.reveal && s.flags[isl.reveal]);
        if (isl.id !== 'hearthglow') mk('path', { d: `M${hg.x} ${hg.y} Q ${(hg.x + isl.x) / 2 + 40} ${(hg.y + isl.y) / 2 - 40} ${isl.x} ${isl.y}`, stroke: revealed ? '#fff' : '#cdeef8', 'stroke-width': 4, 'stroke-dasharray': '10 10', fill: 'none', opacity: revealed ? 0.95 : 0.5 });
      }
      for (const isl of ISLANDS) {
        const revealed = isl.built || (isl.reveal && s.flags[isl.reveal]);
        const g = mk('g', { class: 'map-island', transform: `translate(${isl.x} ${isl.y})` });
        mk('ellipse', { cx: 0, cy: 10, rx: isl.r + 12, ry: isl.r * 0.75 + 10, fill: '#f0dfae' }, g);
        mk('path', { d: blob(isl.r), fill: revealed ? isl.color : '#b9c4c8', stroke: '#fff', 'stroke-width': 4 }, g);
        for (let n = 0; n < 5; n++) mk('circle', { cx: Math.cos(n * 1.3) * isl.r * 0.5, cy: Math.sin(n * 1.7) * isl.r * 0.35, r: 7, fill: revealed ? '#4fae63' : '#9aa5a9' }, g);
        if (isl.id === 'hearthglow') { mk('rect', { x: -8, y: -30, width: 16, height: 20, fill: '#f4ecdf' }, g); mk('polygon', { points: '-11,-30 0,-44 11,-30', fill: '#5f7fd8' }, g); }
        const t = mk('text', { x: 0, y: isl.r * 0.75 + 32, 'text-anchor': 'middle', 'font-size': 20, fill: '#5a3d2b', stroke: '#fff', 'stroke-width': 5, 'paint-order': 'stroke' }, g); t.textContent = revealed ? isl.name : '???';
        if (!revealed) { const lock = mk('text', { x: 0, y: 10, 'text-anchor': 'middle', 'font-size': 34 }, g); lock.textContent = '🔒'; }
        if (isl.id === 'hearthglow') {
          const active = this.game.story.engine.active().length + QUESTS.filter(q => this.game.story.engine.canOffer(q.id)).length;
          if (active) { const m = mk('text', { x: isl.r * 0.6, y: -isl.r * 0.55, 'font-size': 28 }, g); m.textContent = `❗${active}`; }
          const you = mk('text', { x: -isl.r * 0.65, y: -isl.r * 0.45, 'font-size': 24 }, g); you.textContent = '📍';
        }
        g.addEventListener('click', () => {
          info.innerHTML = '';
          info.append(el('strong', {}, revealed ? isl.name : 'An unexplored island'), el('div', {}, revealed ? isl.desc : `Rumours say: ${isl.desc}`));
          if (isl.id === 'hearthglow') info.append(el('div', { style: { color: '#8a6a50' } }, `You are here. ${this.game.story.engine.active().length} active quest(s).`));
          else if (!revealed) info.append(el('div', { style: { color: '#b34a6a' } }, s.flags.boatReady ? 'The Captain hasn\'t charted a route here yet.' : 'Open Hearthglow\'s harbor and repair the dock to start sailing.'));
          else if (fromBoat || s.flags.boatReady) info.append(el('div', { class: 'row', style: { marginTop: '8px' } }, el('button', { class: 'primary', onclick: () => this.game.sailTo(isl) }, `⛵ Sail to ${isl.name}`)));
          this.game.sfx('select');
        });
      }
      body.append(el('div', { class: 'map-wrap' }, svg), info);
    });
  }
  pause() {
    this.open('pause', '🌟 Paused', body => {
      const g = this.game;
      body.append(el('div', { class: 'pause-menu' },
        el('button', { class: 'primary', onclick: () => this.close() }, '▶ Resume'),
        el('button', { onclick: () => this.saves('save') }, '💾 Save game'),
        el('button', { onclick: () => this.saves('load') }, '📂 Load game'),
        el('button', { onclick: () => { this.close(); g.openWardrobe(); } }, '👗 Wardrobe'),
        el('button', { onclick: () => this.settings() }, '⚙️ Settings & controls'),
        el('button', { onclick: () => { this.close(); g.toTitle(); } }, '🏠 Quit to title')));
    });
  }
  saves(mode) {
    this.open('saves', mode === 'save' ? '💾 Save Game' : '📂 Load Game', body => {
      const g = this.game, store = g.storage;
      const slots = mode === 'save' ? SLOTS : [AUTOSAVE, ...SLOTS];
      for (const slot of slots) {
        const m = saveMeta(store, slot);
        const label = slot === AUTOSAVE ? 'Autosave' : `Slot ${slot.slice(-1)}`;
        const desc = m && !m.broken ? `${m.name} · Day ${m.day} · 💖 ${m.harmony} · ${m.quests} quests done · ${new Date(m.savedAt).toLocaleString()}` : m?.broken ? 'Damaged save' : 'Empty';
        body.append(el('div', { class: 'slot' }, el('div', {}, label, el('small', {}, desc)), el('span', { class: 'spacer' }),
          mode === 'save' ? el('button', { class: 'small primary', 'data-slot': slot, onclick: () => { g.saveTo(slot); this.saves('save'); } }, m ? 'Overwrite' : 'Save here')
            : el('button', { class: 'small primary', disabled: !m || m.broken, 'data-slot': slot, onclick: () => { this.close(); g.loadFrom(slot); } }, 'Load')));
      }
      body.append(el('button', { class: 'small', onclick: () => this.pause() }, '← Back'));
    });
  }
  settings() {
    this.open('settings', '⚙️ Settings', body => {
      const g = this.game, st = g.settings;
      const range = (label, key, min, max, step) => el('div', { class: 'setting' }, el('span', {}, label), el('input', { type: 'range', min, max, step, value: st[key], oninput: e => { st[key] = Number(e.target.value); g.applySettings(); } }));
      const check = (label, key) => el('div', { class: 'setting' }, el('span', {}, label), el('input', { type: 'checkbox', checked: !!st[key], onchange: e => { st[key] = e.target.checked; g.applySettings(); } }));
      body.append(range('🎵 Music volume', 'music', 0, 1, 0.05), range('🔔 Sound effects', 'sfx', 0, 1, 0.05), range('🖱️ Camera sensitivity', 'sensitivity', 0.3, 2.5, 0.1), check('↕️ Invert camera Y', 'invertY'), check('🌦️ Weather effects', 'weather'));
      body.append(el('div', { class: 'setting' }, el('span', {}, '✨ Graphics quality (applies on reload)'), el('select', { onchange: e => { st.quality = e.target.value; g.applySettings(); } }, ['high', 'medium', 'low'].map(q => el('option', { value: q, selected: st.quality === q }, q)))));
      body.append(el('h3', {}, 'Controls — click a key to change it'));
      const keys = el('div');
      const renderKeys = () => {
        keys.innerHTML = '';
        for (const a of Object.keys(DEFAULT_BINDINGS)) {
          const b = el('button', { class: 'small', onclick: () => { b.textContent = 'Press a key…'; g.input.captureNextKey(code => { if (code !== 'Escape') { g.input.setBindings(rebind(g.input.bindings, a, code)); st.bindings = g.input.bindings; g.applySettings(); } renderKeys(); }); } }, g.input.bindings[a].map(keyLabel).join(' / '));
          keys.append(el('div', { class: 'setting' }, el('span', {}, ACTION_LABELS[a]), b));
        }
        keys.append(el('div', { class: 'setting' }, el('span', {}, 'Undo / Redo (build mode)'), el('span', {}, 'Ctrl+Z / Ctrl+Y')));
        keys.append(el('div', { class: 'setting' }, el('span', {}, 'Gamepad'), el('span', { style: { fontSize: '13px' } }, 'Left stick move · right stick camera · A interact · X build · Y journal · Start menu · Back map')));
      };
      renderKeys();
      body.append(keys, el('div', { class: 'row', style: { marginTop: '10px' } }, el('button', { class: 'small', onclick: () => { g.input.setBindings(DEFAULT_BINDINGS); st.bindings = null; g.applySettings(); renderKeys(); } }, 'Reset controls'), el('button', { class: 'small', onclick: () => this.pause() }, '← Back')));
    });
  }
}
function blob(r) {
  const pts = [];
  for (let n = 0; n < 10; n++) { const a = n / 10 * Math.PI * 2, rr = r * (0.85 + 0.15 * Math.sin(n * 2.7)); pts.push([Math.cos(a) * rr, Math.sin(a) * rr * 0.75]); }
  let d = `M${pts[0][0]} ${pts[0][1]}`;
  for (let n = 0; n < pts.length; n++) { const p = pts[(n + 1) % pts.length], c = pts[n]; d += ` Q ${c[0]} ${c[1]} ${(c[0] + p[0]) / 2} ${(c[1] + p[1]) / 2}`; }
  return d + 'Z';
}
