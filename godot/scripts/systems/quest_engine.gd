class_name QuestEngine
extends RefCounted
## Quests: offering, accepting, tracking objectives from events and live checks, turning in.
## Objective kinds: gather, event, build, harmony, flag, talk (final ones unlock last). Collection objectives latch.

var state: Dictionary
var checks: Dictionary   # check id -> Callable returning bool
var gate := Callable()   # optional (quest id) -> bool: extra condition on offers (the guided first day uses it)

func _init(p_state: Dictionary, p_checks: Dictionary = {}) -> void:
	state = p_state; checks = p_checks

func rec(id: String) -> Dictionary: return state.quests.get(id, {})
func status(id: String) -> String: return rec(id).get("status", "")
func is_done(id: String) -> bool: return status(id) == "done"

func requirements_met(q: Dictionary) -> bool:
	var r: Dictionary = q.get("requires", {})
	for id in r.get("quests", []):
		if not is_done(id): return false
	if r.has("harmony") and state.harmony < r.harmony: return false
	for f in r.get("flags", []):
		if not state.flags.get(f, false): return false
	return true

func can_offer(id: String) -> bool:
	var q := Data.quest(id)
	return not q.is_empty() and not state.quests.has(id) and requirements_met(q) and (not gate.is_valid() or gate.call(id))
func offers_for(npc: String) -> Array: return Data.quests.filter(func(q): return q.giver == npc and can_offer(q.id))
func active() -> Array: return Data.quests.filter(func(q): return status(q.id) == "active")
func done() -> Array: return Data.quests.filter(func(q): return is_done(q.id))

## Main-story requests you could start now (someone is waiting to ask you). These are always shown, so the story
## never disappears behind a side request.
func story_leads() -> Array: return Data.quests.filter(func(q): return q.get("main", false) and can_offer(q.id))

## What the player follows: an active request id, "lead:<id>" for a story request not started yet, or "".
func tracked_valid() -> bool:
	var t: String = state.tracked
	if t.begins_with("lead:"): return can_offer(t.trim_prefix("lead:"))
	return status(t) == "active"

func accept(id: String) -> Dictionary:
	if not can_offer(id): return {}
	state.quests[id] = {"status": "active", "progress": {}, "done": {}}
	# picking up the story request you were heading for, or nothing tracked: follow the new request
	if state.tracked == "lead:" + id or not tracked_valid(): state.tracked = id
	return Data.quest(id).get("onAccept", {})

func objective(qid: String, o: Dictionary) -> Dictionary:
	var p: Dictionary = rec(qid).get("progress", {})
	var need := int(o.get("count", 1))
	match o.kind:
		"gather", "event":
			# a `stat` objective also counts finds made before accepting (chests don't come back)
			var before: int = int(state.get("stats", {}).get(o.stat, 0)) if o.has("stat") else 0
			var have := mini(need, maxi(int(p.get(o.id, 0)), before))
			return {"done": have >= need, "have": have, "need": need}
		"harmony": return {"done": p.get(o.id, 0) == 1 or state.harmony >= o.value, "have": mini(int(state.harmony), int(o.value)), "need": int(o.value)}
		"build":
			var c = checks.get(o.check)
			return {"done": p.get(o.id, 0) == 1 or (c != null and c.call()), "have": 0, "need": 1}
		"flag": return {"done": p.get(o.id, 0) == 1 or state.flags.get(o.flag, false), "have": 0, "need": 1}
		"talk": return {"done": p.get(o.id, 0) == 1, "have": 0, "need": 1}
	return {"done": false, "have": 0, "need": need}

func is_ready(qid: String) -> bool:
	if status(qid) != "active": return false
	for o in Data.quest(qid).objectives:
		if not o.get("final", false) and not objective(qid, o).done: return false
	return true

## Latch live objectives; report newly completed ones as [{quest, objective} | {quest, ready: true}].
func refresh() -> Array:
	var newly: Array = []
	for q in active():
		var r: Dictionary = state.quests[q.id]
		if not r.has("done"): r["done"] = {}
		for o in q.objectives:
			if o.get("final", false): continue
			var st := objective(q.id, o)
			if st.done and o.kind in ["harmony", "build", "flag"]: r.progress[o.id] = 1
			if st.done and not r.done.has(o.id): r.done[o.id] = true; newly.append({"quest": q, "objective": o})
		if is_ready(q.id) and not r.get("ready", false): r["ready"] = true; newly.append({"quest": q, "ready": true})
	return newly

func on_gain(items: Dictionary) -> Array:
	for q in active():
		for o in q.objectives:
			if o.kind == "gather" and items.get(o.item, 0) > 0:
				var p: Dictionary = state.quests[q.id].progress
				p[o.id] = mini(int(o.count), int(p.get(o.id, 0)) + int(items[o.item]))
	return refresh()

func on_event(name: String, n: int = 1) -> Array:
	for q in active():
		for o in q.objectives:
			if o.kind == "event" and o.event == name:
				var p: Dictionary = state.quests[q.id].progress
				p[o.id] = mini(int(o.count), int(p.get(o.id, 0)) + n)
	return refresh()

## After finishing something: head for the next story request first, then any active story request, then the rest.
func retrack() -> void:
	var leads := story_leads()
	var act := active()
	var main_act := act.filter(func(q): return q.get("main", false))
	if not main_act.is_empty(): state.tracked = main_act[0].id
	elif not leads.is_empty(): state.tracked = "lead:" + leads[0].id
	elif not act.is_empty(): state.tracked = act[0].id
	else: state.tracked = ""

func turn_ins_for(npc: String) -> Array:
	return active().filter(func(q): return is_ready(q.id) and q.objectives.any(func(o): return o.get("final", false) and o.kind == "talk" and o.npc == npc))

func complete(qid: String) -> Dictionary:
	var q := Data.quest(qid)
	if status(qid) != "active": return {}
	var r: Dictionary = state.quests[qid]
	for o in q.objectives:
		if o.get("final", false): r.progress[o.id] = 1
	r.status = "done"
	if state.tracked == qid or not tracked_valid(): retrack()
	return q.get("rewards", {})

func next_step(qid: String) -> Dictionary:
	var q := Data.quest(qid)
	if q.is_empty(): return {}
	if is_ready(qid):
		for o in q.objectives:
			if o.get("final", false): return {"objective": o, "npc": o.get("npc", "")}
	for o in q.objectives:
		if not o.get("final", false) and not objective(qid, o).done: return {"objective": o, "hint": o.get("hint", {})}
	return {}

func blueprint_hint(id: String) -> String:
	for q in Data.quests:
		if q.get("onAccept", {}).get("blueprints", []).has(id): return "Accept “%s” from %s" % [q.title, Data.npc(q.giver).name]
		if q.get("rewards", {}).get("blueprints", []).has(id): return "Complete “%s” for %s" % [q.title, Data.npc(q.giver).name]
	for u in Data.harmony_unlocks:
		if u.get("blueprints", []).has(id): return "Reach %d Kingdom Harmony" % int(u.at)
	for n in Data.npcs:
		for g in n.get("gifts", []):
			if g.get("blueprint", "") == id: return "Become good friends with %s" % n.name
	for n in Data.layout.nodes:
		if n.get("blueprint", "") == id: return "Hidden in a treasure chest somewhere on the island"
	return "Reach 250 Kingdom Harmony"
