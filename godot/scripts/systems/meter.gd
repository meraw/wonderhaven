class_name LocationMeter
## A location's own progress meter, shown instead of Monteforchetta's approval rating while you're there: a river
## gauge, an evening paper's column inches, a petition's signatures. Its map entry (islands.json or a pack's
## location.json) describes it:
##   "meter": {"name", "icon", "about"?, "reward"?, "display"?, "milestones": [{at, id, title, desc, blueprints?,
##             clothes?, flags?}]}
## Requests from that location add points with "meter" in their rewards. Points count up from 0 and milestones come
## at those points. "display" ({from, per_point, format, to?}) turns points into what the meter reads: a flood gauge
## going down from 7.40 m and stopping at 0.00 m, say. "reward" is how a reward reads ("%d cm off the gauge"). Pure: no nodes.

static func def(island: String) -> Dictionary: return Data.island_def(island).get("meter", {})

## Points on an island's meter so far.
static func points(state: Dictionary, island: String) -> int:
	var m = state.get("meters", {})
	return int(m.get(island, 0)) if m is Dictionary else 0

## What the meter reads at these points. A display's "to" is where the reading stops (a gauge doesn't go below zero,
## however much more you do).
static func reading(m: Dictionary, pts: int) -> String:
	if not m.has("display"): return str(pts)
	var d: Dictionary = m.display
	var per := float(d.get("per_point", 1.0))
	var v := float(d.get("from", 0.0)) + pts * per
	if d.has("to"): v = maxf(v, float(d.to)) if per < 0.0 else minf(v, float(d.to))
	return String(d.get("format", "%d")) % v

static func next_milestone(m: Dictionary, pts: int) -> Dictionary:
	for u in m.get("milestones", []):
		if int(u.at) > pts: return u
	return {}

static func between(m: Dictionary, before: int, after: int) -> Array:
	return m.get("milestones", []).filter(func(u): return int(u.at) > before and int(u.at) <= after)

## How a reward of n points reads.
static func reward_text(m: Dictionary, n: int) -> String:
	return "%s %s" % [String(m.get("icon", "📈")), String(m.get("reward", "+%d " + String(m.get("name", "progress")))) % n]

## Adds points to an island's meter; returns the milestones passed on the way.
static func add(state: Dictionary, island: String, n: int) -> Array:
	if not state.get("meters") is Dictionary: state["meters"] = {}
	var before := points(state, island)
	state.meters[island] = before + n
	return between(def(island), before, before + n)
