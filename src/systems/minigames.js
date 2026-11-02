// Short, friendly gathering minigames as pure state machines: step(dt, { press, hold }) until done.
import { makeRng } from '../core/rng.js';

// Wood chopping: stop the swinging needle inside the green zone, three swings.
export class ChopGame {
  constructor(rng = makeRng(Date.now() & 0xffff)) {
    this.rng = rng; this.round = 0; this.rounds = 3; this.results = []; this.t = 0; this.done = false; this.pause = 0;
    this.newRound();
  }
  newRound() { this.center = 0.3 + this.rng() * 0.4; this.width = 0.24; this.perfect = 0.07; this.speed = 1.1 + this.round * 0.25; this.phase = this.rng() * Math.PI * 2; }
  get needle() { return 0.5 + 0.5 * Math.sin(this.phase); }
  step(dt, { press = false } = {}) {
    if (this.done) return;
    if (this.pause > 0) { this.pause -= dt; if (this.pause <= 0 && this.round >= this.rounds) this.done = true; return; }
    this.phase += dt * this.speed * Math.PI;
    if (press) {
      const d = Math.abs(this.needle - this.center);
      const r = d <= this.perfect / 2 ? 'perfect' : d <= this.width / 2 ? 'good' : 'miss';
      this.results.push(r); this.round++; this.pause = 0.45; this.last = r;
      if (this.round < this.rounds) this.newRound();
    }
  }
  reward() {
    const good = this.results.filter(r => r !== 'miss').length, perfect = this.results.filter(r => r === 'perfect').length;
    return { wood: 1 + good + Math.floor(perfect / 2), spark: 1 + perfect };
  }
}

// Mining: strike when the shrinking ring overlaps the target circle.
export class MineGame {
  constructor({ rich = false } = {}, rng = makeRng(Date.now() & 0xffff)) {
    this.rng = rng; this.rich = rich; this.strikes = 3; this.results = []; this.done = false; this.pause = 0; this.reset();
  }
  reset() { this.r = 1; this.speed = 0.55 + this.results.length * 0.12; this.target = [0.32, 0.46]; }
  step(dt, { press = false } = {}) {
    if (this.done) return;
    if (this.pause > 0) { this.pause -= dt; if (this.pause <= 0) { if (this.results.length >= this.strikes) this.done = true; else this.reset(); } return; }
    this.r -= dt * this.speed;
    if (this.r < 0.05) { this.results.push('miss'); this.last = 'miss'; this.pause = 0.45; return; }
    if (press) {
      const [a, b] = this.target, mid = (a + b) / 2;
      const r = this.r >= a && this.r <= b ? (Math.abs(this.r - mid) < 0.03 ? 'perfect' : 'good') : 'miss';
      this.results.push(r); this.last = r; this.pause = 0.45;
    }
  }
  reward() {
    const hits = this.results.filter(r => r !== 'miss').length, perfect = this.results.filter(r => r === 'perfect').length;
    const out = { stone: 1 + hits, spark: 1 + perfect };
    if (hits >= 2 || (this.rich && hits >= 1)) out.metal = 1;
    if (this.rich && hits >= 1) out.crystal = hits >= 3 ? 2 : 1;
    else if (perfect >= 2) out.crystal = 1;
    return out;
  }
}

// Fishing: wait for the bite, hook it in time, then keep the line tension in the green band while reeling.
export const FISH = [
  { id: 'minnow', name: 'Sunny Minnow', weight: 5, pull: 0.5 },
  { id: 'trout', name: 'Rainbow Trout', weight: 3, pull: 0.8 },
  { id: 'puffer', name: 'Puffy Pufferfish', weight: 1.5, pull: 1.0 },
  { id: 'starfish', name: 'Wishing Starfin', weight: 0.6, pull: 1.25 },
];
export class FishGame {
  constructor(rng = makeRng(Date.now() & 0xffff)) {
    this.rng = rng; this.phase = 'wait'; this.t = 0; this.wait = 1.4 + rng() * 2.6; this.done = false; this.caught = null;
    this.tension = 0.4; this.progress = 0; this.band = [0.32, 0.74]; this.fish = this.pickFish(); this.pull = 0;
  }
  pickFish() { const total = FISH.reduce((s, f) => s + f.weight, 0); let x = this.rng() * total; for (const f of FISH) { x -= f.weight; if (x <= 0) return f; } return FISH[0]; }
  step(dt, { press = false, hold = false } = {}) {
    if (this.done) return;
    this.t += dt;
    if (this.phase === 'wait') { if (press) { this.phase = 'early'; this.done = true; this.result = 'early'; return; } if (this.t >= this.wait) { this.phase = 'bite'; this.t = 0; } return; }
    if (this.phase === 'bite') { if (press) { this.phase = 'reel'; this.t = 0; return; } if (this.t > 1.3) { this.done = true; this.result = 'missed'; } return; }
    if (this.phase === 'reel') {
      // The fish tugs in bursts; holding raises tension, letting go lowers it.
      if (this.rng() < dt * 1.6) this.pull = (this.rng() - 0.3) * this.fish.pull;
      this.tension += (hold ? 0.55 : -0.5) * dt + this.pull * dt * 0.8;
      this.pull *= 1 - dt * 1.5;
      this.tension = Math.max(0, Math.min(1, this.tension));
      const inBand = this.tension >= this.band[0] && this.tension <= this.band[1];
      this.progress += (inBand ? 0.22 : -0.08) * dt;
      this.progress = Math.max(0, this.progress);
      if (this.tension >= 0.99) { this.done = true; this.result = 'snap'; }
      else if (this.progress >= 1) { this.done = true; this.result = 'caught'; this.caught = this.fish; }
      else if (this.t > 25) { this.done = true; this.result = 'escaped'; }
    }
  }
  reward() { return this.result === 'caught' ? { fish: 1, spark: 2 } : {}; }
}
