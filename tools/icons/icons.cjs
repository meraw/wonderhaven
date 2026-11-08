// Wonderhaven's icons: one drawing per emoji the game uses, in a 64x64 box, rendered in the watercolour-and-pencil
// style (style E of the icon directions). render.cjs turns them into PNGs and build_font.py into the colour font
// godot/assets/fonts/WonderhavenIcons.ttf, which the UI fonts fall back to before the system emoji font
// (godot/scripts/ui/ui_theme.gd). An emoji with no drawing here still shows as the system's emoji.
//
// A drawing is a list of parts:
//   shapes ({t:'path'|'circle'|'ellipse'|'rect', ..., f: palette key}) are washed with colour and outlined in pencil;
//   {t:'line', d, w?, o?} is a pencil detail line; {t:'wire', d, c, w, dash?} a stroke in a colour;
//   {t:'hl', d} a white highlight. An icon's `g` is an SVG transform for the whole drawing.
// Keep shapes inside about 6..58 so the wash has room to bleed, and draw at least one shape per icon.

const P = {
  gold: '#f2b632', goldDk: '#d18a1c', wood: '#b8743f', woodLt: '#e9bb80', woodDk: '#8a532a', stone: '#aaa59a', stoneLt: '#cdc8bd',
  metal: '#9fadb9', metalDk: '#56616d', copper: '#cf6f37', nut: '#8a4a2b', nutLt: '#dcb68b', fish: '#6a9fc6', fishLt: '#bcd8ea',
  cap: '#9a582c', stem: '#f1e3c4', green: '#2f8a4a', leaf: '#6aa84f', leafDk: '#3f7a3a', white: '#fbf7ee', red: '#c8323a',
  pink: '#e88aa6', journal: '#3f6e5a', paper: '#f4ead2', paperDk: '#dfcca5', bag: '#a06c3c', bagDk: '#7b4e29', clay: '#c4683c',
  wool: '#c9567a', woolDk: '#9c3d5d', bread: '#d9a25b', breadDk: '#a8692e', cream: '#f6e7cf', pumpkin: '#e0782e', sky: '#8ec5e8',
  blue: '#3a6fb5', blueDk: '#264f86', navy: '#2c3e5a', sun: '#f6c343', sunDk: '#e39a2b', moon: '#efe2a8', cloud: '#e8edf2',
  cloudDk: '#b9c4cf', rain: '#5f97c9', snow: '#ffffff', grey: '#8d8a84', purple: '#8a6fb8', teal: '#4f9a95', ink: '#4a3a30',
  hole: '#fff8ec', plum: '#7c4f8a', glass: '#bfe0f0', rose: '#d65a6a',
};

// small helpers so drawings stay short
const C = (cx, cy, r, f) => ({ t: 'circle', cx, cy, r, f });
const E = (cx, cy, rx, ry, f) => ({ t: 'ellipse', cx, cy, rx, ry, f });
const R = (x, y, w, h, f, rx) => ({ t: 'rect', x, y, w, h, f, rx });
const S = (d, f, rule) => ({ t: 'path', d, f, rule });
const L = (d, w, o) => ({ t: 'line', d, w, o });
const W = (d, c, w, dash) => ({ t: 'wire', d, c, w, dash });
const H = (d) => ({ t: 'hl', d });
const star = (cx, cy, ro, ri, n = 5, rot = -90) => {
  let d = '';
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 ? ri : ro, a = (rot + i * 180 / n) * Math.PI / 180;
    d += (i ? 'L' : 'M') + (cx + r * Math.cos(a)).toFixed(1) + ' ' + (cy + r * Math.sin(a)).toFixed(1) + ' ';
  }
  return d + 'Z';
};
const cloudPath = (x, y, s = 1) => `M${x} ${y} c${-7 * s} 0 ${-10 * s} ${-8 * s} ${-4 * s} ${-12 * s} c${1 * s} ${-8 * s} ${10 * s} ${-11 * s} ${15 * s} ${-5 * s} c${3 * s} ${-7 * s} ${15 * s} ${-7 * s} ${17 * s} ${2 * s} c${8 * s} ${-1 * s} ${11 * s} ${10 * s} ${4 * s} ${15 * s} Z`;
const heartPath = 'M32 53 C20 44 9 36 9 24.5 C9 16.5 15 11 22.5 11 C26.8 11 30 13.4 32 17.2 C34 13.4 37.2 11 41.5 11 C49 11 55 16.5 55 24.5 C55 36 44 44 32 53 Z';

const ICONS = [
  // ---------------- resources (godot/data/resources.json) ----------------
  { e: '💰', name: 'Lire', parts: [C(41, 40, 15, 'goldDk'), C(27, 29, 19, 'gold'), L('M27 16.5 a12.5 12.5 0 1 0 0.01 0'),
    L('M31.5 21.5 c-4.5-2.5-9-0.5-8.5 4 v11 h10 M19.5 28.5 h9 M19.5 32.5 h9', 2.6), H('M16 22 a13 13 0 0 1 7-6 l1 2.4 a10.5 10.5 0 0 0 -5.6 4.8 z')] },
  { e: '🪵', name: 'Wood', parts: [S('M19 14 H50 V27 H19 a6.5 6.5 0 0 1 0 -13 Z', 'wood'), E(50, 20.5, 6, 6.5, 'woodLt'), L('M50 18 a2.6 2.6 0 1 0 0.01 0'),
    S('M11 31 H46 V45 H11 a7 7 0 0 1 0 -14 Z', 'wood'), E(46, 38, 6.5, 7, 'woodLt'), L('M46 35 a3 3 0 1 0 0.01 0'), L('M16 36 H33 M21 40.5 H37 M25 19 H40', 2)] },
  { e: '🪚', name: 'Oak beams', parts: [S('M8 26 L38 12 L50 18 L20 32 Z', 'wood'), S('M20 32 L50 18 V25 L20 39 Z', 'woodDk'), S('M8 26 L20 32 V39 L8 33 Z', 'woodLt'),
    S('M14 42 L44 28 L56 34 L26 48 Z', 'wood'), S('M26 48 L56 34 V41 L26 55 Z', 'woodDk'), S('M14 42 L26 48 V55 L14 49 Z', 'woodLt'),
    L('M17 27 L39 16.5 M23 43 L45 32.5', 1.4, .6), L('M11 31 l6 3 M17 47 l6 3', 1.2, .5)] },
  { e: '🧱', name: 'Cut stone', parts: [S('M12 26 L30 18 L46 25 L28 33 Z', 'stoneLt'), S('M12 26 L28 33 V46 L12 39 Z', 'stone'), S('M28 33 L46 25 V38 L28 46 Z', 'grey'),
    S('M32 41 L44 36 L54 41 L42 46 Z', 'stoneLt'), S('M32 41 L42 46 V55 L32 50 Z', 'stone'), S('M42 46 L54 41 V50 L42 55 Z', 'grey'),
    L('M16 33 l7 3.2 M31 37 l9 -4', 1.2, .5), H('M15 26 L29 20 l3 1.3 L18 27.5 Z')] },
  { e: '🪨', name: 'Stone', parts: [S('M11 46 C9 36 15 25 25 21.5 C34 18.5 45 20.5 50.5 28.5 C55 35 54.5 42.5 51 47 Z', 'stone'),
    S('M44 50 c0-4.5 4.5-6.5 8.5-5.2 c3.5 1.2 4.5 4.8 2.2 6.4 Z', 'stoneLt'), L('M29 26 C33 30 30 34 36 38 M40 31 l3 3', 2),
    H('M18 32 C19 28 22 25.5 25.5 24.2 l0.8 2.2 C23.6 27.4 21.4 29.5 20.4 32.6 Z')] },
  { e: '🔩', name: 'Metal', parts: [S('M32 12 L49.3 22 V42 L32 52 L14.7 42 V22 Z', 'metal'), C(32, 32, 8.5, 'metalDk'),
    L('M14.7 22 L32 32 M49.3 22 L32 32 M32 52 V40.5', 1.6, .55), H('M18 23.5 L31 16 l0 2.6 L20.2 24.8 Z')] },
  { e: '🟠', name: 'Clay', parts: [S('M10 44 C9 34 18 27 27 27 C30 21 40 20 45 26 C53 27 57 35 54 44 C52 50 14 50 10 44 Z', 'clay'),
    L('M20 40 C25 37 30 39 34 36 M38 33 C42 31 46 33 48 36', 1.8, .6), H('M16 37 C18 33 22 31 26 30.5 l0.2 2.2 C22.6 33 20 35 18.4 38 Z')] },
  { e: '🧶', name: 'Fabric', parts: [C(30, 32, 19, 'wool'), L('M14 26 C24 30 36 26 46 20 M12 34 C24 40 38 36 49 30 M16 43 C26 47 38 45 47 39', 1.8),
    L('M22 15 C28 24 30 38 26 50', 1.8, .7), W('M47 40 C53 44 55 50 51 55', 'woolDk', 2.6)] },
  { e: '🔌', name: 'Copper wire', parts: [R(18, 17, 28, 30, 'copper'), L('M18 23 H46 M18 29 H46 M18 35 H46 M18 41 H46', 1.8),
    R(13, 11, 38, 7, 'wood', 3), R(13, 46, 38, 7, 'wood', 3), W('M46 29 C55 29 57 37 53 42 S49 51 57 53', 'copper', 3.4)] },
  { e: '🌸', name: 'Flowers', parts: [W('M30 34 C29 42 30 50 32 57 M38 36 C40 44 38 50 34 57 M23 36 C24 45 28 51 32 57', 'leafDk', 2.6),
    C(22, 27, 7.5, 'pink'), C(39, 23, 8, 'rose'), C(33, 35, 7, 'pink'), C(22, 27, 2.4, 'gold'), C(39, 23, 2.6, 'gold'), C(33, 35, 2.2, 'gold'),
    S('M37 46 c5-4 11-3 13 0 c-4 3-9 3-13 0 Z', 'leaf')] },
  { e: '🔑', name: 'Lost things', g: 'rotate(-32 32 32)', parts: [S('M17 21 a11 11 0 1 0 0.01 0 Z M17 27.5 a4.5 4.5 0 1 1 -0.01 0 Z', 'gold', 'evenodd'),
    S('M27.5 29 H56 V35 H52 V41 H47 V35 H43 V39 H38.5 V35 H27.5 Z', 'gold'), H('M9.5 27 a8.5 8.5 0 0 1 4-4.6 l1 2 a6.5 6.5 0 0 0 -3 3.4 Z')] },
  { e: '🐟', name: 'Fish', parts: [S('M7 32 C15 20 35 18 45 30 L56 21.5 L53.5 32 L56 42.5 L45 34 C35 46 15 44 7 32 Z', 'fish'), C(17, 29.5, 2.6, 'metalDk'),
    L('M24 25 C27.5 29 27.5 35 24 39 M31 31 h6 M30 35.5 h5', 2), H('M14 26 C19 22 26 21 32 22.5 l-0.4 2.2 C26 23.6 20 24.4 15.5 27.6 Z')] },
  { e: '🥜', name: 'Hazelnuts', parts: [S('M14 40 C14 30 22 24 28 24 C34 24 40 30 40 40 C40 48 34 53 27 53 C20 53 14 48 14 40 Z', 'nut'),
    S('M15 34 C18 26 38 26 39 34 C34 31 20 31 15 34 Z', 'nutLt'), S('M34 30 C34 21 41 15 47 15 C53 15 58 21 58 30 C58 37 53 41 46 41 C39 41 34 37 34 30 Z', 'nut'),
    S('M35 24 C38 17 55 17 57 24 C52 21 40 21 35 24 Z', 'nutLt'), S('M45 15 C42 9 46 6 50 8 C49 11 48 13 45 15 Z', 'leaf'),
    H('M19 40 C19 35 21 32 24 30 l1.2 1.8 C23 33.6 21.6 36.4 21.6 40.4 Z')] },
  { e: '🌰', name: 'Chestnuts', parts: [S('M32 13 C40 21 50 28 50 40 C50 50 42 54.5 32 54.5 C22 54.5 14 50 14 40 C14 28 24 21 32 13 Z', 'nut'),
    S('M16.5 44.5 C22 50.5 42 50.5 47.5 44.5 C46 51.5 40 54.5 32 54.5 C24 54.5 18 51.5 16.5 44.5 Z', 'nutLt'), L('M32 13 v-3', 2.4),
    H('M22 31 C24 26 27 22.5 30 20 l1.6 1.8 C28.8 24.4 26.6 27.6 25 31.8 Z')] },
  { e: '🌱', name: 'Pumpkin seeds', parts: [W('M32 54 C32 44 31 36 32 28', 'leafDk', 2.8), S('M32 30 C24 30 16 24 15 15 C24 14 31 20 32 30 Z', 'leaf'),
    S('M32 34 C38 31 46 31 50 24 C42 21 34 25 32 34 Z', 'leaf'), E(19, 52, 6, 3.6, 'cream'), E(44, 53, 6, 3.6, 'cream'), E(31, 56, 5, 3, 'cream')] },
  { e: '🍞', name: 'Bread', parts: [S('M8 42 C8 28 20 20 32 20 C44 20 56 28 56 42 C56 47 52 50 46 50 H18 C12 50 8 47 8 42 Z', 'bread'),
    L('M20 26 C22 31 22 36 20 40 M31 23 C33 29 33 35 31 40 M42 26 C44 31 44 36 42 40', 2.2), S('M8 42 C14 46 50 46 56 42 C56 47 52 50 46 50 H18 C12 50 8 47 8 42 Z', 'breadDk'),
    H('M14 33 C16 28 20 25 24 23.5 l0.6 2.2 C21 27.2 18 29.6 16.4 34 Z')] },
  { e: '🍰', name: 'Hazelnut cake', parts: [S('M10 40 L46 22 L54 30 V46 L10 50 Z', 'cream'), S('M10 40 L46 22 L54 30 L18 44 Z', 'bread'),
    S('M10 40 L18 44 V54 L10 50 Z', 'breadDk'), S('M18 44 L54 30 V46 L18 54 Z', 'cream'), L('M18 49 L54 37', 2.6, .7), C(40, 25, 4, 'nut'), H('M24 37 L40 29 l0.8 1.8 L25 38.6 Z')] },
  { e: '🎃', name: 'Pumpkins', parts: [S('M32 18 C46 16 56 26 56 37 C56 48 46 54 32 54 C18 54 8 48 8 37 C8 26 18 16 32 18 Z', 'pumpkin'),
    L('M32 19 C24 26 23 46 32 53 M32 19 C40 26 41 46 32 53 M18 21 C12 30 13 46 20 52 M46 21 C52 30 51 46 44 52', 1.8),
    S('M30 19 C29 14 31 10 35 9 L37 11 C34 12 33 15 34 19 Z', 'leafDk'), S('M35 13 C40 8 47 9 49 13 C44 15 39 15 35 13 Z', 'leaf')] },
  { e: '🍄', name: 'Porcini', parts: [S('M22 36 C21 44 20 50 24 54 H40 C44 50 43 44 42 36 Z', 'stem'),
    S('M9 33 C9 17.5 55 17.5 55 33 C55 36 51 37.5 47 37.5 H17 C13 37.5 9 36 9 33 Z', 'cap'), L('M27 44 C27.5 47 28 49 29.5 51', 1.8, .6),
    H('M17 27 C20 22.5 26 20.4 32 20.2 l0 2.6 C26.6 23 22 24.8 19.6 28.4 Z')] },

  // ---------------- HUD, menus, journal ----------------
  { e: '💖', name: 'Approval', parts: [S('M25 39 L18.5 58 L25.5 54.5 L29 59.5 L33 42 Z', 'red'), S('M39 39 L45.5 58 L38.5 54.5 L35 59.5 L31 42 Z', 'red'),
    C(32, 27, 18.5, 'green'), C(32, 27, 12, 'white'), C(32, 27, 5.6, 'red')] },
  { e: '📜', name: 'Journal', parts: [R(44, 12, 7, 40, 'paper', 2), L('M46.5 16 V48', 1.4, .5), R(13, 9, 34, 46, 'journal', 4), R(19, 17, 21, 11, 'paper', 1.5),
    L('M22.5 21 H36.5 M22.5 24.5 H32', 1.6), W('M39.5 9.5 V54.5', 'red', 3)] },
  { e: '🗺', name: 'Map', parts: [S('M8 16 L24 11.5 L40 16 L56 11.5 V48 L40 52.5 L24 48 L8 52.5 Z', 'paper'), S('M24 11.5 L40 16 V52.5 L24 48 Z', 'paperDk'),
    W('M14 42 C20 31 28 40 34 29 S45 23 49 21', 'red', 2.6, '3.5 3'), L('M45.5 17.5 l7 7 M52.5 17.5 l-7 7', 2.6)] },
  { e: '🧭', name: 'Compass', parts: [C(32, 32, 22, 'gold'), C(32, 32, 17, 'paper'), S('M32 15 L37 32 L32 49 L27 32 Z', 'paperDk'), S('M32 15 L37 32 H27 Z', 'red'),
    C(32, 32, 2.6, 'metalDk'), L('M32 10 v3 M32 51 v3 M10 32 h3 M51 32 h3', 2)] },
  { e: '🔨', name: 'Build', g: 'rotate(-38 32 34)', parts: [R(28.5, 20, 7, 38, 'wood', 2.5), S('M15 11 H44 C48 11 50 13 50 16 V22 C50 24 48.5 25 46.5 25 H15 Z', 'metal'),
    L('M20 11 V25', 1.6, .5), H('M23 13.5 H43 v2.4 H23 Z')] },
  { e: '🎒', name: 'Bag', parts: [W('M23.5 26 C23.5 13 40.5 13 40.5 26', 'bagDk', 4.2), S('M11 26 H53 V50 C53 53 51 55 48 55 H16 C13 55 11 53 11 50 Z', 'bag'),
    S('M11 26 H53 V36 C53 38.5 51 40.5 48.5 40.5 H15.5 C13 40.5 11 38.5 11 36 Z', 'bagDk'), R(28.5, 36.5, 7, 7.5, 'gold', 1.5), L('M16 47 H24', 1.6, .5)] },
  { e: '📍', name: 'Pin', parts: [S('M32 56 C26 46 16 37 16 26 C16 17 23 10 32 10 C41 10 48 17 48 26 C48 37 38 46 32 56 Z', 'red'), C(32, 26, 6.5, 'white'),
    H('M21 22 C22 18 25 15 29 14 l0.4 2.2 C26 17 24 19 23.2 22.6 Z')] },
  { e: '📌', name: 'Notice', g: 'rotate(25 32 32)', parts: [W('M32 36 V58', 'metalDk', 2.6), S('M22 36 H42 L38 28 V16 H26 V28 Z', 'red'), R(22, 12, 20, 6, 'red', 3),
    H('M28 18 h3 v9 h-3 Z')] },
  { e: '👗', name: 'Wardrobe', parts: [W('M32 6 C36 6 36 11 32 12 M32 12 L18 19 H46 Z', 'metalDk', 2), S('M25 19 H39 L37 28 C46 36 50 46 52 56 H12 C14 46 18 36 27 28 Z', 'rose'),
    S('M27 28 H37 L36 31 H28 Z', 'red'), L('M22 44 C27 47 37 47 42 44', 1.6, .6)] },
  { e: '📂', name: 'Load', parts: [S('M8 16 H24 L29 21 H50 V48 H8 Z', 'goldDk'), S('M8 26 H56 L50 50 H8 Z', 'gold'), R(14, 18, 34, 10, 'paper', 1)] },
  { e: '💾', name: 'Save', parts: [S('M10 10 H48 L54 16 V54 H10 Z', 'blue'), R(18, 10, 24, 15, 'metal', 1), R(34, 13, 5, 9, 'metalDk', 1), R(16, 34, 32, 20, 'paper', 1.5),
    L('M21 41 H43 M21 46.5 H38', 1.6)] },
  { e: '🔒', name: 'Locked', parts: [W('M22 30 V22 C22 10 42 10 42 22 V30', 'metal', 5), R(14, 29, 36, 26, 'gold', 4), C(32, 39, 3.6, 'metalDk'),
    S('M30.5 41 H33.5 L34.5 48 H29.5 Z', 'metalDk'), H('M18 33 h11 v2.4 h-11 Z')] },
  { e: '📐', name: 'Plans', parts: [S('M10 14 H46 V50 H10 Z', 'blue'), L('M15 21 H40 M15 27 H34 M20 33 H40 M15 39 H30 M24 21 V44', 1.4), S('M46 14 C52 14 54 18 54 22 V54 C54 50 52 50 46 50 Z', 'blueDk'),
    L('M28 28 h8 v8 h-8 Z', 1.6)] },
  { e: '📈', name: 'Progress', parts: [R(10, 10, 44, 44, 'paper', 3), L('M16 48 H48 M16 48 V16', 1.8), W('M18 43 L27 36 L34 39 L46 22', 'green', 3.4), S('M41 20 L48 19 L47 26 Z', 'green')] },
  { e: '✨', name: 'New', parts: [S(star(25, 32, 16, 4.5, 4, -90), 'sun'), S(star(46, 18, 8, 2.4, 4, -90), 'sun'), S(star(46, 46, 6, 1.8, 4, -90), 'sunDk')] },
  { e: '⚙', name: 'Settings', parts: [S(star(32, 32, 24, 18, 8, -90).replace(/L/g, 'L'), 'metal'), C(32, 32, 7.5, 'hole'), L('M32 20 a12 12 0 1 0 0.01 0', 1.6, .55)] },
  { e: '🕒', name: 'Clock', parts: [C(32, 32, 22, 'cream'), L('M32 14 v3 M32 47 v3 M14 32 h3 M47 32 h3', 2), W('M32 32 V20 M32 32 H43', 'ink', 3), C(32, 32, 2.4, 'ink'),
    W('M32 10 a22 22 0 1 1 -0.01 0', 'wood', 2)] },
  { e: '🕛', name: 'Noon', parts: [C(32, 32, 22, 'cream'), L('M32 14 v3 M32 47 v3 M14 32 h3 M47 32 h3', 2), W('M32 32 V17 M32 32 V22', 'ink', 3), C(32, 32, 2.4, 'ink'),
    W('M32 10 a22 22 0 1 1 -0.01 0', 'wood', 2)] },
  { e: '💡', name: 'Tip', parts: [S('M32 8 C43 8 50 16 50 26 C50 33 45 37 42 41 V46 H22 V41 C19 37 14 33 14 26 C14 16 21 8 32 8 Z', 'sun'), R(23, 46, 18, 9, 'metal', 2),
    L('M23 50.5 H41', 1.4, .6), L('M28 41 V30 L32 34 L36 30 V41', 1.6), H('M20 22 C21 17 24 14 28 13 l0.4 2.2 C25.4 16.4 23.2 19 22.4 22.6 Z')] },
  { e: '🛍', name: 'Shop', parts: [W('M24 22 V16 C24 9 40 9 40 16 V22', 'woodDk', 3), S('M12 22 H52 L49 56 H15 Z', 'rose'), L('M20 30 C26 34 38 34 44 30', 1.4, .5),
    H('M17 26 h6 l-0.6 22 h-3 Z')] },
  { e: '🎁', name: 'Gift', parts: [R(12, 28, 40, 26, 'red', 2), R(9, 20, 46, 10, 'rose', 2), R(29, 20, 6, 34, 'gold', 0), S('M32 20 C24 10 14 12 18 19 C20 21 26 21 32 20 Z', 'gold'),
    S('M32 20 C40 10 50 12 46 19 C44 21 38 21 32 20 Z', 'gold')] },
  { e: '💬', name: 'Talk', parts: [S('M12 14 H52 C55 14 57 16 57 19 V38 C57 41 55 43 52 43 H30 L18 53 L20 43 H12 C9 43 7 41 7 38 V19 C7 16 9 14 12 14 Z', 'white'),
    C(22, 28.5, 2.6, 'ink'), C(32, 28.5, 2.6, 'ink'), C(42, 28.5, 2.6, 'ink')] },
  { e: '🏠', name: 'Home', parts: [S('M14 30 L32 14 L50 30 V54 H14 Z', 'cream'), S('M8 32 L32 10 L56 32 L52 35 L32 17 L12 35 Z', 'clay'), R(27, 38, 10, 16, 'wood', 1),
    R(17, 34, 7, 7, 'glass', 1), R(40, 34, 7, 7, 'glass', 1)] },
  { e: '🎵', name: 'Music', parts: [W('M24 46 V16 L48 11 V40', 'ink', 3), S('M24 16 L48 11 V18 L24 23 Z', 'ink'), E(19, 46, 6.5, 5, 'plum'), E(43, 41, 6.5, 5, 'plum')] },
  { e: '♪', name: 'Note', parts: [W('M36 44 V13 C40 18 47 19 48 26', 'ink', 3), E(30, 45, 7.5, 5.6, 'plum')] },
  { e: '🔔', name: 'Sounds', parts: [S('M32 10 C42 10 46 18 46 28 V38 L51 45 H13 L18 38 V28 C18 18 22 10 32 10 Z', 'gold'), C(32, 49, 4.5, 'goldDk'), C(32, 9, 3, 'goldDk'),
    H('M23 24 C23 19 26 15 30 14 l0.4 2.2 C27.4 17 25.6 20 25.4 24.4 Z')] },
  { e: '🆘', name: 'Help', parts: [C(32, 32, 22, 'red'), C(32, 32, 9.5, 'hole'), S('M21 14 A22 22 0 0 1 43 14 L37 23.5 A10 10 0 0 0 27 23.5 Z', 'white'),
    S('M21 50 A22 22 0 0 0 43 50 L37 40.5 A10 10 0 0 1 27 40.5 Z', 'white'), W('M32 10 a22 22 0 1 1 -0.01 0', 'ink', 1)] },
  { e: '⛵', name: 'Travel', parts: [S('M8 42 H56 L49 51 H15 Z', 'woodDk'), S('M30 8 V38 H10 Z', 'white'), S('M34 14 C44 20 50 30 52 38 H34 Z', 'paper'), W('M32 8 V42', 'woodDk', 2.4),
    W('M6 56 C12 53 18 59 24 56 S36 53 42 56 S52 59 58 56', 'rain', 2.2)] },
  { e: '🚌', name: 'Bus', parts: [S('M8 18 C8 14 11 12 15 12 H50 C54 12 57 15 57 20 V45 H8 Z', 'blue'), R(12, 18, 10, 11, 'glass', 1.5), R(25, 18, 10, 11, 'glass', 1.5),
    R(38, 18, 10, 11, 'glass', 1.5), R(50, 18, 5, 15, 'glass', 1.5), L('M8 35 H57', 2, .6), C(20, 46, 6, 'metalDk'), C(46, 46, 6, 'metalDk'), C(20, 46, 2.2, 'metal'), C(46, 46, 2.2, 'metal')] },
  { e: '🚋', name: 'City bus', parts: [W('M24 12 L32 5 L40 12', 'metalDk', 2), S('M10 16 H54 V46 H10 Z', 'pumpkin'), R(14, 20, 10, 11, 'glass', 1.5), R(27, 20, 10, 11, 'glass', 1.5),
    R(40, 20, 10, 11, 'glass', 1.5), L('M10 36 H54', 2, .6), C(20, 47, 5, 'metalDk'), C(44, 47, 5, 'metalDk'), W('M4 54 H60', 'metalDk', 2)] },
  { e: '📟', name: 'Beeper', parts: [R(10, 14, 44, 36, 'navy', 6), R(15, 19, 26, 14, 'leaf', 2), L('M18 24 h4 M24 24 h6 M18 28 h10', 1.6), C(47, 23, 3, 'red'),
    R(16, 38, 6, 6, 'metal', 1.5), R(26, 38, 6, 6, 'metal', 1.5), R(36, 38, 6, 6, 'metal', 1.5)] },
  { e: '📋', name: 'Clipboard', parts: [R(13, 12, 38, 46, 'wood', 3), R(18, 18, 28, 35, 'paper', 1), R(24, 8, 16, 8, 'metal', 2), L('M22 26 H42 M22 32 H42 M22 38 H36 M22 44 H40', 1.6)] },
  { e: '🎲', name: 'Surprise', parts: [S('M32 8 L54 19 L32 30 L10 19 Z', 'white'), S('M10 19 L32 30 V56 L10 45 Z', 'paper'), S('M54 19 L32 30 V56 L54 45 Z', 'paperDk'),
    E(32, 19, 3, 2, 'red'), C(17, 31, 2.2, 'ink'), C(25, 43, 2.2, 'ink'), C(39, 36, 2.2, 'ink'), C(47, 30, 2.2, 'ink'), C(43, 46, 2.2, 'ink')] },
  { e: '💎', name: 'Treasures', parts: [S('M18 14 H46 L56 26 L32 56 L8 26 Z', 'teal'), S('M8 26 H56 L46 14 H18 Z', 'glass'), L('M18 14 L24 26 L32 14 L40 26 L46 14 M24 26 L32 56 L40 26', 1.4, .7)] },
  { e: '🛏', name: 'Sleep', parts: [R(8, 32, 48, 12, 'wood', 2), R(8, 26, 12, 10, 'white', 4), S('M20 27 H54 C56 27 56 29 56 31 V36 H20 Z', 'blue'), W('M8 22 V52 M56 34 V52', 'woodDk', 3.4)] },
  { e: '🌟', name: 'Unlocked', parts: [S(star(32, 33, 23, 10), 'sun'), S(star(32, 33, 13, 6), 'sunDk'), L('M32 4 v3 M58 22 l-3 1 M6 22 l3 1', 2, .7)] },
  { e: '⭐', name: 'Star', parts: [S(star(32, 33, 23, 10), 'sun'), H('M25 26 L31 14 l1 4 L28 27 Z')] },
  { e: '★', name: 'Star', parts: [S(star(32, 33, 23, 10), 'sun'), H('M25 26 L31 14 l1 4 L28 27 Z')] },
  { e: '✦', name: 'Sparkle', parts: [S(star(32, 32, 22, 6, 4, -90), 'gold')] },
  { e: '✔', name: 'Done', parts: [W('M12 34 L26 48 L54 16', 'green', 7)] },
  { e: '✕', name: 'Close', parts: [W('M16 16 L48 48 M48 16 L16 48', 'red', 6)] },
  { e: '♥', name: 'Heart', parts: [S(heartPath, 'rose'), H('M15 22 C16 18 19 15 23 14.5 l0.4 2.2 C20.4 17.2 18.4 19.6 17.4 23 Z')] },
  { e: '♡', name: 'Empty heart', parts: [S(heartPath, 'hole'), W('M32 46 C24 40 16 34 16 25 C16 20 19 17 23 17 C27 17 30 20 32 24 C34 20 37 17 41 17 C45 17 48 20 48 25 C48 34 40 40 32 46 Z', 'rose', 2, '2.5 2.5')] },
  { e: '❗', name: 'Alert', parts: [S('M26 10 H38 L35 40 H29 Z', 'red'), C(32, 50, 5, 'red')] },
  { e: '▶', name: 'Resume', parts: [S('M18 12 L50 32 L18 52 Z', 'green'), H('M22 20 l12 7.5 l-1 1.8 L23 23 Z')] },
  { e: '➤', name: 'Arrow', parts: [S('M12 14 L54 32 L12 50 L20 32 Z', 'pumpkin')] },
  { e: '➜', name: 'Arrow', parts: [S('M8 27 H36 V16 L56 32 L36 48 V37 H8 Z', 'pumpkin')] },
  { e: '✛', name: 'Place', parts: [S('M26 8 H38 V26 H56 V38 H38 V56 H26 V38 H8 V26 H26 Z', 'green')] },
  { e: '✏', name: 'Rename', g: 'rotate(45 32 32)', parts: [R(25, 8, 14, 38, 'gold', 1), S('M25 46 H39 L32 58 Z', 'woodLt'), S('M30 54.5 H34 L32 58 Z', 'ink'), R(25, 4, 14, 6, 'rose', 2)] },
  { e: '🖱', name: 'Mouse', parts: [S('M32 10 C44 10 48 18 48 30 V40 C48 50 41 56 32 56 C23 56 16 50 16 40 V30 C16 18 20 10 32 10 Z', 'white'), L('M16 30 H48 M32 10 V30', 1.6),
    W('M32 10 C32 6 36 5 39 4', 'ink', 2)] },
  { e: '🖥', name: 'Display', parts: [R(8, 10, 48, 32, 'navy', 3), R(12, 14, 40, 24, 'sky', 1.5), S('M26 42 H38 L40 52 H24 Z', 'metal'), R(18, 51, 28, 5, 'metal', 2),
    S('M14 32 C22 28 30 34 38 28 C44 24 48 28 52 26 V38 H12 Z', 'leaf')] },

  // ---------------- weather and the hours (the clock in the corner, the wake-up times) ----------------
  { e: '☀', name: 'Sun', parts: [C(32, 32, 12, 'sun'), W('M32 8 V15 M32 49 V56 M8 32 H15 M49 32 H56 M15 15 L20 20 M44 44 L49 49 M49 15 L44 20 M15 49 L20 44', 'sunDk', 3.2)] },
  { e: '🌙', name: 'Night', parts: [S('M40 10 C26 12 18 22 18 34 C18 46 28 55 41 55 C47 55 52 53 55 49 C50 50 44 49 39 46 C30 40 28 26 33 17 C35 14 37 12 40 10 Z', 'moon'),
    S(star(16, 16, 4, 1.4), 'moon'), S(star(50, 24, 3, 1.1), 'moon')] },
  { e: '☁', name: 'Cloudy', parts: [S(cloudPath(15, 46, 1.25), 'cloud')] },
  { e: '⛅', name: 'Fair', parts: [C(24, 22, 11, 'sun'), W('M24 4 V8 M6 22 H10 M11 9 L14 12 M37 9 L34 12', 'sunDk', 2.6), S(cloudPath(23, 52, 1.05), 'cloud')] },
  { e: '🌦', name: 'Drizzle', parts: [C(44, 18, 9, 'sun'), W('M44 3 V6 M57 18 H60 M53 8 L55 6', 'sunDk', 2.4), S(cloudPath(14, 40, 1.05), 'cloud'),
    W('M18 46 L15 54 M28 46 L25 54 M38 46 L35 54', 'rain', 2.6)] },
  { e: '🌧', name: 'Rain', parts: [S(cloudPath(13, 36, 1.2), 'cloudDk'), W('M17 42 L13 52 M27 42 L23 52 M37 42 L33 52 M47 42 L43 52', 'rain', 3)] },
  { e: '🌨', name: 'Snow', parts: [S(cloudPath(13, 36, 1.2), 'cloud'), C(18, 46, 2.6, 'snow'), C(30, 50, 2.6, 'snow'), C(42, 46, 2.6, 'snow'), C(24, 56, 2.2, 'snow'), C(38, 57, 2.2, 'snow'),
    W('M18 46 h0 M30 50 h0', 'cloudDk', 1)] },
  { e: '🌫', name: 'Mist', parts: [S(cloudPath(16, 30, .9), 'cloud'), W('M8 38 H44 M14 45 H56 M8 52 H40', 'cloudDk', 3.4)] },
  { e: '🌅', name: 'Dawn', parts: [S('M12 40 A20 20 0 0 1 52 40 Z', 'sun'), W('M32 10 V16 M14 18 L18 22 M50 18 L46 22', 'sunDk', 2.8), S('M4 44 C14 36 22 38 32 42 C42 38 50 36 60 44 V56 H4 Z', 'leafDk'),
    W('M8 50 H24 M38 52 H56', 'leaf', 2)] },
  { e: '🌇', name: 'Evening', parts: [C(32, 26, 14, 'sunDk'), W('M32 4 V8 M12 12 L15 15 M52 12 L49 15', 'sunDk', 2.6), S('M6 56 V38 H18 V30 H28 V40 H36 V32 L42 26 L48 32 V40 H58 V56 Z', 'plum'),
    R(21, 34, 3, 4, 'sun', 0), R(40, 35, 3, 4, 'sun', 0), R(10, 44, 3, 4, 'sun', 0), R(50, 46, 3, 4, 'sun', 0)] },

  // ---------------- minigames and building ----------------
  { e: '🪓', name: 'Chop', g: 'rotate(-30 32 32)', parts: [R(29, 10, 6, 48, 'wood', 2.5), S('M33 12 H46 C52 16 54 24 52 30 H33 Z', 'metal'), L('M49 14 C53 19 53 25 51 29', 1.6, .6)] },
  { e: '⛏', name: 'Mine', g: 'rotate(-35 32 34)', parts: [R(29, 16, 6, 44, 'wood', 2.5), S('M8 22 C18 10 46 10 56 22 C46 17 18 17 8 22 Z', 'metal'), R(26, 13, 12, 9, 'metalDk', 2)] },
  { e: '🎣', name: 'Fish', parts: [W('M10 56 L50 8', 'wood', 3.6), W('M50 8 C55 20 56 34 50 44', 'ink', 1.4), C(50, 46, 3, 'red'), S('M40 50 C44 46 50 48 52 52 C48 55 43 54 40 50 Z', 'fish')] },
  { e: '✋', name: 'Move', parts: [S('M20 34 V16 C20 13 25 13 25 16 V30 V12 C25 9 30 9 30 12 V30 V11 C30 8 35 8 35 11 V30 V15 C35 12 40 12 40 15 V36 L44 30 C46 27 51 29 49 33 L42 46 C39 52 34 55 28 55 C22 55 18 50 18 44 Z', 'cream'),
    L('M25 30 V20 M30 30 V18 M35 30 V20', 1.2, .5)] },
  { e: '🗑', name: 'Remove', parts: [S('M16 20 H48 L45 56 H19 Z', 'metal'), R(12, 14, 40, 7, 'metalDk', 2), R(27, 9, 10, 6, 'metalDk', 2), L('M25 26 L26 50 M32 26 V50 M39 26 L38 50', 1.8)] },
  { e: '🧵', name: 'Colour', parts: [R(16, 10, 32, 7, 'wood', 2), R(16, 47, 32, 7, 'wood', 2), R(21, 17, 22, 30, 'rose', 1), L('M21 22 H43 M21 27 H43 M21 32 H43 M21 37 H43 M21 42 H43', 1.4, .7),
    W('M43 30 C52 30 56 38 52 44', 'rose', 2.2)] },
];

if (typeof module !== 'undefined') module.exports = { P, ICONS };
