// Shared colours and cel-shaded materials for the cartoon-diorama look.
import * as THREE from 'three';

export const COLORS = {
  grass: '#8fd16a', grass2: '#76c25a', grass3: '#a6dc74', sand: '#f0dfae', path: '#e8cf9a', plaza: '#e9dccb',
  dirt: '#c9a27a', wood: '#c98a55', woodDark: '#9a6238', stone: '#cfc8bd', stoneDark: '#a39c92', water: '#5fcde4',
  leaf: '#5cb85c', leaf2: '#7ccc5a', pine: '#3f9a6a', trunk: '#8b5a3c', white: '#ffffff', gold: '#ffd35c', star: '#fff2a8',
  flowers: ['#ff7aa8', '#ffd84a', '#ffffff', '#b98cff', '#ff9a52'],
};

let gradient = null;
function toonGradient() {
  if (gradient) return gradient;
  const data = new Uint8Array([120, 120, 120, 255, 190, 190, 190, 255, 255, 255, 255, 255]);
  gradient = new THREE.DataTexture(data, 3, 1, THREE.RGBAFormat);
  gradient.minFilter = gradient.magFilter = THREE.NearestFilter;
  gradient.needsUpdate = true;
  return gradient;
}
const cache = new Map();
// Cached toon material by colour (shared, so do not mutate; use `uniqueMat` for per-object tweaks).
export function mat(color, opts = {}) {
  const key = `${color}|${JSON.stringify(opts)}`;
  if (!cache.has(key)) cache.set(key, uniqueMat(color, opts));
  return cache.get(key);
}
export function uniqueMat(color, opts = {}) {
  const { flatShading, ...rest } = opts;
  return new THREE.MeshToonMaterial({ color, gradientMap: toonGradient(), ...rest });
}
export function mesh(geo, material, { shadow = true, receive = true } = {}) {
  const m = new THREE.Mesh(geo, material);
  m.castShadow = shadow; m.receiveShadow = receive;
  return m;
}
// Rounded box via a beveled ExtrudeGeometry-free approach: scaled sphere-ish capsule corners are costly,
// so use a box with a small bevel made from RoundedBox logic.
export function roundedBox(w, h, d, r = 0.08, seg = 2) {
  const geo = new THREE.BoxGeometry(w, h, d, seg + 2, seg + 2, seg + 2);
  const pos = geo.attributes.position, v = new THREE.Vector3();
  const hw = w / 2 - r, hh = h / 2 - r, hd = d / 2 - r;
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    const c = new THREE.Vector3(Math.max(-hw, Math.min(hw, v.x)), Math.max(-hh, Math.min(hh, v.y)), Math.max(-hd, Math.min(hd, v.z)));
    const dlt = v.clone().sub(c);
    if (dlt.lengthSq() > 0) v.copy(c.add(dlt.normalize().multiplyScalar(r)));
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  geo.computeVertexNormals();
  return geo;
}
