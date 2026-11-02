// Everything you can do with the world itself: chop, mine, dig clay, fish, pick, shake, dig treasure,
// open chests, catch fragments, garden, and win over the bakery squirrels.
import * as THREE from 'three';
import { NODES, FEATURES } from '../data/village-layout.js';
import { PIECE } from '../data/pieces.js';
import { ChopGame, MineGame, FishGame } from '../systems/minigames.js';
import { GARDEN_PLOTS, plotAction, plant, water, grow, harvest, plotState } from '../systems/gardening.js';
import { terrainHeight, WATER_Y } from '../systems/heightfield.js';
import { mat, mesh } from '../world/palette.js';
import { toast } from '../ui/dom.js';

const REGROW = { chop: 360, mine: 480, clay: 300, flowers: 240, shake: 90, fruit: 360, fragment: 1440 };
const SQUIRREL_SPOTS = [[-8.4, -3.2], [-13.7, -3.3], [-7.2, -6.6]];

export class WorldActions {
  constructor(game) {
    this.game = game;
    for (const n of NODES) this.registerNode(n);
    for (const f of FEATURES) this.registerFeature(f);
    this.buildGardens();
    this.buildSquirrels();
    this.bobber = mesh(new THREE.SphereGeometry(0.09, 10, 8), mat('#ff5a5f')); this.bobber.visible = false; game.scene.add(this.bobber);
    this.line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]), new THREE.LineBasicMaterial({ color: '#ffffff' }));
    this.line.visible = false; game.scene.add(this.line);
    this.hum = 0;
  }
  get state() { return this.game.state; }
  now() { return this.state.time.total; }
  nodeState(id) { return this.state.nodes[id] || {}; }
  ready(n) {
    const s = this.nodeState(n.id);
    if (s.done) return false;
    if (n.flag && !this.state.flags[n.flag]) return false;
    if (n.kind === 'fruit' && !this.state.flags.orchardOpen) return false;
    return !(s.readyAt > this.now());
  }
  deplete(n) {
    if (['chest', 'dig'].includes(n.kind)) this.state.nodes[n.id] = { done: true };
    else this.state.nodes[n.id] = { readyAt: this.now() + (REGROW[n.kind] || 300) };
    this.refreshNode(n);
  }
  registerNode(n) {
    const g = this.game, obj = g.village.nodeVisuals[n.id];
    const base = { id: n.id, x: n.x, z: n.z, object: obj, available: () => this.ready(n) };
    const labels = { chop: 'Chop tree', mine: 'Mine rock', clay: 'Dig clay', fish: 'Fish here', flowers: 'Pick flowers', shake: 'Shake the oak', fruit: 'Pick apples', chest: 'Open chest', fragment: 'Catch the fragment' };
    if (n.kind === 'dig') { g.addInteractable({ ...base, radius: 0.9, object: null, available: () => this.ready(n) && this.state.flags.hasTool, label: () => 'Dig here — the Starforge Tool is singing!', act: () => this.dig(n) }); return; }
    g.addInteractable({ ...base, radius: n.kind === 'mine' ? 2.0 : n.kind === 'fish' ? 1.3 : 1.7, label: () => labels[n.kind], act: () => this.act(n) });
  }
  registerFeature(f) {
    const g = this.game;
    if (f.kind === 'rest') g.addInteractable({ id: f.id, x: f.x, z: f.z, radius: 1.3, label: () => 'Rest until morning', act: () => g.rest() });
    if (f.kind === 'wardrobe') g.addInteractable({ id: f.id, x: f.x, z: f.z, object: g.village.objects[f.id], label: () => 'Change outfit', act: () => g.openWardrobe() });
    if (f.kind === 'board') g.addInteractable({ id: f.id, x: f.x, z: f.z, object: g.village.objects[f.id], label: () => 'Read the notice board', act: () => g.panels.noticeBoard() });
    if (f.kind === 'boat') g.addInteractable({ id: f.id, x: f.x, z: f.z, radius: 2.6, available: () => !!this.state.flags.boatReady, object: g.village.objects.boat, label: () => 'Board the ferry', act: () => g.panels.map(true) });
  }
  act(n) {
    const g = this.game, src = new THREE.Vector3(n.x, terrainHeight(n.x, n.z) + 1, n.z);
    g.player.yaw = Math.atan2(n.x - g.player.pos.x, n.z - g.player.pos.z); g.player.sync();
    switch (n.kind) {
      case 'chop':
        return g.startMinigame('chop', new ChopGame(), mg => { if (!mg) return; const r = mg.reward(); g.give(r, { source: src }); g.state.stats.chopped++; this.deplete(n); g.effects.poof(src, { color: '#9fdc7a' }); g.sfx('collect'); });
      case 'mine':
        return g.startMinigame('mine', new MineGame({ rich: n.rich }), mg => { if (!mg) return; g.give(mg.reward(), { source: src }); g.state.stats.mined++; this.deplete(n); g.sfx('collect'); });
      case 'fish': return this.fish(n);
      case 'clay': g.playerChar.play('dig'); g.sfx('dig'); setTimeout(() => { g.give({ clay: 2, spark: 1 }, { source: src }); this.deplete(n); }, 500); return;
      case 'flowers': g.playerChar.play('dig'); g.sfx('pick'); g.give({ flowers: 2, spark: 1 }, { source: src }); this.deplete(n); return;
      case 'shake': {
        g.sfx('rustle'); g.cam.shake = 0.3;
        const obj = g.village.nodeVisuals[n.id]; obj.userData.shake = 0.6;
        g.give({ acorn: 3, spark: 1 }, { source: src.clone().setY(src.y + 1) }); this.deplete(n); return;
      }
      case 'fruit': g.sfx('pick'); g.give({ fruit: 2, spark: 1 }, { source: src.setY(src.y + 1) }); this.deplete(n); return;
      case 'chest': return this.openChest(n);
      case 'fragment': return this.catchFragment(n);
    }
  }
  catchFragment(n) {
    const g = this.game;
    const p = new THREE.Vector3(n.x, terrainHeight(n.x, n.z) + 1, n.z);
    g.give({ fragment: 1, spark: 5 }, { source: p });
    g.effects.sparkle(p, { count: 20, color: '#c9a8ff' });
    g.sfx('sparkle'); g.state.stats.fragments++;
    this.deplete(n);
  }
  openChest(n) {
    const g = this.game, s = this.state;
    const p = new THREE.Vector3(n.x, terrainHeight(n.x, n.z) + 0.8, n.z);
    g.sfx('chest'); g.playerChar.play('surprised');
    g.give(n.loot, { source: p });
    if (n.blueprint) g.story.unlockBlueprints([n.blueprint], 'treasure chest');
    if (n.outfit) g.story.unlockClothes([n.outfit]);
    s.stats.chests++; s.stats.treasures++;
    this.deplete(n);
    g.effects.sparkle(p, { count: 26 });
    g.story.event('treasure'); g.story.event('chest');
  }
  dig(n) {
    const g = this.game;
    const p = new THREE.Vector3(n.x, terrainHeight(n.x, n.z) + 0.3, n.z);
    g.playerChar.play('dig'); g.sfx('dig');
    setTimeout(() => {
      const loot = [{ crystal: 1, spark: 6 }, { fabric: 2, spark: 6 }, { metal: 2, spark: 6 }, { crystal: 1, fabric: 1, spark: 6 }, { metal: 1, crystal: 1, spark: 6 }][NODES.filter(x => x.kind === 'dig').indexOf(n) % 5];
      g.give(loot, { source: p });
      g.effects.sparkle(p, { count: 22 });
      g.state.stats.dug++; g.state.stats.treasures++;
      this.deplete(n);
      g.sfx('chest');
      g.story.event('treasure'); g.story.event('dig');
    }, 650);
  }
  fish(n) {
    const g = this.game;
    g.player.teleport(n.x, n.z, n.facing ?? Math.PI); g.player.yaw = n.facing ?? Math.PI; g.player.sync();
    const fx = n.x + Math.sin(g.player.yaw) * 3, fz = n.z + Math.cos(g.player.yaw) * 3;
    this.bobber.position.set(fx, WATER_Y + 0.05, fz); this.bobber.visible = true; this.line.visible = true;
    g.playerChar.play('cast', true); g.sfx('cast');
    const mg = new FishGame();
    this.fishing = { mg, fx, fz };
    g.startMinigame('fish', mg, res => {
      this.bobber.visible = false; this.line.visible = false; this.fishing = null; g.playerChar.stopHold();
      if (!res || res.result !== 'caught') return;
      g.give(res.reward(), { source: new THREE.Vector3(fx, 0.3, fz) });
      g.effects.splash(new THREE.Vector3(fx, WATER_Y + 0.1, fz));
      g.playerChar.play('celebrate'); g.sfx('fanfareSmall');
      g.state.stats.fish++;
      toast(`You caught a ${res.caught.name}!`, 'good');
      g.story.event('fish');
    });
  }
  refreshNode(n) {
    const o = this.game.village.nodeVisuals[n.id]; if (!o) return;
    const ready = this.ready(n);
    switch (n.kind) {
      case 'chop': o.visible = ready; if (o.userData.stump) o.userData.stump.visible = !ready; break;
      case 'mine': o.scale.setScalar(ready ? 1 : 0.45); break;
      case 'clay': case 'flowers': case 'fragment': o.visible = ready; break;
      case 'fruit': { const f = o.getObjectByName('fruit'); if (f) f.visible = ready; break; }
      case 'shake': { const a = o.getObjectByName('acorns'); if (a) a.visible = ready; break; }
      case 'chest': { const lid = o.getObjectByName('lid'); if (lid) lid.rotation.x = this.nodeState(n.id).done ? -1.9 : 0; break; }
      case 'dig': o.visible = !!this.nodeState(n.id).done; break;
    }
    if (ready && o.userData.wasDepleted) { o.userData.pop = 0; this.game.effects.sparkle(o.position.clone().add(new THREE.Vector3(0, 0.8, 0)), { count: 8, color: '#bfffb0' }); }
    o.userData.wasDepleted = !ready;
  }
  refreshAll() { for (const n of NODES) this.refreshNode(n); this.refreshGardens(); this.placeSquirrels(); }

  // ---- Gardens ----
  buildGardens() {
    const g = this.game;
    this.plots = GARDEN_PLOTS.map(p => {
      const group = new THREE.Group(); group.position.set(p.x, 0.17, p.z); g.scene.add(group);
      const soil = mesh(new THREE.BoxGeometry(1.4, 0.03, 0.9), mat('#7a4a2a')); soil.position.y = 0.01; group.add(soil);
      const plant = new THREE.Group(); group.add(plant);
      g.addInteractable({ id: p.id, x: p.x, z: p.z, radius: 1.1, object: group, label: () => ({ plant: 'Plant a seed', needSeeds: 'Garden bed (you need seeds)', water: 'Water the seedling', growing: 'Growing nicely…', harvest: 'Pick the bloom' })[plotAction(this.state.gardens, p.id, this.state.inventory)], act: () => this.gardenAct(p) });
      return { def: p, group, soil, plant };
    });
  }
  gardenAct(p) {
    const g = this.game, s = this.state, a = plotAction(s.gardens, p.id, s.inventory);
    const pos = new THREE.Vector3(p.x, 0.5, p.z);
    if (a === 'plant') { plant(s.gardens, p.id, this.now()); s.inventory.seeds--; g.hud.resources(['seeds']); g.playerChar.play('dig'); g.sfx('dig'); g.story.event('plant'); toast('Planted! Now give it some water.'); }
    else if (a === 'water') { water(s.gardens, p.id, this.now()); g.playerChar.play('feed'); g.effects.splash(pos); g.sfx('water'); g.story.event('water'); toast('Watered. It will grow while you explore.'); }
    else if (a === 'harvest') { const r = harvest(s.gardens, p.id); g.give(r, { source: pos }); g.sfx('pick'); g.story.event('harvest'); }
    else if (a === 'needSeeds') toast('You need flower seeds. Fern might have some!', 'warn');
    else toast('The little plant is soaking up the sun. Come back in a bit!');
    this.refreshGardens();
  }
  refreshGardens() {
    for (const pl of this.plots) {
      const st = plotState(this.state.gardens, pl.def.id);
      if (pl.stage === st.stage && pl.watered === st.watered) continue;
      pl.stage = st.stage; pl.watered = st.watered;
      pl.soil.material = mat(st.watered ? '#5a3420' : '#7a4a2a');
      pl.plant.clear();
      if (st.stage < 0) continue;
      for (const x of [-0.35, 0, 0.35]) {
        if (st.stage === 0) { const s = mesh(new THREE.SphereGeometry(0.06, 6, 4), mat('#8b5a3c')); s.position.set(x, 0.04, 0); pl.plant.add(s); continue; }
        const h = 0.15 + st.stage * 0.14;
        const stem = mesh(new THREE.CylinderGeometry(0.02, 0.025, h, 5), mat('#4f9e45')); stem.position.set(x, h / 2, 0); pl.plant.add(stem);
        const leaf = mesh(new THREE.SphereGeometry(0.07, 6, 4), mat('#6cc65a')); leaf.scale.set(1.4, 0.4, 0.8); leaf.position.set(x + 0.05, h * 0.5, 0); pl.plant.add(leaf);
        if (st.stage >= 2) { const bud = mesh(new THREE.SphereGeometry(st.stage === 3 ? 0.13 : 0.07, 8, 6), mat(st.stage === 3 ? ['#ff7aa8', '#ffd84a', '#b98cff'][Math.round((x + 0.35) / 0.35)] : '#9fdc7a')); bud.position.set(x, h + 0.04, 0); pl.plant.add(bud); }
      }
    }
  }

  // ---- Squirrels ----
  buildSquirrels() {
    const g = this.game;
    this.squirrels = SQUIRREL_SPOTS.map(([x, z], n) => {
      const s = new THREE.Group();
      const body = mesh(new THREE.SphereGeometry(0.18, 10, 8), mat('#b5733f')); body.scale.set(0.9, 1.1, 1); body.position.y = 0.18; s.add(body);
      const head = mesh(new THREE.SphereGeometry(0.13, 10, 8), mat('#b5733f')); head.position.set(0, 0.38, 0.1); s.add(head);
      for (const sx of [-1, 1]) { const ear = mesh(new THREE.ConeGeometry(0.04, 0.09, 5), mat('#9a5f30')); ear.position.set(sx * 0.07, 0.5, 0.08); s.add(ear); const eye = mesh(new THREE.SphereGeometry(0.022, 6, 4), mat('#1d1414')); eye.position.set(sx * 0.055, 0.41, 0.21); s.add(eye); }
      const tail = mesh(new THREE.SphereGeometry(0.17, 10, 8), mat('#c98447')); tail.scale.set(0.7, 1.5, 0.7); tail.position.set(0, 0.36, -0.2); tail.rotation.x = -0.4; s.add(tail);
      g.scene.add(s);
      const sq = { n, obj: s, home: [x, z], t: Math.random() * 10, pos: { x, z } };
      g.addInteractable({ id: `squirrel${n}`, x: () => sq.pos.x, z: () => sq.pos.z, radius: 1.3, object: s, available: () => !this.squirrelFed(n),
        label: () => (this.state.quests.squirrels?.status === 'active' && this.state.inventory.acorn > 0 ? 'Offer an acorn' : 'Say hello to the squirrel'), act: () => this.feedSquirrel(sq) });
      return sq;
    });
    this.placeSquirrels();
  }
  squirrelFed(n) { return !!this.state.flags.squirrelsGone || !!this.state.flags[`squirrelFed${n}`]; }
  feedSquirrel(sq) {
    const g = this.game, s = this.state;
    if (s.quests.squirrels?.status !== 'active' || !(s.inventory.acorn > 0)) {
      g.sfx('squeak');
      toast(s.inventory.acorn > 0 ? 'The squirrel eyes your acorns hungrily… Mabel might want to hear about this.' : 'The squirrel looks at your empty hands, deeply unimpressed.');
      return;
    }
    s.inventory.acorn--; g.hud.resources(['acorn']);
    s.flags[`squirrelFed${sq.n}`] = true;
    g.playerChar.play('feed'); g.sfx('squeak');
    g.effects.hearts(sq.obj.position.clone().add(new THREE.Vector3(0, 0.6, 0)));
    toast('Munch munch! The squirrel scampers happily back to the oak.', 'good');
    g.story.event('feed');
  }
  placeSquirrels() {
    for (const sq of this.squirrels || []) {
      if (this.squirrelFed(sq.n)) { sq.home = [-16.5 + [-0.6, 0.5, 0.1][sq.n], -1.5 + [0.4, 0.2, -0.6][sq.n]]; sq.up = 1.9 + sq.n * 0.25; }
      else sq.up = 0;
    }
  }

  update(dt) {
    const g = this.game, s = this.state;
    // Regrowth
    this.checkT = (this.checkT || 0) - dt;
    if (this.checkT <= 0) {
      this.checkT = 1;
      for (const n of NODES) { const was = this.game.village.nodeVisuals[n.id]?.userData.wasDepleted; if (was && this.ready(n)) this.refreshNode(n); }
      if (grow(s.gardens, this.now())) this.refreshGardens();
    }
    // Fragments: catch them just by walking through
    const p = g.player.pos;
    if (g.mode === 'explore') for (const n of NODES) if (n.kind === 'fragment' && this.ready(n) && Math.hypot(n.x - p.x, n.z - p.z) < 1.1) this.catchFragment(n);
    // Treasure hum: the closer to buried treasure, the louder the tool sings.
    let best = Infinity;
    if (s.flags.hasTool) for (const n of NODES) if (n.kind === 'dig' && this.ready(n)) best = Math.min(best, Math.hypot(n.x - p.x, n.z - p.z));
    this.hum = best < 3 ? 3 : best < 7 ? 2 : best < 13 ? 1 : 0;
    if (this.hum >= 2 && Math.random() < dt * (this.hum === 3 ? 4 : 1.5)) {
      for (const n of NODES) if (n.kind === 'dig' && this.ready(n) && Math.hypot(n.x - p.x, n.z - p.z) < 7) g.effects.sparkle(new THREE.Vector3(n.x, terrainHeight(n.x, n.z) + 0.1, n.z), { count: 2, up: 0.8, size: 0.2 });
    }
    // Shaken oak wobble
    for (const n of NODES) { const o = g.village.nodeVisuals[n.id]; if (o?.userData.shake > 0) { o.userData.shake -= dt; o.rotation.z = Math.sin(o.userData.shake * 40) * 0.05; } }
    // Squirrels hop about
    for (const sq of this.squirrels) {
      sq.t += dt;
      const r = sq.up ? 0.2 : 0.9;
      sq.pos.x = sq.home[0] + Math.sin(sq.t * 0.7 + sq.n) * r; sq.pos.z = sq.home[1] + Math.cos(sq.t * 0.5 + sq.n * 2) * r;
      const hop = Math.abs(Math.sin(sq.t * 5)) * 0.15;
      sq.obj.position.set(sq.pos.x, (sq.up || terrainHeight(sq.pos.x, sq.pos.z)) + hop, sq.pos.z);
      sq.obj.rotation.y = Math.atan2(Math.cos(sq.t * 0.7 + sq.n) * 0.7, -Math.sin(sq.t * 0.5 + sq.n * 2) * 0.5);
    }
    // Fishing line and bobber
    if (this.fishing) {
      const { mg, fx, fz } = this.fishing;
      const dip = mg.phase === 'bite' ? -0.12 + Math.sin(g.time * 30) * 0.04 : mg.phase === 'reel' ? Math.sin(g.time * 12) * 0.05 : Math.sin(g.time * 2) * 0.02;
      this.bobber.position.y = WATER_Y + 0.05 + dip;
      const hand = g.playerChar.parts.armR.localToWorld(new THREE.Vector3(0, -0.6, 0.3));
      this.line.geometry.setFromPoints([hand, this.bobber.position.clone()]);
      if (mg.phase === 'reel' && g.playerChar.hold !== 'reel') g.playerChar.play('reel', true);
    }
  }
}
export { PIECE };
