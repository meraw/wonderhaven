// Simple, honest machine simulation: power flows from waterwheels and windmills through shafts, gears
// and switched-on levers; powered pumps beside water push it through connected pipes to fountains.
import { PIECE } from '../data/pieces.js';
import { SIDES, SIDE_DIR, OPPOSITE, rotSide } from './build-grid.js';
import { isStreamCell } from './heightfield.js';

export function portsOf(pl) {
  const m = PIECE[pl.id].mech; if (!m) return {};
  const out = {};
  for (const [side, type] of Object.entries(m.ports)) out[rotSide(side, pl.r)] = type;
  return out;
}
// inlets: [{ id, cell: [i, k], side }] — fixed world targets such as the village fountain.
export function solveMechanics(placements, { inlets = [], isStream = isStreamCell } = {}) {
  const nodes = placements.filter(p => PIECE[p.id].mech && !(PIECE[p.id].mech.switch && !p.state?.on));
  const at = new Map();
  for (const n of nodes) { const key = `${n.i},${n.k}`; if (!at.has(key)) at.set(key, []); at.get(key).push(n); }
  const neighbours = (n, type) => {
    const out = [], ports = portsOf(n);
    for (const side of SIDES) {
      if (ports[side] !== type) continue;
      const [di, dk] = SIDE_DIR[side];
      for (const m of at.get(`${n.i + di},${n.k + dk}`) || []) {
        if (Math.abs(m.y - n.y) > 0.7) continue;
        if (portsOf(m)[OPPOSITE[side]] === type) out.push(m);
      }
    }
    return out;
  };
  const flood = (starts, type) => {
    const seen = new Set(starts.map(s => s.uid)), queue = [...starts];
    while (queue.length) for (const m of neighbours(queue.shift(), type)) if (!seen.has(m.uid)) { seen.add(m.uid); queue.push(m); }
    return seen;
  };
  const sources = nodes.filter(n => {
    const s = PIECE[n.id].mech.source;
    return s === 'wind' || (s === 'stream' && isStream(n.i, n.k));
  });
  const powered = flood(sources, 'power');
  const pumps = nodes.filter(n => PIECE[n.id].mech.pump && powered.has(n.uid) &&
    (isStream(n.i, n.k) || SIDES.some(s => isStream(n.i + SIDE_DIR[s][0], n.k + SIDE_DIR[s][1]))));
  const watered = flood(pumps, 'water');
  const fed = {};
  for (const inlet of inlets) {
    const [i, k] = inlet.cell;
    fed[inlet.id] = (at.get(`${i},${k}`) || []).some(n => watered.has(n.uid) && portsOf(n)[inlet.side] === 'water');
  }
  const lamps = nodes.filter(n => PIECE[n.id].mech.lamp && powered.has(n.uid)).map(n => n.uid);
  const fountains = nodes.filter(n => PIECE[n.id].mech.fountain && watered.has(n.uid)).map(n => n.uid);
  return { powered, watered, pumps: new Set(pumps.map(p => p.uid)), sources: new Set(sources.map(s => s.uid)), fed, lamps: new Set(lamps), fountains: new Set(fountains) };
}
