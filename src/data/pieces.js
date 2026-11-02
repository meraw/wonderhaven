// The Starforge building catalog. Sizes are in cells (w along x, d along z before rotation), heights in world units.
// box: local [u0, v0, u1, v1] footprint of the solid part (default: whole footprint). Edge pieces sit on the north edge.
// walkable: the top is a floor you can stand on and stack onto. span: may float at a zone's span height over water,
// if a support is within SPAN_LIMIT cells. post: stands on a river or sea bed. mech: ports per side before rotation.
export const SPAN_LIMIT = 2;
export const CATEGORIES = [
  { id: 'structure', name: 'Structure', icon: '🧱' },
  { id: 'furniture', name: 'Furniture', icon: '🪑' },
  { id: 'outdoor', name: 'Outdoor', icon: '🌳' },
  { id: 'mechanism', name: 'Mechanisms', icon: '⚙️' },
];
const EDGE = [0, 0, 1, 0.18];
export const PIECES = [
  // Structure
  { id: 'bridgeDeck', name: 'Bridge Plank', icon: '🟫', cat: 'structure', size: [1, 1], h: 0.15, walkable: true, span: true, cost: { wood: 1, spark: 1 }, color: '#c98a55', colorable: true, desc: 'A sturdy plank. Can reach out over water up to two planks from a support.' },
  { id: 'bridgePost', name: 'Bridge Post', icon: '🪵', cat: 'structure', size: [1, 1], h: 1.4, walkable: true, post: true, box: [0.2, 0.2, 0.8, 0.8], cost: { wood: 2, spark: 2 }, color: '#9a6238', desc: 'Stands on the river bed and holds up planks above the water.' },
  { id: 'railing', name: 'Railing', icon: '🚧', cat: 'structure', size: [1, 1], h: 0.7, box: EDGE, edge: true, cost: { wood: 1 }, color: '#f4e6d0', colorable: true, desc: 'Keeps visitors from tumbling off bridges.' },
  { id: 'floor', name: 'Wood Floor', icon: '🟨', cat: 'structure', size: [1, 1], h: 0.12, walkable: true, cost: { wood: 1 }, color: '#e0b07a', colorable: true, desc: 'A smooth floor tile.' },
  { id: 'stoneBlock', name: 'Stone Block', icon: '⬜', cat: 'structure', size: [1, 1], h: 1, walkable: true, cost: { stone: 2, spark: 1 }, color: '#cfc8bd', colorable: true, desc: 'Stack them to build upward.' },
  { id: 'foundation', name: 'Foundation', icon: '🔲', cat: 'structure', size: [2, 2], h: 0.3, walkable: true, cost: { stone: 3, spark: 1 }, color: '#bdb5a8', desc: 'A wide, flat stone base.' },
  { id: 'platform', name: 'Raised Platform', icon: '🟪', cat: 'structure', size: [2, 2], h: 1, walkable: true, cost: { wood: 4, spark: 2 }, color: '#d9a066', colorable: true, desc: 'A deck on legs. Pair with stairs.' },
  { id: 'stairs', name: 'Stairs', icon: '📶', cat: 'structure', size: [1, 1], h: 1, walkable: true, ramp: true, cost: { wood: 2, spark: 1 }, color: '#c98a55', colorable: true, desc: 'Climbs one level toward its back edge.' },
  { id: 'woodWall', name: 'Wall', icon: '🧱', cat: 'structure', size: [1, 1], h: 2.2, box: EDGE, edge: true, cost: { wood: 2 }, color: '#f3dfc1', colorable: true, desc: 'A wall along one edge of a tile.' },
  { id: 'windowWall', name: 'Window Wall', icon: '🪟', cat: 'structure', size: [1, 1], h: 2.2, box: EDGE, edge: true, cost: { wood: 2, crystal: 1 }, color: '#f3dfc1', colorable: true, desc: 'A wall with a sunny window.' },
  { id: 'doorWall', name: 'Door', icon: '🚪', cat: 'structure', size: [1, 1], h: 2.2, box: EDGE, edge: true, door: true, interact: 'door', cost: { wood: 3 }, color: '#a0623a', colorable: true, desc: 'Walk up and press E to open or close it.' },
  { id: 'roof', name: 'Roof', icon: '🔺', cat: 'structure', size: [2, 2], h: 1.2, cost: { wood: 3, clay: 1, spark: 1 }, color: '#e86f5c', colorable: true, needsSupport: true, desc: 'Rests on top of walls or pillars.' },
  { id: 'pillar', name: 'Pillar', icon: '🏛️', cat: 'structure', size: [1, 1], h: 2.2, box: [0.3, 0.3, 0.7, 0.7], walkable: true, cost: { stone: 2 }, color: '#f2ece2', colorable: true, desc: 'Holds up roofs and looks grand.' },
  { id: 'fence', name: 'Fence', icon: '🪜', cat: 'structure', size: [1, 1], h: 0.8, box: EDGE, edge: true, cost: { wood: 1 }, color: '#f4e6d0', colorable: true, desc: 'A picket fence along one edge.' },
  // Furniture
  { id: 'chair', name: 'Chair', icon: '🪑', cat: 'furniture', size: [1, 1], h: 0.9, box: [0.25, 0.25, 0.75, 0.75], interact: 'sit', cost: { wood: 1 }, color: '#e8a0b4', colorable: true, desc: 'Sit a while (E).' },
  { id: 'table', name: 'Table', icon: '🍽️', cat: 'furniture', size: [1, 1], h: 0.7, box: [0.1, 0.1, 0.9, 0.9], cost: { wood: 2 }, color: '#c98a55', colorable: true, desc: 'For tea, plans, and snacks.' },
  { id: 'sofa', name: 'Sofa', icon: '🛋️', cat: 'furniture', size: [2, 1], h: 0.85, box: [0.05, 0.2, 1.95, 0.85], interact: 'sit', cost: { wood: 2, fabric: 2 }, color: '#8fbfff', colorable: true, desc: 'Extra fluffy.' },
  { id: 'bed', name: 'Bed', icon: '🛏️', cat: 'furniture', size: [1, 2], h: 0.75, box: [0.05, 0.05, 0.95, 1.95], interact: 'sleep', cost: { wood: 3, fabric: 2 }, color: '#ffb3c7', colorable: true, desc: 'Rest until morning (E).' },
  { id: 'cabinet', name: 'Cabinet', icon: '🗄️', cat: 'furniture', size: [1, 1], h: 1.2, box: [0.1, 0.2, 0.9, 0.8], shelf: true, cost: { wood: 2 }, color: '#d9a066', colorable: true, desc: 'Storage with little brass knobs.' },
  { id: 'bookshelf', name: 'Bookshelf', icon: '📚', cat: 'furniture', size: [1, 1], h: 1.8, box: [0.05, 0.1, 0.95, 0.6], shelf: true, cost: { wood: 3 }, color: '#a0623a', colorable: true, desc: 'Full of very important stories.' },
  { id: 'desk', name: 'Desk', icon: '🖋️', cat: 'furniture', size: [2, 1], h: 0.75, box: [0.05, 0.15, 1.95, 0.85], cost: { wood: 3 }, color: '#c98a55', colorable: true, desc: 'For drawing blueprints.' },
  { id: 'lamp', name: 'Lamp', icon: '🛋', cat: 'furniture', size: [1, 1], h: 1.3, box: [0.35, 0.35, 0.65, 0.65], light: true, cost: { wood: 1, crystal: 1 }, color: '#ffd166', colorable: true, desc: 'Glows warmly at night.' },
  { id: 'rug', name: 'Rug', icon: '🟥', cat: 'furniture', size: [2, 2], h: 0.04, walkable: true, solid: false, cost: { fabric: 2 }, color: '#ff8fab', colorable: true, desc: 'Soft underfoot. Furniture can sit on it.' },
  { id: 'counter', name: 'Counter', icon: '🧁', cat: 'furniture', size: [2, 1], h: 0.95, box: [0, 0.1, 2, 0.9], cost: { wood: 2, stone: 1 }, color: '#f2ece2', colorable: true, desc: 'A shop counter.' },
  { id: 'workbench', name: 'Workbench', icon: '🛠️', cat: 'furniture', size: [2, 1], h: 0.9, box: [0, 0.1, 2, 0.9], cost: { wood: 3, metal: 1 }, color: '#b5733f', colorable: true, desc: 'Where Starforge ideas take shape.' },
  { id: 'painting', name: 'Painting', icon: '🖼️', cat: 'furniture', size: [1, 1], h: 0.7, attach: 'wall', solid: false, cost: { fabric: 1, flowers: 1 }, color: '#ffd166', colorable: true, desc: 'Hangs on a wall.' },
  // Outdoor
  { id: 'tree', name: 'Young Tree', icon: '🌳', cat: 'outdoor', size: [1, 1], h: 2.6, box: [0.35, 0.35, 0.65, 0.65], cost: { wood: 1, spark: 2 }, color: '#5cb85c', colorable: true, desc: 'Grows instantly, thanks to magic.' },
  { id: 'flowerBed', name: 'Flower Bed', icon: '🌷', cat: 'outdoor', size: [1, 1], h: 0.35, box: [0.05, 0.05, 0.95, 0.95], cost: { flowers: 2, wood: 1 }, color: '#ff7aa8', colorable: true, desc: 'A riot of petals.' },
  { id: 'hedge', name: 'Hedge', icon: '🟩', cat: 'outdoor', size: [1, 1], h: 0.9, cost: { wood: 1, flowers: 1 }, color: '#5aa65a', colorable: true, desc: 'Neatly trimmed.' },
  { id: 'bench', name: 'Bench', icon: '🪵', cat: 'outdoor', size: [2, 1], h: 0.8, box: [0.05, 0.25, 1.95, 0.85], interact: 'sit', cost: { wood: 2 }, color: '#c98a55', colorable: true, desc: 'A place to watch the clouds.' },
  { id: 'statue', name: 'Statue', icon: '🗿', cat: 'outdoor', size: [1, 1], h: 2.0, box: [0.15, 0.15, 0.85, 0.85], cost: { stone: 4, spark: 2 }, color: '#e8e2d6', colorable: true, desc: 'A noble star-gazing apprentice.' },
  { id: 'signpost', name: 'Signpost', icon: '🪧', cat: 'outdoor', size: [1, 1], h: 1.4, box: [0.4, 0.4, 0.6, 0.6], cost: { wood: 1 }, color: '#c98a55', colorable: true, desc: 'Points the way.' },
  { id: 'streetlight', name: 'Streetlight', icon: '🏮', cat: 'outdoor', size: [1, 1], h: 2.5, box: [0.4, 0.4, 0.6, 0.6], light: true, cost: { metal: 1, crystal: 1 }, color: '#4a4a5a', desc: 'Lights the path at night.' },
  { id: 'gardenPath', name: 'Garden Path', icon: '🟤', cat: 'outdoor', size: [1, 1], h: 0.05, walkable: true, solid: false, cost: { stone: 1 }, color: '#e8cf9a', colorable: true, desc: 'Stepping stones.' },
  { id: 'pond', name: 'Little Pond', icon: '💧', cat: 'outdoor', size: [2, 2], h: 0.2, box: [0.1, 0.1, 1.9, 1.9], cost: { stone: 2, clay: 2, spark: 2 }, color: '#5fcde4', desc: 'Ducks approve.' },
  { id: 'miniFountain', name: 'Garden Fountain', icon: '⛲', cat: 'outdoor', size: [1, 1], h: 1.1, box: [0.1, 0.1, 0.9, 0.9], cost: { stone: 3, spark: 2 }, color: '#e8e2d6', mech: { ports: { N: 'water', E: 'water', S: 'water', W: 'water' }, fountain: true }, desc: 'Sprays when a pipe brings it water.' },
  // Mechanisms
  { id: 'waterwheel', name: 'Waterwheel', icon: '🎡', cat: 'mechanism', size: [1, 1], h: 1.3, placeOn: 'stream', cost: { wood: 4, spark: 3 }, color: '#b5733f', mech: { ports: { N: 'power', S: 'power' }, source: 'stream' }, desc: 'Place in flowing water. Its axle sends power out of both sides.' },
  { id: 'windmill', name: 'Windmill', icon: '🌬️', cat: 'mechanism', size: [1, 1], h: 2.6, box: [0.2, 0.2, 0.8, 0.8], cost: { wood: 4, fabric: 2, spark: 3 }, color: '#f3dfc1', mech: { ports: { S: 'power' }, source: 'wind' }, desc: 'Turns in the breeze; power comes out of its base.' },
  { id: 'gear', name: 'Gear Box', icon: '⚙️', cat: 'mechanism', size: [1, 1], h: 0.7, box: [0.15, 0.15, 0.85, 0.85], cost: { wood: 1, metal: 1 }, color: '#d9a066', mech: { ports: { N: 'power', E: 'power', S: 'power', W: 'power' } }, desc: 'Passes power in every direction.' },
  { id: 'shaft', name: 'Drive Shaft', icon: '➖', cat: 'mechanism', size: [1, 1], h: 0.45, box: [0.35, 0, 0.65, 1], cost: { wood: 1 }, color: '#a0623a', mech: { ports: { N: 'power', S: 'power' } }, desc: 'Carries power in a straight line.' },
  { id: 'lever', name: 'Lever', icon: '🕹️', cat: 'mechanism', size: [1, 1], h: 0.7, box: [0.25, 0.1, 0.75, 0.9], interact: 'lever', cost: { wood: 1, metal: 1 }, color: '#e85d75', mech: { ports: { N: 'power', S: 'power' }, switch: true }, desc: 'A power switch. Press E to flip it.' },
  { id: 'pump', name: 'Water Pump', icon: '🚰', cat: 'mechanism', size: [1, 1], h: 1.0, box: [0.1, 0.1, 0.9, 0.9], cost: { metal: 2, wood: 1, spark: 3 }, color: '#6c9bd1', mech: { ports: { E: 'power', W: 'water' }, pump: true }, desc: 'Next to water and powered, it pushes water out of its spout.' },
  { id: 'pipe', name: 'Pipe', icon: '🟦', cat: 'mechanism', size: [1, 1], h: 0.4, box: [0.3, 0, 0.7, 1], cost: { clay: 1, spark: 1 }, color: '#8a9fb5', mech: { ports: { N: 'water', S: 'water' } }, desc: 'Carries water in a straight line.' },
  { id: 'pipeCorner', name: 'Pipe Bend', icon: '↩️', cat: 'mechanism', size: [1, 1], h: 0.4, box: [0.3, 0, 1, 0.7], cost: { clay: 1, spark: 1 }, color: '#8a9fb5', mech: { ports: { N: 'water', E: 'water' } }, desc: 'Turns water around a corner.' },
  { id: 'pipeTee', name: 'Pipe Splitter', icon: '⊤', cat: 'mechanism', size: [1, 1], h: 0.4, box: [0, 0, 1, 0.7], cost: { clay: 2, spark: 1 }, color: '#8a9fb5', mech: { ports: { N: 'water', E: 'water', W: 'water' } }, desc: 'Splits water three ways.' },
  { id: 'poweredLamp', name: 'Spark Lamp', icon: '💡', cat: 'mechanism', size: [1, 1], h: 1.6, box: [0.3, 0.3, 0.7, 0.7], cost: { metal: 1, crystal: 1 }, color: '#4a4a5a', mech: { ports: { N: 'power', E: 'power', S: 'power', W: 'power' }, lamp: true }, desc: 'Shines whenever it has power.' },
];
export const PIECE = Object.fromEntries(PIECES.map(p => [p.id, p]));
export const STARTER_BLUEPRINTS = ['floor', 'stoneBlock', 'fence', 'chair', 'table', 'bench', 'signpost', 'gardenPath', 'hedge'];
export const COLOR_PALETTE = ['#ff8fab', '#ffd166', '#7bd389', '#6cc4ff', '#b59cff', '#ff9f5a', '#ffffff', '#e86f5c', '#c98a55', '#5cb85c', '#4a4a6a', '#3fb5a3'];
