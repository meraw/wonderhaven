class_name Meter
## A location's own progress meter, in place of the Sindaco's approval rating, which stays Monteforchetta's:
## Casalrana's petition signatures, say. It is defined by `meter` in the location's location.json:
##   {name, icon, unit, about, milestones: [{at, id, title, desc, items?, flags?, blueprints?, clothes?}]}
## Requests given there add to it with `meter: n` in their rewards; a request step can wait for it with an
## objective {kind: "meter", value}. Values are whole points counted up from 0 and kept per location in
## state.meters. The HUD and the progress panel show the meter of the place you're on, when it has one.

static func def(island: String) -> Dictionary: return Data.island_def(island).get("meter", {})
static func has_meter(island: String) -> bool: return not def(island).is_empty()

static func value(state: Dictionary, island: String) -> int: return int(state.get("meters", {}).get(island, 0))

## The next milestone above v, or {} when every one is reached.
static func next_milestone(island: String, v: int) -> Dictionary:
	for m in def(island).get("milestones", []):
		if int(m.at) > v: return m
	return {}

## Milestones passed going from `before` to `after`.
static func between(island: String, before: int, after: int) -> Array:
	return def(island).get("milestones", []).filter(func(m): return int(m.at) > before and int(m.at) <= after)

## Adds n points to a location's meter; returns the milestones it passed, for the caller to reward.
static func add(state: Dictionary, island: String, n: int) -> Array:
	if not state.has("meters"): state["meters"] = {}
	var before := value(state, island)
	state.meters[island] = before + n
	return between(island, before, before + n)

## "250 signatures"
static func amount(island: String, n: int) -> String:
	var unit: String = def(island).get("unit", "")
	return "%d %s" % [n, unit] if unit != "" else str(n)
