class_name Travel
## Sailing between islands. Pieces you build stay on their island: the ones on the island you leave are put away in
## state.away[island], and the destination's come back out. The player arrives at the destination's spawn point.

static func leave(state: Dictionary, from: String, to: String, spawn: Dictionary) -> void:
	if not state.get("away") is Dictionary: state["away"] = {}
	state.away[from] = {"placements": state.placements, "drafts": state.get("drafts", [])}
	var back: Dictionary = state.away.get(to, {})
	state.placements = back.get("placements", [])
	state.drafts = back.get("drafts", [])
	state.away.erase(to)
	state.island = to
	state.player = {"x": float(spawn.x), "z": float(spawn.z), "yaw": float(spawn.get("yaw", 0.0))}

## Every placement uid in use, on this island and the others (new pieces get a fresh one).
static func max_uid(state: Dictionary) -> int:
	var m := 0
	for p in state.get("placements", []) + state.get("drafts", []): m = maxi(m, int(p.uid))
	for isl in state.get("away", {}):
		for p in state.away[isl].get("placements", []) + state.away[isl].get("drafts", []): m = maxi(m, int(p.uid))
	return m

## Whether a place is on the travel map. Places stay off it until they're unlocked, so each one turns up as a
## surprise and the map grows as the game goes on: a place with a `reveal` flag appears once that flag is set, and
## one without needs `built` (the starting village). The place you're in is always there; `hidden` ones never are.
static func on_map(isl: Dictionary, flags: Dictionary, here: String) -> bool:
	if isl.get("hidden", false): return false
	if isl.id == here: return true
	if isl.has("reveal"): return flags.get(isl.reveal, false)
	return isl.get("built", false)

## The part of the travel map to show (map units; the whole map is 800 x 500): a box round the places on it with
## room for their names, never smaller than min_size and always in the map's proportions. A lone village fills the
## view, and the view widens as places appear.
static func map_frame(places: Array, min_size := Vector2(360, 225), margin := 30.0) -> Rect2:
	if places.is_empty(): return Rect2(0, 0, 800, 500)
	var box := Rect2()
	for i in places.size():
		var p: Dictionary = places[i]
		var r := float(p.r)
		var b := Rect2(float(p.x) - maxf(r, 110.0), float(p.y) - r, maxf(r, 110.0) * 2.0, r * 2.0 + 40.0)   # the name sits below
		box = b if i == 0 else box.merge(b)
	box = box.grow(margin)
	var w := maxf(box.size.x, min_size.x); var h := maxf(box.size.y, min_size.y)
	if w / h > 1.6: h = w / 1.6
	else: w = h * 1.6
	return Rect2(box.get_center() - Vector2(w, h) / 2.0, Vector2(w, h))

# ---- Rides within a place (trams, funiculars, lifts) ------------------------------------------------------------
## A place can have stops: features {"kind": "stop", "line": "<id>", "name": "...", "x", "z", "ride_label"?,
## "arrive_text"?}. At a stop you choose another stop on the same line and ride there: the screen fades, the clock
## moves on by the ride's length and you step off at the other stop (game.ride_to).
const RIDE_SPEED := 8.0   # metres per second, so a ride across a city takes a few game minutes

## The other stops on `stop`'s line, in the order the line runs (the layout's order), starting with the next one.
static func stops_on(stop: Dictionary, features: Array) -> Array:
	var line: Array = features.filter(func(f): return f.get("kind", "") == "stop" and f.get("line", "") == stop.get("line", ""))
	var i := line.find(stop)
	if i < 0: return line
	return line.slice(i + 1) + line.slice(0, i)

## How many game minutes a ride from one stop to another takes (at least a couple).
static func ride_minutes(from: Dictionary, to: Dictionary) -> float:
	var d := Vector2(float(to.x) - float(from.x), float(to.z) - float(from.z)).length()
	return maxf(2.0, d / RIDE_SPEED * Clock.MINUTES_PER_SECOND)   # a game minute for each second riding
