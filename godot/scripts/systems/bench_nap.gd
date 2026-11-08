class_name BenchNap
## Waking up from a nap on a bench in the open (game.sleep_until). Most of the time nothing happens; sometimes a gag:
## the local paper over you that the wind takes, a stranger's wet umbrella left open beside you to drip on you all
## night, or a villager caught staring who hurries off. If it rained while you slept, you wake up soaked. These are
## the rules; the scene is world/nap_gags.gd. Odds and lines are data (data/naps.json, Data.naps_here).

const RAINY := ["rain", "drizzle"]

static func rained(t0: Dictionary, t1: Dictionary, allowed: Array = [], forced: Dictionary = {}) -> bool:
	var since := maxf(float(t0.get("total", 0.0)), float(t1.get("total", 0.0)) - Daylight.SLOT_MINUTES)
	if RAINY.has(String(forced.get("type", ""))) and float(forced.get("until", 0.0)) > since: return true
	var last := _slot_before(t1, 1.0)
	for slot in range(maxi(Daylight.slot_index(t0), _slot_before(t1, Daylight.SLOT_MINUTES)), last + 1):
		if RAINY.has(Daylight.slot_weather(slot, allowed)): return true
	return false

static func _slot_before(t: Dictionary, minutes: float) -> int:
	var m := float(t.get("minute", 0.0)) - minutes
	var d := int(t.get("day", 1))
	while m < 0.0:
		m += 24.0 * 60.0
		d -= 1
	return d * 6 + int(m / Daylight.SLOT_MINUTES)

## The gag on waking, or "" for none. ctx: indoors (a sofa in your house: nothing happens), rained, watchers (names of
## villagers who could be standing there), last (the previous gag, not repeated while another is possible).
## roll and roll2 are random numbers in 0..1: whether a gag happens, and which.
static func pick(naps: Dictionary, ctx: Dictionary, roll: float, roll2: float) -> String:
	if ctx.get("indoors", false): return ""
	if ctx.get("rained", false): return "rain"
	var chance := float(naps.get("overnight", naps.get("chance", 0.0))) if ctx.get("overnight", false) else float(naps.get("chance", 0.0))
	if roll >= chance: return ""
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
