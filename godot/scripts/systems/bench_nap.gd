class_name BenchNap
## Waking up from a nap on a bench in the open (game.sleep_until). Most of the time nothing happens; sometimes a gag:
## the local paper over you that the wind takes, a stranger's wet umbrella left open beside you to drip on you all
## night, or a villager caught staring who hurries off. If it rained while you slept, you wake up soaked. These are
## the rules; the scene is world/nap_gags.gd. Odds and lines are data (data/naps.json, Data.naps_here).

const RAINY := ["rain", "drizzle"]

## True when rain (or drizzle) fell during a nap from t0 to t1 (clock time dictionaries): every weather slot the nap
## spans, and weather a request brought (state.forced_weather, see Daylight.force).
static func rained(t0: Dictionary, t1: Dictionary, allowed: Array = [], forced: Dictionary = {}) -> bool:
	if RAINY.has(String(forced.get("type", ""))) and float(forced.get("until", 0.0)) > float(t0.get("total", 0.0)): return true
	for slot in range(Daylight.slot_index(t0), Daylight.slot_index(t1) + 1):
		if RAINY.has(Daylight.slot_weather(slot, allowed)): return true
	return false

## The gag on waking, or "" for none. ctx: indoors (a sofa in your house: nothing happens), rained, watchers (names of
## villagers who could be standing there), last (the previous gag, not repeated while another is possible).
## roll and roll2 are random numbers in 0..1: whether a gag happens, and which.
static func pick(naps: Dictionary, ctx: Dictionary, roll: float, roll2: float) -> String:
	if ctx.get("indoors", false): return ""
	if ctx.get("rained", false): return "rain"
	if roll >= float(naps.get("chance", 0.0)): return ""
	var pool: Array = []
	var gags: Dictionary = naps.get("gags", {})
	for id in gags:
		if id == "rain" or float(gags[id].get("weight", 0.0)) <= 0.0: continue
		if id == "stared" and ctx.get("watchers", []).is_empty(): continue
		pool.append(id)
	if pool.size() > 1: pool.erase(String(ctx.get("last", "")))
	if pool.is_empty(): return ""
	var total := 0.0
	for id in pool: total += float(gags[id].weight)
	var r := roll2 * total
	for id in pool:
		r -= float(gags[id].weight)
		if r < 0.0: return id
	return pool[-1]

## A gag's line with its blanks filled in: {name} (who was staring) and {paper} (the local paper).
static func line(naps: Dictionary, id: String, roll: float, name: String = "") -> String:
	var lines: Array = naps.get("gags", {}).get(id, {}).get("lines", [])
	if lines.is_empty(): return ""
	var s: String = lines[mini(int(roll * lines.size()), lines.size() - 1)]
	return s.replace("{name}", name).replace("{paper}", String(naps.get("paper", "paper")))
