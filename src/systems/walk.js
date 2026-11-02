// Walkable-surface model shared by player physics and construction validation.
// Ground comes from the heightfield; placed pieces add surfaces (decks, floors, stairs) and colliders (walls, furniture).
import { terrainHeight, WALKABLE_MIN } from './heightfield.js';

export const STEP_UP = 0.45;
export const PLAYER_RADIUS = 0.32;
export const PLAYER_HEIGHT = 1.3;

// Statics: { type:'circle', x, z, r } | { type:'box', minX, maxX, minZ, maxZ, flag? (removed when flag set) }
// Surfaces (from pieces): { minX, maxX, minZ, maxZ, bottom, top, walkable, solid, topAt?(x,z) }
export class WalkWorld {
  constructor({ heightAt = terrainHeight, statics = [], flags = () => false } = {}) {
    this.heightAt = heightAt;
    this.statics = statics;
    this.flags = flags;
    this.surfaces = [];
    this.dynamic = [];   // moving colliders such as NPCs: { x, z, r }
  }
  setSurfaces(list) { this.surfaces = list; }
  topOf(s, x, z) { return s.topAt ? s.topAt(x, z) : s.top; }
  // Highest walkable surface at (x, z) reachable from feet height `feetY`.
  surfaceAt(x, z, feetY = Infinity) {
    const g = this.heightAt(x, z);
    let y = g, walkable = g >= WALKABLE_MIN, piece = null;
    for (const s of this.surfaces) {
      if (!s.walkable || x < s.minX || x > s.maxX || z < s.minZ || z > s.maxZ) continue;
      const t = this.topOf(s, x, z);
      if (t <= feetY + STEP_UP + 1e-6 && (t > y || !walkable)) { y = t; walkable = true; piece = s; }
    }
    return { y, walkable, piece, ground: g };
  }
  staticActive(c) { return !(c.flag && this.flags(c.flag)); }
  // Is a body of radius r at (x, z) with feet at feetY blocked by something solid?
  blocked(x, z, feetY, r = PLAYER_RADIUS, ignore = null) {
    for (const c of this.statics) {
      if (!this.staticActive(c)) continue;
      if (c.type === 'circle') { if (Math.hypot(x - c.x, z - c.z) < c.r + r) return true; }
      else if (circleBox(x, z, r, c)) return true;
    }
    for (const s of this.surfaces) {
      if (!s.solid) continue;
      const top = s.topAt ? Math.max(s.top, this.topOf(s, x, z)) : s.top;
      if (s.walkable && top <= feetY + STEP_UP + 1e-6) continue;   // you can step onto it
      if (top <= feetY + 0.05 || s.bottom >= feetY + PLAYER_HEIGHT) continue; // below the feet / above the head
      if (circleBox(x, z, r * 0.9, s)) return true;
    }
    for (const d of this.dynamic) {
      if (d === ignore) continue;
      if (Math.hypot(x - d.x, z - d.z) < d.r + r * 0.8) return true;
    }
    return false;
  }
  // Returns the surface if a body can stand at (x, z) coming from feet height feetY, else null.
  canStand(x, z, feetY, r = PLAYER_RADIUS, ignore = null) {
    if (this.blocked(x, z, feetY, r, ignore)) return null;
    const s = this.surfaceAt(x, z, feetY);
    if (!s.walkable || s.y - feetY > STEP_UP + 1e-6) return null;
    return s;
  }
}

export function circleBox(x, z, r, b) {
  const cx = Math.max(b.minX, Math.min(x, b.maxX)), cz = Math.max(b.minZ, Math.min(z, b.maxZ));
  return (x - cx) ** 2 + (z - cz) ** 2 < r * r;
}

// One movement step with wall sliding. Returns the new { x, z, y (surface), moved }.
export function stepMove(world, pos, dx, dz, r = PLAYER_RADIUS, ignore = null) {
  const tries = [[dx, dz], [dx, 0], [0, dz]];
  for (const [mx, mz] of tries) {
    if (!mx && !mz) continue;
    const s = world.canStand(pos.x + mx, pos.z + mz, pos.y, r, ignore);
    if (s) return { x: pos.x + mx, z: pos.z + mz, y: s.y, moved: true };
  }
  const s = world.surfaceAt(pos.x, pos.z, pos.y);
  return { x: pos.x, z: pos.z, y: s.y, moved: false };
}
