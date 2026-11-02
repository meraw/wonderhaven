// Construction rules: footprints, rotation, snapping height, support, collisions and building zones. Pure.
import { PIECE, SPAN_LIMIT } from '../data/pieces.js';
import { terrainHeight, WALKABLE_MIN, WATER_Y, isStreamCell } from './heightfield.js';
import { circleBox, STEP_UP } from './walk.js';

export const SIDES = ['N', 'E', 'S', 'W'];
export const SIDE_DIR = { N: [0, -1], E: [1, 0], S: [0, 1], W: [-1, 0] };
export const OPPOSITE = { N: 'S', S: 'N', E: 'W', W: 'E' };
export const MAX_HEIGHT = 7;
export const rotSide = (side, r) => SIDES[(SIDES.indexOf(side) + r) % 4];
const EPS = 0.02;

export function footprint(def, r) { const [w, d] = def.size; return r % 2 ? [d, w] : [w, d]; }
export function localToWorld(def, pl, u, v) {
  const [w, d] = def.size, [fw, fd] = footprint(def, pl.r);
  let x = u - w / 2, z = v - d / 2;
  for (let n = 0; n < pl.r; n++) { const t = x; x = -z; z = t; }
  return [pl.i + fw / 2 + x, pl.k + fd / 2 + z];
}
export function worldToLocal(def, pl, x, z) {
  const [w, d] = def.size, [fw, fd] = footprint(def, pl.r);
  let lx = x - (pl.i + fw / 2), lz = z - (pl.k + fd / 2);
  for (let n = 0; n < pl.r; n++) { const t = lx; lx = lz; lz = -t; }
  return [lx + w / 2, lz + d / 2];
}
function localBox(def) {
  if (def.attach === 'wall') return [0.15, 0.19, 0.85, 0.26];
  return def.box || [0, 0, def.size[0], def.size[1]];
}
export function rectOf(def, pl, box = localBox(def)) {
  const [u0, v0, u1, v1] = box;
  const pts = [localToWorld(def, pl, u0, v0), localToWorld(def, pl, u1, v1)];
  return { minX: Math.min(pts[0][0], pts[1][0]), maxX: Math.max(pts[0][0], pts[1][0]), minZ: Math.min(pts[0][1], pts[1][1]), maxZ: Math.max(pts[0][1], pts[1][1]) };
}
export function bounds(pl) {
  const def = PIECE[pl.id];
  return { ...rectOf(def, pl), bottom: pl.y, top: pl.y + def.h };
}
export function cells(pl) {
  const [fw, fd] = footprint(PIECE[pl.id], pl.r), out = [];
  for (let a = 0; a < fw; a++) for (let b = 0; b < fd; b++) out.push([pl.i + a, pl.k + b]);
  return out;
}
const overlap2 = (a, b, e = EPS) => a.minX < b.maxX - e && a.maxX > b.minX + e && a.minZ < b.maxZ - e && a.maxZ > b.minZ + e;
const overlap3 = (a, b) => overlap2(a, b) && a.bottom < b.top - EPS && a.top > b.bottom + EPS;
const groundAt = (env, i, k) => (env.heightAt || terrainHeight)(i + 0.5, k + 0.5);

// Zones -----------------------------------------------------------------------------------------
export function zoneBounds(zone, harmony = 0) {
  return zone.expanded && harmony >= zone.expanded.harmony ? zone.expanded : zone;
}
export function zoneContainsCell(zone, i, k, harmony = 0) {
  const b = zoneBounds(zone, harmony);
  return i >= b.minI && i <= b.maxI && k >= b.minK && k <= b.maxK;
}
export function zoneAt(zones, i, k, harmony = 0) { return zones.find(z => zoneContainsCell(z, i, k, harmony)) || null; }

// Where does a piece rest if the cursor is over cell (i, k) and the ray hit height hitY?
export function suggestBottom(id, i, k, r, hitY, placements, env = {}) {
  const def = PIECE[id];
  const probe = { id, i, k, r, y: 0 };
  const rect = rectOf(def, probe, [0, 0, def.size[0], def.size[1]]);
  let g = -Infinity;
  for (const [ci, ck] of cells(probe)) g = Math.max(g, groundAt(env, ci, ck));
  if (def.placeOn === 'stream') return WATER_Y + 0.05;
  let base = g;
  const zone = env.zone;
  if (def.span && g < WALKABLE_MIN && zone && zone.spanY !== undefined) base = zone.spanY;
  let stackTop = -Infinity;
  for (const q of placements) {
    const qd = PIECE[q.id];
    if (!(qd.walkable || (def.needsSupport && (qd.edge || q.id === 'pillar')))) continue;
    const qt = q.y + qd.h;
    if (qt > hitY + 0.35) continue;
    if (overlap2(rect, bounds(q), 0.05)) stackTop = Math.max(stackTop, qt);
  }
  if (stackTop > -Infinity && stackTop >= base - 0.01) base = stackTop;
  return base;
}

// Support ---------------------------------------------------------------------------------------
function restsOn(pl, q) {
  const def = PIECE[pl.id], qd = PIECE[q.id];
  if (!(qd.walkable || (def.needsSupport && (qd.edge || q.id === 'pillar')))) return false;
  if (Math.abs(q.y + qd.h - pl.y) > 0.05) return false;
  return overlap2(rectOf(def, pl, [0, 0, def.size[0], def.size[1]]), bounds(q), 0.05);
}
function overWater(pl, env) { return cells(pl).some(([i, k]) => groundAt(env, i, k) < WALKABLE_MIN); }
function baseSupported(pl, placements, sup, env) {
  const def = PIECE[pl.id];
  if (def.attach === 'wall') return placements.some(q => sup.has(q.uid) && PIECE[q.id].edge && PIECE[q.id].h >= 2 && q.i === pl.i && q.k === pl.k && q.r === pl.r);
  if (def.placeOn === 'stream') return cells(pl).every(([i, k]) => isStreamCell(i, k));
  for (const q of placements) if (q !== pl && sup.has(q.uid) && restsOn(pl, q)) return true;
  if (def.span && env.fixedSupports && env.fixedSupports.has(`${pl.i},${pl.k}`) && Math.abs(pl.y - (env.zoneSpanY ?? 0)) < 0.1) return true;
  if (def.needsSupport) return false;
  let g = -Infinity, wet = false;
  for (const [i, k] of cells(pl)) { const h = groundAt(env, i, k); g = Math.max(g, h); if (h < WALKABLE_MIN) wet = true; }
  if (Math.abs(pl.y - g) < 0.08 && (!wet || def.post)) return true;
  return false;
}
// Returns { supported: Set(uid), chain: Map(uid -> distance from an anchor) }
export function computeSupport(placements, env = {}) {
  const sup = new Set(), chain = new Map();
  for (let guard = 0; guard < 30; guard++) {
    let changed = false;
    for (const pl of placements) if (!sup.has(pl.uid) && baseSupported(pl, placements, sup, env)) { sup.add(pl.uid); changed = true; }
    const spans = placements.filter(p => PIECE[p.id].span);
    const anchors = spans.filter(p => sup.has(p.uid) && !chain.has(p.uid));
    const dist = new Map(anchors.map(a => [a.uid, 0]));
    const queue = [...anchors];
    while (queue.length) {
      const p = queue.shift(), d = dist.get(p.uid);
      if (d >= SPAN_LIMIT) continue;
      for (const n of spans) {
        if (dist.has(n.uid) || Math.abs(n.i - p.i) + Math.abs(n.k - p.k) !== 1 || Math.abs(n.y - p.y) > 0.3) continue;
        if (!overWater(n, env) && !sup.has(n.uid)) continue;   // chain only reaches out over water
        dist.set(n.uid, d + 1); queue.push(n);
      }
    }
    for (const [uid, d] of dist) if (!sup.has(uid)) { sup.add(uid); chain.set(uid, d); changed = true; }
    if (!changed) break;
  }
  return { supported: sup, chain };
}

// Validation ------------------------------------------------------------------------------------
// ctx: { placements, zones (unlocked), harmony, statics, bodies: [{x,z,r,y}], env }
export function validatePlacement(pl, ctx) {
  const def = PIECE[pl.id];
  if (!def) return { ok: false, reason: 'Unknown piece' };
  const zones = ctx.zones || [];
  const cs = cells(pl);
  const zone = zoneAt(zones, cs[0][0], cs[0][1], ctx.harmony);
  if (!zone || !cs.every(([i, k]) => zoneContainsCell(zone, i, k, ctx.harmony))) {
    const locked = ctx.lockedZones && zoneAt(ctx.lockedZones, cs[0][0], cs[0][1], ctx.harmony);
    return { ok: false, reason: locked ? `${locked.name} isn't open for building yet` : 'Outside a building area — look for the glowing grid' };
  }
  const b = bounds(pl);
  if (b.top > MAX_HEIGHT) return { ok: false, reason: 'Too high for the Starforge Tool to reach' };
  const env = { ...(ctx.env || {}), zone, fixedSupports: new Set((zone.fixedSupports || []).map(([i, k]) => `${i},${k}`)), zoneSpanY: zone.spanY };
  if (def.placeOn === 'stream' && !cs.every(([i, k]) => isStreamCell(i, k))) return { ok: false, reason: 'A waterwheel needs flowing water underneath' };
  if (!def.span && !def.post && def.placeOn !== 'stream' && def.attach !== 'wall') {
    const onPiece = ctx.placements.some(q => q.uid !== pl.uid && restsOn(pl, q));
    if (!onPiece && overWater(pl, env)) return { ok: false, reason: "That would sink! Use bridge planks and posts over water" };
  }
  for (const q of ctx.placements) {
    if (q.uid === pl.uid) continue;
    if (overlap3(b, bounds(q))) return { ok: false, reason: `Bumps into the ${PIECE[q.id].name.toLowerCase()}` };
  }
  for (const s of ctx.statics || []) {
    if (s.flag && ctx.flags?.[s.flag]) continue;
    const hit = s.type === 'circle' ? circleBox(s.x, s.z, s.r, shrink(b, 0.05)) : overlap2(b, s, 0.05);
    if (hit) return { ok: false, reason: 'Something is already in the way there' };
  }
  if (def.solid !== false && !(def.walkable && def.h <= STEP_UP)) {
    for (const body of ctx.bodies || []) {
      if (b.bottom < (body.y ?? 0) + 1.2 && circleBox(body.x, body.z, body.r, shrink(b, 0.05))) return { ok: false, reason: body.name ? `${body.name} is standing there` : "You're standing there!" };
    }
  }
  const all = [...ctx.placements.filter(q => q.uid !== pl.uid), pl];
  const { supported } = computeSupport(all, env);
  if (!supported.has(pl.uid)) {
    if (def.span) return { ok: false, reason: `Too far from a support — planks reach ${SPAN_LIMIT} tiles. Add a bridge post, or build out from the other bank` };
    if (def.attach === 'wall') return { ok: false, reason: 'Paintings hang on walls' };
    if (def.needsSupport) return { ok: false, reason: 'Roofs need walls or pillars underneath' };
    return { ok: false, reason: 'Needs something solid underneath' };
  }
  return { ok: true, zone };
}
function shrink(b, e) { return { minX: b.minX + e, maxX: b.maxX - e, minZ: b.minZ + e, maxZ: b.maxZ - e }; }

// Can this piece be removed without leaving anything floating?
export function validateRemoval(uid, ctx) {
  const target = ctx.placements.find(p => p.uid === uid);
  if (!target) return { ok: false, reason: 'Nothing there' };
  const envFor = pl => { const zone = zoneAt(ctx.zones || [], pl.i, pl.k, ctx.harmony) || {}; return { ...(ctx.env || {}), fixedSupports: new Set((zone.fixedSupports || []).map(([i, k]) => `${i},${k}`)), zoneSpanY: zone.spanY }; };
  const env = envFor(target);
  const before = computeSupport(ctx.placements, env).supported;
  const rest = ctx.placements.filter(p => p.uid !== uid);
  const after = computeSupport(rest, env).supported;
  const orphan = rest.find(p => before.has(p.uid) && !after.has(p.uid));
  if (orphan) return { ok: false, reason: `The ${PIECE[orphan.id].name.toLowerCase()} rests on it — remove that first` };
  return { ok: true };
}

// Walk surfaces and colliders produced by placed pieces.
export function surfacesFor(placements) {
  const out = [];
  for (const pl of placements) {
    const def = PIECE[pl.id];
    if (def.attach) continue;
    const b = bounds(pl);
    if (def.door) {
      const posts = [[0, 0, 0.14, 0.18], [0.86, 0, 1, 0.18]];
      if (!pl.state?.open) posts.push([0.14, 0, 0.86, 0.18]);
      for (const bx of posts) out.push({ ...rectOf(def, pl, bx), bottom: b.bottom, top: b.top, walkable: false, solid: true, uid: pl.uid });
      out.push({ ...rectOf(def, pl, [0, 0, 1, 0.18]), bottom: b.bottom + 1.95, top: b.top, walkable: false, solid: true, uid: pl.uid });
      continue;
    }
    const s = { ...b, walkable: !!def.walkable, solid: def.solid !== false, uid: pl.uid };
    if (def.ramp) {
      s.topAt = (x, z) => { const [, v] = worldToLocal(def, pl, x, z); const t = 1 - Math.max(0, Math.min(1, v / def.size[1])); return pl.y + def.h * t; };
    }
    if (def.solid === false && !def.walkable) continue;
    out.push(s);
  }
  return out;
}

export function canAfford(inv, cost) { return Object.entries(cost).every(([k, n]) => (inv[k] || 0) >= n); }
