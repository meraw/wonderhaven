class_name Needs

const STEP := 0.5
const BODY := 0.28

static func hangouts() -> Array: return Data.layout.get("hangouts", [])

static func kind_def(kind: String) -> Dictionary: return Data.needs.get("kinds", {}).get(kind, {})

static func provides(id: String) -> Array: return Data.piece(id).get("provides", [])

static func key(h: Dictionary, kind: String) -> String: return "%s:%s" % [String(h.id), kind]

static func of(state: Dictionary) -> Dictionary:
	if not state.get("needs") is Dictionary: state["needs"] = {}
	if not state.needs.get("noticed") is Array: state.needs["noticed"] = []
	return state.needs

static func center(pl: Dictionary) -> Vector2:
	var b := BuildGrid.bounds(pl)
	return Vector2((b.minX + b.maxX) / 2.0, (b.minZ + b.maxZ) / 2.0)

static func inside(pl: Dictionary, h: Dictionary) -> bool:
	return center(pl).distance_to(Vector2(float(h.x), float(h.z))) <= float(h.get("r", 3.0))

static func near(pl: Dictionary, h: Dictionary, margin: float = 2.5) -> bool:
	return _rect_dist(BuildGrid.bounds(pl), float(h.x), float(h.z)) <= float(h.get("r", 3.0)) + margin

static func _rect_dist(b: Dictionary, x: float, z: float) -> float:
	return Vector2(x - clampf(x, b.minX, b.maxX), z - clampf(z, b.minZ, b.maxZ)).length()

static func _local_walk(walk: WalkWorld, c: Vector2, reach: float) -> WalkWorld:
	var keep := func(s: Dictionary) -> bool:
		if String(s.get("type", "")) == "circle": return c.distance_to(Vector2(float(s.x), float(s.z))) < reach + float(s.r) + 1.0
		return _rect_dist(s, c.x, c.y) < reach + 1.0
	var w := WalkWorld.new(walk.statics.filter(keep), walk.flag_fn)
	w.surfaces = walk.surfaces.filter(func(s): return _rect_dist(s, c.x, c.y) < reach + 1.0)
	w.floors = walk.floors.filter(func(s): return _rect_dist(s, c.x, c.y) < reach + 1.0)
	return w

static func reach_cells(walk: WalkWorld, h: Dictionary) -> Array:
	var reach := float(h.get("r", 3.0)) + 1.2
	var c := Vector2(float(h.x), float(h.z))
	var w := _local_walk(walk, c, reach)
	var span := int(ceil(reach / STEP))
	var order: Array = []
	for i in range(-span, span + 1):
		for k in range(-span, span + 1):
			if Vector2(i, k).length() * STEP <= reach: order.append(Vector2i(i, k))
	order.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	var cells := {}
	var queue: Array = []
	for g in order:
		var x: float = c.x + g.x * STEP
		var z: float = c.y + g.y * STEP
		var s := w.can_stand(x, z, w.surface_at(x, z).y, BODY)
		if not s.is_empty():
			cells[g] = float(s.y); queue.append(g)
			break
	while not queue.is_empty():
		var g: Vector2i = queue.pop_front()
		var y: float = cells[g]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = g + d
			if cells.has(n) or Vector2(n).length() * STEP > reach: continue
			var s := w.can_stand(c.x + n.x * STEP, c.y + n.y * STEP, y, BODY)
			if s.is_empty(): continue
			cells[n] = float(s.y); queue.append(n)
	var out: Array = []
	for g in cells: out.append(Vector3(c.x + g.x * STEP, cells[g], c.y + g.y * STEP))
	return out

static func reachable(pl: Dictionary, kind: String, cells: Array) -> bool:
	var b := BuildGrid.bounds(pl)
	for p in cells:
		if kind == "shelter":
			if p.x >= b.minX and p.x <= b.maxX and p.z >= b.minZ and p.z <= b.maxZ and p.y < float(b.bottom) - 1.0: return true
		elif _rect_dist(b, p.x, p.z) <= 0.95 and (kind in ["light", "green"] or absf(p.y - float(b.bottom)) <= 0.6): return true
	return false

static func gives(pl: Dictionary, kind: String, lit: Dictionary) -> bool:
	if not provides(String(pl.id)).has(kind): return false
	if Data.piece(String(pl.id)).get("mech", {}).get("lamp", false): return lit.has(pl.uid)
	return true

static func charm_value(pieces: Array) -> float:
	var cfg: Dictionary = Data.needs.get("charm", {})
	var rep: Array = cfg.get("repeat", [1.0, 0.5])
	var seen := {}
	var colours := {}
	var v := 0.0
	for p in pieces:
		var n := int(seen.get(p.id, 0))
		if n < rep.size(): v += float(rep[n])
		seen[p.id] = n + 1
		var col := String(p.get("color", ""))
		if col != "" and col != String(Data.piece(String(p.id)).get("color", "")): colours[col] = true
	return v + colours.size() * float(cfg.get("colour", 0.5))

static func charm_points(pieces: Array) -> int:
	return clampi(int(floor(charm_value(pieces) + 0.001)), 0, int(Data.needs.get("charm", {}).get("max", 5)))

static func village(hs: Array, placements: Array, cells_by: Dictionary, lit: Dictionary) -> Dictionary:
	var per := int(Data.needs.get("points", 5))
	var pts := 0
	var needs: Array = []
	var charm: Array = []
	for h in hs:
		var here: Array = placements.filter(func(p): return inside(p, h))
		var cells: Array = cells_by.get(String(h.id), [])
		for kind in h.get("needs", []):
			var by := -1
			for p in here:
				if gives(p, String(kind), lit) and reachable(p, String(kind), cells): by = int(p.uid); break
			needs.append({"hangout": String(h.id), "kind": String(kind), "key": key(h, String(kind)), "met": by != -1, "uid": by})
			if by != -1: pts += per
		var c := charm_points(here)
		charm.append({"hangout": String(h.id), "points": c})
		pts += c
	return {"points": pts, "needs": needs, "charm": charm}

static func met_keys(v: Dictionary) -> Dictionary:
	var out := {}
	for n in v.get("needs", []):
		if n.met: out[n.key] = true
	return out

static func know(state: Dictionary, keys: Array) -> void:
	var noticed: Array = of(state).noticed
	for k in keys:
		if not noticed.has(k): noticed.append(k)

static func open_keys(state: Dictionary, met: Dictionary) -> Array:
	return of(state).noticed.filter(func(k): return not met.get(k, false))

static func can_build(kind: String, blueprints: Array) -> bool:
	for p in Data.pieces:
		if p.get("provides", []).has(kind) and blueprints.has(p.id): return true
	return false

static func notice(state: Dictionary, hs: Array, met: Dictionary, roll: float) -> Array:
	var noticed: Array = of(state).noticed
	var room := int(Data.needs.get("open_max", 3)) - open_keys(state, met).size()
	var pool: Array = []
	for h in hs:
		for kind in h.get("needs", []):
			var k := key(h, String(kind))
			if noticed.has(k) or met.get(k, false) or not can_build(String(kind), state.get("blueprints", [])): continue
			pool.append(k)
	var picked: Array = []
	var r := clampf(roll, 0.0, 0.999)
	while room > 0 and not pool.is_empty():
		var i := mini(int(r * pool.size()), pool.size() - 1)
		picked.append(pool[i]); pool.remove_at(i)
		r = fmod(r * 7.31 + 0.137, 1.0)
		room -= 1
	noticed.append_array(picked)
	return picked

static func hangout(hs: Array, id: String) -> Dictionary:
	for h in hs:
		if String(h.id) == id: return h
	return {}

static func line(hs: Array, k: String, which: String = "noticed") -> String:
	var parts := k.split(":")
	var h := hangout(hs, parts[0])
	var at := String(h.get("at", ""))
	var text := String(kind_def(parts[1]).get(which, ""))
	var cap := (at.substr(0, 1).to_upper() + at.substr(1)) if at != "" else ""
	return text.replace("{Place}", cap).replace("{place}", at)

static func settle(state: Dictionary, points: int) -> Dictionary:
	var delta := points - int(state.get("village_points", 0))
	state["village_points"] = points
	var best_before := int(state.get("approval_best", state.get("harmony", 0)))
	state["harmony"] = int(state.get("harmony", 0)) + delta
	var best := maxi(best_before, int(state.harmony))
	state["approval_best"] = best
	return {"delta": delta, "unlocks": Harmony.between(best_before, best)}

static func raise(state: Dictionary, n: int) -> Array:
	var best_before := int(state.get("approval_best", state.get("harmony", 0)))
	state["harmony"] = int(state.get("harmony", 0)) + n
	var best := maxi(best_before, int(state.harmony))
	state["approval_best"] = best
	return Harmony.between(best_before, best)
