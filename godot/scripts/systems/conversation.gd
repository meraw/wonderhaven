class_name Conversation
## What an NPC says and which choices you get, from the game state.

static func fill(text: String, player_name: String) -> String: return text.replace("{name}", player_name)

## Returns {turn_ins, main_offer, greeting, options: [{label, kind, id, quest?}]}
static func build(npc: Dictionary, engine: QuestEngine, flags: Dictionary, player_name: String, sleepy: bool = false, seed: int = 0) -> Dictionary:
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
	var options: Array = []
	for q in offers:
		if q != main_offer: options.append({"label": "✨ Request: %s" % q.title, "kind": "offer", "id": q.id, "quest": true})
	for q in engine.active():
		if q.giver == npc.id and not turn_ins.has(q): options.append({"label": "📜 About: %s" % q.title, "kind": "progress", "id": q.id})
	for t in npc.topics:
		if not t.has("requires") or flags.get(t.requires, false): options.append({"label": "💬 " + t.label, "kind": "topic", "id": t.id})
	options.append({"label": "Goodbye!", "kind": "bye"})
	return {"turn_ins": turn_ins, "main_offer": main_offer, "greeting": greeting, "options": options}

static func quest_lines(qid: String, key: String, player_name: String) -> Array:
	return Data.quest(qid).dialogue.get(key, []).map(func(l): return fill(l, player_name))

static func topic_lines(npc: Dictionary, id: String, player_name: String) -> Array:
	for t in npc.topics:
		if t.id == id: return t.lines.map(func(l): return fill(l, player_name))
	return []
