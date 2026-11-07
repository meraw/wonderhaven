class_name Story
extends RefCounted
## Quests, conversations, rewards, friendship, Kingdom Harmony and the build-mode checklists.

var game
var engine: QuestEngine
var busy := false

func _init(g) -> void:
	game = g
	engine = QuestEngine.new(game.state, {
		"bridge": func(): return path_ok("bridge"), "dock": func(): return path_ok("dock"),
		"fountain": func(): return game.mech.fed.get("fountain", false), "lamp": func(): return not game.mech.lamps.is_empty(),
		# "fed:<machine>": water or power delivered to a machine target in the layout (a lighthouse's drive, a clock);
		# "path:<zone>": a walkable path across a build zone, from its endpoint a to b (a bridge, a slipway);
		# "sealed:<zone>": a wall across a zone that keeps water from getting through (Validate.sealed)
		"*": func(name: String) -> bool:
			if name.begins_with("fed:"): return game.mech.fed.get(name.substr(4), false)
			if name.begins_with("path:"): return path_ok(name.substr(5))
			if name.begins_with("sealed:"): return Validate.sealed(Data.zone(name.substr(7)), game.state.placements).sealed
			return false})
	engine.gate = func(qid: String) -> bool: return Tutorial.allows_offer(game.state.get("tutorial", {}), qid)
	game.game_event.connect(_on_event)

func attach(state: Dictionary) -> void: engine.state = state; engine.invalidate()

func _on_event(type: String, data: Dictionary) -> void:
	if type == "gain": handle(engine.on_gain(data.items))
	if type == "rode": event("ride"); event("ride:" + String(data.to))   # a ride between stops, and where to
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
		if x.has("objective"): _on_done(x.objective)
		if x.has("ready"):
			for o in x.quest.objectives:
				if o.get("final", false): game.toast("📜 %s: %s" % [x.quest.title, o.text], "good", 4.0)
			game.sfx("objective")
		elif x.has("objective"): game.toast("✔ " + x.objective.text, "good", 3.0); game.sfx("objective")
	if not list.is_empty(): game.build.refresh_plan()   # the next step's plan, if it has one
	game.hud.render_tracker()

## Effects of finishing one step of a request (onDone in quests.json): flags, items, blueprints, and weather
## ({type, hours}: that weather for a while, a storm on the night the levee is tested, say).
func _on_done(o: Dictionary) -> void:
	var eff: Dictionary = o.get("onDone", {})
	if eff.is_empty(): return
	for f in eff.get("flags", []): game.set_flag(f)
	if eff.has("items"): game.give(_ints(eff.items))
	if eff.has("blueprints"): unlock_blueprints(eff.blueprints)
	if eff.has("weather"): Daylight.force(game.state, String(eff.weather.type), float(eff.weather.get("hours", 6)))   # a storm for the finale
	if eff.has("flags"): game.build.rebuild_grid()

func marker_for(npc: String) -> String:
	if not engine.turn_ins_for(npc).is_empty(): return "ready"
	for q in engine.active():   # a step of a request you took on waits at this villager (talk to them, or pay them)
		var st := engine.next_step(q.id)
		if not st.is_empty() and st.get("npc", "") == npc and not st.objective.get("final", false): return "ready"
	if not engine.offers_for(npc).is_empty(): return "offer"
	return ""

func _conv(agent, first_meeting: bool = false) -> Dictionary:
	return Conversation.build(agent.def, engine, game.state.flags, game.state.name, agent.activity == "sleep", int(game.state.time.total / 7.0) + agent.def.id.length(), first_meeting)

func talk(agent) -> void:
	if busy: return
	busy = true
	game.emit_event("talk", {"npc": agent.def.id})
	var ui: DialogueUI = game.dialogue
	var s: Dictionary = game.state
	game.enter_dialogue(agent)
	if not s.relationships.has(agent.def.id): s.relationships[agent.def.id] = {"hearts": 0, "talked_day": 0, "gifts": []}
	var rel: Dictionary = s.relationships[agent.def.id]
	var met := bool(rel.get("met", int(rel.talked_day) > 0))   # talked to them before (saves from before "met" count a talk day)
	rel.met = true
	if rel.talked_day != s.time.day: rel.talked_day = s.time.day; add_hearts(agent.def.id, 1)
	# a request step that was "talk to me": they explain the next part
	var talked := engine.on_talk(agent.def.id)
	for x in talked:
		if x.has("objective") and x.objective.get("npc", "") == agent.def.id and x.objective.has("lines"):
			await ui.say(x.objective.lines.map(func(l): return Conversation.fill(l, s.name)))
	handle(talked)
	var conv := _conv(agent, not met)
	for q in conv.turn_ins: await complete_quest(q.id, agent)
	conv = _conv(agent, not met)
	if not conv.main_offer.is_empty(): await offer(conv.main_offer.id, agent, met); met = true
	var greeted := false
	var shop := false
	while true:
		conv = _conv(agent, not met and not greeted)
		if not conv.turn_ins.is_empty():
			for q in conv.turn_ins: await complete_quest(q.id, agent)
			continue
		if not greeted: await ui.say([conv.greeting]); greeted = true
		else: ui.set_text("Anything else?")
		var choice: Dictionary = await ui.choose(conv.options)
		if choice.kind == "bye":   # just ends: no parting line to click through
			agent.character.play("wave")
			break
		match choice.kind:
			"offer": await offer(choice.id, agent, true)
			"progress": await ui.say(Conversation.quest_lines(choice.id, "progress", s.name) + progress_summary(choice.id))
			"topic": await ui.say(Conversation.topic_lines(agent.def, choice.id, s.name))
			"gift": await gift(agent)
			"later":
				var lq := Data.quest(choice.id)
				await ui.say([Conversation.fill(lq.dialogue.get("later", "Come back %s and I'll tell you all about it!" % Clock.hours_text(lq.hours)), s.name)])
			"pay": await pay(choice.id, choice.obj, agent)
			"shop":
				await ui.say([{"text": Conversation.fill(Shop.def(agent.def.id).get("greet", "Have a look!"), s.name), "anim": "wave"}])
				shop = true
		if shop: break
	await give_gifts(agent)
	game.exit_dialogue()
	busy = false
	if game.rebuild_pending: game.rebuild_world()   # the conversation changed the place (Game.request_rebuild)
	if shop: game.panels.shop(agent.def.id)

## A "pay" step: hand over coins or items; the villager reacts with the objective's lines.
func pay(qid: String, oid: String, agent) -> void:
	var ui: DialogueUI = game.dialogue
	var r := engine.pay(qid, oid)
	if not r.ok:
		var short: Array = r.missing.map(func(m): return Money.lire(m.need) + " more" if m.id == "coins" else "%d more %s" % [m.need, Data.resources[m.id].name.to_lower()])
		await ui.say([{"text": "Ah, not quite enough yet. You'll need %s." % " and ".join(short), "mood": "sad"}])
		return
	game.render_resources()
	game.sfx("unlock")
	var o := {}
	for x in Data.quest(qid).objectives:
		if x.id == oid: o = x
	if o.has("lines"): await ui.say(o.lines.map(func(l): return {"text": Conversation.fill(l, game.state.name), "mood": "happy"}))
	handle(r.newly)

## Pick something from your bag to give; treats and things they love count for more.
func gift(agent) -> void:
	var ui: DialogueUI = game.dialogue
	var npc: Dictionary = agent.def
	var opts: Array = Shop.gift_options(game.state, npc).map(func(id): return {"label": "%s %s (%d)" % [Data.resources[id].icon, Data.resources[id].name, int(game.state.inventory.get(id, 0))], "kind": "item", "id": id})
	opts.append({"label": "Never mind", "kind": "no"})
	ui.set_text("🎁 What would you like to give %s? (One gift a day. Treats and favourite things mean the most.)" % npc.name.split(" ")[0])
	var c: Dictionary = await ui.choose(opts)
	if c.kind != "item": return
	var r := Shop.give_gift(game.state, npc, c.id)
	if not r.ok: return
	game.render_resources()
	var lines: Array = Data.shops.get("giftLines", {}).get("loved" if r.loved else "nice", ["Thank you!"])
	var thanks := {"text": Conversation.fill(String(lines[randi() % lines.size()]).replace("{item}", Data.resources[c.id].name), game.state.name), "mood": "happy"}
	if r.loved: thanks["anim"] = "clap"
	await ui.say([thanks])
	add_hearts(npc.id, int(r.hearts))
	game.sfx("objective")
	game.emit_event("gift", {"npc": npc.id, "item": c.id})

func progress_summary(qid: String) -> Array:
	var left: Array = []
	for o in Data.quest(qid).objectives:
		var st := engine.objective(qid, o)
		if not engine.is_current(qid, o) or st.done: continue   # this step only; later ones are a surprise
		left.append(("%s (%d/%d)" % [o.text, st.have, st.need]) if st.need > 1 and o.kind != "harmony" else o.text)
	return [] if left.is_empty() else ["Still to do: %s." % "; ".join(left)]

## `met`: you've talked to them before, so an offer that opens with introductions uses its `offerMet` lines instead.
func offer(qid: String, agent, met: bool = true) -> void:
	var ui: DialogueUI = game.dialogue
	var q := Data.quest(qid)
	var key := "offerMet" if met and q.dialogue.has("offerMet") else "offer"
	await ui.say(Conversation.quest_lines(qid, key, game.state.name), {"anim": "wave"} if q.get("main", false) else {})
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
	game.render_resources()   # what this request has you collect gets a chip
	if qid == "tool":
		game.player_char.show_staff(true)
		game.toast("You opened your Geometra's kit! Press %s to build." % Controls.key_label("build"), "good", 4.0)
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
	var where := Data.quest_island(qid)
	var lines: Array = []
	if r.get("harmony", 0) > 0: lines.append("+%d 💖 approval" % int(r.harmony))
	if r.get("meter", 0) > 0: lines.append(LocationMeter.reward_text(LocationMeter.def(where), int(r.meter)))
	for k in r.get("items", {}): lines.append("+" + Money.amount(k, int(r.items[k])))
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
	WorkDay.note(game.state, "quests", String(q.id))
	if r.get("harmony", 0) > 0: add_harmony(int(r.harmony))
	if r.get("meter", 0) > 0 or not LocationMeter.waiting(game.state, where).is_empty(): add_meter(where, int(r.get("meter", 0)))
	game.on_quest_completed(qid)
	handle(engine.refresh())
	game.render_resources()
	game.autosave("quest", true)

func give_gifts(agent) -> void:
	var rel: Dictionary = game.state.relationships[agent.def.id]
	for gift in agent.def.get("gifts", []):
		if rel.hearts < gift.hearts or rel.gifts.has(int(gift.hearts)): continue
		rel.gifts.append(int(gift.hearts))
		await game.dialogue.say([{"text": Conversation.fill(gift.line, game.state.name), "mood": "happy", "anim": "clap"}])
		if gift.has("items"): game.give(_ints(gift.items))
		if gift.has("blueprint"): unlock_blueprints([gift.blueprint], "%s's gift" % agent.def.name)
		if gift.has("clothes"): unlock_clothes(gift.clothes)
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
	if n > 0: game.emit_event("harmony", {"n": n})
	for u in Harmony.between(before, s.harmony): apply_unlock(u)
	handle(engine.refresh())

## Points on a location's own meter (LocationMeter), and the milestones they reach. A milestone that waits for
## something ("requires": the front page waits for the finale) comes when that's done, if you have the points.
func add_meter(island: String, n: int) -> void:
	var m := LocationMeter.def(island)
	var due: Array = LocationMeter.add(game.state, island, n).filter(func(u): return LocationMeter.requirements_met(game.state, u))
	for u in LocationMeter.waiting(game.state, island):
		if not due.has(u): due.append(u)
	for u in due:
		if u.has("blueprints"): unlock_blueprints(u.blueprints, "", true)
		if u.has("clothes"): unlock_clothes(u.clothes, true)
		if u.has("items"): game.give(_ints(u.items), null, true)
		for f in u.get("flags", []): game.set_flag(f)
		var mu: Dictionary = u
		game.get_tree().create_timer(1.8).timeout.connect(func(): game.banner("%s %s" % [m.get("icon", "📈"), m.get("name", "Milestone")], "%s  %s" % [LocationMeter.reading(m, int(mu.at)), mu.title], [mu.desc], 4.0); game.sfx("unlock"))
		game.state.unlocks_seen.append(u.get("id", ""))
	if not due.is_empty(): game.build.rebuild_grid()   # a build site there may grow with the meter
	game.hud.render_harmony()
	handle(engine.refresh())

func apply_unlock(u: Dictionary) -> void:
	if u.has("blueprints"): unlock_blueprints(u.blueprints, "", true)
	if u.has("clothes"): unlock_clothes(u.clothes, true)
	if u.get("allBlueprints", false): unlock_blueprints(Data.pieces.map(func(p): return p.id), "", true)
	if u.id == "plot": game.build.rebuild_grid()
	game.get_tree().create_timer(1.8).timeout.connect(func(): game.banner("Approval milestone!", "%d 💖 %s" % [int(u.at), u.title], [u.desc], 4.0); game.sfx("unlock"))
	game.state.unlocks_seen.append(u.id)

func first_of_kind(id: String) -> void:
	var types: Array = game.state.stats.types
	if types.has(id): return
	types.append(id)
	add_harmony(1)
	game.toast("First %s! +1 💖 approval" % Data.piece(id).name, "", 2.0)

## The build-mode checklist for a zone: the active request that builds here, its current step's items, and what
## is still to do before its building step (materials first) if that hasn't come up yet.
func build_goals(z: Dictionary) -> Dictionary:
	if z.is_empty(): return {}
	for q in engine.active().filter(func(x): return engine.here(x.id)):
		var cur := engine.current_stage(q.id)
		var here: Array = q.objectives.filter(func(o): return o.get("zone", "") == z.id and not o.get("final", false))
		if here.is_empty(): continue
		var items: Array = []
		var hint := ""
		# materials and other steps that come before building here
		var first_build := 1 << 30
		for o in here: first_build = mini(first_build, QuestEngine.stage_of(o))
		if cur < first_build:
			# not this step yet: what to do first, then one line for the building to come
			for o in q.objectives:
				if engine.is_current(q.id, o) and not engine.objective(q.id, o).done:
					var st := engine.objective(q.id, o)
					items.append({"label": o.text + (" (%d/%d)" % [st.have, st.need] if st.need > 1 else ""), "ok": false})
			items.append({"label": "Then: " + String(here[0].text), "ok": false, "later": true})
			return {"title": q.title, "hint": "First:", "items": items}
		for o in here:
			if QuestEngine.stage_of(o) > cur: continue
			if o.has("buildHint") and hint == "": hint = o.buildHint
			items.append_array(_zone_items(q.id, o))
		return {"title": q.title, "hint": hint, "items": items} if hint != "" else {"title": q.title, "items": items}
	return {}

func _zone_items(qid: String, o: Dictionary) -> Array:
	var st := engine.objective(qid, o)
	var drafts := Drafts.of(game.state)
	match o.kind:
		"room":
			var rows := Validate.room_checklist(Data.zone(o.zone), game.state.placements, o.needs)
			var planned := Validate.room_checklist(Data.zone(o.zone), Drafts.design(game.state.placements, drafts), o.needs)
			var out: Array = []
			for i in rows.size():
				var r: Dictionary = rows[i]
				var ok: bool = r.ok or st.done
				var drafted: bool = not ok and i < planned.size() and planned[i].ok
				out.append({"label": r.label + ("" if r.ok or int(r.get("count", 1)) <= 1 else " (%d/%d)" % [r.have, int(r.count)]) + (" (drafted)" if drafted else ""), "ok": ok})
			return out
		"pieces":
			var in_draft := 0 if st.done else Validate.pieces_in_zone(Data.zone(o.zone), drafts).filter(func(pl): return o.any.has(pl.id)).size()
			return [{"label": o.text + ("" if st.done else " (%d/%d)" % [st.have, st.need]) + ((" +%d drafted" % in_draft) if in_draft > 0 else ""), "ok": st.done}]
		"build":
			if o.check == "fountain":
				var m: Dictionary = game.mech
				var wheel: bool = game.state.placements.any(func(p): return p.id == "waterwheel" and m.sources.has(p.uid))
				return [{"label": "Waterwheel turning in the channel", "ok": wheel}, {"label": "Pump next to water, powered", "ok": not m.pumps.is_empty()}, {"label": "Water reaches the fountain inlet", "ok": m.fed.get("fountain", false)}]
			return [{"label": o.get("goal", o.text), "ok": st.done}]
	return [{"label": o.text, "ok": st.done}]

func tracked_target() -> Dictionary:
	var s: Dictionary = game.state
	if not engine.tracked_valid(): engine.retrack()
	var t: String = s.tracked
	if t == "": return {}
	if not engine.here(t.trim_prefix("lead:")): return {}   # a request on another island: no compass here
	if t.begins_with("lead:"):
		var q := Data.quest(t.trim_prefix("lead:"))
		var a = game.npcs.get(q.giver)
		return {"x": a.pos.x, "z": a.pos.z, "label": "%s has a request" % a.def.name} if a and a.present else {}
	var step := engine.next_step(t)
	if step.is_empty(): return {}
	if step.get("npc", "") != "":
		var a = game.npcs.get(step.npc)
		return {"x": a.pos.x, "z": a.pos.z, "label": step.objective.text} if a else {}
	if step.objective.get("kind", "") == "gather":
		var n: Dictionary = game.actions.nearest_ready(step.objective.get("item", ""))   # nearest place to get it right now
		if not n.is_empty(): return {"x": n.x, "z": n.z, "label": step.objective.text}
	var h: Dictionary = step.get("hint", {})
	return {"x": h.x, "z": h.z, "label": step.objective.text} if not h.is_empty() else {}
