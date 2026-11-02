// Chibi characters: big heads, short limbs, canvas-drawn faces and bouncy procedural animation.
import * as THREE from 'three';
import { mat, mesh, uniqueMat, roundedBox, COLORS } from './palette.js';
import { sanitizeAppearance } from '../data/appearance.js';

const sph = (r, w = 14, h = 12) => new THREE.SphereGeometry(r, w, h);
const cap = (r, l) => new THREE.CapsuleGeometry(r, l, 4, 8);
const HEAD_R = 0.4;

const ACTION_LENGTH = { wave: 1.6, clap: 1.4, celebrate: 1.9, surprised: 0.9, chop: 0.55, mine: 0.6, dig: 0.7, build: 0.9, nod: 0.8, shrug: 1.0, feed: 1.0 };

function drawFace(ctx, f) {
  const W = 512, H = 256; ctx.clearRect(0, 0, W, H);
  const cx = 128, ey = 136, ex = 39;
  const mood = f.mood || 'neutral';
  const shape = mood === 'happy' ? 'happy' : mood === 'surprised' ? 'wide' : mood === 'sleepy' ? 'sleepy' : f.eyeShape;
  const blink = f.blink || 0;
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  for (const s of [-1, 1]) {
    const x = cx + s * ex;
    if (shape === 'happy' || blink > 0.5) {
      ctx.strokeStyle = '#3a2a2a'; ctx.lineWidth = 6;
      ctx.beginPath();
      if (shape === 'happy') ctx.arc(x, ey + 6, 13, Math.PI * 1.1, Math.PI * 1.9); else { ctx.moveTo(x - 13, ey); ctx.lineTo(x + 13, ey); }
      ctx.stroke();
      continue;
    }
    if (shape === 'sleepy') {
      ctx.fillStyle = '#2a1f1f'; ctx.beginPath(); ctx.ellipse(x, ey + 4, 13, 8, 0, 0, Math.PI); ctx.fill();
      ctx.strokeStyle = '#3a2a2a'; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(x - 15, ey + 2); ctx.lineTo(x + 15, ey + 2); ctx.stroke();
      continue;
    }
    const rx = shape === "wide" ? 17 : 14.5, ry = shape === "wide" ? 23 : 20.5;
    ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.ellipse(x, ey, rx + 3, ry + 3, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = f.eyeColor; ctx.beginPath(); ctx.ellipse(x, ey + 2, rx - 1, ry - 2, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#1d1414'; ctx.beginPath(); ctx.ellipse(x, ey + 4, rx * 0.5, ry * 0.55, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.arc(x - 4, ey - 6, shape === 'sparkle' ? 6 : 5, 0, Math.PI * 2); ctx.fill();
    if (shape === 'sparkle') { ctx.beginPath(); ctx.arc(x + 5, ey + 7, 3, 0, Math.PI * 2); ctx.fill(); }
    ctx.strokeStyle = '#3a2a2a'; ctx.lineWidth = 3; ctx.beginPath(); ctx.ellipse(x, ey, rx + 3, ry + 3, 0, Math.PI * 1.15, Math.PI * 1.85); ctx.stroke();
  }
  // Brows
  ctx.strokeStyle = 'rgba(60,40,30,0.75)'; ctx.lineWidth = 4;
  for (const s of [-1, 1]) {
    ctx.beginPath();
    const lift = mood === 'surprised' ? -10 : mood === 'sad' ? 4 : 0;
    ctx.moveTo(cx + s * (ex - 12), ey - 30 + lift + (mood === 'sad' ? -s * 0 : 0)); ctx.lineTo(cx + s * (ex + 10), ey - 32 + lift + (mood === 'sad' ? 6 : 0)); ctx.stroke();
  }
  // Blush
  ctx.fillStyle = 'rgba(255,120,140,0.35)';
  for (const s of [-1, 1]) { ctx.beginPath(); ctx.ellipse(cx + s * 58, ey + 26, 14, 8, 0, 0, Math.PI * 2); ctx.fill(); }
  // Mouth
  const mouth = mood === 'happy' ? 'grin' : mood === 'surprised' ? 'o' : mood === 'sad' ? 'sad' : (f.talking ? (f.talkOpen ? 'o' : f.mouth) : f.mouth);
  const my = 180;
  ctx.strokeStyle = '#7a3a3a'; ctx.fillStyle = '#c4545e'; ctx.lineWidth = 5;
  ctx.beginPath();
  if (mouth === 'smile') { ctx.arc(cx, my - 10, 13, Math.PI * 0.2, Math.PI * 0.8); ctx.stroke(); }
  else if (mouth === 'grin') { ctx.moveTo(cx - 16, my - 4); ctx.quadraticCurveTo(cx, my + 22, cx + 16, my - 4); ctx.closePath(); ctx.fill(); ctx.stroke(); }
  else if (mouth === 'cat') { ctx.moveTo(cx - 14, my - 4); ctx.quadraticCurveTo(cx - 7, my + 6, cx, my - 2); ctx.quadraticCurveTo(cx + 7, my + 6, cx + 14, my - 4); ctx.stroke(); }
  else if (mouth === 'calm') { ctx.moveTo(cx - 9, my); ctx.lineTo(cx + 9, my); ctx.stroke(); }
  else if (mouth === 'o') { ctx.ellipse(cx, my, 7, 9, 0, 0, Math.PI * 2); ctx.fill(); }
  else if (mouth === 'sad') { ctx.arc(cx, my + 10, 11, Math.PI * 1.2, Math.PI * 1.8); ctx.stroke(); }
}

function makeStaff() {
  const g = new THREE.Group(); g.name = 'staff';
  const shaft = mesh(new THREE.CylinderGeometry(0.025, 0.03, 0.95, 6), mat('#a0663a')); shaft.position.y = 0.2; g.add(shaft);
  const ring = mesh(new THREE.TorusGeometry(0.09, 0.022, 6, 12), mat(COLORS.gold)); ring.position.y = 0.72; g.add(ring);
  const star = mesh(new THREE.OctahedronGeometry(0.1, 0), uniqueMat('#fff2a8', { emissive: '#ffd35c', emissiveIntensity: 0.9 }), { shadow: false }); star.position.y = 0.72; star.name = 'star'; g.add(star);
  return g;
}

function buildHair(style, color) {
  const g = new THREE.Group(), m = mat(color);
  const capGeo = new THREE.SphereGeometry(HEAD_R * 1.06, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.5);
  const top = mesh(capGeo, m); top.position.y = HEAD_R * 0.04; top.rotation.x = -0.18; g.add(top);
  const fringe = mesh(new THREE.SphereGeometry(HEAD_R * 1.04, 14, 8, -Math.PI * 0.85, Math.PI * 0.7, Math.PI * 0.32, Math.PI * 0.16), m); fringe.rotation.y = Math.PI; g.add(fringe);
  const add = (geo, x, y, z, sx = 1, sy = 1, sz = 1) => { const p = mesh(geo, m); p.position.set(x, y, z); p.scale.set(sx, sy, sz); g.add(p); return p; };
  if (style === 'bob' || style === 'long' || style === 'pigtails' || style === 'ponytail' || style === 'bun') {
    add(new THREE.SphereGeometry(HEAD_R * 1.08, 16, 10, Math.PI * 0.15, Math.PI * 1.7, Math.PI * 0.3, Math.PI * 0.45), 0, 0, 0).rotation.y = Math.PI * 0.5;
  }
  if (style === 'long') add(roundedBox(0.7, 0.75, 0.25, 0.12), 0, -0.3, -0.25);
  if (style === 'pigtails') for (const s of [-1, 1]) add(sph(0.15, 10, 8), s * 0.45, -0.15, -0.05, 0.9, 1.4, 0.9);
  if (style === 'ponytail') add(sph(0.14, 10, 8), 0, 0.0, -0.48, 0.9, 1.6, 0.9).rotation.x = 0.6;
  if (style === 'bun') add(sph(0.17, 12, 10), 0, 0.42, -0.1);
  if (style === 'spiky') for (let n = 0; n < 7; n++) { const a = n / 7 * Math.PI * 2; const c = add(new THREE.ConeGeometry(0.1, 0.28, 6), Math.cos(a) * 0.22, 0.36, Math.sin(a) * 0.22 - 0.05); c.rotation.set(Math.sin(a) * 0.7, 0, -Math.cos(a) * 0.7); }
  if (style === 'curly') for (let n = 0; n < 12; n++) { const a = n / 12 * Math.PI * 2; add(sph(0.13, 8, 6), Math.cos(a) * 0.36, 0.18 + (n % 2) * 0.1, Math.sin(a) * 0.36 - 0.05); }
  if (style === 'short') add(sph(0.12, 8, 6), 0.05, 0.42, 0.1, 1.2, 0.5, 1);
  return g;
}
function buildHat(kind, color) {
  const g = new THREE.Group();
  const add = (geo, m, x, y, z) => { const p = mesh(geo, m); p.position.set(x, y, z); g.add(p); return p; };
  if (kind === 'beret') { const b = add(sph(0.36, 14, 8), mat(color), 0.06, 0.36, 0); b.scale.set(1.1, 0.4, 1.1); b.rotation.z = -0.25; }
  if (kind === 'beanie') { add(new THREE.SphereGeometry(0.43, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.5), mat(color), 0, 0.08, 0); add(sph(0.08), mat('#ffffff'), 0, 0.52, 0); }
  if (kind === 'bow') { for (const s of [-1, 1]) { const w = add(new THREE.ConeGeometry(0.1, 0.2, 8), mat(color), s * 0.12, 0.42, 0.05); w.rotation.z = s * Math.PI / 2; } add(sph(0.05), mat(color), 0, 0.42, 0.05); }
  if (kind === 'sunhat') { add(new THREE.CylinderGeometry(0.62, 0.62, 0.03, 20), mat('#f2d27a'), 0, 0.3, 0); add(new THREE.CylinderGeometry(0.3, 0.36, 0.24, 16), mat('#f2d27a'), 0, 0.42, 0); add(new THREE.CylinderGeometry(0.365, 0.365, 0.06, 16), mat(color), 0, 0.34, 0); }
  if (kind === 'chef') { add(new THREE.CylinderGeometry(0.3, 0.28, 0.25, 14), mat('#ffffff'), 0, 0.4, 0); const p = add(sph(0.33, 14, 10), mat('#ffffff'), 0, 0.6, 0); p.scale.y = 0.75; }
  if (kind === 'flowerCrown') { for (let n = 0; n < 9; n++) { const a = n / 9 * Math.PI * 2; add(sph(0.065, 8, 6), mat(COLORS.flowers[n % 5]), Math.cos(a) * 0.36, 0.3, Math.sin(a) * 0.36); } }
  if (kind === 'captain') { add(new THREE.CylinderGeometry(0.4, 0.38, 0.22, 16), mat('#ffffff'), 0, 0.38, 0); add(new THREE.CylinderGeometry(0.39, 0.39, 0.07, 16), mat('#2f3f6a'), 0, 0.3, 0); const v = add(new THREE.CylinderGeometry(0.25, 0.25, 0.03, 12, 1, false, 0, Math.PI), mat('#2f3f6a'), 0, 0.28, 0.25); v.rotation.y = Math.PI / 2; add(new THREE.OctahedronGeometry(0.05), mat(COLORS.gold), 0, 0.4, 0.4); }
  if (kind === 'crown') { add(new THREE.CylinderGeometry(0.24, 0.24, 0.16, 8, 1, true), mat(COLORS.gold, { side: THREE.DoubleSide }), 0, 0.45, 0); for (let n = 0; n < 5; n++) { const a = n / 5 * Math.PI * 2; add(new THREE.ConeGeometry(0.05, 0.12, 5), mat(COLORS.gold), Math.cos(a) * 0.23, 0.58, Math.sin(a) * 0.23); } add(sph(0.04), mat('#ff5a8a'), 0, 0.46, 0.24); }
  if (kind === 'goggles') { const band = add(new THREE.TorusGeometry(0.41, 0.03, 6, 24), mat('#6a4a3a'), 0, 0.2, 0); band.rotation.x = Math.PI / 2 - 0.3; for (const s of [-1, 1]) { const l = add(new THREE.CylinderGeometry(0.09, 0.09, 0.07, 12), mat('#c9a06e'), s * 0.13, 0.3, 0.33); l.rotation.x = Math.PI / 2 - 0.5; const gl = add(sph(0.07, 8, 6), mat('#8fe0ff', { emissive: '#3fa9d6', emissiveIntensity: 0.3 }), s * 0.13, 0.31, 0.37); gl.scale.z = 0.4; } }
  return g;
}

export function createCharacter(appearance, opts = {}) {
  const root = new THREE.Group();
  root.name = opts.name || 'character';
  const rig = new THREE.Group(); root.add(rig);
  const parts = {};
  const canvas = typeof document !== 'undefined' ? document.createElement('canvas') : null;
  if (canvas) { canvas.width = 512; canvas.height = 256; }
  const faceTex = canvas ? new THREE.CanvasTexture(canvas) : null;
  if (faceTex) { faceTex.colorSpace = THREE.SRGBColorSpace; faceTex.anisotropy = 4; }
  const face = { eyeShape: 'round', eyeColor: '#333', mouth: 'smile', mood: 'neutral', blink: 0, talking: false, talkOpen: false };
  const self = {
    root, rig, parts, face, appearance: null,
    action: null, actionT: 0, hold: null, speed: 0, airborne: false, t: Math.random() * 10, nextBlink: 2 + Math.random() * 3,
    moodTimer: 0, staffVisible: false, emoteObj: null,
  };
  function redrawFace() { if (!canvas) return; drawFace(canvas.getContext('2d'), face); faceTex.needsUpdate = true; }
  function build(a) {
    a = sanitizeAppearance(a);
    self.appearance = a;
    while (rig.children.length) rig.remove(rig.children[0]);
    const skin = mat(a.skin), top = mat(a.topColor), bottom = mat(a.bottomColor), shoes = mat(a.shoesColor);
    const body = new THREE.Group(); body.name = 'body'; rig.add(body); parts.body = body;
    // Legs
    for (const s of [-1, 1]) {
      const hip = new THREE.Group(); hip.position.set(s * 0.1, 0.34, 0); body.add(hip);
      const legMat = a.bottom === 'shorts' || a.bottom === 'skirt' || a.bottom === 'dress' ? skin : bottom;
      const leg = mesh(cap(0.075, 0.16), legMat); leg.position.y = -0.14; hip.add(leg);
      const shoe = mesh(sph(0.1, 10, 8), shoes); shoe.scale.set(0.9, a.shoes === 'boots' ? 1.0 : 0.6, 1.3); shoe.position.set(0, -0.29, 0.03); hip.add(shoe);
      if (a.shoes === 'boots') { const cuff = mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.12, 10), shoes); cuff.position.y = -0.21; hip.add(cuff); }
      parts[s < 0 ? 'legL' : 'legR'] = hip;
    }
    // Torso
    const torso = mesh(sph(0.22, 14, 12), a.top === 'overalls' ? bottom : top); torso.scale.set(1, 1.05, 0.88); torso.position.y = 0.5; body.add(torso);
    if (a.bottom === 'shorts' || a.bottom === 'pants') { const hips = mesh(sph(0.2, 12, 8, 0, Math.PI * 2, Math.PI * 0.5, Math.PI * 0.5), bottom); hips.position.y = 0.42; hips.scale.set(1, 0.8, 0.88); body.add(hips); }
    if (a.bottom === 'skirt') { const sk = mesh(new THREE.CylinderGeometry(0.2, 0.3, 0.2, 14), bottom); sk.position.y = 0.36; body.add(sk); }
    if (a.bottom === 'dress') { const dr = mesh(new THREE.CylinderGeometry(0.19, 0.34, 0.36, 16), top); dr.position.y = 0.38; body.add(dr); }
    if (a.top === 'overalls') { const bib = mesh(roundedBox(0.26, 0.2, 0.08, 0.03), bottom); bib.position.set(0, 0.58, 0.17); body.add(bib); const shirt = mesh(sph(0.205, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.4), top); shirt.position.y = 0.52; body.add(shirt); }
    if (a.top === 'tunic') { const belt = mesh(new THREE.TorusGeometry(0.205, 0.03, 6, 16), mat('#8b5a3c')); belt.rotation.x = Math.PI / 2; belt.position.y = 0.44; body.add(belt); }
    if (a.top === 'jacket') { for (const s of [-1, 1]) { const lap = mesh(new THREE.BoxGeometry(0.06, 0.26, 0.05), mat('#ffffff')); lap.position.set(s * 0.05, 0.53, 0.19); lap.rotation.z = s * 0.2; body.add(lap); } }
    if (a.top === 'sailor') { const col = mesh(new THREE.CylinderGeometry(0.17, 0.24, 0.07, 14), mat('#2f5fa8')); col.position.y = 0.66; body.add(col); const tie = mesh(new THREE.ConeGeometry(0.05, 0.12, 4), mat('#e85d75')); tie.position.set(0, 0.6, 0.2); tie.rotation.x = Math.PI; body.add(tie); }
    if (a.top === 'sweater') { const hem = mesh(new THREE.TorusGeometry(0.19, 0.035, 6, 16), top); hem.rotation.x = Math.PI / 2; hem.position.y = 0.33; body.add(hem); }
    // Arms
    for (const s of [-1, 1]) {
      const sh = new THREE.Group(); sh.position.set(s * 0.22, 0.62, 0); body.add(sh);
      const arm = mesh(cap(0.058, 0.16), a.top === 'tee' || a.top === 'overalls' ? skin : top); arm.position.y = -0.12; arm.rotation.z = s * 0.15; sh.add(arm);
      const hand = mesh(sph(0.07, 10, 8), skin); hand.position.set(s * 0.03, -0.26, 0); hand.name = 'hand'; sh.add(hand);
      parts[s < 0 ? 'armL' : 'armR'] = sh;
    }
    const staff = makeStaff(); staff.position.set(0.03, -0.26, 0.02); staff.rotation.x = 0.2; staff.visible = self.staffVisible; parts.armR.add(staff); parts.staff = staff;
    // Head
    const head = new THREE.Group(); head.position.y = 0.7; body.add(head); parts.head = head;
    const skull = mesh(sph(HEAD_R, 24, 18), skin); skull.position.y = HEAD_R * 0.92; head.add(skull);
    if (faceTex) {
      const faceMesh = new THREE.Mesh(sph(HEAD_R * 1.005, 24, 18), new THREE.MeshBasicMaterial({ map: faceTex, transparent: true, depthWrite: false }));
      faceMesh.position.copy(skull.position); faceMesh.renderOrder = 2; head.add(faceMesh);
    }
    for (const s of [-1, 1]) { const ear = mesh(sph(0.07, 8, 6), skin); ear.position.set(s * HEAD_R * 0.98, HEAD_R * 0.9, 0); ear.scale.set(0.6, 1, 0.8); head.add(ear); }
    const hairG = buildHair(a.hair, a.hairColor); hairG.position.y = HEAD_R * 0.92; head.add(hairG);
    if (a.hat !== 'none') { const h = buildHat(a.hat, a.hatColor); h.position.y = HEAD_R * 0.92; head.add(h); }
    if (a.accessory === 'glasses') for (const s of [-1, 1]) { const r = mesh(new THREE.TorusGeometry(0.075, 0.014, 6, 16), mat('#3a3a4a')); r.position.set(s * 0.14, HEAD_R * 0.7, HEAD_R * 0.95); head.add(r); }
    if (a.accessory === 'beard') { const b = mesh(sph(0.26, 12, 8, 0, Math.PI * 2, Math.PI * 0.45, Math.PI * 0.55), mat(a.hairColor)); b.position.set(0, HEAD_R * 0.62, 0.1); b.scale.set(1, 1, 0.9); head.add(b); }
    if (a.accessory === 'scarf') { const sc = mesh(new THREE.TorusGeometry(0.17, 0.06, 8, 16), mat(a.hatColor)); sc.rotation.x = Math.PI / 2; sc.position.y = 0.68; body.add(sc); }
    if (a.accessory === 'backpack') { const bp = mesh(roundedBox(0.3, 0.32, 0.16, 0.06), mat(a.hatColor)); bp.position.set(0, 0.52, -0.25); body.add(bp); }
    if (a.accessory === 'bowtie') for (const s of [-1, 1]) { const w = mesh(new THREE.ConeGeometry(0.05, 0.1, 6), mat('#e85d75')); w.rotation.z = s * Math.PI / 2; w.position.set(s * 0.05, 0.66, 0.19); body.add(w); }
    face.eyeShape = a.eyeShape; face.eyeColor = a.eyeColor; face.mouth = a.mouth;
    redrawFace();
    root.traverse(o => { if (o.isMesh && o.material?.map !== faceTex) o.castShadow = true; });
  }
  build(appearance);
  if (opts.scale) root.scale.setScalar(opts.scale);

  self.setAppearance = a => build(a);
  self.showStaff = v => { self.staffVisible = v; if (parts.staff) parts.staff.visible = v; };
  self.setMood = (mood, seconds = 0) => { face.mood = mood; self.moodTimer = seconds; redrawFace(); };
  self.setTalking = v => { face.talking = v; if (!v) { face.talkOpen = false; redrawFace(); } };
  self.play = (name, holdState = false) => {
    if (holdState) { self.hold = name; self.action = null; return; }
    self.action = name; self.actionT = 0;
    if (name === 'celebrate' || name === 'clap') self.setMood('happy', ACTION_LENGTH[name]);
    if (name === 'surprised') self.setMood('surprised', 1.2);
  };
  self.stopHold = () => { self.hold = null; };
  self.headWorldPos = (out = new THREE.Vector3()) => parts.head.localToWorld(out.set(0, HEAD_R * 0.92, 0));

  self.update = (dt, { speed = 0, airborne = false } = {}) => {
    self.t += dt;
    const t = self.t, P = parts;
    // Blink + mood timers
    self.nextBlink -= dt;
    if (self.nextBlink < 0) { face.blink = 1; redrawFace(); self.nextBlink = 2.5 + Math.random() * 3; setTimeout(() => { face.blink = 0; redrawFace(); }, 120); }
    if (self.moodTimer > 0) { self.moodTimer -= dt; if (self.moodTimer <= 0) { face.mood = 'neutral'; redrawFace(); } }
    if (face.talking) { const open = Math.sin(t * 18) > 0.2; if (open !== face.talkOpen) { face.talkOpen = open; redrawFace(); } }
    // Reset pose
    P.body.position.set(0, 0, 0); P.body.rotation.set(0, 0, 0); P.head.rotation.set(0, 0, 0);
    for (const k of ['armL', 'armR', 'legL', 'legR']) P[k].rotation.set(0, 0, 0);
    const walk = Math.min(1, speed);
    if (walk > 0.05) {
      const f = t * (8 + speed * 4);
      P.legL.rotation.x = Math.sin(f) * 0.8 * walk; P.legR.rotation.x = -Math.sin(f) * 0.8 * walk;
      P.armL.rotation.x = -Math.sin(f) * 0.7 * walk; P.armR.rotation.x = Math.sin(f) * 0.7 * walk;
      P.body.position.y = Math.abs(Math.sin(f)) * 0.07 * walk;
      P.body.rotation.z = Math.sin(f) * 0.05 * walk;
      P.head.rotation.z = -Math.sin(f) * 0.05 * walk;
    } else {
      P.body.position.y = Math.sin(t * 2.2) * 0.012;
      P.head.rotation.z = Math.sin(t * 0.9) * 0.04;
      P.armL.rotation.z = -0.1 - Math.sin(t * 2.2) * 0.03; P.armR.rotation.z = 0.1 + Math.sin(t * 2.2) * 0.03;
    }
    if (airborne) { P.legL.rotation.x = 0.5; P.legR.rotation.x = -0.3; P.armL.rotation.z = -1.2; P.armR.rotation.z = 1.2; }
    // Held poses
    const h = self.hold;
    if (h === 'sit') { P.body.position.y = -0.2; P.legL.rotation.x = P.legR.rotation.x = -1.4; P.armL.rotation.x = P.armR.rotation.x = -0.3; }
    if (h === 'sleep') { P.body.position.y = -0.24; P.legL.rotation.x = P.legR.rotation.x = -1.4; P.head.rotation.x = 0.35; P.head.rotation.z = 0.25; }
    if (h === 'cast') { P.armR.rotation.x = -1.3; P.armL.rotation.x = -1.1; P.armL.rotation.z = 0.4; }
    if (h === 'reel') { P.armR.rotation.x = -1.0 + Math.sin(t * 14) * 0.15; P.armL.rotation.x = -1.0; P.armL.rotation.z = 0.4; P.body.rotation.x = -0.12; }
    if (h === 'build') { P.armR.rotation.x = -2.6 + Math.sin(t * 3) * 0.12; P.armR.rotation.z = 0.2; P.armL.rotation.z = -0.5 - Math.sin(t * 3) * 0.1; }
    if (h === 'work') { P.armR.rotation.x = -0.9 + Math.sin(t * 7) * 0.5; P.armL.rotation.x = -0.6; P.body.rotation.x = 0.1; }
    if (h === 'garden') { P.body.rotation.x = 0.3; P.armL.rotation.x = P.armR.rotation.x = -0.9 + Math.sin(t * 4) * 0.2; }
    if (h === 'read') { P.armL.rotation.x = P.armR.rotation.x = -1.1; P.armL.rotation.z = 0.35; P.armR.rotation.z = -0.35; P.head.rotation.x = 0.25; }
    if (h === 'talk') { P.armR.rotation.x = -0.4 + Math.sin(t * 3) * 0.3; P.armR.rotation.z = 0.35; P.head.rotation.y = Math.sin(t * 1.3) * 0.12; }
    // One-shot actions
    if (self.action) {
      self.actionT += dt;
      const len = ACTION_LENGTH[self.action] || 1, p = self.actionT / len, s = Math.sin(p * Math.PI);
      switch (self.action) {
        case 'wave': P.armR.rotation.z = 2.6; P.armR.rotation.x = Math.sin(self.actionT * 12) * 0.35; P.head.rotation.z = 0.12; break;
        case 'clap': P.armL.rotation.x = P.armR.rotation.x = -1.3; P.armL.rotation.z = 0.5 + Math.abs(Math.sin(self.actionT * 14)) * -0.5; P.armR.rotation.z = -0.5 - Math.abs(Math.sin(self.actionT * 14)) * -0.5; P.body.position.y += Math.abs(Math.sin(self.actionT * 7)) * 0.05; break;
        case 'celebrate': P.body.position.y += Math.abs(Math.sin(self.actionT * 6)) * 0.35; P.armL.rotation.z = -2.7; P.armR.rotation.z = 2.7; P.armL.rotation.x = P.armR.rotation.x = Math.sin(self.actionT * 12) * 0.2; P.body.rotation.y = self.actionT * 3.4; break;
        case 'surprised': P.body.position.y += s * 0.25; P.armL.rotation.z = -1.5 * s; P.armR.rotation.z = 1.5 * s; break;
        case 'nod': P.head.rotation.x = Math.sin(p * Math.PI * 4) * 0.25; break;
        case 'shrug': P.armL.rotation.z = -0.9 * s; P.armR.rotation.z = 0.9 * s; P.head.rotation.z = 0.2 * s; break;
        case 'chop': case 'mine': P.armR.rotation.x = -2.8 + p * 3.2; P.armL.rotation.x = -2.4 + p * 2.8; P.body.rotation.x = 0.25 * s; break;
        case 'dig': P.body.rotation.x = 0.45 * s; P.armR.rotation.x = -0.6 - s; P.armL.rotation.x = -0.6 - s; break;
        case 'build': P.armR.rotation.x = -2.8 * s; P.body.position.y += 0.08 * s; break;
        case 'feed': P.armR.rotation.x = -1.2 * s; P.body.rotation.x = 0.3 * s; break;
      }
      if (p >= 1) self.action = null;
    }
    if (self.staffVisible && P.staff) { const star = P.staff.getObjectByName('star'); star.rotation.y = t * 2; star.material.emissiveIntensity = 0.7 + Math.sin(t * 4) * 0.3; }
  };
  return self;
}
