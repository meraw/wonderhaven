class_name Story
extends RefCounted
## Quests, conversations, rewards, friendship, Kingdom Harmony and the build-mode checklists.

const WORKSHOP_NEEDS := [
	{"any": ["workbench"], "label": "A workbench"}, {"any": ["chair", "sofa", "bench"], "label": "Something to sit on"},
	{"any": ["lamp", "poweredLamp", "streetlight"], "label": "A lamp"}, {"any": ["cabinet", "bookshelf"], "label": "A shelf or cabinet"},
	{"recolored": true, "label": "Recolour a piece (T)"}]

var game
var engine: QuestEngine
var busy := false

func _init(g) -> void:
	game = g
	engine = QuestEngine.new(game.state, {
		"bridge": func(): return path_ok("bridge"), "dock": func(): return path_ok("dock"),
		"workshop": func(): return Validate.room_checklist(Data.zone("workshop"), game.state.placements, WORKSHOP_NEEDS).all(func(r): return r.ok),
		"fountain": func(): return game.mech.fed.get("fountain", false), "lamp": func(): return not game.mech.lamps.is_empty()})
	game.game_event.connect(_on_event)

func attach(state: Dictionary) -> void: engine.state = state

func _on_event(type: String, data: Dictionary) -> void:
	if type == "gain": handle(engine.on_gain(data.items))
	if type == "build":
		if data.get("action", "") == "place": first_of_kind(data.pl.id)
		handle(engine.refresh())

func path_ok(id: String) -> bool:
	var r := Validate.path_across(Data.zone(id), game.walk)
	if r.ok: game.state.crossings[id] = r.path.map(func(c): return [c.x, c.y])
	return r.ok

func event(name: String, n: int = 1) -> void: handle(engine.on_event(name, n))

func handle(list: Array) -> void:
	for x in list:
		if x.has("ready"):
			for o in x.quest.objectives:
				if o.get("final", false): game.toast("📜 %s: %s" % [x.quest.title, o.text], "good", 4.0)
			game.sfx("objective")
		elif x.has("objective"): game.toast("✔ " + x.objective.text, "good", 3.0); game.sfx("objective")
	game.hud.render_tracker()

func marker_for(npc: String) -> String:
	if not engine.turn_ins_for(npc).is_empty(): return "ready"
	if not engine.offers_for(npc).is_empty(): return "offer"
	return ""

func _conv(agent) -> Dictionary:
	return Conversation.build(agent.def, engine, game.state.flags, game.state.name, agent.activity == "sleep", int(game.state.time.total / 7.0) + agent.def.id.length())

func talk(agent) -> void:
	if busy: return
	busy = true
	var ui: DialogueUI = game.dialogue
	var s: Dictionary = game.state
	game.enter_dialogue(agent)
	if not s.relationships.has(agent.def.id): s.relationships[agent.def.id] = {"hearts": 0, "talked_day": 0, "gifts": []}
	var rel: Dictionary = s.relationships[agent.def.id]
	if rel.talked_day != s.time.day: rel.talked_day = s.time.day; add_hearts(agent.def.id, 1)
	var conv := _conv(agent)
	for q in conv.turn_ins: await complete_quest(q.id, agent)
	conv = _conv(agent)
	if not conv.main_offer.is_empty(): await offer(conv.main_offer.id, agent)
	var greeted := false
	while true:
		conv = _conv(agent)
		if not conv.turn_ins.is_empty():
			for q in conv.turn_ins: await complete_quest(q.id, agent)
			continue
		if not greeted: await ui.say([conv.greeting]); greeted = true
		else: ui.set_text("Anything else?")
		var choice: Dictionary = await ui.choose(conv.options)
		if choice.kind == "bye":
			await ui.say([{"text": Conversation.fill(["See you around!", "Bye-bye!", "Take care, {name}!"][randi() % 3], s.name), "anim": "wave"}])
			break
		match choice.kind:
			"offer": await offer(choice.id, agent)
			"progress": await ui.say(Conversation.quest_lines(choice.id, "progress", s.name) + progress_summary(choice.id))
			"topic": await ui.say(Conversation.topic_lines(agent.def, choice.id, s.name))
	await give_gifts(agent)
	game.exit_dialogue()
	busy = false

func progress_summary(qid: String) -> Array:
	var left: Array = []
	for o in Data.quest(qid).objectives:
		var st := engine.objective(qid, o)
		if o.get("final", false) or st.done: continue
		left.append(("%s (%d/%d)" % [o.text, st.have, st.need]) if st.need > 1 and o.kind != "harmony" else o.text)
	return [] if left.is_empty() else ["Still to do: %s." % "; ".join(left)]

func offer(qid: String, agent) -> void:
	var ui: DialogueUI = game.dialogue
	var q := Data.quest(qid)
	await ui.say(Conversation.quest_lines(qid, "offer", game.state.name), {"anim": "wave"} if q.get("main", false) else {})
	var c: Dictionary = await ui.choose([{"label": "✨ " + q.dialogue.get("acceptLabel", "I'll help!"), "kind": "yes", "quest": true}, {"label": q.dialogue.get("declineLabel", "Not right now"), "kind": "no"}])
	if c.kind == "yes":
		await ui.say([{"text": c.label.trim_prefix("✨ "), "player": true}])
		accept(qid, agent)
		await ui.say(Conversation.quest_lines(qid, "accept", game.state.name), {"mood": "happy"})
	else:
		await ui.say(Conversation.quest_lines(qid, "decline", game.state.name))

func accept(qid: String, agent = null) -> void:
	var eff := engine.accept(qid)
	if not game.state.quests.has(qid): return
	for f in eff.get("flags", []): game.set_flag(f)
	if eff.has("items"): game.give(_ints(eff.items))
	if eff.has("blueprints"): unlock_blueprints(eff.blueprints, "", true)
	game.banner("Quest Accepted!", Data.quest(qid).title)
	game.sfx("accept")
	if agent: agent.character.play("clap")
	handle(engine.refresh())
	if qid == "tool":
		game.player_char.show_staff(true); game.effects.magic(game.player.pos)
		game.toast("You received the Starforge Tool! Press %s to build." % Controls.key_label("build"), "good", 4.0)
	game.build.refresh_plan()
	game.hud.render_tracker()
	game.autosave("quest", true)

func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d: out[k] = int(d[k])
	return out

func complete_quest(qid: String, agent) -> void:
	var ui: DialogueUI = game.dialogue
	var q := Data.quest(qid)
	agent.character.play("celebrate")
	await ui.say(Conversation.quest_lines(qid, "complete", game.state.name), {"mood": "happy"})
	var r := engine.complete(qid)
	var lines: Array = []
	if r.get("harmony", 0) > 0: lines.append("+%d 💖 Harmony" % int(r.harmony))
	for k in r.get("items", {}): lines.append("+%d %s %s" % [int(r.items[k]), Data.resources[k].icon, Data.resources[k].name])
	for b in r.get("blueprints", []): lines.append("📐 " + Data.piece(b).name)
	for c in r.get("clothes", []): lines.append("👗 " + Data.appearance.labels.get(c, c))
	game.banner("Quest Complete!", q.title, lines, 4.2)
	game.sfx("fanfare")
	game.player_char.play("celebrate")
	game.effects.sparkle(game.player.pos + Vector3(0, 1.5, 0), 40, Color("fff2a8"), 0.35)
	if r.has("items"): game.give(_ints(r.items), null, true)
	if r.has("blueprints"): unlock_blueprints(r.blueprints, "", true)
	if r.has("clothes"): unlock_clothes(r.clothes, true)
	for f in r.get("flags", []): game.set_flag(f)
	add_hearts(q.giver, 2)
	if r.get("harmony", 0) > 0: add_harmony(int(r.harmony))
	game.on_quest_completed(qid)
	handle(engine.refresh())
	game.autosave("quest", true)

func give_gifts(agent) -> void:
	var rel: Dictionary = game.state.relationships[agent.def.id]
	for gift in agent.def.get("gifts", []):
		if rel.hearts < gift.hearts or rel.gifts.has(int(gift.hearts)): continue
		rel.gifts.append(int(gift.hearts))
		await game.dialogue.say([{"text": Conversation.fill(gift.line, game.state.name), "mood": "happy", "anim": "clap"}])
		if gift.has("items"): game.give(_ints(gift.items))
		if gift.has("blueprint"): unlock_blueprints([gift.blueprint], "%s's gift" % agent.def.name)
		game.banner("A gift!", "from " + agent.def.name)

func add_hearts(npc: String, n: int) -> void:
	var s: Dictionary = game.state
	if not s.relationships.has(npc): s.relationships[npc] = {"hearts": 0, "talked_day": 0, "gifts": []}
	var rel: Dictionary = s.relationships[npc]
	var before := int(rel.hearts)
	rel.hearts = mini(10, before + n)
	if rel.hearts > before:
		var a = game.npcs.get(npc)
		if a: game.effects.hearts(a.pos + Vector3(0, 1.6, 0), rel.hearts - before + 1)
		if game.dialogue.open: game.dialogue.update_hearts()

func unlock_blueprints(ids: Array, source: String = "", quiet: bool = false) -> void:
	var s: Dictionary = game.state
	var fresh := ids.filter(func(id): return not s.blueprints.has(id))
	if fresh.is_empty():
		if source != "": game.give({"spark": 8})
		return
	s.blueprints.append_array(fresh); s.new_blueprints.append_array(fresh)
	var names := ", ".join(fresh.map(func(id): return Data.piece(id).name))
	if not quiet: game.toast("📐 New blueprint%s: %s" % ["s" if fresh.size() > 1 else "", names], "good", 3.5)
	if source != "" and not quiet: game.banner("New Blueprint!", "%s — from a %s" % [names, source])
	game.sfx("unlock")
	if game.build.active: game.build._build_ui()

func unlock_clothes(ids: Array, quiet: bool = false) -> void:
	var s: Dictionary = game.state
	var fresh := ids.filter(func(id): return not s.clothes_owned.has(id))
	s.clothes_owned.append_array(fresh)
	if not fresh.is_empty() and not quiet: game.toast("👗 New outfit piece: %s — try it at your wardrobe!" % ", ".join(fresh.map(func(c): return Data.appearance.labels.get(c, c))), "good", 3.5)

func add_harmony(n: int) -> void:
	var s: Dictionary = game.state
	var before := int(s.harmony)
	s.harmony = before + n
	game.hud.render_harmony()
	for u in Harmony.between(before, s.harmony): apply_unlock(u)
	handle(engine.refresh())

func apply_unlock(u: Dictionary) -> void:
	if u.has("blueprints"): unlock_blueprints(u.blueprints, "", true)
	if u.has("clothes"): unlock_clothes(u.clothes, true)
	if u.get("allBlueprints", false): unlock_blueprints(Data.pieces.map(func(p): return p.id), "", true)
	if u.id == "plot": game.build.rebuild_grid()
	game.get_tree().create_timer(1.8).timeout.connect(func(): game.banner("Harmony Milestone!", "%d 💖 %s" % [int(u.at), u.title], [u.desc], 4.0); game.sfx("unlock"))
	game.state.unlocks_seen.append(u.id)

func first_of_kind(id: String) -> void:
	var types: Array = game.state.stats.types
	if types.has(id): return
	types.append(id)
	add_harmony(1)
	game.toast("First %s! +1 💖 Harmony" % Data.piece(id).name, "", 2.0)

func build_goals(z: Dictionary) -> Dictionary:
	if z.is_empty(): return {}
	var active := func(q): return game.state.quests.get(q, {}).get("status", "") == "active"
	match z.id:
		"bridge":
			if active.call("bridge"): return {"title": "Orchard Bridge", "hint": "Planks reach 2 tiles from a bank or post.", "items": [{"label": "Continuous walkable path from bank to bank", "ok": path_ok("bridge")}]}
		"dock":
			if active.call("dock"): return {"title": "Harbor Dock", "hint": "The old pilings hold planks up.", "items": [{"label": "Planks from the shore to the mooring post", "ok": path_ok("dock")}]}
		"workshop":
			if active.call("workshop"): return {"title": "Bram's Workshop", "items": Validate.room_checklist(z, game.state.placements, WORKSHOP_NEEDS).map(func(r): return {"label": r.label, "ok": r.ok})}
		"plaza":
			if active.call("fountain"):
				var m: Dictionary = game.mech
				var wheel: bool = game.state.placements.any(func(p): return p.id == "waterwheel" and m.sources.has(p.uid))
				return {"title": "Garden Fountain", "hint": "Fountain inlet: east side, by the plaza edge.", "items": [{"label": "Waterwheel turning in the channel", "ok": wheel}, {"label": "Pump next to water, powered", "ok": not m.pumps.is_empty()}, {"label": "Water reaches the fountain inlet", "ok": m.fed.get("fountain", false)}]}
	return {}

func tracked_target() -> Dictionary:
	var s: Dictionary = game.state
	var qid: String = s.tracked if engine.status(s.tracked) == "active" else ""
	if qid == "" and not engine.active().is_empty(): qid = engine.active()[0].id
	if qid == "":
		for q in Data.quests:
			if q.get("main", false) and engine.can_offer(q.id):
				var a = game.npcs.get(q.giver)
				if a and a.present: return {"x": a.pos.x, "z": a.pos.z, "label": "%s has a request" % a.def.name}
		return {}
	var step := engine.next_step(qid)
	if step.is_empty(): return {}
	if step.get("npc", "") != "":
		var a = game.npcs.get(step.npc)
		return {"x": a.pos.x, "z": a.pos.z, "label": step.objective.text} if a else {}
	var h: Dictionary = step.get("hint", {})
	return {"x": h.x, "z": h.z, "label": step.objective.text} if not h.is_empty() else {}
