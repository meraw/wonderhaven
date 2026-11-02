// Quest construction checks. They look at what the player built, not at one exact layout.
import { PIECE } from '../data/pieces.js';
import { zoneContainsCell, cells } from './build-grid.js';
import { STEP_UP } from './walk.js';

// Is there a continuous walkable path, at least one player wide, from endpoint a to endpoint b of the zone?
export function pathAcross(zone, walk) {
  const inZone = (i, k) => i >= zone.minI && i <= zone.maxI && k >= zone.minK && k <= zone.maxK;
  const inRect = (r, i, k) => i >= r.minI && i <= r.maxI && k >= r.minK && k <= r.maxK;
  const stand = new Map();
  const standAt = (i, k, fromY) => {
    const s = walk.surfaceAt(i + 0.5, k + 0.5, fromY);
    if (!s.walkable || s.y - fromY > STEP_UP + 1e-6 || walk.blocked(i + 0.5, k + 0.5, s.y, 0.28)) return null;
    return s.y;
  };
  const queue = [];
  for (let i = zone.endpoints.a.minI; i <= zone.endpoints.a.maxI; i++) for (let k = zone.endpoints.a.minK; k <= zone.endpoints.a.maxK; k++) {
    const y = standAt(i, k, Infinity);
    if (y !== null) { stand.set(`${i},${k}`, y); queue.push([i, k]); }
  }
  const prev = new Map();
  while (queue.length) {
    const [i, k] = queue.shift();
    const y = stand.get(`${i},${k}`);
    if (inRect(zone.endpoints.b, i, k)) {
      const path = [[i, k]]; let key = `${i},${k}`;
      while (prev.has(key)) { key = prev.get(key); path.unshift(key.split(',').map(Number)); }
      return { ok: true, path };
    }
    for (const [di, dk] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const ni = i + di, nk = k + dk, key = `${ni},${nk}`;
      if (!inZone(ni, nk) || stand.has(key)) continue;
      const ny = standAt(ni, nk, y);
      if (ny === null || Math.abs(ny - y) > STEP_UP + 1e-6) continue;
      // The edge between the two cells must not be blocked by a railing or wall.
      const mx = (i + ni) / 2 + 0.5, mz = (k + nk) / 2 + 0.5;
      if (walk.blocked(mx, mz, Math.max(y, ny), 0.2)) continue;
      stand.set(key, ny); prev.set(key, `${i},${k}`); queue.push([ni, nk]);
    }
  }
  return { ok: false, reached: stand.size };
}

export function piecesInZone(zone, placements) {
  return placements.filter(p => cells(p).every(([i, k]) => zoneContainsCell(zone, i, k, Infinity)));
}
// requirement: { any: ['cabinet','bookshelf'], count: 1, label }
export function roomChecklist(zone, placements, requirements) {
  const inside = piecesInZone(zone, placements);
  return requirements.map(req => {
    let n;
    if (req.recolored) n = inside.filter(p => p.color && p.color !== PIECE[p.id].color).length;
    else n = inside.filter(p => req.any.includes(p.id)).length;
    return { ...req, have: n, ok: n >= (req.count || 1) };
  });
}
