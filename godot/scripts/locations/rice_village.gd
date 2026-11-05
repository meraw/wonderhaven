extends RefCounted
## Casalrana (rice_village): a hamlet on the rice plain in late November. The ground shape and its paint; its
## buildings, scenery and trains are in the helpers in scripts/locations/rice_village/. See docs/locations/rice_village.md and the layout in
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
const NOTCHES := [10.5, -12.5]   # where the canal's east bank is cut low: the winter paddy's inlet and the mill race (z)
const LEVEE_LOW := 0.22
const HOLES := [Vector2(11.0, 13.0), Vector2(18.0, 20.0), Vector2(26.0, 28.0)]   # where the old platform has crumbled (x from, to)
const HOLE_Z := Vector2(-44.4, -40.7)
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
	var levee := LEVEE
	if x > CANAL_X:   # low cuts in the east bank, so a waterwheel in the canal can drive a pump or a shaft beside it
		for nz in NOTCHES: levee = lerpf(LEVEE_LOW, levee, _ss(1.2, 2.2, absf(z - nz)))
	h = maxf(h, lerpf(levee, h, _ss(3.6, 5.2, dc)))
	if dc < 2.4:
		var bed := BED
		if dc < 0.8 + 0.5 * sin(z * 0.53) and fposmod(z * 0.071 + 0.3, 1.0) < 0.3: bed = -0.55   # puddles left in the drained canal
		h = minf(h, lerpf(bed, h, _ss(1.9, 2.4, dc)))
	h = minf(h, lerpf(BED, h, _ss(0.0, 0.6, _box_d(x, z, WINTER.grow(-0.6)))))
	for hx in HOLES:   # the crumbled stretches of the old platform, until The Train Stops Here decks them over
		h = minf(h, lerpf(BED, h, _ss(0.0, 0.3, _box_d(x, z, Rect2(hx.x + 0.3, HOLE_Z.x + 0.3, hx.y - hx.x - 0.6, HOLE_Z.y - HOLE_Z.x - 0.6)))))
	var dp := Vector2(x - POOL.x, z - POOL.y).length()
	h = minf(h, lerpf(POOL_DEPTH, h, _ss(POOL.z - 1.5, POOL.z, dp)))
	return lerpf(h, EDGE, _ss(55.0, 57.0, maxf(absf(x), absf(z))))

## The canal is the only flowing water (for waterwheels). It's drained for its winter repairs until Water for the
## Winter fills it; until then its build sites stay locked.
static func is_stream_cell(i: float, k: float) -> bool:
	return absf(i + 0.5 - CANAL_X) < 2.0 and absf(k + 0.5) < 54.0

const STUBBLE_A := Color("c8ad74")
const STUBBLE_B := Color("d4bd88")
const BANK_GRASS := Color("aba684")
const GRAVEL := Color("cbbf9f")
const BRICK := Color("c99d84")
const BALLAST := Color("9a948c")
const MUD := Color("a08b6c")
const DRY_PADDY := Color("a08d66")
const GROVE := Color("88ad66")
const UNDER_POPLARS := Color("aeaa7c")
const RUBBLE := Color("8a7f72")

## Ground paint: stubble in the paddies, olive winter grass on the banks and levees, gravel under the village, brick in
## the farmstead's yard, ballast on the railway bed, mud in the drained canal. Only the spring pool's grove, kept green
## by its mild water, has meadow (alpha).
static func paint(x: float, z: float) -> Color:
	var dc := absf(x - CANAL_X)
	var dp := Vector2(x - POOL.x, z - POOL.y).length()
	var c: Color
	if dc < 2.3: c = MUD
	elif _box_d(x, z, WINTER.grow(-0.3)) <= 0.0: c = DRY_PADDY
	elif dp < POOL.z + 0.4: c = MUD
	elif dp < POOL.z + 6.0: return Color(GROVE.r, GROVE.g, GROVE.b, 0.8)
	elif _in_hole(x, z): c = RUBBLE
	elif absf(z - RAIL_Z) < 2.6: c = BALLAST
	elif _box_d(x, z, COURTYARD) <= 0.0: c = BRICK
	elif _on_pad(x, z): c = GRAVEL
	elif dc < 5.0 or _bank_d(x, z) < 1.3: c = BANK_GRASS
	elif _box_d(x, z, PLANTATION) <= 0.0: c = UNDER_POPLARS
	else:
		var cell := Vector2i(_cell(x, BANK_X), _cell(z, BANK_Z))
		c = STUBBLE_A.lerp(STUBBLE_B, fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0))
		if _in_puddle(x, z) < 1.15: c = c.lerp(MUD, 0.2)   # damp ground round a puddle
	return Color(c.r, c.g, c.b, 0.0)

static func _in_hole(x: float, z: float) -> bool:
	if z < HOLE_Z.x - 0.1 or z > HOLE_Z.y + 0.1: return false
	for hx in HOLES:
		if x > hx.x - 0.1 and x < hx.y + 0.1: return true
	return false

static func _on_pad(x: float, z: float) -> bool:
	for p in PADS:
		if _box_d(x, z, p) <= 0.2: return true
	return false

static func _cell(v: float, lines: Array) -> int:
	var n := 0
	for l in lines:
		if v > l: n += 1
	return n

# ---- Buildings and scenery (scripts/locations/rice_village/) ---------------------------------------------------
const Buildings := preload("res://scripts/locations/rice_village/buildings.gd")
const Scenery := preload("res://scripts/locations/rice_village/scenery.gd")

## Casalrana's own buildings (kinds rice_village_*); anything else uses the shared models.
static func building(b: Dictionary) -> Node3D:
	if not String(b.kind).begins_with("rice_village_"): return null
	return Buildings.make(b)

## Trees, the railway's furniture, the trains and the plain past the edge.
static func dress(village) -> void: Scenery.dress(village)
