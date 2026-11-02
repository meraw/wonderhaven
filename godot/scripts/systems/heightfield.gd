class_name Heightfield
## The island's ground shape: shared by the terrain mesh, movement, building and quest checks.

const WATER_Y := -0.4
const WALKABLE_MIN := -0.3
const RIVER_HALF := 3.0
const RIVER_BANK := 0.4
const SPRING := Vector3(14, 0, 1)
const SPRING_R := 2.2
const CHANNEL := Rect2(8, 1, 4, 1)   # x 8..12, z 1..2
const CASTLE_MOUND := Vector3(30, 0.9, -5)
const CASTLE_R := 9.0

static func ss(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func river_center(x: float) -> float:
	var w := ss(6, 16, absf(x))
	return -18.0 + w * 2.6 * sin(x * 0.07 + 0.6)

static func _island_radius(a: float) -> float:
	return 54.0 + 3.0 * sin(3.0 * a + 1.0) + 2.0 * cos(5.0 * a)

static func height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var a := atan2(z, x)
	var ring := ss(32, 42, r) * (1.0 - ss(46, 50, r))
	var h := ring * (0.9 + 0.7 * sin(x * 0.13 + 1.3) * cos(z * 0.11 - 0.4))
	var dc := Vector2(x - CASTLE_MOUND.x, z - CASTLE_MOUND.z).length()
	h += CASTLE_MOUND.y * (1.0 - ss(CASTLE_R - 3.0, CASTLE_R, dc))
	var edge := _island_radius(a) - r
	h = lerpf(-2.4, h, ss(-2, 7, edge))
	var m := 1.0 - ss(20, 28, absf(x - 4.0))
	if z > 34.0 and m > 0.0:
		var hh := 0.25 - maxf(0.0, z - 40.0) * 0.3
		if hh < h: h = lerpf(h, maxf(hh, -2.4), m)
	var dz := absf(z - river_center(x))
	if dz < RIVER_HALF + RIVER_BANK:
		var rh := -1.4 if dz < RIVER_HALF else lerpf(-1.4, h, (dz - RIVER_HALF) / RIVER_BANK)
		h = minf(h, rh)
	var ds := Vector2(x - SPRING.x, z - SPRING.z).length()
	if ds < SPRING_R + 0.4:
		h = minf(h, -0.8 if ds < SPRING_R else lerpf(-0.8, h, (ds - SPRING_R) / 0.4))
	if x >= CHANNEL.position.x and x <= CHANNEL.end.x and z >= CHANNEL.position.y and z <= CHANNEL.end.y:
		h = minf(h, -0.6)
	return h

static func is_water(x: float, z: float) -> bool: return height(x, z) < WALKABLE_MIN

static func is_stream_cell(i: float, k: float) -> bool:
	var x := i + 0.5
	var z := k + 0.5
	if x >= CHANNEL.position.x and x <= CHANNEL.end.x and z >= CHANNEL.position.y and z <= CHANNEL.end.y: return true
	if Vector2(x - SPRING.x, z - SPRING.z).length() < SPRING_R: return true
	return absf(z - river_center(x)) < RIVER_HALF and sqrt(x * x + z * z) < 50.0
