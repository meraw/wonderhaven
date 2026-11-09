extends Node3D

const Sounds := preload("sounds.gd")
const BELL := Vector2(-38.2, -35.5)
const BELL_H := 16.0
const CASTLE := Vector2(-46.5, -63.5)
const CASTLE_H := 7.0
const SWARM_AT := Vector3(-38.2, 5.2, -33.85)
const STUMP := Vector2(22.0, 60.4)
const GULL_RING := Vector2(24.0, 66.0)
const GULL_NEAR := 3.0
const LIZARD_NEAR := 2.5

var swifts: Array = []
var gulls: Array = []
var lizards: Array = []
var swarm: MultiMeshInstance3D
var clock := 0.0

static func lizard_spots() -> Array:
	var out: Array = []
	for xi in range(18, 64, 3):
		var x := float(xi)
		var z := -50.0
		while z < 40.0 and out.size() < 14:
			var top := Heightfield.height(x, z)
			var low := Heightfield.height(x, z + 0.6)
			if top - low > 1.2 and low > 1.0:
				var face := z
				while face < z + 0.6 and Heightfield.height(x, face) > (top + low) * 0.5: face += 0.02
				var spot := Vector3(x, (top + low) * 0.5, face + 0.02)
				if out.all(func(o): return Vector2(o.x - spot.x, o.z - spot.z).length() > 7.0): out.append(spot)
				z += 2.0
			z += 0.25
	return out

static func tower_tops() -> Array:
	return [Vector3(BELL.x, Heightfield.height(BELL.x, BELL.y) + BELL_H + 2.5, BELL.y), Vector3(CASTLE.x, Heightfield.height(CASTLE.x, CASTLE.y) + CASTLE_H + 3.5, CASTLE.y)]

static func gull_seats() -> Array:
	var out: Array = []
	for b in Data.layout.get("props", []).filter(func(p): return p.kind == "olive_village_boat"):
		out.append(Vector3(float(b.x), Heightfield.height(float(b.x), float(b.z)) + 0.55, float(b.z) - 0.6))
	out.append(Vector3(STUMP.x + 0.9, Heightfield.height(STUMP.x, STUMP.y) + 1.12, STUMP.y - 0.9))
	return out

static func swifts_out(hour: float) -> bool:
	return hour >= 5.5 and hour < 21.5

static func swarm_shown(flags: Dictionary) -> bool:
	return Sounds.bells_silent(flags)

func build() -> void:
	name = "olive_village_animals"
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var tops := tower_tops()
	for k in 12:
		var c: Vector3 = tops[0] if k < 7 else tops[1]
		var o := _swift()
		add_child(o)
		swifts.append({"obj": o, "c": c, "r": rng.randf_range(3.5, 8.5), "w": rng.randf_range(1.4, 2.3) * (1.0 if k % 2 == 0 else -1.0), "ph": rng.randf() * TAU, "h": rng.randf_range(-1.0, 2.5)})
	for s in gull_seats():
		var o := _gull()
		add_child(o)
		gulls.append({"obj": o, "seat": s, "flying": 0.0, "ph": rng.randf() * TAU, "ring": false})
	for k in 2:
		var o := _gull()
		add_child(o)
		gulls.append({"obj": o, "seat": Vector3(GULL_RING.x, 9.0 + k * 3.0, GULL_RING.y), "flying": 1.0, "ph": k * PI, "ring": true, "r": 10.0 + k * 4.0})
	for s in lizard_spots():
		var o := _lizard()
		o.position = s
		add_child(o)
		lizards.append({"obj": o, "home": s, "hide": 0.0, "dart": 0.0})
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Palette.sphere(0.03, 6, 4)
	mm.instance_count = 40
	swarm = MultiMeshInstance3D.new()
	swarm.multimesh = mm
	swarm.material_override = Palette.mat(Color("2a2418"))
	swarm.position = Vector3(SWARM_AT.x, Heightfield.height(SWARM_AT.x, SWARM_AT.z) + SWARM_AT.y, SWARM_AT.z)
	swarm.visible = false
	add_child(swarm)

func _swift() -> Node3D:
	var root := Node3D.new()
	var dark := Palette.mat(Color("26262c"))
	root.add_child(Palette.mi(Palette.box(0.05, 0.04, 0.16), dark, Vector3.ZERO))
	for s in [-1.0, 1.0]:
		var w := Palette.mi(Palette.box(0.22, 0.012, 0.06), dark, Vector3(s * 0.12, 0.0, 0.03))
		w.rotation = Vector3(0.0, -s * 0.5, s * 0.15)
		root.add_child(w)
	root.scale = Vector3.ONE * 2.0
	return root

func _gull() -> Node3D:
	var root := Node3D.new()
	var white := Palette.mat(Color("f4f1ea"))
	var grey := Palette.mat(Color("a3a8b0"))
	var body := Palette.mi(Palette.sphere(0.1, 10, 8), white, Vector3(0.0, 0.0, 0.0))
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
	var skin := Palette.mat(Color("7a8a42"))
	root.add_child(Palette.mi(Palette.box(0.05, 0.15, 0.02), skin, Vector3(0.0, 0.0, 0.012)))
	root.add_child(Palette.mi(Palette.sphere(0.028, 8, 6), skin, Vector3(0.0, 0.09, 0.014)))
	var tail := Palette.mi(Palette.cone(0.018, 0.14, 6), skin, Vector3(0.0, -0.14, 0.012))
	tail.rotation.z = PI
	root.add_child(tail)
	for s in [-1.0, 1.0]:
		for e in [-1.0, 1.0]:
			root.add_child(Palette.mi(Palette.box(0.05, 0.012, 0.012), skin, Vector3(s * 0.04, e * 0.045, 0.012)))
	return root

func _process(dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or g.get("player") == null or not (g.get("state") is Dictionary): return
	clock += dt
	var p: Vector3 = g.player.pos
	var hour := float(g.state.time.minute) / 60.0
	var out := swifts_out(hour)
	var dusk := hour >= 18.0
	for s in swifts:
		var o: Node3D = s.obj
		o.visible = out
		if not out: continue
		var a: float = float(s.ph) + float(s.w) * clock * (1.3 if dusk else 1.0)
		var r: float = float(s.r) * (0.8 if dusk else 1.0)
		var c: Vector3 = s.c
		o.position = c + Vector3(cos(a) * r, float(s.h) + sin(a * 2.3 + float(s.ph)) * 1.2, sin(a) * r * 0.85)
		o.rotation.y = -a + (PI if float(s.w) > 0.0 else 0.0)
	for q in gulls:
		_gull_step(q, p, dt)
	for l in lizards:
		_lizard_step(l, p, dt)
	var buzzing := swarm_shown(g.state.flags)
	swarm.visible = buzzing
	if buzzing:
		for i in swarm.multimesh.instance_count:
			var f := float(i)
			var off := Vector3(sin(clock * 3.1 + f * 1.7) * 0.35, sin(clock * 2.3 + f * 2.9) * 0.3 + cos(f) * 0.15, cos(clock * 2.7 + f * 1.3) * 0.25)
			swarm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, off))

func _gull_step(q: Dictionary, p: Vector3, dt: float) -> void:
	var o: Node3D = q.obj
	var seat: Vector3 = q.seat
	if not q.ring:
		if float(q.flying) <= 0.0 and Vector2(p.x - seat.x, p.z - seat.z).length() < GULL_NEAR: q.flying = 22.0
		q.flying = maxf(0.0, float(q.flying) - dt)
	var flying := bool(q.ring) or float(q.flying) > 0.0
	var flap := sin(clock * 9.0 + float(q.ph)) * 0.6 if flying else 0.0
	var wl := o.get_node("wing_l")
	var wr := o.get_node("wing_r")
	wl.rotation.z = flap
	wr.rotation.z = -flap
	if not flying:
		o.position = seat
		o.rotation.y = float(q.ph)
		return
	var r: float = float(q.get("r", 7.0))
	var a: float = float(q.ph) + clock * 0.55
	var up: float = 0.0 if q.ring else minf(6.0, (22.0 - float(q.flying)) * 2.0) * minf(1.0, float(q.flying) / 3.0)
	var lift := 1.0 if q.ring else minf(1.0, (22.0 - float(q.flying)) / 2.0) * minf(1.0, float(q.flying) / 3.0)
	var centre := seat + Vector3(0.0, up, 0.0)
	o.position = centre + Vector3(cos(a) * r * lift, 0.0, sin(a) * r * lift)
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
		o.position = home + Vector3((0.3 - float(l.dart)) * 3.0, 0.0, 0.0)
		if float(l.dart) <= 0.0:
			l.hide = 18.0
			o.visible = false
		return
	if Vector2(p.x - home.x, p.z - home.z).length() < LIZARD_NEAR: l.dart = 0.3
