class_name LocationMeter
## A location's own progress meter, shown instead of Monteforchetta's approval rating while you're there: a river
## gauge, an evening paper's column inches, a petition's signatures. Its map entry (islands.json or a pack's
## location.json) describes it:
##   "meter": {"name", "icon", "about"?, "reward"?, "display"?, "short"?, "milestones": [{at, id, title, desc,
##             blueprints?, clothes?, items?, flags?, requires?, waits?}]}
## Requests from that location add points with "meter" in their rewards. Points count up from 0 and milestones come
## at those points. "display" ({from, per_point, format}) turns points into what the meter reads: a flood gauge
## going down from 7.40 m, say. "reward" is how a reward reads ("%d cm off the gauge"). A milestone with "requires"
## ({quests, flags}) also waits for those, however many points you have (a front page that has to be about the
## finale); "waits" says what for, in words. Build sites there grow with the meter (progress). Pure: no nodes.

static func def(island: String) -> Dictionary: return Data.island_def(island).get("meter", {})

## Points on an island's meter so far.
static func points(state: Dictionary, island: String) -> int:
	var m = state.get("meters", {})
	return int(m.get(island, 0)) if m is Dictionary else 0

## What the meter reads at these points.
static func reading(m: Dictionary, pts: int) -> String:
	if not m.has("display"): return str(pts)
	var d: Dictionary = m.display
	return String(d.get("format", "%d")) % (float(d.get("from", 0.0)) + pts * float(d.get("per_point", 1.0)))

static func next_milestone(m: Dictionary, pts: int) -> Dictionary:
	for u in m.get("milestones", []):
		if int(u.at) > pts: return u
	return {}

static func between(m: Dictionary, before: int, after: int) -> Array:
	return m.get("milestones", []).filter(func(u): return int(u.at) > before and int(u.at) <= after)

## What a place's progress is measured in: its own meter's points where it has one, otherwise the approval rating
## (a zone's `expanded.harmony` is compared with this).
static func progress(state: Dictionary, island: String) -> float:
	return float(points(state, island)) if not def(island).is_empty() else float(state.get("harmony", 0))

static func requirements_met(state: Dictionary, u: Dictionary) -> bool:
	var r: Dictionary = u.get("requires", {})
	for q in r.get("quests", []):
		if state.get("quests", {}).get(q, {}).get("status", "") != "done": return false
	for f in r.get("flags", []):
		if not state.get("flags", {}).get(f, false): return false
	return true

## Has this milestone been handed out? (Story notes each one in unlocks_seen.)
static func reached(state: Dictionary, u: Dictionary) -> bool: return state.get("unlocks_seen", []).has(u.get("id", ""))

## Milestones with requirements that you have the points for and that are due now (their requirements just met).
static func waiting(state: Dictionary, island: String) -> Array:
	var pts := points(state, island)
	return def(island).get("milestones", []).filter(func(u): return u.has("requires") and int(u.at) <= pts and not reached(state, u) and requirements_met(state, u))

## How a reward of n points reads.
static func reward_text(m: Dictionary, n: int) -> String:
	return "%s %s" % [String(m.get("icon", "📈")), String(m.get("reward", "+%d " + String(m.get("name", "progress")))) % n]

## Adds points to an island's meter; returns the milestones passed on the way.
static func add(state: Dictionary, island: String, n: int) -> Array:
	if not state.get("meters") is Dictionary: state["meters"] = {}
	var before := points(state, island)
	state.meters[island] = before + n
	return between(def(island), before, before + n)
