import test from 'node:test';
import assert from 'node:assert/strict';
import { QUESTS, QUEST } from '../src/data/quests.js';
import { NPCS, NPC } from '../src/data/npcs.js';
import { PIECE } from '../src/data/pieces.js';
import { HARMONY_UNLOCKS, nextUnlock, unlocksBetween } from '../src/data/harmony.js';
import { LOCKED_CLOTHES } from '../src/data/appearance.js';
import { NAV_NODES, ZONES, NODES } from '../src/data/village-layout.js';
import { newGameState } from '../src/systems/state.js';
import { QuestEngine } from '../src/systems/quests.js';
import { buildConversation } from '../src/systems/dialogue.js';
import { activityAt, findPath, scheduleFor } from '../src/systems/schedule.js';
import { advanceTime, isNight, clockText, sleepUntilMorning, weatherAt } from '../src/systems/time.js';

test('quest data is complete and consistent', () => {
  const ids = new Set();
  for (const q of QUESTS) {
    assert.ok(!ids.has(q.id), `duplicate ${q.id}`); ids.add(q.id);
    assert.ok(q.title && q.description && NPC[q.giver], `${q.id} has title, description, a real giver`);
    assert.ok(q.objectives.length >= 1 && q.objectives.some(o => o.final), `${q.id} ends by talking to someone`);
    for (const k of ['offer', 'accept', 'progress', 'complete']) assert.ok(q.dialogue[k]?.length, `${q.id} dialogue.${k}`);
    for (const b of [...(q.onAccept?.blueprints || []), ...(q.rewards?.blueprints || [])]) assert.ok(PIECE[b], `${q.id} blueprint ${b}`);
    for (const c of q.rewards?.clothes || []) assert.ok(c in LOCKED_CLOTHES, `${q.id} clothing ${c}`);
    for (const r of q.requires?.quests || []) assert.ok(QUEST[r], `${q.id} requires ${r}`);
    for (const o of q.objectives) if (o.kind === 'talk') assert.ok(NPC[o.npc]);
  }
  assert.ok(QUESTS.filter(q => q.main).length >= 4, 'at least four main quests');
});

test('NPC data: at least five distinct villagers with schedules on real paths', () => {
  assert.ok(NPCS.length >= 5);
  assert.equal(new Set(NPCS.map(n => n.name)).size, NPCS.length);
  for (const n of NPCS) {
    assert.ok(n.topics.length >= 2 && n.greetings.length >= 1, `${n.id} has things to say`);
    assert.ok(NAV_NODES[n.home], `${n.id} home`);
    for (const s of [n.schedule, ...(n.when || []).map(w => w.schedule)]) for (const [, , node] of s) assert.ok(NAV_NODES[node], `${n.id} → ${node}`);
    assert.ok(QUESTS.some(q => q.giver === n.id), `${n.id} gives at least one quest`);
  }
});

test('every locked blueprint and outfit can be earned in play', () => {
  const earnable = new Set(newGameState().blueprints);
  for (const q of QUESTS) for (const b of [...(q.onAccept?.blueprints || []), ...(q.rewards?.blueprints || [])]) earnable.add(b);
  for (const u of HARMONY_UNLOCKS) for (const b of u.blueprints || []) earnable.add(b);
  for (const n of NODES) if (n.blueprint) earnable.add(n.blueprint);
  for (const n of NPCS) for (const g of n.gifts || []) if (g.blueprint) earnable.add(g.blueprint);
  const virtuoso = HARMONY_UNLOCKS.some(u => u.allBlueprints);
  assert.ok(virtuoso || Object.keys(PIECE).every(id => earnable.has(id)));
  const clothes = new Set([...QUESTS.flatMap(q => q.rewards?.clothes || []), ...HARMONY_UNLOCKS.flatMap(u => u.clothes || []), ...NODES.filter(n => n.outfit).map(n => n.outfit)]);
  for (const c of Object.keys(LOCKED_CLOTHES)) assert.ok(clothes.has(c), `outfit ${c} is earnable`);
});

test('the main story can reach 120 Harmony without grinding side content', () => {
  const main = QUESTS.filter(q => q.main && q.id !== 'decree' && q.id !== 'dock');
  const total = main.reduce((s, q) => s + (q.rewards.harmony || 0), 0);
  assert.ok(total >= 120, `main quests give ${total}`);
  assert.equal(nextUnlock(0).at, 15);
  assert.deepEqual(unlocksBetween(10, 60).map(u => u.id), ['cozy', 'plot']);
});

test('quest flow: offer → accept → gather → build check → turn in', () => {
  const state = newGameState();
  let bridgeBuilt = false;
  const e = new QuestEngine(state, { bridge: () => bridgeBuilt });
  assert.deepEqual(e.offersFor('fern'), [], 'bridge needs the tool quest first');
  assert.ok(e.offersFor('odessa').some(q => q.id === 'tool'));
  e.accept('tool');
  e.onGain({ wood: 2 }); assert.equal(e.isReady('tool'), false);
  e.onGain({ wood: 1, fragment: 1 });
  assert.ok(e.isReady('tool'));
  assert.deepEqual(e.turnInsFor('odessa').map(q => q.id), ['tool']);
  assert.equal(e.complete('tool').harmony, 10);
  assert.ok(e.offersFor('fern').some(q => q.id === 'bridge'));
  e.accept('bridge');
  e.onGain({ wood: 6, spark: 5 });
  assert.equal(e.isReady('bridge'), false, 'still needs the bridge');
  bridgeBuilt = true;
  const ev = e.refresh();
  assert.ok(ev.some(x => x.objective?.id === 'build') && ev.some(x => x.ready));
  bridgeBuilt = false;
  assert.ok(e.isReady('bridge'), 'build objectives latch once met');
  assert.ok(e.nextStep('bridge').npc === 'fern');
});

test('collection objectives latch even when materials are spent', () => {
  const state = newGameState();
  const e = new QuestEngine(state);
  state.quests.tool = { status: 'done', progress: {} };
  e.accept('bridge');
  e.onGain({ wood: 6 });
  state.inventory.wood = 0;
  assert.ok(e.objective('bridge', QUEST.bridge.objectives[0]).done);
});

test('conversations: turn-ins first, main offers up front, side quests and topics as choices', () => {
  const state = newGameState();
  const e = new QuestEngine(state);
  let c = buildConversation(NPC.odessa, { engine: e, flags: state.flags, name: 'Pip' });
  assert.equal(c.mainOffer.id, 'tool');
  e.accept('tool'); e.onGain({ wood: 3, fragment: 1 });
  c = buildConversation(NPC.odessa, { engine: e, flags: state.flags, name: 'Pip' });
  assert.equal(c.turnIns[0].id, 'tool');
  e.complete('tool'); state.quests.bridge = { status: 'done', progress: {} };
  c = buildConversation(NPC.percival, { engine: e, flags: state.flags, name: 'Pip' });
  assert.equal(c.mainOffer.id, 'decree');
  assert.ok(c.options.some(o => o.kind === 'offer' && o.id === 'stones'));
  assert.ok(c.options.some(o => o.kind === 'topic'));
  assert.equal(c.options.at(-1).kind, 'bye');
  assert.ok(!c.greeting.includes('{name}'));
});

test('schedules follow the clock and react to world changes', () => {
  assert.equal(activityAt(NPC.fern, 8 * 60, {}).node, 'fernGarden');
  assert.equal(activityAt(NPC.fern, 13 * 60, { orchardOpen: true }).node, 'orchard');
  assert.equal(activityAt(NPC.fern, 23 * 60, {}).activity, 'sleep');
  assert.equal(activityAt(NPC.odessa, 9 * 60, {}).node, 'westGate', 'Odessa waits at the gate for the newcomer');
  assert.equal(activityAt(NPC.bram, 9 * 60, { workshopDone: true }).node, 'workshopInside');
  assert.equal(scheduleFor(NPC.captain, { boatReady: true })[0][2], 'dockStart');
});

test('NPC paths only cross the bridge once it is built', () => {
  assert.equal(findPath('squareN', 'orchard', {}), null);
  const p = findPath('squareN', 'orchard', { orchardOpen: true });
  assert.ok(p && p.includes('bridgeS') && p.includes('bridgeN'));
  assert.ok(findPath('cottageDoor', 'castleSteps', {}));
});

test('clock, nights, weather and resting', () => {
  const t = { day: 1, minute: 8 * 60, total: 0 };
  advanceTime(t, 60 * 14); assert.equal(Math.floor(t.minute / 60), 22); assert.ok(isNight(t));
  assert.match(clockText(t), /Day 1 · 10:00 PM/);
  sleepUntilMorning(t); assert.equal(t.day, 2); assert.equal(t.minute, 7 * 60); assert.ok(!isNight(t));
  assert.equal(weatherAt({ day: 1, minute: 600 }), 'sunny', 'first day is always sunny');
  const kinds = new Set(); for (let d = 2; d < 60; d++) kinds.add(weatherAt({ day: d, minute: 600 }));
  assert.ok(kinds.has('rain') && kinds.has('sunny'));
});
