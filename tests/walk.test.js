import test from 'node:test';
import assert from 'node:assert/strict';
import { WalkWorld, stepMove, STEP_UP } from '../src/systems/walk.js';
import { terrainHeight, riverCenter, isStreamCell, WALKABLE_MIN } from '../src/systems/heightfield.js';
import { generateDecor, buildStatics } from '../src/systems/world-statics.js';
import { SPAWN, NAV_NODES, ZONES } from '../src/data/village-layout.js';

const decor = generateDecor();
const statics = buildStatics(decor);

test('the village core is flat, dry ground and the river is water', () => {
  assert.ok(Math.abs(terrainHeight(0, 2)) < 0.05);
  assert.ok(terrainHeight(0, -18) < WALKABLE_MIN, 'river centre is water');
  assert.ok(terrainHeight(0, -14.5) >= WALKABLE_MIN, 'south bank cell is walkable');
  assert.ok(terrainHeight(0, -21.5) >= WALKABLE_MIN, 'north bank cell is walkable');
  assert.ok(terrainHeight(0, -60) < WALKABLE_MIN, 'the sea surrounds the island');
});

test('bridge zone spans exactly six water cells between two banks', () => {
  const z = ZONES.find(z => z.id === 'bridge');
  const water = [];
  for (let k = z.minK; k <= z.maxK; k++) if (terrainHeight(0.5, k + 0.5) < WALKABLE_MIN) water.push(k);
  assert.deepEqual(water, [-21, -20, -19, -18, -17, -16]);
  assert.ok(isStreamCell(0, -18) && !isStreamCell(0, -15));
});

test('the player cannot walk into the river but can walk along the bank', () => {
  const w = new WalkWorld({ statics });
  const pos = { x: 0, z: -14.5, y: terrainHeight(0, -14.5) };
  let p = pos;
  for (let n = 0; n < 40; n++) p = { ...p, ...stepMove(w, p, 0, -0.1) };
  assert.ok(p.z > -15.1, `stopped at the water's edge (z=${p.z.toFixed(2)})`);
  const side = stepMove(w, p, 0.1, 0);
  assert.ok(side.moved, 'can still move sideways along the bank');
});

test('a deck surface over the water makes it walkable, and walls block', () => {
  const w = new WalkWorld({ statics });
  w.setSurfaces([{ minX: -0.5, maxX: 1.5, minZ: -22, maxZ: -14, bottom: 0, top: 0.15, walkable: true, solid: true }]);
  let p = { x: 0.5, z: -14.5, y: 0 };
  for (let n = 0; n < 90; n++) p = { ...p, ...stepMove(w, p, 0, -0.1) };
  assert.ok(p.z < -21.5, `crossed the river on the deck (z=${p.z.toFixed(2)})`);
  w.setSurfaces([{ minX: 3, maxX: 3.2, minZ: 0, maxZ: 4, bottom: 0, top: 2.2, walkable: false, solid: true }]);
  p = { x: 2, z: 2, y: 0 };
  for (let n = 0; n < 30; n++) p = { ...p, ...stepMove(w, p, 0.1, 0) };
  assert.ok(p.x < 3, 'a wall stops the player');
});

test('steps up to STEP_UP only', () => {
  const w = new WalkWorld({ statics: [] });
  w.setSurfaces([{ minX: 1, maxX: 2, minZ: 1, maxZ: 2, bottom: 0, top: STEP_UP - 0.05, walkable: true, solid: true },
    { minX: 4, maxX: 5, minZ: 1, maxZ: 2, bottom: 0, top: 1, walkable: true, solid: true }]);
  assert.ok(w.canStand(1.5, 1.5, 0), 'low step is climbable');
  assert.equal(w.canStand(4.5, 1.5, 0), null, 'a 1-unit block is not');
  assert.ok(w.canStand(4.5, 1.5, 0.6), 'but you can stand on it from a higher place');
});

test('spawn and every navigation node stand on free, walkable ground', () => {
  const w = new WalkWorld({ statics, flags: () => true });
  assert.ok(w.canStand(SPAWN.x, SPAWN.z, terrainHeight(SPAWN.x, SPAWN.z)), 'spawn');
  for (const [id, [x, z]] of Object.entries(NAV_NODES)) {
    if (id === 'workshopInside') continue;
    assert.ok(w.canStand(x, z, terrainHeight(x, z), 0.3), `nav node ${id} at ${x},${z}`);
  }
});

test('the harbor gate blocks until harborOpen is set', () => {
  let open = false;
  const w = new WalkWorld({ statics, flags: f => f === 'harborOpen' && open });
  assert.ok(w.blocked(5, 34.7, 0.2));
  open = true;
  assert.ok(!w.blocked(5, 34.7, 0.2));
});

test('the river curves but stays continuous', () => {
  for (let x = -40; x <= 40; x += 5) assert.ok(terrainHeight(x, riverCenter(x)) < WALKABLE_MIN, `water at x=${x}`);
});
