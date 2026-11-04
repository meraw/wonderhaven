class_name Heightfield
## The ground shape of the place you're on: shared by the terrain mesh, movement, building and quest checks.

const WATER_Y := -0.4
const WALKABLE_MIN := -0.3
const RIVER_HALF := 3.0
const RIVER_BANK := 0.4
const SPRING := Vector3(14, 0, 1)
const SPRING_R := 2.2
const CHANNEL := Rect2(8, 1, 4, 1)   # x 8..12, z 1..2
const CASTLE_MOUND := Vector3(30, 0.9, -5)
const CASTLE_R := 9.0

## Which island's ground this is (set by Data.use_island). Each island has its own shape below, or in its location
## pack's script (scripts/locations/<id>.gd) as static height(x, z) and, optionally, is_stream_cell(i, k).
static var island := "hearthglow"
static var _pack = null   # untyped, so its static functions can be called
static var _pack_height := false
static var _pack_stream := false

## Switch to an island's ground.
static func use(id: String) -> void:
	island = id
	var path := "res://scripts/locations/%s.gd" % id
	_pack = load(path) if ResourceLoader.exists(path) else null
	var names: Array = []
	if _pack: names = _pack.get_script_method_list().map(func(m): return m.name)
	_pack_height = names.has("height")
	_pack_stream = names.has("is_stream_cell")

# Clockwork Cove: a round island with Gearspring Hill to the north-east, a knoll with the lighthouse on the
# north-west cape, a millrace (stream channel fed by a spring) by the clock tower, and a sheltered bay in the south.
const COVE_HILL := Vector3(20, 2.6, -20)
const COVE_KNOLL := Vector3(-24, 1.2, -21)
const COVE_SPRING := Vector3(8.4, 0, -7.5)
const COVE_SPRING_R := 1.6
const COVE_CHANNEL := Rect2(10, -8, 5, 1)   # x 10..15, z -8..-7

static func ss(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func river_center(x: float) -> float:
	var w := ss(6, 16, absf(x))
	return -18.0 + w * 2.6 * sin(x * 0.07 + 0.6)

static func _island_radius(a: float) -> float:
	return 54.0 + 3.0 * sin(3.0 * a + 1.0) + 2.0 * cos(5.0 * a)

static func height(x: float, z: float) -> float:
	if _pack_height: return _pack.height(x, z)
	if island == "clockwork": return _cove(x, z)
	return _monteforchetta(x, z)

## Monteforchetta (the "hearthglow" id): a hilltop. The village and its fields are nearly level, with the castle on
## a mound; past the edge the hill falls away in long vineyard slopes to the valley floor far below. A stream runs
## through a fold in the hilltop (the washed-out road crosses it), fed by the spring by the mill channel.
const VALLEY_Y := -28.0
const SLOPE_RUN := -48.0   # how far past the edge the hillside reaches the valley floor (metres; gentle enough to see the vines)
static func _monteforchetta(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var a := atan2(z, x)
	var h := 0.12 * sin(x * 0.13 + 1.3) * cos(z * 0.11 - 0.4) * ss(28, 40, r)
	var dc := Vector2(x - CASTLE_MOUND.x, z - CASTLE_MOUND.z).length()
	h = lerpf(h, maxf(h, CASTLE_MOUND.y), 1.0 - ss(CASTLE_R - 3.0, CASTLE_R, dc))   # a level mound: the castle floor sits flat on it
	var edge := _island_radius(a) - r
	h = lerpf(VALLEY_Y, h, ss(SLOPE_RUN, 4, edge))   # the slopes down to the valley (unwalkable, like water)
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

static func _cove(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var a := atan2(z, x)
	var h := 0.14 + 0.16 * sin(x * 0.12 + 0.5) * cos(z * 0.1 - 0.3)
	var dh := Vector2(x - COVE_HILL.x, z - COVE_HILL.z).length()
	h += COVE_HILL.y * (1.0 - ss(4.5, 11.0, dh))
	# the clock tower yard is level with the millrace banks, so a waterwheel's shafts line up with the bank
	if x > 7.0 and x < 17.0 and z > -13.0 and z < -4.0: h = minf(h, 0.12)
	var dk := Vector2(x - COVE_KNOLL.x, z - COVE_KNOLL.z).length()
	h = lerpf(h, maxf(h, COVE_KNOLL.y), 1.0 - ss(5.0, 9.0, dk))
	var edge := 40.0 + 2.5 * sin(3.0 * a + 0.4) + 1.8 * cos(5.0 * a + 1.0) - r
	h = lerpf(-2.4, h, ss(-2, 6, edge))
	# the bay: the sea reaches in from the south to a sandy beach at z ~ 31
	var bay := 1.0 - ss(7.0, 13.0, absf(x - 2.0))
	if z > 26.0 and bay > 0.0: h = lerpf(h, minf(h, 0.3 - maxf(0.0, z - 30.6) * 1.2), bay)
	var ds := Vector2(x - COVE_SPRING.x, z - COVE_SPRING.z).length()
	if ds < COVE_SPRING_R + 0.4: h = minf(h, -0.8 if ds < COVE_SPRING_R else lerpf(-0.8, h, (ds - COVE_SPRING_R) / 0.4))
	if x >= COVE_CHANNEL.position.x and x <= COVE_CHANNEL.end.x and z >= COVE_CHANNEL.position.y and z <= COVE_CHANNEL.end.y: h = minf(h, -0.6)
	return h

static func is_water(x: float, z: float) -> bool: return height(x, z) < WALKABLE_MIN

static func is_stream_cell(i: float, k: float) -> bool:
	if _pack_stream: return _pack.is_stream_cell(i, k)
	var x := i + 0.5
	var z := k + 0.5
	if _pack_height: return false   # a pack's ground without streams of its own
	if island == "clockwork":
		if x >= COVE_CHANNEL.position.x and x <= COVE_CHANNEL.end.x and z >= COVE_CHANNEL.position.y and z <= COVE_CHANNEL.end.y: return true
		return Vector2(x - COVE_SPRING.x, z - COVE_SPRING.z).length() < COVE_SPRING_R
	if x >= CHANNEL.position.x and x <= CHANNEL.end.x and z >= CHANNEL.position.y and z <= CHANNEL.end.y: return true
	if Vector2(x - SPRING.x, z - SPRING.z).length() < SPRING_R: return true
	return absf(z - river_center(x)) < RIVER_HALF and sqrt(x * x + z * z) < 50.0
