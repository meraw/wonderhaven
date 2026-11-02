// Orbit follow camera: drag or right-stick to rotate, wheel/triggers to zoom, eases into build and dialogue views.
import * as THREE from 'three';
import { clamp, damp, angleDamp } from '../core/math.js';
import { terrainHeight } from '../systems/heightfield.js';

export class FollowCamera {
  constructor(camera) {
    this.camera = camera;
    this.yaw = Math.PI * 0.5 + Math.PI; this.pitch = 0.5; this.dist = 8.5;
    this.target = new THREE.Vector3(); this.focus = new THREE.Vector3();
    this.mode = 'explore';
    this.cur = { yaw: this.yaw, pitch: this.pitch, dist: this.dist };
    this.limits = { explore: [3.5, 16, 0.12, 1.25], build: [6, 30, 0.55, 1.35], dialogue: [2.5, 6, 0.1, 0.6] };
    this.shake = 0;
  }
  setMode(mode) {
    this.mode = mode;
    if (mode === 'build') { this.pitch = Math.max(this.pitch, 0.95); this.dist = Math.max(this.dist, 15); }
    if (mode === 'explore') { this.pitch = clamp(this.pitch, 0.25, 0.75); this.dist = clamp(this.dist, 5, 11); }
  }
  // Rotate the view to look at a speaker during dialogue.
  frameDialogue(playerPos, npcPos) {
    this.focus.set((playerPos.x + npcPos.x) / 2, (playerPos.y + npcPos.y) / 2 + 0.9, (playerPos.z + npcPos.z) / 2);
    const dx = npcPos.x - playerPos.x, dz = npcPos.z - playerPos.z;
    this.yaw = Math.atan2(dx, dz) + Math.PI / 2 + 0.6; this.pitch = 0.28; this.dist = 4.6;
  }
  handleInput(input, dt, allowDrag = true) {
    const m = input.mouse, sens = 0.0055 * input.sensitivity;
    if (allowDrag && m.dragging !== false) { this.yaw -= m.dx * sens; this.pitch += (input.invertY ? -1 : 1) * m.dy * sens; }
    if (input.down('camLeft')) this.yaw += 1.8 * dt;
    if (input.down('camRight')) this.yaw -= 1.8 * dt;
    if (input.pad.connected) { this.yaw -= input.pad.lookX * 2.4 * dt * input.sensitivity; this.pitch += (input.invertY ? -1 : 1) * input.pad.lookY * 1.6 * dt; this.dist += -input.pad.zoom * 8 * dt; }
    if (m.wheel) this.dist *= Math.pow(1.12, m.wheel);
    const [d0, d1, p0, p1] = this.limits[this.mode] || this.limits.explore;
    this.dist = clamp(this.dist, d0, d1); this.pitch = clamp(this.pitch, p0, p1);
  }
  update(dt, followPos) {
    if (this.mode !== 'dialogue' && this.mode !== 'build') this.focus.set(followPos.x, followPos.y + 1.0, followPos.z);
    this.target.x = damp(this.target.x, this.focus.x, 10, dt); this.target.y = damp(this.target.y, this.focus.y, 10, dt); this.target.z = damp(this.target.z, this.focus.z, 10, dt);
    this.cur.yaw = angleDamp(this.cur.yaw, this.yaw, 12, dt);
    this.cur.pitch = damp(this.cur.pitch, this.pitch, 8, dt);
    this.cur.dist = damp(this.cur.dist, this.dist, 8, dt);
    const { yaw, pitch, dist } = this.cur;
    const c = this.camera;
    c.position.set(this.target.x + Math.sin(yaw) * Math.cos(pitch) * dist, this.target.y + Math.sin(pitch) * dist, this.target.z + Math.cos(yaw) * Math.cos(pitch) * dist);
    const minY = terrainHeight(c.position.x, c.position.z) + 0.6;
    if (c.position.y < minY) c.position.y = minY;
    if (this.shake > 0) { this.shake -= dt; c.position.x += (Math.random() - 0.5) * this.shake * 0.3; c.position.y += (Math.random() - 0.5) * this.shake * 0.3; }
    c.lookAt(this.target);
  }
  // Ground-plane yaw used for camera-relative movement.
  moveYaw() { return this.cur.yaw; }
}
