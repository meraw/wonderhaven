// Resource inventory helpers. Inventories are plain objects { wood: 3, spark: 10, ... }.
export function count(inv, id) { return inv[id] || 0; }
export function canAfford(inv, cost = {}) { return Object.entries(cost).every(([k, n]) => (inv[k] || 0) >= n); }
export function missing(inv, cost = {}) {
  return Object.entries(cost).filter(([k, n]) => (inv[k] || 0) < n).map(([k, n]) => ({ id: k, need: n - (inv[k] || 0) }));
}
export function spend(inv, cost = {}) {
  if (!canAfford(inv, cost)) return false;
  for (const [k, n] of Object.entries(cost)) inv[k] = (inv[k] || 0) - n;
  return true;
}
export function add(inv, items = {}) {
  for (const [k, n] of Object.entries(items)) inv[k] = Math.max(0, (inv[k] || 0) + n);
  return inv;
}
