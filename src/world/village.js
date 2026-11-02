// Assembles Hearthglow Village from the layout data: terrain, buildings, decor, resource nodes and features.
import * as THREE from 'three';
import * as P from './props.js';
import { mat, mesh, COLORS } from './palette.js';
import { createTerrain, createWater, createSky } from './terrain.js';
import { terrainHeight } from '../systems/heightfield.js';
import { BUILDINGS, NODES, FEATURES, FOUNTAIN, HARBOR_GATE, HARBOR_CLIFFS, ZONES } from '../data/village-layout.js';

function instanced(geo, material, items, place) {
  const im = new THREE.InstancedMesh(geo, material, items.length);
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), p = new THREE.Vector3(), c = new THREE.Color(), e = new THREE.Euler();
  items.forEach((it, i) => { const r = place(it, p, e, s, c); q.setFromEuler(e); m.compose(p, q, s); im.setMatrixAt(i, m); if (r) im.setColorAt(i, c); });
  im.castShadow = true; im.receiveShadow = true;
  return im;
}

export function createVillage(decor) {
  const group = new THREE.Group(); group.name = 'village';
  const objects = {};       // id -> Object3D
  const animated = [];      // { obj, fn(t, dt) }
  const terrain = createTerrain(); group.add(terrain);
  const water = createWater(); group.add(water);
  const sky = createSky(); group.add(sky);
  const H = (x, z) => terrainHeight(x, z);

  // Buildings
  for (const b of BUILDINGS) {
    const builder = { workshop: P.makeWorkshop, castle: P.makeCastle, caravan: P.makeCaravan, hut: P.makeHut }[b.kind] || P.makeCottage;
    const o = builder(b);
    o.position.set(b.x, b.kind === 'castle' ? H(b.x, b.z) - 0.05 : Math.max(0, H(b.x, b.z)) + 0.0, b.z);
    o.name = b.id; group.add(o); objects[b.id] = o;
  }
  // Fountain
  const fountain = P.makeFountain(); fountain.position.set(FOUNTAIN.x, 0, FOUNTAIN.z); group.add(fountain); objects.fountain = fountain;
  // Harbor cliffs, gate, stall, pilings
  for (const c of HARBOR_CLIFFS) {
    const w = c.maxX - c.minX; if (w > 60) continue;
    const cl = P.makeCliff(w, c.maxZ - c.minZ); cl.position.set((c.minX + c.maxX) / 2, H((c.minX + c.maxX) / 2, c.minZ) - 0.3, (c.minZ + c.maxZ) / 2); group.add(cl);
  }
  for (const [x0, x1] of [[-48, 2.5], [7.5, 50]]) { const cl = P.makeCliff(x1 - x0, 1.6); cl.position.set((x0 + x1) / 2, -0.2, 34.8); group.add(cl); }
  const gate = P.makeGate(); gate.position.set((HARBOR_GATE.minX + HARBOR_GATE.maxX) / 2, H(5, 34.7), 34.7); group.add(gate); objects.harborGate = gate;
  const stall = P.makeMarketStall(); stall.position.set(-2, H(-2, 39), 39); stall.rotation.y = 0.2; group.add(stall); objects.stall = stall;
  const dock = ZONES.find(z => z.id === 'dock');
  for (const [i, k] of dock.fixedSupports) { const pl = mesh(new THREE.CylinderGeometry(0.2, 0.24, 2.4, 8), mat('#8a6a50')); pl.position.set(i + 0.5, -1.0, k + 0.5); group.add(pl); const cap = mesh(new THREE.CylinderGeometry(0.26, 0.26, 0.08, 8), mat('#6a4a30')); cap.position.set(i + 0.5, 0.02, k + 0.5); group.add(cap); }
  const moor = mesh(new THREE.CylinderGeometry(0.18, 0.22, 2.6, 8), mat('#8a6a50')); moor.position.set(4.3, -0.6, 50.4); group.add(moor);
  // Old broken bridge posts in the river
  for (const [x, z, r] of [[-1.6, -17.2, 0.3], [1.8, -19.6, -0.4], [-0.4, -20.4, 0.2]]) { const bp = P.makeBrokenPost(); bp.position.set(x, -0.2, z); bp.rotation.z = r; group.add(bp); }
  const plank = mesh(new THREE.BoxGeometry(0.9, 0.1, 1.6), mat('#9a7a5a')); plank.position.set(1.2, -0.36, -16.6); plank.rotation.set(0.1, 0.7, 0.15); group.add(plank);
  // Lamp posts around the square and along roads
  const lamps = [];
  for (const [x, z] of [[-6, -3], [6, -3], [-6, 7.5], [6.8, 7.2], [-20, 5.2], [-30, 6.6], [2, -12.5], [12.6, 1.2], [4.6, 20.6], [20, 6.8], [7.4, 31.5]]) {
    const l = P.makeLampPost(); l.position.set(x, H(x, z), z); group.add(l); lamps.push(l.getObjectByName('bulb'));
  }
  // Fences around Fern's garden and the plot
  for (const [x, z, len, ry] of [[3.4, -12.2, 4, 0], [3.4, -8.0, 4, 0], [1.4, -10.1, 4, Math.PI / 2], [-40, 2.5, 3, 0], [-40, 7.6, 3, 0]]) { const f = P.makeFence(len); f.position.set(x, H(x, z), z); f.rotation.y = ry; group.add(f); }
  // Fern's garden beds (soil)
  for (const [x, z] of [[4.4, -9.4], [6.6, -9.4], [4.4, -11], [6.6, -11]]) { const bed = mesh(new THREE.BoxGeometry(1.6, 0.16, 1.1), mat('#9a6a45')); bed.position.set(x, 0.08, z); group.add(bed); }
  // Spawn pier
  const pier = mesh(new THREE.BoxGeometry(2.2, 0.15, 7), mat('#c49a6c')); pier.position.set(-48.5, 0.05, 5); pier.rotation.y = Math.PI / 2; group.add(pier);

  // Decorative trees (instanced)
  const round = decor.trees.filter(t => t.kind === 'round'), pine = decor.trees.filter(t => t.kind === 'pine');
  group.add(instanced(new THREE.CylinderGeometry(0.16, 0.24, 1.3, 7), mat(COLORS.trunk), decor.trees, (t, p, e, s) => { p.set(t.x, H(t.x, t.z) + 0.65 * t.s, t.z); s.setScalar(t.s); }));
  const leafColors = ['#5cb85c', '#6cc65a', '#4fae63', '#7ccc5a', '#5fbf7a'];
  group.add(instanced(new THREE.IcosahedronGeometry(1, 1), mat('#ffffff', { flatShading: false }), round, (t, p, e, s, c) => { p.set(t.x, H(t.x, t.z) + 1.9 * t.s, t.z); s.set(1.05 * t.s, 0.95 * t.s, 1.05 * t.s); e.set(0, t.hue * 6, 0); c.set(leafColors[Math.floor(t.hue * leafColors.length)]); return true; }));
  group.add(instanced(new THREE.IcosahedronGeometry(0.7, 1), mat('#ffffff'), round, (t, p, e, s, c) => { p.set(t.x + 0.3 * t.s, H(t.x, t.z) + 2.55 * t.s, t.z - 0.1); s.setScalar(t.s); c.set(leafColors[(Math.floor(t.hue * 7) + 1) % leafColors.length]); return true; }));
  for (const [y, r, h] of [[1.2, 1.0, 1.3], [1.9, 0.78, 1.1], [2.5, 0.52, 0.9]])
    group.add(instanced(new THREE.ConeGeometry(r, h, 8), mat(COLORS.pine), pine, (t, p, e, s) => { p.set(t.x, H(t.x, t.z) + y * t.s, t.z); s.setScalar(t.s); }));
  group.add(instanced(new THREE.IcosahedronGeometry(0.5, 1), mat('#ffffff'), decor.bushes, (b, p, e, s, c) => { p.set(b.x, H(b.x, b.z) + 0.25 * b.s, b.z); s.set(b.s * 1.2, b.s * 0.8, b.s); c.set(['#69bf5f', '#5aa65a', '#7dcf6a'][Math.floor(b.hue * 3)]); return true; }));
  const flowerHeads = instanced(new THREE.IcosahedronGeometry(0.09, 0), mat('#ffffff'), decor.flowers, (f, p, e, s, c) => { p.set(f.x, H(f.x, f.z) + 0.26 * f.s, f.z); s.setScalar(f.s); c.set(COLORS.flowers[f.c]); return true; });
  flowerHeads.castShadow = false; group.add(flowerHeads);
  const stems = instanced(new THREE.CylinderGeometry(0.015, 0.015, 0.26, 3), mat('#4f9e45'), decor.flowers, (f, p, e, s) => { p.set(f.x, H(f.x, f.z) + 0.13 * f.s, f.z); s.setScalar(f.s); });
  stems.castShadow = false; group.add(stems);
  const grassGeo = new THREE.ConeGeometry(0.07, 0.32, 3);
  const grass = instanced(grassGeo, mat('#6fbf4f'), decor.grass, (g, p, e, s) => { p.set(g.x, H(g.x, g.z) + 0.14 * g.s, g.z); e.set((g.r - 1.5) * 0.2, g.r, 0); s.setScalar(g.s); });
  grass.castShadow = false; group.add(grass);

  // Resource nodes and features
  const nodeVisuals = {};
  for (const n of NODES) {
    let o;
    switch (n.kind) {
      case 'chop': o = P.makeRoundTree(1.05, (n.x * 7.3) % 1); break;
      case 'mine': o = P.makeRock(n.rich); break;
      case 'clay': o = P.makeClayMound(); break;
      case 'fish': o = P.makeFishingSpot(); break;
      case 'flowers': o = P.makeFlowerPatch(); break;
      case 'shake': o = P.makeOak(); break;
      case 'fruit': o = P.makeRoundTree(0.9, 0.7); { const f = P.addFruit(o); f.visible = false; } break;
      case 'dig': o = P.makeDigSpot(); break;
      case 'chest': o = P.makeChest(); break;
      case 'fragment': o = P.makeFragment(); break;
      default: o = new THREE.Group();
    }
    const y = n.kind === 'fish' ? Math.max(H(n.x, n.z), -0.2) : H(n.x, n.z);
    o.position.set(n.x, y, n.z);
    if (n.kind === 'fragment') o.position.y += 1.0;
    if (n.kind === 'chest') o.rotation.y = Math.atan2(-n.x, -n.z);
    if (n.facing !== undefined) o.rotation.y = n.facing;
    o.name = n.id; group.add(o); objects[n.id] = o; nodeVisuals[n.id] = o;
    if (n.kind === 'chop') {
      const stump = P.makeRock(false, 0.01); stump.visible = false; // placeholder replaced below
      const st = mesh(new THREE.CylinderGeometry(0.24, 0.28, 0.3, 8), mat(COLORS.trunk)); st.position.set(n.x, y + 0.15, n.z); st.visible = false; group.add(st); o.userData.stump = st;
    }
  }
  for (const f of FEATURES) {
    let o;
    if (f.kind === 'sign') o = P.makeSign();
    else if (f.kind === 'board') o = P.makeNoticeBoard();
    else if (f.kind === 'wardrobe') o = P.makeWardrobe();
    else if (f.kind === 'boat') { o = P.makeBoat(); o.visible = false; }
    else o = new THREE.Group();
    o.position.set(f.x, f.kind === 'boat' ? -0.45 : H(f.x, f.z), f.z);
    if (f.kind === 'sign') o.rotation.y = Math.atan2(-f.x, -f.z) * 0 + (f.id === 'welcomeSign' ? Math.PI / 2 : 0);
    if (f.kind === 'wardrobe') o.rotation.y = 0;
    o.name = f.id; group.add(o); objects[f.id] = o;
  }

  const t0 = performance.now();
  function update(dt, t, flags) {
    water.material.uniforms.uTime.value = t;
    animateFountain(t, flags);
    for (const n of NODES) {
      const o = nodeVisuals[n.id];
      if (n.kind === 'fragment' && o.visible) { o.position.y = H(n.x, n.z) + 1.0 + Math.sin(t * 2 + n.x) * 0.15; o.rotation.y = t * 1.5; }
    }
    const gateDoors = gate.getObjectByName('doors');
    const open = flags.harborOpen ? 1 : 0;
    for (const d of gateDoors.children) d.rotation.y = THREE.MathUtils.lerp(d.rotation.y, -d.userData.side * open * 1.6, 1 - Math.exp(-dt * 2));
    gate.getObjectByName('seal').visible = !flags.harborOpen;
    const boat = objects.boat; boat.visible = !!flags.boatReady;
    if (boat.visible) { boat.position.y = -0.45 + Math.sin(t * 1.3) * 0.06; boat.rotation.z = Math.sin(t * 0.9) * 0.03; }
    const ws = objects.workshop;
    ws.getObjectByName('clutter').visible = !flags.workshopDone;
    ws.userData.signGear.rotation.z = flags.workshopDone ? t * 1.5 : 0;
    if (objects.caravan.userData.cog) objects.caravan.userData.cog.rotation.z = t * 0.8;
    for (const l of lamps) l.material.emissiveIntensity = flags.night ? 1.6 : 0.15;
  }
  function animateFountain(t, flags) { P.animateFountain(fountain, t, !!flags.fountainFlowing); }
  return { group, objects, nodeVisuals, terrain, water, sky, update, lamps };
}
