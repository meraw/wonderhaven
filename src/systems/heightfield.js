// The island's ground shape. Pure functions shared by the terrain mesh, player physics,
// building placement and quest validation, so what you see is what you can walk on.
import { smoothstep, lerp } from '../core/math.js';

export const WATER_Y = -0.4;        // sea / river surface
export const WALKABLE_MIN = -0.3;   // ground lower than this is water: you cannot wade in
export const RIVER_HALF = 3;        // river bed half width (cells at |dz| < 3 are water)
export const RIVER_BANK = 0.4;      // steep bank width
export const SPRING = { x: 14, z: 1, r: 2.2 };
export const CHANNEL = { minX: 8, maxX: 12, minZ: 1, maxZ: 2 };
export const CASTLE_MOUND = { x: 30, z: -5, r: 9, h: 0.9 };

export function riverCenter(x) {
  const w = smoothstep(6, 16, Math.abs(x));
  return -18 + w * 2.6 * Math.sin(x * 0.07 + 0.6);
}
function islandRadius(a) { return 54 + 3 * Math.sin(3 * a + 1) + 2 * Math.cos(5 * a); }

export function terrainHeight(x, z) {
  const r = Math.hypot(x, z), a = Math.atan2(z, x);
  // Gentle rolling hills only in the outer ring, keeping the village core flat for building.
  const ring = smoothstep(32, 42, r) * (1 - smoothstep(46, 50, r));
  let h = ring * (0.9 + 0.7 * Math.sin(x * 0.13 + 1.3) * Math.cos(z * 0.11 - 0.4));
  // Castle mound
  const dc = Math.hypot(x - CASTLE_MOUND.x, z - CASTLE_MOUND.z);
  h += CASTLE_MOUND.h * (1 - smoothstep(CASTLE_MOUND.r - 3, CASTLE_MOUND.r, dc));
  // Beaches into the sea
  const edge = islandRadius(a) - r;
  h = lerp(-2.4, h, smoothstep(-2, 7, edge));
  // The southern harbor cove: the shore sits at about z = 42.
  const m = 1 - smoothstep(20, 28, Math.abs(x - 4));
  if (z > 34 && m > 0) {
    const hh = 0.25 - Math.max(0, z - 40) * 0.3;
    if (hh < h) h = lerp(h, Math.max(hh, -2.4), m);
  }
  // River with steep banks, crossing the whole island from east to west.
  const dz = Math.abs(z - riverCenter(x));
  if (dz < RIVER_HALF + RIVER_BANK) {
    const rh = dz < RIVER_HALF ? -1.4 : lerp(-1.4, h, (dz - RIVER_HALF) / RIVER_BANK);
    h = Math.min(h, rh);
  }
  // Sprite Spring pond and its stone mill channel.
  const ds = Math.hypot(x - SPRING.x, z - SPRING.z);
  if (ds < SPRING.r + 0.4) h = Math.min(h, ds < SPRING.r ? -0.8 : lerp(-0.8, h, (ds - SPRING.r) / 0.4));
  if (x >= CHANNEL.minX && x <= CHANNEL.maxX && z >= CHANNEL.minZ && z <= CHANNEL.maxZ) h = Math.min(h, -0.6);
  return h;
}

export const isWaterAt = (x, z) => terrainHeight(x, z) < WALKABLE_MIN;
// Flowing water a waterwheel can turn in, or a pump can draw from: river, spring, channel.
export function isStreamCell(i, k) {
  const x = i + 0.5, z = k + 0.5;
  if (x >= CHANNEL.minX && x <= CHANNEL.maxX && z >= CHANNEL.minZ && z <= CHANNEL.maxZ) return true;
  if (Math.hypot(x - SPRING.x, z - SPRING.z) < SPRING.r) return true;
  return Math.abs(z - riverCenter(x)) < RIVER_HALF && Math.hypot(x, z) < 50;
}
