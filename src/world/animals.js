// Ambient wildlife: butterflies over flowers, ducks on the river, chickens in Fern's yard.
// Chickens and ducks can be greeted or fed for a little friendship sparkle.
import * as THREE from 'three';
import { mat, mesh } from './palette.js';
import { riverCenter, terrainHeight, WATER_Y } from '../systems/heightfield.js';
import { toast } from '../ui/dom.js';

function butterfly(color) {
  const g = new THREE.Group();
  const wm = new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide });
  for (const s of [-1, 1]) { const w = new THREE.Mesh(new THREE.CircleGeometry(0.09, 8), wm); w.position.x = s * 0.07; w.userData.side = s; g.add(w); }
  g.add(mesh(new THREE.CylinderGeometry(0.01, 0.01, 0.1, 4), mat('#3a2a2a'), { shadow: false }));
  return g;
}
function duck() {
  const g = new THREE.Group();
  const body = mesh(new THREE.SphereGeometry(0.22, 10, 8), mat('#ffffff')); body.scale.set(1, 0.7, 1.3); g.add(body);
  const head = mesh(new THREE.SphereGeometry(0.12, 10, 8), mat('#3c9a4a')); head.position.set(0, 0.2, 0.22); g.add(head);
  const beak = mesh(new THREE.ConeGeometry(0.04, 0.1, 6), mat('#ffb33b')); beak.rotation.x = Math.PI / 2; beak.position.set(0, 0.18, 0.36); g.add(beak);
  return g;
}
function chicken() {
  const g = new THREE.Group();
  const body = mesh(new THREE.SphereGeometry(0.2, 10, 8), mat('#fff7ea')); body.position.y = 0.25; g.add(body);
  const head = mesh(new THREE.SphereGeometry(0.11, 10, 8), mat('#fff7ea')); head.position.set(0, 0.45, 0.13); g.add(head);
  const comb = mesh(new THREE.SphereGeometry(0.05, 6, 5), mat('#ff5a5f')); comb.position.set(0, 0.57, 0.13); g.add(comb);
  const beak = mesh(new THREE.ConeGeometry(0.03, 0.07, 5), mat('#ffb33b')); beak.rotation.x = Math.PI / 2; beak.position.set(0, 0.44, 0.25); g.add(beak);
  for (const s of [-1, 1]) { const leg = mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.12, 4), mat('#ffb33b')); leg.position.set(s * 0.06, 0.06, 0); g.add(leg); }
  g.userData.head = head;
  return g;
}

export class Animals {
  constructor(game) {
    this.game = game; this.t = 0;
    this.butterflies = [];
    const spots = [[-20, -2], [18, -12], [-9, 25], [22, 21], [3, -38], [4, 6], [-6, 4], [12, 18]];
    spots.forEach(([x, z], n) => { for (let k = 0; k < 2; k++) { const b = butterfly(['#ffd84a', '#ff9ec7', '#9fd8ff', '#c9a8ff'][(n + k) % 4]); game.scene.add(b); this.butterflies.push({ obj: b, x, z, ph: Math.random() * 10, sp: 0.6 + Math.random() * 0.5 }); } });
    this.ducks = [-26, -10, 14, 24].map((x, n) => { const d = duck(); game.scene.add(d); return { obj: d, x0: x, ph: n * 1.7, x, z: riverCenter(x) }; });
    this.chickens = [[12.5, -4.2], [14, -6.5], [8.5, -5]].map(([x, z], n) => { const c = chicken(); game.scene.add(c); return { obj: c, home: [x, z], x, z, ph: n * 2.1, yaw: 0, peck: 0 }; });
    this.chickens.forEach((c, n) => game.addInteractable({ id: `chicken${n}`, x: () => c.x, z: () => c.z, radius: 1.1, object: c.obj, label: () => 'Pet the chicken', act: () => this.pet(c, 'chicken') }));
    this.ducks.forEach((d, n) => game.addInteractable({ id: `duck${n}`, x: () => d.x, z: () => d.z + (d.z < riverCenter(d.x) ? 0 : 0), radius: 3.6, object: d.obj, available: () => (game.state.inventory.fruit || 0) > 0, label: () => 'Toss an apple to the duck', act: () => this.pet(d, 'duck') }));
  }
  pet(a, kind) {
    const g = this.game, s = g.state;
    if (kind === 'duck') { s.inventory.fruit--; g.hud.resources(['fruit']); }
    g.effects.hearts(a.obj.position.clone().add(new THREE.Vector3(0, 0.6, 0)), 3);
    g.sfx('squeak');
    a.peck = 1.2;
    const key = `pet_${kind}_${s.time.day}`;
    if (!s.flags[key]) { s.flags[key] = true; g.give({ spark: 2 }); toast(kind === 'duck' ? 'Quack! The duck does a happy little spin.' : 'Bawk! The chicken clucks contentedly.', 'good'); }
    g.story.event('animal');
  }
  update(dt) {
    this.t += dt; const t = this.t, night = this.game.state.flags.night;
    for (const b of this.butterflies) {
      b.obj.visible = !night;
      const a = t * b.sp + b.ph;
      b.obj.position.set(b.x + Math.sin(a) * 1.6 + Math.sin(a * 2.3) * 0.4, terrainHeight(b.x, b.z) + 0.7 + Math.sin(a * 3.1) * 0.3, b.z + Math.cos(a * 0.8) * 1.4);
      b.obj.rotation.y = a;
      for (const w of b.obj.children) if (w.userData.side) w.rotation.y = w.userData.side * Math.sin(t * 18 + b.ph) * 0.9;
    }
    for (const d of this.ducks) {
      d.x = d.x0 + Math.sin(t * 0.15 + d.ph) * 4; d.z = riverCenter(d.x) + Math.sin(t * 0.4 + d.ph) * 1.2;
      d.obj.position.set(d.x, WATER_Y + 0.08 + Math.sin(t * 2 + d.ph) * 0.02, d.z);
      d.obj.rotation.y = Math.cos(t * 0.15 + d.ph) > 0 ? Math.PI / 2 : -Math.PI / 2;
      if (d.peck > 0) { d.peck -= dt; d.obj.rotation.y += t * 6; }
    }
    for (const c of this.chickens) {
      c.ph += dt;
      const tx = c.home[0] + Math.sin(c.ph * 0.3) * 1.5, tz = c.home[1] + Math.cos(c.ph * 0.23) * 1.2;
      const dx = tx - c.x, dz = tz - c.z;
      c.x += dx * dt * 0.8; c.z += dz * dt * 0.8;
      if (Math.hypot(dx, dz) > 0.05) c.yaw = Math.atan2(dx, dz);
      c.obj.position.set(c.x, Math.max(0, terrainHeight(c.x, c.z)) + Math.abs(Math.sin(c.ph * 9)) * 0.03, c.z);
      c.obj.rotation.y = c.yaw;
      c.obj.userData.head.position.y = 0.45 - (Math.sin(c.ph * 3) > 0.7 || c.peck > 0 ? 0.12 : 0);
      if (c.peck > 0) c.peck -= dt;
    }
  }
}
