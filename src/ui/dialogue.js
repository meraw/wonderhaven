// Dialogue box: name plate, live 3D portrait, typewriter text, choices (mouse, keys 1-4, arrows + E, gamepad).
import * as THREE from 'three';
import { $, el } from './dom.js';

export class DialogueUI {
  constructor(game) {
    this.game = game; this.npc = null; this.open = false;
    this.portraitCam = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
    this.queue = null; this.choiceResolve = null; this.choices = null; this.focusIndex = 0;
  }
  start(npc) {
    this.npc = npc; this.open = true;
    const root = $('dialogue'); root.innerHTML = '';
    this.portrait = el('div', { class: 'd-portrait' });
    this.nameEl = el('div', { class: 'd-name' }, npc.def.name);
    this.heartsEl = el('div', { class: 'd-hearts' });
    this.textEl = el('div', { class: 'd-text' });
    this.choicesEl = el('div', { class: 'd-choices' });
    this.moreEl = el('div', { class: 'd-more' }, '▼ click / E');
    this.box = el('div', { class: 'd-box' }, this.nameEl, this.heartsEl, this.textEl, this.choicesEl, this.moreEl);
    root.append(this.portrait, this.box);
    root.hidden = false;
    this.box.addEventListener('click', e => { if (e.target.tagName !== 'BUTTON') this.advance(); });
    this.updateHearts();
  }
  updateHearts() {
    const h = this.game.state.relationships[this.npc.def.id]?.hearts || 0;
    this.heartsEl.textContent = '♥'.repeat(Math.min(10, h)) + '♡'.repeat(Math.max(0, 5 - h)) || '♡♡♡♡♡';
    this.heartsEl.title = `${this.npc.def.name}: ${h} friendship heart${h === 1 ? '' : 's'}`;
  }
  // Show lines one after another. Each line may be a string or { text, mood, anim }.
  say(lines, opts = {}) {
    return new Promise(resolve => {
      this.queue = { lines: lines.map(l => (typeof l === 'string' ? { text: l } : l)), i: -1, resolve, opts, speaker: opts.speaker || this.npc };
      this.nextLine();
    });
  }
  nextLine() {
    const q = this.queue; q.i++;
    if (q.i >= q.lines.length) { this.queue = null; this.npc.character.setTalking(false); q.resolve(); return; }
    const line = q.lines[q.i];
    this.full = line.text; this.shown = 0; this.typing = true;
    this.textEl.textContent = '';
    this.choicesEl.innerHTML = ''; this.moreEl.hidden = true;
    const speaker = line.player ? this.game.playerChar : this.npc.character;
    this.nameEl.textContent = line.player ? this.game.state.name : this.npc.def.name;
    this.npc.character.setTalking(!line.player);
    if (line.mood || q.opts.mood) speaker.setMood(line.mood || q.opts.mood, 2.5);
    if (line.anim || (q.i === 0 && q.opts.anim)) speaker.play(line.anim || q.opts.anim);
    this.game.audio?.voice(line.player ? 1.0 : this.npc.def.voice, Math.min(6, Math.ceil(this.full.length / 14)));
  }
  advance() {
    if (this.choices) return;
    if (!this.queue) return;
    if (this.typing) { this.shown = this.full.length; return; }
    this.game.sfx('blip');
    this.nextLine();
  }
  choose(options) {
    return new Promise(resolve => {
      this.choices = options; this.focusIndex = 0;
      this.choicesEl.innerHTML = ''; this.moreEl.hidden = true;
      options.forEach((o, n) => {
        const b = el('button', { class: o.quest ? 'quest' : '', onclick: () => this.pick(n) }, `${n + 1}. ${o.label}`);
        this.choicesEl.append(b);
      });
      this.choiceResolve = resolve;
      this.highlight();
    });
  }
  pick(n) {
    if (!this.choices) return;
    const o = this.choices[n]; this.choices = null; this.choicesEl.innerHTML = '';
    this.game.sfx('select');
    const r = this.choiceResolve; this.choiceResolve = null; r(o);
  }
  highlight() { [...this.choicesEl.children].forEach((b, n) => { b.style.outline = n === this.focusIndex ? '3px solid #ff8fab' : ''; }); }
  setText(t) { this.textEl.textContent = t; this.choicesEl.innerHTML = ''; this.moreEl.hidden = true; }
  update(dt) {
    if (!this.open) return;
    const input = this.game.input;
    if (this.typing) {
      this.shown = Math.min(this.full.length, this.shown + dt * 48);
      this.textEl.textContent = this.full.slice(0, Math.floor(this.shown));
      if (this.shown >= this.full.length) { this.typing = false; this.npc.character.setTalking(false); this.moreEl.hidden = !!this.choices; }
    }
    if (this.choices) {
      for (let n = 0; n < Math.min(9, this.choices.length); n++) if (input.codePressed(`Digit${n + 1}`)) return this.pick(n);
      if (input.codePressed('ArrowDown') || input.codePressed('KeyS') || input.padPressed('DOWN')) { this.focusIndex = (this.focusIndex + 1) % this.choices.length; this.highlight(); }
      if (input.codePressed('ArrowUp') || input.codePressed('KeyW') || input.padPressed('UP')) { this.focusIndex = (this.focusIndex + this.choices.length - 1) % this.choices.length; this.highlight(); }
      if (input.pressed('interact') || input.codePressed('Enter')) this.pick(this.focusIndex);
    } else if (input.pressed('interact') || input.codePressed('Space') || input.codePressed('Enter') || input.mouse.leftClick) this.advance();
  }
  end() {
    this.open = false; this.queue = null; this.choices = null;
    if (this.npc) this.npc.character.setTalking(false);
    $('dialogue').hidden = true;
  }
  // Render the speaker's face into the portrait frame.
  renderPortrait(renderer, scene) {
    if (!this.open || !this.portrait) return;
    const r = this.portrait.getBoundingClientRect();
    if (r.width < 10) return;
    const speaker = this.npc.character;
    const head = speaker.headWorldPos(new THREE.Vector3());
    const yaw = speaker.root.rotation.y;
    this.portraitCam.position.set(head.x + Math.sin(yaw) * 2.3, head.y + 0.05, head.z + Math.cos(yaw) * 2.3);
    this.portraitCam.lookAt(head.x, head.y - 0.08, head.z);
    this.portraitCam.aspect = r.width / r.height; this.portraitCam.updateProjectionMatrix();
    const H = window.innerHeight;
    renderer.setScissorTest(true);
    renderer.setScissor(r.left, H - r.bottom, r.width, r.height);
    renderer.setViewport(r.left, H - r.bottom, r.width, r.height);
    renderer.setClearColor('#ffefd2', 1);
    renderer.clear(true, true, false);
    renderer.render(scene, this.portraitCam);
    renderer.setScissorTest(false);
  }
}
