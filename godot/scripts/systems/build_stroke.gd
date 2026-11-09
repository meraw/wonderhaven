class_name BuildStroke

const START_PX := 12.0
const LEVEL_STEP := 0.35
const NO_STACK := -1000.0
const LONGEST_STEP := 32

static func started(from: Vector2, now: Vector2) -> bool:
	return from.distance_to(now) >= START_PX

static func stands_on_same(pl: Dictionary, below: Array) -> bool:
	for q in below:
		if String(q.id) == String(pl.id) and BuildGrid.rests_on(pl, q): return true
	return false

static func anchor(pl: Dictionary, below: Array, zone: Dictionary) -> Dictionary:
	var id := String(pl.id)
	var d := Data.piece(id)
	var r := int(pl.r)
	var fp := BuildGrid.footprint(d, r)
	var base := BuildGrid.suggest_bottom(id, float(pl.i), float(pl.k), r, NO_STACK, below, zone)
	var rect := BuildGrid.rect_of(d, pl)
	var ground: bool = absf(float(pl.y) - base) < 0.08
	return {
		"id": id, "i": float(pl.i), "k": float(pl.k), "r": r, "y": float(pl.y),
		"fx": int(fp.x), "fz": int(fp.y),
		"ground": ground,
		"edge": bool(d.get("edge", false)),
		"along_x": rect.maxX - rect.minX >= rect.maxZ - rect.minZ,
		"self": not ground and stands_on_same(pl, below),
	}

static func cell_at(a: Dictionary, x: float, z: float) -> Vector2i:
	var n := floori((x - float(a.i)) / float(a.fx))
	var m := floori((z - float(a.k)) / float(a.fz))
	if a.edge: return Vector2i(n, 0) if a.along_x else Vector2i(0, m)
	return Vector2i(n, m)

static func origin(a: Dictionary, cell: Vector2i) -> Vector2:
	return Vector2(float(a.i) + float(cell.x * int(a.fx)), float(a.k) + float(cell.y * int(a.fz)))

static func line(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	if maxi(dx, dy) > LONGEST_STEP: return [to]
	var sx := 1 if to.x > from.x else -1
	var sy := 1 if to.y > from.y else -1
	var err := dx - dy
	var c := from
	while c != to:
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			c.x += sx
		if e2 < dx:
			err += dx
			c.y += sy
		out.append(c)
	return out

static func candidate(a: Dictionary, cell: Vector2i, below: Array, zones: Array, progress: float = 0.0) -> Dictionary:
	var at := origin(a, cell)
	var id := String(a.id)
	var r := int(a.r)
	var zone := BuildGrid.zone_at(zones, at.x, at.y, progress)
	var base := BuildGrid.suggest_bottom(id, at.x, at.y, r, NO_STACK, below, zone)
	var pl := {"id": id, "i": at.x, "k": at.y, "r": r, "y": base}
	if a.ground: return pl
	pl.y = BuildGrid.suggest_bottom(id, at.x, at.y, r, float(a.y), below, zone)
	if float(pl.y) <= base + 0.01 or absf(float(pl.y) - float(a.y)) > LEVEL_STEP: return {}
	if not a.self and stands_on_same(pl, below): return {}
	return pl
