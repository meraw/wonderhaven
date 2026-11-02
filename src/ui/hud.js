// Heads-up display: resources, Harmony, clock, quest tracker, hotkeys.
import { RESOURCES, RESOURCE_ORDER } from '../data/resources.js';
import { $, el } from './dom.js';

export class Hud {
  constructor(game) { this.game = game; this.last = {}; }
  resources(pop = []) {
    const inv = this.game.state.inventory, root = $('hud-res');
    root.innerHTML = '';
    for (const id of RESOURCE_ORDER) {
      if (id !== 'spark' && !(inv[id] > 0)) continue;
      const r = RESOURCES[id];
      const chip = el('span', { class: `chip ${id === 'spark' ? 'spark' : ''} ${pop.includes(id) ? 'pop' : ''}`, title: r.name, 'data-res': id }, el('span', { class: 'ico' }, r.icon), String(inv[id] || 0));
      root.append(chip);
    }
  }
  harmony(value, next) {
    const pct = next ? Math.min(100, (value / next.at) * 100) : 100;
    $('hud-harmony').innerHTML = '';
    $('hud-harmony').append(el('span', {}, '💖 Harmony'), el('span', { class: 'hbar' }, el('i', { style: { width: `${pct}%` } })), el('span', {}, `${value}${next ? ` / ${next.at}` : ''}`));
  }
  clock(text) { const c = $('hud-clock'); if (c.textContent !== text) c.textContent = text; }
}
