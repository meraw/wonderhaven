// Overlays for the gathering minigames. Press = E / Space / click; hold = keep E / Space / mouse down.
import { $, el } from './dom.js';

const TITLES = { chop: '🪓 Chop the tree!', mine: '⛏️ Strike the rock!', fish: '🎣 Fishing' };
const HINTS = {
  chop: 'Press E (or click) when the needle is in the green. Gold is perfect!',
  mine: 'Press E when the dark ring lines up with the green circle.',
};
export class MinigameUI {
  constructor(game) { this.game = game; this.active = null; }
  start(kind, mg, onDone) {
    this.active = { kind, mg, onDone, resultT: 0 };
    const root = $('minigame'); root.hidden = false; root.innerHTML = '';
    root.append(el('h3', {}, TITLES[kind]));
    this.body = el('div'); root.append(this.body);
    this.hint = el('div', { class: 'mg-hint' }, HINTS[kind] || ''); root.append(this.hint);
    this.result = el('div', { class: 'mg-result' }); root.append(this.result);
    root.append(el('div', { class: 'mg-hint', style: { fontSize: '12px', marginTop: '4px' } }, 'Esc to stop'));
    root.onpointerdown = () => { this.mouseHold = true; this.clicked = true; };
    root.onpointerup = () => { this.mouseHold = false; };
    this.lastResults = 0;
    this.build();
  }
  build() {
    const { kind } = this.active; this.body.innerHTML = ''; this.dots = null;
    if (kind === 'chop') {
      this.bar = el('div', { class: 'mg-bar' }); this.zone = el('div', { class: 'mg-zone' }); this.perfect = el('div', { class: 'mg-zone perfect' }); this.needle = el('div', { class: 'mg-needle' });
      this.bar.append(this.zone, this.perfect, this.needle); this.dots = el('div', { class: 'mg-dots' }, [0, 1, 2].map(() => el('i')));
      this.body.append(this.bar, this.dots);
    } else if (kind === 'mine') {
      this.ring = el('div', { class: 'mg-ring' }); this.target = el('div', { class: 'target' }); this.shrink = el('div', { class: 'shrink' });
      this.ring.append(this.target, this.shrink); this.dots = el('div', { class: 'mg-dots' }, [0, 1, 2].map(() => el('i')));
      this.body.append(this.ring, this.dots);
    } else if (kind === 'fish') {
      this.status = el('div', { style: { fontSize: '20px', fontWeight: 900, margin: '8px 0' } }, 'Waiting for a bite…');
      this.tension = el('div', { class: 'tension' }); this.band = el('div', { class: 'band' }); this.level = el('div', { class: 'level' }); this.tension.append(this.band, this.level);
      this.progress = el('div', { class: 'mg-bar reel-progress' }); this.progFill = el('div', { class: 'mg-zone', style: { left: 0, width: '0%' } }); this.progress.append(this.progFill);
      this.reelWrap = el('div', { class: 'reel-wrap' }, this.tension, el('div', {}, el('div', { class: 'mg-hint' }, 'Catch'), this.progress)); this.reelWrap.hidden = true;
      this.body.append(this.status, this.reelWrap);
    }
  }
  update(dt) {
    const a = this.active; if (!a) return;
    const input = this.game.input;
    if (input.pressed('pause')) { this.finish(true); return; }
    const press = input.pressed('interact') || input.codePressed('Space') || input.mouse.leftClick || this.clicked;
    const hold = input.down('interact') || input.keys.has('Space') || input.mouse.leftDown || this.mouseHold;
    this.clicked = false;
    if (a.mg.done) { a.resultT += dt; if (a.resultT > 1.1) { this.finish(false); return; } this.render(); return; }
    a.mg.step(dt, { press, hold });
    const n = a.mg.results?.length || 0;
    if (n > this.lastResults) { this.lastResults = n; const r = a.mg.results[n - 1]; this.game.sfx(r === 'miss' ? 'miss' : r === 'perfect' ? 'perfect' : 'hit'); this.game.playerChar.play(a.kind === 'mine' ? 'mine' : 'chop'); this.game.cam.shake = r === 'miss' ? 0 : 0.25; }
    this.render();
  }
  render() {
    const { kind, mg } = this.active;
    if (kind === 'chop') {
      this.zone.style.left = `${(mg.center - mg.width / 2) * 100}%`; this.zone.style.width = `${mg.width * 100}%`;
      this.perfect.style.left = `${(mg.center - mg.perfect / 2) * 100}%`; this.perfect.style.width = `${mg.perfect * 100}%`;
      this.needle.style.left = `${mg.needle * 100}%`;
    }
    if (kind === 'mine') {
      const px = v => `${v * 140}px`;
      this.target.style.width = this.target.style.height = px((mg.target[0] + mg.target[1]) / 2 * 2 * 0.5 + 0.12);
      this.target.style.borderWidth = `${(mg.target[1] - mg.target[0]) * 70}px`;
      this.target.style.width = this.target.style.height = px(mg.target[1]);
      this.shrink.style.width = this.shrink.style.height = px(Math.max(0.02, mg.r));
    }
    if (this.dots && mg.results) [...this.dots.children].forEach((d, n) => { d.className = mg.results[n] === 'miss' ? 'miss' : mg.results[n] === 'perfect' ? 'perfect' : mg.results[n] ? 'hit' : ''; });
    if (kind === 'fish') {
      const ph = mg.phase;
      this.status.textContent = ph === 'wait' ? 'Waiting for a bite… (don\'t pull yet!)' : ph === 'bite' ? '❗ A bite! Press E!' : ph === 'reel' ? 'Hold E to reel — keep the line in the green' : '';
      this.status.style.color = ph === 'bite' ? '#e86f8f' : '';
      this.reelWrap.hidden = ph !== 'reel';
      this.band.style.bottom = `${mg.band[0] * 100}%`; this.band.style.height = `${(mg.band[1] - mg.band[0]) * 100}%`;
      this.level.style.bottom = `${mg.tension * 100}%`;
      this.progFill.style.width = `${Math.min(100, mg.progress * 100)}%`;
      if (ph === 'bite' && !this.bitePlayed) { this.bitePlayed = true; this.game.sfx('bite'); this.game.playerChar.play('surprised'); }
    }
    if (mg.done) {
      const msg = kind === 'fish'
        ? ({ caught: `Caught a ${mg.caught?.name}! 🐟`, snap: 'Snap! The line broke — too much tension.', missed: 'It got away… press quicker next time!', early: 'Too soon! The fish swam off.', escaped: 'It wriggled free!' })[mg.result]
        : `${mg.results.filter(r => r !== 'miss').length} / 3 hits${mg.results.includes('perfect') ? ' ✨' : ''}`;
      this.result.textContent = msg;
    }
  }
  finish(cancelled) {
    const a = this.active; this.active = null; this.bitePlayed = false;
    $('minigame').hidden = true;
    a.onDone(cancelled ? null : a.mg);
  }
}
