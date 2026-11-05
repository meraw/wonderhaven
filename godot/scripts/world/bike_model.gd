class_name BikeModel
## The player's bicycle (Bicycle): a sturdy town bike drawn under the rider, facing +z like the character. Its
## upgrades show: a front basket, a dynamo lamp that lights the way at night, a rear rack, and the paint job's racing
## stripe. Built again when they change (Game.refresh_bike).
const P := preload("res://scripts/world/palette.gd")

const WHEEL_R := 0.3
const SADDLE_Y := 0.86   # where the rider sits

static func build(color: String, ups: Array) -> Node3D:
	var g := Node3D.new(); g.name = "Bike"
	var frame := P.mat(color)
	var dark := P.mat("2a2a2a")
	var steel := P.mat("b8b8b0")
	for z in [-0.48, 0.48]:   # wheels: tyre, rim, hub
		var w := Node3D.new(); w.name = "wheel_front" if z > 0.0 else "wheel_back"; w.position = Vector3(0, WHEEL_R, z); g.add_child(w)
		_add(w, P.torus(WHEEL_R, 0.035, 20), dark, Vector3.ZERO, Vector3(0, 0, PI / 2))
		_add(w, P.torus(WHEEL_R - 0.04, 0.012, 20), steel, Vector3.ZERO, Vector3(0, 0, PI / 2))
		for k in 3: _add(w, P.box(0.012, (WHEEL_R - 0.05) * 2.0, 0.012), steel, Vector3.ZERO, Vector3(k * PI / 3.0, 0, 0))
	# the frame: a step-through town bike
	_bar(g, Vector3(0, WHEEL_R, -0.48), Vector3(0, 0.62, -0.12), frame)    # seat stay
	_bar(g, Vector3(0, 0.38, 0.0), Vector3(0, 0.62, -0.12), frame)        # seat tube
	_bar(g, Vector3(0, 0.38, 0.0), Vector3(0, 0.78, 0.36), frame)         # down tube
	_bar(g, Vector3(0, WHEEL_R, -0.48), Vector3(0, 0.38, 0.0), frame)      # chain stay
	_bar(g, Vector3(0, WHEEL_R, 0.48), Vector3(0, 0.86, 0.38), frame)      # fork
	_add(g, P.cyl(0.06, 0.06, 0.06, 10), dark, Vector3(0, 0.38, 0.0), Vector3(0, 0, PI / 2))   # crank
	_add(g, P.rbox(0.16, 0.05, 0.24, 0.03), P.mat("6a4a30"), Vector3(0, 0.66, -0.14))         # saddle
	_add(g, P.cyl(0.015, 0.015, 0.5, 6), dark, Vector3(0, 0.9, 0.36), Vector3(0, 0, PI / 2))  # handlebar
	for s in [-1, 1]: _add(g, P.cyl(0.022, 0.022, 0.09, 6), P.mat("6a4a30"), Vector3(s * 0.24, 0.9, 0.36), Vector3(0, 0, PI / 2))
	_add(g, P.box(0.12, 0.02, 0.36), frame, Vector3(0, WHEEL_R + 0.33, -0.44))               # rear mudguard
	if ups.has("paint"):   # a racing stripe and white tyres' walls, like Primo's 1953 racer
		_bar(g, Vector3(0.02, 0.4, 0.02), Vector3(0.02, 0.79, 0.35), P.mat("f4f1ea"), 0.012)
	if ups.has("basket"):
		var b := Node3D.new(); b.name = "basket"; b.position = Vector3(0, 0.84, 0.55); g.add_child(b)
		_add(b, P.box(0.32, 0.2, 0.26), P.wood("c9a06e"), Vector3.ZERO)
		_add(b, P.box(0.28, 0.02, 0.22), P.wood("8a6a40"), Vector3(0, 0.1, 0))
	if ups.has("rack"):
		_add(g, P.box(0.2, 0.025, 0.34), steel, Vector3(0, 0.66, -0.45))
		for s in [-1, 1]: _bar(g, Vector3(s * 0.08, 0.66, -0.3), Vector3(s * 0.08, WHEEL_R, -0.48), steel, 0.01)
	if ups.has("lamp"):
		var l := Node3D.new(); l.name = "lamp"; l.position = Vector3(0, 0.82, 0.47); g.add_child(l)
		_add(l, P.cyl(0.05, 0.045, 0.07, 10), P.mat("f2c53a"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		var glass := _add(l, P.cyl(0.04, 0.04, 0.01, 10), P.unique_mat("fff6d0", "ffe9a0", 0.0), Vector3(0, 0, 0.04), Vector3(PI / 2, 0, 0))
		glass.name = "glass"
		var beam := SpotLight3D.new(); beam.name = "beam"; beam.light_color = Color("ffe9b0"); beam.light_energy = 2.2
		beam.spot_range = 9.0; beam.spot_angle = 28.0; beam.rotation = Vector3(-0.2, PI, 0); beam.visible = false
		l.add_child(beam)
	return g

## The lamp lights at night (it's a dynamo: it only shines while you ride), and the wheels turn with speed.
static func animate(g: Node3D, dt: float, speed: float, night: bool) -> void:
	for n in ["wheel_front", "wheel_back"]:
		var w := g.get_node_or_null(n) as Node3D
		if w: w.rotation.x += speed * dt / WHEEL_R
	var l := g.get_node_or_null("lamp")
	if l:
		var on := night and speed > 0.5
		(l.get_node("beam") as SpotLight3D).visible = on
		((l.get_node("glass") as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 2.5 if on else 0.0

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.position = pos; m.rotation = rot
	parent.add_child(m)
	return m

## A tube from a to b.
static func _bar(parent: Node3D, a: Vector3, b: Vector3, mat: Material, r: float = 0.022) -> void:
	var m := MeshInstance3D.new(); m.mesh = P.cyl(r, r, a.distance_to(b), 6); m.material_override = mat
	parent.add_child(m)
	m.position = (a + b) / 2.0
	var up := (b - a).normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length() > 1e-4: m.rotate(axis.normalized(), Vector3.UP.angle_to(up))
