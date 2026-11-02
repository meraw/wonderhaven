// The whole saved game as one plain, serialisable object.
import { SPAWN } from '../data/village-layout.js';
import { STARTER_BLUEPRINTS } from '../data/pieces.js';
import { DEFAULT_APPEARANCE, sanitizeAppearance, LOCKED_CLOTHES } from '../data/appearance.js';

export const SAVE_VERSION = 1;
export const START_MINUTE = 8 * 60;

export function newGameState({ name = 'Apprentice', appearance = DEFAULT_APPEARANCE } = {}) {
  return {
    version: SAVE_VERSION,
    name: String(name).slice(0, 16) || 'Apprentice',
    appearance: sanitizeAppearance(appearance),
    created: Date.now(), playTime: 0,
    island: 'hearthglow',
    player: { x: SPAWN.x, z: SPAWN.z, yaw: SPAWN.yaw },
    inventory: { spark: 10 },
    harmony: 0,
    flags: {},
    quests: {},             // id -> { status: 'active' | 'done', progress: { objectiveId: n }, readyToTurnIn }
    tracked: null,
    placements: [], nextUid: 1,
    blueprints: [...STARTER_BLUEPRINTS], newBlueprints: [],
    lockedClothesOwned: [], // ids from LOCKED_CLOTHES the player has unlocked
    relationships: {},      // npcId -> { hearts, talkedDay, gifts: [] }
    nodes: {},              // nodeId -> { readyAt (game minutes) } | { done: true }
    gardens: {},            // plotId -> { stage, watered, plantedAt }
    time: { day: 1, minute: START_MINUTE, total: 0 },
    weather: { kind: 'sunny', until: 0 },
    stats: { fish: 0, chopped: 0, mined: 0, dug: 0, chests: 0, fragments: 0, placed: 0, treasures: 0 },
    unlocksSeen: [],
  };
}
export function isClothingUnlocked(state, id) { return !(id in LOCKED_CLOTHES) || state.lockedClothesOwned.includes(id); }
