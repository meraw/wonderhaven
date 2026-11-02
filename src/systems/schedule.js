// NPC daily routines and navigation over the village path graph. Pure.
import { NAV_NODES, NAV_EDGES } from '../data/village-layout.js';

export function scheduleFor(npc, flags) {
  for (const w of npc.when || []) {
    const neg = w.flag.startsWith('!'), f = neg ? w.flag.slice(1) : w.flag;
    if (neg ? !flags[f] : flags[f]) return w.schedule;
  }
  return npc.schedule;
}
export function activityAt(npc, minute, flags) {
  const h = minute / 60;
  for (const [from, to, node, activity] of scheduleFor(npc, flags)) if (h >= from && h < to) return { node, activity };
  return { node: npc.home, activity: 'sleep' };
}
// Dijkstra over the nav graph; edges with a flag are only open once it is set.
export function findPath(from, to, flags = {}) {
  if (from === to) return [to];
  const adj = new Map();
  for (const [a, b, f] of NAV_EDGES) {
    if (f && !flags[f]) continue;
    const d = Math.hypot(NAV_NODES[a][0] - NAV_NODES[b][0], NAV_NODES[a][1] - NAV_NODES[b][1]);
    if (!adj.has(a)) adj.set(a, []); if (!adj.has(b)) adj.set(b, []);
    adj.get(a).push([b, d]); adj.get(b).push([a, d]);
  }
  const dist = new Map([[from, 0]]), prev = new Map(), open = new Set([from]);
  while (open.size) {
    let cur = null; for (const n of open) if (cur === null || dist.get(n) < dist.get(cur)) cur = n;
    open.delete(cur);
    if (cur === to) break;
    for (const [n, d] of adj.get(cur) || []) {
      const nd = dist.get(cur) + d;
      if (nd < (dist.get(n) ?? Infinity)) { dist.set(n, nd); prev.set(n, cur); open.add(n); }
    }
  }
  if (!prev.has(to)) return null;
  const path = [to]; let c = to;
  while (prev.has(c)) { c = prev.get(c); path.unshift(c); }
  return path;
}
export function nearestNode(x, z, flags = {}) {
  let best = null, bd = Infinity;
  const reachable = new Set(NAV_EDGES.filter(e => !e[2] || flags[e[2]]).flatMap(e => [e[0], e[1]]));
  for (const [id, [nx, nz]] of Object.entries(NAV_NODES)) {
    if (!reachable.has(id)) continue;
    const d = Math.hypot(nx - x, nz - z); if (d < bd) { bd = d; best = id; }
  }
  return best;
}
