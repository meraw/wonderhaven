class_name Validate
## Quest construction checks: they look at what was built, not at one exact layout.

## Continuous walkable path, at least one player wide, from endpoint a to endpoint b of a zone. It may climb (stairs,
## stacked blocks) as far as the walker can. The endpoints may lie just outside the build site, on the ground it
## joins (a quay, a roof terrace), and endpoint b may need you to stand at least `minY` high (up on that terrace).
static func path_across(zone: Dictionary, walk: WalkWorld) -> Dictionary:
	var in_rect := func(r: Dictionary, i: int, k: int) -> bool: return i >= r.minI and i <= r.maxI and k >= r.minK and k <= r.maxK
	var in_zone := func(i: int, k: int) -> bool: return in_rect.call(zone, i, k) or in_rect.call(zone.endpoints.a, i, k) or in_rect.call(zone.endpoints.b, i, k)
	var min_y: float = float(zone.endpoints.b.get("minY", -INF)) - 0.25
	var stand_at := func(i: int, k: int, from_y: float):
		var s := walk.surface_at(i + 0.5, k + 0.5, from_y)
		if not s.walkable or s.y - from_y > WalkWorld.STEP_UP + 1e-6 or walk.blocked(i + 0.5, k + 0.5, s.y, 0.28): return null
		return s.y
	# from one cell's centre to the next in short steps, as the walker goes: up stairs and ramps, but never up or down
	# more than a step at a time, and never through anything solid
	var step_to := func(c: Vector2i, n: Vector2i, from_y: float):
		var y := from_y
		for s in range(1, 5):
			var x := lerpf(c.x, n.x, s / 4.0) + 0.5
			var z := lerpf(c.y, n.y, s / 4.0) + 0.5
			var sf := walk.surface_at(x, z, y)
			if not sf.walkable or absf(sf.y - y) > WalkWorld.STEP_UP + 1e-6 or walk.blocked(x, z, sf.y, 0.28 if s == 4 else 0.2): return null
			y = sf.y
		return y
	var stand := {}
	var prev := {}
	var queue: Array = []
	var a: Dictionary = zone.endpoints.a
	for i in range(int(a.minI), int(a.maxI) + 1):
		for k in range(int(a.minK), int(a.maxK) + 1):
			var y = stand_at.call(i, k, INF)
			if y != null: stand[Vector2i(i, k)] = y; queue.append(Vector2i(i, k))
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var y: float = stand[c]
		if in_rect.call(zone.endpoints.b, c.x, c.y) and y >= min_y:
			var path: Array = [c]
			var key := c
			while prev.has(key): key = prev[key]; path.push_front(key)
			return {"ok": true, "path": path}
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if not in_zone.call(n.x, n.y) or stand.has(n): continue
			var ny = step_to.call(c, n, y)
			if ny == null: continue
			stand[n] = ny; prev[n] = c; queue.append(n)
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
