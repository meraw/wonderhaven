extends RefCounted

const MAP_HALF := 90.0
const TORRENT_X := 4.0
const TORRENT_SWING := 3.0
const TORRENT_HALF := 2.8
const MOUTH_HALF := 6.0
const BRIDGE_Z := 12.0
const BRIDGE_HALF := 1.1
const BRIDGE_W := 2.0
const BRIDGE_E := 11.3
const CROWN_W := 5.9
const CROWN_E := 7.4
const BRIDGE_LOW := 8.3
const BRIDGE_PEAK := 9.9
const RIDGE_X := -42.0
const TERRACE_STEP := 1.8
const STAIR_STEP := 0.3
const TERRACE_SOUTH := 44.0
const TERRACE_NORTH := -62.0
const CRAG_Z := -83.0
const CRAG_RISE := 4.5
const GULLY_W := -83.0
const GULLY_E := 83.0
const GULLY_HALF := 2.5
const GULLY_BANK := 9.0
const SHELF := Rect2(9.9, 18.0, 4.1, 10.0)
const SHELF_H := 0.25
const FALLEN := Rect2(34.0, -20.0, 12.0, 6.0)
const MULE_GAP := Vector2(29.5, 33.5)
const PIAZZA := Vector3(-20.0, 13.8, -6.0)
const PIAZZA_R := 8.5
const PAD_EDGE := 2.0
const TANK_PAD := 20
const BLEND := 1.0
const CART_HALF := 1.6
const PATH_HALF := 1.1

const CART := [Vector2(36.5, 54.0), Vector2(52.0, 47.0), Vector2(30.0, 42.0), Vector2(50.0, 36.0), Vector2(30.0, 28.0),
	Vector2(50.0, 22.0), Vector2(26.0, 14.0), Vector2(17.5, 12.5)]
const MULE := [Vector2(20.5, 50.0), Vector2(20.0, 30.0), Vector2(18.5, 15.5)]
const TERRACE_PATH := [Vector2(15.5, 9.0), Vector2(16.0, -10.0), Vector2(17.5, -25.0), Vector2(21.0, -40.0),
	Vector2(27.0, -54.0), Vector2(37.0, -62.0)]
const FARM_LANE := [Vector2(15.8, 1.0), Vector2(33.0, 1.0)]
const MILL_RAMP := [Vector2(12.0, 27.5), Vector2(13.5, 37.0)]

const PADS := [
	[-20.0, -18.6, 5.0, 3.2, 13.8],
	[-10.5, -18.6, 3.0, 3.2, 13.8],
	[-31.5, -6.0, 3.0, 4.0, 13.8],
	[-7.0, -3.0, 3.0, 2.6, -99.0],
	[-19.75, 14.8, 6.0, 6.0, -99.0],
	[-34.5, -27.0, 6.0, 11.5, -99.0],
	[-44.0, -61.0, 7.0, 6.0, -99.0],
	[-45.0, -6.0, 3.3, 3.3, -99.0],
	[-39.0, 5.0, 3.3, 3.3, -99.0],
	[-31.0, 4.5, 3.3, 3.3, -99.0],
	[-9.5, 9.5, 3.3, 3.3, -99.0],
	[-9.0, 21.0, 3.3, 3.3, -99.0],
	[-31.0, 19.0, 3.3, 3.3, -99.0],
	[-48.0, -30.0, 3.3, 3.3, -99.0],
	[-24.0, -33.0, 3.3, 3.3, -99.0],
	[-14.0, -31.0, 3.3, 3.3, -99.0],
	[-30.0, -46.0, 3.3, 3.3, -99.0],
	[-52.0, -46.0, 3.3, 3.3, -99.0],
	[-1.5, 12.0, 3.0, 2.8, 8.3],
	[14.5, 12.0, 3.2, 2.8, 8.3],
	[14.5, 39.5, 2.5, 2.0, -99.0],
	[38.0, 3.5, 4.0, 3.5, -99.0],
	[40.0, -67.0, 3.0, 2.7, -99.0],
	[16.5, 54.8, 3.0, 2.4, -99.0],
	[24.5, 52.5, 3.0, 2.4, -99.0],
	[31.5, 53.0, 3.0, 2.4, -99.0],
]

static var _levels: Array = []

static func ss(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func torrent_center(z: float) -> float:
	return TORRENT_X + TORRENT_SWING * sin(z * 0.04 + 0.6)

static func torrent_half(z: float) -> float:
	return TORRENT_HALF + (MOUTH_HALF - TORRENT_HALF) * ss(46.0, 62.0, z)

static func shore(x: float) -> float:
	return 60.0 + 2.0 * sin(x * 0.06 + 0.5)

static func ridge(z: float) -> float:
	return 15.5 - 0.19 * z

static func west_slope(x: float, z: float) -> float:
	var d := x - RIDGE_X
	var soft := sqrt(d * d + 4.0)
	var down_east := 0.12 * (soft + d) * 0.5
	var down_west := 0.22 * (soft - d) * 0.5
	return ridge(z) - down_east - down_west + 0.25 * sin(x * 0.13 + 0.7) * cos(z * 0.11)

static func east_slope(x: float, z: float) -> float:
	var h := 0.5 + 0.1625 * (60.0 - z) if z >= BRIDGE_Z else BRIDGE_LOW + 0.24 * (BRIDGE_Z - z)
	return h + 0.035 * maxf(0.0, x - 12.0)

static func smooth(x: float, z: float) -> float:
	var tc := torrent_center(z)
	return lerpf(west_slope(x, z), east_slope(x, z), ss(tc - 1.5, tc + 1.5, x))

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var v := b - a
	var t := clampf((p - a).dot(v) / v.length_squared(), 0.0, 1.0)
	return p.distance_to(a + v * t)

static func line_dist(p: Vector2, line: Array) -> float:
	var d := INF
	for n in range(line.size() - 1):
		d = minf(d, seg_dist(p, line[n], line[n + 1]))
	return d

static func box_dist(p: Vector2, cx: float, cz: float, hx: float, hz: float) -> float:
	var dx := maxf(absf(p.x - cx) - hx, 0.0)
	var dz := maxf(absf(p.y - cz) - hz, 0.0)
	return sqrt(dx * dx + dz * dz)

static func terraced(s: float) -> float:
	return floorf(s / TERRACE_STEP) * TERRACE_STEP

static func stairs(s: float) -> float:
	return floorf(s / STAIR_STEP) * STAIR_STEP

static func pad_level(i: int) -> float:
	if _levels.is_empty():
		for pd in PADS:
			_levels.append(float(pd[4]) if float(pd[4]) > -50.0 else smooth(pd[0], pd[1]))
	return _levels[i]

static func in_mule_gap(p: Vector2) -> bool:
	return p.y > MULE_GAP.x and p.y < MULE_GAP.y and line_dist(p, MULE) < PATH_HALF + BLEND

static func stairs_dist(p: Vector2) -> float:
	return minf(line_dist(p, MULE), minf(line_dist(p, TERRACE_PATH), line_dist(p, FARM_LANE)))

static func ramp_level(p: Vector2) -> float:
	var a: Vector2 = MILL_RAMP[0]
	var b: Vector2 = MILL_RAMP[1]
	var v := b - a
	var t := clampf((p - a).dot(v) / v.length_squared(), 0.0, 1.0)
	return lerpf(SHELF_H, pad_level(TANK_PAD), t)

static func fallen_level(p: Vector2) -> float:
	var low := terraced(smooth(p.x, FALLEN.end.y))
	var t := (FALLEN.end.y - p.y) / FALLEN.size.y
	return lerpf(low, low + TERRACE_STEP, ss(0.15, 0.85, t))

static func _east_ground(p: Vector2, s: float) -> float:
	var h := s
	if p.y < TERRACE_SOUTH and p.y > TERRACE_NORTH:
		h = terraced(s)
		if FALLEN.has_point(p): h = fallen_level(p)
	var dc := line_dist(p, CART)
	if dc < CART_HALF + BLEND:
		h = lerpf(s, h, ss(CART_HALF, CART_HALF + BLEND, dc))
	var dr := line_dist(p, MILL_RAMP)
	if dr < PATH_HALF + BLEND:
		h = lerpf(ramp_level(p), h, ss(PATH_HALF, PATH_HALF + BLEND, dr))
	var dst := stairs_dist(p)
	if dst < PATH_HALF + BLEND and not in_mule_gap(p):
		h = lerpf(stairs(s), h, ss(PATH_HALF, PATH_HALF + BLEND, dst))
	return h

static func _pads(p: Vector2, h: float) -> float:
	var dp := maxf(0.0, p.distance_to(Vector2(PIAZZA.x, PIAZZA.z)) - PIAZZA_R)
	if dp < PAD_EDGE: h = lerpf(PIAZZA.y, h, ss(0.0, PAD_EDGE, dp))
	for i in PADS.size():
		var pd: Array = PADS[i]
		var d := box_dist(p, pd[0], pd[1], pd[2], pd[3])
		if d < PAD_EDGE: h = lerpf(pad_level(i), h, ss(0.0, PAD_EDGE, d))
	return h

static func _torrent(x: float, z: float, h: float) -> float:
	var hw := torrent_half(z)
	var d := absf(x - torrent_center(z))
	if d >= hw + 1.0: return h
	if d < hw: return minf(h, lerpf(-1.1, -0.6, ss(hw - 1.5, hw, d)))
	return minf(h, lerpf(-0.5, h, ss(hw, hw + 1.0, d)))

static func _gullies(x: float, h: float) -> float:
	for gx in [GULLY_W, GULLY_E]:
		var d := absf(x - gx)
		if d < GULLY_HALF: h = minf(h, lerpf(-1.0, -0.6, ss(GULLY_HALF - 1.0, GULLY_HALF, d)))
		elif d < GULLY_HALF + GULLY_BANK: h = minf(h, lerpf(-0.5, h, ss(GULLY_HALF, GULLY_HALF + GULLY_BANK, d)))
	return h

static func _sea(x: float, z: float, h: float) -> float:
	var sh := shore(x)
	if z < sh - 6.0: return h
	if x < -6.0 or x > 46.0:
		if z > sh - 1.0: return minf(h, lerpf(-1.2, -3.0, ss(sh - 1.0, sh + 6.0, z)))
		return h
	if z < sh: return minf(h, lerpf(h, -0.35, ss(sh - 5.0, sh, z)))
	return minf(h, lerpf(-0.35, -2.6, ss(sh, sh + 8.0, z)))

static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var s := smooth(x, z)
	var h := s
	if x > torrent_center(z): h = _east_ground(p, s)
	h = _pads(p, h)
	h = _gullies(x, h)
	if z < CRAG_Z: h += CRAG_RISE
	h = _torrent(x, z, h)
	if SHELF.has_point(p): h = SHELF_H
	return _sea(x, z, h)

static func is_stream_cell(i: float, k: float) -> bool:
	var x := i + 0.5
	var z := k + 0.5
	if z < CRAG_Z + 2.0 or z > 50.0: return false
	if absf(z - BRIDGE_Z) < BRIDGE_HALF + 0.6: return false
	if absf(x - torrent_center(z)) > torrent_half(z) + 0.2: return false
	return height(x, z) < Heightfield.WALKABLE_MIN

const C_TERRACE := [Color("cdb36b"), Color("b8a35a"), Color("a8946a")]
const C_WOODS := Color("5f7d3c")
const C_SCRUB := Color("8c9a55")
const C_VILLAGE := Color("b5a868")
const C_GRAVEL := Color("c8b48e")
const C_STAIRS := Color("b3a891")
const C_ROCK := Color("8f8a7e")
const C_WALL := Color("a89f8d")
const C_PEBBLES := Color("cfc6b4")
const C_BED := Color("8a8578")
const C_SEABED := Color("b9ad94")

static func _bare(c: Color) -> Color: return Color(c.r, c.g, c.b, 0.0)

static func _grown(c: Color, a: float) -> Color: return Color(c.r, c.g, c.b, a)

static func steep(x: float, z: float, h: float) -> bool:
	var d := 0.0
	for o in [Vector2(0.5, 0.0), Vector2(-0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.0, -0.5)]:
		d = maxf(d, absf(height(x + o.x, z + o.y) - h))
	return d > 0.8

static func paint(x: float, z: float) -> Color:
	var h := height(x, z)
	var p := Vector2(x, z)
	var n := 0.5 + 0.25 * sin(x * 0.37 + cos(z * 0.21) * 2.0) + 0.25 * sin(z * 0.43 + sin(x * 0.19) * 2.0)
	var tc := torrent_center(z)
	if h < Heightfield.WALKABLE_MIN:
		if z > shore(x) - 1.0: return _bare(C_SEABED.lerp(C_PEBBLES, n * 0.4))
		return _bare(C_BED.lerp(C_ROCK, n * 0.5))
	if z < CRAG_Z: return _bare(C_ROCK.lerp(C_ROCK.lightened(0.12), n))
	if SHELF.has_point(p): return _bare(C_STAIRS.darkened(0.12))
	if absf(x - tc) < torrent_half(z) + 1.2 and h > 0.6: return _bare(C_ROCK.lerp(C_ROCK.darkened(0.12), n))
	if absf(absf(x) - GULLY_E) < GULLY_HALF + 2.0: return _bare(C_ROCK.lerp(C_ROCK.darkened(0.1), n))
	if z > shore(x) - 6.0 and h < 1.6: return _bare(C_PEBBLES.lerp(C_PEBBLES.darkened(0.08), n))
	if x > tc:
		if line_dist(p, CART) < CART_HALF: return _bare(C_GRAVEL.lerp(C_GRAVEL.darkened(0.1), n))
		if line_dist(p, MILL_RAMP) < PATH_HALF or (stairs_dist(p) < PATH_HALF and not in_mule_gap(p)):
			return _bare(C_STAIRS.lerp(C_STAIRS.darkened(0.12), n))
		if FALLEN.has_point(p): return _bare(C_ROCK.lerp(C_TERRACE[2], 0.5))
		if z < TERRACE_NORTH: return _grown(C_WOODS.lerp(C_WOODS.darkened(0.15), n), 1.0)
		if z < TERRACE_SOUTH:
			if steep(x, z, h): return _bare(C_WALL.lerp(C_WALL.darkened(0.18), n))
			var g: Color = C_TERRACE[0].lerp(C_TERRACE[1], n)
			return _grown(g.lerp(C_TERRACE[2], 0.25 * sin(x * 0.11 + z * 0.07) + 0.25), 0.35)
		return _grown(C_SCRUB.lerp(C_TERRACE[1], n * 0.5), 0.85)
	if z < -66.0: return _grown(C_WOODS.lerp(C_WOODS.darkened(0.15), n), 1.0)
	if x < RIDGE_X - 8.0 or z > 26.0: return _grown(C_SCRUB.lerp(C_SCRUB.darkened(0.1), n), 0.9)
	return _grown(C_VILLAGE.lerp(C_TERRACE[0], n * 0.5), 0.45)

const Models := preload("olive_village/models.gd")
const Scenery := preload("olive_village/scenery.gd")

static func building(b: Dictionary) -> Node3D:
	return Models.build(b)

static func dress(village: Node3D) -> void:
	Scenery.dress(village)

static func far_height(x: float, z: float) -> float:
	var cx := clampf(x, -MAP_HALF, MAP_HALF)
	var cz := clampf(z, -MAP_HALF, MAP_HALF)
	var edge := height(cx, cz)
	var beyond := Vector2(x - cx, z - cz).length()
	var hill := 12.0 + 30.0 * ss(0.0, 260.0, beyond) + 6.0 * sin(x * 0.021 + 1.3) * cos(z * 0.017)
	var head := 1.0 - ss(40.0, 95.0, Vector2((x - 300.0) * 0.7, z - 105.0).length())
	var coast := shore(x) + 70.0 * head
	if z > coast - 18.0: hill = lerpf(hill, -3.0, ss(coast - 18.0, coast + 4.0, z))
	return lerpf(edge, hill, ss(0.0, 40.0, beyond))
