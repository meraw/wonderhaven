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
import { $, el, setPrompt, toast, banner, fade } from './ui/dom.js';
import { NpcAgent } from './npc/agent.js';
import { NPCS } from './data/npcs.js';
import { QUEST } from './data/quests.js';
import { nextUnlock } from './data/harmony.js';
import { Story } from './gameplay/story.js';
import { WorldActions } from './gameplay/world-actions.js';
import { DialogueUI } from './ui/dialogue.js';
import { MinigameUI } from './ui/minigame.js';
import { Panels } from './ui/panels.js';
import { advanceTime, isNight, daylight, clockText, weatherAt, sleepUntilMorning } from './systems/time.js';
import { writeSave, readSave, loadSettings, storeSettings, AUTOSAVE } from './systems/save.js';
import { NAV_NODES } from './data/village-layout.js';
import { terrainHeight } from './systems/heightfield.js';

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.bus = new EventBus();
    this.input = new Input(canvas);
    const { renderer, scene, camera, sun, hemi, ambient } = createRenderer(canvas);
    Object.assign(this, { renderer, scene, camera, sun, hemi, ambient });
    this.storage = safeStorage();
    this.settings = loadSettings(this.storage);
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
    this.dialogue = new DialogueUI(this);
    this.minigame = new MinigameUI(this);
    this.panels = new Panels(this);
    this.story = new Story(this);
    this.npcs = { list: [], byId: {} };
    for (const def of NPCS) {
      const a = new NpcAgent(this, def);
      this.npcs.list.push(a); this.npcs.byId[def.id] = a;
      this.addInteractable({ id: `npc:${def.id}`, x: () => a.pos.x, z: () => a.pos.z, radius: 1.9, priority: 0.6, object: null, available: () => a.present, label: () => `Talk to ${def.name}`, act: () => this.story.talk(a) });
    }
    this.actions = new WorldActions(this);
    this.applySettings();
    this.rain = makeRain(); scene.add(this.rain);
    this.lastAutosave = 0;
  }

  // ---- Modes ----------------------------------------------------------------------------------
  setMode(mode) {
    this.mode = mode;
    if (mode !== 'explore') setPrompt(null);
  }
  enterDialogue(agent) {
    if (this.mode === 'build') this.build.close();
    this.setMode('dialogue');
    agent.talking = true;
    this.dialogue.start(agent);
    this.cam.setMode('dialogue');
    this.cam.frameDialogue(this.player.pos, agent.pos);
    this.player.yaw = Math.atan2(agent.pos.x - this.player.pos.x, agent.pos.z - this.player.pos.z); this.player.sync();
    $('hud').classList.add('dim');
  }
  exitDialogue() {
    for (const a of this.npcs.list) a.talking = false;
    this.dialogue.end();
    this.cam.setMode('explore');
    this.setMode('explore');
    $('hud').classList.remove('dim');
  }
  startMinigame(kind, mg, onDone) {
    this.setMode('minigame');
    this.minigame.start(kind, mg, res => { this.setMode('explore'); onDone(res); });
  }
  rest() {
    fade(true);
    this.setMode('cutscene');
    setTimeout(() => {
      sleepUntilMorning(this.state.time);
      for (const a of this.npcs.list) a.teleportHome();
      this.actions.refreshAll();
      fade(false); this.setMode('explore');
      banner('Good morning!', clockText(this.state.time));
      this.sfx('morning');
      this.autosave('rest', true);
    }, 900);
  }
  openWardrobe() { this.screens?.wardrobe(); }
  sailTo(isl) {
    this.panels.close();
    if (isl.id === 'hearthglow') { toast('You are already in Hearthglow!'); return; }
    this.setMode('cutscene');
    fade(true); this.sfx('sail');
    setTimeout(() => {
      fade(false);
      banner(`${isl.name}`, 'Coming in the next chapter of Wonderhaven!', ['The Captain sails you round the bay and back.', 'Thank you for playing the Hearthglow chapter!'], 6);
      this.setFlag('sailedOnce');
      this.playerChar.play('celebrate');
      this.setMode('explore');
      this.autosave('travel', true);
    }, 1400);
  }
  toTitle() { this.autosave('quit', true); location.reload(); }
  onQuestCompleted(qid) {
    const p = new THREE.Vector3();
    if (qid === 'bridge') { this.actions.refreshAll(); this.effects.sparkle(p.set(0.5, 0.5, -18), { count: 50, spread: 3 }); }
    if (qid === 'workshop') { this.effects.sparkle(p.set(-13, 2, 10), { count: 40, spread: 3 }); }
    if (qid === 'fountain') { this.effects.sparkle(p.set(0, 2.5, 2), { count: 60, spread: 3, color: '#bff3ff' }); }
    if (qid === 'decree') { this.cam.shake = 0.4; this.sfx('gate'); toast('The harbor gate creaks open to the south!', 'good', 4); }
    if (qid === 'dock') { this.effects.sparkle(p.set(5.5, 1, 51), { count: 50, spread: 3 }); setTimeout(() => banner('The ferry has arrived!', 'Clockwork Cove now appears on your world map (M)', [], 5), 4400); }
    for (const a of this.npcs.list) if (a.present && Math.hypot(a.pos.x - this.player.pos.x, a.pos.z - this.player.pos.z) < 12) a.character.play(Math.random() < 0.5 ? 'clap' : 'celebrate');
  }
  // Path cells of the bridge or dock the player built, so villagers walk across it.
  crossingPath(a, b) {
    const pairs = { 'bridgeS|bridgeN': ['bridge', 1], 'bridgeN|bridgeS': ['bridge', -1] };
    const m = pairs[`${a}|${b}`]; if (!m) return null;
    const cells = this.state.crossings?.[m[0]]; if (!cells) return null;
    const pts = cells.map(([i, k]) => [i + 0.5, k + 0.5]);
    return m[1] > 0 ? pts : pts.reverse();
  }

  // ---- Saving ---------------------------------------------------------------------------------
  snapshot() {
    this.state.player = { x: this.player.pos.x, z: this.player.pos.z, yaw: this.player.yaw };
    return this.state;
  }
  saveTo(slot) {
    try { writeSave(this.storage, slot, this.snapshot()); toast(slot === AUTOSAVE ? '💾 Autosaved' : '💾 Game saved', 'good', 1.8); this.sfx('save'); return true; }
    catch (e) { toast('Could not save: ' + e.message, 'warn'); return false; }
  }
  autosave(reason, force = false) {
    if (!this.started) return;
    if (!force && this.time - this.lastAutosave < 20 && reason === 'build') return;
    this.lastAutosave = this.time;
    this.saveTo(AUTOSAVE);
  }
  loadFrom(slot) {
    const s = readSave(this.storage, slot);
    if (!s) { toast('That save is empty', 'warn'); return false; }
    this.loadState(s);
    toast('📂 Game loaded', 'good');
    return true;
  }
  loadState(s) {
    if (this.build.active) this.build.close();
    this.state = s;
    this.story.attach(s);
    this.playerChar.setAppearance(s.appearance);
    this.playerChar.showStaff(!!s.flags.hasTool);
    this.player.teleport(s.player.x, s.player.z, s.player.yaw);
    this.rebuildAllPieces();
    for (const a of this.npcs.list) a.teleportHome();
    this.actions.refreshAll();
    this.build.history.clear();
    this.hud.resources(); this.renderHarmony(); this.renderTracker();
  }
  applySettings() {
    const st = this.settings;
    this.input.sensitivity = st.sensitivity; this.input.invertY = st.invertY;
    if (st.bindings) this.input.setBindings(st.bindings);
    this.audio?.setVolumes(st.music, st.sfx);
    storeSettings(this.storage, st);
  }

  // ---- HUD ------------------------------------------------------------------------------------
  renderHarmony(pop = false) {
    this.hud.harmony(this.state.harmony, nextUnlock(this.state.harmony));
    if (pop) { const h = $('hud-harmony'); h.classList.remove('pop'); void h.offsetWidth; h.classList.add('pop'); }
  }
  renderTracker() {
    const root = $('tracker'); root.innerHTML = '';
    const e = this.story.engine;
    const act = e.active();
    const tracked = act.find(q => q.id === this.state.tracked) || act[0];
    const show = tracked ? [tracked, ...act.filter(q => q !== tracked && q.main).slice(0, 1)] : [];
    for (const q of show) {
      const ready = e.isReady(q.id);
      root.append(el('div', { class: 'track' }, el('h4', {}, q === tracked ? '📍' : '📜', q.title, q.main ? el('span', { class: 'tag' }, 'Story') : null),
        el('ul', {}, q.objectives.filter(o => !o.final || ready).filter(o => q === tracked || !e.objective(q.id, o).done).map(o => {
          const st = e.objective(q.id, o);
          return el('li', { class: st.done ? 'done' : '' }, `${o.text}${st.need > 1 && !st.done ? ` (${o.kind === 'harmony' ? this.state.harmony : st.have}/${st.need})` : ''}`);
        }))));
    }
    if (!show.length) {
      const offer = Object.values(QUEST).find(q => e.canOffer(q.id) && q.main);
      if (offer) root.append(el('div', { class: 'track' }, el('h4', {}, '✨ Next'), el('ul', {}, el('li', {}, `Look for the gold ! — ${this.npcs.byId[offer.giver].def.name} needs help`))));
    }
  }
  updateCompass() {
    const c = $('compass');
    const t = this.mode === 'explore' ? this.story.trackedTarget() : null;
    if (!t) { c.style.opacity = 0; return; }
    const d = Math.hypot(t.x - this.player.pos.x, t.z - this.player.pos.z);
    if (d < 3) { c.style.opacity = 0; return; }
    const v = new THREE.Vector3(t.x, Math.max(0, terrainHeight(t.x, t.z)) + 2.4, t.z).project(this.camera);
    const W = window.innerWidth, H = window.innerHeight;
    let x = (v.x + 1) / 2 * W, y = (1 - v.y) / 2 * H;
    const behind = v.z > 1;
    const on = !behind && x > 40 && x < W - 40 && y > 90 && y < H - 120;
    if (on) { c.textContent = '⭐'; c.style.transform = ''; }
    else {
      if (behind) { x = W - x; y = H - y; }
      const cx = W / 2, cy = H / 2, ang = Math.atan2(y - cy, x - cx);
      const r = Math.min(W / 2 - 50, H / 2 - 110) / Math.max(Math.abs(Math.cos(ang)), Math.abs(Math.sin(ang)) * (W / 2 - 50) / (H / 2 - 110));
      x = cx + Math.cos(ang) * Math.min(r, W / 2 - 50); y = cy + Math.sin(ang) * Math.min(r, H / 2 - 110);
      c.textContent = '➤'; c.style.transform = `rotate(${ang}rad)`;
    }
    c.style.left = `${x}px`; c.style.top = `${y}px`; c.style.opacity = 1; c.title = t.label;
  }
  updateWorldTime(dt) {
    const s = this.state, wasNight = s.flags.night;
    if (this.mode !== 'menu' && this.mode !== 'title') { advanceTime(s.time, dt); s.playTime += dt; }
    const night = isNight(s.time);
    if (night !== wasNight) s.flags.night = night;
    const d = daylight(s.time), h = s.time.minute / 60;
    const weather = this.settings.weather ? weatherAt(s.time) : 'sunny';
    const cloud = weather === 'cloudy' ? 0.35 : weather === 'rain' ? 0.55 : 0;
    const sunset = Math.max(0, 1 - Math.abs(h - 19) / 1.8) + Math.max(0, 1 - Math.abs(h - 6.5) / 1.5);
    const restored = Math.min(1, s.harmony / 150);
    this.sun.intensity = (0.25 + 1.9 * d) * (1 - cloud * 0.6);
    this.sun.color.set('#fff1d6').lerp(tmpC.set('#ff9a5a'), Math.min(1, sunset) * 0.6);
    this.hemi.intensity = 0.45 + 0.75 * d;
    this.hemi.color.set('#9fb4e8').lerp(tmpC.set('#dff3ff'), d).lerp(tmpC.set('#c8ced2'), cloud * 0.5 + (1 - restored) * 0.15);
    const top = tmpC.set('#1d2a5a').lerp(tmpC2.set('#6cc4ff'), d).lerp(tmpC2.set('#9aa9b8'), cloud);
    const bottom = tmpC3.set('#3b4a80').lerp(tmpC2.set('#d9f2ff'), d).lerp(tmpC2.set('#ffb88a'), Math.min(1, sunset) * 0.5 * d + Math.min(1, sunset) * 0.3).lerp(tmpC2.set('#c9d3dc'), cloud);
    this.village.sky.material.uniforms.uTop.value.copy(top);
    this.village.sky.material.uniforms.uBottom.value.copy(bottom);
    this.scene.fog.color.copy(bottom);
    this.village.water.material.uniforms.uNight.value = 1 - d;
    this.rain.visible = weather === 'rain';
    if (this.rain.visible) animateRain(this.rain, dt, this.camera.position);
    const clockIcon = night ? '🌙' : weather === 'rain' ? '🌧️' : weather === 'cloudy' ? '⛅' : '☀️';
    this.hud.clock(`${clockIcon} ${clockText(s.time)}`);
    if (this.actions.hum) this.hud.clock(`${clockIcon} ${clockText(s.time)}  ${'🎵'.repeat(this.actions.hum)}`);
  }
  updateWorldReactions(dt) {
    const s = this.state;
    if (!!s.flags.fountainFlowing !== !!this.mech.fed.fountain) this.setFlag('fountainFlowing', !!this.mech.fed.fountain);
    this.smokeT = (this.smokeT || 0) - dt;
    if (this.smokeT < 0) {
      this.smokeT = 0.5;
      const chim = (id, on) => { const o = this.village.objects[id]; if (on && o?.userData.chimney) this.effects.smoke(o.localToWorld(o.userData.chimney.clone())); };
      chim('bakery', s.flags.squirrelsGone); chim('odessaHouse', true); chim('fernHouse', s.flags.orchardOpen); chim('playerHouse', s.flags.toolGiven);
    }
    if (s.harmony >= 160 && this.player.moving && Math.random() < dt * 8) this.effects.sparkle(new THREE.Vector3(this.player.pos.x, this.player.pos.y + 0.1, this.player.pos.z), { count: 1, up: 0.6, size: 0.18 });
    // Workshop roof turns see-through while you are inside or building in it
    const ws = this.village.objects.workshop, p = this.player.pos;
    const inside = (p.x > -17.5 && p.x < -8.5 && p.z > 6.5 && p.z < 13.5) || (this.build.active && this.build.currentZone?.id === 'workshop');
    ws.userData.roofMat.opacity += ((inside ? 0.12 : 1) - ws.userData.roofMat.opacity) * Math.min(1, dt * 6);
    ws.userData.roofMat.depthWrite = ws.userData.roofMat.opacity > 0.9;
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
    if (ev.action !== 'load') this.autosave('build');
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
  startLoop() {
    const loop = () => { requestAnimationFrame(loop); this.frame(); };
    loop();
  }
  beginPlay() {
    this.started = true;
    $('hud').hidden = false;
    this.hud.resources(); this.renderHarmony(); this.renderTracker();
    this.setMode('explore');
  }
  start() { this.startLoop(); this.beginPlay(); }
  frame() {
    const dt = Math.min(0.1, this.clock.getDelta());
    this.time += dt;
    const input = this.input;
    input.pollGamepad();
    if (this.mode === 'title' || this.mode === 'creator') { this.screens?.update(dt); this.render(); input.endFrame(); return; }
    const buildDragOk = this.mode !== 'build' || input.mouse.dragging === 2 || input.mouse.dragging === 1;
    if (this.mode !== 'menu' && this.mode !== 'dialogue') this.cam.handleInput(input, dt, buildDragOk);
    this.updateWorldTime(dt);
    if (this.mode === 'explore') {
      if (this.sitting) { const mv = input.moveVector(); if (Math.hypot(mv.x, mv.y) > 0.3 || input.pressed('jump')) this.standUp(); else this.playerChar.update(dt, {}); }
      else this.player.update(dt, input, this.cam.moveYaw(), true);
      if (input.pressed('build') && this.build.open()) this.setMode('build');
      else if (input.pressed('inventory')) this.panels.inventory();
      else if (input.pressed('journal')) this.panels.journal();
      else if (input.pressed('map')) this.panels.map();
      else if (input.pressed('progress')) this.panels.progress();
      else if (input.pressed('wardrobe')) this.openWardrobe();
      else if (input.pressed('pause')) this.panels.pause();
    } else if (this.mode === 'build') {
      this.playerChar.update(dt, {});
      this.build.update(dt);
      if (!this.build.active) this.setMode('explore');
    } else {
      this.playerChar.update(dt, {});
      if (this.mode === 'dialogue') this.dialogue.update(dt);
      if (this.mode === 'minigame') this.minigame.update(dt);
      if (this.mode === 'menu') this.panels.update(dt);
    }
    for (const a of this.npcs.list) a.update(dt);
    this.actions.update(dt);
    this.cam.update(dt, this.player.pos);
    this.updateInteraction();
    this.updateHotkeys();
    this.updateCompass();
    this.updateWorldReactions(dt);
    this.village.update(dt, this.time, { ...this.state.flags, fountainFlowing: this.mech.fed.fountain });
    for (let i = this.spawnAnims.length - 1; i >= 0; i--) {
      const a = this.spawnAnims[i]; a.t += dt * 2.6;
      const k = Math.min(1, a.t);
      a.m.scale.setScalar(Math.max(0.01, k >= 1 ? 1 : 1 + Math.sin(k * Math.PI) * 0.25 * (1 - k) * 2 - (1 - k) * (1 - k) * 0.9));
      if (a.t >= 1) this.spawnAnims.splice(i, 1);
    }
    for (const pl of this.state.placements) {
      const m = this.pieceMeshes.get(pl.uid); if (!m) continue;
      animatePiece(m, pl, this.time, dt, { spinning: this.mech.powered.has(pl.uid) || this.mech.sources.has(pl.uid), powered: this.mech.powered.has(pl.uid), watered: this.mech.watered.has(pl.uid), on: pl.state?.on, open: pl.state?.open, night: !!this.state.flags.night });
    }
    this.effects.update(dt);
    this.audio?.update(dt);
    this.render();
    input.endFrame();
  }
  render() {
    const p = this.mode === 'build' ? this.build.focus : this.player.pos;
    this.sun.position.set(p.x + 18, 30, p.z + 12); this.sun.target.position.set(p.x, 0, p.z);
    this.renderer.setScissorTest(false);
    this.renderer.setViewport(0, 0, window.innerWidth, window.innerHeight);
    this.renderer.clear();
    this.renderer.render(this.scene, this.camera);
    if (this.mode === 'dialogue') this.dialogue.renderPortrait(this.renderer, this.scene);
    if (this.mode === 'creator') this.screens?.renderPreview(this.renderer, this.scene);
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

const tmpC = new THREE.Color(), tmpC2 = new THREE.Color(), tmpC3 = new THREE.Color();
function safeStorage() {
  try { const k = '__wh_test'; localStorage.setItem(k, '1'); localStorage.removeItem(k); return localStorage; }
  catch { const m = new Map(); return { getItem: k => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: k => m.delete(k) }; }
}
function makeRain() {
  const n = 1400, pos = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { pos[i * 3] = (Math.random() - 0.5) * 50; pos[i * 3 + 1] = Math.random() * 25; pos[i * 3 + 2] = (Math.random() - 0.5) * 50; }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({ color: '#cfe8ff', size: 0.12, transparent: true, opacity: 0.7, depthWrite: false }));
  pts.visible = false; pts.frustumCulled = false; pts.name = 'rain';
  return pts;
}
function animateRain(rain, dt, cam) {
  const a = rain.geometry.attributes.position;
  for (let i = 0; i < a.count; i++) { let y = a.getY(i) - dt * 14; if (y < 0) y += 25; a.setY(i, y); }
  a.needsUpdate = true;
  rain.position.set(cam.x, 0, cam.z);
}
