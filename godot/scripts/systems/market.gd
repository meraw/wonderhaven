class_name Market

static func cfg() -> Dictionary: return Data.market

static func here() -> bool:
	var people: Array = Data.npcs_here().map(func(n): return String(n.id))
	return cfg().get("sellers", []).any(func(id): return people.has(String(id)))

static func is_day(day: int) -> bool:
	var every := int(cfg().get("every", 5))
	return every > 0 and day >= every and day % every == 0

static func open(time: Dictionary) -> bool:
	var h := float(time.get("minute", 0.0)) / 60.0
	return is_day(int(time.get("day", 1))) and h >= float(cfg().get("open", 8.0)) and h < float(cfg().get("close", 19.0))

static func counters(placements: Array) -> Array:
	var out: Array = placements.filter(func(p): return Needs.provides(String(p.id)).has("stall"))
	out.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	return out

static func assign(sellers: Array, stalls: Array) -> Dictionary:
	var out := {}
	var order: Array = cfg().get("sellers", [])
	var n := 0
	for id in order:
		if n >= stalls.size(): break
		if not sellers.has(String(id)): continue
		out[String(id)] = int(stalls[n].uid)
		n += 1
	return out

static func record(state: Dictionary) -> Dictionary:
	if not state.get("market") is Dictionary: state["market"] = {}
	return state.market

static func selling(state: Dictionary, npc_id: String) -> bool:
	var r := record(state)
	var t: Dictionary = state.get("time", {})
	return open(t) and int(r.get("day", 0)) == int(t.get("day", 1)) and r.get("at", {}).has(npc_id)

static func paper_line(day: int, stalls: int) -> String:
	var p: Dictionary = cfg().get("paper", {})
	if is_day(day): return String(p.get("today", "")).replace("{n}", str(stalls)) if stalls > 0 else String(p.get("none", ""))
	if is_day(day + 1): return String(p.get("tomorrow", ""))
	return ""

static func spot(walk: WalkWorld, counter: Dictionary) -> Dictionary:
	var c := Needs.center(counter)
	var b := BuildGrid.bounds(counter)
	var f := Visits.forward(counter)
	for d in [-1.0, 1.0]:
		var want: Vector2 = c - f * d * (0.5 + (b.maxZ - b.minZ if absf(f.y) > 0.5 else b.maxX - b.minX) / 2.0)
		var s := walk.free_spot(want.x, want.y, Rect2(), 0.8, 0.32)
		if not s.is_empty(): return {"x": float(s.x), "y": float(s.y), "z": float(s.z), "yaw": atan2(c.x - float(s.x), c.y - float(s.z))}
	var any := walk.free_spot(c.x, c.y, Rect2(), 2.0, 0.32)
	if any.is_empty(): return {}
	return {"x": float(any.x), "y": float(any.y), "z": float(any.z), "yaw": atan2(c.x - float(any.x), c.y - float(any.z))}
