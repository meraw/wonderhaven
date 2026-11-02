// Copies the game into dist/ as a static site (no bundler needed).
import { cp, mkdir, rm } from 'node:fs/promises';
await rm('dist', { recursive: true, force: true });
await mkdir('dist/node_modules/three/build', { recursive: true });
await cp('index.html', 'dist/index.html');
await cp('src', 'dist/src', { recursive: true });
for (const file of ['three.module.js', 'three.core.js']) await cp('node_modules/three/build/' + file, 'dist/node_modules/three/build/' + file);
await cp('node_modules/three/LICENSE', 'dist/node_modules/three/LICENSE');
// Sanity check: every module imports resolve from the copied tree.
const { readdir, readFile, access } = await import('node:fs/promises');
const { join, dirname, resolve } = await import('node:path');
async function walk(dir) { const out = []; for (const e of await readdir(dir, { withFileTypes: true })) { const p = join(dir, e.name); if (e.isDirectory()) out.push(...await walk(p)); else if (p.endsWith('.js')) out.push(p); } return out; }
let missing = 0;
for (const file of await walk('dist/src')) {
  const src = await readFile(file, 'utf8');
  for (const m of src.matchAll(/^\s*import\s[^'"]*['"](\.[^'"]+)['"]/gm)) {
    try { await access(resolve(dirname(file), m[1])); } catch { console.error(`Missing import ${m[1]} in ${file}`); missing++; }
  }
}
if (missing) { console.error(`${missing} missing import(s)`); process.exit(1); }
console.log('Built Wonderhaven in dist/');
