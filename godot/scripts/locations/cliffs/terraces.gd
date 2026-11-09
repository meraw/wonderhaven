extends RefCounted

const ORDER := ["e1", "w2", "w3", "w4", "e3", "e4", "w5", "e5", "w6", "e6", "w7", "e7", "w8", "e8"]
const TENDED := ["w1", "e2"]
const BREACHES := {"w4": [-30, -25, 4], "e3": [26, 30, 3], "w5": [-20, -16, 5], "w6": [-38, -34, 6], "e7": [32, 36, 7], "w8": [-14, -10, 8], "e8": [22, 26, 8]}
const WALLED := {"w3": "w4", "w4": "w4", "e3": "e3", "w5": "w5", "w6": "w6", "e7": "e7", "w8": "w8", "e8": "e8"}
const BY_FLAG := {"e5": "cliffs_monorailRuns", "e6": "cliffs_monorailRuns", "w7": "cliffs_sanctuaryPath"}

static func zs(n: int) -> int: return -26 - 4 * (n - 1)

static func level(n: int) -> float: return 10.0 + 2.0 * n

static func flag(id: String) -> String: return "cliffs_terrace_" + id

static func rect(id: String) -> Dictionary:
	var n := int(id.substr(1))
	var k0 := zs(n) - 4
	var k1 := zs(n) - 1
	if id.begins_with("w"): return {"minI": -46, "maxI": -4, "minK": k0, "maxK": k1}
	return {"minI": 3, "maxI": 45, "minK": k0, "maxK": k1}

static func breach_zone(id: String) -> Dictionary:
	var b: Array = BREACHES[id]
	var n := int(b[2])
	var s := zs(n)
	var i0 := int(b[0])
	var i1 := int(b[1]) - 1
	return {"id": "cliffs_breach_" + id, "minI": i0, "maxI": i1, "minK": s - 2, "maxK": s + 1, "seal": level(n) + 0.5,
		"endpoints": {"a": {"minI": i0, "maxI": i1, "minK": s + 1, "maxK": s + 1}, "b": {"minI": i0, "maxI": i1, "minK": s - 2, "maxK": s - 2}}}

static func green_on(id: String, placements: Array) -> bool:
	var r := rect(id)
	for p in placements:
		if not Data.piece(String(p.id)).get("provides", []).has("green"): continue
		for c in BuildGrid.cells(p):
			if c.x >= r.minI and c.x <= r.maxI and c.y >= r.minK and c.y <= r.maxK: return true
	return false

static func walled(id: String, placements: Array) -> bool:
	if not WALLED.has(id): return true
	return Validate.sealed(breach_zone(String(WALLED[id])), placements).sealed

static func back(id: String, state: Dictionary) -> bool:
	var flags: Dictionary = state.get("flags", {})
	if BY_FLAG.has(id): return bool(flags.get(BY_FLAG[id], false))
	var placements: Array = state.get("placements", [])
	return green_on(id, placements) and walled(id, placements)

static func things(state: Dictionary) -> Array:
	var out: Array = []
	for id in ORDER:
		if back(id, state): out.append({"flag": flag(id), "text": "🌿 Terrace %s is back in use" % id.to_upper()})
	return out

static func in_use(state: Dictionary) -> int:
	var flags: Dictionary = state.get("flags", {})
	return TENDED.size() + ORDER.filter(func(id): return flags.get(flag(id), false)).size()
