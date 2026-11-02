class_name Chibi
extends Node3D
## Chibi character: big head, short limbs, a 3D cartoon face that blinks and emotes, bouncy procedural animation.
const P := preload("res://scripts/world/palette.gd")
const HEAD_R := 0.4
const ACTION_LENGTH := {"wave": 1.6, "clap": 1.4, "celebrate": 1.9, "surprised": 0.9, "chop": 0.55, "mine": 0.6, "dig": 0.7, "build": 0.9, "nod": 0.8, "shrug": 1.0, "feed": 1.0}

var appearance: Dictionary
var body: Node3D
var head: Node3D
var face: Node3D
var arm_l: Node3D; var arm_r: Node3D; var leg_l: Node3D; var leg_r: Node3D
var staff: Node3D
var eyes: Array = []
var mouths: Dictionary = {}
var action := ""
var action_t := 0.0
var hold := ""
var t := randf() * 10.0
var next_blink := 2.0 + randf() * 3.0
var blink_t := 0.0
var mood := "neutral"
var mood_t := 0.0
var talking := false
var staff_visible := false

func _init(app: Dictionary = {}) -> void:
	set_appearance(app)

static func sanitize(a: Dictionary) -> Dictionary:
	var A: Dictionary = Data.appearance
	var D: Dictionary = A["default"]
	var out := {}
	var pick := func(k: String, list: Array) -> void: out[k] = a[k] if a.has(k) and list.has(a[k]) else D[k]
	var col := func(k: String) -> void: out[k] = a[k] if a.has(k) and a[k] is String and a[k].length() == 7 and a[k].begins_with("#") else D[k]
	col.call("skin"); pick.call("eyeShape", A.EYE_SHAPES); col.call("eyeColor"); pick.call("hair", A.HAIR_STYLES); col.call("hairColor"); pick.call("mouth", A.MOUTHS)
	pick.call("top", A.TOPS); col.call("topColor"); pick.call("bottom", A.BOTTOMS); col.call("bottomColor"); pick.call("shoes", A.SHOES); col.call("shoesColor")
	pick.call("hat", A.HATS); col.call("hatColor"); pick.call("accessory", A.ACCESSORIES)
	return out

func _m(mesh: Mesh, color, parent: Node3D, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := P.mi(mesh, P.mat(color) if not color is Material else color, pos)
	mi.scale = scl; mi.rotation = rot
	parent.add_child(mi)
	return mi

func set_appearance(app: Dictionary) -> void:
	appearance = sanitize(app)
	var a := appearance
	for c in get_children(): c.queue_free(); remove_child(c)
	eyes.clear(); mouths.clear()
	body = Node3D.new(); add_child(body)
	var skin = a.skin; var top = a.topColor; var bottom = a.bottomColor; var shoes = a.shoesColor
	var bare_legs: bool = a.bottom in ["shorts", "skirt", "dress"]
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 0.1, 0.34, 0); body.add_child(hip)
		_m(P.capsule(0.075, 0.16), skin if bare_legs else bottom, hip, Vector3(0, -0.14, 0))
		_m(P.sphere(0.1, 10, 8), shoes, hip, Vector3(0, -0.29, 0.03), Vector3(0.9, 1.0 if a.shoes == "boots" else 0.6, 1.3))
		if a.shoes == "boots": _m(P.cyl(0.09, 0.09, 0.12, 10), shoes, hip, Vector3(0, -0.21, 0))
		if s < 0: leg_l = hip
		else: leg_r = hip
	_m(P.sphere(0.22, 14, 12), bottom if a.top == "overalls" else top, body, Vector3(0, 0.5, 0), Vector3(1, 1.05, 0.88))
	if a.bottom in ["shorts", "pants"]: _m(P.sphere(0.2, 12, 8), bottom, body, Vector3(0, 0.42, 0), Vector3(1, 0.8, 0.88))
	if a.bottom == "skirt": _m(P.cyl(0.2, 0.3, 0.2, 14), bottom, body, Vector3(0, 0.36, 0))
	if a.bottom == "dress": _m(P.cyl(0.19, 0.34, 0.36, 16), top, body, Vector3(0, 0.38, 0))
	if a.top == "overalls":
		_m(P.rbox(0.26, 0.2, 0.08, 0.03), bottom, body, Vector3(0, 0.58, 0.17))
		_m(P.hemi(0.205, 12), top, body, Vector3(0, 0.56, 0))
	if a.top == "tunic": _m(P.torus(0.205, 0.03, 16), "8b5a3c", body, Vector3(0, 0.44, 0))
	if a.top == "jacket":
		for s in [-1, 1]: _m(P.box(0.06, 0.26, 0.05), "ffffff", body, Vector3(s * 0.05, 0.53, 0.19), Vector3.ONE, Vector3(0, 0, s * 0.2))
	if a.top == "sailor":
		_m(P.cyl(0.17, 0.24, 0.07, 14), "2f5fa8", body, Vector3(0, 0.66, 0))
		_m(P.cone(0.05, 0.12, 4), "e85d75", body, Vector3(0, 0.6, 0.2), Vector3.ONE, Vector3(PI, 0, 0))
	if a.top == "sweater": _m(P.torus(0.19, 0.035, 16), top, body, Vector3(0, 0.33, 0))
	for s in [-1, 1]:
		var sh := Node3D.new(); sh.position = Vector3(s * 0.22, 0.62, 0); body.add_child(sh)
		_m(P.capsule(0.058, 0.16), skin if a.top in ["tee", "overalls"] else top, sh, Vector3(0, -0.12, 0), Vector3.ONE, Vector3(0, 0, s * 0.15))
		_m(P.sphere(0.07, 10, 8), skin, sh, Vector3(s * 0.03, -0.26, 0))
		if s < 0: arm_l = sh
		else: arm_r = sh
	staff = Node3D.new(); staff.position = Vector3(0.03, -0.26, 0.02); staff.rotation.x = 0.2; staff.visible = staff_visible; arm_r.add_child(staff)
	_m(P.cyl(0.025, 0.03, 0.95, 6), "a0623a", staff, Vector3(0, 0.2, 0))
	_m(P.torus(0.09, 0.022, 12), P.GOLD, staff, Vector3(0, 0.72, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	var star := _m(P.sphere(0.1, 4, 2), P.unique_mat("fff2a8", "ffd35c", 2.0), staff, Vector3(0, 0.72, 0)); star.name = "star"
	head = Node3D.new(); head.position.y = 0.7; body.add_child(head)
	_m(P.sphere(HEAD_R, 24, 16), skin, head, Vector3(0, HEAD_R * 0.92, 0))
	for s in [-1, 1]: _m(P.sphere(0.07, 8, 6), skin, head, Vector3(s * HEAD_R * 0.98, HEAD_R * 0.9, 0), Vector3(0.6, 1, 0.8))
	_build_face(a)
	_build_hair(a.hair, a.hairColor)
	if a.hat != "none": _build_hat(a.hat, a.hatColor)
	match a.accessory:
		"glasses":
			for s in [-1, 1]: _m(P.torus(0.08, 0.014, 16), "3a3a4a", head, Vector3(s * 0.15, HEAD_R * 0.85, HEAD_R * 0.97), Vector3.ONE, Vector3(PI / 2, 0, 0))
		"beard": _m(P.sphere(0.26, 12, 8), a.hairColor, head, Vector3(0, HEAD_R * 0.45, 0.14), Vector3(1, 0.7, 0.8))
		"scarf": _m(P.torus(0.17, 0.06, 16), a.hatColor, body, Vector3(0, 0.68, 0))
		"backpack": _m(P.rbox(0.3, 0.32, 0.16, 0.06), a.hatColor, body, Vector3(0, 0.52, -0.25))
		"bowtie":
			for s in [-1, 1]: _m(P.cone(0.05, 0.1, 6), "e85d75", body, Vector3(s * 0.05, 0.66, 0.19), Vector3.ONE, Vector3(0, 0, s * PI / 2))

# Face: features sit on the head's front surface and face outward.
func _on_face(node: Node3D, x: float, y: float, inset: float = 0.0) -> void:
	var c := Vector3(0, HEAD_R * 0.92, 0)
	var dir := Vector3(x, y, 0)
	dir.z = sqrt(maxf(0.0, HEAD_R * HEAD_R - x * x - y * y))
	node.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), c + dir.normalized() * (HEAD_R - inset))

func _build_face(a: Dictionary) -> void:
	face = Node3D.new(); head.add_child(face)
	for s in [-1, 1]:
		var eye := Node3D.new(); face.add_child(eye)
		_on_face(eye, s * 0.15, -0.02, 0.005)
		var e := Node3D.new(); e.name = "open"; eye.add_child(e)
		_m(P.sphere(0.075, 12, 8), "ffffff", e, Vector3(0, 0, 0), Vector3(1, 1.3, 0.35))
		_m(P.sphere(0.064, 12, 8), a.eyeColor, e, Vector3(0, -0.005, -0.012), Vector3(1, 1.3, 0.35))
		_m(P.sphere(0.034, 10, 6), "1d1414", e, Vector3(0, -0.002, -0.024), Vector3(1, 1.3, 0.35))
		_m(P.sphere(0.017, 6, 4), P.glow_mat(Color.WHITE), e, Vector3(0.022 * s * -1, 0.03, -0.032))
		if a.eyeShape == "sparkle": _m(P.sphere(0.01, 6, 4), P.glow_mat(Color.WHITE), e, Vector3(-0.015 * s * -1, -0.03, -0.032))
		var closed := Node3D.new(); closed.name = "closed"; closed.visible = false; eye.add_child(closed)
		_m(P.capsule(0.012, 0.09), "3a2a2a", closed, Vector3(0, 0, -0.01), Vector3.ONE, Vector3(0, 0, PI / 2))
		var happy := Node3D.new(); happy.name = "happy"; happy.visible = false; eye.add_child(happy)
		for k in [-1, 1]: _m(P.capsule(0.012, 0.05), "3a2a2a", happy, Vector3(k * 0.022, 0.01, -0.01), Vector3.ONE, Vector3(0, 0, PI / 2 + k * 0.7))
		var brow := _m(P.capsule(0.01, 0.07), "6a4a3a", face, Vector3.ZERO, Vector3.ONE)
		_on_face(brow, s * 0.15, 0.11, 0.0); brow.rotate_object_local(Vector3.FORWARD, PI / 2 + s * 0.12); brow.name = "brow"
		eye.scale = Vector3.ONE * (1.15 if a.eyeShape == "wide" else 1.0)
		eyes.append(eye)
		var blush := _m(P.sphere(0.05, 8, 6), P.glow_mat(Color(1, 0.55, 0.6), 0.45), face, Vector3.ZERO, Vector3(1.3, 0.7, 0.2))
		_on_face(blush, s * 0.25, -0.09, -0.005)
	var mouth_pos := Vector2(0, -0.17)
	var make := func(name: String) -> Node3D:
		var m := Node3D.new(); m.name = name; m.visible = false; face.add_child(m); _on_face(m, mouth_pos.x, mouth_pos.y, 0.004); mouths[name] = m; return m
	var red := "b94a55"
	_m(P.hemi(0.05, 12), red, make.call("smile"), Vector3.ZERO, Vector3(1.1, 0.7, 0.3), Vector3(PI, 0, 0))
	_m(P.hemi(0.07, 12), red, make.call("grin"), Vector3.ZERO, Vector3(1.1, 0.9, 0.3), Vector3(PI, 0, 0))
	_m(P.sphere(0.035, 10, 6), red, make.call("o"), Vector3.ZERO, Vector3(1, 1.25, 0.3))
	_m(P.capsule(0.012, 0.05), red, make.call("calm"), Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2))
	var cat: Node3D = make.call("cat")
	for k in [-1, 1]: _m(P.hemi(0.025, 8), red, cat, Vector3(k * 0.024, 0, 0), Vector3(1, 0.7, 0.3), Vector3(PI, 0, 0))
	_m(P.hemi(0.045, 12), red, make.call("sad"), Vector3(0, -0.01, 0), Vector3(1.1, 0.6, 0.3), Vector3.ZERO)
	_refresh_face()

func _refresh_face() -> void:
	if eyes.is_empty(): return
	var shape: String = appearance.eyeShape
	if mood == "happy": shape = "happy"
	elif mood == "surprised": shape = "wide"
	elif mood == "sleepy": shape = "sleepy"
	for e in eyes:
		var blink := blink_t > 0.0
		e.get_node("open").visible = not blink and shape != "happy" and shape != "sleepy"
		e.get_node("closed").visible = (blink and shape != "happy") or shape == "sleepy"
		e.get_node("happy").visible = shape == "happy"
		e.get_node("open").scale = Vector3.ONE * (1.2 if shape == "wide" else 1.0)
	var mouth: String = appearance.mouth
	if mood == "happy": mouth = "grin"
	elif mood == "surprised": mouth = "o"
	elif mood == "sad": mouth = "sad"
	elif talking and fmod(t * 9.0, 2.0) > 1.0: mouth = "o"
	for k in mouths: mouths[k].visible = k == mouth

func show_staff(v: bool) -> void:
	staff_visible = v
	if staff: staff.visible = v

func set_mood(m: String, seconds: float = 0.0) -> void:
	mood = m; mood_t = seconds; _refresh_face()

func set_talking(v: bool) -> void:
	talking = v; _refresh_face()

func play(name: String, hold_state: bool = false) -> void:
	if hold_state: hold = name; action = ""; return
	action = name; action_t = 0.0
	if name in ["celebrate", "clap"]: set_mood("happy", ACTION_LENGTH[name])
	if name == "surprised": set_mood("surprised", 1.2)

func stop_hold() -> void: hold = ""

func head_world_pos() -> Vector3: return head.to_global(Vector3(0, HEAD_R * 0.92, 0))

func _build_hair(style: String, color: String) -> void:
	var g := Node3D.new(); g.position.y = HEAD_R * 0.92; head.add_child(g)
	_m(P.hemi(HEAD_R * 1.06, 18), color, g, Vector3(0, HEAD_R * 0.04, -0.02), Vector3.ONE, Vector3(-0.22, 0, 0))
	# fringe
	_m(P.sphere(HEAD_R * 0.55, 12, 8), color, g, Vector3(0, HEAD_R * 0.55, HEAD_R * 0.45), Vector3(1.5, 0.45, 0.6))
	if style in ["bob", "long", "pigtails", "ponytail", "bun"]:
		_m(P.sphere(HEAD_R * 1.06, 16, 10), color, g, Vector3(0, -0.02, -0.06), Vector3(1.04, 0.95, 0.95))
		for s in [-1, 1]: _m(P.sphere(0.16, 10, 8), color, g, Vector3(s * 0.33, -0.12, 0.08), Vector3(0.7, 1.3, 0.9))
	if style == "long": _m(P.rbox(0.7, 0.75, 0.25, 0.12), color, g, Vector3(0, -0.3, -0.25))
	if style == "pigtails":
		for s in [-1, 1]: _m(P.sphere(0.15, 10, 8), color, g, Vector3(s * 0.47, -0.15, -0.05), Vector3(0.9, 1.4, 0.9))
	if style == "ponytail": _m(P.sphere(0.14, 10, 8), color, g, Vector3(0, 0.0, -0.48), Vector3(0.9, 1.6, 0.9), Vector3(0.6, 0, 0))
	if style == "bun": _m(P.sphere(0.17, 12, 10), color, g, Vector3(0, 0.42, -0.1))
	if style == "spiky":
		for n in 7:
			var a := n / 7.0 * TAU
			_m(P.cone(0.1, 0.28, 6), color, g, Vector3(cos(a) * 0.22, 0.36, sin(a) * 0.22 - 0.05), Vector3.ONE, Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7))
	if style == "curly":
		for n in 12:
			var a := n / 12.0 * TAU
			_m(P.sphere(0.13, 8, 6), color, g, Vector3(cos(a) * 0.36, 0.18 + (n % 2) * 0.1, sin(a) * 0.36 - 0.05))
	if style == "short": _m(P.sphere(0.12, 8, 6), color, g, Vector3(0.05, 0.42, 0.1), Vector3(1.2, 0.5, 1))

func _build_hat(kind: String, color: String) -> void:
	var g := Node3D.new(); g.position.y = HEAD_R * 0.92; head.add_child(g)
	match kind:
		"beret": _m(P.sphere(0.36, 14, 8), color, g, Vector3(0.06, 0.36, 0), Vector3(1.1, 0.4, 1.1), Vector3(0, 0, -0.25))
		"beanie":
			_m(P.hemi(0.43, 16), color, g, Vector3(0, 0.08, 0))
			_m(P.sphere(0.08), "ffffff", g, Vector3(0, 0.52, 0))
		"bow":
			for s in [-1, 1]: _m(P.cone(0.1, 0.2, 8), color, g, Vector3(s * 0.12, 0.42, 0.05), Vector3.ONE, Vector3(0, 0, s * PI / 2))
			_m(P.sphere(0.05), color, g, Vector3(0, 0.42, 0.05))
		"sunhat":
			_m(P.cyl(0.62, 0.62, 0.03, 20), "f2d27a", g, Vector3(0, 0.3, 0))
			_m(P.cyl(0.3, 0.36, 0.24, 16), "f2d27a", g, Vector3(0, 0.42, 0))
			_m(P.cyl(0.365, 0.365, 0.06, 16), color, g, Vector3(0, 0.34, 0))
		"chef":
			_m(P.cyl(0.3, 0.28, 0.25, 14), "ffffff", g, Vector3(0, 0.4, 0))
			_m(P.sphere(0.33, 14, 10), "ffffff", g, Vector3(0, 0.6, 0), Vector3(1, 0.75, 1))
		"flowerCrown":
			for n in 9:
				var a := n / 9.0 * TAU
				_m(P.sphere(0.065, 8, 6), P.FLOWERS[n % 5], g, Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36))
		"captain":
			_m(P.cyl(0.4, 0.38, 0.22, 16), "ffffff", g, Vector3(0, 0.38, 0))
			_m(P.cyl(0.39, 0.39, 0.07, 16), "2f3f6a", g, Vector3(0, 0.3, 0))
			_m(P.box(0.4, 0.03, 0.18), "2f3f6a", g, Vector3(0, 0.28, 0.36))
			_m(P.sphere(0.05, 4, 2), P.GOLD, g, Vector3(0, 0.4, 0.4))
		"crown":
			_m(P.cyl(0.24, 0.24, 0.16, 8), P.GOLD, g, Vector3(0, 0.45, 0))
			for n in 5:
				var a := n / 5.0 * TAU
				_m(P.cone(0.05, 0.12, 5), P.GOLD, g, Vector3(cos(a) * 0.23, 0.58, sin(a) * 0.23))
			_m(P.sphere(0.04), "ff5a8a", g, Vector3(0, 0.46, 0.24))
		"goggles":
			_m(P.torus(0.41, 0.03, 24), "6a4a3a", g, Vector3(0, 0.2, 0), Vector3.ONE, Vector3(-0.3, 0, 0))
			for s in [-1, 1]:
				_m(P.cyl(0.09, 0.09, 0.07, 12), "c9a06e", g, Vector3(s * 0.13, 0.3, 0.33), Vector3.ONE, Vector3(PI / 2 - 0.5, 0, 0))
				_m(P.sphere(0.07, 8, 6), P.mat("8fe0ff", "3fa9d6", 0.6), g, Vector3(s * 0.13, 0.31, 0.37), Vector3(1, 1, 0.4))

func animate(dt: float, speed: float = 0.0, airborne: bool = false) -> void:
	t += dt
	next_blink -= dt
	if next_blink < 0.0: blink_t = 0.12; next_blink = 2.5 + randf() * 3.0; _refresh_face()
	if blink_t > 0.0:
		blink_t -= dt
		if blink_t <= 0.0: _refresh_face()
	if mood_t > 0.0:
		mood_t -= dt
		if mood_t <= 0.0: mood = "neutral"; _refresh_face()
	if talking: _refresh_face()
	body.position = Vector3.ZERO; body.rotation = Vector3.ZERO; head.rotation = Vector3.ZERO
	for p in [arm_l, arm_r, leg_l, leg_r]: p.rotation = Vector3.ZERO
	var walk := minf(1.0, speed)
	if walk > 0.05:
		var f := t * (8.0 + speed * 4.0)
		leg_l.rotation.x = sin(f) * 0.8 * walk; leg_r.rotation.x = -sin(f) * 0.8 * walk
		arm_l.rotation.x = -sin(f) * 0.7 * walk; arm_r.rotation.x = sin(f) * 0.7 * walk
		body.position.y = absf(sin(f)) * 0.07 * walk
		body.rotation.z = sin(f) * 0.05 * walk; head.rotation.z = -sin(f) * 0.05 * walk
	else:
		body.position.y = sin(t * 2.2) * 0.012; head.rotation.z = sin(t * 0.9) * 0.04
		arm_l.rotation.z = -0.1 - sin(t * 2.2) * 0.03; arm_r.rotation.z = 0.1 + sin(t * 2.2) * 0.03
	if airborne: leg_l.rotation.x = 0.5; leg_r.rotation.x = -0.3; arm_l.rotation.z = -1.2; arm_r.rotation.z = 1.2
	match hold:
		"sit": body.position.y = -0.2; leg_l.rotation.x = -1.4; leg_r.rotation.x = -1.4; arm_l.rotation.x = -0.3; arm_r.rotation.x = -0.3
		"sleep": body.position.y = -0.24; leg_l.rotation.x = -1.4; leg_r.rotation.x = -1.4; head.rotation.x = 0.35; head.rotation.z = 0.25
		"cast": arm_r.rotation.x = -1.3; arm_l.rotation.x = -1.1; arm_l.rotation.z = 0.4
		"reel": arm_r.rotation.x = -1.0 + sin(t * 14.0) * 0.15; arm_l.rotation.x = -1.0; arm_l.rotation.z = 0.4; body.rotation.x = -0.12
		"build": arm_r.rotation.x = -2.6 + sin(t * 3.0) * 0.12; arm_r.rotation.z = 0.2; arm_l.rotation.z = -0.5 - sin(t * 3.0) * 0.1
		"work": arm_r.rotation.x = -0.9 + sin(t * 7.0) * 0.5; arm_l.rotation.x = -0.6; body.rotation.x = 0.1
		"garden": body.rotation.x = 0.3; arm_l.rotation.x = -0.9 + sin(t * 4.0) * 0.2; arm_r.rotation.x = arm_l.rotation.x
		"read": arm_l.rotation.x = -1.1; arm_r.rotation.x = -1.1; arm_l.rotation.z = 0.35; arm_r.rotation.z = -0.35; head.rotation.x = 0.25
		"talk": arm_r.rotation.x = -0.4 + sin(t * 3.0) * 0.3; arm_r.rotation.z = 0.35; head.rotation.y = sin(t * 1.3) * 0.12
	if action != "":
		action_t += dt
		var p: float = action_t / ACTION_LENGTH.get(action, 1.0)
		var s := sin(p * PI)
		match action:
			"wave": arm_r.rotation.z = 2.6; arm_r.rotation.x = sin(action_t * 12.0) * 0.35; head.rotation.z = 0.12
			"clap":
				arm_l.rotation.x = -1.3; arm_r.rotation.x = -1.3
				var c := absf(sin(action_t * 14.0)) * 0.5
				arm_l.rotation.z = 0.5 - c; arm_r.rotation.z = -0.5 + c; body.position.y += absf(sin(action_t * 7.0)) * 0.05
			"celebrate":
				body.position.y += absf(sin(action_t * 6.0)) * 0.35; arm_l.rotation.z = -2.7; arm_r.rotation.z = 2.7
				arm_l.rotation.x = sin(action_t * 12.0) * 0.2; arm_r.rotation.x = arm_l.rotation.x; body.rotation.y = action_t * 3.4
			"surprised": body.position.y += s * 0.25; arm_l.rotation.z = -1.5 * s; arm_r.rotation.z = 1.5 * s
			"nod": head.rotation.x = sin(p * PI * 4.0) * 0.25
			"shrug": arm_l.rotation.z = -0.9 * s; arm_r.rotation.z = 0.9 * s; head.rotation.z = 0.2 * s
			"chop", "mine": arm_r.rotation.x = -2.8 + p * 3.2; arm_l.rotation.x = -2.4 + p * 2.8; body.rotation.x = 0.25 * s
			"dig": body.rotation.x = 0.45 * s; arm_r.rotation.x = -0.6 - s; arm_l.rotation.x = -0.6 - s
			"build": arm_r.rotation.x = -2.8 * s; body.position.y += 0.08 * s
			"feed": arm_r.rotation.x = -1.2 * s; body.rotation.x = 0.3 * s
		if p >= 1.0: action = ""
	if staff_visible:
		var star: Node3D = staff.get_node("star")
		star.rotation.y = t * 2.0
