class_name Visits

static func level(v: Dictionary, hid: String) -> int:
	var met := 0
	for n in v.get("needs", []):
		if String(n.hangout) == hid and n.met: met += 1
	var charm := 0
	for c in v.get("charm", []):
		if String(c.hangout) == hid: charm = int(c.points)
	var score := met + charm / 2.0
	var lv := 0
	for s in Data.needs.get("liveliness", [1.0, 2.5, 4.0]):
		if score >= float(s) - 0.001: lv += 1
	return lv

static func forward(pl: Dictionary) -> Vector2:
	var yaw := -int(pl.r) * PI / 2.0
	return Vector2(sin(yaw), cos(yaw))

static func center(pl: Dictionary) -> Vector2:
	var b := BuildGrid.bounds(pl)
	return Vector2((b.minX + b.maxX) / 2.0, (b.minZ + b.maxZ) / 2.0)

static func near_cell(cells: Array, p: Vector2, max_d: float, y: float = INF, dy: float = 0.6) -> Dictionary:
	var best := {}
	var bd := max_d
	for c in cells:
		if y != INF and absf(c.y - y) > dy: continue
		var d := p.distance_to(Vector2(c.x, c.z))
		if d <= bd: bd = d; best = {"x": c.x, "y": c.y, "z": c.z}
	return best

static func _face(from: Dictionary, to: Vector2) -> float: return atan2(to.x - float(from.x), to.y - float(from.z))

static func use_spot(pl: Dictionary, kind: String, cells: Array) -> Dictionary:
	var b := BuildGrid.bounds(pl)
	var c := center(pl)
	var spot := {}
	match kind:
		"seat":
			var cell := near_cell(cells, c + forward(pl) * 0.85, 0.55, float(b.bottom))
			if not cell.is_empty():
				var at := NapGags.seat_spot(pl)
				spot = {"approach": Vector2(cell.x, cell.z), "at": Vector2(at.x, at.z), "y": at.y, "yaw": -int(pl.r) * PI / 2.0, "pose": "sit"}
		"shelter":
			for p in cells:
				if p.x > b.minX + 0.2 and p.x < b.maxX - 0.2 and p.z > b.minZ + 0.2 and p.z < b.maxZ - 0.2 and p.y < float(b.bottom) - 1.0:
					spot = {"approach": Vector2(p.x, p.z), "at": Vector2(p.x, p.z), "y": p.y, "yaw": PI, "pose": ""}
					break
		"stall":
			var cell := near_cell(cells, c, 1.4, float(b.bottom))
			if not cell.is_empty(): spot = {"approach": Vector2(cell.x, cell.z), "at": Vector2(cell.x, cell.z), "y": cell.y, "yaw": _face(cell, c), "pose": "work"}
		"light", "green":
			var cell := near_cell(cells, c, 1.6)
			if not cell.is_empty(): spot = {"approach": Vector2(cell.x, cell.z), "at": Vector2(cell.x, cell.z), "y": cell.y, "yaw": _face(cell, c), "pose": "read" if kind == "light" else "garden"}
	if not spot.is_empty():
		spot["ok"] = true
		return spot
	var look := near_cell(cells, c, 3.5)
	if look.is_empty(): return {"ok": false}
	return {"ok": false, "stare": true, "approach": Vector2(look.x, look.z), "at": Vector2(look.x, look.z), "y": look.y, "yaw": _face(look, c), "pose": ""}

static func options(hs: Array, placements: Array, cells_by: Dictionary, lit: Dictionary) -> Array:
	var out: Array = []
	for h in hs:
		var hid := String(h.id)
		var cells: Array = cells_by.get(hid, [])
		if cells.is_empty(): continue
		var here: Array = placements.filter(func(p): return Needs.inside(p, h))
		for kind in h.get("needs", []):
			for p in here:
				if not Needs.gives(p, String(kind), lit): continue
				var spot := use_spot(p, String(kind), cells)
				if spot.get("ok", false) or spot.get("stare", false):
					out.append({"hangout": hid, "uid": int(p.uid), "kind": String(kind), "use": spot.get("ok", false), "spot": spot})
	return out

static func gathering(v: Dictionary, dusk: bool) -> bool: return dusk and level(v, "piazza") >= 3

static func pick(opts: Array, who: String, hs: Array, v: Dictionary, taken: Dictionary, roll: float, dusk: bool) -> Dictionary:
	var gather := gathering(v, dusk)
	var pool: Array = []
	var total := 0.0
	for o in opts:
		if o.use and taken.has(o.uid): continue
		var h := Needs.hangout(hs, String(o.hangout))
		var w := 1.0 + level(v, String(o.hangout)) * 1.5
		if String(h.get("who", "")) == who: w += 2.0
		if not o.use: w *= 0.6
		if gather: w *= 8.0 if String(o.hangout) == "piazza" else 0.25
		pool.append([o, w]); total += w
	if pool.is_empty(): return {}
	var r := clampf(roll, 0.0, 0.999) * total
	for e in pool:
		r -= float(e[1])
		if r < 0.0: return (e[0] as Dictionary).duplicate(true)
	return (pool[-1][0] as Dictionary).duplicate(true)

static func grid(h: Dictionary, p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - float(h.x)) / Needs.STEP)), int(round((p.y - float(h.z)) / Needs.STEP)))

static func path(cells: Array, h: Dictionary, from: Vector2, to: Vector2) -> Array:
	var have := {}
	for c in cells: have[grid(h, Vector2(c.x, c.z))] = true
	if have.is_empty(): return []
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var bs := INF
	var bg := INF
	for g in have:
		var p := Vector2(float(h.x) + g.x * Needs.STEP, float(h.z) + g.y * Needs.STEP)
		if p.distance_to(from) < bs: bs = p.distance_to(from); start = g
		if p.distance_to(to) < bg: bg = p.distance_to(to); goal = g
	var prev := {start: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var g: Vector2i = queue.pop_front()
		if g == goal: break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = g + d
			if have.has(n) and not prev.has(n): prev[n] = g; queue.append(n)
	if not prev.has(goal): return []
	var out: Array = []
	var g := goal
	while true:
		out.push_front(Vector2(float(h.x) + g.x * Needs.STEP, float(h.z) + g.y * Needs.STEP))
		if g == start: break
		g = prev[g]
	return out
