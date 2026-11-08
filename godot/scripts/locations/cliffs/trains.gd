extends Node3D

const P := preload("res://scripts/world/palette.gd")
const RAIL_Y := 9.45
const TRACK_Z := -8.25
const STOP_X := -12.0
const SPEED := 25.0
const BRAKE := 40.0
const DWELL := 1.5
const FIRST := 310
const EVERY := 20
const LAST := 1390
const SHOW := 46.0
const CAR := 13.0

var game = null
var models := {}

static func departures() -> Array:
	var out: Array = []
	var k := 0
	var m := FIRST
	while m <= LAST:
		var stops := k % 3 != 1
		out.append({"n": k, "at": float(m), "dir": 1.0 if k % 2 == 0 else -1.0, "stops": stops, "cars": 3 if stops else 5})
		k += 1
		m += EVERY
	return out

static func brake_minutes() -> float: return 2.0 * BRAKE / SPEED

static func centre_x(dep: Dictionary, minute: float) -> float:
	var u := minute - float(dep.at)
	var dir := float(dep.dir)
	if not dep.stops: return STOP_X + dir * SPEED * u
	var tb := brake_minutes()
	if u >= 0.0 and u <= DWELL: return STOP_X
	if u < 0.0:
		var tau := -u
		if tau <= tb: return STOP_X - dir * BRAKE * pow(tau / tb, 2.0)
		return STOP_X - dir * (BRAKE + SPEED * (tau - tb))
	var after := u - DWELL
	if after <= tb: return STOP_X + dir * BRAKE * pow(after / tb, 2.0)
	return STOP_X + dir * (BRAKE + SPEED * (after - tb))

static func length_of(dep: Dictionary) -> float: return float(dep.cars) * CAR

static func active(minute: float) -> Dictionary:
	for dep in departures():
		if absf(minute - float(dep.at)) > 12.0: continue
		var x := centre_x(dep, minute)
		if absf(x) - length_of(dep) / 2.0 < SHOW: return {"dep": dep, "x": x}
	return {}

static func standing(minute: float) -> bool:
	var a := active(minute)
	return not a.is_empty() and a.dep.stops and absf(float(a.x) - STOP_X) < 0.01

func setup(g) -> void:
	game = g
	name = "cliffs_trains"
	models["regional"] = _train(3, "b8322a", "efeae0", "2a2c33")
	models["fast"] = _train(5, "f1f1ee", "2f7d55", "2a2c33")
	for m in models.values():
		m.visible = false
		add_child(m)

func _train(cars: int, body: String, band: String, glass: String) -> Node3D:
	var root := Node3D.new()
	var bm := P.mat(body)
	var am := P.mat(band)
	var gm := P.mat(glass)
	var dm := P.mat("2a2a2e")
	var rm := P.mat("9aa0a6")
	for i in cars:
		var x := (i - (cars - 1) / 2.0) * CAR
		var c := Node3D.new()
		c.position = Vector3(x, 0, 0)
		root.add_child(c)
		Props._add(c, P.box(CAR - 0.6, 1.3, 2.8), bm, Vector3(0, 1.15, 0))
		Props._add(c, P.box(CAR - 0.6, 1.3, 2.8), am, Vector3(0, 2.45, 0))
		Props._add(c, P.box(CAR - 1.4, 0.75, 2.84), gm, Vector3(0, 2.3, 0))
		Props._add(c, P.box(CAR - 0.5, 0.28, 2.6), rm, Vector3(0, 3.24, 0))
		for s in [-1.0, 1.0]:
			Props._add(c, P.box(2.4, 0.5, 2.3), dm, Vector3(s * (CAR / 2.0 - 2.2), 0.3, 0))
		for s in [-1.0, 1.0]:
			Props._add(c, P.box(0.9, 1.9, 2.86), am, Vector3(s * (CAR / 2.0 - 1.4), 1.6, 0))
	var nose := (cars / 2.0) * CAR - 0.3
	for s in [-1.0, 1.0]:
		Props._add(root, P.box(0.3, 1.0, 2.2), gm, Vector3(s * nose, 2.4, 0))
		Props._add(root, P.box(0.12, 0.25, 0.4), P.unique_mat("fff2c0", "fff2c0", 1.2), Vector3(s * (nose + 0.05), 1.0, -0.8))
		Props._add(root, P.box(0.12, 0.25, 0.4), P.unique_mat("fff2c0", "fff2c0", 1.2), Vector3(s * (nose + 0.05), 1.0, 0.8))
	return root

func _process(_dt: float) -> void:
	if game == null or game.get("state") == null: return
	var minute := float(game.state.time.minute)
	var a := active(minute)
	for k in models: models[k].visible = false
	if a.is_empty(): return
	var m: Node3D = models["regional" if a.dep.stops else "fast"]
	m.visible = true
	m.position = Vector3(float(a.x), RAIL_Y, TRACK_Z)
	m.rotation.y = 0.0 if float(a.dep.dir) > 0.0 else PI
