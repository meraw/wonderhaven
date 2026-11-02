// Low-poly prop builders for Hearthglow Village. Each returns a THREE.Group positioned at its local origin.
import * as THREE from 'three';
import { mat, mesh, roundedBox, COLORS, uniqueMat } from './palette.js';

const G = () => new THREE.Group();
const cyl = (rt, rb, h, s = 10) => new THREE.CylinderGeometry(rt, rb, h, s);
const sph = (r, w = 12, h = 10) => new THREE.SphereGeometry(r, w, h);

export function makeRoundTree(s = 1, hue = 0.5, fruit = false) {
  const g = G();
  const trunk = mesh(cyl(0.16, 0.24, 1.3), mat(COLORS.trunk)); trunk.position.y = 0.65; g.add(trunk);
  const leaf = new THREE.Color(COLORS.leaf).offsetHSL((hue - 0.5) * 0.06, 0, (hue - 0.5) * 0.08);
  const m = mat('#' + leaf.getHexString());
  for (const [x, y, z, r] of [[0, 1.85, 0, 0.95], [0.5, 1.55, 0.2, 0.62], [-0.45, 1.6, -0.15, 0.6], [0.05, 2.45, 0.05, 0.6]]) {
    const b = mesh(sph(r, 9, 7), m); b.position.set(x, y, z); g.add(b);
  }
  if (fruit) addFruit(g);
  g.scale.setScalar(s);
  return g;
}
export function addFruit(tree) {
  const fruits = G(); fruits.name = 'fruit';
  for (const [x, y, z] of [[0.7, 1.7, 0.5], [-0.6, 1.9, 0.6], [0.2, 1.4, -0.85], [-0.3, 2.4, -0.5], [0.8, 2.1, -0.3]]) {
    const f = mesh(sph(0.13, 8, 6), mat('#ff5a5f')); f.position.set(x, y, z); fruits.add(f);
  }
  tree.add(fruits);
  return fruits;
}
export function makePine(s = 1) {
  const g = G();
  const trunk = mesh(cyl(0.14, 0.2, 0.9), mat(COLORS.trunk)); trunk.position.y = 0.45; g.add(trunk);
  for (const [y, r, h] of [[1.2, 1.0, 1.3], [1.9, 0.78, 1.1], [2.5, 0.52, 0.9]]) {
    const c = mesh(new THREE.ConeGeometry(r, h, 9), mat(COLORS.pine)); c.position.y = y; g.add(c);
  }
  g.scale.setScalar(s);
  return g;
}
export function makeBush(s = 1, color = '#69bf5f') {
  const g = G();
  for (const [x, y, z, r] of [[0, 0.3, 0, 0.45], [0.35, 0.25, 0.1, 0.32], [-0.3, 0.25, -0.1, 0.32]]) { const b = mesh(sph(r, 8, 6), mat(color)); b.position.set(x, y, z); g.add(b); }
  g.scale.setScalar(s);
  return g;
}
export function makeRock(rich = false, s = 1) {
  const g = G();
  const geo = new THREE.DodecahedronGeometry(0.8, 0);
  const r = mesh(geo, mat(COLORS.stone, { flatShading: true })); r.scale.set(1.1, 0.75, 0.95); r.position.y = 0.4; g.add(r);
  const r2 = mesh(new THREE.DodecahedronGeometry(0.45, 0), mat(COLORS.stoneDark, { flatShading: true })); r2.position.set(0.55, 0.25, 0.35); g.add(r2);
  const veinColor = rich ? '#8fe9ff' : '#d9a066';
  for (const [x, y, z] of [[0.3, 0.75, 0.45], [-0.45, 0.55, 0.5], [0.1, 0.5, -0.7]]) {
    const v = mesh(new THREE.OctahedronGeometry(rich ? 0.2 : 0.12, 0), mat(veinColor, { emissive: rich ? '#3fbfff' : '#000000', emissiveIntensity: rich ? 0.6 : 0 })); v.position.set(x, y, z); g.add(v);
  }
  g.scale.setScalar(s);
  return g;
}
export function makeClayMound() {
  const g = G();
  const m = mesh(sph(0.6, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), mat('#d98b5f')); m.scale.set(1.2, 0.5, 1); g.add(m);
  for (const [x, z] of [[0.5, 0.3], [-0.4, 0.4], [0.1, -0.5]]) { const b = mesh(sph(0.18, 7, 5), mat('#c97a50')); b.position.set(x, 0.1, z); g.add(b); }
  return g;
}
export function makeFlowerPatch(colors = COLORS.flowers) {
  const g = G();
  for (let n = 0; n < 9; n++) {
    const a = n * 2.4, r = 0.2 + (n % 3) * 0.22;
    const stem = mesh(cyl(0.02, 0.02, 0.35, 4), mat('#4f9e45'), { shadow: false }); stem.position.set(Math.cos(a) * r, 0.17, Math.sin(a) * r); g.add(stem);
    const head = mesh(sph(0.11, 7, 5), mat(colors[n % colors.length])); head.position.set(Math.cos(a) * r, 0.38, Math.sin(a) * r); g.add(head);
  }
  return g;
}
export function makeChest() {
  const g = G();
  const base = mesh(roundedBox(0.9, 0.45, 0.62, 0.05), mat('#b5733f')); base.position.y = 0.23; g.add(base);
  const lid = G(); lid.name = 'lid'; lid.position.set(0, 0.45, -0.31);
  const lm = mesh(new THREE.CylinderGeometry(0.31, 0.31, 0.9, 12, 1, false, 0, Math.PI), mat('#c98447')); lm.rotation.z = Math.PI / 2; lm.position.z = 0.31; lid.add(lm);
  g.add(lid);
  for (const x of [-0.3, 0.3]) { const band = mesh(new THREE.BoxGeometry(0.08, 0.47, 0.64), mat(COLORS.gold)); band.position.set(x, 0.24, 0); g.add(band); }
  const lock = mesh(new THREE.BoxGeometry(0.14, 0.16, 0.06), mat(COLORS.gold)); lock.position.set(0, 0.42, 0.33); g.add(lock);
  return g;
}
export function makeFragment() {
  const g = G();
  const c = mesh(new THREE.OctahedronGeometry(0.22, 0), mat('#c9a8ff', { emissive: '#9b6bff', emissiveIntensity: 0.8 }), { shadow: false });
  c.scale.y = 1.5; g.add(c);
  return g;
}
export function makeSign(text = '') {
  const g = G();
  const post = mesh(cyl(0.06, 0.07, 1.1, 6), mat(COLORS.woodDark)); post.position.y = 0.55; g.add(post);
  const board = mesh(roundedBox(1.0, 0.55, 0.1, 0.04), mat(COLORS.wood)); board.position.y = 1.05; g.add(board);
  return g;
}
export function makeNoticeBoard() {
  const g = G();
  for (const x of [-0.6, 0.6]) { const p = mesh(cyl(0.07, 0.08, 1.7, 6), mat(COLORS.woodDark)); p.position.set(x, 0.85, 0); g.add(p); }
  const b = mesh(roundedBox(1.4, 0.9, 0.1, 0.04), mat('#d9a066')); b.position.y = 1.2; g.add(b);
  for (const [x, y, c] of [[-0.35, 1.3, '#fff7e0'], [0.25, 1.15, '#ffe0ec'], [-0.1, 0.98, '#e0f4ff']]) { const n = mesh(new THREE.PlaneGeometry(0.4, 0.3), mat(c), { shadow: false }); n.position.set(x, y, 0.06); g.add(n); }
  const roof = mesh(new THREE.BoxGeometry(1.6, 0.08, 0.3), mat('#c25b4a')); roof.position.y = 1.72; g.add(roof);
  return g;
}
export function makeWardrobe() {
  const g = G();
  const body = mesh(roundedBox(0.9, 1.7, 0.5, 0.06), mat('#e9b3c9')); body.position.y = 0.85; g.add(body);
  const mirror = mesh(new THREE.PlaneGeometry(0.55, 1.1), new THREE.MeshBasicMaterial({ color: '#cfefff' })); mirror.position.set(0, 0.95, 0.26); g.add(mirror);
  const top = mesh(new THREE.ConeGeometry(0.55, 0.3, 4), mat('#d48aab')); top.rotation.y = Math.PI / 4; top.position.y = 1.85; g.add(top);
  return g;
}

function addDoor(g, b, color = '#a0623a') {
  const door = mesh(roundedBox(1.0, 1.6, 0.12, 0.05), mat(color));
  const knob = mesh(sph(0.05, 6, 5), mat(COLORS.gold)); knob.position.set(0.3, 0, 0.08); door.add(knob);
  placeOnSide(door, b, b.door, 0.8, b.doorOffset || 0);
  g.add(door);
}
function placeOnSide(obj, b, side, y, offset = 0, out = 0.02) {
  const hw = b.w / 2 + out, hd = b.d / 2 + out;
  if (side === 'S') { obj.position.set(offset, y, hd); }
  if (side === 'N') { obj.position.set(offset, y, -hd); obj.rotation.y = Math.PI; }
  if (side === 'E') { obj.position.set(hw, y, offset); obj.rotation.y = Math.PI / 2; }
  if (side === 'W') { obj.position.set(-hw, y, offset); obj.rotation.y = -Math.PI / 2; }
}
function windowMesh() {
  const w = G();
  const frame = mesh(roundedBox(0.8, 0.8, 0.1, 0.04), mat('#ffffff')); w.add(frame);
  const glass = mesh(new THREE.PlaneGeometry(0.62, 0.62), mat('#9fdcff', { emissive: '#ffcf6b', emissiveIntensity: 0 }), { shadow: false }); glass.position.z = 0.055; glass.name = 'glass'; w.add(glass);
  const bar = mesh(new THREE.BoxGeometry(0.06, 0.62, 0.02), mat('#ffffff')); bar.position.z = 0.06; w.add(bar);
  return w;
}
export function makeCottage(b) {
  const g = G(), h = 2.4;
  const walls = mesh(roundedBox(b.w, h, b.d, 0.12), mat(b.wall)); walls.position.y = h / 2; g.add(walls);
  const base = mesh(new THREE.BoxGeometry(b.w + 0.2, 0.25, b.d + 0.2), mat(COLORS.stoneDark)); base.position.y = 0.12; g.add(base);
  // Gable roof
  const roofGeo = new THREE.CylinderGeometry(0.01, (Math.max(b.w, b.d) / 2) * 1.2, 1.8, 4, 1);
  const roof = mesh(roofGeo, mat(b.roof)); roof.rotation.y = Math.PI / 4; roof.scale.set(b.w / Math.max(b.w, b.d), 1, b.d / Math.max(b.w, b.d)); roof.position.y = h + 0.9; g.add(roof);
  const chimney = mesh(new THREE.BoxGeometry(0.5, 1.2, 0.5), mat('#c97a5a')); chimney.position.set(b.w * 0.25, h + 1.1, -b.d * 0.15); g.add(chimney);
  g.userData.chimney = new THREE.Vector3(b.w * 0.25, h + 1.8, -b.d * 0.15);
  addDoor(g, b);
  const sides = ['N', 'S', 'E', 'W'].filter(s => s !== b.door);
  const glasses = [];
  for (const s of sides) {
    const long = s === 'N' || s === 'S' ? b.w : b.d;
    for (const off of long > 4.5 ? [-long * 0.25, long * 0.25] : [0]) { const w = windowMesh(); placeOnSide(w, b, s, 1.45, off); g.add(w); glasses.push(w.getObjectByName('glass')); }
  }
  for (const off of [-b.w * 0.3, b.w * 0.3]) { if (b.door === 'S' || b.door === 'N') { const w = windowMesh(); placeOnSide(w, b, b.door, 1.45, off); g.add(w); glasses.push(w.getObjectByName('glass')); } }
  g.userData.glasses = glasses;
  if (b.awning) {
    const aw = mesh(new THREE.CylinderGeometry(0.5, 0.5, b.w * 0.8, 12, 1, false, 0, Math.PI), mat(b.awning)); aw.rotation.z = Math.PI / 2; aw.rotation.x = -Math.PI / 2;
    placeOnSide(aw, b, b.door, 2.05, 0, 0.3); aw.rotation.set(0, 0, Math.PI / 2); g.add(aw);
  }
  return g;
}
export function makeWorkshop(b) {
  const g = G(), h = 2.6, t = 0.35;
  const hw = b.w / 2, hd = b.d / 2;
  const wallMat = uniqueMat(b.wall);
  const g0 = b.doorAt - b.z - b.doorWidth / 2, g1 = b.doorAt - b.z + b.doorWidth / 2;
  const walls = G(); walls.name = 'walls';
  const add = (w, d, x, z) => { const m = mesh(new THREE.BoxGeometry(w, h, d), wallMat); m.position.set(x, h / 2, z); walls.add(m); };
  add(b.w, t, 0, -hd + t / 2); add(b.w, t, 0, hd - t / 2); add(t, b.d, -hw + t / 2, 0);
  add(t, g0 + hd, hw - t / 2, (-hd + g0) / 2); add(t, hd - g1, hw - t / 2, (g1 + hd) / 2);
  const lintel = mesh(new THREE.BoxGeometry(t, h - 1.9, g1 - g0), wallMat); lintel.position.set(hw - t / 2, 1.9 + (h - 1.9) / 2, (g0 + g1) / 2); walls.add(lintel);
  g.add(walls);
  const floor = mesh(new THREE.BoxGeometry(b.w - 0.2, 0.06, b.d - 0.2), mat('#d9b48a')); floor.position.y = 0.03; floor.receiveShadow = true; g.add(floor);
  // Plank pattern
  for (let x = -hw + 0.6; x < hw; x += 0.9) { const line = mesh(new THREE.BoxGeometry(0.03, 0.065, b.d - 0.3), mat('#c49a6c'), { shadow: false }); line.position.set(x, 0.035, 0); g.add(line); }
  const roofMat = uniqueMat(b.roof, { transparent: true });
  const roof = G(); roof.name = 'roof';
  const rp = mesh(new THREE.CylinderGeometry(0.01, (Math.max(b.w, b.d) / 2) * 1.22, 2.0, 4, 1), roofMat); rp.rotation.y = Math.PI / 4; rp.scale.set(b.w / Math.max(b.w, b.d), 1, b.d / Math.max(b.w, b.d)); rp.position.y = h + 1.0; roof.add(rp);
  const ceiling = mesh(new THREE.BoxGeometry(b.w, 0.1, b.d), roofMat); ceiling.position.y = h + 0.05; roof.add(ceiling);
  g.add(roof);
  g.userData.roofMat = roofMat; g.userData.wallMat = wallMat;
  const sign = mesh(roundedBox(1.6, 0.5, 0.1, 0.05), mat('#8b5a3c')); sign.position.set(hw + 0.1, 2.25, b.doorAt - b.z - 1.6); sign.rotation.y = Math.PI / 2; g.add(sign);
  const gear = mesh(new THREE.TorusGeometry(0.22, 0.07, 6, 10), mat(COLORS.gold)); gear.position.set(hw + 0.17, 2.25, b.doorAt - b.z - 1.6); gear.rotation.y = Math.PI / 2; g.add(gear);
  g.userData.signGear = gear;
  for (const off of [-1.8, 1.8]) { const w = windowMesh(); placeOnSide(w, b, 'S', 1.5, off); g.add(w); }
  for (const off of [-2, 2]) { const w = windowMesh(); placeOnSide(w, b, 'N', 1.5, off); g.add(w); }
  // Neglect: dusty crates and cobwebs inside (removed when restored)
  const clutter = G(); clutter.name = 'clutter';
  for (const [x, z, s] of [[-3.3, -2.4, 0.6], [-3.6, 2.4, 0.5], [2.6, 2.6, 0.55]]) { const c = mesh(roundedBox(s, s, s, 0.04), mat('#a88a6a')); c.position.set(x, s / 2, z); c.rotation.y = x; clutter.add(c); }
  for (const [x, z, ry] of [[-hw + 0.4, -hd + 0.4, 0.8], [-hw + 0.4, hd - 0.4, -0.8]]) { const w = mesh(new THREE.CircleGeometry(0.5, 6), new THREE.MeshBasicMaterial({ color: '#e8e8e8', transparent: true, opacity: 0.5, side: THREE.DoubleSide })); w.position.set(x, 2.3, z); w.rotation.set(0, ry, 0); clutter.add(w); }
  g.add(clutter);
  return g;
}
export function makeCaravan(b) {
  const g = G();
  const body = mesh(roundedBox(b.w, 1.7, b.d, 0.3), mat(b.wall)); body.position.y = 1.35; g.add(body);
  const roof = mesh(new THREE.CylinderGeometry(b.d / 2 + 0.15, b.d / 2 + 0.15, b.w + 0.2, 14, 1, false, 0, Math.PI), mat(b.roof)); roof.rotation.z = Math.PI / 2; roof.rotation.y = Math.PI / 2; roof.rotation.set(0, 0, Math.PI / 2); roof.position.y = 2.15; roof.rotation.x = Math.PI / 2; g.add(roof);
  for (const [x, z] of [[-1.2, b.d / 2], [1.2, b.d / 2], [-1.2, -b.d / 2], [1.2, -b.d / 2]]) { const wh = mesh(new THREE.TorusGeometry(0.35, 0.08, 6, 12), mat('#8b5a3c')); wh.position.set(x, 0.38, z); g.add(wh); }
  const chimney = mesh(cyl(0.12, 0.12, 0.7), mat('#555')); chimney.position.set(1.3, 2.9, 0); g.add(chimney);
  const cog = mesh(new THREE.TorusGeometry(0.3, 0.09, 6, 8), mat(COLORS.gold)); cog.position.set(0, 1.5, b.d / 2 + 0.05); g.add(cog); g.userData.cog = cog;
  addDoor(g, { ...b, doorOffset: 0 }, '#7a4a8a');
  return g;
}
export function makeHut(b) { return makeCottage({ ...b, w: b.w, d: b.d }); }
export function makeCastle(b) {
  const g = G();
  const keep = mesh(roundedBox(b.w - 2, 4.2, b.d - 2, 0.15), mat(b.wall)); keep.position.y = 2.1; g.add(keep);
  const wallH = 2.4;
  const walls = mesh(roundedBox(b.w, wallH, b.d, 0.12), mat('#eadfcd')); walls.position.y = wallH / 2; g.add(walls);
  for (let x = -b.w / 2 + 0.4; x <= b.w / 2 - 0.4; x += 0.9) for (const z of [-b.d / 2, b.d / 2]) { const c = mesh(new THREE.BoxGeometry(0.45, 0.45, 0.4), mat('#eadfcd')); c.position.set(x, wallH + 0.22, z); g.add(c); }
  for (const [x, z] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    const tw = mesh(cyl(1.0, 1.1, 5.2, 14), mat(b.wall)); tw.position.set(x * b.w / 2, 2.6, z * b.d / 2); g.add(tw);
    const cone = mesh(new THREE.ConeGeometry(1.3, 2.2, 14), mat(b.roof)); cone.position.set(x * b.w / 2, 6.3, z * b.d / 2); g.add(cone);
    const flagPole = mesh(cyl(0.03, 0.03, 0.9, 4), mat('#666')); flagPole.position.set(x * b.w / 2, 7.8, z * b.d / 2); g.add(flagPole);
    const flag = mesh(new THREE.PlaneGeometry(0.6, 0.35), mat('#ff6f91', { side: THREE.DoubleSide })); flag.position.set(x * b.w / 2 + 0.3, 8.05, z * b.d / 2); g.add(flag);
  }
  const keepRoof = mesh(new THREE.ConeGeometry((b.w - 2) * 0.62, 2.6, 4), mat(b.roof)); keepRoof.rotation.y = Math.PI / 4; keepRoof.position.y = 5.5; keepRoof.scale.z = (b.d - 2) / (b.w - 2); g.add(keepRoof);
  const gate = mesh(roundedBox(0.15, 2.0, 1.6, 0.06), mat('#7a4a2a')); gate.position.set(-b.w / 2 - 0.05, 1.0, 0); g.add(gate);
  const arch = mesh(new THREE.TorusGeometry(0.8, 0.12, 6, 12, Math.PI), mat(COLORS.stoneDark)); arch.position.set(-b.w / 2 - 0.08, 2.0, 0); arch.rotation.y = Math.PI / 2; g.add(arch);
  const banner = mesh(new THREE.PlaneGeometry(0.9, 1.6), mat('#ff6f91', { side: THREE.DoubleSide })); banner.position.set(-b.w / 2 - 0.08, 3.4, 0); banner.rotation.y = -Math.PI / 2; g.add(banner);
  const star = mesh(new THREE.OctahedronGeometry(0.25), mat(COLORS.gold)); star.position.set(-b.w / 2 - 0.12, 3.5, 0); g.add(star);
  for (const z of [-2.2, 2.2]) { const w = windowMesh(); w.position.set(-b.w / 2 - 0.02, 1.5, z); w.rotation.y = -Math.PI / 2; g.add(w); }
  return g;
}
export function makeFountain() {
  const g = G();
  const basin = mesh(cyl(1.7, 1.85, 0.6, 24), mat(COLORS.stone)); basin.position.y = 0.3; g.add(basin);
  const inner = mesh(cyl(1.45, 1.45, 0.62, 24), mat('#b8b0a4')); inner.position.y = 0.32; g.add(inner);
  const column = mesh(cyl(0.25, 0.35, 1.4, 12), mat(COLORS.stone)); column.position.y = 1.0; g.add(column);
  const bowl = mesh(cyl(0.75, 0.35, 0.3, 16), mat(COLORS.stone)); bowl.position.y = 1.7; g.add(bowl);
  const topper = mesh(new THREE.OctahedronGeometry(0.22), mat('#c9a8ff', { emissive: '#7a5cff', emissiveIntensity: 0 })); topper.position.y = 2.15; topper.name = 'topper'; g.add(topper);
  const water = mesh(cyl(1.42, 1.42, 0.05, 24), new THREE.MeshLambertMaterial({ color: '#6fd8ee', transparent: true, opacity: 0.85 }), { shadow: false }); water.position.y = 0.5; water.name = 'pool'; water.visible = false; g.add(water);
  const bowlWater = mesh(cyl(0.66, 0.66, 0.04, 16), new THREE.MeshLambertMaterial({ color: '#6fd8ee', transparent: true, opacity: 0.85 }), { shadow: false }); bowlWater.position.y = 1.82; bowlWater.name = 'bowlWater'; bowlWater.visible = false; g.add(bowlWater);
  const cracks = G(); cracks.name = 'cracks';
  for (let n = 0; n < 6; n++) { const w = mesh(new THREE.ConeGeometry(0.12, 0.4, 4), mat('#8a9a5a')); const a = n * 1.1; w.position.set(Math.cos(a) * 1.2, 0.75, Math.sin(a) * 1.2); w.rotation.z = Math.sin(a) * 0.4; cracks.add(w); }
  g.add(cracks);
  // Water jets (animated when flowing)
  const jets = G(); jets.name = 'jets'; jets.visible = false;
  const jm = new THREE.MeshBasicMaterial({ color: '#c9f6ff', transparent: true, opacity: 0.7 });
  for (let n = 0; n < 6; n++) { const d = mesh(sph(0.07, 6, 4), jm, { shadow: false }); d.userData.phase = n / 6; jets.add(d); }
  for (let n = 0; n < 8; n++) { const d = mesh(sph(0.06, 6, 4), jm, { shadow: false }); d.userData.phase = n / 8; d.userData.ring = true; jets.add(d); }
  g.add(jets);
  // Inlet pipe stub on the east side (where the plaza pipes connect)
  const stub = mesh(cyl(0.16, 0.16, 0.5, 10), mat('#8a8f9a')); stub.rotation.z = Math.PI / 2; stub.position.set(1.9, 0.35, 0.5); g.add(stub);
  return g;
}
export function animateFountain(g, t, flowing) {
  const jets = g.getObjectByName('jets');
  jets.visible = flowing;
  g.getObjectByName('pool').visible = flowing;
  g.getObjectByName('bowlWater').visible = flowing;
  g.getObjectByName('cracks').visible = !flowing;
  const topper = g.getObjectByName('topper');
  topper.material.emissiveIntensity = flowing ? 0.8 : 0;
  topper.rotation.y = t * (flowing ? 1.2 : 0);
  if (!flowing) return;
  for (const d of jets.children) {
    const p = (t * 0.8 + d.userData.phase) % 1;
    if (d.userData.ring) { const a = d.userData.phase * Math.PI * 2; const r = 0.3 + p * 0.5; d.position.set(Math.cos(a) * r, 1.95 + Math.sin(p * Math.PI) * 0.35 - p * 0.15, Math.sin(a) * r); }
    else d.position.set(0, 2.2 + p * 0.6, 0);
    d.scale.setScalar(1 - p * 0.5);
  }
}
export function makeLampPost() {
  const g = G();
  const p = mesh(cyl(0.06, 0.09, 2.2, 8), mat('#4a4a5a')); p.position.y = 1.1; g.add(p);
  const lamp = mesh(sph(0.2, 10, 8), mat('#fff3b0', { emissive: '#ffcf6b', emissiveIntensity: 0.2 })); lamp.position.y = 2.3; lamp.name = 'bulb'; g.add(lamp);
  const cap = mesh(new THREE.ConeGeometry(0.28, 0.2, 8), mat('#4a4a5a')); cap.position.y = 2.5; g.add(cap);
  return g;
}
export function makeFence(len = 2) {
  const g = G();
  for (let x = 0; x <= len; x += 1) { const p = mesh(new THREE.BoxGeometry(0.12, 0.8, 0.12), mat('#f4e6d0')); p.position.set(x - len / 2, 0.4, 0); g.add(p); }
  for (const y of [0.3, 0.6]) { const r = mesh(new THREE.BoxGeometry(len, 0.08, 0.06), mat('#f4e6d0')); r.position.y = y; g.add(r); }
  return g;
}
export function makeBrokenPost() {
  const g = G();
  const p = mesh(cyl(0.16, 0.2, 1.3, 7), mat('#8a6a50')); p.position.y = -0.7; p.rotation.z = 0.25; g.add(p);
  return g;
}
export function makeCliff(w, d) {
  const g = G();
  const n = Math.ceil(w / 2.2);
  for (let i = 0; i < n; i++) {
    const r = mesh(new THREE.DodecahedronGeometry(1.4, 0), mat(i % 2 ? '#b9a993' : '#c8b9a2', { flatShading: true }));
    r.position.set(-w / 2 + (i + 0.5) * (w / n), 0.9 + (i % 3) * 0.25, 0); r.scale.set(1.2, 1.1 + (i % 2) * 0.3, 0.9); r.rotation.y = i * 1.7; g.add(r);
    if (i % 2 === 0) { const b = makeBush(0.8, '#5aa65a'); b.position.set(-w / 2 + (i + 0.5) * (w / n), 2.2, 0.2); g.add(b); }
  }
  return g;
}
export function makeGate() {
  const g = G();
  for (const x of [-2.6, 2.6]) { const p = mesh(roundedBox(0.5, 2.6, 0.5, 0.06), mat(COLORS.stone)); p.position.set(x, 1.3, 0); g.add(p); }
  const doors = G(); doors.name = 'doors';
  for (const s of [-1, 1]) {
    const d = G(); d.position.x = s * 2.35;
    for (let n = 0; n < 4; n++) { const bar = mesh(new THREE.BoxGeometry(0.14, 2, 0.1), mat('#7a4a2a')); bar.position.set(-s * (0.3 + n * 0.55), 1.0, 0); d.add(bar); }
    const rail = mesh(new THREE.BoxGeometry(2.2, 0.14, 0.12), mat('#7a4a2a')); rail.position.set(-s * 1.1, 1.5, 0); d.add(rail);
    const rail2 = rail.clone(); rail2.position.y = 0.5; d.add(rail2);
    d.userData.side = s; doors.add(d);
  }
  g.add(doors);
  const seal = mesh(new THREE.TorusGeometry(0.3, 0.07, 6, 16), mat('#ff6f91', { emissive: '#ff6f91', emissiveIntensity: 0.4 })); seal.position.set(0, 1.4, 0.1); seal.name = 'seal'; g.add(seal);
  return g;
}
export function makeBoat() {
  const g = G();
  const hull = mesh(new THREE.CylinderGeometry(1.1, 0.7, 4.2, 10, 1, false, 0, Math.PI), mat('#e8705a', { side: THREE.DoubleSide })); hull.rotation.x = Math.PI / 2; hull.rotation.y = Math.PI; hull.rotation.set(Math.PI / 2, 0, Math.PI); hull.position.y = 0.4; g.add(hull);
  const deck = mesh(new THREE.BoxGeometry(1.8, 0.08, 4.0), mat('#e0b07a')); deck.position.y = 0.38; g.add(deck);
  const mast = mesh(cyl(0.07, 0.08, 3.4, 6), mat('#8b5a3c')); mast.position.y = 2.0; g.add(mast);
  const sail = mesh(new THREE.PlaneGeometry(1.6, 2.2), mat('#fff7e8', { side: THREE.DoubleSide })); sail.position.set(0, 2.3, 0.15); sail.rotation.y = Math.PI / 2; g.add(sail);
  const flag = mesh(new THREE.PlaneGeometry(0.5, 0.3), mat('#5f9be0', { side: THREE.DoubleSide })); flag.position.set(0, 3.8, 0.25); flag.rotation.y = Math.PI / 2; g.add(flag);
  return g;
}
export function makeDigSpot() {
  const g = G();
  const mound = mesh(sph(0.35, 8, 5, 0, Math.PI * 2, 0, Math.PI / 2), mat('#b88b5e')); mound.scale.y = 0.4; g.add(mound);
  return g;
}
export function makeFishingSpot() {
  const g = G();
  const plat = mesh(new THREE.CylinderGeometry(0.55, 0.6, 0.12, 10), mat('#c9a06e')); plat.position.y = 0.06; g.add(plat);
  return g;
}
export function makeOak() {
  const g = makeRoundTree(1.25, 0.2);
  const acorns = G(); acorns.name = 'acorns';
  for (const [x, z] of [[0.6, 0.5], [-0.5, 0.7], [0.3, -0.7]]) { const a = mesh(sph(0.08, 6, 5), mat('#9a6a3a')); a.position.set(x, 0.05, z); acorns.add(a); }
  g.add(acorns);
  return g;
}
export function makeMarketStall() {
  const g = G();
  const counter = mesh(roundedBox(2.2, 0.9, 0.9, 0.05), mat('#d9a066')); counter.position.y = 0.45; g.add(counter);
  for (const x of [-1, 1]) { const p = mesh(cyl(0.05, 0.05, 2.2, 6), mat('#8b5a3c')); p.position.set(x, 1.1, -0.3); g.add(p); }
  const aw = mesh(new THREE.BoxGeometry(2.5, 0.1, 1.3), mat('#ff8fab')); aw.position.set(0, 2.2, 0); aw.rotation.x = 0.2; g.add(aw);
  for (const [x, c] of [[-0.6, '#ffd84a'], [0, '#7cc35a'], [0.6, '#ff5a5f']]) { const f = mesh(sph(0.16, 8, 6), mat(c)); f.position.set(x, 1.0, 0.1); g.add(f); }
  return g;
}
