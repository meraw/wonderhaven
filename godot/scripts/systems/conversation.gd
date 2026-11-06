class_name Conversation
## What an NPC says and which choices you get, from the game state.

static func fill(text: String, player_name: String) -> String: return text.replace("{name}", player_name)

## Returns {turn_ins, main_offer, greeting, options: [{label, kind, id, quest?}]}
## `first_meeting`: you've never talked to them; a villager with an `intro` line greets you with it.
static func build(npc: Dictionary, engine: QuestEngine, flags: Dictionary, player_name: String, sleepy: bool = false, seed: int = 0, first_meeting: bool = false) -> Dictionary:
	var turn_ins := engine.turn_ins_for(npc.id)
	var offers := engine.offers_for(npc.id)
	var main_offer := {}
	for q in offers:
		if q.get("main", false): main_offer = q; break
	var lines: Array
	if sleepy and npc.has("sleepy"): lines = npc.sleepy
	else:
		lines = npc.greetings.back().lines
		for g in npc.greetings:
			if not g.has("flag") or flags.get(g.flag, false): lines = g.lines; break
	var greeting := fill(lines[absi(seed) % lines.size()], player_name)
	if first_meeting and npc.has("intro") and not sleepy: greeting = fill(String(npc.intro), player_name)
	var options: Array = []
	for pm in engine.payments_for(npc.id):
		var o: Dictionary = pm.objective
		var cost: Array = o.items.keys().map(func(k): return "%d %s" % [int(o.items[k]), Data.resources[k].name.to_lower()])
		options.append({"label": "💰 " + String(o.get("label", "Hand over " + ", ".join(cost))), "kind": "pay", "id": pm.quest.id, "obj": o.id, "quest": true})
	for q in offers:
		if q != main_offer: options.append({"label": "✨ Request: %s" % q.title, "kind": "offer", "id": q.id, "quest": true})
	for q in engine.active():
		if q.giver == npc.id and not turn_ins.has(q): options.append({"label": "📜 About: %s" % q.title, "kind": "progress", "id": q.id})
	for q in engine.later_for(npc.id):   # a request they'd ask at another time of day
		options.append({"label": "🕒 %s (%s)" % [q.title, Clock.hours_text(q.hours)], "kind": "later", "id": q.id})
	for t in npc.topics:
		if not t.has("requires") or flags.get(t.requires, false): options.append({"label": "💬 " + t.label, "kind": "topic", "id": t.id})
	if Shop.is_open(engine.state, npc.id): options.append({"label": "🛍 " + Shop.def(npc.id).get("label", "Let's trade"), "kind": "shop"})
	if Shop.can_gift(engine.state, npc.id): options.append({"label": "🎁 Give a gift", "kind": "gift"})
	options.append({"label": "Goodbye!", "kind": "bye"})
	return {"turn_ins": turn_ins, "main_offer": main_offer, "greeting": greeting, "options": options}

static func quest_lines(qid: String, key: String, player_name: String) -> Array:
	return Data.quest(qid).dialogue.get(key, []).map(func(l): return fill(l, player_name))

static func topic_lines(npc: Dictionary, id: String, player_name: String) -> Array:
	for t in npc.topics:
		if t.id == id: return t.lines.map(func(l): return fill(l, player_name))
	return []
