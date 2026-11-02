// Remappable action -> key bindings (KeyboardEvent.code values). Pure, so it is unit tested.
export const DEFAULT_BINDINGS = {
  forward: ['KeyW', 'ArrowUp'],
  back: ['KeyS', 'ArrowDown'],
  left: ['KeyA', 'ArrowLeft'],
  right: ['KeyD', 'ArrowRight'],
  sprint: ['ShiftLeft', 'ShiftRight'],
  jump: ['Space'],
  interact: ['KeyE'],
  build: ['KeyB'],
  inventory: ['KeyI'],
  journal: ['KeyJ'],
  map: ['KeyM'],
  progress: ['KeyP'],
  wardrobe: ['KeyC'],
  pause: ['Escape'],
  rotate: ['KeyR'],
  remove: ['Delete', 'Backspace'],
  halfGrid: ['KeyG'],
  camLeft: ['KeyQ'],
  camRight: ['KeyZ'],
  recolor: ['KeyT'],
};
export const ACTION_LABELS = {
  forward: 'Move forward', back: 'Move back', left: 'Move left', right: 'Move right', sprint: 'Run', jump: 'Hop',
  interact: 'Interact', build: 'Starforge build mode', inventory: 'Inventory', journal: 'Quest journal', map: 'World map',
  progress: 'Kingdom Harmony', wardrobe: 'Wardrobe', pause: 'Pause / back', rotate: 'Rotate piece', remove: 'Remove piece',
  halfGrid: 'Half-grid snapping', camLeft: 'Turn camera left', camRight: 'Turn camera right', recolor: 'Recolor piece',
};
export function cloneBindings(b = DEFAULT_BINDINGS) {
  const out = {};
  for (const k of Object.keys(DEFAULT_BINDINGS)) out[k] = [...(b[k] || DEFAULT_BINDINGS[k])];
  return out;
}
// Binds `code` as the primary key of `action`, removing it from any other action so no key does two things.
export function rebind(bindings, action, code) {
  if (!(action in DEFAULT_BINDINGS)) throw new Error(`Unknown action ${action}`);
  const out = cloneBindings(bindings);
  for (const k of Object.keys(out)) out[k] = out[k].filter(c => c !== code);
  out[action] = [code, ...out[action].filter(c => c !== code)].slice(0, 2);
  return out;
}
export function actionsForCode(bindings, code) {
  return Object.keys(bindings).filter(k => bindings[k].includes(code));
}
export function keyLabel(code) {
  if (!code) return '—';
  if (code.startsWith('Key')) return code.slice(3);
  if (code.startsWith('Digit')) return code.slice(5);
  return ({ Space: 'Space', Escape: 'Esc', ShiftLeft: 'Shift', ShiftRight: 'Shift', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→', Backspace: 'Bksp' })[code] || code;
}
