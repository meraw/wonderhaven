extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const G := preload("res://scripts/locations/cliffs/ground_data.gd")

const ROCK := Color("8d96a3")
const ROCK_DARK := Color("6c7480")
const SCRUB := Color("6f7d4c")
const WALL_ROCK := Color("8a97aa")
const SEABED := Color("c8b88e")
const PAINT := {
	0: Color("c8b88e"), 1: Color("cbbba0"), 2: Color("b9ada0"), 3: Color("c7b593"), 4: Color("c2bdb2"), 5: Color("7b736b"),
	6: Color("a89c8a"), 7: Color("8a6d4c"), 8: Color("8f8a58"), 9: Color("8c7a64"), 10: Color("cdbd9b"), 11: Color("b39a72"),
	12: Color("8e7c66"), 13: Color("7c5f45"), 14: Color("8b7a58"), 15: Color("d8cdb6"), 16: Color("a39d92"), 17: Color("d2c4a2"),
	18: Color("b0aaa0"),
}
const MEADOW := {7: 0.0, 8: 0.35, 14: 0.4, 15: 0.15}

static var _grid := {}

static func _key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floorf((x + G.HALF) / G.CELL)), int(floorf((z + G.HALF) / G.CELL)))

static func _cells() -> Dictionary:
	if not _grid.is_empty(): return _grid
	for i in G.AREAS.size():
		var a: Array = G.AREAS[i]
		var lo := _key(a[0] - G.NEAR, a[1] - G.NEAR)
		var hi := _key(a[2] + G.NEAR, a[3] + G.NEAR)
		for gx in range(lo.x, hi.x + 1):
			for gz in range(lo.y, hi.y + 1):
				var k := Vector2i(gx, gz)
				if not _grid.has(k): _grid[k] = []
				_grid[k].append(i)
	return _grid

static func _ss(a: float, b: float, v: float) -> float: return Heightfield.ss(a, b, v)

static func area_y(a: Array, x: float, z: float) -> float:
	if int(a[6]) == 1: return lerpf(a[4], a[5], clampf((x - a[0]) / (a[2] - a[0]), 0.0, 1.0))
	if int(a[6]) == 2: return lerpf(a[4], a[5], clampf((z - a[1]) / (a[3] - a[1]), 0.0, 1.0))
	return a[4]

static func find(x: float, z: float) -> int:
	var lst: Array = _cells().get(_key(x, z), [])
	for j in range(lst.size() - 1, -1, -1):
		var a: Array = G.AREAS[lst[j]]
		if x >= a[0] and x <= a[2] and z >= a[1] and z <= a[3]: return lst[j]
	return -1

static func coast(x: float) -> float: return 37.0 + 2.5 * sin(0.19 * x + 1.0)

static func rock(x: float, z: float) -> float:
	var v := 1.5 + (30.0 - z) * 0.3167
	var s := v + minf(22.0, 0.62 * maxf(0.0, absf(x) - 5.0)) + 1.4 * sin(0.31 * x) * cos(0.27 * z)
	var c := coast(x)
	return s + (0.8 - s) * _ss(c - 12.0, c, z)

static func near_level(x: float, z: float) -> float:
	var best := -INF
	for j in _cells().get(_key(x, z), []):
		var a: Array = G.AREAS[j]
		if int(a[7]) != 1: continue
		var cx := clampf(x, a[0], a[2])
		var cz := clampf(z, a[1], a[3])
		if Vector2(x - cx, z - cz).length() <= G.NEAR: best = maxf(best, area_y(a, cx, cz))
	return best

static func height(x: float, z: float) -> float:
	var i := find(x, z)
	if i >= 0: return area_y(G.AREAS[i], x, z)
	var c := coast(x)
	if z > c: return -1.0 - 1.8 * _ss(0.0, 8.0, z - c)
	return maxf(rock(x, z), near_level(x, z) + G.WALL)

static func kind_at(x: float, z: float) -> int:
	var i := find(x, z)
	return int(G.AREAS[i][8]) if i >= 0 else -1

static func walkable_area(x: float, z: float) -> bool:
	var i := find(x, z)
	return i >= 0 and int(G.AREAS[i][7]) == 1

static func paint(x: float, z: float) -> Color:
	var k := kind_at(x, z)
	if k >= 0:
		var c: Color = PAINT.get(k, ROCK)
		var n := fposmod(sin(floorf(x * 1.3) * 12.9898 + floorf(z * 1.3) * 78.233) * 43758.5453, 1.0)
		c = c.darkened(0.06 * n)
		return Color(c.r, c.g, c.b, float(MEADOW.get(k, 0.0)))
	if z > coast(x): return Color(SEABED.r, SEABED.g, SEABED.b, 0.0)
	var wall := near_level(x, z) > -INF
	var patch := 0.5 + 0.5 * sin(x * 0.23 + 1.7) * cos(z * 0.19 - 0.4)
	var rc := ROCK.lerp(ROCK_DARK, 0.5 + 0.5 * sin(x * 0.9 + z * 0.7))
	if wall:
		var wc := WALL_ROCK.lerp(ROCK_DARK, 0.35 + 0.35 * sin(x * 0.9 + z * 0.7))
		return Color(wc.r, wc.g, wc.b, 0.0)
	var g := rc.lerp(SCRUB, _ss(0.35, 0.75, patch))
	return Color(g.r, g.g, g.b, 0.75 if patch > 0.45 else 0.3)

const Buildings := preload("res://scripts/locations/cliffs/buildings.gd")
const Scenery := preload("res://scripts/locations/cliffs/scenery.gd")

static func dress(village) -> void: Scenery.dress(village)

static func building(b: Dictionary) -> Node3D:
	if HouseKit.uses(b): return Buildings.kit_house(b)
	if not String(b.kind).begins_with("cliffs_"): return null
	return Buildings.make(b)
