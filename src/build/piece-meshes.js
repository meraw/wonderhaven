// 3D models for every building piece, centred on their footprint. Colourable parts share one per-object
// "tint" material so recolouring is instant. Mechanisms expose animate(t, status).
import * as THREE from 'three';
import { PIECE, PIECES } from '../data/pieces.js';
import { mat, mesh, uniqueMat, roundedBox, COLORS } from '../world/palette.js';

const box = (w, h, d, m, x = 0, y = 0, z = 0) => { const o = mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); return o; };
const rbox = (w, h, d, m, x = 0, y = 0, z = 0, r = 0.04) => { const o = mesh(roundedBox(w, h, d, r), m); o.position.set(x, y, z); return o; };
const cyl = (rt, rb, h, m, x = 0, y = 0, z = 0, s = 12) => { const o = mesh(new THREE.CylinderGeometry(rt, rb, h, s), m); o.position.set(x, y, z); return o; };
const ball = (r, m, x = 0, y = 0, z = 0) => { const o = mesh(new THREE.SphereGeometry(r, 12, 10), m); o.position.set(x, y, z); return o; };
const N = -0.5 + 0.09; // z of a north-edge piece's centre line

const BUILDERS = {
  bridgeDeck: (g, t) => { for (let n = 0; n < 3; n++) g.add(rbox(0.31, 0.13, 0.98, t, -0.33 + n * 0.33, 0.075, 0, 0.03)); g.add(box(1, 0.04, 0.12, mat(COLORS.woodDark), 0, 0.02, 0.3)); g.add(box(1, 0.04, 0.12, mat(COLORS.woodDark), 0, 0.02, -0.3)); },
  bridgePost: (g, t) => { g.add(cyl(0.26, 0.3, 1.4, t, 0, 0.7, 0, 10)); g.add(cyl(0.32, 0.32, 0.1, mat(COLORS.woodDark), 0, 1.35, 0, 10)); g.add(box(1.0, 0.1, 0.16, mat(COLORS.woodDark), 0, 1.33, 0)); },
  railing: (g, t) => { for (const x of [-0.42, 0, 0.42]) g.add(box(0.1, 0.7, 0.1, t, x, 0.35, N)); g.add(box(1, 0.08, 0.12, t, 0, 0.66, N)); g.add(box(1, 0.06, 0.08, t, 0, 0.35, N)); },
  floor: (g, t) => { g.add(rbox(0.99, 0.12, 0.99, t, 0, 0.06, 0, 0.02)); for (const x of [-0.25, 0.25]) g.add(box(0.02, 0.122, 0.95, mat('#b98a5a'), x, 0.061, 0)); },
  stoneBlock: (g, t) => { g.add(rbox(0.99, 0.99, 0.99, t, 0, 0.5, 0, 0.06)); },
  foundation: (g, t) => { g.add(rbox(1.98, 0.3, 1.98, t, 0, 0.15, 0, 0.05)); },
  platform: (g, t) => { g.add(rbox(1.98, 0.16, 1.98, t, 0, 0.92, 0, 0.04)); for (const [x, z] of [[-0.85, -0.85], [0.85, -0.85], [-0.85, 0.85], [0.85, 0.85]]) g.add(cyl(0.08, 0.09, 0.85, mat(COLORS.woodDark), x, 0.42, z, 8)); },
  stairs: (g, t) => { for (let n = 0; n < 4; n++) g.add(box(0.96, 0.25 * (n + 1), 0.25, t, 0, 0.125 * (n + 1), 0.375 - n * 0.25)); },
  woodWall: (g, t) => { g.add(box(1, 2.2, 0.18, t, 0, 1.1, N)); g.add(box(1.0, 0.12, 0.2, mat(COLORS.woodDark), 0, 0.06, N)); },
  windowWall: (g, t) => {
    g.add(box(1, 0.8, 0.18, t, 0, 0.4, N)); g.add(box(1, 0.6, 0.18, t, 0, 1.9, N)); g.add(box(0.2, 0.8, 0.18, t, -0.4, 1.2, N)); g.add(box(0.2, 0.8, 0.18, t, 0.4, 1.2, N));
    const glass = box(0.6, 0.8, 0.04, mat('#bfe8ff', { emissive: '#ffcf6b', emissiveIntensity: 0 }), 0, 1.2, N); glass.name = 'glass'; g.add(glass); g.add(box(0.05, 0.8, 0.06, mat('#fff'), 0, 1.2, N));
  },
  doorWall: (g, t) => {
    const frame = mat('#f3dfc1');
    g.add(box(0.14, 2.2, 0.18, frame, -0.43, 1.1, N)); g.add(box(0.14, 2.2, 0.18, frame, 0.43, 1.1, N)); g.add(box(1, 0.25, 0.18, frame, 0, 2.08, N));
    const hinge = new THREE.Group(); hinge.position.set(-0.36, 0, N); hinge.name = 'hinge';
    const leaf = rbox(0.72, 1.92, 0.08, t, 0.36, 0.97, 0, 0.03); hinge.add(leaf); hinge.add(ball(0.04, mat(COLORS.gold), 0.62, 0.95, 0.06));
    g.add(hinge);
  },
  roof: (g, t) => { const r = mesh(new THREE.ConeGeometry(1.5, 1.2, 4), t); r.rotation.y = Math.PI / 4; r.position.y = 0.6; g.add(r); },
  pillar: (g, t) => { g.add(cyl(0.18, 0.2, 2.0, t, 0, 1.0, 0, 12)); g.add(box(0.5, 0.12, 0.5, t, 0, 0.06, 0)); g.add(box(0.5, 0.12, 0.5, t, 0, 2.14, 0)); },
  fence: (g, t) => { for (const x of [-0.42, 0, 0.42]) { g.add(box(0.1, 0.75, 0.08, t, x, 0.37, N)); const tip = mesh(new THREE.ConeGeometry(0.07, 0.12, 4), t); tip.position.set(x, 0.8, N); g.add(tip); } g.add(box(1, 0.07, 0.06, t, 0, 0.55, N)); g.add(box(1, 0.07, 0.06, t, 0, 0.25, N)); },
  chair: (g, t) => { g.add(rbox(0.5, 0.08, 0.5, t, 0, 0.45, 0)); g.add(rbox(0.5, 0.5, 0.08, t, 0, 0.72, -0.22)); for (const [x, z] of [[-0.2, -0.2], [0.2, -0.2], [-0.2, 0.2], [0.2, 0.2]]) g.add(cyl(0.03, 0.03, 0.45, mat(COLORS.woodDark), x, 0.22, z, 6)); },
  table: (g, t) => { g.add(rbox(0.85, 0.08, 0.85, t, 0, 0.66, 0)); g.add(cyl(0.06, 0.1, 0.62, mat(COLORS.woodDark), 0, 0.31, 0)); g.add(cyl(0.25, 0.28, 0.05, mat(COLORS.woodDark), 0, 0.025, 0)); g.add(ball(0.08, mat('#ff8fab'), 0.15, 0.75, 0.1)); },
  sofa: (g, t) => { g.add(rbox(1.9, 0.35, 0.6, t, 0, 0.3, 0.05, 0.12)); g.add(rbox(1.9, 0.5, 0.2, t, 0, 0.6, -0.25, 0.1)); for (const x of [-0.9, 0.9]) g.add(rbox(0.2, 0.45, 0.65, t, x, 0.42, 0.02, 0.08)); for (const x of [-0.45, 0.45]) g.add(rbox(0.82, 0.1, 0.5, mat('#ffffff'), x, 0.5, 0.08, 0.05)); },
  bed: (g, t) => { g.add(rbox(0.9, 0.35, 1.9, mat('#d9a066'), 0, 0.2, 0)); g.add(rbox(0.86, 0.15, 1.3, t, 0, 0.43, 0.25, 0.06)); g.add(rbox(0.6, 0.15, 0.35, mat('#ffffff'), 0, 0.45, -0.65, 0.07)); g.add(rbox(0.9, 0.7, 0.1, mat('#c98a55'), 0, 0.4, -0.92)); },
  cabinet: (g, t) => { g.add(rbox(0.8, 1.2, 0.6, t, 0, 0.6, 0)); for (const y of [0.35, 0.8]) { g.add(box(0.7, 0.02, 0.02, mat('#00000033'), 0, y + 0.18, 0.31)); g.add(ball(0.035, mat(COLORS.gold), 0, y, 0.31)); } },
  bookshelf: (g, t) => { g.add(rbox(0.9, 1.8, 0.5, t, 0, 0.9, -0.15)); const cols = ['#ff8fab', '#6cc4ff', '#7bd389', '#ffd166', '#b59cff']; for (let s = 0; s < 3; s++) for (let n = 0; n < 5; n++) g.add(box(0.12, 0.38, 0.32, mat(cols[(n + s) % 5]), -0.3 + n * 0.15, 0.32 + s * 0.55, -0.06)); },
  desk: (g, t) => { g.add(rbox(1.9, 0.08, 0.7, t, 0, 0.72, 0)); for (const x of [-0.85, 0.85]) g.add(rbox(0.15, 0.7, 0.62, t, x, 0.35, 0)); g.add(box(0.5, 0.02, 0.35, mat('#e0f4ff'), -0.3, 0.77, 0)); g.add(cyl(0.03, 0.03, 0.2, mat('#5a3d2b'), 0.4, 0.86, 0, 6)); },
  lamp: (g, t) => { g.add(cyl(0.18, 0.2, 0.06, mat('#5a3d2b'), 0, 0.03, 0)); g.add(cyl(0.025, 0.025, 1.0, mat('#5a3d2b'), 0, 0.53, 0, 6)); const shade = cyl(0.12, 0.24, 0.28, t, 0, 1.12, 0, 14); g.add(shade); const bulb = ball(0.08, mat('#fff3b0', { emissive: '#ffcf6b', emissiveIntensity: 0.3 }), 0, 1.05, 0); bulb.name = 'bulb'; g.add(bulb); },
  rug: (g, t) => { const r = mesh(new THREE.CylinderGeometry(0.95, 0.95, 0.04, 28), t); r.scale.z = 0.9; r.position.y = 0.02; g.add(r); const r2 = mesh(new THREE.CylinderGeometry(0.6, 0.6, 0.045, 24), mat('#ffffff')); r2.scale.z = 0.9; r2.position.y = 0.022; g.add(r2); },
  counter: (g, t) => { g.add(rbox(2, 0.85, 0.8, t, 0, 0.425, 0)); g.add(rbox(2.05, 0.1, 0.85, mat('#c98a55'), 0, 0.9, 0)); g.add(cyl(0.18, 0.12, 0.12, mat('#ffffff'), -0.5, 1.0, 0)); g.add(ball(0.13, mat('#f5c27a'), -0.5, 1.1, 0)); },
  workbench: (g, t) => { g.add(rbox(2, 0.1, 0.8, t, 0, 0.85, 0)); for (const [x, z] of [[-0.9, -0.3], [0.9, -0.3], [-0.9, 0.3], [0.9, 0.3]]) g.add(box(0.1, 0.8, 0.1, mat(COLORS.woodDark), x, 0.4, z)); g.add(box(1.8, 0.06, 0.7, mat(COLORS.woodDark), 0, 0.25, 0)); g.add(box(0.4, 0.1, 0.12, mat('#9aa4b5'), 0.5, 0.95, 0)); g.add(cyl(0.05, 0.05, 0.3, mat('#d9a066'), -0.5, 0.95, 0.1)).rotation.z = Math.PI / 2; },
  painting: (g, t) => { g.add(rbox(0.7, 0.55, 0.05, mat('#c98a55'), 0, 0.35, N + 0.14)); g.add(box(0.58, 0.43, 0.02, t, 0, 0.35, N + 0.17)); g.add(ball(0.08, mat('#fff3b0'), 0.12, 0.42, N + 0.18)); g.add(box(0.5, 0.12, 0.02, mat('#7bd389'), 0, 0.2, N + 0.18)); },
  tree: (g, t) => { g.add(cyl(0.12, 0.17, 1.1, mat(COLORS.trunk), 0, 0.55, 0, 7)); g.add(ball(0.7, t, 0, 1.6, 0)); g.add(ball(0.45, t, 0.3, 2.1, 0.1)); g.add(ball(0.42, t, -0.35, 1.4, 0.25)); },
  flowerBed: (g, t) => { g.add(rbox(0.9, 0.2, 0.9, mat('#a0623a'), 0, 0.1, 0)); g.add(box(0.8, 0.04, 0.8, mat('#7a4a2a'), 0, 0.21, 0)); for (let n = 0; n < 8; n++) { const a = n * 0.8, r = 0.12 + (n % 3) * 0.1; g.add(ball(0.07, n % 2 ? t : mat('#ffffff'), Math.cos(a) * r, 0.32, Math.sin(a) * r)); } },
  hedge: (g, t) => { g.add(rbox(0.98, 0.9, 0.98, t, 0, 0.45, 0, 0.2)); },
  bench: (g, t) => { g.add(rbox(1.8, 0.08, 0.45, t, 0, 0.42, 0.05)); g.add(rbox(1.8, 0.3, 0.06, t, 0, 0.66, -0.2)); for (const x of [-0.75, 0.75]) g.add(box(0.08, 0.42, 0.45, mat('#4a4a5a'), x, 0.21, 0.05)); },
  statue: (g, t) => { g.add(rbox(0.7, 0.5, 0.7, t, 0, 0.25, 0)); g.add(ball(0.25, t, 0, 1.6, 0)); g.add(cyl(0.18, 0.24, 0.6, t, 0, 1.1, 0)); const s = mesh(new THREE.OctahedronGeometry(0.12), mat(COLORS.gold)); s.position.set(0.25, 1.75, 0); g.add(s); g.add(cyl(0.02, 0.02, 0.6, mat(COLORS.gold), 0.25, 1.4, 0, 5)); },
  signpost: (g, t) => { g.add(cyl(0.05, 0.06, 1.4, mat(COLORS.woodDark), 0, 0.7, 0, 6)); g.add(rbox(0.7, 0.22, 0.06, t, 0.15, 1.15, 0)); g.add(rbox(0.6, 0.2, 0.06, t, -0.12, 0.85, 0)); },
  streetlight: (g, t) => { g.add(cyl(0.05, 0.08, 2.3, t, 0, 1.15, 0, 8)); const b = ball(0.18, mat('#fff3b0', { emissive: '#ffcf6b', emissiveIntensity: 0.3 }), 0, 2.4, 0); b.name = 'bulb'; g.add(b); const c = mesh(new THREE.ConeGeometry(0.26, 0.18, 8), t); c.position.y = 2.58; g.add(c); },
  gardenPath: (g, t) => { for (const [x, z, r] of [[-0.2, -0.2, 0.28], [0.25, 0.15, 0.25], [-0.15, 0.3, 0.18], [0.3, -0.3, 0.15]]) g.add(cyl(r, r, 0.05, t, x, 0.025, z, 9)); },
  pond: (g, t) => { const rim = mesh(new THREE.TorusGeometry(0.85, 0.12, 6, 20), mat('#bdb5a8')); rim.rotation.x = Math.PI / 2; rim.position.y = 0.12; g.add(rim); g.add(cyl(0.85, 0.85, 0.12, mat('#5fcde4'), 0, 0.08, 0, 24)); const lily = cyl(0.12, 0.12, 0.02, mat('#5cb85c'), 0.3, 0.15, 0.2, 8); g.add(lily); g.add(ball(0.05, mat('#ff9ec7'), 0.3, 0.18, 0.2)); },
  miniFountain: (g, t) => { g.add(cyl(0.4, 0.45, 0.35, t, 0, 0.18, 0, 16)); g.add(cyl(0.08, 0.1, 0.6, t, 0, 0.6, 0, 8)); g.add(cyl(0.22, 0.1, 0.12, t, 0, 0.92, 0, 12)); const w = cyl(0.34, 0.34, 0.03, mat('#6fd8ee'), 0, 0.34, 0, 16); w.name = 'water'; w.visible = false; g.add(w); const spray = ball(0.12, new THREE.MeshBasicMaterial({ color: '#c9f6ff', transparent: true, opacity: 0.7 }), 0, 1.1, 0); spray.name = 'spray'; spray.visible = false; g.add(spray); },
  waterwheel: (g, t) => {
    const wheel = new THREE.Group(); wheel.name = 'spin'; wheel.position.y = 0.6; wheel.userData.axis = 'z';
    const rim = mesh(new THREE.TorusGeometry(0.55, 0.05, 6, 18), t); wheel.add(rim);
    for (let n = 0; n < 8; n++) { const a = n * Math.PI / 4; const sp = box(0.06, 1.1, 0.06, t); sp.rotation.z = a; wheel.add(sp); const pad = box(0.08, 0.22, 0.45, mat(COLORS.woodDark), Math.cos(a) * 0.58, Math.sin(a) * 0.58, 0); pad.rotation.z = a; wheel.add(pad); }
    wheel.rotation.y = Math.PI / 2; g.add(wheel);
    const axle = cyl(0.06, 0.06, 1.0, mat('#7a7f8a'), 0, 0.6, 0, 8); axle.rotation.x = Math.PI / 2; g.add(axle);
    for (const z of [-0.45, 0.45]) g.add(box(0.12, 0.7, 0.12, mat(COLORS.woodDark), 0, 0.35, z));
  },
  windmill: (g, t) => {
    g.add(cyl(0.22, 0.32, 2.0, t, 0, 1.0, 0, 8)); g.add(mesh(new THREE.ConeGeometry(0.3, 0.4, 8), mat('#e86f5c'))).position.y = 2.2;
    const blades = new THREE.Group(); blades.name = 'spin'; blades.userData.axis = 'z'; blades.position.set(0, 1.85, 0.3);
    for (let n = 0; n < 4; n++) { const b = box(0.16, 0.9, 0.03, mat('#fff7e8')); b.position.y = 0.45; const arm = new THREE.Group(); arm.rotation.z = n * Math.PI / 2; arm.add(b); blades.add(arm); }
    g.add(blades); g.add(box(0.12, 0.3, 0.12, mat('#7a7f8a'), 0, 0.15, 0.4));
  },
  gear: (g, t) => {
    g.add(rbox(0.66, 0.4, 0.66, t, 0, 0.2, 0));
    const cog = new THREE.Group(); cog.name = 'spin'; cog.userData.axis = 'y'; cog.position.y = 0.48;
    const ring = mesh(new THREE.CylinderGeometry(0.28, 0.28, 0.1, 12), mat(COLORS.gold)); cog.add(ring);
    for (let n = 0; n < 10; n++) { const tooth = box(0.09, 0.1, 0.09, mat(COLORS.gold)); const a = n / 10 * Math.PI * 2; tooth.position.set(Math.cos(a) * 0.32, 0, Math.sin(a) * 0.32); tooth.rotation.y = -a; cog.add(tooth); }
    g.add(cog);
    for (const [x, z] of [[0, -0.42], [0, 0.42], [0.42, 0], [-0.42, 0]]) g.add(box(x ? 0.18 : 0.12, 0.12, x ? 0.12 : 0.18, mat('#7a7f8a'), x, 0.22, z));
  },
  shaft: (g, t) => { const s = new THREE.Group(); s.name = 'spin'; s.userData.axis = 'z'; s.position.y = 0.25; const c = cyl(0.07, 0.07, 1.0, t, 0, 0, 0, 8); c.rotation.x = Math.PI / 2; s.add(c); for (const z of [-0.25, 0.25]) { const k = box(0.2, 0.05, 0.05, mat(COLORS.gold), 0, 0, z); s.add(k); } g.add(s); for (const z of [-0.3, 0.3]) g.add(box(0.14, 0.22, 0.1, mat(COLORS.woodDark), 0, 0.11, z)); },
  lever: (g, t) => { g.add(rbox(0.45, 0.2, 0.75, mat('#7a7f8a'), 0, 0.1, 0)); g.add(box(0.12, 0.12, 1.0, mat('#a0623a'), 0, 0.12, 0)); const h = new THREE.Group(); h.name = 'handle'; h.position.y = 0.2; h.add(cyl(0.03, 0.03, 0.5, mat('#5a3d2b'), 0, 0.25, 0, 6)); h.add(ball(0.08, t, 0, 0.52, 0)); g.add(h); },
  pump: (g, t) => {
    g.add(rbox(0.75, 0.6, 0.75, t, 0, 0.3, 0)); g.add(cyl(0.2, 0.2, 0.3, mat('#7a7f8a'), 0, 0.75, 0));
    const piston = cyl(0.08, 0.08, 0.35, mat(COLORS.gold), 0, 0.95, 0, 8); piston.name = 'piston'; g.add(piston);
    const spout = cyl(0.1, 0.1, 0.4, mat('#7a7f8a'), -0.45, 0.25, 0, 8); spout.rotation.z = Math.PI / 2; g.add(spout);
    const input = box(0.3, 0.16, 0.16, mat(COLORS.gold), 0.42, 0.25, 0); g.add(input);
    const dot = ball(0.06, mat('#9aa4b5', { emissive: '#3fbfff', emissiveIntensity: 0 }), 0, 0.62, 0.38); dot.name = 'status'; g.add(dot);
  },
  pipe: (g, t) => { const p = cyl(0.17, 0.17, 1.0, t, 0, 0.2, 0, 10); p.rotation.x = Math.PI / 2; g.add(p); for (const z of [-0.45, 0.45]) { const c = cyl(0.2, 0.2, 0.08, mat('#6f8296'), 0, 0.2, z, 10); c.rotation.x = Math.PI / 2; g.add(c); } addFlow(g, [[0, 0.2, -0.5], [0, 0.2, 0.5]]); },
  pipeCorner: (g, t) => { const a = cyl(0.17, 0.17, 0.62, t, 0, 0.2, -0.19, 10); a.rotation.x = Math.PI / 2; g.add(a); const b = cyl(0.17, 0.17, 0.62, t, 0.19, 0.2, 0, 10); b.rotation.z = Math.PI / 2; g.add(b); g.add(ball(0.19, t, 0, 0.2, 0)); addFlow(g, [[0, 0.2, -0.5], [0, 0.2, 0], [0.5, 0.2, 0]]); },
  pipeTee: (g, t) => { const a = cyl(0.17, 0.17, 1.0, t, 0, 0.2, 0, 10); a.rotation.z = Math.PI / 2; g.add(a); const b = cyl(0.17, 0.17, 0.5, t, 0, 0.2, -0.25, 10); b.rotation.x = Math.PI / 2; g.add(b); g.add(ball(0.19, t, 0, 0.2, 0)); addFlow(g, [[-0.5, 0.2, 0], [0.5, 0.2, 0]]); addFlow(g, [[0, 0.2, 0], [0, 0.2, -0.5]]); },
  poweredLamp: (g, t) => { g.add(rbox(0.4, 0.15, 0.4, mat('#7a7f8a'), 0, 0.075, 0)); g.add(cyl(0.05, 0.05, 1.2, t, 0, 0.75, 0, 8)); const b = ball(0.2, mat('#d0e8ff', { emissive: '#7fd8ff', emissiveIntensity: 0 }), 0, 1.45, 0); b.name = 'bulb'; g.add(b); },
};
function addFlow(g, pts) {
  const flow = new THREE.Group(); flow.name = 'flow'; flow.visible = false;
  const m = new THREE.MeshBasicMaterial({ color: '#7fe3ff', transparent: true, opacity: 0.9 });
  for (let n = 0; n < 4; n++) { const d = new THREE.Mesh(new THREE.SphereGeometry(0.07, 6, 5), m); d.userData.phase = n / 4; d.userData.pts = pts; flow.add(d); }
  g.add(flow);
}

export function makePieceMesh(id, color) {
  const def = PIECE[id];
  const g = new THREE.Group();
  const tint = uniqueMat(color || def.color);
  BUILDERS[id](g, tint);
  g.userData.tint = tint; g.userData.id = id;
  return g;
}
export function hasMeshFor(id) { return typeof BUILDERS[id] === 'function'; }
export const BUILDER_IDS = Object.keys(BUILDERS);

export function setPieceColor(g, color) { g.userData.tint.color.set(color); }

// Animate a placed piece given its mechanical status { spinning, powered, watered, on, open, night }.
export function animatePiece(g, pl, t, dt, s) {
  g.traverse(o => {
    if (o.name === 'spin' && s.spinning) { if (o.userData.axis === 'y') o.rotation.y += dt * 2.6; else o.rotation.z += dt * 2.2; }
    if (o.name === 'flow') {
      o.visible = !!s.watered;
      if (s.watered) for (const d of o.children) { const [a, b] = [d.userData.pts[0], d.userData.pts[d.userData.pts.length - 1]]; const p = (t * 1.2 + d.userData.phase) % 1; d.position.set(a[0] + (b[0] - a[0]) * p, a[1], a[2] + (b[2] - a[2]) * p); }
    }
    if (o.name === 'piston') o.position.y = 0.95 + (s.powered ? Math.abs(Math.sin(t * 6)) * 0.12 : 0);
    if (o.name === 'status') o.material.emissiveIntensity = s.watered ? 1.2 : s.powered ? 0.5 : 0;
    if (o.name === 'bulb') o.material.emissiveIntensity = pl.id === 'poweredLamp' ? (s.powered ? 1.8 : 0) : (s.night ? 1.6 : 0.25);
    if (o.name === 'handle') o.rotation.x = s.on ? 0.6 : -0.6;
    if (o.name === 'hinge') o.rotation.y += ((s.open ? -1.5 : 0) - o.rotation.y) * Math.min(1, dt * 8);
    if (o.name === 'water') o.visible = !!s.watered;
    if (o.name === 'spray') { o.visible = !!s.watered; if (s.watered) { o.position.y = 1.1 + Math.abs(Math.sin(t * 5)) * 0.25; o.scale.setScalar(0.8 + Math.sin(t * 9) * 0.2); } }
    if (o.name === 'glass') o.material.emissiveIntensity = s.night ? 0.6 : 0;
  });
}

// Translucent ghost copy for previews.
const ghostMats = { ok: new THREE.MeshBasicMaterial({ color: '#7dffb0', transparent: true, opacity: 0.5, depthWrite: false }), bad: new THREE.MeshBasicMaterial({ color: '#ff7a7a', transparent: true, opacity: 0.5, depthWrite: false }), plan: new THREE.MeshBasicMaterial({ color: '#b07cff', transparent: true, opacity: 0.45, depthWrite: false }) };
export function makeGhost(id, kind = 'ok') {
  const g = makePieceMesh(id);
  g.traverse(o => { if (o.isMesh) { o.material = ghostMats[kind]; o.castShadow = false; o.receiveShadow = false; } });
  g.userData.ghostKind = kind;
  return g;
}
export function setGhostKind(g, kind) {
  if (g.userData.ghostKind === kind) return;
  g.traverse(o => { if (o.isMesh) o.material = ghostMats[kind]; });
  g.userData.ghostKind = kind;
}
export function allPieceIdsHaveMeshes() { return PIECES.every(p => hasMeshFor(p.id)); }
