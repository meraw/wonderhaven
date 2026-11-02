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
import { newGameState } from './systems/state.js';
import { validatePlacement, validateRemoval, surfacesFor, bounds, footprint } from './systems/build-grid.js';
import { solveMechanics } from './systems/mechanics.js';
import { canAfford, spend, add } from './systems/inventory.js';
import { PlayerController } from './player/controller.js';
import { FollowCamera } from './player/camera.js';
import { BuildMode } from './build/build-mode.js';
import { makePieceMesh, setPieceColor, animatePiece } from './build/piece-meshes.js';
import { SPAWN, FEATURES, ZONES, FOUNTAIN } from './data/village-layout.js';
import { PIECE } from './data/pieces.js';
import { RESOURCES } from './data/resources.js';
import { Hud } from './ui/hud.js';
import { $, setPrompt, toast } from './ui/dom.js';

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.bus = new EventBus();
    this.input = new Input(canvas);
    const { renderer, scene, camera, sun, hemi, ambient } = createRenderer(canvas);
    Object.assign(this, { renderer, scene, camera, sun, hemi, ambient });
    this.state = newGameState();
    this.decor = generateDecor();
    this.statics = buildStatics(this.decor);
    this.walk = new WalkWorld({ statics: this.statics, flags: f => !!this.state.flags[f] });
    this.village = createVillage(this.decor);
    scene.add(this.village.group);
    this.effects = new Effects(scene);
    this.playerChar = createCharacter(this.state.appearance, { name: 'player' });
    scene.add(this.playerChar.root);
    this.player = new PlayerController(this.playerChar, this.walk, SPAWN);
    this.walk.dynamic.push(this.player.body);
    this.cam = new FollowCamera(camera);
    this.hud = new Hud(this);
    this.mode = 'explore';
    this.time = 0;
    this.clock = new THREE.Clock();
    this.interactables = [];
    this.target = null;
    this.highlightCache = new Map();
    this.pieceGroup = new THREE.Group(); this.pieceGroup.name = 'placements'; scene.add(this.pieceGroup);
    this.pieceMeshes = new Map();
    this.spawnAnims = [];
    this.mech = solveMechanics([]);
    this.sitting = null;
    this.registerWorldInteractables();
    this.build = new BuildMode(this);
    this.marker = textSprite('!'); this.marker.scale.set(0.8, 0.8, 1); this.marker.visible = false; scene.add(this.marker);
  }

  // ---- Flags, zones, blueprints ----------------------------------------------------------------
  get flags() { return this.state.flags; }
  setFlag(f, v = true) { if (!!this.state.flags[f] === !!v) return; this.state.flags[f] = v; this.bus.emit('flag', { flag: f, value: v }); }
  zoneUnlocked(zone) {
    const u = zone.unlock || {};
    if (u.flag && !this.state.flags[u.flag]) return false;
    if (u.quest && !this.state.quests[u.quest]) return false;
    return true;
  }
  zonePlanVisible(zone) { return this.zoneUnlocked(zone) && (!zone.unlock?.quest || this.state.quests[zone.unlock.quest]?.status === 'active') && !(zone.id === 'dock' && this.state.flags.boatReady); }
  blueprintHint(id) { return this.quests?.blueprintHint(id) || 'Keep helping the villagers to discover this blueprint'; }
  buildGoals(zone) { return this.quests?.buildGoals(zone) || null; }

  // ---- Construction ----------------------------------------------------------------------------
  placementCtx(placements = this.state.placements) {
    const bodies = [{ x: this.player.pos.x, z: this.player.pos.z, r: 0.3, y: this.player.pos.y }];
    for (const n of this.npcs?.list || []) bodies.push({ x: n.pos.x, z: n.pos.z, r: 0.3, y: n.pos.y, name: n.def.name });
    return { placements, zones: ZONES.filter(z => this.zoneUnlocked(z)), lockedZones: ZONES.filter(z => !this.zoneUnlocked(z)), harmony: this.state.harmony, statics: this.statics, flags: this.state.flags, bodies };
  }
  commitPlace(pl, animate = true, { checkCost = true } = {}) {
    const others = this.state.placements.filter(p => p.uid !== pl.uid);
    const v = validatePlacement(pl, this.placementCtx(others));
    if (!v.ok) return v;
    const cost = PIECE[pl.id].cost;
    if (checkCost && !canAfford(this.state.inventory, cost)) return { ok: false, reason: 'Not enough materials' };
    if (checkCost) spend(this.state.inventory, cost);
    this.state.placements.push(pl);
    this.state.nextUid = Math.max(this.state.nextUid, pl.uid + 1);
    this.state.stats.placed++;
    this.addPieceMesh(pl, animate);
    if (animate) { this.playerChar.play('build'); this.sfx('place'); }
    this.hud.resources(Object.keys(cost));
    this.onBuildChanged({ action: 'place', pl, zone: v.zone });
    return { ok: true };
  }
  commitRemove(uid, refund = true) {
    const v = validateRemoval(uid, this.placementCtx());
    if (!v.ok) return v;
    const pl = this.state.placements.find(p => p.uid === uid);
    this.state.placements = this.state.placements.filter(p => p.uid !== uid);
    if (refund) add(this.state.inventory, PIECE[pl.id].cost);
    const m = this.pieceMeshes.get(uid);
    if (m) { this.effects.poof(m.position.clone(), { color: '#e9ddff' }); this.pieceGroup.remove(m); this.pieceMeshes.delete(uid); }
    this.sfx('remove');
    this.hud.resources(Object.keys(PIECE[pl.id].cost));
    this.onBuildChanged({ action: 'remove', pl });
    return { ok: true };
  }
  commitMove(uid, to) {
    const pl = this.state.placements.find(p => p.uid === uid);
    if (!pl) return { ok: false, reason: 'That piece is gone' };
    const cand = { ...pl, ...to };
    const others = this.state.placements.filter(p => p.uid !== uid);
    const rm = validateRemoval(uid, this.placementCtx());
    if (!rm.ok && (to.i !== pl.i || to.k !== pl.k || to.y !== pl.y)) return rm;
    const v = validatePlacement(cand, this.placementCtx(others));
    if (!v.ok) return v;
    Object.assign(pl, to);
    this.syncPieceMesh(pl);
    this.effects.sparkle(this.pieceMeshes.get(uid).position.clone().add(new THREE.Vector3(0, 0.4, 0)), { count: 8, color: '#c9a8ff' });
    this.sfx('place');
    this.onBuildChanged({ action: 'move', pl, zone: v.zone });
    return { ok: true };
  }
  commitRecolor(uid, color) {
    const pl = this.state.placements.find(p => p.uid === uid);
    if (!pl) return { ok: false, reason: 'That piece is gone' };
    pl.color = color || undefined;
    setPieceColor(this.pieceMeshes.get(uid), color || PIECE[pl.id].color);
    this.effects.sparkle(this.pieceMeshes.get(uid).position.clone().add(new THREE.Vector3(0, 0.5, 0)), { count: 10, color: color || '#ffffff' });
    this.sfx('paint');
    this.onBuildChanged({ action: 'recolor', pl });
    return { ok: true };
  }
  toggleLever(uid) {
    const pl = this.state.placements.find(p => p.uid === uid); if (!pl) return;
    pl.state = { ...(pl.state || {}), on: !pl.state?.on };
    this.sfx('lever');
    this.onBuildChanged({ action: 'switch', pl });
    this.build.render();
  }
  addPieceMesh(pl, animate) {
    const m = makePieceMesh(pl.id, pl.color);
    m.userData.uid = pl.uid;
    this.pieceGroup.add(m); this.pieceMeshes.set(pl.uid, m);
    this.syncPieceMesh(pl);
    if (animate) {
      m.scale.setScalar(0.01);
      this.spawnAnims.push({ m, t: 0 });
      this.effects.magic(m.position.clone(), { height: Math.min(2, PIECE[pl.id].h + 0.5) });
    }
  }
  syncPieceMesh(pl) {
    const m = this.pieceMeshes.get(pl.uid); if (!m) return;
    const [fw, fd] = footprint(PIECE[pl.id], pl.r);
    m.position.set(pl.i + fw / 2, pl.y, pl.k + fd / 2);
    m.rotation.y = -pl.r * Math.PI / 2;
  }
  rebuildAllPieces() {
    this.pieceGroup.clear(); this.pieceMeshes.clear();
    for (const pl of this.state.placements) this.addPieceMesh(pl, false);
    this.onBuildChanged({ action: 'load' });
  }
  onBuildChanged(ev) {
    this.walk.setSurfaces(surfacesFor(this.state.placements));
    this.mech = solveMechanics(this.state.placements, { inlets: [{ id: 'fountain', ...FOUNTAIN.inlet }] });
    this.refreshPieceInteractables();
    this.build.refreshPlan();
    this.bus.emit('build', ev);
  }
  refreshPieceInteractables() {
    this.interactables = this.interactables.filter(it => !it.piece);
    for (const pl of this.state.placements) {
      const def = PIECE[pl.id];
      if (!def.interact) continue;
      const b = bounds(pl), cx = (b.minX + b.maxX) / 2, cz = (b.minZ + b.maxZ) / 2;
      const rec = { id: `pl:${pl.uid}`, piece: true, x: cx, z: cz, radius: 1.3, object: this.pieceMeshes.get(pl.uid) };
      if (def.interact === 'door') Object.assign(rec, { label: () => (pl.state?.open ? 'Close door' : 'Open door'), act: () => { pl.state = { ...(pl.state || {}), open: !pl.state?.open }; this.sfx('door'); this.walk.setSurfaces(surfacesFor(this.state.placements)); } });
      if (def.interact === 'lever') Object.assign(rec, { label: () => (pl.state?.on ? 'Switch lever off' : 'Switch lever on'), act: () => this.toggleLever(pl.uid) });
      if (def.interact === 'sit') Object.assign(rec, { label: () => 'Sit down', act: () => this.sitOn(pl) });
      if (def.interact === 'sleep') Object.assign(rec, { label: () => 'Rest until morning', act: () => this.rest?.() });
      if (rec.act) this.addInteractable(rec);
    }
  }
  sitOn(pl) {
    const def = PIECE[pl.id], b = bounds(pl);
    const seatY = pl.y + (def.id === 'chair' ? 0.48 : 0.45);
    const [fx, fz] = [Math.sin(-pl.r * Math.PI / 2 + Math.PI) * -1, Math.cos(-pl.r * Math.PI / 2)];
    this.sitting = { pl, back: { ...this.player.pos } };
    this.player.pos.x = (b.minX + b.maxX) / 2; this.player.pos.z = (b.minZ + b.maxZ) / 2; this.player.pos.y = seatY - 0.2;
    this.player.yaw = -pl.r * Math.PI / 2; this.player.sync();
    this.playerChar.play('sit', true);
    toast('Ahh, cozy. Move to stand up.');
  }
  standUp() {
    if (!this.sitting) return;
    const { back } = this.sitting; this.sitting = null;
    this.player.teleport(back.x, back.z);
    this.playerChar.stopHold();
  }

  // ---- Interaction ----------------------------------------------------------------------------
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
      const score = d - facing * 0.8 - (it.priority || 0);
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
  updateInteraction() {
    const prev = this.target;
    this.target = this.mode === 'explore' && !this.sitting ? this.findTarget() : null;
    if (prev && prev !== this.target) this.setHighlight(prev.object, false);
    if (this.target) {
      this.setHighlight(this.target.object, true, this.time);
      setPrompt(`<kbd>${keyLabel(this.input.bindings.interact[0])}</kbd> ${this.target.label()}`);
      if (this.input.pressed('interact')) this.target.act();
    } else setPrompt(null);
  }
  updateHotkeys() {
    const k = a => `<kbd>${keyLabel(this.input.bindings[a][0])}</kbd>`;
    let html = `<span>${k('forward')}${k('left')}${k('back')}${k('right')} Move</span><span>Drag / ${k('camLeft')}${k('camRight')} Camera</span><span>${k('interact')} Interact</span>`;
    if (this.state.flags.hasTool) html += `<span>${k('build')} Build</span>`;
    html += `<span>${k('inventory')} Bag</span><span>${k('journal')} Journal</span><span>${k('map')} Map</span><span>${k('pause')} Menu</span>`;
    const h = $('hotkeys'); if (h.dataset.html !== html) { h.innerHTML = html; h.dataset.html = html; }
  }

  // ---- Rewards ---------------------------------------------------------------------------------
  give(items, { source = null, quiet = false } = {}) {
    add(this.state.inventory, items);
    this.hud.resources(Object.keys(items));
    if (!quiet) for (const [id, n] of Object.entries(items)) if (n > 0) toast(`+${n} ${RESOURCES[id]?.icon || ''} ${RESOURCES[id]?.name || id}`, 'good', 1.8);
    if (source) this.effects.sparkle(source, { count: 10 });
    this.bus.emit('gain', { items });
  }
  sfx(name) { this.audio?.sfx(name); }

  // ---- Loop ------------------------------------------------------------------------------------
  start() {
    $('hud').hidden = false;
    this.hud.resources();
    const loop = () => { requestAnimationFrame(loop); this.frame(); };
    loop();
  }
  frame() {
    const dt = Math.min(0.1, this.clock.getDelta());
    this.time += dt;
    const input = this.input;
    input.pollGamepad();
    const buildDragOk = this.mode !== 'build' || input.mouse.dragging === 2 || input.mouse.dragging === 1;
    this.cam.handleInput(input, dt, buildDragOk);
    if (this.mode === 'explore') {
      if (this.sitting) { const mv = input.moveVector(); if (Math.hypot(mv.x, mv.y) > 0.3 || input.pressed('jump')) this.standUp(); else this.playerChar.update(dt, {}); }
      else this.player.update(dt, input, this.cam.moveYaw(), true);
      if (input.pressed('build') && this.build.open()) this.mode = 'build';
    } else if (this.mode === 'build') {
      this.playerChar.update(dt, {});
      this.build.update(dt);
      if (!this.build.active) this.mode = 'explore';
    } else this.playerChar.update(dt, {});
    this.cam.update(dt, this.player.pos);
    this.updateInteraction();
    this.updateHotkeys();
    this.village.update(dt, this.time, { ...this.state.flags, fountainFlowing: this.mech.fed.fountain });
    for (let i = this.spawnAnims.length - 1; i >= 0; i--) {
      const a = this.spawnAnims[i]; a.t += dt * 2.6;
      const s = a.t >= 1 ? 1 : 1 + Math.sin(a.t * Math.PI * 1.5) * (1 - a.t) * 0.5 - (1 - a.t) * (1 - a.t);
      a.m.scale.setScalar(Math.max(0.01, a.t >= 1 ? 1 : s * Math.min(1, a.t * 2)));
      if (a.t >= 1) this.spawnAnims.splice(i, 1);
    }
    for (const pl of this.state.placements) {
      const m = this.pieceMeshes.get(pl.uid); if (!m) continue;
      animatePiece(m, pl, this.time, dt, { spinning: this.mech.powered.has(pl.uid) || this.mech.sources.has(pl.uid), powered: this.mech.powered.has(pl.uid), watered: this.mech.watered.has(pl.uid), on: pl.state?.on, open: pl.state?.open, night: !!this.state.flags.night });
    }
    this.effects.update(dt);
    const p = this.mode === 'build' ? this.build.focus : this.player.pos;
    this.sun.position.set(p.x + 18, 30, p.z + 12); this.sun.target.position.set(p.x, 0, p.z);
    this.renderer.setViewport(0, 0, window.innerWidth, window.innerHeight);
    this.renderer.setScissorTest(false);
    this.renderer.clear();
    this.renderer.render(this.scene, this.camera);
    input.endFrame();
  }
  testHook() {
    const game = this;
    return {
      game,
      state: () => structuredClone(game.state),
      player: () => ({ ...game.player.pos }),
      worldToScreen(x, y, z) { const v = new THREE.Vector3(x, y, z).project(game.camera); return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight, visible: v.z < 1 }; },
      mode: () => game.mode,
    };
  }
}
