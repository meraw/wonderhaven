// Terrain mesh built from the shared heightfield, with painted vertex colours for grass, paths, sand and plaza.
import * as THREE from 'three';
import { terrainHeight, WATER_Y, CHANNEL } from '../systems/heightfield.js';
import { distToPaths } from '../systems/world-statics.js';
import { SQUARE } from '../data/village-layout.js';
import { COLORS } from './palette.js';
import { makeRng } from '../core/rng.js';

export function createTerrain() {
  const size = 124, seg = 186;
  const geo = new THREE.PlaneGeometry(size, size, seg, seg);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const c = new THREE.Color(), grass = new THREE.Color(COLORS.grass), grass2 = new THREE.Color(COLORS.grass2), grass3 = new THREE.Color(COLORS.grass3);
  const sand = new THREE.Color(COLORS.sand), path = new THREE.Color(COLORS.path), plaza = new THREE.Color(COLORS.plaza), bed = new THREE.Color('#d8c08e'), stone = new THREE.Color('#bdb5a8');
  const rng = makeRng(3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const h = terrainHeight(x, z);
    pos.setY(i, h);
    const n = Math.sin(x * 0.35) * Math.cos(z * 0.29) * 0.5 + 0.5;
    c.copy(grass).lerp(grass2, n * 0.6).lerp(grass3, Math.max(0, Math.sin(x * 0.11 + z * 0.07)) * 0.35);
    c.offsetHSL(0, 0, (rng() - 0.5) * 0.03);
    if (h < 0.12) c.lerp(sand, Math.min(1, (0.12 - h) * 3));
    if (h < WATER_Y) c.copy(bed);
    const dp = distToPaths(x, z);
    if (dp < 1.25 && h > -0.25) c.lerp(path, Math.min(1, (1.25 - dp) * 2.2));
    const ds = Math.hypot(x - SQUARE.x, z - SQUARE.z);
    if (ds < SQUARE.r) c.lerp(plaza, Math.min(1, (SQUARE.r - ds) * 1.5));
    if (x >= CHANNEL.minX - 0.3 && x <= CHANNEL.maxX && z >= CHANNEL.minZ - 0.3 && z <= CHANNEL.maxZ + 0.3) c.copy(stone);
    colors.set([c.r, c.g, c.b], i * 3);
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  const material = new THREE.MeshLambertMaterial({ vertexColors: true });
  const mesh = new THREE.Mesh(geo, material);
  mesh.receiveShadow = true;
  mesh.name = 'terrain';
  return mesh;
}

export function createWater() {
  const geo = new THREE.PlaneGeometry(420, 420, 1, 1);
  geo.rotateX(-Math.PI / 2);
  const material = new THREE.ShaderMaterial({
    transparent: true,
    uniforms: { uTime: { value: 0 }, uDeep: { value: new THREE.Color('#2fa9d6') }, uShallow: { value: new THREE.Color('#8fe7f2') }, uNight: { value: 0 } },
    vertexShader: `varying vec3 vW; void main(){ vec4 w = modelMatrix * vec4(position,1.0); vW = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader: `uniform float uTime; uniform vec3 uDeep; uniform vec3 uShallow; uniform float uNight; varying vec3 vW;
      float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
      float noise(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.0-2.0*f);
        return mix(mix(hash(i),hash(i+vec2(1,0)),u.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x), u.y); }
      void main(){
        float r = length(vW.xz);
        float shore = smoothstep(62.0, 46.0, r);
        vec3 col = mix(uDeep, uShallow, 0.35 + 0.4*shore);
        float n = noise(vW.xz*0.45 + vec2(uTime*0.25, uTime*0.18)) * noise(vW.xz*0.8 - vec2(uTime*0.2, 0.0));
        float sparkle = smoothstep(0.42, 0.6, n);
        col += vec3(1.0) * sparkle * 0.45;
        col = mix(col, col*vec3(0.35,0.45,0.8), uNight);
        gl_FragColor = vec4(col, 0.82);
        #include <colorspace_fragment>
      }`,
  });
  const mesh = new THREE.Mesh(geo, material);
  mesh.position.y = WATER_Y;
  mesh.renderOrder = 1;
  mesh.name = 'water';
  return mesh;
}

export function createSky() {
  const geo = new THREE.SphereGeometry(300, 32, 16);
  const material = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { uTop: { value: new THREE.Color('#6cc4ff') }, uBottom: { value: new THREE.Color('#d9f2ff') } },
    vertexShader: `varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
    fragmentShader: `uniform vec3 uTop; uniform vec3 uBottom; varying vec3 vP; void main(){ float t = smoothstep(-0.05, 0.6, vP.y); gl_FragColor = vec4(mix(uBottom, uTop, t), 1.0);
      #include <colorspace_fragment>
    }`,
  });
  const sky = new THREE.Mesh(geo, material);
  sky.name = 'sky';
  return sky;
}
