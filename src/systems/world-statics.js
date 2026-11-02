// Derives decorative placement and solid colliders from the village layout. Pure and deterministic,
// so the rendered world and the physics agree, and tests can check that roads and zones stay clear.
import { makeRng } from '../core/rng.js';
import { terrainHeight, WALKABLE_MIN } from './heightfield.js';
import { BUILDINGS, ZONES, NODES, FEATURES, PATHS, HARBOR_CLIFFS, HARBOR_GATE, FOUNTAIN, NAV_NODES } from '../data/village-layout.js';

export function distToSegment(px, pz, ax, az, bx, bz) {
  const vx = bx - ax, vz = bz - az, l2 = vx * vx + vz * vz;
  const t = l2 ? Math.max(0, Math.min(1, ((px - ax) * vx + (pz - az) * vz) / l2)) : 0;
  return Math.hypot(px - (ax + t * vx), pz - (az + t * vz));
}
export function distToPaths(x, z, paths = PATHS) {
  let d = Infinity;
  for (const p of paths) for (let n = 0; n < p.length - 1; n++) d = Math.min(d, distToSegment(x, z, p[n][0], p[n][1], p[n + 1][0], p[n + 1][1]));
  return d;
}
function nearBuilding(x, z, pad) {
  return BUILDINGS.some(b => Math.abs(x - b.x) < b.w / 2 + pad && Math.abs(z - b.z) < b.d / 2 + pad);
}
function inZone(x, z, pad) {
  return ZONES.some(zn => { const e = zn.expanded || zn; return x > e.minI - pad && x < e.maxI + 1 + pad && z > e.minK - pad && z < e.maxK + 1 + pad; });
}
function nearPoint(x, z, list, pad) { return list.some(p => Math.hypot(x - p.x, z - p.z) < pad); }

// Places decorative trees, bushes and flowers on free ground.
export function generateDecor(seed = 7) {
  const rng = makeRng(seed);
  const trees = [], bushes = [], flowers = [], grass = [];
  const points = [...NODES, ...FEATURES];
  const navPts = Object.values(NAV_NODES).map(([x, z]) => ({ x, z }));
  const clear = (x, z, pad) => {
    const h = terrainHeight(x, z);
    if (h < WALKABLE_MIN + 0.25) return false;
    if (Math.hypot(x, z) > 50) return false;
    if (distToPaths(x, z) < pad + 1.2) return false;
    if (nearBuilding(x, z, pad + 1)) return false;
    if (inZone(x, z, pad + 0.6)) return false;
    if (Math.hypot(x - FOUNTAIN.x, z - FOUNTAIN.z) < 8 + pad) return false;
    if (nearPoint(x, z, points, pad + 1.6) || nearPoint(x, z, navPts, pad + 1.4)) return false;
    if (z > 33 && z < 37) return false;
    return true;
  };
  for (let n = 0; n < 900 && trees.length < 95; n++) {
    const x = rng.range(-50, 50), z = rng.range(-48, 46);
    const r = Math.hypot(x, z);
    if (r < 12 && rng() < 0.8) continue;
    if (!clear(x, z, 0.9) || trees.some(t => Math.hypot(t.x - x, t.z - z) < 3)) continue;
    trees.push({ x, z, s: rng.range(0.85, 1.3), kind: rng() < 0.3 ? 'pine' : 'round', hue: rng() });
  }
  for (let n = 0; n < 600 && bushes.length < 70; n++) {
    const x = rng.range(-48, 48), z = rng.range(-46, 44);
    if (!clear(x, z, 0.4) || trees.some(t => Math.hypot(t.x - x, t.z - z) < 1.8)) continue;
    bushes.push({ x, z, s: rng.range(0.6, 1.1), hue: rng() });
  }
  for (let n = 0; n < 2500 && flowers.length < 520; n++) {
    const x = rng.range(-48, 48), z = rng.range(-46, 44);
    if (terrainHeight(x, z) < 0 || distToPaths(x, z) < 0.9 || nearBuilding(x, z, 0.3) || inZone(x, z, 0.2) || Math.hypot(x, z) > 49) continue;
    flowers.push({ x, z, c: rng.int(0, 4), s: rng.range(0.7, 1.2) });
  }
  for (let n = 0; n < 4000 && grass.length < 1400; n++) {
    const x = rng.range(-49, 49), z = rng.range(-47, 45);
    if (terrainHeight(x, z) < 0.02 || distToPaths(x, z) < 0.8 || nearBuilding(x, z, 0.1) || Math.hypot(x, z) > 50) continue;
    grass.push({ x, z, r: rng.range(0, Math.PI), s: rng.range(0.6, 1.3) });
  }
  return { trees, bushes, flowers, grass };
}

// Solid colliders for physics.
export function buildStatics(decor) {
  const out = [];
  for (const b of BUILDINGS) {
    const minX = b.x - b.w / 2, maxX = b.x + b.w / 2, minZ = b.z - b.d / 2, maxZ = b.z + b.d / 2;
    if (b.kind === 'workshop') {
      // Hollow, with a doorway in the east wall.
      const t = 0.35, g0 = b.doorAt - b.doorWidth / 2, g1 = b.doorAt + b.doorWidth / 2;
      out.push({ type: 'box', minX, maxX, minZ, maxZ: minZ + t, tag: b.id });
      out.push({ type: 'box', minX, maxX, minZ: maxZ - t, maxZ, tag: b.id });
      out.push({ type: 'box', minX, maxX: minX + t, minZ, maxZ, tag: b.id });
      out.push({ type: 'box', minX: maxX - t, maxX, minZ, maxZ: g0, tag: b.id });
      out.push({ type: 'box', minX: maxX - t, maxX, minZ: g1, maxZ, tag: b.id });
    } else {
      out.push({ type: 'box', minX, maxX, minZ, maxZ, tag: b.id });
    }
  }
  out.push({ type: 'circle', x: FOUNTAIN.x, z: FOUNTAIN.z, r: FOUNTAIN.r + 0.2, tag: 'fountain' });
  for (const c of HARBOR_CLIFFS) out.push({ type: 'box', ...c, tag: 'cliff' });
  out.push({ type: 'box', minX: HARBOR_GATE.minX, maxX: HARBOR_GATE.maxX, minZ: HARBOR_GATE.minZ, maxZ: HARBOR_GATE.maxZ, flag: HARBOR_GATE.flag, tag: 'gate' });
  for (const n of NODES) {
    if (n.kind === 'chop' || n.kind === 'fruit' || n.kind === 'shake') out.push({ type: 'circle', x: n.x, z: n.z, r: 0.45, tag: n.id });
    if (n.kind === 'mine') out.push({ type: 'circle', x: n.x, z: n.z, r: 0.75, tag: n.id });
    if (n.kind === 'chest') out.push({ type: 'box', minX: n.x - 0.45, maxX: n.x + 0.45, minZ: n.z - 0.32, maxZ: n.z + 0.32, tag: n.id });
  }
  for (const f of FEATURES) if (f.kind === 'sign' || f.kind === 'board' || f.kind === 'wardrobe') out.push({ type: 'circle', x: f.x, z: f.z, r: 0.3, tag: f.id });
  for (const t of decor.trees) out.push({ type: 'circle', x: t.x, z: t.z, r: 0.42 * t.s, tag: 'tree' });
  return out;
}
