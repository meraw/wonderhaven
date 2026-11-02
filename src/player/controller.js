// Third-person character controller: camera-relative movement, running, hopping, step-up and wall sliding.
import { stepMove, PLAYER_RADIUS } from '../systems/walk.js';
import { angleDamp } from '../core/math.js';

export class PlayerController {
  constructor(character, walk, start) {
    this.character = character;
    this.walk = walk;
    this.pos = { x: start.x, y: walk.surfaceAt(start.x, start.z).y, z: start.z };
    this.yaw = start.yaw ?? 0;
    this.vy = 0; this.grounded = true; this.speed = 0; this.moving = false;
    this.walkSpeed = 4.4; this.runSpeed = 7.2;
    this.body = { x: this.pos.x, z: this.pos.z, r: PLAYER_RADIUS };
    this.sync();
  }
  teleport(x, z, yaw) {
    this.pos.x = x; this.pos.z = z; this.pos.y = this.walk.surfaceAt(x, z).y; this.vy = 0;
    if (yaw !== undefined) this.yaw = yaw;
    this.sync();
  }
  update(dt, input, camYaw, enabled = true) {
    let mv = enabled ? input.moveVector() : { x: 0, y: 0 };
    const run = enabled && input.down('sprint');
    const target = (run ? this.runSpeed : this.walkSpeed) * Math.min(1, Math.hypot(mv.x, mv.y));
    this.speed += (target - this.speed) * Math.min(1, dt * 10);
    // camera forward on the ground plane: camera looks along (-sin yaw, -cos yaw)
    const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw), rx = -fz, rz = fx;
    let dx = (fx * mv.y + rx * mv.x), dz = (fz * mv.y + rz * mv.x);
    const len = Math.hypot(dx, dz);
    this.moving = len > 0.05;
    if (this.moving) { dx /= len; dz /= len; this.yaw = angleDamp(this.yaw, Math.atan2(dx, dz), 14, dt); }
    // Integrate in small substeps so fast movement never tunnels through thin walls.
    const total = this.speed * dt, steps = Math.max(1, Math.ceil(total / 0.12));
    let movedAny = false;
    for (let n = 0; n < steps && this.moving; n++) {
      const r = stepMove(this.walk, this.pos, dx * total / steps, dz * total / steps, PLAYER_RADIUS, this.body);
      if (r.moved) { movedAny = true; this.pos.x = r.x; this.pos.z = r.z; if (this.grounded && r.y <= this.pos.y + 0.46) { if (r.y > this.pos.y) this.pos.y = r.y; } }
    }
    if (this.moving && !movedAny) this.speed *= 0.5;
    // Vertical
    const ground = this.walk.surfaceAt(this.pos.x, this.pos.z, this.pos.y).y;
    if (enabled && this.grounded && input.pressed('jump')) { this.vy = 6.2; this.grounded = false; }
    if (!this.grounded || this.pos.y > ground + 0.02) {
      this.vy -= 22 * dt;
      this.pos.y += this.vy * dt;
      if (this.pos.y <= ground) { this.pos.y = ground; this.vy = 0; this.grounded = true; }
      else this.grounded = false;
    } else { this.pos.y = ground; this.grounded = true; }
    this.sync();
    this.character.update(dt, { speed: this.moving ? this.speed / this.walkSpeed : 0, airborne: !this.grounded });
  }
  sync() {
    this.body.x = this.pos.x; this.body.z = this.pos.z;
    const r = this.character.root;
    r.position.set(this.pos.x, this.pos.y, this.pos.z);
    r.rotation.y = this.yaw;
  }
  forward() { return { x: Math.sin(this.yaw), z: Math.cos(this.yaw) }; }
}
