// Story controller: quests, conversations, rewards, friendship, Kingdom Harmony and world reactions.
import * as THREE from 'three';
import { QuestEngine } from '../systems/quests.js';
import { buildConversation, questLines, topicLines, fill } from '../systems/dialogue.js';
import { pathAcross, roomChecklist } from '../systems/validate.js';
import { QUEST, QUESTS } from '../data/quests.js';
import { NPC } from '../data/npcs.js';
import { PIECE, PIECES } from '../data/pieces.js';
import { RESOURCES } from '../data/resources.js';
import { HARMONY_UNLOCKS, nextUnlock, unlocksBetween } from '../data/harmony.js';
import { ZONES, NAV_NODES } from '../data/village-layout.js';
import { LABELS } from '../data/appearance.js';
import { banner, toast } from '../ui/dom.js';

export const HOME_NEEDS = [
  { any: ['woodWall', 'windowWall'], count: 3, label: 'Walls (3)' },
  { any: ['doorWall'], label: 'A door' },
  { any: ['roof'], label: 'A roof' },
  { any: ['bed'], label: 'A bed' },
];
export const WORKSHOP_NEEDS = [
  { any: ['workbench'], label: 'A workbench' },
  { any: ['chair', 'sofa', 'bench'], label: 'Something to sit on' },
  { any: ['lamp', 'poweredLamp', 'streetlight'], label: 'A lamp' },
  { any: ['cabinet', 'bookshelf'], label: 'A shelf or cabinet' },
  { recolored: true, label: 'Recolour a piece (T)' },
];
const zone = id => ZONES.find(z => z.id === id);

export class Story {
  constructor(game) {
    this.game = game;
    this.checks = {
      bridge: () => this.pathOk('bridge'),
      dock: () => this.pathOk('dock'),
      workshop: () => roomChecklist(zone('workshop'), game.state.placements, WORKSHOP_NEEDS).every(r => r.ok),
      home: () => roomChecklist(zone('plot'), game.state.placements, HOME_NEEDS).every(r => r.ok),
      fountain: () => !!game.mech.fed.fountain,
      lamp: () => game.mech.lamps.size > 0,
    };
    this.engine = new QuestEngine(game.state, this.checks);
    game.bus.on('gain', ({ items }) => this.handle(this.engine.onGain(items)));
    game.bus.on('build', ev => {
      if (ev.action === 'place') this.firstOfKind(ev.pl.id);
      this.handle(this.engine.refresh());
    });
    this.busy = false;
  }
  attach(state) { this.engine.state = state; }
  pathOk(id) {
    const z = zone(id);
    const r = pathAcross(z, this.game.walk);
    if (r.ok) this.game.state.crossings = { ...(this.game.state.crossings || {}), [id]: r.path };
    return r.ok;
  }
  event(name, n = 1) { this.handle(this.engine.onEvent(name, n)); }
  handle(list) {
    for (const x of list || []) {
      if (x.ready) {
        const f = x.quest.objectives.find(o => o.final);
        toast(`📜 ${x.quest.title}: ${f.text}`, 'good', 4);
        this.game.sfx('objective');
      } else if (x.objective) { toast(`✔ ${x.objective.text}`, 'good', 3); this.game.sfx('objective'); }
    }
    this.game.renderTracker();
  }
  markerFor(npcId) {
    if (this.engine.turnInsFor(npcId).length) return 'ready';
    if (this.engine.offersFor(npcId).length) return 'offer';
    return null;
  }

  // ---- Conversations ----
  async talk(agent) {
    if (this.busy) return;
    this.busy = true;
    const g = this.game, s = g.state, ui = g.dialogue, def = agent.def;
    const ctx = () => ({ engine: this.engine, flags: s.flags, name: s.name, sleepy: agent.activity === 'sleep', seed: Math.floor(s.time.total / 7) + def.id.length });
    g.enterDialogue(agent);
    const rel = (s.relationships[def.id] ||= { hearts: 0, talkedDay: 0, gifts: [] });
    try {
      if (rel.talkedDay !== s.time.day) { rel.talkedDay = s.time.day; this.addHearts(def.id, 1, false); }
      let conv = buildConversation(def, ctx());
      for (const q of conv.turnIns) await this.completeQuest(q.id, agent);
      conv = buildConversation(def, ctx());
      if (conv.mainOffer) await this.offer(conv.mainOffer.id, agent);
      let greeted = false;
      for (;;) {
        conv = buildConversation(def, ctx());
        if (conv.turnIns.length) { for (const q of conv.turnIns) await this.completeQuest(q.id, agent); continue; }
        if (!greeted) { await ui.say([conv.greeting]); greeted = true; }
        else ui.setText('Anything else?');
        const choice = await ui.choose(conv.options);
        if (choice.kind === 'bye') { await ui.say([{ text: ['See you around!', 'Bye-bye!', 'Take care, {name}!'].map(t => fill(t, ctx()))[Math.floor(Math.random() * 3)], anim: 'wave' }]); break; }
        if (choice.kind === 'offer') await this.offer(choice.id, agent);
        if (choice.kind === 'progress') await ui.say(questLines(choice.id, 'progress', ctx()).concat(this.progressSummary(choice.id)));
        if (choice.kind === 'topic') await ui.say(topicLines(def, choice.id, ctx()));
      }
      await this.giveGifts(agent);
    } finally {
      g.exitDialogue();
      this.busy = false;
    }
  }
  progressSummary(qid) {
    const q = QUEST[qid];
    const left = q.objectives.filter(o => !this.engine.objective(qid, o).done && !o.final);
    if (!left.length) return [];
    return [`Still to do: ${left.map(o => { const st = this.engine.objective(qid, o); return st.need > 1 && o.kind !== 'harmony' ? `${o.text} (${st.have}/${st.need})` : o.text; }).join('; ')}.`];
  }
  async offer(qid, agent) {
    const g = this.game, ui = g.dialogue, q = QUEST[qid], ctx = { name: g.state.name };
    await ui.say(questLines(qid, 'offer', ctx), { anim: q.main ? 'wave' : undefined });
    const c = await ui.choose([{ label: `✨ ${q.dialogue.acceptLabel || 'I\'ll help!'}`, kind: 'yes', quest: true }, { label: q.dialogue.declineLabel || 'Not right now', kind: 'no' }]);
    if (c.kind === 'yes') {
      await ui.say([{ text: c.label.replace('✨ ', ''), player: true }]);
      this.accept(qid, agent);
      await ui.say(questLines(qid, 'accept', ctx), { mood: 'happy' });
    } else await ui.say(questLines(qid, 'decline', ctx));
  }
  accept(qid, agent) {
    const g = this.game, eff = this.engine.accept(qid);
    if (!eff) return;
    for (const f of eff.flags || []) g.setFlag(f);
    if (eff.items) g.give(eff.items, { quiet: false });
    if (eff.blueprints) this.unlockBlueprints(eff.blueprints, null, true);
    banner('Quest Accepted!', QUEST[qid].title);
    g.sfx('accept');
    agent?.character.play('clap');
    this.handle(this.engine.refresh());
    if (qid === 'tool') { g.playerChar.showStaff(true); g.effects.magic(new THREE.Vector3(g.player.pos.x, g.player.pos.y, g.player.pos.z)); toast('You received the Starforge Tool! Press B to build.', 'good', 4); }
    g.build.refreshPlan();
    g.renderTracker();
    g.autosave('quest');
  }
  async completeQuest(qid, agent) {
    const g = this.game, ui = g.dialogue, q = QUEST[qid];
    agent.character.play('celebrate');
    await ui.say(questLines(qid, 'complete', { name: g.state.name }), { mood: 'happy' });
    const rewards = this.engine.complete(qid);
    const lines = [];
    if (rewards.harmony) lines.push(`+${rewards.harmony} 💖 Harmony`);
    for (const [k, n] of Object.entries(rewards.items || {})) lines.push(`+${n} ${RESOURCES[k].icon} ${RESOURCES[k].name}`);
    for (const b of rewards.blueprints || []) lines.push(`📐 ${PIECE[b].name}`);
    for (const c of rewards.clothes || []) lines.push(`👗 ${LABELS[c] || c}`);
    banner('Quest Complete!', q.title, lines, 4.2);
    g.sfx('fanfare');
    g.playerChar.play('celebrate');
    g.effects.sparkle(new THREE.Vector3(g.player.pos.x, g.player.pos.y + 1.5, g.player.pos.z), { count: 40, spread: 1.5 });
    if (rewards.items) g.give(rewards.items, { quiet: true });
    if (rewards.blueprints) this.unlockBlueprints(rewards.blueprints, null, true);
    if (rewards.clothes) this.unlockClothes(rewards.clothes, true);
    for (const f of rewards.flags || []) g.setFlag(f);
    this.addHearts(q.giver, 2, false);
    if (rewards.harmony) this.addHarmony(rewards.harmony, q.title);
    g.onQuestCompleted(qid);
    this.handle(this.engine.refresh());
    g.renderTracker();
    g.autosave('quest');
  }
  async giveGifts(agent) {
    const g = this.game, def = agent.def, rel = g.state.relationships[def.id];
    for (const gift of def.gifts || []) {
      if (rel.hearts < gift.hearts || rel.gifts.includes(gift.hearts)) continue;
      rel.gifts.push(gift.hearts);
      g.enterDialogue(agent);
      await g.dialogue.say([{ text: fill(gift.line, { name: g.state.name }), mood: 'happy', anim: 'clap' }]);
      g.exitDialogue();
      if (gift.items) g.give(gift.items);
      if (gift.blueprint) this.unlockBlueprints([gift.blueprint], `${def.name}'s gift`);
      banner('A gift!', `from ${def.name}`);
    }
  }
  addHearts(npcId, n, announce = true) {
    const s = this.game.state, rel = (s.relationships[npcId] ||= { hearts: 0, talkedDay: 0, gifts: [] });
    const before = rel.hearts;
    rel.hearts = Math.min(10, rel.hearts + n);
    if (rel.hearts > before) {
      const agent = this.game.npcs.byId[npcId];
      if (agent) this.game.effects.hearts(new THREE.Vector3(agent.pos.x, agent.pos.y + 1.6, agent.pos.z), rel.hearts - before + 1);
      if (announce) toast(`${NPC[npcId].name} likes you more! ♥ ${rel.hearts}`);
      this.game.dialogue.open && this.game.dialogue.updateHearts();
    }
  }

  // ---- Rewards ----
  unlockBlueprints(ids, source = null, quiet = false) {
    const s = this.game.state, fresh = ids.filter(id => !s.blueprints.includes(id));
    if (!fresh.length) { if (source) this.game.give({ spark: 8 }); return; }
    s.blueprints.push(...fresh); s.newBlueprints.push(...fresh);
    if (!quiet) toast(`📐 New blueprint${fresh.length > 1 ? 's' : ''}: ${fresh.map(id => PIECE[id].name).join(', ')}`, 'good', 3.5);
    if (source && !quiet) banner('New Blueprint!', `${fresh.map(id => PIECE[id].name).join(', ')} — from a ${source}`);
    this.game.sfx('unlock');
    if (this.game.build.active) this.game.build.render();
  }
  unlockClothes(ids, quiet = false) {
    const s = this.game.state, fresh = ids.filter(id => !s.lockedClothesOwned.includes(id));
    s.lockedClothesOwned.push(...fresh);
    if (fresh.length && !quiet) toast(`👗 New outfit piece: ${fresh.map(c => LABELS[c] || c).join(', ')} — try it at your wardrobe!`, 'good', 3.5);
  }
  addHarmony(n, reason = '') {
    const s = this.game.state, before = s.harmony;
    s.harmony += n;
    this.game.renderHarmony(true);
    for (const u of unlocksBetween(before, s.harmony)) this.applyUnlock(u);
    this.handle(this.engine.refresh());
  }
  applyUnlock(u) {
    const g = this.game;
    if (u.blueprints) this.unlockBlueprints(u.blueprints, null, true);
    if (u.clothes) this.unlockClothes(u.clothes, true);
    if (u.allBlueprints) this.unlockBlueprints(PIECES.map(p => p.id), null, true);
    if (u.id === 'plot') g.build.rebuildGrid();
    setTimeout(() => { banner('Harmony Milestone!', `${u.at} 💖 ${u.title}`, [u.desc], 4); g.sfx('unlock'); }, 1800);
    g.state.unlocksSeen.push(u.id);
  }
  firstOfKind(id) {
    const s = this.game.state;
    s.stats.types = s.stats.types || [];
    if (s.stats.types.includes(id)) return;
    s.stats.types.push(id);
    this.addHarmony(1, `first ${PIECE[id].name}`);
    toast(`First ${PIECE[id].name}! +1 💖 Harmony`, '', 2);
  }
  blueprintHint(id) { return this.engine.blueprintHint(id); }

  // Checklist shown in build mode for a quest zone.
  buildGoals(z) {
    if (!z) return null;
    const s = this.game.state;
    const active = q => s.quests[q]?.status === 'active';
    if (z.id === 'bridge' && active('bridge')) return { title: 'Orchard Bridge', hint: 'Planks reach 2 tiles from a bank or post.', items: [{ label: 'Continuous walkable path from bank to bank', ok: this.checks.bridge() }] };
    if (z.id === 'dock' && active('dock')) return { title: 'Harbor Dock', hint: 'The old pilings hold planks up.', items: [{ label: 'Planks from the shore to the mooring post', ok: this.checks.dock() }] };
    if (z.id === 'workshop' && active('workshop')) return { title: "Bram's Workshop", items: roomChecklist(z, s.placements, WORKSHOP_NEEDS).map(r => ({ label: r.label, ok: r.ok })) };
    if (z.id === 'plaza' && active('fountain')) {
      const m = this.game.mech;
      const wheel = s.placements.some(p => p.id === 'waterwheel' && m.sources.has(p.uid));
      return { title: 'Garden Fountain', hint: 'Fountain inlet: east side, by the plaza edge.', items: [{ label: 'Waterwheel turning in the channel', ok: wheel }, { label: 'Pump next to water, powered', ok: m.pumps.size > 0 }, { label: 'Water reaches the fountain inlet', ok: !!m.fed.fountain }] };
    }
    return null;
  }
  // Where should the player go next for the tracked quest?
  trackedTarget() {
    const s = this.game.state;
    const qid = s.tracked && s.quests[s.tracked]?.status === 'active' ? s.tracked : this.engine.active()[0]?.id;
    if (!qid) {
      const offer = QUESTS.find(q => q.main && this.engine.canOffer(q.id));
      if (offer) { const a = this.game.npcs.byId[offer.giver]; return a?.present ? { x: a.pos.x, z: a.pos.z, label: `${NPC[offer.giver].name} has a request` } : null; }
      return null;
    }
    const step = this.engine.nextStep(qid);
    if (!step) return null;
    if (step.npc) { const a = this.game.npcs.byId[step.npc]; return a ? { x: a.pos.x, z: a.pos.z, label: step.objective.text } : null; }
    if (step.hint) return { ...step.hint, label: step.objective.text };
    return null;
  }
}
export { HARMONY_UNLOCKS, nextUnlock, NAV_NODES };
