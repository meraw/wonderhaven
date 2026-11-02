// Save/load: versioned JSON in localStorage (or any storage with getItem/setItem). Pure apart from the storage.
import { newGameState, SAVE_VERSION } from './state.js';
import { sanitizeAppearance } from '../data/appearance.js';
import { PIECE } from '../data/pieces.js';

export const SLOTS = ['slot1', 'slot2', 'slot3'];
export const AUTOSAVE = 'autosave';
const PREFIX = 'wonderhaven.';

export function serialize(state) { return JSON.stringify({ ...state, version: SAVE_VERSION, savedAt: Date.now() }); }
export function deserialize(text) {
  const raw = JSON.parse(text);
  if (!raw || typeof raw !== 'object') throw new Error('Not a Wonderhaven save');
  const base = newGameState();
  const s = { ...base, ...raw };
  for (const k of ['flags', 'quests', 'relationships', 'nodes', 'gardens', 'stats', 'inventory', 'time', 'player']) s[k] = { ...base[k], ...(raw[k] || {}) };
  for (const k of ['blueprints', 'newBlueprints', 'lockedClothesOwned', 'unlocksSeen']) s[k] = Array.isArray(raw[k]) ? raw[k].filter(x => typeof x === 'string') : base[k];
  s.appearance = sanitizeAppearance(raw.appearance);
  s.placements = (Array.isArray(raw.placements) ? raw.placements : []).filter(p => p && PIECE[p.id] && Number.isFinite(p.i) && Number.isFinite(p.k) && Number.isFinite(p.y))
    .map(p => ({ uid: p.uid, id: p.id, i: p.i, k: p.k, r: ((p.r | 0) % 4 + 4) % 4, y: p.y, ...(p.color ? { color: p.color } : {}), ...(p.state ? { state: p.state } : {}) }));
  s.nextUid = Math.max(raw.nextUid || 1, ...s.placements.map(p => p.uid + 1), 1);
  s.version = SAVE_VERSION;
  return s;
}
export function writeSave(storage, slot, state) { storage.setItem(PREFIX + slot, serialize(state)); }
export function readSave(storage, slot) { const t = storage.getItem(PREFIX + slot); return t ? deserialize(t) : null; }
export function deleteSave(storage, slot) { storage.removeItem(PREFIX + slot); }
export function saveMeta(storage, slot) {
  const t = storage.getItem(PREFIX + slot); if (!t) return null;
  try { const s = JSON.parse(t); return { slot, name: s.name, day: s.time?.day, harmony: s.harmony, savedAt: s.savedAt, quests: Object.values(s.quests || {}).filter(q => q.status === 'done').length }; }
  catch { return { slot, broken: true }; }
}
export function latestSlot(storage) {
  const metas = [AUTOSAVE, ...SLOTS].map(s => saveMeta(storage, s)).filter(m => m && !m.broken);
  metas.sort((a, b) => (b.savedAt || 0) - (a.savedAt || 0));
  return metas[0]?.slot || null;
}
export const SETTINGS_KEY = PREFIX + 'settings';
export const DEFAULT_SETTINGS = { music: 0.6, sfx: 0.8, sensitivity: 1, invertY: false, quality: 'high', bindings: null, weather: true };
export function loadSettings(storage) { try { return { ...DEFAULT_SETTINGS, ...JSON.parse(storage.getItem(SETTINGS_KEY) || '{}') }; } catch { return { ...DEFAULT_SETTINGS }; } }
export function storeSettings(storage, s) { storage.setItem(SETTINGS_KEY, JSON.stringify(s)); }
