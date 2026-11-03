class_name QuestEngine
extends RefCounted
## Quests: offering, accepting, tracking objectives from events and live checks, turning in.
## Objective kinds:
##   gather {item, count, stat?}   items gained while the objective is current (stat: lifetime count instead)
##   event  {event, count}         game events (fish, plant, feed, ...) while current
##   build  {check}                a live check from `checks` (bridge walkable, fountain fed, ...)
##   room   {zone, needs}          a room checklist in a build zone: needs = [{any: [piece ids], count?, label} | {recolored: true, label}]
##   pieces {zone, any, count}     how many of these pieces stand in a build zone
##   harmony {value}, flag {flag}
##   pay    {npc, items}           hand items or coins to a villager (a choice in their conversation)
##   talk   {npc, lines?}          talk to someone; `final` ones hand the request in
## Stages: an objective may have a `stage` (0 by default). Only the lowest stage with something unfinished is
## current: gathering and events only count for current objectives, and the journal and tracker show the request
## step by step. onDone {flags, items, blueprints} on an objective is applied when it completes. Live checks latch.

var state: Dictionary
var checks: Dictionary   # check id -> Callable returning bool
var gate := Callable()   # optional (quest id) -> bool: extra condition on offers (the guided first day uses it)

var _memo: Dictionary = {}   # objective results and current stages, until something changes (see invalidate)

func _init(p_state: Dictionary, p_checks: Dictionary = {}) -> void:
	state = p_state; checks = p_checks

## Forget cached objective results. Called whenever quest state changes, and once a frame by the game (live
## checks look at the world: a bridge's path, a fountain's water), so villagers' markers, the compass and the
## tracker can all ask every frame without re-running those checks.
func invalidate() -> void: _memo.clear()

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
	invalidate()
	if not can_offer(id): return {}
	state.quests[id] = {"status": "active", "progress": {}, "done": {}}
	# picking up the story request you were heading for, or nothing tracked: follow the new request
	if state.tracked == "lead:" + id or not tracked_valid(): state.tracked = id
	return Data.quest(id).get("onAccept", {})

static func stage_of(o: Dictionary) -> int: return int(o.get("stage", 0))
const ALL_DONE := 1 << 30

## The lowest stage with an unfinished objective (ALL_DONE when everything but the hand-in is done).
func current_stage(qid: String) -> int:
	var key := "stage/" + qid
	if _memo.has(key): return _memo[key]
	var cur := ALL_DONE
	for o in Data.quest(qid).get("objectives", []):
		if not o.get("final", false) and not objective(qid, o).done: cur = mini(cur, stage_of(o))
	_memo[key] = cur
	return cur

func is_current(qid: String, o: Dictionary) -> bool: return not o.get("final", false) and stage_of(o) == current_stage(qid)

## Stages as [stage numbers in order]; and which one you're on, counting from 1, for "Step 2 of 3".
func stages(qid: String) -> Array:
	var out: Array = []
	for o in Data.quest(qid).get("objectives", []):
		if not o.get("final", false) and not out.has(stage_of(o)): out.append(stage_of(o))
	out.sort()
	return out
func stage_index(qid: String) -> int:
	var st := stages(qid)
	var cur := current_stage(qid)
	return st.size() if cur == ALL_DONE else st.find(cur) + 1

## Objectives to show: everything up to the current stage (and the hand-in once ready); `later` counts the rest.
func shown_objectives(qid: String) -> Dictionary:
	var cur := current_stage(qid)
	var ready := is_ready(qid)
	var out: Array = []; var later := 0
	for o in Data.quest(qid).get("objectives", []):
		if o.get("final", false):
			if ready: out.append(o)
		elif stage_of(o) <= cur: out.append(o)
		else: later += 1
	return {"objectives": out, "later": later}

func objective(qid: String, o: Dictionary) -> Dictionary:
	var key: String = qid + "/" + String(o.get("id", ""))
	if _memo.has(key): return _memo[key]
	var r := _objective(qid, o)
	_memo[key] = r
	return r

func _objective(qid: String, o: Dictionary) -> Dictionary:
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
		"talk", "pay": return {"done": p.get(o.id, 0) == 1, "have": 0, "need": 1}
		"room":
			if p.get(o.id, 0) == 1: return {"done": true, "have": o.needs.size(), "need": o.needs.size()}
			var list := Validate.room_checklist(Data.zone(o.zone), state.get("placements", []), o.needs)
			var ok := list.filter(func(r): return r.ok).size()
			return {"done": ok == list.size(), "have": ok, "need": list.size()}
		"pieces":
			if p.get(o.id, 0) == 1: return {"done": true, "have": need, "need": need}
			var n := Validate.pieces_in_zone(Data.zone(o.zone), state.get("placements", [])).filter(func(pl): return o.any.has(pl.id)).size()
			return {"done": n >= need, "have": mini(n, need), "need": need}
	return {"done": false, "have": 0, "need": need}

func is_ready(qid: String) -> bool:
	if status(qid) != "active": return false
	for o in Data.quest(qid).objectives:
		if not o.get("final", false) and not objective(qid, o).done: return false
	return true

## Latch live objectives; report newly completed ones as [{quest, objective} | {quest, ready: true}].
## Objectives of later stages wait their turn: they neither latch nor get reported until their stage comes up, so
## finishing one stage can complete the next at once if it's already true (say, the bridge was built early).
func refresh() -> Array:
	invalidate()
	var newly: Array = []
	for q in active():
		var r: Dictionary = state.quests[q.id]
		if not r.has("done"): r["done"] = {}
		var guard := 0
		while guard < 8:   # a finished stage can finish the next one too
			guard += 1
			var cur := current_stage(q.id)
			var any := false
			for o in q.objectives:
				if o.get("final", false) or stage_of(o) > cur: continue
				var st := objective(q.id, o)
				if st.done and o.kind in ["harmony", "build", "flag", "room", "pieces"]: r.progress[o.id] = 1
				if st.done and not r.done.has(o.id): r.done[o.id] = true; newly.append({"quest": q, "objective": o}); any = true
			if not any or current_stage(q.id) == cur: break
		if is_ready(q.id) and not r.get("ready", false): r["ready"] = true; newly.append({"quest": q, "ready": true})
	return newly

func on_gain(items: Dictionary) -> Array:
	invalidate()
	for q in active():
		for o in q.objectives:
			if o.kind == "gather" and items.get(o.item, 0) > 0 and is_current(q.id, o):
				var p: Dictionary = state.quests[q.id].progress
				p[o.id] = mini(int(o.count), int(p.get(o.id, 0)) + int(items[o.item]))
	return refresh()

func on_event(name: String, n: int = 1) -> Array:
	invalidate()
	for q in active():
		for o in q.objectives:
			if o.kind == "event" and o.event == name and is_current(q.id, o):
				var p: Dictionary = state.quests[q.id].progress
				p[o.id] = mini(int(o.count), int(p.get(o.id, 0)) + n)
	return refresh()

## Talking to someone completes a current (non-final) talk objective for them.
func on_talk(npc: String) -> Array:
	invalidate()
	for q in active():
		for o in q.objectives:
			if o.kind == "talk" and not o.get("final", false) and o.npc == npc and is_current(q.id, o):
				state.quests[q.id].progress[o.id] = 1
	return refresh()

## Current pay objectives waiting at this villager: [{quest, objective}].
func payments_for(npc: String) -> Array:
	var out: Array = []
	for q in active():
		for o in q.objectives:
			if o.kind == "pay" and o.npc == npc and is_current(q.id, o) and not objective(q.id, o).done: out.append({"quest": q, "objective": o})
	return out

## Hands over the items. Returns {ok, missing: [{id, need}], newly}.
func pay(qid: String, oid: String) -> Dictionary:
	invalidate()
	var o := {}
	for x in Data.quest(qid).get("objectives", []):
		if x.id == oid: o = x
	if o.is_empty() or o.kind != "pay" or not is_current(qid, o): return {"ok": false, "missing": []}
	var cost: Dictionary = {}
	for k in o.items: cost[k] = int(o.items[k])
	if not Inventory.spend(state.inventory, cost): return {"ok": false, "missing": Inventory.missing(state.inventory, cost)}
	state.quests[qid].progress[oid] = 1
	return {"ok": true, "missing": [], "newly": refresh()}

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
	invalidate()
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
		if is_current(qid, o) and not objective(qid, o).done:
			if o.kind in ["talk", "pay"]: return {"objective": o, "npc": o.npc}
			return {"objective": o, "hint": o.get("hint", {})}
	return {}

func blueprint_hint(id: String) -> String:
	var hint := _blueprint_source(id)
	for sid in Data.shops.get("shops", {}):
		for line in Data.shops.shops[sid].get("stock", []):
			if line.get("blueprint", "") == id: return "%s · or buy it at %s" % [hint, Data.shops.shops[sid].name]
	return hint

func _blueprint_source(id: String) -> String:
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
