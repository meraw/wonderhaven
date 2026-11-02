// Original procedural music and synthesized sound effects (WebAudio). No audio files are needed.
// Instruments: marimba, glockenspiel, ukulele-ish pluck, soft pad, bass, shaker and a tiny kick.
const NOTE = n => 440 * Math.pow(2, (n - 69) / 12);
// Hearthglow theme: F major, a lilting 3/4-ish feel written in 8th-note steps (16 steps per bar, 4 bars per loop).
const SONGS = {
  hearthglow: {
    bpm: 96, root: 65, // F4
    chords: [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14], [0, 4, 7], [2, 5, 9], [5, 9, 12], [7, 11, 14]],
    melody: [[0, 7], [2, 9], [4, 12], [6, 11], [8, 9], [12, 7], [16, 9], [18, 12], [20, 16], [24, 14], [28, 12],
      [32, 5], [34, 9], [36, 12], [38, 14], [40, 12], [44, 9], [48, 7], [50, 11], [52, 14], [56, 12], [60, 11],
      [64, 7], [66, 9], [68, 12], [70, 11], [72, 9], [76, 7], [80, 2], [82, 5], [84, 9], [88, 7], [92, 5],
      [96, 5], [98, 9], [100, 12], [102, 14], [104, 16], [108, 14], [112, 11], [114, 14], [116, 12], [120, 7]],
  },
  night: {
    bpm: 72, root: 60,
    chords: [[0, 4, 7, 11], [9, 12, 16], [5, 9, 12, 16], [7, 11, 14, 17]],
    melody: [[0, 16], [6, 14], [8, 12], [16, 11], [24, 12], [32, 9], [38, 12], [40, 16], [48, 14], [56, 11]],
  },
  build: {
    bpm: 104, root: 67,
    chords: [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
    melody: [[0, 12], [2, 16], [4, 19], [8, 17], [12, 16], [16, 14], [18, 17], [20, 21], [24, 19], [28, 17], [32, 16], [36, 12], [40, 14], [44, 16], [48, 19], [56, 24]],
  },
};

export class AudioEngine {
  constructor() { this.ctx = null; this.music = 0.6; this.sfxVol = 0.8; this.song = 'hearthglow'; this.step = 0; this.nextTime = 0; this.enabled = true; this.ambT = 0; }
  unlock() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    this.ctx = new AC();
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = 0.9; this.master.connect(c.destination);
    this.musicGain = c.createGain(); this.musicGain.connect(this.master);
    this.sfxGain = c.createGain(); this.sfxGain.connect(this.master);
    // Gentle room reverb made from decaying noise
    this.verb = c.createConvolver();
    const len = c.sampleRate * 1.6, buf = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const d = buf.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3); }
    this.verb.buffer = buf;
    this.verbGain = c.createGain(); this.verbGain.gain.value = 0.25; this.verb.connect(this.verbGain); this.verbGain.connect(this.master);
    this.noise = c.createBuffer(1, c.sampleRate, c.sampleRate); const nd = this.noise.getChannelData(0); for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    this.setVolumes(this.music, this.sfxVol);
    this.nextTime = c.currentTime + 0.1;
  }
  setVolumes(m, s) { this.music = m; this.sfxVol = s; if (this.ctx) { this.musicGain.gain.value = m * 0.5; this.sfxGain.gain.value = s * 0.7; } }
  setSong(name) { if (SONGS[name] && name !== this.song) { this.song = name; this.step = 0; } }

  // ---- Instruments ----
  env(g, t, a, peak, d) { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(peak, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); }
  tone(freq, t, { type = 'sine', a = 0.005, d = 0.4, vol = 0.2, out = this.musicGain, verb = 0.3, detune = 0 } = {}) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.value = freq; o.detune.value = detune;
    this.env(g, t, a, vol, d);
    o.connect(g); g.connect(out);
    if (verb) { const s = c.createGain(); s.gain.value = verb; g.connect(s); s.connect(this.verb); }
    o.start(t); o.stop(t + a + d + 0.05);
  }
  marimba(n, t, vol = 0.22, out) { const f = NOTE(n); this.tone(f, t, { d: 0.5, vol, out }); this.tone(f * 4, t, { d: 0.06, vol: vol * 0.25, out }); }
  glock(n, t, vol = 0.12, out) { const f = NOTE(n); this.tone(f, t, { d: 1.1, vol, out, verb: 0.5 }); this.tone(f * 2.76, t, { d: 0.3, vol: vol * 0.3, out, verb: 0.5 }); }
  pluck(n, t, vol = 0.12, out) {
    const c = this.ctx, o = c.createOscillator(), f = c.createBiquadFilter(), g = c.createGain();
    o.type = 'triangle'; o.frequency.value = NOTE(n); f.type = 'lowpass'; f.frequency.setValueAtTime(3000, t); f.frequency.exponentialRampToValueAtTime(400, t + 0.3);
    this.env(g, t, 0.003, vol, 0.35); o.connect(f); f.connect(g); g.connect(out || this.musicGain); o.start(t); o.stop(t + 0.45);
  }
  pad(notes, t, dur, vol = 0.035) {
    const c = this.ctx;
    for (const n of notes) for (const dt of [-6, 6]) {
      const o = c.createOscillator(), f = c.createBiquadFilter(), g = c.createGain();
      o.type = 'sawtooth'; o.frequency.value = NOTE(n); o.detune.value = dt; f.type = 'lowpass'; f.frequency.value = 900;
      g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vol, t + dur * 0.3); g.gain.linearRampToValueAtTime(0.0001, t + dur);
      o.connect(f); f.connect(g); g.connect(this.musicGain); const s = c.createGain(); s.gain.value = 0.4; g.connect(s); s.connect(this.verb);
      o.start(t); o.stop(t + dur + 0.05);
    }
  }
  noiseHit(t, { vol = 0.05, freq = 8000, d = 0.05, type = 'highpass', out } = {}) {
    const c = this.ctx, src = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain();
    src.buffer = this.noise; f.type = type; f.frequency.value = freq; this.env(g, t, 0.002, vol, d);
    src.connect(f); f.connect(g); g.connect(out || this.musicGain); src.start(t); src.stop(t + d + 0.05);
  }
  kick(t, vol = 0.12) { const c = this.ctx, o = c.createOscillator(), g = c.createGain(); o.frequency.setValueAtTime(140, t); o.frequency.exponentialRampToValueAtTime(45, t + 0.15); this.env(g, t, 0.003, vol, 0.18); o.connect(g); g.connect(this.musicGain); o.start(t); o.stop(t + 0.25); }

  // ---- Sequencer ----
  scheduleMusic() {
    const c = this.ctx, song = SONGS[this.song];
    const stepDur = 60 / song.bpm / 4 * 2; // 8th notes
    while (this.nextTime < c.currentTime + 0.25) {
      const t = this.nextTime, s = this.step;
      const bar = Math.floor(s / 16) % song.chords.length, chord = song.chords[bar], beat = s % 16;
      const R = song.root;
      if (beat === 0) { this.pad(chord.map(n => R + n - 12), t, stepDur * 16, this.song === 'night' ? 0.045 : 0.028); this.pluck(R + chord[0] - 24, t, 0.16); }
      if (beat === 8) this.pluck(R + chord[2] - 24, t, 0.12);
      if (this.song !== 'night') {
        if (beat % 2 === 0) this.marimba(R + chord[(beat / 2) % chord.length] - (beat % 4 ? 0 : 12), t, 0.1);
        if (beat % 4 === 2) this.noiseHit(t, { vol: 0.025 });
        if (beat === 0 || beat === 10) this.kick(t, 0.07);
      } else if (beat % 4 === 0) this.glock(R + chord[(beat / 4) % chord.length] + 12, t, 0.05);
      const loop = song.melody.length ? Math.max(...song.melody.map(m => m[0])) + 8 : 128;
      const ms = s % (Math.ceil(loop / 16) * 16);
      for (const [at, n] of song.melody) if (at === ms) (this.song === 'build' ? this.glock : this.marimba).call(this, R + n, t, this.song === 'build' ? 0.09 : 0.17);
      this.step++; this.nextTime += stepDur;
    }
  }
  update(dt, ctx = {}) {
    if (!this.ctx || this.ctx.state !== 'running') return;
    this.scheduleMusic();
    this.ambT -= dt;
    if (this.ambT < 0) {
      this.ambT = 0.8 + Math.random() * 2.5;
      const t = this.ctx.currentTime;
      if (ctx.night) { for (let i = 0; i < 3; i++) this.tone(4200 + Math.random() * 300, t + i * 0.07, { d: 0.04, vol: 0.012, out: this.sfxGain, verb: 0 }); }
      else if (!ctx.rain && Math.random() < 0.7) { const base = 2200 + Math.random() * 1500; for (let i = 0; i < 2 + Math.floor(Math.random() * 3); i++) this.tone(base * (1 + (i % 2) * 0.18), t + i * 0.09, { d: 0.06, vol: 0.02, out: this.sfxGain, verb: 0.2 }); }
      if (ctx.rain) this.noiseHit(t, { vol: 0.04, freq: 1200, d: 2.4, type: 'lowpass', out: this.sfxGain });
      if (ctx.water) this.noiseHit(t, { vol: 0.03 * ctx.water, freq: 600, d: 1.8, type: 'lowpass', out: this.sfxGain });
      if (ctx.machines) for (let i = 0; i < 2; i++) this.noiseHit(t + i * 0.25, { vol: 0.03 * ctx.machines, freq: 3000, d: 0.03, type: 'bandpass', out: this.sfxGain });
    }
  }

  // ---- Sound effects ----
  sfx(name) {
    if (!this.ctx || this.ctx.state !== 'running') return;
    const t = this.ctx.currentTime, o = this.sfxGain;
    const arp = (notes, gap, inst = 'glock', vol = 0.18) => notes.forEach((n, i) => this[inst](n, t + i * gap, vol, o));
    switch (name) {
      case 'place': arp([72, 76, 79, 84], 0.05, 'glock', 0.16); this.noiseHit(t, { vol: 0.05, freq: 3000, d: 0.25, type: 'bandpass', out: o }); break;
      case 'remove': this.tone(600, t, { type: 'triangle', d: 0.12, vol: 0.15, out: o }); this.tone(300, t + 0.06, { type: 'triangle', d: 0.15, vol: 0.12, out: o }); break;
      case 'collect': arp([79, 86], 0.07, 'marimba', 0.2); break;
      case 'sparkle': arp([84, 88, 91, 96], 0.04, 'glock', 0.12); break;
      case 'objective': arp([76, 83], 0.08, 'glock', 0.16); break;
      case 'accept': arp([67, 72, 76], 0.09, 'marimba', 0.22); break;
      case 'fanfare': arp([60, 64, 67, 72, 76, 79, 84], 0.08, 'marimba', 0.24); this.pad([60, 64, 67, 72], t + 0.5, 1.5, 0.05); break;
      case 'fanfareSmall': arp([72, 76, 79, 84], 0.07, 'marimba', 0.2); break;
      case 'unlock': arp([72, 79, 84, 88, 91], 0.06, 'glock', 0.14); break;
      case 'error': this.tone(180, t, { type: 'square', d: 0.12, vol: 0.06, out: o, verb: 0 }); this.tone(150, t + 0.1, { type: 'square', d: 0.14, vol: 0.05, out: o, verb: 0 }); break;
      case 'select': case 'tick': case 'blip': this.tone(name === 'blip' ? 900 : 1200, t, { type: 'triangle', d: 0.04, vol: 0.06, out: o, verb: 0 }); break;
      case 'open': arp([67, 74], 0.05, 'marimba', 0.12); break;
      case 'close': arp([74, 67], 0.05, 'marimba', 0.1); break;
      case 'chest': arp([72, 76, 79, 84, 88], 0.06, 'glock', 0.16); this.noiseHit(t, { vol: 0.06, freq: 900, d: 0.2, type: 'lowpass', out: o }); break;
      case 'hit': this.noiseHit(t, { vol: 0.15, freq: 1800, d: 0.08, type: 'bandpass', out: o }); this.tone(220, t, { type: 'triangle', d: 0.1, vol: 0.12, out: o }); break;
      case 'perfect': this.noiseHit(t, { vol: 0.15, freq: 1800, d: 0.08, type: 'bandpass', out: o }); arp([84, 91], 0.05, 'glock', 0.14); break;
      case 'miss': this.tone(160, t, { type: 'sine', d: 0.15, vol: 0.1, out: o }); break;
      case 'cast': this.noiseHit(t, { vol: 0.08, freq: 2500, d: 0.35, type: 'bandpass', out: o }); break;
      case 'bite': this.tone(520, t, { type: 'sine', d: 0.1, vol: 0.15, out: o }); this.tone(780, t + 0.08, { type: 'sine', d: 0.1, vol: 0.12, out: o }); break;
      case 'dig': case 'rustle': this.noiseHit(t, { vol: 0.12, freq: 700, d: 0.25, type: 'lowpass', out: o }); break;
      case 'pick': this.tone(880, t, { type: 'triangle', d: 0.05, vol: 0.1, out: o }); break;
      case 'water': this.noiseHit(t, { vol: 0.1, freq: 1500, d: 0.6, type: 'bandpass', out: o }); break;
      case 'squeak': this.tone(1800, t, { type: 'sine', d: 0.06, vol: 0.08, out: o }); this.tone(2300, t + 0.07, { type: 'sine', d: 0.05, vol: 0.07, out: o }); break;
      case 'door': this.tone(200, t, { type: 'triangle', d: 0.2, vol: 0.1, out: o }); break;
      case 'lever': this.noiseHit(t, { vol: 0.12, freq: 2500, d: 0.05, type: 'bandpass', out: o }); this.tone(400, t + 0.03, { type: 'square', d: 0.05, vol: 0.05, out: o, verb: 0 }); break;
      case 'paint': arp([88, 91, 95], 0.03, 'glock', 0.08); break;
      case 'undo': this.tone(500, t, { type: 'triangle', d: 0.06, vol: 0.08, out: o }); this.tone(700, t + 0.05, { type: 'triangle', d: 0.06, vol: 0.06, out: o }); break;
      case 'gate': this.tone(70, t, { type: 'sawtooth', d: 0.9, vol: 0.08, out: o }); arp([60, 67, 72], 0.2, 'marimba', 0.2); break;
      case 'sail': this.noiseHit(t, { vol: 0.1, freq: 500, d: 1.2, type: 'lowpass', out: o }); arp([67, 71, 74, 79], 0.15, 'marimba', 0.18); break;
      case 'morning': arp([72, 76, 79], 0.12, 'glock', 0.12); break;
      case 'save': arp([79, 84], 0.06, 'glock', 0.1); break;
    }
  }
  // Cartoon "babble" voice: short pitched syllables.
  voice(pitch = 1, syllables = 3) {
    if (!this.ctx || this.ctx.state !== 'running') return;
    const t = this.ctx.currentTime;
    for (let i = 0; i < syllables; i++) {
      const f = 330 * pitch * (0.85 + Math.random() * 0.4), at = t + i * 0.085;
      const c = this.ctx, osc = c.createOscillator(), flt = c.createBiquadFilter(), g = c.createGain();
      osc.type = 'square'; osc.frequency.setValueAtTime(f, at); osc.frequency.linearRampToValueAtTime(f * (Math.random() < 0.5 ? 1.15 : 0.9), at + 0.06);
      flt.type = 'bandpass'; flt.frequency.value = 900 + Math.random() * 900; flt.Q.value = 2;
      this.env(g, at, 0.005, 0.05, 0.06); osc.connect(flt); flt.connect(g); g.connect(this.sfxGain); osc.start(at); osc.stop(at + 0.1);
    }
  }
}
