// Small DOM helpers shared by every UI module.
export const $ = id => document.getElementById(id);
export function el(tag, attrs = {}, ...children) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k === 'class') e.className = v;
    else if (k === 'style' && typeof v === 'object') Object.assign(e.style, v);
    else if (k.startsWith('on') && typeof v === 'function') e.addEventListener(k.slice(2), v);
    else if (k === 'html') e.innerHTML = v;
    else if (v === true) e.setAttribute(k, '');
    else if (v !== false && v != null) e.setAttribute(k, v);
  }
  for (const c of children.flat()) if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(String(c)));
  return e;
}
export function toast(text, kind = '', life = 2.6) {
  const t = el('div', { class: `toast ${kind}`, style: { '--life': `${life}s` } }, text);
  $('toasts').append(t);
  setTimeout(() => t.remove(), (life + 0.5) * 1000);
  while ($('toasts').children.length > 5) $('toasts').firstChild.remove();
}
let bannerTimer = null;
export function banner(title, sub = '', rewards = [], seconds = 3.2) {
  const b = $('banner');
  b.innerHTML = '';
  b.append(el('div', { class: 'b-title' }, title));
  if (sub) b.append(el('div', {}, el('div', { class: 'b-sub' }, sub)));
  if (rewards.length) b.append(el('div', { class: 'b-rewards' }, rewards.map(r => el('span', { class: 'reward' }, r))));
  b.hidden = false; b.style.animation = 'none'; void b.offsetWidth; b.style.animation = '';
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => { b.hidden = true; }, seconds * 1000);
}
export function setPrompt(html) {
  const p = $('prompt');
  if (!html) { p.hidden = true; return; }
  if (p.dataset.html !== html) { p.innerHTML = html; p.dataset.html = html; }
  p.hidden = false;
}
export function fade(on) { $('fade').classList.toggle('on', on); }
