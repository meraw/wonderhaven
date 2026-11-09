extends Node3D

const Terraces := preload("res://scripts/locations/cliffs/terraces.gd")
const GULL_NEAR := 3.0
const GULL_UP := 20.0
const LIZARD_NEAR := 2.5
const LIZARDS_PER_TERRACE := 2
const SEA_RING := Vector3(2.0, 11.0, 41.0)
const SWALLOW_SPOTS := [Vector3(0.0, 7.0, 26.0), Vector3(27.6, 14.0, 25.2), Vector3(-11.5, 14.0, -1.5)]
const MAIN := ["cliffs_welcome", "cliffs_hut", "cliffs_wall", "cliffs_monorail", "cliffs_path", "cliffs_easter"]

var gulls: Array = []
var lizards: Array = []
var swallows: Array = []
var clock := 0.0

static func basking(hour: float) -> bool: return hour >= 9.0 and hour < 18.0

static func swallows_out(hour: float) -> bool: return hour >= 6.0 and hour < 20.0

static func swallow_count(state: Dictionary) -> int:
	var done := 0
	for q in MAIN:
		if String(state.get("quests", {}).get(q, {}).get("status", "")) == "done": done += 1
	return 4 + done * 2

static func in_use(state: Dictionary) -> Array:
	var flags: Dictionary = state.get("flags", {})
	var out: Array = Terraces.TENDED.duplicate()
	for id in Terraces.ORDER:
		if flags.get(Terraces.flag(id), false): out.append(id)
	return out

static func wall_spots(id: String) -> Array:
	var n := int(id.substr(1))
	var z := float(Terraces.zs(n))
	var west := id.begins_with("w")
	var xs: Array = [-38.0, -31.0, -23.0, -15.0, -8.0] if west else [6.0, 10.0, 22.0, 31.0, 40.0]
	var out: Array = []
	for x in xs:
		if Terraces.BREACHES.has(id):
			var b: Array = Terraces.BREACHES[id]
			if x >= float(b[0]) - 1.0 and x <= float(b[1]) + 1.0: continue
		var top := Heightfield.height(x, z - 0.4)
		var low := Heightfield.height(x, z + 0.4)
		if top - low < 1.2: continue
		var face := z - 0.4
		while face < z + 0.4 and Heightfield.height(x, face) > (top + low) * 0.5: face += 0.02
		out.append(Vector3(x, (top + low) * 0.5 + 0.2, face + 0.03))
		if out.size() >= LIZARDS_PER_TERRACE: break
	return out

static func gull_seats() -> Array:
	var out: Array = []
	for b in Data.layout.get("props", []).filter(func(p): return String(p.kind) == "cliffs_boat"):
		var base := Heightfield.WATER_Y - 0.52 if b.get("afloat", false) else Heightfield.height(float(b.x), float(b.z))
		out.append(Vector3(float(b.x), base + 0.88, float(b.z) - 1.5))
	for x in [-7.0, -2.0, 4.0]: out.append(Vector3(x, 0.95, 30.85))
	out.append(Vector3(-3.0, 1.35, 45.2))
	out.append(Vector3(12.5, 1.35, 47.8))
	return out

func build(village: Node3D, state: Dictionary) -> void:
	name = "cliffs_animals"
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var seats := gull_seats()
	var church = village.get("objects").get("cliffs_church") if village.get("objects") is Dictionary else null
	if church != null:
		var rise := 0.0
		for n in church.find_children("*", "Node3D", true, false):
			if n.has_meta("rise"): rise = float(n.get_meta("rise"))
		seats.append(Vector3(22.5, church.position.y + 6.2 + rise + 0.05, 31.5))
	for s in seats:
		var o := _gull()
		add_child(o)
		gulls.append({"obj": o, "seat": s, "flying": 0.0, "ph": rng.randf() * TAU, "ring": false})
	for k in 3:
		var o := _gull()
		add_child(o)
		gulls.append({"obj": o, "seat": SEA_RING + Vector3(0.0, k * 2.5, 0.0), "flying": 1.0, "ph": k * TAU / 3.0, "ring": true, "r": 9.0 + k * 4.0})
	for id in Terraces.TENDED + Terraces.ORDER:
		for s in wall_spots(String(id)):
			var o := _lizard()
			o.position = s
			o.visible = false
			add_child(o)
			lizards.append({"obj": o, "home": s, "terrace": id, "hide": 0.0, "dart": 0.0})
	for k in 16:
		var o := _swallow()
		o.visible = false
		add_child(o)
		var c: Vector3 = SWALLOW_SPOTS[k % SWALLOW_SPOTS.size()]
		swallows.append({"obj": o, "c": c, "r": rng.randf_range(3.0, 7.5), "w": rng.randf_range(1.6, 2.6) * (1.0 if k % 2 == 0 else -1.0), "ph": rng.randf() * TAU, "h": rng.randf_range(-1.0, 2.0), "k": k})

func _gull() -> Node3D:
	var root := Node3D.new()
	var white := Palette.mat(Color("f4f1ea"))
	var grey := Palette.mat(Color("a3a8b0"))
	var body := Palette.mi(Palette.sphere(0.1, 10, 8), white, Vector3.ZERO)
	body.scale = Vector3(1.0, 0.9, 2.0)
	root.add_child(body)
	root.add_child(Palette.mi(Palette.sphere(0.07, 10, 8), white, Vector3(0.0, 0.07, -0.18)))
	var beak := Palette.mi(Palette.cone(0.02, 0.07, 8), Palette.mat(Color("f2c41c")), Vector3(0.0, 0.07, -0.27))
	beak.rotation.x = -PI / 2.0
	root.add_child(beak)
	for s in [-1.0, 1.0]:
		var w := Palette.mi(Palette.box(0.32, 0.015, 0.12), grey, Vector3(s * 0.17, 0.04, 0.02))
		w.name = "wing_l" if s < 0.0 else "wing_r"
		root.add_child(w)
	return root

func _lizard() -> Node3D:
	var root := Node3D.new()
	var skin := Palette.mat(Color("6f8a3a"))
	root.add_child(Palette.mi(Palette.box(0.05, 0.15, 0.02), skin, Vector3(0.0, 0.0, 0.012)))
	root.add_child(Palette.mi(Palette.sphere(0.028, 8, 6), skin, Vector3(0.0, 0.09, 0.014)))
	var tail := Palette.mi(Palette.cone(0.018, 0.14, 6), skin, Vector3(0.0, -0.14, 0.012))
	tail.rotation.z = PI
	root.add_child(tail)
	for s in [-1.0, 1.0]:
		for e in [-1.0, 1.0]:
			root.add_child(Palette.mi(Palette.box(0.05, 0.012, 0.012), skin, Vector3(s * 0.04, e * 0.045, 0.012)))
	return root

func _swallow() -> Node3D:
	var root := Node3D.new()
	var dark := Palette.mat(Color("1f2633"))
	var belly := Palette.mat(Color("efe7da"))
	root.add_child(Palette.mi(Palette.box(0.05, 0.04, 0.16), dark, Vector3.ZERO))
	root.add_child(Palette.mi(Palette.box(0.04, 0.012, 0.1), belly, Vector3(0.0, -0.022, 0.0)))
	for s in [-1.0, 1.0]:
		var w := Palette.mi(Palette.box(0.2, 0.01, 0.05), dark, Vector3(s * 0.11, 0.0, 0.02))
		w.rotation = Vector3(0.0, -s * 0.6, s * 0.15)
		root.add_child(w)
		var fork := Palette.mi(Palette.box(0.012, 0.008, 0.08), dark, Vector3(s * 0.015, 0.0, 0.11))
		fork.rotation.y = s * 0.3
		root.add_child(fork)
	root.scale = Vector3.ONE * 2.0
	return root

func _process(dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or g.get("player") == null or not (g.get("state") is Dictionary): return
	clock += dt
	var p: Vector3 = g.player.pos
	var hour := float(g.state.time.minute) / 60.0
	for q in gulls: _gull_step(q, p, dt)
	var sunny := basking(hour)
	var use := in_use(g.state)
	for l in lizards:
		var shown: bool = sunny and use.has(l.terrace)
		if not shown:
			l.obj.visible = false
			continue
		_lizard_step(l, p, dt)
	var out := swallows_out(hour)
	var count := swallow_count(g.state)
	var dusk := hour >= 18.0
	for s in swallows:
		var o: Node3D = s.obj
		o.visible = out and int(s.k) < count
		if not o.visible: continue
		var a: float = float(s.ph) + float(s.w) * clock * (1.3 if dusk else 1.0)
		var r: float = float(s.r)
		var c: Vector3 = s.c
		o.position = c + Vector3(cos(a) * r, float(s.h) + sin(a * 2.1 + float(s.ph)) * 1.4, sin(a) * r * 0.8)
		o.rotation.y = -a + (PI if float(s.w) > 0.0 else 0.0)

func _gull_step(q: Dictionary, p: Vector3, dt: float) -> void:
	var o: Node3D = q.obj
	var seat: Vector3 = q.seat
	if not q.ring:
		if float(q.flying) <= 0.0 and Vector2(p.x - seat.x, p.z - seat.z).length() < GULL_NEAR and absf(p.y - seat.y) < 4.0: q.flying = GULL_UP
		q.flying = maxf(0.0, float(q.flying) - dt)
	var flying := bool(q.ring) or float(q.flying) > 0.0
	var flap := sin(clock * 9.0 + float(q.ph)) * 0.6 if flying else 0.0
	(o.get_node("wing_l") as Node3D).rotation.z = flap
	(o.get_node("wing_r") as Node3D).rotation.z = -flap
	if not flying:
		o.position = seat
		o.rotation.y = float(q.ph)
		return
	var r: float = float(q.get("r", 6.0))
	var a: float = float(q.ph) + clock * 0.55
	var left: float = float(q.flying)
	var up: float = 0.0 if q.ring else minf(6.0, (GULL_UP - left) * 2.0) * minf(1.0, left / 3.0)
	var lift := 1.0 if q.ring else minf(1.0, (GULL_UP - left) / 2.0) * minf(1.0, left / 3.0)
	o.position = seat + Vector3(cos(a) * r * lift, up, sin(a) * r * lift)
	o.rotation.y = -a

func _lizard_step(l: Dictionary, p: Vector3, dt: float) -> void:
	var o: Node3D = l.obj
	var home: Vector3 = l.home
	if float(l.hide) > 0.0:
		l.hide = float(l.hide) - dt
		o.visible = float(l.hide) <= 0.0
		if o.visible: o.position = home
		return
	if float(l.dart) > 0.0:
		l.dart = float(l.dart) - dt
		o.visible = true
		o.position = home + Vector3((0.3 - float(l.dart)) * 3.0, 0.0, 0.0)
		if float(l.dart) <= 0.0:
			l.hide = 18.0
			o.visible = false
		return
	o.visible = true
	o.position = home
	if Vector2(p.x - home.x, p.z - home.z).length() < LIZARD_NEAR: l.dart = 0.3
