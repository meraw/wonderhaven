extends RefCounted

const P := preload("../world/palette.gd")
const Palazzo := preload("port/palazzo.gd")
const Landmarks := preload("port/landmarks.gd")
const Scenery := preload("port/scenery.gd")
const Horizon := preload("port/horizon.gd")
const Life := preload("port/life.gd")

const SEA := -3.0
const GAP_BED := -1.0
const QUAY_H := 1.2
const MID_H := 10.0
const TOP_H := 20.0
const BW_H := 0.4
const ROCK_H := 1.6
const EAST_H := 1.4
const MOUNTAIN_BASE := 28.0

const WEST_X := -46.0
const MID_EAST_X := 56.0
const TOP_EAST_X := 60.0
const NECK_Z := -84.0
const BAND_A := Vector2(-34.0, -22.0)
const BAND_B := Vector2(12.0, 22.0)
const QUAYS := Rect2(-60.0, 22.0, 102.0, 20.0)
const TIP := Rect2(42.0, 22.0, 16.0, 18.0)
const STRIP_EAST_X := 70.0
const STRIP_SOUTH_Z := 30.0
const STRIP_NORTH_Z := -62.0
const BREAKWATER_Z := Vector2(42.0, 76.0)
const BREAKWATER_X := Vector2(38.0, 41.0)
const BREAKWATER_HALF := 2.0
const GAP_Z := Vector2(54.0, 61.0)
const ROCK_CENTRE := Vector2(42.0, 82.0)
const ROCK_RADII := Vector2(11.0, 8.0)
const SPURS := [Rect2(-46.0, -84.0, 8.0, 9.0), Rect2(50.0, -84.0, 10.0, 8.0)]
const CARVED := [[Rect2(-9.0, 15.5, 13.0, 6.5), QUAY_H], [Rect2(8.0, 15.5, 12.0, 6.5), QUAY_H], [Rect2(38.0, 77.0, 8.0, 4.5), ROCK_H], [Rect2(39.0, 81.5, 6.0, 6.0), ROCK_H]]
const LANES := [Rect2(-13.0, -34.0, 4.0, 12.0), Rect2(14.0, -34.0, 4.0, 12.0), Rect2(-13.0, 12.0, 4.0, 10.0), Rect2(4.0, 12.0, 4.0, 10.0), Rect2(44.0, 12.0, 4.0, 10.0)]
const RAIL := {"z": -81.5, "x0": -38.0, "x1": 50.0, "y": 20.0}

const WORLD_FLAGS := ["port_lift_on"]
const WARMTH := Vector3(0.95, 0.98, 1.1)

static func _inside(r: Rect2, x: float, z: float) -> bool:
	return x >= r.position.x and x < r.end.x and z >= r.position.y and z < r.end.y

static func coast_north(x: float) -> float:
	if x < WEST_X: return -96.0 + 3.0 * sin(x * 0.07)
	if x >= TOP_EAST_X: return -90.0 + 3.0 * sin(x * 0.09 + 1.0)
	return NECK_Z

static func mountain(x: float, z: float) -> float:
	return MOUNTAIN_BASE + 0.55 * (coast_north(x) - z) + 2.5 * sin(x * 0.11) * cos(z * 0.07) + 1.5 * sin(x * 0.031 + z * 0.05)

static func breakwater_x(z: float) -> float:
	return lerpf(BREAKWATER_X.x, BREAKWATER_X.y, clampf((z - BREAKWATER_Z.x) / (BREAKWATER_Z.y - BREAKWATER_Z.x), 0.0, 1.0))

static func on_breakwater(x: float, z: float) -> bool:
	return z >= BREAKWATER_Z.x and z < BREAKWATER_Z.y and absf(x - breakwater_x(z)) < BREAKWATER_HALF

static func in_gap(x: float, z: float) -> bool:
	return on_breakwater(x, z) and z >= GAP_Z.x and z < GAP_Z.y

static func on_rock(x: float, z: float) -> bool:
	var dx := (x - ROCK_CENTRE.x) / ROCK_RADII.x
	var dz := (z - ROCK_CENTRE.y) / ROCK_RADII.y
	return dx * dx + dz * dz < 1.0 + 0.06 * sin(atan2(dz, dx) * 5.0)

static func on_east_rocks(x: float, z: float) -> bool:
	if _inside(TIP, x, z) and z < TIP.end.y + 1.2 * sin(x * 0.3) - 1.2: return true
	if x >= STRIP_EAST_X + 1.5 * sin(z * 0.21): return false
	if z >= BAND_A.x and z < STRIP_SOUTH_Z: return x >= MID_EAST_X
	if z >= STRIP_NORTH_Z and z < BAND_A.x: return x >= TOP_EAST_X
	return false

static func level(x: float, z: float) -> String:
	if z < coast_north(x): return "mountain"
	if x >= WEST_X and x < TOP_EAST_X and z >= NECK_Z and z < BAND_A.x:
		for s in SPURS:
			if _inside(s, x, z): return "mountain"
		return "top"
	if x >= WEST_X and x < MID_EAST_X:
		if z >= BAND_A.x and z < BAND_A.y: return "band_a"
		if z >= BAND_A.y and z < BAND_B.x: return "middle"
		if z >= BAND_B.x and z < BAND_B.y: return "band_b"
	if _inside(QUAYS, x, z): return "quay"
	if on_east_rocks(x, z): return "rocks"
	if on_breakwater(x, z): return "gap" if in_gap(x, z) else "breakwater"
	if on_rock(x, z): return "rock"
	return "sea"

static func height(x: float, z: float) -> float:
	for c in CARVED:
		if _inside(c[0], x, z): return float(c[1])
	match level(x, z):
		"mountain":
			var m := mountain(x, z)
			for s in SPURS:
				if _inside(s, x, z): m = maxf(m, TOP_H + 10.0)
			return m
		"top": return TOP_H
		"band_a": return lerpf(TOP_H, MID_H, (z - BAND_A.x) / (BAND_A.y - BAND_A.x))
		"middle": return MID_H
		"band_b": return lerpf(MID_H, QUAY_H, (z - BAND_B.x) / (BAND_B.y - BAND_B.x))
		"quay": return QUAY_H
		"rocks": return EAST_H + 0.12 * sin(x * 0.7 + z * 0.3) * cos(z * 0.5)
		"gap": return GAP_BED
		"breakwater":
			if z < BREAKWATER_Z.x + 4.0: return lerpf(QUAY_H, BW_H, (z - BREAKWATER_Z.x) / 4.0)
			if z >= BREAKWATER_Z.y - 4.0: return lerpf(BW_H, ROCK_H, (z - (BREAKWATER_Z.y - 4.0)) / 4.0)
			return BW_H
		"rock": return ROCK_H + 0.2 * sin(x * 0.9) * cos(z * 0.8)
	return SEA

static func _noise(x: float, z: float) -> float:
	return 0.5 + 0.25 * sin(x * 0.37 + z * 0.11) + 0.25 * cos(z * 0.29 - x * 0.13)

static func paint(x: float, z: float) -> Color:
	var n := _noise(x, z)
	match level(x, z):
		"mountain":
			var c := Color("a39d8e").lerp(Color("7f8f5c"), clampf(n * 1.4 - 0.25, 0.0, 1.0))
			return Color(c.r, c.g, c.b, 0.0)
		"top":
			var g := Color("a9b277").lerp(Color("96a465"), n)
			return Color(g.r, g.g, g.b, 0.7)
		"band_a", "band_b", "middle": return _bare(Color("c4bba9"))
		"quay": return _bare(Color("cfc7b5"))
		"rocks", "rock": return _bare(cool(Color("c8c4ba").lerp(Color("aca89e"), n)))
		"breakwater", "gap": return _bare(cool(Color("bdb7ab")))
	return _bare(Color("8c9a8f"))

static func _bare(c: Color) -> Color: return Color(c.r, c.g, c.b, 0.0)

static func cool(c: Color) -> Color: return Color(c.r * WARMTH.x, c.g * WARMTH.y, minf(1.0, c.b * WARMTH.z))

static func is_stream_cell(_i: float, _k: float) -> bool: return false

static func adjust(layout: Dictionary, flags: Dictionary) -> void:
	if not flags.get("port_lift_on", false): return
	var have: Array = layout.features.map(func(f): return String(f.get("id", "")))
	for s in layout.get("port_lift_stops", []):
		if not have.has(String(s.id)): layout.features.append(s.duplicate(true))

static func node(n: Dictionary) -> Node3D:
	if n.kind == "chop" and String(n.id).begins_with("port_driftwood"): return _driftwood(n)
	return null

static func _driftwood(n: Dictionary) -> Node3D:
	var g := Node3D.new()
	var start := absf(float(n.x) * 1.7 + float(n.z) * 0.9)
	var greys := ["9b8a72", "a89a83", "8a7a64", "b3a58e"]
	for i in 5:
		var a := start + i * 1.37
		var length := 1.4 + 0.5 * fmod(a * 3.1, 1.0)
		var r := 0.09 + 0.05 * fmod(a * 7.3, 1.0)
		var piece := P.mi(P.cyl(r, r * 1.1, length, 8), P.wood(Color(greys[i % greys.size()])), Vector3(0.35 * sin(a * 2.0), r + 0.16 * floorf(i / 2.0), 0.3 * cos(a * 2.0)))
		piece.rotation = Vector3(PI / 2.0, a, 0.15 * sin(a))
		g.add_child(piece)
	return g

static func ground_fn() -> Callable:
	return func(x: float, z: float) -> float: return height(x, z)

static func base_of(b: Dictionary) -> float:
	return float(b.y) if b.has("y") else maxf(0.0, height(float(b.x), float(b.z)))

static func building(b: Dictionary) -> Node3D:
	var base := base_of(b)
	match String(b.kind):
		"port_palazzo", "port_room", "port_lift_house", "port_stair_hut": return Palazzo.build(b, base, ground_fn())
		"port_station": return Landmarks.station(b, base, ground_fn())
		"port_church": return Landmarks.church(b)
		"port_castle": return Landmarks.castle(b)
		"port_lighthouse": return Landmarks.lighthouse(b)
		"port_lantern": return Landmarks.lantern(b)
		"port_solid": return Node3D.new()
	return _plain(b, base)

static func _plain(b: Dictionary, base: float) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w)
	var d := float(b.d)
	var h := float(b.get("h", 10.0))
	var low := base
	for fx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		for fz in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			low = minf(low, maxf(SEA, height(float(b.x) + fx * w, float(b.z) + fz * d)))
	var drop := base - low
	var total := h + drop
	g.add_child(P.mi(P.box(w, total, d), P.plaster(Color(String(b.get("wall", "d4a24c")))), Vector3(0.0, total / 2.0 - drop, 0.0)))
	return g

static func dress(village: Node3D) -> void:
	Scenery.dress(village, ground_fn(), LANES, RAIL)
	Horizon.dress(village, ground_fn())
	var life := Life.new()
	life.name = "port_life"
	village.add_child(life)
	life.setup(village.get_parent(), village)
