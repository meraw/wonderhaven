// Quest engine: offering, accepting, tracking objectives from events and live checks, turning in.
import { QUESTS, QUEST } from '../data/quests.js';
import { HARMONY_UNLOCKS } from '../data/harmony.js';
import { NPC, NPCS } from '../data/npcs.js';
import { NODES } from '../data/village-layout.js';

export class QuestEngine {
  // checks: { bridge: () => bool, workshop: () => bool, home: () => bool, fountain: () => bool, dock: () => bool, lamp: () => bool }
  constructor(state, checks = {}) { this.state = state; this.checks = checks; }
  rec(id) { return this.state.quests[id]; }
  status(id) { return this.rec(id)?.status; }
  isDone(id) { return this.status(id) === 'done'; }
  requirementsMet(q) {
    const r = q.requires || {};
    if (r.quests && !r.quests.every(id => this.isDone(id))) return false;
    if (r.harmony && this.state.harmony < r.harmony) return false;
    if (r.flags && !r.flags.every(f => this.state.flags[f])) return false;
    return true;
  }
  canOffer(id) { const q = QUEST[id]; return !!q && !this.rec(id) && this.requirementsMet(q); }
  offersFor(npcId) { return QUESTS.filter(q => q.giver === npcId && this.canOffer(q.id)); }
  active() { return QUESTS.filter(q => this.status(q.id) === 'active'); }
  done() { return QUESTS.filter(q => this.isDone(q.id)); }
  accept(id) {
    if (!this.canOffer(id)) return null;
    this.state.quests[id] = { status: 'active', progress: {}, acceptedAt: this.state.time?.total || 0 };
    if (!this.state.tracked || this.isDone(this.state.tracked)) this.state.tracked = id;
    return QUEST[id].onAccept || {};
  }
  objective(qid, obj) {
    const p = this.rec(qid)?.progress || {};
    const need = obj.count || 1;
    switch (obj.kind) {
      case 'gather': case 'event': {
        const before = obj.stat ? (this.state.stats?.[obj.stat] || 0) : 0;   // finite finds made before accepting still count
        const have = Math.min(need, Math.max(p[obj.id] || 0, before));
        return { done: have >= need, have, need };
      }
      case 'harmony': { const done = p[obj.id] === true || this.state.harmony >= obj.value; return { done, have: Math.min(this.state.harmony, obj.value), need: obj.value }; }
      case 'build': return { done: p[obj.id] === true || !!this.checks[obj.check]?.(), have: 0, need: 1 };
      case 'flag': return { done: p[obj.id] === true || !!this.state.flags[obj.flag], have: 0, need: 1 };
      case 'talk': return { done: p[obj.id] === true, have: 0, need: 1 };
    }
    return { done: false, have: 0, need };
  }
  isReady(qid) {
    const q = QUEST[qid];
    return this.status(qid) === 'active' && q.objectives.filter(o => !o.final).every(o => this.objective(qid, o).done);
  }
  // Latch live objectives and report the ones that just became complete.
  refresh() {
    const newly = [];
    for (const q of this.active()) {
      const rec = this.rec(q.id);
      for (const o of q.objectives) {
        if (o.final) continue;
        const was = rec.done?.[o.id];
        const st = this.objective(q.id, o);
        if (st.done && ['harmony', 'build', 'flag'].includes(o.kind)) rec.progress[o.id] = true;
        if (st.done && !was) { rec.done = { ...(rec.done || {}), [o.id]: true }; newly.push({ quest: q, objective: o }); }
      }
      if (this.isReady(q.id) && !rec.ready) { rec.ready = true; newly.push({ quest: q, ready: true }); }
    }
    return newly;
  }
  onGain(items) {
    for (const q of this.active()) for (const o of q.objectives) {
      if (o.kind === 'gather' && items[o.item] > 0) { const p = this.rec(q.id).progress; p[o.id] = Math.min(o.count, (p[o.id] || 0) + items[o.item]); }
    }
    return this.refresh();
  }
  onEvent(name, n = 1) {
    for (const q of this.active()) for (const o of q.objectives) {
      if (o.kind === 'event' && o.event === name) { const p = this.rec(q.id).progress; p[o.id] = Math.min(o.count, (p[o.id] || 0) + n); }
    }
    return this.refresh();
  }
  turnInsFor(npcId) {
    return this.active().filter(q => this.isReady(q.id) && q.objectives.some(o => o.final && o.kind === 'talk' && o.npc === npcId));
  }
  complete(qid) {
    const q = QUEST[qid]; const rec = this.rec(qid);
    if (!rec || rec.status !== 'active') return null;
    for (const o of q.objectives) if (o.final) rec.progress[o.id] = true;
    rec.status = 'done'; rec.completedAt = this.state.time?.total || 0;
    if (this.state.tracked === qid) this.state.tracked = this.active()[0]?.id || null;
    return q.rewards || {};
  }
  // The next thing to do for a quest, with a map location where possible.
  nextStep(qid) {
    const q = QUEST[qid];
    if (!q) return null;
    if (this.isReady(qid)) { const f = q.objectives.find(o => o.final); return { objective: f, npc: f?.npc }; }
    const o = q.objectives.find(o => !o.final && !this.objective(qid, o).done);
    return o ? { objective: o, hint: o.hint } : null;
  }
  blueprintHint(id) {
    for (const q of QUESTS) {
      if (q.onAccept?.blueprints?.includes(id)) return `Accept “${q.title}” from ${NPC[q.giver].name}`;
      if (q.rewards?.blueprints?.includes(id)) return `Complete “${q.title}” for ${NPC[q.giver].name}`;
    }
    const u = HARMONY_UNLOCKS.find(u => u.blueprints?.includes(id));
    if (u) return `Reach ${u.at} Kingdom Harmony`;
    const g = NPCS.find(n => n.gifts?.some(x => x.blueprint === id));
    if (g) return `Become good friends with ${g.name}`;
    if (NODES.some(n => n.blueprint === id)) return 'Hidden in a treasure chest somewhere on the island';
    return 'Reach 250 Kingdom Harmony';
  }
}
