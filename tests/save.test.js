import test from 'node:test';
import assert from 'node:assert/strict';
import { newGameState } from '../src/systems/state.js';
import { writeSave, readSave, saveMeta, latestSlot, deserialize, loadSettings, storeSettings } from '../src/systems/save.js';

class Mem { constructor() { this.m = new Map(); } getItem(k) { return this.m.has(k) ? this.m.get(k) : null; } setItem(k, v) { this.m.set(k, String(v)); } removeItem(k) { this.m.delete(k); } }

test('a full game state survives a save and load', () => {
  const st = newGameState({ name: 'Pip', appearance: { hair: 'curly', hairColor: '#ff9ec7', hat: 'crown' } });
  st.inventory.wood = 7; st.harmony = 88; st.flags.orchardOpen = true; st.flags.harborOpen = true;
  st.quests.bridge = { status: 'done', progress: { build: true } }; st.quests.workshop = { status: 'active', progress: { wood: 2 } };
  st.placements.push({ uid: 4, id: 'bridgeDeck', i: 0, k: -16, r: 0, y: 0 }, { uid: 9, id: 'lever', i: 3, k: 2, r: 1, y: 0, state: { on: false } }, { uid: 10, id: 'chair', i: -15, k: 8, r: 2, y: 0, color: '#7bd389' });
  st.relationships.fern = { hearts: 5, talkedDay: 2, gifts: [4] };
  st.blueprints.push('bridgeDeck'); st.lockedClothesOwned.push('overalls');
  st.player = { x: 3, z: -20, yaw: 1 }; st.time = { day: 3, minute: 900, total: 5000 };
  st.gardens.bed1 = { stage: 2, watered: true, wateredAt: 4900 };
  const mem = new Mem();
  writeSave(mem, 'slot2', st);
  const back = readSave(mem, 'slot2');
  for (const k of ['name', 'inventory', 'harmony', 'flags', 'quests', 'placements', 'relationships', 'blueprints', 'lockedClothesOwned', 'player', 'time', 'gardens']) assert.deepEqual(back[k], st[k], k);
  assert.equal(back.appearance.hair, 'curly');
  assert.equal(back.nextUid, 11);
  assert.equal(saveMeta(mem, 'slot2').harmony, 88);
  assert.equal(latestSlot(mem), 'slot2');
});
test('loading is forgiving: unknown pieces and bad data are dropped, missing fields filled', () => {
  const s = deserialize(JSON.stringify({ name: 'X', placements: [{ uid: 1, id: 'laserCannon', i: 0, k: 0, y: 0 }, { uid: 2, id: 'floor', i: 1, k: 1, y: 0, r: 5 }], appearance: { hair: 'mohawk' } }));
  assert.equal(s.placements.length, 1); assert.equal(s.placements[0].r, 1);
  assert.equal(s.appearance.hair, 'bob');
  assert.ok(s.inventory && s.time && s.stats);
  assert.throws(() => deserialize('null'));
});
test('settings persist with defaults', () => {
  const mem = new Mem();
  assert.equal(loadSettings(mem).music, 0.6);
  storeSettings(mem, { ...loadSettings(mem), music: 0.2, invertY: true });
  assert.equal(loadSettings(mem).music, 0.2); assert.equal(loadSettings(mem).invertY, true);
});
