// Day/night clock and gentle weather. One real second is one game minute: a day lasts 24 real minutes.
export const MINUTES_PER_SECOND = 1;
export function advanceTime(t, dtSec) {
  const m = dtSec * MINUTES_PER_SECOND;
  t.total += m; t.minute += m;
  let newDay = false;
  while (t.minute >= 1440) { t.minute -= 1440; t.day += 1; newDay = true; }
  return newDay;
}
export const hourOf = t => Math.floor(t.minute / 60);
export const isNight = t => t.minute < 6 * 60 || t.minute >= 20 * 60 + 30;
// 0 at midnight, 1 at midday, smooth in between
export function daylight(t) {
  const h = t.minute / 60;
  if (h < 5 || h > 21.5) return 0;
  if (h < 8) return (h - 5) / 3;
  if (h > 18.5) return 1 - (h - 18.5) / 3;
  return 1;
}
export function clockText(t) {
  const h = Math.floor(t.minute / 60), m = Math.floor(t.minute % 60);
  const ap = h < 12 ? 'AM' : 'PM', h12 = ((h + 11) % 12) + 1;
  return `Day ${t.day} · ${h12}:${String(m).padStart(2, '0')} ${ap}`;
}
// Deterministic weather per half-day: mostly sunny, sometimes cloudy, occasionally a gentle rain.
export function weatherAt(t) {
  const slot = t.day * 2 + (t.minute >= 720 ? 1 : 0);
  if (slot < 3) return 'sunny';
  const x = Math.sin(slot * 12.9898) * 43758.5453, r = x - Math.floor(x);
  return r < 0.6 ? 'sunny' : r < 0.85 ? 'cloudy' : 'rain';
}
export function sleepUntilMorning(t) {
  if (t.minute >= 6 * 60) t.day += 1;
  const skipped = (t.minute >= 6 * 60 ? 1440 - t.minute + 7 * 60 : 7 * 60 - t.minute);
  t.total += skipped; t.minute = 7 * 60;
  return skipped;
}
