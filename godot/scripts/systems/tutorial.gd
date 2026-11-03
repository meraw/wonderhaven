class_name Tutorial
## The guided first day: which step is current, what counts as done, which HUD parts are shown yet and which
## requests are open. Steps and tips live in data/tutorial.json. Tutorial state is saved with the game:
## {on, step, seen (tip ids already shown), panels (panels opened so far)}.

static func new_state(on: bool = true, all_tips_seen: bool = false) -> Dictionary:
	return {"on": on, "step": 0, "seen": Data.tutorial.tips.keys() if all_tips_seen else [], "panels": []}

static func steps() -> Array: return Data.tutorial.steps

static func current(t: Dictionary) -> Dictionary:
	if not t.get("on", false): return {}
	var i := int(t.get("step", 0))
	return steps()[i] if i < steps().size() else {}

## True when a HUD part (e.g. "harmony", "resources", "key:journal") should be shown. Everything shows once the
## guided day is over or switched off.
static func revealed(t: Dictionary, what: String) -> bool:
	if not t.get("on", false): return true
	for k in mini(int(t.get("step", 0)) + 1, steps().size()):
		if what in steps()[k].get("reveal", []): return true
	return false

## During the guided day only the story requests it walks you through are offered.
static func allows_offer(t: Dictionary, qid: String) -> bool:
	return not t.get("on", false) or qid in Data.tutorial.get("offers", [])

## facts: moved (m), looked (radians), flags, panels, buildmode (bool), quests (state.quests),
## ready (Callable qid -> bool), objective (Callable qid, index -> bool).
static func is_done(step: Dictionary, facts: Dictionary) -> bool:
	var parts: PackedStringArray = String(step.get("done", "")).split(":")
	var quests: Dictionary = facts.get("quests", {})
	match parts[0]:
		"moved": return float(facts.get("moved", 0.0)) >= 3.0
		"looked": return float(facts.get("looked", 0.0)) >= 0.6
		"flag": return facts.get("flags", {}).get(parts[1], false)
		"panel": return parts[1] in facts.get("panels", [])
		"buildmode": return facts.get("buildmode", false)
		"accepted": return quests.has(parts[1])
		"quest": return quests.get(parts[1], {}).get("status", "") == "done"
		"ready":
			if quests.get(parts[1], {}).get("status", "") == "done": return true
			return facts.has("ready") and facts.ready.call(parts[1])
		"objective":
			if quests.get(parts[1], {}).get("status", "") == "done": return true
			return facts.has("objective") and facts.objective.call(parts[1], int(parts[2]))
	return false

## Steps finished by story progress (taking or finishing a request). If the player is already past one of these,
## the guide catches up, so a learning step they skipped (say, opening the bag) can never hold the game back.
const PROGRESS_KINDS := ["flag", "accepted", "quest", "ready", "objective"]

## Moves past every step that is already done, and jumps ahead to just after the furthest story-progress step that
## is done. Returns the ids of the steps passed; switches the guided day off after the last one.
static func advance(t: Dictionary, facts: Dictionary) -> Array:
	var out: Array = []
	while t.get("on", false):
		var i := int(t.step)
		var st := current(t)
		if st.is_empty(): break
		var to := i + 1 if is_done(st, facts) else -1
		for j in range(steps().size() - 1, i, -1):
			var later: Dictionary = steps()[j]
			if String(later.done).split(":")[0] in PROGRESS_KINDS and is_done(later, facts):
				to = maxi(to, j + 1); break
		if to < 0: break
		for k in range(i, to): out.append(steps()[k].id)
		t.step = to
		if int(t.step) >= steps().size(): t.on = false
	return out

## Replaces {action} with the player's key for it, and {move} with all four movement keys.
static func fill(text: String, key_label: Callable) -> String:
	var out := text.replace("{move}", "%s%s%s%s" % [key_label.call("move_forward"), key_label.call("move_left"), key_label.call("move_back"), key_label.call("move_right")])
	var i := out.find("{")
	while i >= 0:
		var j := out.find("}", i)
		if j < 0: break
		var action := out.substr(i + 1, j - i - 1)
		out = out.substr(0, i) + str(key_label.call(action)) + out.substr(j + 1)
		i = out.find("{", i)
	return out
