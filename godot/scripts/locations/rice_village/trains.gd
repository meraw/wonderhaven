extends Node3D
## The main line in motion: trains running past on the timetable (timetable.gd) and the level crossing, whose
## barriers come down, red lights blink and, while it's closed, bodies across the crossing keep everyone off the line
## (WalkWorld's moving bodies). Anyone standing on the crossing as it closes steps back off it.
const P := preload("res://scripts/world/palette.gd")
const TT := preload("res://scripts/locations/rice_village/timetable.gd")
const Buildings := preload("res://scripts/locations/rice_village/buildings.gd")
const Sounds := preload("res://scripts/locations/rice_village/sounds.gd")

const RAIL_Y := 0.62                         # top of the railway bed
const GAP := Rect2(-0.6, -49.8, 5.2, 5.6)    # the road over the line, between the two blocks of the railway bed
const SOUTH_POST := Vector3(4.4, 0.0, -43.9)
const NORTH_POST := Vector3(-0.4, 0.0, -50.1)

var game = null
var trains: Dictionary = {}     # "day:n" -> Node3D
var bodies: Array = []           # moving bodies across both mouths of the crossing
var arms: Array = []             # [pivot, which way it swings up]
var lamps: Array = []            # red lamp materials, two per side
var lamp_lights: Array = []
var arm_down := 0.0
var was_closed := false
var t := 0.0
var _mats: Dictionary = {}
var honked: Dictionary = {}      # trains that have sounded their horn, "day:n"
var bell_t := 0.0
var rumble_t := 0.0

func setup(g, village: Node3D) -> void:
	game = g
	_build_crossing(village)
	if g != null and g.get("walk") != null:
		for z in [GAP.position.y + 0.5, GAP.end.y - 0.5]:
			for x in [0.2, 2.0, 3.8]:
				var bd := {"x": x, "z": z, "r": 0.0}
				bodies.append(bd); g.walk.dynamic.append(bd)

func _clock() -> Dictionary:
	if game == null or game.get("state") == null: return {}
	return game.state.time

func _process(dt: float) -> void:
	var tm := _clock()
	if tm.is_empty() or game.get("traveling"): return
	t += dt
	var day := int(tm.day); var minute := float(tm.minute)
	var stopping: bool = game.state.flags.get(TT.STOP_FLAG, false)
	var closed := TT.crossing_closed(day, minute, stopping)
	if closed and not was_closed: _clear_crossing()
	was_closed = closed
	for bd in bodies: bd.r = 0.95 if closed else 0.0
	arm_down = move_toward(arm_down, 1.0 if closed else 0.0, dt / 2.2)
	for a in arms: (a[0] as Node3D).rotation.z = a[1] * (1.0 - arm_down) * PI / 2.0 * 0.97
	var blink := closed and fmod(t, 1.0) < 0.5
	for i in lamps.size():
		var on := closed and ((i % 2 == 0) == blink)
		(lamps[i] as StandardMaterial3D).emission_energy_multiplier = 2.6 if on else 0.0
	for li in lamp_lights: (li as OmniLight3D).visible = closed and game.state.flags.get("night", false)
	_run_trains(day, minute, stopping)
	_sounds(dt, day, minute, closed, stopping)

## The crossing's bells while the barriers come down, each train's horn as it nears the crossing, and its rumble
## as it passes you.
func _sounds(dt: float, day: int, minute: float, closed: bool, stopping: bool) -> void:
	var p: Vector3 = game.player.pos
	var to_crossing := Vector2(p.x - TT.CROSS_X, p.z - (TT.EAST_Z + TT.WEST_Z) / 2.0).length()
	bell_t -= dt
	if closed and arm_down < 0.999 and bell_t <= 0.0:
		bell_t = 0.5
		Sounds.crossing_bell(game, Sounds.by_distance(to_crossing, 10.0, 60.0))
	rumble_t -= dt
	var nearest := 1000.0
	for tr in TT.on_line(day, minute, stopping):
		var key := "%d:%d" % [tr.day, tr.n]
		var ahead: float = (TT.CROSS_X - float(tr.front)) * float(tr.dir)   # metres still to go to the crossing
		if ahead > 0.0 and ahead < 160.0 and not honked.has(key):
			honked[key] = true
			Sounds.horn(game, Sounds.by_distance(Vector2(p.x - float(tr.front), p.z - float(tr.z)).length(), 30.0, 200.0))
		if tr.stopped: continue   # waiting at the platform: quiet
		var x0 := minf(tr.front, tr.front - tr.dir * tr.length); var x1 := maxf(tr.front, tr.front - tr.dir * tr.length)
		nearest = minf(nearest, Vector2(p.x - clampf(p.x, x0, x1), p.z - float(tr.z)).length())
	if nearest < 70.0 and rumble_t <= 0.0:
		rumble_t = 0.28
		Sounds.rumble(game, Sounds.by_distance(nearest, 6.0, 70.0), nearest < 30.0)
	if honked.size() > 40: honked.clear()

## Someone on the crossing as the bells start steps back to the nearer side.
func _clear_crossing() -> void:
	var p: Vector3 = game.player.pos
	if not GAP.has_point(Vector2(p.x, p.z)): return
	var south := p.z > TT.WEST_Z - 1.0
	game.player.teleport(clampf(p.x, 1.0, 3.0), GAP.end.y + 0.6 if south else GAP.position.y - 0.6)
	if game.has_method("toast"): game.toast("Ding, ding, ding: you step back from the crossing.", "", 2.5)

func _run_trains(day: int, minute: float, stopping: bool = false) -> void:
	var seen := {}
	var night: bool = game.state.flags.get("night", false)
	for tr in TT.on_line(day, minute, stopping):
		var key := "%d:%d" % [tr.day, tr.n]
		seen[key] = true
		if not trains.has(key):
			var m := train_model(tr.kind)
			m.rotation.y = 0.0 if tr.dir > 0 else PI
			add_child(m); trains[key] = m
		var node: Node3D = trains[key]
		node.position = Vector3(tr.front, RAIL_Y, tr.z)
	for key in trains.keys():
		if not seen.has(key): trains[key].queue_free(); trains.erase(key)
	for m in _mats.get("windows", []): (m as StandardMaterial3D).emission_energy_multiplier = 1.6 if night else 0.0
	for m in _mats.get("heads", []): (m as StandardMaterial3D).emission_energy_multiplier = 3.0 if night else 0.8

# ---- The crossing -----------------------------------------------------------------------------------------------
func _build_crossing(village: Node3D) -> void:
	for spec in [[SOUTH_POST, -1.0], [NORTH_POST, 1.0]]:
		var base: Vector3 = spec[0]
		var post := Node3D.new(); post.position = Vector3(base.x, Heightfield.height(base.x, base.z), base.z)
		village.add_child(post)
		post.add_child(P.mi(P.cyl(0.12, 0.16, 1.1, 10), P.mat("e8e4dc"), Vector3(0, 0.55, 0)))
		post.add_child(P.mi(P.box(0.5, 0.6, 0.4), P.mat("9aa0a6"), Vector3(0, 0.3, 0)))
		# the arm: red and white stripes, pivoting up out of the way
		var pivot := Node3D.new(); pivot.position = Vector3(0, 1.0, 0); post.add_child(pivot)
		var dir: float = spec[1]
		for k in 8:
			pivot.add_child(P.mi(P.box(0.58, 0.12, 0.08), P.mat("d23a32" if k % 2 == 0 else "f4f1ea"), Vector3(dir * (0.45 + k * 0.58), 0, 0)))
		arms.append([pivot, dir])
		# the St Andrew's cross and two red lamps, on their own pole beside the road
		var cross := Node3D.new(); cross.position = Vector3(base.x - dir * 0.9, Heightfield.height(base.x, base.z), base.z - dir * 0.7)
		village.add_child(cross)
		cross.add_child(P.mi(P.cyl(0.05, 0.05, 2.6, 8), P.mat("7d8288"), Vector3(0, 1.3, 0)))
		for a in [0.7, -0.7]:
			var bar := P.mi(P.box(1.0, 0.14, 0.04), P.mat("f4f1ea"), Vector3(0, 2.35, 0.04)); bar.rotation.z = a; cross.add_child(bar)
			var rim := P.mi(P.box(1.05, 0.04, 0.03), P.mat("d23a32"), Vector3(0, 2.35, 0.065)); rim.rotation.z = a; cross.add_child(rim)
		cross.add_child(P.mi(P.box(0.7, 0.24, 0.12), P.mat("2b2826"), Vector3(0, 1.75, 0.0)))
		for x in [-0.22, 0.22]:
			var m := P.unique_mat("6e1e18", "ff2a1a", 0.0)
			cross.add_child(P.mi(P.cyl(0.09, 0.09, 0.06, 12), m, Vector3(x, 1.75, 0.08), false))
			cross.get_child(cross.get_child_count() - 1).rotation.x = PI / 2
			lamps.append(m)
		cross.rotation.y = 0.0 if dir < 0 else PI
		var li := OmniLight3D.new(); li.light_color = Color("ff3a20"); li.omni_range = 5.0; li.light_energy = 1.2; li.visible = false
		li.position = Vector3(0, 1.8, 0.4); cross.add_child(li); lamp_lights.append(li)

# ---- Train models -----------------------------------------------------------------------------------------------
## A train built along -x from its front at the origin, sitting on the rails.
func train_model(kind: String) -> Node3D:
	var g := Node3D.new(); g.name = "train_" + kind
	var k: Dictionary = TT.KINDS[kind]
	var x := 0.0
	if float(k.loco) > 0.0:
		_loco(g, kind, x, float(k.loco)); x -= float(k.loco) + 0.6
	for c in int(k.cars):
		_car(g, kind, x, float(k.car), c == 0 and float(k.loco) == 0.0, c == int(k.cars) - 1 and float(k.loco) == 0.0); x -= float(k.car) + 0.6
	return g

func _mat(key: String, color: String, emissive: String = "", group: String = "") -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m: StandardMaterial3D = P.unique_mat(color, emissive, 0.0) if emissive != "" else P.mat(color)
	_mats[key] = m
	if group != "":
		if not _mats.has(group): _mats[group] = []
		_mats[group].append(m)
	return m

const LIVERY := {
	"regional": ["f1eee6", "c8322b", "9aa0a6"],
	"intercity": ["ebe8df", "3f7a52", "8f969b"],
	"freight": ["7a4a35", "5e3a2a", "6f6a64"],
	"night_express": ["2c3e6b", "e3d7b8", "7d8590"],
	"inspection": ["f2c230", "2b2826", "c9a227"],
}

func _bogies(g: Node3D, x0: float, length: float) -> void:
	for bx in [x0 - 2.2, x0 - length + 2.2]:
		g.add_child(P.mi(P.box(2.6, 0.5, 2.2), _mat("bogie", "2b2826"), Vector3(bx, 0.45, 0)))

func _loco(g: Node3D, kind: String, x0: float, length: float) -> void:
	var lv: Array = LIVERY[kind]
	var body := _mat("body_" + kind, lv[0]); var band := _mat("band_" + kind, lv[1])
	g.add_child(P.mi(P.rbox(length, 2.8, 2.9, 0.25), body, Vector3(x0 - length / 2.0, 2.2, 0)))
	g.add_child(P.mi(P.box(length + 0.02, 0.5, 2.94), band, Vector3(x0 - length / 2.0, 1.25, 0)))
	g.add_child(P.mi(P.box(0.06, 0.8, 2.3), _mat("glass", "2d3a44"), Vector3(x0 + 0.02, 2.75, 0)))
	g.add_child(P.mi(P.box(0.06, 0.8, 2.3), _mat("glass", "2d3a44"), Vector3(x0 - length - 0.02, 2.75, 0)))
	for z in [-0.9, 0.9]:
		g.add_child(P.mi(P.cyl(0.13, 0.13, 0.06, 10), _mat("head", "fff4d0", "fff1c0", "heads"), Vector3(x0 + 0.04, 1.6, z)))
		g.get_child(g.get_child_count() - 1).rotation.z = PI / 2
	# the pantograph reaching up to the overhead wire
	for px in [x0 - 3.0, x0 - length + 3.0]:
		g.add_child(P.mi(P.box(0.06, 1.3, 0.06), _mat("panto", "3e4743"), Vector3(px, 4.2, 0)))
		g.add_child(P.mi(P.box(0.08, 0.06, 1.4), _mat("panto", "3e4743"), Vector3(px, 4.85, 0)))
	_bogies(g, x0, length)

func _car(g: Node3D, kind: String, x0: float, length: float, cab_front: bool, cab_back: bool) -> void:
	var lv: Array = LIVERY[kind]
	var body := _mat("body_" + kind, lv[0]); var band := _mat("band_" + kind, lv[1]); var roof := _mat("roof_" + kind, lv[2])
	var cx := x0 - length / 2.0
	if kind == "freight":
		var w := int(absf(x0) * 0.37) % 3
		if w == 0:   # a tank wagon
			g.add_child(P.mi(P.cyl(1.3, 1.3, length - 1.0, 14), _mat("tank", "9aa0a6"), Vector3(cx, 2.1, 0), false))
			g.get_child(g.get_child_count() - 1).rotation.z = PI / 2
		elif w == 1:   # a covered wagon
			g.add_child(P.mi(P.rbox(length, 2.6, 2.8, 0.1), body, Vector3(cx, 2.1, 0)))
			g.add_child(P.mi(P.box(length * 0.3, 2.0, 2.84), band, Vector3(cx, 2.0, 0)))
		else:   # a flat wagon with a container
			g.add_child(P.mi(P.box(length, 0.3, 2.6), band, Vector3(cx, 1.05, 0)))
			g.add_child(P.mi(P.box(length - 1.6, 2.4, 2.4), _mat("box", "b8862e"), Vector3(cx, 2.4, 0)))
		g.add_child(P.mi(P.box(length, 0.25, 2.5), _mat("frame", "2b2826"), Vector3(cx, 0.85, 0)))
		_bogies(g, x0, length)
		return
	g.add_child(P.mi(P.rbox(length, 2.9, 2.9, 0.2), body, Vector3(cx, 2.25, 0)))
	g.add_child(P.mi(P.box(length + 0.02, 0.36, 2.94), band, Vector3(cx, 1.15, 0)))
	g.add_child(P.mi(P.rbox(length - 0.3, 0.3, 2.6, 0.12), roof, Vector3(cx, 3.75, 0)))
	g.add_child(P.mi(P.box(length - 2.4, 0.62, 2.95), _mat("win", "2d3a44", "ffe2a0", "windows"), Vector3(cx, 2.65, 0)))
	if kind == "night_express":
		g.add_child(P.mi(P.box(length + 0.02, 0.12, 2.94), band, Vector3(cx, 3.15, 0)))
	for cab in [[cab_front, x0], [cab_back, x0 - length]]:
		if not cab[0]: continue
		g.add_child(P.mi(P.box(0.06, 0.8, 2.3), _mat("glass", "2d3a44"), Vector3(cab[1] + (0.02 if cab[1] == x0 else -0.02), 2.75, 0)))
		for z in [-0.9, 0.9]:
			g.add_child(P.mi(P.cyl(0.13, 0.13, 0.06, 10), _mat("head", "fff4d0", "fff1c0", "heads"), Vector3(cab[1] + (0.04 if cab[1] == x0 else -0.04), 1.55, z)))
			g.get_child(g.get_child_count() - 1).rotation.z = PI / 2
	if (cab_front or kind == "regional") and kind != "inspection":
		g.add_child(P.mi(P.box(0.06, 1.2, 0.06), _mat("panto", "3e4743"), Vector3(cx, 4.4, 0)))
		g.add_child(P.mi(P.box(0.08, 0.06, 1.4), _mat("panto", "3e4743"), Vector3(cx, 5.0, 0)))
	_bogies(g, x0, length)
