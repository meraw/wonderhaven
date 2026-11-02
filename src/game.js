// The game: owns the scene, systems and modes, and runs the main loop.
import * as THREE from 'three';
import { createRenderer } from './world/renderer.js';
import { createVillage } from './world/village.js';
import { createCharacter } from './world/characters.js';
import { Effects, textSprite } from './world/effects.js';
import { Input } from './core/input.js';
import { EventBus } from './core/events.js';
import { keyLabel } from './core/bindings.js';
import { WalkWorld } from './systems/walk.js';
import { generateDecor, buildStatics } from './systems/world-statics.js';
import { PlayerController } from './player/controller.js';
import { FollowCamera } from './player/camera.js';
import { SPAWN, NODES, FEATURES } from './data/village-layout.js';
import { DEFAULT_APPEARANCE } from './data/appearance.js';
import { $, setPrompt, toast } from './ui/dom.js';

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.bus = new EventBus();
    this.input = new Input(canvas);
    const { renderer, scene, camera, sun, hemi, ambient } = createRenderer(canvas);
    Object.assign(this, { renderer, scene, camera, sun, hemi, ambient });
    this.flags = {};
    this.decor = generateDecor();
    this.statics = buildStatics(this.decor);
    this.walk = new WalkWorld({ statics: this.statics, flags: f => !!this.flags[f] });
    this.village = createVillage(this.decor);
    scene.add(this.village.group);
    this.effects = new Effects(scene);
    this.playerChar = createCharacter(DEFAULT_APPEARANCE, { name: 'player' });
    scene.add(this.playerChar.root);
    this.player = new PlayerController(this.playerChar, this.walk, SPAWN);
    this.walk.dynamic.push(this.player.body);
    this.cam = new FollowCamera(camera);
    this.mode = 'explore';
    this.time = 0;
    this.clock = new THREE.Clock();
    this.interactables = [];
    this.target = null;
    this.highlightCache = new Map();
    this.registerWorldInteractables();
    this.marker = textSprite('!'); this.marker.scale.set(0.8, 0.8, 1); this.marker.visible = false; scene.add(this.marker);
  }

  // Interactables are plain records: { id, x, z, y?, radius, label(), available(), act(), object }
  addInteractable(rec) { this.interactables.push({ radius: 1.8, available: () => true, ...rec }); }
  registerWorldInteractables() {
    for (const f of FEATURES) {
      if (f.kind === 'sign') this.addInteractable({ id: f.id, x: f.x, z: f.z, object: this.village.objects[f.id], label: () => 'Read sign', act: () => toast(f.text, '', 4) });
    }
  }
  findTarget() {
    const p = this.player.pos, fwd = this.player.forward();
    let best = null, bestScore = Infinity;
    for (const it of this.interactables) {
      if (!it.available()) continue;
      const x = typeof it.x === 'function' ? it.x() : it.x, z = typeof it.z === 'function' ? it.z() : it.z;
      const dx = x - p.x, dz = z - p.z, d = Math.hypot(dx, dz);
      if (d > it.radius + 0.6) continue;
      const facing = d > 0.01 ? (dx * fwd.x + dz * fwd.z) / d : 1;
      if (d > 1.0 && facing < 0.1) continue;
      const score = d - facing * 0.8;
      if (score < bestScore) { bestScore = score; best = it; }
    }
    return best;
  }
  setHighlight(obj, on, t = 0) {
    if (!obj) return;
    obj.traverse(o => {
      if (!o.isMesh || !o.material || o.isSprite || !('emissive' in o.material)) return;
      if (!this.highlightCache.has(o)) { this.highlightCache.set(o, o.material); o.material = o.material.clone(); o.userData.baseEmissive = o.material.emissive.clone(); o.userData.baseEI = o.material.emissiveIntensity; }
      if (on) { o.material.emissive.set('#ffd98a'); o.material.emissiveIntensity = 0.25 + Math.sin(t * 6) * 0.12; }
      else { o.material.emissive.copy(o.userData.baseEmissive); o.material.emissiveIntensity = o.userData.baseEI; }
    });
  }
  updateInteraction(dt) {
    const prev = this.target;
    this.target = this.mode === 'explore' ? this.findTarget() : null;
    if (prev && prev !== this.target) this.setHighlight(prev.object, false);
    if (this.target) {
      this.setHighlight(this.target.object, true, this.time);
      setPrompt(`<kbd>${keyLabel(this.input.bindings.interact[0])}</kbd> ${this.target.label()}`);
      if (this.input.pressed('interact')) this.target.act();
    } else setPrompt(null);
  }
  updateHotkeys() {
    const k = a => `<kbd>${keyLabel(this.input.bindings[a][0])}</kbd>`;
    const html = `<span>${k('forward')}${k('left')}${k('back')}${k('right')} Move</span><span>Drag / ${k('camLeft')}${k('camRight')} Camera</span><span>Wheel Zoom</span><span>${k('interact')} Interact</span><span>${k('jump')} Hop</span>`;
    const h = $('hotkeys'); if (h.dataset.html !== html) { h.innerHTML = html; h.dataset.html = html; }
  }
  start() {
    $('hud').hidden = false;
    const loop = () => { requestAnimationFrame(loop); this.frame(); };
    loop();
  }
  frame() {
    const dt = Math.min(0.1, this.clock.getDelta());
    this.time += dt;
    this.input.pollGamepad();
    this.cam.handleInput(this.input, dt, true);
    this.player.update(dt, this.input, this.cam.moveYaw(), this.mode === 'explore');
    this.cam.update(dt, this.player.pos);
    this.updateInteraction(dt);
    this.updateHotkeys();
    this.village.update(dt, this.time, this.flags);
    this.effects.update(dt);
    // Shadow camera follows the player so shadows stay crisp.
    const p = this.player.pos;
    this.sun.position.set(p.x + 18, p.y + 30, p.z + 12); this.sun.target.position.set(p.x, p.y, p.z);
    this.renderer.setViewport(0, 0, window.innerWidth, window.innerHeight);
    this.renderer.setScissorTest(false);
    this.renderer.clear();
    this.renderer.render(this.scene, this.camera);
    this.input.endFrame();
  }
}
