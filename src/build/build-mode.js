// Starforge build mode: catalog, transparent preview, grid snapping, placement, selection, move, rotate,
// remove, recolour, undo/redo. Rules come from systems/build-grid.js; this file is the interactive layer.
import * as THREE from 'three';
import { PIECE, PIECES, CATEGORIES, COLOR_PALETTE } from '../data/pieces.js';
import { RESOURCES } from '../data/resources.js';
import { ZONES } from '../data/village-layout.js';
import { footprint, suggestBottom, validatePlacement, validateRemoval, zoneBounds, zoneAt } from '../systems/build-grid.js';
import { canAfford, missing } from '../systems/inventory.js';
import { History } from '../systems/history.js';
import { terrainHeight, WATER_Y, WALKABLE_MIN } from '../systems/heightfield.js';
import { makeGhost, setGhostKind } from './piece-meshes.js';
import { keyLabel } from '../core/bindings.js';
import { $, el, toast } from '../ui/dom.js';

const costText = cost => Object.entries(cost).map(([k, n]) => `${RESOURCES[k]?.icon || k}${n}`).join(' ');

export class BuildMode {
  constructor(game) {
    this.game = game;
    this.active = false;
    this.category = 'structure';
    this.itemId = null;      // catalog piece being placed
    this.rotation = 0;
    this.color = null;
    this.half = false;
    this.selected = null;    // uid of a selected placed piece
    this.moving = null;      // { pl, from } while carrying a placed piece
    this.history = new History();
    this.ray = new THREE.Raycaster();
    this.ndc = new THREE.Vector2();
    this.focus = new THREE.Vector3();
    this.gridGroup = new THREE.Group(); this.gridGroup.name = 'build-grid'; this.gridGroup.visible = false;
    this.planGroup = new THREE.Group(); this.planGroup.name = 'build-plan';
    game.scene.add(this.gridGroup, this.planGroup);
    this.ghost = null; this.ghostKey = '';
    this.hover = null; this.check = null;
    this.selBox = new THREE.Box3Helper(new THREE.Box3(), new THREE.Color('#a07cff')); this.selBox.visible = false; game.scene.add(this.selBox);
    this.zoneIndex = 0;
  }
  get state() { return this.game.state; }
  unlockedZones() { return ZONES.filter(z => this.game.zoneUnlocked(z)); }
  lockedZones() { return ZONES.filter(z => !this.game.zoneUnlocked(z)); }

  open(zoneId) {
    if (!this.state.flags.hasTool) { toast('You need the Starforge Tool first — Odessa might know where it is!', 'warn'); return false; }
    this.active = true;
    const zones = this.unlockedZones();
    const p = this.game.player.pos;
    let zone = zones.find(z => z.id === zoneId) || zoneAt(zones, Math.floor(p.x), Math.floor(p.z), this.state.harmony);
    if (!zone) zone = zones.slice().sort((a, b) => zdist(a, p) - zdist(b, p))[0];
    this.zoneIndex = Math.max(0, zones.indexOf(zone));
    this.jumpToZone(zone);
    this.rebuildGrid();
    this.refreshPlan();
    this.gridGroup.visible = true;
    $('hotkeys').hidden = true;
    this.game.cam.setMode('build');
    this.game.playerChar.play('build', true);
    this.game.playerChar.showStaff(true);
    $('build-ui').hidden = false;
    this.render();
    this.game.bus.emit('buildmode', { open: true, zone: zone?.id });
    return true;
  }
  close() {
    if (this.moving) this.cancelMove();
    this.active = false; this.itemId = null; this.selected = null;
    this.clearGhost(); this.selBox.visible = false;
    this.gridGroup.visible = false;
    this.game.cam.setMode('explore');
    this.game.playerChar.stopHold();
    $('build-ui').hidden = true;
    $('hotkeys').hidden = false;
    this.game.bus.emit('buildmode', { open: false });
  }
  jumpToZone(zone) {
    if (!zone) { this.focus.set(this.game.player.pos.x, 0, this.game.player.pos.z); return; }
    const b = zoneBounds(zone, this.state.harmony);
    this.focus.set((b.minI + b.maxI + 1) / 2, Math.max(0, zone.spanY ?? 0), (b.minK + b.maxK + 1) / 2);
    this.currentZone = zone;
  }
  cycleZone(dir) {
    const zones = this.unlockedZones(); if (!zones.length) return;
    this.zoneIndex = (this.zoneIndex + dir + zones.length) % zones.length;
    this.jumpToZone(zones[this.zoneIndex]); this.render();
  }

  // Grid and plan visuals ---------------------------------------------------------------------
  cellY(zone, i, k) {
    const g = terrainHeight(i + 0.5, k + 0.5);
    return (g < WALKABLE_MIN && zone.spanY !== undefined ? zone.spanY : Math.max(g, WATER_Y)) + 0.04;
  }
  rebuildGrid() {
    this.gridGroup.clear();
    for (const zone of ZONES) {
      const unlocked = this.game.zoneUnlocked(zone);
      const b = zoneBounds(zone, this.state.harmony);
      const pts = [], fill = [];
      for (let i = b.minI; i <= b.maxI; i++) for (let k = b.minK; k <= b.maxK; k++) {
        const y = this.cellY(zone, i, k);
        pts.push(i, y, k, i + 1, y, k, i, y, k, i, y, k + 1);
        if (i === b.maxI) pts.push(i + 1, y, k, i + 1, y, k + 1);
        if (k === b.maxK) pts.push(i, y, k + 1, i + 1, y, k + 1);
        fill.push(i + 0.04, y - 0.01, k + 0.04, i + 0.96, y - 0.01, k + 0.04, i + 0.96, y - 0.01, k + 0.96, i + 0.04, y - 0.01, k + 0.04, i + 0.96, y - 0.01, k + 0.96, i + 0.04, y - 0.01, k + 0.96);
      }
      const lg = new THREE.BufferGeometry(); lg.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
      const lines = new THREE.LineSegments(lg, new THREE.LineBasicMaterial({ color: unlocked ? '#ffffff' : '#9a8f9f', transparent: true, opacity: unlocked ? 0.8 : 0.35 }));
      const fg = new THREE.BufferGeometry(); fg.setAttribute('position', new THREE.Float32BufferAttribute(fill, 3));
      const area = new THREE.Mesh(fg, new THREE.MeshBasicMaterial({ color: unlocked ? '#c9a8ff' : '#777777', transparent: true, opacity: unlocked ? 0.22 : 0.12, depthWrite: false, side: THREE.DoubleSide }));
      lines.renderOrder = 3; area.renderOrder = 2;
      this.gridGroup.add(lines, area);
    }
    for (const z of [...(this.game.buildEndpoints?.() || [])]) this.gridGroup.add(z);
  }
  // Suggested layouts for quest zones the player is working on.
  refreshPlan() {
    this.planGroup.clear();
    for (const zone of ZONES) {
      if (!zone.blueprint || !this.game.zonePlanVisible(zone)) continue;
      for (const [i, k, id, r = 0] of zone.blueprint) {
        if (this.state.placements.some(p => p.id === id && p.i === i && p.k === k)) continue;
        const g = makeGhost(id, 'plan');
        const y = suggestBottom(id, i, k, r, id === 'bridgeDeck' ? 0.2 : -5, [], { zone });
        const [fw, fd] = footprint(PIECE[id], r);
        g.position.set(i + fw / 2, y + 0.01, k + fd / 2); g.rotation.y = -r * Math.PI / 2;
        this.planGroup.add(g);
      }
    }
  }

  // Input & cursor ----------------------------------------------------------------------------
  pickRay() {
    const m = this.game.input.mouse;
    this.ndc.set((m.x / window.innerWidth) * 2 - 1, -(m.y / window.innerHeight) * 2 + 1);
    this.ray.setFromCamera(this.ndc, this.game.camera);
    const targets = [this.game.village.terrain, ...this.game.pieceMeshes.values()].filter(o => !this.moving || o !== this.game.pieceMeshes.get(this.moving.pl.uid));
    const hits = this.ray.intersectObjects(targets, true);
    if (!hits.length) return null;
    const h = hits[0];
    let o = h.object, uid = null;
    while (o) { if (o.userData.uid) { uid = o.userData.uid; break; } o = o.parent; }
    const n = h.face ? h.face.normal.clone().transformDirection(h.object.matrixWorld) : new THREE.Vector3(0, 1, 0);
    const p = h.point.clone();
    let hitY = p.y;
    if (!uid && p.y < WATER_Y) { // looking through water: aim at deck height, where bridges are built
      const t = (0.1 - this.ray.ray.origin.y) / this.ray.ray.direction.y;
      if (t > 0) p.copy(this.ray.ray.origin).addScaledVector(this.ray.ray.direction, t);
      hitY = 0.2;
    }
    if (uid && n.y < 0.6) { p.addScaledVector(n, 0.35); }
    return { point: p, normal: n, uid, hitY };
  }
  cellFor(def, r, p) {
    const [fw, fd] = footprint(def, r);
    if (this.half) return [Math.floor((p.x - fw / 2 + 0.25) * 2) / 2, Math.floor((p.z - fd / 2 + 0.25) * 2) / 2];
    return [Math.floor(p.x - fw / 2 + 0.5), Math.floor(p.z - fd / 2 + 0.5)];
  }
  candidate() {
    const id = this.moving ? this.moving.pl.id : this.itemId;
    if (!id || !this.hover) return null;
    const def = PIECE[id], r = this.moving ? this.moving.r : this.rotation;
    if (def.attach === 'wall') {
      const wall = this.hover.uid && this.state.placements.find(p => p.uid === this.hover.uid && PIECE[p.id].edge && PIECE[p.id].h >= 2);
      if (!wall) { const [i, k] = this.cellFor(def, r, this.hover.point); return { id, i, k, r, y: this.hover.point.y, noWall: true }; }
      return { id, i: wall.i, k: wall.k, r: wall.r, y: wall.y + 0.9 };
    }
    const [i, k] = this.cellFor(def, r, this.hover.point);
    const zone = zoneAt(ZONES, i, k, this.state.harmony);
    const others = this.state.placements.filter(p => !this.moving || p.uid !== this.moving.pl.uid);
    const y = suggestBottom(id, i, k, r, this.hover.hitY, others, { zone });
    return { id, i, k, r, y };
  }
  evaluate(c) {
    const others = this.state.placements.filter(p => !this.moving || p.uid !== this.moving.pl.uid);
    const pl = { uid: this.moving ? this.moving.pl.uid : -1, ...c, color: this.moving ? this.moving.pl.color : this.color, state: this.moving?.pl.state };
    if (c.noWall) return { pl, ok: false, reason: 'Point at a wall to hang this' };
    const v = validatePlacement(pl, this.game.placementCtx(others));
    if (!v.ok) return { pl, ...v };
    if (!this.moving && !canAfford(this.state.inventory, PIECE[c.id].cost)) {
      const m = missing(this.state.inventory, PIECE[c.id].cost).map(x => `${x.need} more ${RESOURCES[x.id].icon} ${RESOURCES[x.id].name.toLowerCase()}`).join(', ');
      return { pl, ok: false, reason: `Not enough materials — need ${m}`, poor: true };
    }
    return { pl, ok: true, zone: v.zone };
  }
  clearGhost() { if (this.ghost) { this.game.scene.remove(this.ghost); this.ghost = null; this.ghostKey = ''; } }

  update(dt) {
    const g = this.game, input = g.input;
    // Pan the build camera with WASD relative to the view
    const mv = input.moveVector(), yaw = g.cam.moveYaw();
    const fx = -Math.sin(yaw), fz = -Math.cos(yaw), speed = 9 * (input.down('sprint') ? 2 : 1) * dt;
    this.focus.x += (fx * mv.y - fz * mv.x) * speed; this.focus.z += (fz * mv.y + fx * mv.x) * speed;
    this.focus.x = Math.max(-55, Math.min(55, this.focus.x)); this.focus.z = Math.max(-55, Math.min(55, this.focus.z));
    g.cam.focus.copy(this.focus).setY(Math.max(terrainHeight(this.focus.x, this.focus.z), this.focus.y) + 0.5);

    if (input.pressed('pause')) { if (this.moving) this.cancelMove(); else if (this.itemId || this.selected) { this.itemId = null; this.selected = null; this.render(); } else { this.close(); return; } }
    if (input.pressed('build')) { this.close(); return; }
    if (input.pressed('rotate')) this.rotate();
    if (input.pressed('halfGrid')) { this.half = !this.half; toast(this.half ? 'Half-grid snapping on' : 'Half-grid snapping off'); this.render(); }
    if (input.pressed('recolor')) this.cycleColor();
    if (input.ctrl && input.codePressed('KeyZ')) this.undo();
    if (input.ctrl && input.codePressed('KeyY')) this.redo();
    if (input.pressed('remove')) this.removeTarget();
    if (input.codePressed('KeyM') && this.selected && !this.moving) this.startMove(this.selected);
    if (input.codePressed('BracketLeft')) this.cycleZone(-1);
    if (input.codePressed('BracketRight')) this.cycleZone(1);

    this.hover = input.mouse.overUI ? null : this.pickRay();
    const c = this.candidate();
    if (c) {
      const key = `${c.id}|${c.i}|${c.k}|${c.r}|${c.y.toFixed(2)}|${this.state.placements.length}|${JSON.stringify(this.state.inventory)}`;
      if (key !== this.ghostKey || !this.ghost || this.ghost.userData.id !== c.id) {
        this.check = this.evaluate(c);
        if (!this.ghost || this.ghost.userData.id !== c.id) { this.clearGhost(); this.ghost = makeGhost(c.id, 'ok'); this.ghost.userData.id = c.id; g.scene.add(this.ghost); }
        const [fw, fd] = footprint(PIECE[c.id], c.r);
        this.ghost.position.set(c.i + fw / 2, c.y + 0.005, c.k + fd / 2);
        this.ghost.rotation.y = -c.r * Math.PI / 2;
        setGhostKind(this.ghost, this.check.ok ? 'ok' : 'bad');
        this.ghostKey = key;
        this.renderStatus();
      }
      this.ghost.visible = true;
    } else { if (this.ghost) this.ghost.visible = false; if (this.check) { this.check = null; this.renderStatus(); } }

    // Selection box follows the selected piece
    const selMesh = this.selected && g.pieceMeshes.get(this.selected);
    this.selBox.visible = !!selMesh && !this.moving;
    if (selMesh) this.selBox.box.setFromObject(selMesh).expandByScalar(0.05);

    if (input.mouse.leftClick && !input.mouse.overUI) this.click();
    if (input.mouse.rightClick && !input.mouse.overUI) { if (this.moving) this.cancelMove(); else if (this.itemId || this.selected) { this.itemId = null; this.selected = null; this.render(); } }
  }
  click() {
    if (this.moving) return this.dropMove();
    if (this.itemId) return this.place();
    if (this.hover?.uid) { this.selected = this.hover.uid; this.game.sfx('select'); this.render(); }
    else if (this.selected) { this.selected = null; this.render(); }
  }

  // Commands -----------------------------------------------------------------------------------
  place() {
    const c = this.check;
    if (!c) return;
    if (!c.ok) { toast(c.reason, 'warn'); this.game.sfx('error'); return; }
    const pl = { ...c.pl, uid: this.state.nextUid++, color: this.color && PIECE[c.pl.id].colorable ? this.color : undefined };
    if (PIECE[pl.id].switch) pl.state = { on: true };
    if (PIECE[pl.id].door) pl.state = { open: false };
    const r = this.game.commitPlace(pl, true);
    if (r.ok) { this.history.push({ type: 'place', pl: structuredClone(pl) }); this.ghostKey = ''; this.render(); }
  }
  removeTarget() {
    const uid = this.selected || this.hover?.uid;
    if (!uid) { toast('Point at a piece to remove it'); return; }
    const pl = this.state.placements.find(p => p.uid === uid);
    const r = this.game.commitRemove(uid);
    if (r.ok) { this.history.push({ type: 'remove', pl: structuredClone(pl) }); this.selected = null; this.render(); }
    else toast(r.reason, 'warn');
  }
  rotate() {
    if (this.moving) { this.moving.r = (this.moving.r + 1) % 4; this.ghostKey = ''; return; }
    if (this.itemId) { this.rotation = (this.rotation + 1) % 4; this.ghostKey = ''; this.game.sfx('tick'); return; }
    if (this.selected) {
      const pl = this.state.placements.find(p => p.uid === this.selected);
      const from = { i: pl.i, k: pl.k, r: pl.r, y: pl.y };
      const to = { ...from, r: (pl.r + 1) % 4 };
      const r = this.game.commitMove(pl.uid, to);
      if (r.ok) this.history.push({ type: 'move', uid: pl.uid, from, to });
      else toast(r.reason, 'warn');
    }
  }
  startMove(uid) {
    const pl = this.state.placements.find(p => p.uid === uid);
    if (!pl) return;
    // Lifting it must not leave anything floating.
    const rm = validateRemoval(uid, this.game.placementCtx());
    if (!rm.ok) { toast(rm.reason, 'warn'); return; }
    this.moving = { pl, from: { i: pl.i, k: pl.k, r: pl.r, y: pl.y }, r: pl.r };
    this.itemId = null;
    this.game.pieceMeshes.get(uid).visible = false;
    this.render();
  }
  dropMove() {
    const c = this.check;
    if (!c || !c.ok) { toast(c?.reason || 'Point somewhere to put it down', 'warn'); this.game.sfx('error'); return; }
    const { pl, from } = this.moving;
    const to = { i: c.pl.i, k: c.pl.k, r: c.pl.r, y: c.pl.y };
    this.game.pieceMeshes.get(pl.uid).visible = true;
    this.moving = null;
    const r = this.game.commitMove(pl.uid, to);
    if (r.ok) { this.history.push({ type: 'move', uid: pl.uid, from, to }); this.selected = pl.uid; }
    else toast(r.reason, 'warn');
    this.clearGhost(); this.render();
  }
  cancelMove() {
    if (!this.moving) return;
    this.game.pieceMeshes.get(this.moving.pl.uid).visible = true;
    this.moving = null; this.clearGhost(); this.render();
  }
  cycleColor() {
    const cur = this.selected ? (this.state.placements.find(p => p.uid === this.selected)?.color) : this.color;
    const n = (COLOR_PALETTE.indexOf(cur) + 1) % COLOR_PALETTE.length;
    this.setColor(COLOR_PALETTE[n]);
  }
  setColor(color) {
    if (this.selected) {
      const pl = this.state.placements.find(p => p.uid === this.selected);
      if (!PIECE[pl.id].colorable) { toast("This piece can't be recoloured"); return; }
      const from = pl.color || null;
      this.game.commitRecolor(pl.uid, color);
      this.history.push({ type: 'recolor', uid: pl.uid, from, to: color });
    } else { this.color = color; this.render(); }
  }
  undo() { const r = this.history.undo((c, d) => this.apply(c, d)); if (!r.ok) toast(r.reason, 'warn'); else { this.game.sfx('undo'); toast('Undone'); } this.render(); }
  redo() { const r = this.history.redo((c, d) => this.apply(c, d)); if (!r.ok) toast(r.reason, 'warn'); else { this.game.sfx('undo'); toast('Redone'); } this.render(); }
  apply(cmd, dir) {
    const g = this.game;
    const placeIt = pl => g.commitPlace(structuredClone(pl), true, { checkCost: true });
    switch (cmd.type) {
      case 'place': return dir === 'undo' ? g.commitRemove(cmd.pl.uid) : placeIt(cmd.pl);
      case 'remove': return dir === 'undo' ? placeIt(cmd.pl) : g.commitRemove(cmd.pl.uid);
      case 'move': return g.commitMove(cmd.uid, dir === 'undo' ? cmd.from : cmd.to);
      case 'recolor': return g.commitRecolor(cmd.uid, dir === 'undo' ? cmd.from : cmd.to);
    }
    return { ok: false, reason: 'Unknown action' };
  }
  selectItem(id) {
    if (!this.state.blueprints.includes(id)) { toast(`Locked — ${this.game.blueprintHint(id)}`, 'warn'); return; }
    if (this.moving) this.cancelMove();
    this.itemId = this.itemId === id ? null : id;
    this.selected = null; this.ghostKey = '';
    this.state.newBlueprints = this.state.newBlueprints.filter(b => b !== id);
    this.game.sfx('select');
    this.render();
  }

  // UI ---------------------------------------------------------------------------------------
  render() {
    if (!this.active) return;
    const root = $('build-ui'); root.innerHTML = '';
    const k = a => el('kbd', {}, keyLabel(this.game.input.bindings[a][0]));
    const zone = this.currentZone;
    const top = el('div', { class: 'b-top' },
      el('span', {}, '✨ Starforge Build Mode'),
      el('button', { class: 'small', onclick: () => this.cycleZone(-1), title: 'Previous building area ([)' }, '◀'),
      el('span', { class: 'zone' }, zone ? zone.name : 'No area'),
      el('button', { class: 'small', onclick: () => this.cycleZone(1), title: 'Next building area (])' }, '▶'),
      el('button', { class: 'small', onclick: () => this.undo(), title: 'Undo (Ctrl+Z)', disabled: !this.history.canUndo() }, '↶ Undo'),
      el('button', { class: 'small', onclick: () => this.redo(), title: 'Redo (Ctrl+Y)', disabled: !this.history.canRedo() }, '↷ Redo'),
      el('button', { class: 'small', onclick: () => { this.half = !this.half; this.render(); } }, this.half ? '½ grid: on' : '½ grid: off'),
      el('button', { class: 'small primary', onclick: () => this.close() }, 'Done'));
    root.append(top);
    root.append(el('div', { class: 'b-status', id: 'b-status' }, this.statusText()));
    root.append(el('div', { class: 'b-help' },
      el('div', {}, 'Left click — place / select'), el('div', {}, 'Right click — cancel · right-drag — turn view'),
      el('div', {}, k('rotate'), ' rotate  ', k('recolor'), ' colour  ', el('kbd', {}, 'M'), ' move'),
      el('div', {}, k('remove'), ' remove  ', el('kbd', {}, 'Ctrl Z'), ' undo  ', el('kbd', {}, 'Ctrl Y'), ' redo'),
      el('div', {}, k('forward'), k('left'), k('back'), k('right'), ' pan  ', 'wheel zoom  ', k('halfGrid'), ' half-grid'),
      el('div', {}, k('pause'), ' / ', k('build'), ' leave build mode')));
    const goals = this.game.buildGoals(zone);
    if (goals && !this.selected && !this.moving) {
      root.append(el('div', { class: 'b-goal' }, el('h4', {}, `📜 ${goals.title}`), goals.hint ? el('div', { style: { marginBottom: '4px' } }, goals.hint) : null,
        el('ul', {}, goals.items.map(it => el('li', { class: it.ok ? 'ok' : '' }, `${it.ok ? '✔' : '○'} ${it.label}`)))));
    }
    if (this.selected || this.moving) {
      const pl = this.moving ? this.moving.pl : this.state.placements.find(p => p.uid === this.selected);
      if (pl) {
        const def = PIECE[pl.id];
        const sel = el('div', { class: 'b-sel' }, el('h4', {}, `${def.icon} ${def.name}`), el('div', { style: { fontSize: '12px', color: '#8a6a50', marginBottom: '6px' } }, def.desc));
        if (!this.moving) {
          sel.append(el('div', { class: 'row' },
            el('button', { class: 'small', onclick: () => this.startMove(pl.uid) }, '✋ Move'),
            el('button', { class: 'small', onclick: () => this.rotate() }, '⟳ Rotate'),
            el('button', { class: 'small', onclick: () => this.removeTarget() }, '🗑 Remove')));
          if (def.colorable) sel.append(el('div', { class: 'swatches', style: { marginTop: '8px' } }, COLOR_PALETTE.map(c => el('span', { class: `sw ${(pl.color || def.color) === c ? 'on' : ''}`, style: { background: c }, onclick: () => this.setColor(c) }))));
          if (def.mech?.switch) sel.append(el('button', { class: 'small', style: { marginTop: '8px' }, onclick: () => this.game.toggleLever(pl.uid) }, pl.state?.on ? 'Switch off' : 'Switch on'));
          sel.append(el('div', { style: { fontSize: '12px', marginTop: '6px', color: '#8a6a50' } }, `Removing refunds ${costText(def.cost)}`));
        } else sel.append(el('div', {}, 'Click to put it down · R rotate · right click to cancel'));
        root.append(sel);
      }
    }
    const cat = el('div', { class: 'b-cat' });
    cat.append(el('div', { class: 'tabs' }, CATEGORIES.map(c => el('button', { class: `small ${this.category === c.id ? 'on' : ''}`, onclick: () => { this.category = c.id; this.render(); } }, `${c.icon} ${c.name}`)),
      el('span', { class: 'spacer' }),
      this.itemId && PIECE[this.itemId].colorable ? el('span', { class: 'swatches' }, COLOR_PALETTE.map(c => el('span', { class: `sw ${(this.color || PIECE[this.itemId].color) === c ? 'on' : ''}`, style: { background: c, width: '20px', height: '20px' }, onclick: () => this.setColor(c) }))) : null));
    const items = el('div', { class: 'b-items' });
    for (const p of PIECES.filter(p => p.cat === this.category)) {
      const unlocked = this.state.blueprints.includes(p.id);
      const poor = unlocked && !canAfford(this.state.inventory, p.cost);
      items.append(el('div', { class: `b-item ${this.itemId === p.id ? 'on' : ''} ${unlocked ? '' : 'locked'} ${poor ? 'poor' : ''}`, title: unlocked ? `${p.name}: ${p.desc}` : `Locked: ${this.game.blueprintHint(p.id)}`, 'data-piece': p.id, onclick: () => this.selectItem(p.id) },
        unlocked ? null : el('span', { class: 'lock' }, '🔒'),
        this.state.newBlueprints.includes(p.id) ? el('span', { class: 'new' }, 'new') : null,
        el('div', { class: 'ico' }, p.icon), el('div', {}, p.name), el('div', { class: 'cost' }, unlocked ? costText(p.cost) : 'locked')));
    }
    cat.append(items);
    root.append(cat);
    for (const n of root.querySelectorAll('.b-top, .b-cat, .b-sel')) {
      n.addEventListener('pointerenter', () => { this.game.input.mouse.overUI = true; });
      n.addEventListener('pointerleave', () => { this.game.input.mouse.overUI = false; });
    }
    this.game.input.mouse.overUI = false;
  }
  statusText() {
    if (this.moving) return this.check ? (this.check.ok ? 'Click to put it here' : this.check.reason) : 'Carrying a piece — point where it should go';
    if (!this.itemId) return this.selected ? 'Piece selected' : 'Pick a piece from the catalog, or click a placed piece to edit it';
    const def = PIECE[this.itemId];
    if (!this.check) return `${def.name} — point at the glowing grid`;
    return this.check.ok ? `Click to place ${def.name} (${costText(def.cost)})` : this.check.reason;
  }
  renderStatus() {
    const s = document.getElementById('b-status'); if (!s) return;
    s.textContent = this.statusText();
    s.classList.toggle('bad', !!this.check && !this.check.ok);
  }
}
function zdist(z, p) { return Math.hypot((z.minI + z.maxI) / 2 - p.x, (z.minK + z.maxK) / 2 - p.z); }
