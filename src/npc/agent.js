// A villager in the world: follows their daily routine along the path graph, plays activity animations,
// turns to greet the player, and shows a quest marker when they have something for you.
import * as THREE from 'three';
import { createCharacter } from '../world/characters.js';
import { textSprite } from '../world/effects.js';
import { activityAt, findPath, nearestNode } from '../systems/schedule.js';
import { NAV_NODES } from '../data/village-layout.js';
import { angleDamp } from '../core/math.js';

export class NpcAgent {
  constructor(game, def) {
    this.game = game; this.def = def;
    this.character = createCharacter(def.appearance, { name: def.id });
    this.root = this.character.root;
    game.scene.add(this.root);
    const start = activityAt(def, game.state.time.minute, game.state.flags);
    const [x, z] = this.nodePos(start.node);
    this.pos = { x, z, y: game.walk.surfaceAt(x, z).y };
    this.yaw = Math.PI; this.goal = start.node; this.activity = start.activity; this.waypoints = [];
    this.body = { x, z, r: 0.32 };
    game.walk.dynamic.push(this.body);
    this.talking = false; this.greeted = false; this.idleT = Math.random() * 5;
    this.markers = { offer: textSprite('!', { color: '#fff', bg: '#ffb93b', border: '#fff3c4' }), ready: textSprite('★', { color: '#fff', bg: '#59c27a', border: '#d6ffe2' }) };
    for (const m of Object.values(this.markers)) { m.scale.set(0.7, 0.7, 1); m.visible = false; this.root.add(m); m.position.y = 2.15; }
    this.present = true;
    this.sync();
  }
  nodePos(node) {
    if (node === 'workshopInside') {
      const wb = this.game.state.placements.find(p => p.id === 'workbench' && p.i >= -17 && p.i <= -10 && p.k >= 7 && p.k <= 12);
      if (wb) { const zoff = wb.r === 2 ? -0.7 : 1.7; return [wb.i + 1, wb.k + (wb.r % 2 ? 1 : zoff)]; }
    }
    return NAV_NODES[node];
  }
  teleportHome() {
    const a = activityAt(this.def, this.game.state.time.minute, this.game.state.flags);
    const [x, z] = this.nodePos(a.node);
    this.pos.x = x; this.pos.z = z; this.waypoints = []; this.goal = a.node; this.activity = a.activity;
  }
  planRoute(goal) {
    const flags = this.game.state.flags;
    const from = nearestNode(this.pos.x, this.pos.z, flags);
    const path = findPath(from, goal, flags);
    this.goal = goal;
    if (!path) { this.waypoints = [this.nodePos(goal)]; return; }
    const pts = [];
    for (let n = 0; n < path.length; n++) {
      const a = path[n], b = path[n + 1];
      pts.push(this.nodePos(a));
      // Use the bridge or dock the player actually built.
      const crossing = this.game.crossingPath?.(a, b);
      if (crossing) pts.push(...crossing);
    }
    if (Math.hypot(pts[0][0] - this.pos.x, pts[0][1] - this.pos.z) < 0.5) pts.shift();
    this.waypoints = pts;
  }
  update(dt) {
    const g = this.game, flags = g.state.flags;
    this.present = !this.def.present || !!flags[this.def.present];
    this.root.visible = this.present;
    this.body.r = this.present ? 0.32 : 0;
    if (!this.present) return;
    const act = activityAt(this.def, g.state.time.minute, flags);
    if (act.node !== this.goal) this.planRoute(act.node);
    this.activity = act.activity;
    let speed = 0;
    if (this.talking) { this.faceToward(g.player.pos, dt, 10); }
    else if (this.waypoints.length) {
      const [tx, tz] = this.waypoints[0];
      const dx = tx - this.pos.x, dz = tz - this.pos.z, d = Math.hypot(dx, dz);
      const far = Math.hypot(g.player.pos.x - this.pos.x, g.player.pos.z - this.pos.z) > 40;
      const v = far ? 6 : 2.3;
      if (d < 0.15) this.waypoints.shift();
      else {
        const step = Math.min(d, v * dt);
        const nx = this.pos.x + dx / d * step, nz = this.pos.z + dz / d * step;
        // Politely wait if the player is in the way.
        if (Math.hypot(nx - g.player.pos.x, nz - g.player.pos.z) > 0.62) { this.pos.x = nx; this.pos.z = nz; speed = v / 4.4; }
        this.yaw = angleDamp(this.yaw, Math.atan2(dx, dz), 8, dt);
      }
    } else {
      const pd = Math.hypot(g.player.pos.x - this.pos.x, g.player.pos.z - this.pos.z);
      if (pd < 3.2 && this.activity !== 'sleep') {
        this.faceToward(g.player.pos, dt, 5);
        if (!this.greeted && g.mode === 'explore') { this.greeted = true; this.character.play('wave'); g.audio?.voice(this.def.voice, 2); }
      } else if (pd > 6) this.greeted = false;
    }
    const s = g.walk.surfaceAt(this.pos.x, this.pos.z, this.pos.y + 0.3);
    this.pos.y = s.walkable ? s.y : this.pos.y;
    // Activity animation
    const ch = this.character;
    const hold = this.talking ? 'talk' : speed > 0 ? null : ({ garden: 'garden', work: 'work', read: 'read', talk: 'talk', sleep: 'sleep' })[this.activity] || null;
    if (hold) { if (ch.hold !== hold) ch.play(hold, true); } else if (ch.hold) ch.stopHold();
    if (!speed && this.activity === 'wave' && !this.talking) { this.idleT -= dt; if (this.idleT < 0) { ch.play('wave'); this.idleT = 3 + Math.random() * 3; } }
    if (this.activity === 'sleep' && !this.talking && Math.random() < dt * 0.8) g.effects.zzz(new THREE.Vector3(this.pos.x, this.pos.y + 1.4, this.pos.z));
    ch.update(dt, { speed });
    // Quest markers
    const st = g.story?.markerFor(this.def.id);
    this.markers.offer.visible = st === 'offer' && !this.talking;
    this.markers.ready.visible = st === 'ready' && !this.talking;
    const bob = Math.sin(g.time * 3) * 0.08;
    this.markers.offer.position.y = this.markers.ready.position.y = 2.15 + bob;
    this.sync();
  }
  faceToward(p, dt, rate) { this.yaw = angleDamp(this.yaw, Math.atan2(p.x - this.pos.x, p.z - this.pos.z), rate, dt); }
  sync() {
    this.body.x = this.pos.x; this.body.z = this.pos.z;
    this.root.position.set(this.pos.x, this.pos.y, this.pos.z);
    this.root.rotation.y = this.yaw;
  }
}
