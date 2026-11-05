class_name Validate
## Quest construction checks: they look at what was built, not at one exact layout.

## Continuous walkable path, at least one player wide, from endpoint a to endpoint b of a zone. Each cell can be
## stood on at more than one height (the ground under a floor, the floor itself), and a step between cells may climb
## a ramp (stairs) as long as it rises a little at a time, the way you'd walk it.
static func path_across(zone: Dictionary, walk: WalkWorld) -> Dictionary:
	var in_zone := func(i: int, k: int) -> bool: return i >= zone.minI and i <= zone.maxI and k >= zone.minK and k <= zone.maxK
	var in_rect := func(r: Dictionary, i: int, k: int) -> bool: return i >= r.minI and i <= r.maxI and k >= r.minK and k <= r.maxK
	var stand_at := func(i: int, k: int, from_y: float):
		var s := walk.surface_at(i + 0.5, k + 0.5, from_y)
		if not s.walkable or s.y - from_y > WalkWorld.STEP_UP + 1e-6 or walk.blocked(i + 0.5, k + 0.5, s.y, 0.28): return null
		return s.y
	# walking from one cell's centre to the next in quarter steps: up a stair, but not onto the side of one
	var climb := func(c: Vector2i, n: Vector2i, y: float):
		var py := y
		for f in [0.25, 0.5, 0.75, 1.0]:
			var x := lerpf(c.x + 0.5, n.x + 0.5, f); var z := lerpf(c.y + 0.5, n.y + 0.5, f)
			var s := walk.surface_at(x, z, py)
			if not s.walkable or absf(s.y - py) > WalkWorld.STEP_UP + 1e-6 or walk.blocked(x, z, s.y, 0.28 if f == 1.0 else 0.2): return null
			py = s.y
		return py
	var key := func(c: Vector2i, y: float) -> Vector3i: return Vector3i(c.x, c.y, roundi(y * 4.0))
	var stand := {}   # Vector3i(i, k, height in quarter metres) -> feet height
	var prev := {}
	var queue: Array = []
	var a: Dictionary = zone.endpoints.a
	var b: Dictionary = zone.endpoints.b
	# an endpoint may say how high it is ("y"): the bottom of a climb, the floor up a tower; the path has to start and
	# end at those heights (a floor over the ground counts only up on the floor)
	var at_height := func(e: Dictionary, y: float) -> bool: return not e.has("y") or absf(y - float(e.y)) <= WalkWorld.STEP_UP + 1e-6
	for i in range(int(a.minI), int(a.maxI) + 1):
		for k in range(int(a.minK), int(a.maxK) + 1):
			var y = stand_at.call(i, k, float(a.y) if a.has("y") else INF)
			if y == null or not at_height.call(a, y): continue
			var kk: Vector3i = key.call(Vector2i(i, k), y)
			stand[kk] = y; queue.append(kk)
	while not queue.is_empty():
		var ck: Vector3i = queue.pop_front()
		var c := Vector2i(ck.x, ck.y)
		var y: float = stand[ck]
		if in_rect.call(b, c.x, c.y) and at_height.call(b, y):
			var path: Array = [c]
			var kk := ck
			while prev.has(kk): kk = prev[kk]; path.push_front(Vector2i(kk.x, kk.y))
			return {"ok": true, "path": path}
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if not in_zone.call(n.x, n.y): continue
			var ny = stand_at.call(n.x, n.y, y)
			var mx := (c.x + n.x) / 2.0 + 0.5
			var mz := (c.y + n.y) / 2.0 + 0.5
			if ny == null or absf(ny - y) > WalkWorld.STEP_UP + 1e-6 or walk.blocked(mx, mz, maxf(y, ny), 0.2):
				ny = climb.call(c, n, y)
				if ny == null: continue
			var nk: Vector3i = key.call(n, ny)
			if stand.has(nk): continue
			stand[nk] = ny; prev[nk] = ck; queue.append(nk)
	return {"ok": false, "reached": stand.size()}

static func pieces_in_zone(zone: Dictionary, placements: Array) -> Array:
	return placements.filter(func(p):
		for c in BuildGrid.cells(p):
			if not BuildGrid.zone_contains(zone, c.x, c.y, INF): return false
		return true)

## requirements: [{any: [...], count?, label} | {recolored: true, label}]
static func room_checklist(zone: Dictionary, placements: Array, requirements: Array) -> Array:
	var inside := pieces_in_zone(zone, placements)
	var out: Array = []
	for req in requirements:
		var n := 0
		for p in inside:
			if req.get("recolored", false):
				if p.has("color") and p.color != "" and p.color != Data.piece(p.id).color: n += 1
			elif req.any.has(p.id): n += 1
		var r: Dictionary = req.duplicate(); r["have"] = n; r["ok"] = n >= int(req.get("count", 1))
		out.append(r)
	return out
