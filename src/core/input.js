// Keyboard, mouse and gamepad input with per-frame edge detection and remappable bindings.
import { cloneBindings, actionsForCode } from './bindings.js';

const PAD = { A: 0, B: 1, X: 2, Y: 3, LB: 4, RB: 5, LT: 6, RT: 7, SELECT: 8, START: 9, UP: 12, DOWN: 13, LEFT: 14, RIGHT: 15 };
const PAD_ACTIONS = { interact: PAD.A, pause: PAD.START, build: PAD.X, journal: PAD.Y, map: PAD.SELECT, rotate: PAD.RB, remove: PAD.LB, inventory: PAD.UP, progress: PAD.DOWN };

export class Input {
  constructor(target) {
    this.target = target;
    this.bindings = cloneBindings();
    this.keys = new Set();
    this.pressedActions = new Set();
    this.pressedCodes = new Set();
    this.ctrl = false;
    this.mouse = { x: 0, y: 0, dx: 0, dy: 0, wheel: 0, leftDown: false, rightDown: false, leftClick: false, rightClick: false, dragging: false, overUI: false };
    this.pad = { connected: false, moveX: 0, moveY: 0, lookX: 0, lookY: 0, zoom: 0, buttons: [], prev: [] };
    this.capture = null;
    this.sensitivity = 1;
    this.invertY = false;
    this.lastDevice = 'keyboard';
    this._dragStart = null;
    this.bind();
  }
  bind() {
    const t = this.target;
    window.addEventListener('keydown', e => {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT')) return;
      this.lastDevice = 'keyboard';
      if (this.capture) { e.preventDefault(); const cb = this.capture; this.capture = null; cb(e.code); return; }
      this.ctrl = e.ctrlKey || e.metaKey;
      if (!e.repeat) {
        this.pressedCodes.add(e.code);
        for (const a of actionsForCode(this.bindings, e.code)) this.pressedActions.add(a);
      }
      this.keys.add(e.code);
      if (['Space', 'ArrowUp', 'ArrowDown', 'Tab', 'Backspace'].includes(e.code) || (this.ctrl && ['KeyZ', 'KeyY', 'KeyS'].includes(e.code))) e.preventDefault();
    });
    window.addEventListener('keyup', e => { this.keys.delete(e.code); this.ctrl = e.ctrlKey || e.metaKey; });
    window.addEventListener('blur', () => { this.keys.clear(); this.mouse.leftDown = this.mouse.rightDown = false; });
    t.addEventListener('contextmenu', e => e.preventDefault());
    t.addEventListener('pointerdown', e => {
      this.lastDevice = 'mouse';
      this.mouse.x = e.clientX; this.mouse.y = e.clientY;
      if (e.button === 0) this.mouse.leftDown = true;
      if (e.button === 2 || e.button === 1) this.mouse.rightDown = true;
      this._dragStart = { x: e.clientX, y: e.clientY, button: e.button, moved: 0 };
      t.setPointerCapture?.(e.pointerId);
    });
    t.addEventListener('pointermove', e => {
      const dx = e.clientX - this.mouse.x, dy = e.clientY - this.mouse.y;
      this.mouse.x = e.clientX; this.mouse.y = e.clientY;
      if (this._dragStart) {
        this._dragStart.moved += Math.abs(dx) + Math.abs(dy);
        if (this._dragStart.moved > 6) this.mouse.dragging = this._dragStart.button;
        if (this.mouse.dragging !== false) { this.mouse.dx += dx; this.mouse.dy += dy; }
      }
    });
    t.addEventListener('pointerup', e => {
      const wasDrag = this._dragStart && this._dragStart.moved > 6;
      if (e.button === 0) { this.mouse.leftDown = false; if (!wasDrag) this.mouse.leftClick = true; }
      if (e.button === 2 || e.button === 1) { this.mouse.rightDown = false; if (!wasDrag) this.mouse.rightClick = true; }
      this._dragStart = null; this.mouse.dragging = false;
    });
    t.addEventListener('wheel', e => { e.preventDefault(); this.mouse.wheel += Math.sign(e.deltaY); }, { passive: false });
  }
  setBindings(b) { this.bindings = cloneBindings(b); }
  captureNextKey(cb) { this.capture = cb; }
  down(action) {
    if ((this.bindings[action] || []).some(c => this.keys.has(c))) return true;
    const b = PAD_ACTIONS[action];
    return b !== undefined && !!this.pad.buttons[b];
  }
  pressed(action) {
    if (this.pressedActions.has(action)) return true;
    const b = PAD_ACTIONS[action];
    return b !== undefined && !!this.pad.buttons[b] && !this.pad.prev[b];
  }
  codePressed(code) { return this.pressedCodes.has(code); }
  padPressed(name) { const b = PAD[name]; return !!this.pad.buttons[b] && !this.pad.prev[b]; }
  // Movement vector in camera space: x = right, y = forward.
  moveVector() {
    let x = 0, y = 0;
    if (this.down('forward')) y += 1;
    if (this.down('back')) y -= 1;
    if (this.down('right')) x += 1;
    if (this.down('left')) x -= 1;
    if (Math.abs(this.pad.moveX) > 0.2 || Math.abs(this.pad.moveY) > 0.2) { x = this.pad.moveX; y = -this.pad.moveY; }
    const len = Math.hypot(x, y);
    return len > 1 ? { x: x / len, y: y / len } : { x, y };
  }
  pollGamepad() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    const gp = [...pads].find(p => p && p.connected);
    this.pad.prev = this.pad.buttons;
    if (!gp) { this.pad.connected = false; this.pad.buttons = []; this.pad.moveX = this.pad.moveY = this.pad.lookX = this.pad.lookY = this.pad.zoom = 0; return; }
    this.pad.connected = true;
    const dz = v => (Math.abs(v) < 0.15 ? 0 : v);
    this.pad.moveX = dz(gp.axes[0] || 0); this.pad.moveY = dz(gp.axes[1] || 0);
    this.pad.lookX = dz(gp.axes[2] || 0); this.pad.lookY = dz(gp.axes[3] || 0);
    this.pad.buttons = gp.buttons.map(b => b.pressed);
    this.pad.zoom = (gp.buttons[PAD.RT]?.value || 0) - (gp.buttons[PAD.LT]?.value || 0);
    if (this.pad.buttons.some(Boolean) || this.pad.moveX || this.pad.moveY) this.lastDevice = 'gamepad';
  }
  endFrame() {
    this.pressedActions.clear(); this.pressedCodes.clear();
    this.mouse.dx = this.mouse.dy = 0; this.mouse.wheel = 0;
    this.mouse.leftClick = this.mouse.rightClick = false;
  }
}
