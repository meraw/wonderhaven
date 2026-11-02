// Hearthglow Village: where everything stands. Plain data; the world builder, physics,
// NPC navigation and quests all read it. Cells are 1x1 world units: cell (i, k) spans x i..i+1, z k..k+1.
import { riverCenter } from '../systems/heightfield.js';

export const SPAWN = { x: -40, z: 5, yaw: Math.PI / 2 };   // yaw: facing +x (east, towards the village)
export const SQUARE = { x: 0, z: 2, r: 7 };
export const FOUNTAIN = { x: 0, z: 2, r: 1.7, inlet: { cell: [2, 2], side: 'W' } };

// Buildings. w along x, d along z. door: side of the footprint ('N' = -z, 'S' = +z, 'E' = +x, 'W' = -x).
export const BUILDINGS = [
  { id: 'workshop', kind: 'workshop', name: "Bram's Workshop", x: -13, z: 10, w: 9, d: 7, wall: '#f3dfc1', roof: '#d9734e', door: 'E', doorAt: 10, doorWidth: 2 },
  { id: 'bakery', kind: 'shop', name: 'Crumb & Co. Bakery', x: -11, z: -6.5, w: 6, d: 5, wall: '#ffe4ec', roof: '#e98aa8', door: 'S', awning: '#ff9fb8' },
  { id: 'fernHouse', kind: 'cottage', name: "Fern's Cottage", x: 10, z: -9, w: 5, d: 5, wall: '#e9f5d8', roof: '#6fae5c', door: 'S' },
  { id: 'odessaHouse', kind: 'cottage', name: "Odessa's House", x: -5, z: 17, w: 6, d: 5, wall: '#efe3ff', roof: '#8f78d6', door: 'N' },
  { id: 'playerHouse', kind: 'cottage', name: 'Your Cottage', x: 14, z: 13, w: 6, d: 6, wall: '#fff3d6', roof: '#5f9be0', door: 'S' },
  { id: 'caravan', kind: 'caravan', name: "Tilly's Caravan", x: 21, z: 5, w: 4, d: 2.6, wall: '#ffd36b', roof: '#5ab8b0', door: 'W' },
  { id: 'percivalHouse', kind: 'cottage', name: 'Gatehouse', x: -20, z: -10, w: 5, d: 4, wall: '#f5ead2', roof: '#c25b6a', door: 'E' },
  { id: 'captainHut', kind: 'hut', name: "Captain's Hut", x: 13, z: 38, w: 4, d: 4, wall: '#d6eef7', roof: '#3f7fb5', door: 'W' },
  { id: 'castle', kind: 'castle', name: 'Hearthglow Castle', x: 31, z: -5, w: 11, d: 9, wall: '#f4ecdf', roof: '#5f7fd8', door: 'W' },
];

// Interior of the workshop, where furniture can be placed (cells).
export const WORKSHOP_INTERIOR = { minI: -17, maxI: -10, minK: 7, maxK: 12 };

// Cliffs that wall off the harbor until its gate opens.
export const HARBOR_GATE = { minX: 2.5, maxX: 7.5, minZ: 34, maxZ: 35.4, flag: 'harborOpen' };
export const HARBOR_CLIFFS = [
  { minX: -70, maxX: 2.5, minZ: 34, maxZ: 35.6 },
  { minX: 7.5, maxX: 70, minZ: 34, maxZ: 35.6 },
];

// Build zones (cells, inclusive). `unlock` names what opens them; `spanY` lets bridge decks float at that height.
export const ZONES = [
  { id: 'plot', name: 'Your garden plot', minI: 18, maxI: 25, minK: 9, maxK: 16, unlock: { flag: 'hasTool' },
    expanded: { minI: 18, maxI: 29, minK: 6, maxK: 19, harmony: 60 } },
  { id: 'bridge', name: 'Orchard Bridge site', minI: -3, maxI: 2, minK: -22, maxK: -15, spanY: 0, unlock: { quest: 'bridge' },
    endpoints: { a: { minI: -3, maxI: 2, minK: -15, maxK: -15 }, b: { minI: -3, maxI: 2, minK: -22, maxK: -22 } },
    blueprint: [[0, -15, 'bridgeDeck'], [0, -16, 'bridgeDeck'], [0, -17, 'bridgeDeck'], [0, -18, 'bridgePost'], [0, -18, 'bridgeDeck'],
      [0, -19, 'bridgeDeck'], [0, -20, 'bridgeDeck'], [0, -21, 'bridgeDeck'], [0, -22, 'bridgeDeck']] },
  { id: 'workshop', name: "Bram's Workshop", ...WORKSHOP_INTERIOR, interior: true, unlock: { quest: 'workshop' } },
  { id: 'plaza', name: 'Fountain plaza', minI: 2, maxI: 11, minK: -1, maxK: 5, unlock: { quest: 'fountain' },
    blueprint: [[9, 1, 'waterwheel', 0], [9, 2, 'gear'], [8, 2, 'pump', 3], [7, 2, 'pipe', 1], [6, 2, 'pipe', 1], [5, 2, 'pipe', 1], [4, 2, 'pipe', 1], [3, 2, 'pipe', 1], [2, 2, 'pipe', 1]] },
  { id: 'dock', name: 'Harbor dock', minI: 4, maxI: 6, minK: 40, maxK: 49, spanY: 0, unlock: { flag: 'harborOpen' },
    fixedSupports: [[5, 44], [5, 47]],
    endpoints: { a: { minI: 4, maxI: 6, minK: 40, maxK: 40 }, b: { minI: 4, maxI: 6, minK: 49, maxK: 49 } },
    blueprint: [[5, 41, 'bridgeDeck'], [5, 42, 'bridgeDeck'], [5, 43, 'bridgeDeck'], [5, 44, 'bridgeDeck'], [5, 45, 'bridgeDeck'], [5, 46, 'bridgeDeck'], [5, 47, 'bridgeDeck'], [5, 48, 'bridgeDeck'], [5, 49, 'bridgeDeck']] },
  { id: 'orchardPlot', name: 'Orchard garden', minI: 4, maxI: 11, minK: -35, maxK: -28, unlock: { flag: 'orchardOpen' } },
];

const bank = (x, side = 1) => ({ x, z: riverCenter(x) + side * 3.9 });

// Resource nodes. kind decides the activity: chop / mine / clay / fish / flowers / shake / fruit / dig / chest / fragment.
export const NODES = [
  // Renewable trees for wood
  ...[[-24, 15], [-27.5, 19], [-21.5, 20.5], [-29, 13.5], [-25, 23.5], [-19.5, 16], [-35, 10.5], [-37, -1], [16, 25], [-14, 27]]
    .map(([x, z], n) => ({ id: `tree${n}`, kind: 'chop', x, z })),
  // Rocks in the old quarry
  ...[[-31, -9], [-28, -11.5], [-33.5, -5.5], [-27, -6.5], [-30, -2.5], [-35, -10]]
    .map(([x, z], n) => ({ id: `rock${n}`, kind: 'mine', x, z, rich: n === 5 })),
  // Clay along the south river bank
  ...[-14, -18, 16].map((x, n) => ({ id: `clay${n}`, kind: 'clay', ...bank(x) })),
  // Fishing spots (stand here, face the water)
  { id: 'fish0', kind: 'fish', ...bank(-8), facing: Math.PI },
  { id: 'fish1', kind: 'fish', ...bank(11), facing: Math.PI },
  { id: 'fish2', kind: 'fish', x: -7, z: 41.2, facing: 0, flag: 'harborOpen' },
  // Wild flowers
  ...[[-20, -2], [18, -12], [-9, 25], [22, 21], [-38, 14], [3, -38], [-4, -31]]
    .map(([x, z], n) => ({ id: `flowers${n}`, kind: 'flowers', x, z })),
  // Oak by the bakery: shake for acorns
  { id: 'oak0', kind: 'shake', x: -16.5, z: -1.5 },
  // Orchard fruit trees (bear fruit once the orchard is reached)
  ...[[-6, -28], [-2, -28], [2, -28], [-6, -32], [-2, -32], [2, -32], [-6, -36], [-2, -36]]
    .map(([x, z], n) => ({ id: `fruit${n}`, kind: 'fruit', x, z })),
  // Hidden dig spots (the Starforge Tool hums when you are close)
  ...[[-18, 25.5], [25, 19.5], [-41, -12], [6, -37.5], [33, 9]]
    .map(([x, z], n) => ({ id: `dig${n}`, kind: 'dig', x, z })),
  // Treasure chests
  { id: 'chest0', kind: 'chest', x: 38.5, z: -11, loot: { crystal: 2, spark: 12 }, blueprint: 'statue' },
  { id: 'chest1', kind: 'chest', x: -36.5, z: -14.5, loot: { metal: 3, spark: 10 }, blueprint: 'windmill' },
  { id: 'chest2', kind: 'chest', x: 9.5, z: -41, loot: { fabric: 3, spark: 10 }, outfit: 'flowerCrown' },
  // Floating magic fragments
  ...[[-35.5, 6], [-2, 24.5], [18, -5.5], [-22, -13], [35, 3], [0, -43], [-12, 31], [27, 25], [-44, 9], [11, 6.5]]
    .map(([x, z], n) => ({ id: `frag${n}`, kind: 'fragment', x, z })),
];

// Other interactables that are not resources.
export const FEATURES = [
  { id: 'wardrobe', kind: 'wardrobe', x: 11.4, z: 17, label: 'Change outfit' },
  { id: 'bed', kind: 'rest', x: 16.4, z: 16.6, label: 'Rest until morning' },
  { id: 'welcomeSign', kind: 'sign', x: -33, z: 7.5, text: 'Welcome to Hearthglow Village! Population: cozy.' },
  { id: 'bridgeSign', kind: 'sign', x: 2.5, z: -13, text: 'Orchard Bridge — closed for repairs (since forever).' },
  { id: 'harborSign', kind: 'sign', x: 9, z: 32.5, text: 'Hearthglow Harbor. Gate sealed by Royal Decree No. 47.' },
  { id: 'boat', kind: 'boat', x: 5.5, z: 51.6, label: 'Board the ferry', flag: 'boatReady' },
  { id: 'noticeBoard', kind: 'board', x: 4.5, z: 7.5, label: 'Read the notice board' },
];

// NPC navigation graph. Edges with a flag are only walkable once that flag is set.
export const NAV_NODES = {
  spawn: [-40, 5], westGate: [-31, 4.5], westRoad: [-20, 3], workshopDoor: [-6.6, 10], workshopInside: [-12, 10],
  squareW: [-4.5, 2], squareN: [0, -3], squareE: [4.5, 2], squareS: [0, 6.8], bakeryDoor: [-11, -2.6],
  fernDoor: [10, -5.6], fernGarden: [5.5, -10], bridgeS: [0, -13], bridgeN: [0, -23.5], orchard: [0, -30], orchard2: [-4, -34],
  odessaDoor: [-5, 13.4], southRoad: [3, 19.2], cottageDoor: [14, 17], eastRoad: [11.5, -1.5], caravan: [18.2, 5.4],
  castleSteps: [23.5, -5], harborGate: [5, 32], harborIn: [5, 37.5], harborHut: [10, 38.5], dockStart: [5.4, 41.2],
  quarry: [-26, -4], grove: [-22.5, 11.5], gatehouse: [-16.8, -10],
};
export const NAV_EDGES = [
  ['spawn', 'westGate'], ['westGate', 'westRoad'], ['westRoad', 'squareW'], ['squareW', 'workshopDoor'], ['workshopDoor', 'workshopInside'],
  ['squareW', 'squareN'], ['squareN', 'squareE'], ['squareE', 'squareS'], ['squareS', 'squareW'], ['squareW', 'bakeryDoor'],
  ['squareN', 'bridgeS'], ['bridgeS', 'fernGarden'], ['fernGarden', 'fernDoor'], ['fernDoor', 'eastRoad'], ['eastRoad', 'squareE'],
  ['eastRoad', 'caravan'], ['caravan', 'castleSteps'], ['squareS', 'odessaDoor'], ['squareS', 'southRoad'], ['southRoad', 'cottageDoor'],
  ['southRoad', 'harborGate'], ['westRoad', 'quarry'], ['westRoad', 'grove'], ['bakeryDoor', 'gatehouse'], ['quarry', 'gatehouse'],
  ['bridgeS', 'bridgeN', 'orchardOpen'], ['bridgeN', 'orchard', 'orchardOpen'], ['orchard', 'orchard2', 'orchardOpen'],
  ['harborGate', 'harborIn', 'harborOpen'], ['harborIn', 'harborHut', 'harborOpen'], ['harborIn', 'dockStart', 'harborOpen'],
];

// Sandy paths drawn on the ground (polylines).
export const PATHS = [
  [[-46, 5], [-31, 4.5], [-20, 3], [-7, 2.5]],
  [[0, -5], [0, -14.6]],
  [[0, -23], [0, -38]],
  [[6.5, 1], [11.5, -1.5], [18, 4.5], [23.5, -5]],
  [[0, 9], [3, 19.2], [5, 33], [5, 41.5]],
  [[3, 19.2], [14, 17]],
  [[-4.5, 4], [-6.6, 10]],
  [[-3, -3], [-11, -2.6]],
  [[1.5, -12], [5.5, -10], [10, -5.6], [11.5, -1.5]],
  [[-20, 3], [-26, -4]],
  [[-4, 7.5], [-5, 13.4]],
];
