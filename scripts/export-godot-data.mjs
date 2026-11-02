// Writes the game's content (layout, pieces, villagers, quests, unlocks, appearance options) as JSON
// for the Godot project, so both versions share one source of content.
import { writeFileSync, mkdirSync } from 'node:fs';
import * as layout from '../src/data/village-layout.js';
import { PIECES, CATEGORIES, STARTER_BLUEPRINTS, COLOR_PALETTE, SPAN_LIMIT } from '../src/data/pieces.js';
import { NPCS } from '../src/data/npcs.js';
import { QUESTS } from '../src/data/quests.js';
import { HARMONY_UNLOCKS } from '../src/data/harmony.js';
import { ISLANDS } from '../src/data/islands.js';
import { RESOURCES, RESOURCE_ORDER } from '../src/data/resources.js';
import * as appearance from '../src/data/appearance.js';

const out = 'godot/data';
mkdirSync(out, { recursive: true });
const write = (name, data) => writeFileSync(`${out}/${name}.json`, JSON.stringify(data, null, 1) + '\n');
write('layout', {
  spawn: layout.SPAWN, square: layout.SQUARE, fountain: layout.FOUNTAIN, buildings: layout.BUILDINGS, workshop_interior: layout.WORKSHOP_INTERIOR,
  harbor_gate: layout.HARBOR_GATE, harbor_cliffs: layout.HARBOR_CLIFFS, zones: layout.ZONES, nodes: layout.NODES, features: layout.FEATURES,
  nav_nodes: layout.NAV_NODES, nav_edges: layout.NAV_EDGES, paths: layout.PATHS,
});
write('pieces', { pieces: PIECES, categories: CATEGORIES, starter: STARTER_BLUEPRINTS, palette: COLOR_PALETTE, span_limit: SPAN_LIMIT });
write('npcs', { npcs: NPCS });
write('quests', { quests: QUESTS });
write('harmony', { unlocks: HARMONY_UNLOCKS });
write('islands', { islands: ISLANDS });
write('resources', { resources: RESOURCES, order: RESOURCE_ORDER });
const { DEFAULT_APPEARANCE, LOCKED_CLOTHES, LABELS, sanitizeAppearance, ...lists } = appearance;
write('appearance', { ...lists, default: DEFAULT_APPEARANCE, locked: LOCKED_CLOTHES, labels: LABELS });
console.log('Wrote Godot data to', out);
