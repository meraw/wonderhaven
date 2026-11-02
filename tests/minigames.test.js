import test from 'node:test';
import assert from 'node:assert/strict';
import { ChopGame, MineGame, FishGame } from '../src/systems/minigames.js';
import { makeRng } from '../src/core/rng.js';
import { plant, water, grow, harvest, plotAction, GROW_MINUTES } from '../src/systems/gardening.js';

function playChop(perfect) {
  const g = new ChopGame(makeRng(4));
  for (let n = 0; n < 2000 && !g.done; n++) {
    const press = g.pause <= 0 && (perfect ? Math.abs(g.needle - g.center) < 0.02 : n % 97 === 3);
    g.step(1 / 60, { press });
  }
  return g;
}
test('chopping: good timing yields more wood than random presses', () => {
  const good = playChop(true), meh = playChop(false);
  assert.ok(good.done && meh.done);
  assert.ok(good.results.every(r => r !== 'miss') && good.results.filter(r => r === 'perfect').length >= 2, good.results.join());
  assert.ok(good.reward().wood > meh.reward().wood || meh.results.every(r => r !== 'miss'));
  assert.ok(meh.reward().wood >= 1, 'you always get something');
});
test('mining: hitting the ring gives stone; rich rocks give crystal', () => {
  const g = new MineGame({ rich: true }, makeRng(2));
  for (let n = 0; n < 3000 && !g.done; n++) g.step(1 / 60, { press: g.pause <= 0 && g.r < 0.4 && g.r > 0.38 });
  assert.ok(g.done); assert.equal(g.results.filter(r => r !== 'miss').length, 3);
  const r = g.reward(); assert.ok(r.stone >= 4 && r.crystal >= 1 && r.metal === 1);
  const idle = new MineGame({}, makeRng(3));
  for (let n = 0; n < 3000 && !idle.done; n++) idle.step(1 / 60, {});
  assert.deepEqual(idle.results, ['miss', 'miss', 'miss']); assert.equal(idle.reward().stone, 1);
});
test('fishing: pressing early scares the fish; good tension control lands it', () => {
  const early = new FishGame(makeRng(1)); early.step(0.1, { press: true }); assert.equal(early.result, 'early');
  const g = new FishGame(makeRng(5));
  for (let n = 0; n < 6000 && !g.done; n++) {
    const press = g.phase === 'bite';
    const hold = g.phase === 'reel' && g.tension < 0.5;
    g.step(1 / 60, { press, hold });
  }
  assert.equal(g.result, 'caught'); assert.ok(g.caught.name); assert.equal(g.reward().fish, 1);
  const greedy = new FishGame(makeRng(5));
  for (let n = 0; n < 6000 && !greedy.done; n++) greedy.step(1 / 60, { press: greedy.phase === 'bite', hold: true });
  assert.equal(greedy.result, 'snap', 'holding forever snaps the line');
});
test('gardening: plant, water, grow over time, harvest', () => {
  const gardens = {}, inv = { seeds: 1 };
  assert.equal(plotAction(gardens, 'bed0', inv), 'plant');
  assert.ok(plant(gardens, 'bed0', 0)); assert.equal(plotAction(gardens, 'bed0', inv), 'water');
  assert.ok(water(gardens, 'bed0', 0)); assert.equal(plotAction(gardens, 'bed0', inv), 'growing');
  grow(gardens, GROW_MINUTES - 1); assert.equal(gardens.bed0.stage, 0);
  grow(gardens, GROW_MINUTES); assert.equal(gardens.bed0.stage, 1);
  grow(gardens, GROW_MINUTES * 5); assert.equal(gardens.bed0.stage, 1, 'needs water again');
  for (let s = 0; s < 2; s++) { const now = (s + 2) * 1000; water(gardens, 'bed0', now); grow(gardens, now + GROW_MINUTES); }
  assert.equal(plotAction(gardens, 'bed0', inv), 'harvest');
  assert.equal(harvest(gardens, 'bed0').flowers, 3);
  assert.equal(plotAction(gardens, 'bed0', { seeds: 0 }), 'needSeeds');
});
