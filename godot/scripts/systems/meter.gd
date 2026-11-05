class_name Meter
## A location's own progress meter, in place of the Sindaco's approval rating: the column inches a city's evening
## paper gives you, say. A location declares one in its location.json:
##   "meter": {"name": "La Sera di Toriano", "unit": "column inches", "icon": "📰", "about": "how it grows",
##             "milestones": [{"at": 10, "id", "title", "desc", "blueprints"?, "clothes"?, "items"?, "flags"?, "waits"?,
##                             "requires"?: {"quests": [...], "flags": [...]}}]}
## Requests given by that location's villagers, and the first piece of a kind built there, add to it instead of the
## approval rating (their `harmony` reward is the number of points). A milestone with `requires` also waits for
## those (a front page that must be about the finale). Zone expansions there follow it too (see progress).
## Saved as state.meters[location] = {value, got: [milestone ids]}.

static func def(island: String) -> Dictionary: return Data.island_def(island).get("meter", {})
static func has(island: String) -> bool: return not def(island).is_empty()

static func _rec(state: Dictionary, island: String) -> Dictionary:
	if not state.has("meters"): state["meters"] = {}
	if not state.meters.get(island) is Dictionary: state.meters[island] = {"value": 0, "got": []}
	var r: Dictionary = state.meters[island]
	if not r.get("got") is Array: r["got"] = []
	return r

static func value(state: Dictionary, island: String) -> int:
	return int(state.get("meters", {}).get(island, {}).get("value", 0)) if state.get("meters", {}).get(island) is Dictionary else 0

## What this place's progress is measured in: its meter where it has one, otherwise the approval rating.
static func progress(state: Dictionary, island: String) -> float:
	return float(value(state, island)) if has(island) else float(state.get("harmony", 0))

static func milestones(island: String) -> Array:
	var out: Array = def(island).get("milestones", []).duplicate()
	out.sort_custom(func(a, b): return float(a.at) < float(b.at))
	return out

static func got(state: Dictionary, island: String, m: Dictionary) -> bool:
	return state.get("meters", {}).get(island, {}).get("got", []).has(m.id) if state.get("meters", {}).get(island) is Dictionary else false

static func requirements_met(state: Dictionary, m: Dictionary) -> bool:
	var r: Dictionary = m.get("requires", {})
	for q in r.get("quests", []):
		if state.quests.get(q, {}).get("status", "") != "done": return false
	for f in r.get("flags", []):
		if not state.flags.get(f, false): return false
	return true

## The next milestone not reached yet, or {}.
static func next(state: Dictionary, island: String) -> Dictionary:
	for m in milestones(island):
		if not got(state, island, m): return m
	return {}

## Adds points; returns the milestones reached by it (see check).
static func add(state: Dictionary, island: String, n: int) -> Array:
	var r := _rec(state, island)
	r.value = int(r.get("value", 0)) + n
	return check(state, island)

## Milestones newly reached (enough points and their requirements met), now marked as got, in order.
static func check(state: Dictionary, island: String) -> Array:
	if not has(island): return []
	var r := _rec(state, island)
	var out: Array = []
	for m in milestones(island):
		if r.got.has(m.id) or int(r.get("value", 0)) < int(m.at) or not requirements_met(state, m): continue
		r.got.append(m.id); out.append(m)
	return out
