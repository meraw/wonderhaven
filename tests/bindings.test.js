import test from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_BINDINGS, rebind, actionsForCode, cloneBindings } from '../src/core/bindings.js';

test('default bindings match the requested controls', () => {
  assert.ok(DEFAULT_BINDINGS.forward.includes('KeyW'));
  assert.deepEqual([DEFAULT_BINDINGS.interact[0], DEFAULT_BINDINGS.build[0], DEFAULT_BINDINGS.inventory[0], DEFAULT_BINDINGS.journal[0], DEFAULT_BINDINGS.map[0], DEFAULT_BINDINGS.pause[0], DEFAULT_BINDINGS.rotate[0], DEFAULT_BINDINGS.remove[0]],
    ['KeyE', 'KeyB', 'KeyI', 'KeyJ', 'KeyM', 'Escape', 'KeyR', 'Delete']);
});
test('rebinding moves a key and never leaves it on two actions', () => {
  const b = rebind(cloneBindings(), 'interact', 'KeyF');
  assert.equal(b.interact[0], 'KeyF');
  const b2 = rebind(b, 'jump', 'KeyF');
  assert.deepEqual(actionsForCode(b2, 'KeyF'), ['jump']);
  assert.ok(!b2.interact.includes('KeyF'));
  assert.throws(() => rebind(b, 'nope', 'KeyX'));
});
