import test from 'node:test';
import assert from 'node:assert/strict';
import { PIECES, PIECE, CATEGORIES } from '../src/data/pieces.js';
import { ZONES, FOUNTAIN } from '../src/data/village-layout.js';
import { footprint, bounds, cells, suggestBottom, validatePlacement, validateRemoval, surfacesFor, localToWorld, worldToLocal, computeSupport } from '../src/systems/build-grid.js';
import { solveMechanics } from '../src/systems/mechanics.js';
import { pathAcross, roomChecklist } from '../src/systems/validate.js';
import { History } from '../src/systems/history.js';
import { WalkWorld, stepMove } from '../src/systems/walk.js';
import { generateDecor, buildStatics } from '../src/systems/world-statics.js';

const zone = id => ZONES.find(z => z.id === id);
const statics = buildStatics(generateDecor());
let uid = 1;
function place(list, id, i, k, r = 0, z = zone('plot'), hitY = 10) {
  const y = suggestBottom(id, i, k, r, hitY, list, { zone: z });
  const pl = { uid: uid++, id, i, k, r, y };
  const v = validatePlacement(pl, { placements: list, zones: [z], statics, bodies: [] });
  if (v.ok) list.push(pl);
  return { pl, ...v };
}

test('the catalog has at least 25 pieces across all four categories', () => {
  assert.ok(PIECES.length >= 25, `${PIECES.length} pieces`);
  for (const c of CATEGORIES) assert.ok(PIECES.some(p => p.cat === c.id), c.id);
  assert.equal(new Set(PIECES.map(p => p.id)).size, PIECES.length, 'ids are unique');
  for (const p of PIECES) assert.ok(p.cost && p.h > 0 && p.size.length === 2, p.id);
});

test('rotation swaps footprints and maps local points consistently', () => {
  const def = PIECE.sofa;
  assert.deepEqual(footprint(def, 0), [2, 1]);
  assert.deepEqual(footprint(def, 1), [1, 2]);
  for (let r = 0; r < 4; r++) {
    const pl = { id: 'sofa', i: 3, k: 4, r, y: 0 };
    const [x, z] = localToWorld(def, pl, 0.3, 0.7);
    const [u, v] = worldToLocal(def, pl, x, z);
    assert.ok(Math.abs(u - 0.3) < 1e-9 && Math.abs(v - 0.7) < 1e-9, `r=${r}`);
    assert.equal(cells(pl).length, 2);
  }
  const wall = { id: 'woodWall', i: 0, k: 0, r: 1, y: 0 };
  const b = bounds(wall);
  assert.ok(b.minX > 0.8 && b.maxX <= 1.0001, 'a wall rotated once sits on the east edge');
});

test('blocks stack vertically, and overlapping placements are refused', () => {
  const list = [];
  assert.ok(place(list, 'stoneBlock', 20, 10).ok);
  const second = place(list, 'stoneBlock', 20, 10, 0, zone('plot'), 1.0);
  assert.ok(second.ok, second.reason);
  assert.ok(Math.abs(second.pl.y - (list[0].y + 1)) < 1e-6, 'second block sits on the first');
  const clash = { uid: 999, id: 'table', i: 20, k: 10, r: 0, y: list[0].y };
  const v = validatePlacement(clash, { placements: list, zones: [zone('plot')], statics, bodies: [] });
  assert.equal(v.ok, false); assert.match(v.reason, /Bumps into/);
});

test('placing outside a zone gives a clear warning; locked zones name themselves', () => {
  const pl = { uid: 5000, id: 'floor', i: -30, k: 30, r: 0, y: 0 };
  const v = validatePlacement(pl, { placements: [], zones: [zone('plot')], statics });
  assert.equal(v.ok, false); assert.match(v.reason, /Outside a building area/);
  const v2 = validatePlacement({ ...pl, i: 0, k: -16 }, { placements: [], zones: [zone('plot')], lockedZones: ZONES, statics });
  assert.match(v2.reason, /Orchard Bridge site/);
});

test('you cannot build on the player', () => {
  const pl = { uid: 6000, id: 'table', i: 20, k: 12, r: 0, y: suggestBottom('table', 20, 12, 0, 5, []) };
  const v = validatePlacement(pl, { placements: [], zones: [zone('plot')], statics, bodies: [{ x: 20.5, z: 12.5, r: 0.3, y: pl.y }] });
  assert.equal(v.ok, false); assert.match(v.reason, /standing/);
});

test('bridge planks need posts: max two tiles out over the water', () => {
  const z = zone('bridge'), list = [];
  for (const k of [-15, -16, -17]) assert.ok(place(list, 'bridgeDeck', 0, k, 0, z).ok, `deck ${k}`);
  const tooFar = place(list, 'bridgeDeck', 0, -18, 0, z);
  assert.equal(tooFar.ok, false); assert.match(tooFar.reason, /bridge post/);
  const post = place(list, 'bridgePost', 0, -18, 0, z, -1.4);
  assert.ok(post.ok, post.reason);
  assert.ok(Math.abs(post.pl.y + 1.4) < 0.01 && Math.abs(post.pl.y + PIECE.bridgePost.h) < 0.01, 'post stands on the river bed and reaches deck height');
  for (const k of [-18, -19, -20, -22, -21]) { const r = place(list, 'bridgeDeck', 0, k, 0, z, 0.1); assert.ok(r.ok, `deck ${k}: ${r.reason}`); }
  // Removing the post would leave planks floating
  const rm = validateRemoval(post.pl.uid, { placements: list, zones: [z] });
  assert.equal(rm.ok, false);
  // Removing the far bank plank is fine
  assert.ok(validateRemoval(list[list.length - 1].uid, { placements: list, zones: [z] }).ok);
});

test('a finished bridge passes the path check and the player physically walks across it', () => {
  const z = zone('bridge'), list = [];
  const walk = new WalkWorld({ statics });
  assert.equal(pathAcross(z, walk).ok, false, 'no path before building');
  for (const k of [-15, -16, -17]) place(list, 'bridgeDeck', 1, k, 0, z);
  place(list, 'bridgePost', 1, -18, 0, z, -1.4);
  for (const k of [-18, -19, -20, -22, -21]) place(list, 'bridgeDeck', 1, k, 0, z, 0.1);
  walk.setSurfaces(surfacesFor(list));
  const r = pathAcross(z, walk);
  assert.ok(r.ok, 'path found');
  let p = { x: 1.5, z: -13.5, y: 0 };
  for (let n = 0; n < 120; n++) p = { ...p, ...stepMove(walk, p, 0, -0.1) };
  assert.ok(p.z < -22.5, `walked across to the orchard bank (z=${p.z.toFixed(2)})`);
  // A railing across the bridge blocks the path
  list.push({ uid: uid++, id: 'railing', i: 1, k: -19, r: 0, y: 0.15 });
  walk.setSurfaces(surfacesFor(list));
  assert.equal(pathAcross(z, walk).ok, false, 'a railing across the deck blocks it');
});

test('a wider 2-plank bridge with posts elsewhere is equally valid (multiple solutions)', () => {
  const z = zone('bridge'), list = [];
  for (const i of [-2, -1]) {
    for (const k of [-15, -16]) place(list, 'bridgeDeck', i, k, 0, z);
    place(list, 'bridgePost', i, -17, 0, z, -1.4);
    place(list, 'bridgePost', i, -20, 0, z, -1.4);
    for (const k of [-17, -18, -19, -20, -21, -22]) { const r = place(list, 'bridgeDeck', i, k, 0, z, 0.1); assert.ok(r.ok, `${i},${k} ${r.reason}`); }
  }
  const walk = new WalkWorld({ statics }); walk.setSurfaces(surfacesFor(list));
  assert.ok(pathAcross(z, walk).ok);
});

test('doors block when closed and let you through when open', () => {
  const door = { uid: 1, id: 'doorWall', i: 20, k: 10, r: 0, y: 0, state: { open: false } };
  const walk = new WalkWorld({ statics: [] });
  walk.setSurfaces(surfacesFor([door]));
  let p = { x: 20.5, z: 11, y: 0 };
  for (let n = 0; n < 20; n++) p = { ...p, ...stepMove(walk, p, 0, -0.1) };
  assert.ok(p.z > 10.1, 'closed door stops you');
  door.state.open = true; walk.setSurfaces(surfacesFor([door]));
  for (let n = 0; n < 20; n++) p = { ...p, ...stepMove(walk, p, 0, -0.1) };
  assert.ok(p.z < 9.9, 'open door lets you through');
});

test('stairs let you climb onto a platform', () => {
  const list = [];
  assert.ok(place(list, 'platform', 20, 10).ok);
  const st = place(list, 'stairs', 20, 12, 0);
  assert.ok(st.ok, st.reason);
  const walk = new WalkWorld({ statics: [] }); walk.setSurfaces(surfacesFor(list));
  let p = { x: 20.5, z: 13.6, y: walk.surfaceAt(20.5, 13.6).y };
  const y0 = p.y;
  for (let n = 0; n < 40; n++) p = { ...p, ...stepMove(walk, p, 0, -0.08) };
  assert.ok(p.y > y0 + 0.9, `climbed to the platform (y=${p.y.toFixed(2)})`);
});

test('paintings hang only on walls; roofs need support', () => {
  const list = [];
  const v = validatePlacement({ uid: 77, id: 'painting', i: 21, k: 10, r: 0, y: 1 }, { placements: list, zones: [zone('plot')], statics });
  assert.equal(v.ok, false);
  const wall = place(list, 'woodWall', 21, 10);
  assert.ok(wall.ok);
  const pt = { uid: 78, id: 'painting', i: 21, k: 10, r: 0, y: wall.pl.y + 0.9 };
  assert.ok(validatePlacement(pt, { placements: list, zones: [zone('plot')], statics }).ok);
  const roof = { uid: 79, id: 'roof', i: 23, k: 12, r: 0, y: 0 };
  assert.equal(validatePlacement(roof, { placements: list, zones: [zone('plot')], statics }).ok, false);
});

test('the fountain mechanism only works when every link is connected and powered', () => {
  const inlets = [{ id: 'fountain', ...FOUNTAIN.inlet }];
  const bp = zone('plaza').blueprint.map(([i, k, id, r = 0], n) => ({ uid: 100 + n, id, i, k, r, y: id === 'waterwheel' ? -0.35 : 0 }));
  let m = solveMechanics(bp, { inlets });
  assert.ok(m.fed.fountain, 'blueprint layout feeds the fountain');
  assert.ok(m.pumps.size === 1 && m.powered.has(bp.find(p => p.id === 'pump').uid));
  // Remove one pipe: water stops at the gap
  m = solveMechanics(bp.filter(p => !(p.id === 'pipe' && p.i === 5)), { inlets });
  assert.equal(m.fed.fountain, false);
  // Remove the gear: pump has no power, so no water at all
  m = solveMechanics(bp.filter(p => p.id !== 'gear'), { inlets });
  assert.equal(m.pumps.size, 0); assert.equal(m.fed.fountain, false);
  // Pipes rotated the wrong way do not connect
  m = solveMechanics(bp.map(p => (p.id === 'pipe' && p.i === 4 ? { ...p, r: 0 } : p)), { inlets });
  assert.equal(m.fed.fountain, false);
  // A lever in the line works as a switch
  const withLever = bp.filter(p => p.id !== 'gear').concat([
    { uid: 300, id: 'gear', i: 9, k: 2, r: 0, y: 0 },
  ]);
  const leverLine = withLever.map(p => p).filter(p => !(p.id === 'gear'));
  leverLine.push({ uid: 301, id: 'lever', i: 9, k: 2, r: 0, y: 0, state: { on: false } }); // N-S: links wheel to nothing on E
  m = solveMechanics(leverLine, { inlets });
  assert.equal(m.fed.fountain, false, 'a lever cannot turn corners and is off');
});

test('a windmill powers a spark lamp through a shaft; a lever switches it', () => {
  const list = [
    { uid: 1, id: 'windmill', i: 20, k: 10, r: 0, y: 0 },
    { uid: 2, id: 'lever', i: 20, k: 11, r: 0, y: 0, state: { on: true } },
    { uid: 3, id: 'poweredLamp', i: 20, k: 12, r: 0, y: 0 },
  ];
  assert.ok(solveMechanics(list).lamps.has(3));
  list[1].state.on = false;
  assert.ok(!solveMechanics(list).lamps.has(3));
  const wheelOnLand = [{ uid: 9, id: 'waterwheel', i: 20, k: 10, r: 0, y: 0 }, { uid: 10, id: 'poweredLamp', i: 20, k: 11, r: 0, y: 0 }];
  assert.ok(!solveMechanics(wheelOnLand).lamps.has(10), 'a waterwheel on dry land does nothing');
});

test('waterwheels can only be placed in flowing water', () => {
  const z = zone('plaza');
  const ok = validatePlacement({ uid: 1, id: 'waterwheel', i: 9, k: 1, r: 0, y: -0.35 }, { placements: [], zones: [z], statics });
  assert.ok(ok.ok, ok.reason);
  const dry = validatePlacement({ uid: 2, id: 'waterwheel', i: 6, k: 3, r: 0, y: -0.35 }, { placements: [], zones: [z], statics });
  assert.equal(dry.ok, false);
});

test('room checklist counts furniture inside the workshop and recoloured pieces', () => {
  const z = zone('workshop');
  const list = [{ uid: 1, id: 'chair', i: -15, k: 8, r: 0, y: 0, color: '#7bd389' }, { uid: 2, id: 'lamp', i: -14, k: 8, r: 0, y: 0 }, { uid: 3, id: 'chair', i: 20, k: 10, r: 0, y: 0 }];
  const res = roomChecklist(z, list, [{ any: ['chair'], label: 'chair' }, { any: ['workbench'], label: 'bench' }, { recolored: true, label: 'colour' }]);
  assert.deepEqual(res.map(r => [r.have, r.ok]), [[1, true], [0, false], [1, true]]);
});

test('undo / redo history', () => {
  const h = new History(); const log = [];
  const apply = (cmd, dir) => { log.push(`${dir}:${cmd.n}`); return { ok: true }; };
  h.push({ n: 1 }); h.push({ n: 2 });
  assert.ok(h.undo(apply).ok); assert.ok(h.undo(apply).ok); assert.equal(h.undo(apply).ok, false);
  assert.ok(h.redo(apply).ok);
  h.push({ n: 3 }); assert.equal(h.canRedo(), false);
  assert.deepEqual(log, ['undo:2', 'undo:1', 'redo:1']);
});

test('dock: planks bridge between the old pilings to the mooring', () => {
  const z = zone('dock'), list = [];
  for (const [i, k] of z.blueprint) { const r = place(list, 'bridgeDeck', i, k, 0, z, 0.2); assert.ok(r.ok, `${i},${k}: ${r.reason}`); }
  const walk = new WalkWorld({ statics, flags: () => true }); walk.setSurfaces(surfacesFor(list));
  assert.ok(pathAcross(z, walk).ok);
});

test('every catalog piece has a 3D model builder', async () => {
  const { allPieceIdsHaveMeshes, BUILDER_IDS } = await import('../src/build/piece-meshes.js');
  assert.ok(allPieceIdsHaveMeshes(), `missing: ${PIECES.filter(p => !BUILDER_IDS.includes(p.id)).map(p => p.id)}`);
});
