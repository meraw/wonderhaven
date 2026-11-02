// Builds what an NPC says and which choices you get, from the game state. Pure.
import { QUEST } from '../data/quests.js';

export const fill = (text, ctx) => text.replace(/\{name\}/g, ctx.name || 'friend');
function pick(lines, seed) { return lines[Math.abs(seed) % lines.length]; }

// Returns { turnIns: [quest], mainOffer: quest|null, greeting: string, options: [{ label, kind, id }] }
export function buildConversation(npc, ctx) {
  const { engine, flags, sleepy, seed = 0 } = ctx;
  const turnIns = engine.turnInsFor(npc.id);
  const offers = engine.offersFor(npc.id);
  const mainOffer = offers.find(q => q.main) || null;
  let greeting;
  if (sleepy && npc.sleepy) greeting = pick(npc.sleepy, seed);
  else {
    const g = npc.greetings.find(g => !g.flag || flags[g.flag]) || npc.greetings[npc.greetings.length - 1];
    greeting = pick(g.lines, seed);
  }
  const options = [];
  for (const q of offers.filter(q => q !== mainOffer)) options.push({ label: `✨ Need any help? (${q.title})`, kind: 'offer', id: q.id, quest: true });
  for (const q of engine.active().filter(q => q.giver === npc.id && !turnIns.includes(q))) options.push({ label: `📜 About “${q.title}”…`, kind: 'progress', id: q.id });
  for (const t of npc.topics) if (!t.requires || flags[t.requires]) options.push({ label: `💬 ${t.label}`, kind: 'topic', id: t.id });
  options.push({ label: 'Goodbye!', kind: 'bye' });
  return { turnIns, mainOffer, greeting: fill(greeting, ctx), options };
}
export function questLines(qid, key, ctx) { return (QUEST[qid].dialogue[key] || []).map(l => fill(l, ctx)); }
export function topicLines(npc, id, ctx) { return (npc.topics.find(t => t.id === id)?.lines || []).map(l => fill(l, ctx)); }
