// Title screen, character creator (new game) and wardrobe (change your look later).
import * as THREE from 'three';
import { $, el, toast, banner, fade } from './dom.js';
import { SKIN_TONES, EYE_SHAPES, EYE_COLORS, HAIR_STYLES, HAIR_COLORS, MOUTHS, TOPS, BOTTOMS, SHOES, HATS, ACCESSORIES, CLOTH_COLORS, LABELS, LOCKED_CLOTHES, sanitizeAppearance } from '../data/appearance.js';
import { newGameState, isClothingUnlocked } from '../systems/state.js';
import { latestSlot, saveMeta, readSave, SLOTS, AUTOSAVE } from '../systems/save.js';
import { SPAWN } from '../data/village-layout.js';

const pick = a => a[Math.floor(Math.random() * a.length)];

export class Screens {
  constructor(game) { this.game = game; this.t = 0; this.draft = null; this.wardrobeMode = false; this.spin = 0; }
  title() {
    const g = this.game;
    g.setMode('title');
    $('hud').hidden = true;
    g.playerChar.root.visible = false;
    const root = $('screen'); root.hidden = false; root.innerHTML = '';
    const latest = latestSlot(g.storage);
    const buttons = el('div', { class: 'title-buttons' });
    if (latest) buttons.append(el('button', { class: 'primary', id: 'btn-continue', onclick: () => { g.audio.unlock(); this.continueFrom(latest); } }, '▶ Continue'));
    buttons.append(el('button', { class: latest ? '' : 'primary', id: 'btn-new', onclick: () => { g.audio.unlock(); this.creator(); } }, '✨ New Game'));
    if (latest) buttons.append(el('button', { onclick: () => { g.audio.unlock(); this.loadList(); } }, '📂 Load Game'));
    buttons.append(el('button', { onclick: () => { g.audio.unlock(); g.panels.settings(); g.setMode('title'); } }, '⚙️ Settings'));
    root.append(el('div', { class: 'title-wrap' },
      el('div', { class: 'logo' }, el('div', { class: 'l1' }, 'Wonderhaven'), el('div', { class: 'l2' }, '✦ The Lost Isles ✦')),
      buttons,
      el('div', { class: 'title-foot' }, 'A cozy kingdom-building adventure · Chapter 1: Hearthglow Village · WASD + mouse, or a gamepad')));
  }
  loadList() {
    const g = this.game, root = $('screen'); root.innerHTML = '';
    const list = el('div', { class: 'panel', style: { width: 'min(560px, 92vw)' } }, el('h2', {}, '📂 Load Game'));
    for (const slot of [AUTOSAVE, ...SLOTS]) {
      const m = saveMeta(g.storage, slot); if (!m) continue;
      list.append(el('div', { class: 'slot' }, el('div', {}, slot === AUTOSAVE ? 'Autosave' : `Slot ${slot.slice(-1)}`, el('small', {}, m.broken ? 'Damaged' : `${m.name} · Day ${m.day} · 💖 ${m.harmony}`)), el('span', { class: 'spacer' }), el('button', { class: 'small primary', disabled: m.broken, onclick: () => this.continueFrom(slot) }, 'Load')));
    }
    list.append(el('button', { class: 'small', onclick: () => this.title() }, '← Back'));
    root.append(el('div', { class: 'title-wrap' }, list));
  }
  continueFrom(slot) {
    const g = this.game, s = readSave(g.storage, slot);
    if (!s) { toast('That save could not be read', 'warn'); return; }
    $('screen').hidden = true;
    g.playerChar.root.visible = true;
    g.loadState(s);
    g.beginPlay();
    banner(`Welcome back, ${s.name}!`, `Day ${s.time.day} in Hearthglow`);
  }
  creator(wardrobe = false) {
    const g = this.game;
    this.wardrobeMode = wardrobe;
    this.draft = { name: wardrobe ? g.state.name : 'Apprentice', appearance: sanitizeAppearance(wardrobe ? g.state.appearance : { ...g.state.appearance, hair: pick(HAIR_STYLES.slice(0, 6)), hairColor: pick(HAIR_COLORS), topColor: pick(CLOTH_COLORS) }) };
    this.prevMode = g.mode;
    g.setMode('creator');
    g.playerChar.root.visible = true;
    if (!wardrobe) g.player.teleport(0, 9.5, 0);
    this.savedYaw = g.player.yaw;
    this.spin = 0.4;
    g.playerChar.setAppearance(this.draft.appearance);
    $('hud').hidden = true;
    this.renderCreator();
  }
  wardrobe() { if (this.game.mode === 'explore') this.creator(true); }
  isLocked(value) { return !this.wardrobeMode ? value in LOCKED_CLOTHES : !isClothingUnlocked(this.game.state, value); }
  renderCreator() {
    const g = this.game, a = this.draft.appearance, root = $('screen');
    root.hidden = false; root.innerHTML = '';
    const set = (k, v) => { if (this.isLocked(v)) { toast(`🔒 ${LABELS[v]} — ${LOCKED_CLOTHES[v]}`, 'warn', 3); return; } a[k] = v; g.playerChar.setAppearance(a); g.playerChar.play(Math.random() < 0.5 ? 'wave' : 'nod'); g.sfx('select'); this.renderCreator(); };
    const sw = (k, colors) => el('div', { class: 'swatches' }, colors.map(c => el('span', { class: `sw ${a[k] === c ? 'on' : ''}`, style: { background: c }, title: c, onclick: () => set(k, c) })));
    const pills = (k, list) => el('div', { class: 'pills' }, list.map(v => el('button', { class: `${a[k] === v ? 'on' : ''} ${this.isLocked(v) ? 'locked' : ''}`, title: this.isLocked(v) ? `Locked: ${LOCKED_CLOTHES[v]}` : '', 'data-opt': `${k}:${v}`, onclick: () => set(k, v) }, `${this.isLocked(v) ? '🔒 ' : ''}${LABELS[v] || v}`)));
    const opt = (label, ...kids) => el('div', { class: 'opt' }, el('label', {}, label), ...kids);
    const panel = el('div', { class: 'creator' },
      el('h2', {}, this.wardrobeMode ? '👗 Wardrobe' : '✨ Create your apprentice'),
      this.wardrobeMode ? null : opt('Name', el('input', { class: 'name-input', id: 'name-input', maxlength: 16, value: this.draft.name, oninput: e => { this.draft.name = e.target.value; } })),
      opt('Skin tone', sw('skin', SKIN_TONES)),
      opt('Eyes', pills('eyeShape', EYE_SHAPES), sw('eyeColor', EYE_COLORS)),
      opt('Expression', pills('mouth', MOUTHS)),
      opt('Hairstyle', pills('hair', HAIR_STYLES), sw('hairColor', HAIR_COLORS)),
      opt('Top', pills('top', TOPS), sw('topColor', CLOTH_COLORS)),
      opt('Bottoms', pills('bottom', BOTTOMS), sw('bottomColor', CLOTH_COLORS)),
      opt('Shoes', pills('shoes', SHOES), sw('shoesColor', CLOTH_COLORS)),
      opt('Hat', pills('hat', HATS), sw('hatColor', CLOTH_COLORS)),
      opt('Accessory', pills('accessory', ACCESSORIES)),
      el('div', { class: 'row', style: { marginTop: '12px' } },
        el('button', { onclick: () => this.randomize() }, '🎲 Surprise me'),
        el('span', { class: 'spacer' }),
        this.wardrobeMode ? el('button', { onclick: () => this.closeWardrobe(false) }, 'Cancel') : el('button', { onclick: () => this.title() }, '← Back'),
        el('button', { class: 'primary', id: 'btn-start', onclick: () => (this.wardrobeMode ? this.closeWardrobe(true) : this.startNewGame()) }, this.wardrobeMode ? 'Looks great!' : 'Begin adventure ➜')));
    root.append(panel, el('div', { class: 'creator-hint' }, 'Drag to turn · locked pieces unlock as you play'));
    root.onpointerdown = e => { if (e.target === root) { this.dragX = e.clientX; } };
    root.onpointermove = e => { if (this.dragX !== undefined && e.buttons) { this.spin += (e.clientX - this.dragX) * 0.01; this.dragX = e.clientX; } };
    root.onpointerup = () => { this.dragX = undefined; };
  }
  randomize() {
    const a = this.draft.appearance, free = l => l.filter(v => !this.isLocked(v));
    Object.assign(a, { skin: pick(SKIN_TONES), eyeShape: pick(EYE_SHAPES), eyeColor: pick(EYE_COLORS), mouth: pick(MOUTHS), hair: pick(HAIR_STYLES), hairColor: pick(HAIR_COLORS), top: pick(free(TOPS)), topColor: pick(CLOTH_COLORS), bottom: pick(BOTTOMS), bottomColor: pick(CLOTH_COLORS), shoes: pick(SHOES), shoesColor: pick(CLOTH_COLORS), hat: Math.random() < 0.5 ? 'none' : pick(free(HATS)), hatColor: pick(CLOTH_COLORS), accessory: Math.random() < 0.6 ? 'none' : pick(free(ACCESSORIES)) });
    this.game.playerChar.setAppearance(a); this.game.playerChar.play('celebrate'); this.game.sfx('sparkle'); this.renderCreator();
  }
  closeWardrobe(keep) {
    const g = this.game;
    if (keep) { g.state.appearance = sanitizeAppearance(this.draft.appearance); g.effects.sparkle(new THREE.Vector3(g.player.pos.x, g.player.pos.y + 1, g.player.pos.z), { count: 24 }); g.sfx('sparkle'); g.autosave('wardrobe', true); }
    g.playerChar.setAppearance(g.state.appearance);
    g.player.yaw = this.savedYaw; g.player.sync();
    $('screen').hidden = true; $('hud').hidden = false;
    g.setMode('explore');
  }
  startNewGame() {
    const g = this.game;
    const name = (this.draft.name || '').trim() || 'Apprentice';
    const state = newGameState({ name, appearance: this.draft.appearance });
    $('screen').hidden = true;
    fade(true);
    setTimeout(() => {
      g.loadState(state);
      g.player.teleport(SPAWN.x - 6, SPAWN.z, SPAWN.yaw);
      g.cam.yaw = SPAWN.yaw + Math.PI; g.cam.cur.yaw = g.cam.yaw;
      g.beginPlay();
      g.intro();
      fade(false);
    }, 600);
  }
  update(dt) {
    const g = this.game; this.t += dt;
    const cam = g.camera;
    if (g.mode === 'title') {
      const a = this.t * 0.05;
      cam.position.set(Math.sin(a) * 34, 17, Math.cos(a) * 34 + 2); cam.lookAt(0, 0, 0);
      for (const n of g.npcs.list) n.update(dt);
      g.village.update(dt, g.time, { ...g.state.flags });
      g.effects.update(dt);
    } else if (g.mode === 'creator') {
      g.player.yaw = this.spin; g.player.sync();
      g.playerChar.update(dt, {});
      const p = g.player.pos;
      cam.position.set(p.x - 1.1 * 0 + 0.9, p.y + 1.15, p.z + 3.6);
      cam.lookAt(p.x + 0.9, p.y + 0.85, p.z);
      g.village.update(dt, g.time, { ...g.state.flags });
      g.effects.update(dt);
      if (this.wardrobeMode) for (const n of g.npcs.list) n.update(dt);
    }
    g.audio.update(dt, { night: g.state.flags.night });
  }
  renderPreview() {}
}
