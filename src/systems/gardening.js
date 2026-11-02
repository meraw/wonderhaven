// Garden beds: plant a seed, water it, and it grows one stage each time it has had water for a while.
export const GROW_MINUTES = 90;   // game minutes per stage while watered
export const STAGES = ['seed', 'sprout', 'bud', 'bloom'];
export const GARDEN_PLOTS = [
  { id: 'bed0', x: 4.4, z: -9.4 }, { id: 'bed1', x: 6.6, z: -9.4 }, { id: 'bed2', x: 4.4, z: -11 }, { id: 'bed3', x: 6.6, z: -11 },
];
export function plotState(gardens, id) { return gardens[id] || { stage: -1 }; }
export function plant(gardens, id, now) {
  const p = plotState(gardens, id); if (p.stage >= 0) return false;
  gardens[id] = { stage: 0, watered: false, wateredAt: now }; return true;
}
export function water(gardens, id, now) {
  const p = gardens[id]; if (!p || p.stage < 0 || p.stage >= 3 || p.watered) return false;
  p.watered = true; p.wateredAt = now; return true;
}
// Advance growth; returns true if anything changed.
export function grow(gardens, now) {
  let changed = false;
  for (const p of Object.values(gardens)) {
    if (p.stage >= 0 && p.stage < 3 && p.watered && now - p.wateredAt >= GROW_MINUTES) { p.stage++; p.watered = p.stage >= 3; changed = true; }
  }
  return changed;
}
export function harvest(gardens, id) {
  const p = gardens[id]; if (!p || p.stage < 3) return null;
  delete gardens[id];
  return { flowers: 3, seeds: 1, spark: 2 };
}
export function plotAction(gardens, id, inv) {
  const p = plotState(gardens, id);
  if (p.stage < 0) return (inv.seeds || 0) > 0 ? 'plant' : 'needSeeds';
  if (p.stage >= 3) return 'harvest';
  return p.watered ? 'growing' : 'water';
}
