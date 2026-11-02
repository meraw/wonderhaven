// Particles and floating markers: sparkles, poofs, magic swirls, hearts, quest markers.
import * as THREE from 'three';

function canvasTex(draw, size = 64) {
  const c = document.createElement('canvas'); c.width = c.height = size;
  draw(c.getContext('2d'), size);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
let textures = null;
function tex() {
  if (textures) return textures;
  textures = {
    star: canvasTex((g, s) => {
      const r = s / 2; g.translate(r, r); g.fillStyle = '#fff';
      g.beginPath(); for (let n = 0; n < 8; n++) { const a = n * Math.PI / 4, rr = n % 2 ? r * 0.25 : r * 0.95; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } g.fill();
      const grd = g.createRadialGradient(0, 0, 0, 0, 0, r * 0.5); grd.addColorStop(0, 'rgba(255,255,255,1)'); grd.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = grd; g.fillRect(-r, -r, s, s);
    }),
    puff: canvasTex((g, s) => { const grd = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); grd.addColorStop(0, 'rgba(255,255,255,0.95)'); grd.addColorStop(0.6, 'rgba(255,255,255,0.6)'); grd.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = grd; g.fillRect(0, 0, s, s); }),
    heart: canvasTex((g, s) => { g.fillStyle = '#fff'; g.translate(s / 2, s / 2 + 4); g.beginPath(); g.moveTo(0, 18); g.bezierCurveTo(-34, -6, -14, -30, 0, -12); g.bezierCurveTo(14, -30, 34, -6, 0, 18); g.fill(); }),
    drop: canvasTex((g, s) => { g.fillStyle = '#fff'; g.beginPath(); g.moveTo(s / 2, 6); g.quadraticCurveTo(s - 12, s - 14, s / 2, s - 6); g.quadraticCurveTo(12, s - 14, s / 2, 6); g.fill(); }),
  };
  return textures;
}
export function textSprite(text, { color = '#5a3a2a', bg = '#fff8e8', size = 64, border = '#ffcf6b' } = {}) {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = bg; g.strokeStyle = border; g.lineWidth = 8;
  g.beginPath(); g.arc(64, 60, 46, 0, Math.PI * 2); g.fill(); g.stroke();
  g.beginPath(); g.moveTo(52, 100); g.lineTo(64, 122); g.lineTo(76, 100); g.fill();
  g.fillStyle = color; g.font = `bold ${size}px "Trebuchet MS", sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(text, 64, 64);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: false, transparent: true }));
  s.renderOrder = 10;
  return s;
}

export class Effects {
  constructor(scene) {
    this.scene = scene; this.parts = []; this.group = new THREE.Group(); this.group.name = 'effects'; scene.add(this.group);
    this.materials = new Map();
  }
  material(kind, color) {
    const key = kind + color;
    if (!this.materials.has(key)) this.materials.set(key, new THREE.SpriteMaterial({ map: tex()[kind], color, transparent: true, depthWrite: false, blending: kind === 'puff' ? THREE.NormalBlending : THREE.AdditiveBlending }));
    return this.materials.get(key);
  }
  spawn(kind, color, pos, vel, life, size, gravity = 0, spin = 0) {
    const s = new THREE.Sprite(this.material(kind, color).clone());
    s.position.copy(pos); s.scale.setScalar(size);
    this.group.add(s);
    this.parts.push({ s, vel, life, max: life, size, gravity, spin });
  }
  sparkle(pos, { count = 14, color = '#fff2a8', spread = 0.8, up = 1.6, size = 0.28 } = {}) {
    for (let n = 0; n < count; n++) {
      const a = Math.random() * Math.PI * 2, r = Math.random() * spread;
      this.spawn('star', color, pos.clone().add(new THREE.Vector3(Math.cos(a) * r * 0.3, Math.random() * 0.3, Math.sin(a) * r * 0.3)),
        new THREE.Vector3(Math.cos(a) * r * 1.6, up * (0.5 + Math.random()), Math.sin(a) * r * 1.6), 0.7 + Math.random() * 0.5, size * (0.6 + Math.random() * 0.6), -2.2);
    }
  }
  poof(pos, { count = 10, color = '#ffffff', size = 0.6 } = {}) {
    for (let n = 0; n < count; n++) {
      const a = Math.random() * Math.PI * 2;
      this.spawn('puff', color, pos.clone().add(new THREE.Vector3(0, 0.2, 0)), new THREE.Vector3(Math.cos(a) * 1.4, 0.6 + Math.random() * 0.8, Math.sin(a) * 1.4), 0.6 + Math.random() * 0.3, size * (0.7 + Math.random() * 0.6), 0);
    }
  }
  // Swirling magic column used when a building piece materialises.
  magic(pos, { color = '#c9a8ff', height = 1.2 } = {}) {
    for (let n = 0; n < 22; n++) {
      const a = (n / 22) * Math.PI * 4, r = 0.6;
      this.spawn('star', n % 2 ? color : '#fff2a8', pos.clone().add(new THREE.Vector3(Math.cos(a) * r, (n / 22) * height, Math.sin(a) * r)),
        new THREE.Vector3(-Math.sin(a) * 1.2, 0.8 + Math.random() * 0.6, Math.cos(a) * 1.2), 0.8 + Math.random() * 0.4, 0.25 + Math.random() * 0.15, 0, 0);
    }
  }
  hearts(pos, count = 4) { for (let n = 0; n < count; n++) this.spawn('heart', '#ff7aa8', pos.clone().add(new THREE.Vector3((Math.random() - 0.5) * 0.6, 0, (Math.random() - 0.5) * 0.6)), new THREE.Vector3((Math.random() - 0.5) * 0.4, 1 + Math.random() * 0.5, 0), 1.3, 0.3, 0); }
  splash(pos) { for (let n = 0; n < 12; n++) { const a = Math.random() * Math.PI * 2; this.spawn('drop', '#bff3ff', pos.clone(), new THREE.Vector3(Math.cos(a) * 1.2, 2 + Math.random() * 1.5, Math.sin(a) * 1.2), 0.8, 0.18, -7); } }
  zzz(pos) { this.spawn('puff', '#e8f0ff', pos.clone(), new THREE.Vector3(0.2, 0.5, 0), 1.5, 0.25, 0); }
  smoke(pos) { this.spawn('puff', '#f2f2f2', pos.clone(), new THREE.Vector3(0.2 + Math.random() * 0.2, 0.7, 0.1), 2.6, 0.5, 0); }
  update(dt) {
    for (let i = this.parts.length - 1; i >= 0; i--) {
      const p = this.parts[i];
      p.life -= dt;
      if (p.life <= 0) { this.group.remove(p.s); p.s.material.dispose(); this.parts.splice(i, 1); continue; }
      p.vel.y += p.gravity * dt;
      p.s.position.addScaledVector(p.vel, dt);
      p.vel.multiplyScalar(1 - dt * 1.5);
      const k = p.life / p.max;
      p.s.material.opacity = Math.min(1, k * 2);
      p.s.scale.setScalar(p.size * (0.6 + 0.4 * Math.sin(k * Math.PI)));
    }
  }
}
