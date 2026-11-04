extends RefCounted
## Casalrana (rice_village): a hamlet on the rice plain in late November. The ground shape, its paint and, for now,
## plain models for its buildings. See docs/locations/rice_village.md and the layout in
## data/locations/rice_village/layout.json.
##
## North is up (negative z). The main line runs along the north on a low bed; the village sits at a crossroads in
## the middle, Cascina Grande to the east, the drained canal and the old mill to the west, the spring pool to the
## south-west and the poplar plantation to the south. Harvested paddies lie between, on a grid of raised banks,
## with puddles that mirror the sky. Past the edge the plain runs on as flooded paddies (the shared water plane).

const P := preload("res://scripts/world/palette.gd")

const FIELD := 0.12      # harvested paddy floor
const BANK := 0.42       # the raised banks between paddies, and the roads on them
const PAD := 0.42        # the flat ground under the village, the farmstead, the station and the mill
const RAIL := 0.62       # the railway bed
const LEVEE := 0.62      # the canal's banks
const BED := -0.34       # the drained canal and the dry winter paddy: below walkable ground, above the water plane
const PUDDLE := -0.6     # puddles in the stubble and the drained canal (the water plane shows through)
const POOL_DEPTH := -1.0
const EDGE := -0.8       # the flooded plain past the edge
const BANK_X := [-30.0, -18.0, 2.0, 10.0, 24.0, 38.0, 52.0]
const BANK_Z := [-38.0, -27.0, -16.0, -6.0, 6.0, 20.0, 34.0, 46.0]
const PADS := [Rect2(-19, -13, 27, 30), Rect2(12, -24, 34, 33), Rect2(-13, -43.6, 53, 13.6), Rect2(-33, -18, 9, 11)]
const COURTYARD := Rect2(19, -14, 18, 14)
const RAIL_Z := -47.0
const CANAL_X := -40.0
const WINTER := Rect2(-33.6, 7.6, 12.2, 10.8)   # the winter paddy, flooded in Water for the Winter
const POOL := Vector3(-24.0, 32.0, 4.5)          # the spring pool: x, z, radius
const PLANTATION := Rect2(6, 38, 34, 14)
const PUDDLES := [Vector4(-4.9, -20.8, 2.5, 1.8), Vector4(-8.5, 26.7, 1.4, 1.5), Vector4(33.2, 37.9, 1.6, 1.4), Vector4(-49.1, -22.9, 1.6, 1.8),
	Vector4(-6.9, 38.7, 2.5, 1.2), Vector4(-47.9, 29.0, 1.6, 1.1), Vector4(31.0, 25.8, 2.0, 1.6), Vector4(43.3, 13.9, 2.7, 0.9),
	Vector4(44.5, -33.0, 2.5, 1.9), Vector4(-49.6, 12.4, 2.0, 1.2), Vector4(-48.2, -33.1, 1.5, 2.1), Vector4(-26.2, 42.0, 1.3, 1.6),
	Vector4(16.9, 25.2, 1.5, 1.5), Vector4(32.2, 14.0, 2.0, 1.6), Vector4(42.2, 29.5, 1.4, 2.0), Vector4(-22.4, 50.7, 1.7, 1.9),
	Vector4(-4.2, 50.6, 1.3, 1.1), Vector4(-23.6, -33.6, 1.6, 1.0), Vector4(31.1, 49.9, 1.8, 0.9), Vector4(-48.8, -11.1, 2.0, 1.3),
	Vector4(-51.5, -1.1, 1.2, 1.0), Vector4(18.4, 15.9, 1.3, 2.0), Vector4(-14.2, 41.1, 1.8, 1.6), Vector4(47.8, 50.1, 1.4, 1.7),
	Vector4(-25.8, 1.6, 1.6, 2.0), Vector4(46.5, 39.2, 1.6, 2.0), Vector4(5.6, -20.4, 1.5, 1.4), Vector4(-12.8, 50.0, 1.8, 1.9),
	Vector4(-51.3, 37.4, 1.4, 1.2), Vector4(47.4, 24.1, 2.2, 1.6), Vector4(17.7, 51.3, 1.7, 1.5), Vector4(-24.9, -22.1, 1.9, 1.5),
	Vector4(-13.5, 24.5, 1.2, 1.2), Vector4(-50.2, 50.8, 1.7, 1.5)]

static func _ss(a: float, b: float, v: float) -> float: return Heightfield.ss(a, b, v)

## Distance from (x, z) to a rectangle (0 inside).
static func _box_d(x: float, z: float, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dz := maxf(maxf(r.position.y - z, 0.0), z - r.end.y)
	return sqrt(dx * dx + dz * dz)

## Distance to the nearest bank line.
static func _bank_d(x: float, z: float) -> float:
	var d := 1000.0
	for b in BANK_X: d = minf(d, absf(x - b))
	for b in BANK_Z: d = minf(d, absf(z - b))
	return d

static func _in_puddle(x: float, z: float) -> float:
	var e := 2.0
	for p in PUDDLES:
		var dx: float = (x - p.x) / p.z; var dz: float = (z - p.y) / p.w
		e = minf(e, sqrt(dx * dx + dz * dz))
	return e

static func height(x: float, z: float) -> float:
	var h := lerpf(BANK, FIELD, _ss(0.8, 1.6, _bank_d(x, z)))
	for p in PADS: h = maxf(h, lerpf(PAD, FIELD, _ss(0.0, 1.5, _box_d(x, z, p))))
	h = maxf(h, lerpf(RAIL, FIELD, _ss(2.2, 3.4, absf(z - RAIL_Z))))
	var e := _in_puddle(x, z)
	if e < 1.0: h = minf(h, lerpf(PUDDLE, h, _ss(0.55, 1.0, e)))
	var dc := absf(x - CANAL_X)
	h = maxf(h, lerpf(LEVEE, h, _ss(3.6, 5.2, dc)))
	if dc < 2.4:
		var bed := BED
		if dc < 1.3 and fposmod(z * 0.071 + 0.3, 1.0) < 0.3: bed = -0.55   # puddles left in the drained canal
		h = minf(h, lerpf(bed, h, _ss(1.9, 2.4, dc)))
	h = minf(h, lerpf(BED, h, _ss(0.0, 0.6, _box_d(x, z, WINTER.grow(-0.6)))))
	var dp := Vector2(x - POOL.x, z - POOL.y).length()
	h = minf(h, lerpf(POOL_DEPTH, h, _ss(POOL.z - 1.5, POOL.z, dp)))
	return lerpf(h, EDGE, _ss(55.0, 57.0, maxf(absf(x), absf(z))))

## The canal is the only flowing water (for waterwheels). It's drained for its winter repairs until Water for the
## Winter fills it; until then its build sites stay locked.
static func is_stream_cell(i: float, k: float) -> bool:
	return absf(i + 0.5 - CANAL_X) < 2.0 and absf(k + 0.5) < 54.0

const STUBBLE_A := Color("c8ad74")
const STUBBLE_B := Color("d4bd88")
const BANK_GRASS := Color("a2a878")
const GRAVEL := Color("cbbf9f")
const BRICK := Color("b77f66")
const BALLAST := Color("9a948c")
const MUD := Color("86745a")
const DRY_PADDY := Color("a08d66")
const GROVE := Color("88ad66")
const UNDER_POPLARS := Color("aeaa7c")

## Ground paint: stubble in the paddies, olive winter grass on the banks and levees, gravel under the village, brick in
## the farmstead's yard, ballast on the railway bed, mud in the drained canal. Only the spring pool's grove, kept green
## by its mild water, has meadow (alpha).
static func ground(x: float, z: float) -> Color:
	var dc := absf(x - CANAL_X)
	var dp := Vector2(x - POOL.x, z - POOL.y).length()
	var c: Color
	if dc < 2.3: c = MUD
	elif _box_d(x, z, WINTER.grow(-0.3)) <= 0.0: c = DRY_PADDY
	elif dp < POOL.z + 0.4: c = MUD
	elif dp < POOL.z + 6.0: return Color(GROVE.r, GROVE.g, GROVE.b, 0.8)
	elif absf(z - RAIL_Z) < 2.6: c = BALLAST
	elif _box_d(x, z, COURTYARD) <= 0.0: c = BRICK
	elif _on_pad(x, z): c = GRAVEL
	elif dc < 5.0 or _bank_d(x, z) < 1.3: c = BANK_GRASS
	elif _box_d(x, z, PLANTATION) <= 0.0: c = UNDER_POPLARS
	else:
		var cell := Vector2i(_cell(x, BANK_X), _cell(z, BANK_Z))
		c = STUBBLE_A.lerp(STUBBLE_B, fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0))
		if _in_puddle(x, z) < 1.25: c = c.lerp(MUD, 0.45)   # damp ground round a puddle
	return Color(c.r, c.g, c.b, 0.0)

static func _on_pad(x: float, z: float) -> bool:
	for p in PADS:
		if _box_d(x, z, p) <= 0.2: return true
	return false

static func _cell(v: float, lines: Array) -> int:
	var n := 0
	for l in lines:
		if v > l: n += 1
	return n

# ---- Buildings (plain shapes for stage 1; stage 2 models them properly) -------------------------------------
static func building(b: Dictionary) -> Node3D:
	if not String(b.kind).begins_with("rice_village_"): return null
	match String(b.kind):
		"rice_village_track": return _track(b)
		"rice_village_tower": return _tower(b, float(b.get("h", 16.0)), 4)
		"rice_village_dryer": return _tower(b, float(b.get("h", 12.0)), 8)
		_: return _block(b)

static func _block(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var h := float(b.get("h", 3.0))
	var wall_mat: Material = P.stone(b.wall) if String(b.kind) in ["rice_village_church", "rice_village_mill", "rice_village_barn"] else P.plaster(b.wall)
	g.add_child(P.mi(P.box(b.w, h, b.d), wall_mat, Vector3(0, h / 2.0, 0)))
	g.add_child(P.mi(P.box(b.w + 0.2, 0.35, b.d + 0.2), P.stone("b9b1a3"), Vector3(0, 0.12, 0)))
	Props._gable_roof(g, b.w, b.d, h, wall_mat, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	return g

static func _tower(b: Dictionary, h: float, sides: int) -> Node3D:
	var g := Node3D.new()
	var metal := String(b.kind) == "rice_village_dryer"
	var wall_mat: Material = P.smooth(b.wall) if metal else P.stone(b.wall)
	g.add_child(P.mi(P.box(b.w, h, b.d), wall_mat, Vector3(0, h / 2.0, 0)))
	var spire := P.mi(P.cyl(0.02, b.w * (0.62 if sides == 4 else 0.55), b.w * (1.3 if sides == 4 else 0.5), sides), P.mat(b.roof), Vector3(0, h + b.w * (0.65 if sides == 4 else 0.25), 0))
	if sides == 4: spire.rotation.y = PI / 4
	g.add_child(spire)
	return g

## The railway bed: ballast, sleepers and two tracks. The model sits at the bed's top.
static func _track(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	g.add_child(P.mi(P.box(b.w, 0.4, 3.6), P.stone(b.wall), Vector3(0, -0.18, 0)))
	var sleepers := MultiMesh.new()
	sleepers.transform_format = MultiMesh.TRANSFORM_3D
	sleepers.mesh = P.box(0.24, 0.1, 2.5)
	var n := int(b.w / 0.7)
	sleepers.instance_count = n * 2
	for t in 2:
		for k in n:
			sleepers.set_instance_transform(t * n + k, Transform3D(Basis(), Vector3(-b.w / 2.0 + 0.35 + k * 0.7, 0.04, -1.0 + t * 2.0)))
	var mm := MultiMeshInstance3D.new(); mm.multimesh = sleepers; mm.material_override = P.wood(b.roof)
	g.add_child(mm)
	for zc in [-1.0, 1.0]:
		for side in [-0.72, 0.72]:
			g.add_child(P.mi(P.box(b.w, 0.1, 0.08), P.mat("8b9097"), Vector3(0, 0.14, zc + side)))
	return g

# ---- Extra scenery ------------------------------------------------------------------------------------------
## The bus stop's pole and sign (the shared departure point is a boat, which stays hidden here).
static func dress(village) -> void:
	for f in Data.layout.features:
		if f.id != "boat": continue
		var stop := Node3D.new(); stop.name = "rice_village_busStop"
		stop.add_child(P.mi(P.cyl(0.05, 0.05, 2.4, 8), P.mat("8b9097"), Vector3(0, 1.2, 0)))
		var plate := P.mi(P.cyl(0.32, 0.32, 0.05, 20), P.mat("2f6db5"), Vector3(0, 2.3, 0))
		plate.rotation.x = PI / 2
		stop.add_child(plate)
		stop.position = Vector3(f.x, Heightfield.height(f.x, f.z), f.z)
		village.add_child(stop)
