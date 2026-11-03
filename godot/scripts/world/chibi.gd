class_name Chibi
extends Node3D
## Chibi character: big head, short limbs, a painted face (FaceShader) that blinks and emotes, bouncy procedural animation.
const P := preload("res://scripts/world/palette.gd")
const HEAD_R := 0.4
const ACTION_LENGTH := {"wave": 1.6, "clap": 1.4, "celebrate": 1.9, "surprised": 0.9, "chop": 0.55, "mine": 0.6, "dig": 0.7, "build": 0.9, "nod": 0.8, "shrug": 1.0, "feed": 1.0}

var appearance: Dictionary
var body: Node3D
var head: Node3D
var arm_l: Node3D; var arm_r: Node3D; var leg_l: Node3D; var leg_r: Node3D
var staff: Node3D
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
var vis_layer := 1
## Face style drawn by FaceShader on the head: "bean" (small shiny dot eyes, the game's look) or "painted" (big
## glossy eyes, kept for comparison renders).
static var face_style := "bean"
var face_mat: ShaderMaterial

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

# Lathe profiles (radius, height), bottom to top, in body or limb space.
const TORSO := [Vector2(0, 0.27), Vector2(0.12, 0.274), Vector2(0.19, 0.3), Vector2(0.214, 0.36), Vector2(0.22, 0.44), Vector2(0.21, 0.53), Vector2(0.188, 0.6), Vector2(0.155, 0.66), Vector2(0.1, 0.71), Vector2(0, 0.735)]
const WAIST := [Vector2(0, 0.262), Vector2(0.13, 0.266), Vector2(0.198, 0.292), Vector2(0.221, 0.35), Vector2(0.224, 0.42), Vector2(0.2, 0.424), Vector2(0, 0.424)]
const SKIRT := [Vector2(0, 0.43), Vector2(0.215, 0.43), Vector2(0.235, 0.37), Vector2(0.27, 0.29), Vector2(0.29, 0.245), Vector2(0.275, 0.235), Vector2(0, 0.235)]
const DRESS := [Vector2(0, 0.47), Vector2(0.205, 0.47), Vector2(0.226, 0.41), Vector2(0.27, 0.31), Vector2(0.31, 0.21), Vector2(0.33, 0.17), Vector2(0.32, 0.155), Vector2(0, 0.155)]
const TUNIC_HEM := [Vector2(0, 0.43), Vector2(0.222, 0.43), Vector2(0.232, 0.36), Vector2(0.24, 0.3), Vector2(0.232, 0.285), Vector2(0, 0.285)]
const LEG := [Vector2(0, 0.04), Vector2(0.062, 0.03), Vector2(0.074, 0.0), Vector2(0.07, -0.12), Vector2(0.063, -0.24), Vector2(0.05, -0.27), Vector2(0, -0.275)]
const SHORTS_LEG := [Vector2(0, 0.03), Vector2(0.08, 0.02), Vector2(0.085, -0.04), Vector2(0.088, -0.1), Vector2(0.075, -0.108), Vector2(0, -0.108)]
const ARM := [Vector2(0, 0.045), Vector2(0.045, 0.035), Vector2(0.058, 0.0), Vector2(0.054, -0.1), Vector2(0.048, -0.2), Vector2(0.04, -0.225), Vector2(0, -0.23)]
const SLEEVE := [Vector2(0, 0.05), Vector2(0.05, 0.04), Vector2(0.068, 0.0), Vector2(0.07, -0.07), Vector2(0.066, -0.09), Vector2(0, -0.09)]

static var _lathes: Dictionary = {}
## Smooth surface of revolution from a (radius, height) profile, optionally squashed front-to-back.
static func _lathe(key: String, profile: Array, zscale: float = 1.0) -> ArrayMesh:
	var k := "%s|%.2f" % [key, zscale]
	if _lathes.has(k): return _lathes[k]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	if profile[0].y < profile[profile.size() - 1].y:   # wind every profile top-down so faces point outward
		profile = profile.duplicate(); profile.reverse()
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]; var p1: Vector2 = profile[i + 1]
		for j in seg:
			var a0 := TAU * j / seg; var a1 := TAU * (j + 1) / seg
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x * zscale)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x * zscale)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x * zscale)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x * zscale)
			for v in [v00, v10, v11, v00, v11, v01]: st.add_vertex(v)
	st.index()
	st.generate_normals()
	_lathes[k] = st.commit()
	return _lathes[k]

func _m(mesh: Mesh, color, parent: Node3D, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := P.mi(mesh, P.fabric(color) if not color is Material else color, pos)
	mi.scale = scl; mi.rotation = rot
	parent.add_child(mi)
	return mi

func set_appearance(app: Dictionary) -> void:
	appearance = sanitize(app)
	var a := appearance
	for c in get_children(): c.queue_free(); remove_child(c)
	body = Node3D.new(); add_child(body)
	var skin = P.smooth(a.skin); var top = a.topColor; var bottom = a.bottomColor; var shoes = a.shoesColor
	var bare_legs: bool = a.bottom in ["shorts", "skirt", "dress"]
	var dark := func(c, k: float = 0.25) -> Color: return Color(c).darkened(k)
	# Legs: tapered, with rounded two-tone shoes (soles a shade darker; sandals show the foot).
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 0.1, 0.34, 0); body.add_child(hip)
		_m(_lathe("leg", LEG), skin if bare_legs else bottom, hip, Vector3.ZERO)
		if a.bottom == "shorts": _m(_lathe("shorts_leg", SHORTS_LEG), bottom, hip, Vector3.ZERO)
		if a.bottom == "pants": _m(P.torus(0.066, 0.012, 32), dark.call(bottom, 0.15), hip, Vector3(0, -0.245, 0))
		if a.shoes == "sandals":
			_m(P.sphere(0.075, 28, 18), skin, hip, Vector3(0, -0.3, 0.035), Vector3(0.9, 0.5, 1.3))
			_m(P.rbox(0.15, 0.035, 0.24, 0.015), shoes, hip, Vector3(0, -0.335, 0.03))
			_m(P.torus(0.06, 0.012, 32), shoes, hip, Vector3(0, -0.3, 0.06), Vector3(1, 1, 0.8))
		else:
			_m(P.sphere(0.1, 28, 18), shoes, hip, Vector3(0, -0.29, 0.035), Vector3(0.85, 0.55, 1.3))
			_m(P.rbox(0.17, 0.04, 0.27, 0.018), dark.call(shoes, 0.3), hip, Vector3(0, -0.33, 0.035))
			if a.shoes == "sneakers":
				_m(P.sphere(0.06, 28, 18), dark.call(shoes, 0.08), hip, Vector3(0, -0.3, 0.11), Vector3(1, 0.55, 0.9))
			if a.shoes == "boots":
				_m(P.cyl(0.075, 0.08, 0.15, 24), shoes, hip, Vector3(0, -0.22, 0))
				_m(P.torus(0.078, 0.016, 32), dark.call(shoes, 0.2), hip, Vector3(0, -0.15, 0))
		if s < 0: leg_l = hip
		else: leg_r = hip
	# Torso: a soft bell shape in the top's colour, with the bottom garment over the hips.
	var torso_col = bottom if a.top == "overalls" else top
	_m(_lathe("torso", TORSO, 0.86), top, body, Vector3.ZERO)
	if a.bottom in ["pants", "shorts"] or a.top == "overalls":
		_m(_lathe("waist", WAIST, 0.87), bottom, body, Vector3.ZERO)
		_m(P.torus(0.223, 0.012, 40), dark.call(bottom, 0.2), body, Vector3(0, 0.42, 0), Vector3(1, 1, 0.87))
	if a.bottom == "skirt": _m(_lathe("skirt", SKIRT, 0.88), bottom, body, Vector3.ZERO); _m(P.torus(0.285, 0.012, 40), dark.call(bottom, 0.18), body, Vector3(0, 0.243, 0), Vector3(1, 1, 0.88))
	if a.bottom == "dress": _m(_lathe("dress", DRESS, 0.88), top, body, Vector3.ZERO); _m(P.torus(0.325, 0.014, 40), Color(top).lightened(0.3), body, Vector3(0, 0.165, 0), Vector3(1, 1, 0.88))
	match a.top:
		"tee":
			_m(P.torus(0.1, 0.018, 32), dark.call(top, 0.18), body, Vector3(0, 0.715, 0.0), Vector3(1, 1, 0.86))
		"sweater":
			_m(P.torus(0.105, 0.03, 32), dark.call(top, 0.12), body, Vector3(0, 0.71, 0.0), Vector3(1, 1, 0.86))
			_m(P.torus(0.213, 0.022, 40), dark.call(top, 0.12), body, Vector3(0, 0.3, 0), Vector3(1, 1, 0.86))
		"overalls":
			_m(P.rbox(0.25, 0.22, 0.06, 0.03), torso_col, body, Vector3(0, 0.5, 0.17), Vector3.ONE, Vector3(-0.12, 0, 0))
			_m(P.rbox(0.09, 0.06, 0.02, 0.01), dark.call(torso_col, 0.15), body, Vector3(0, 0.5, 0.205), Vector3.ONE, Vector3(-0.12, 0, 0))
			for s in [-1, 1]:
				_m(P.rbox(0.045, 0.2, 0.3, 0.015), torso_col, body, Vector3(s * 0.09, 0.62, 0.0), Vector3.ONE, Vector3(0, 0, -s * 0.12))
				_m(P.sphere(0.018, 12, 8), P.GOLD, body, Vector3(s * 0.085, 0.585, 0.195))
		"tunic":
			_m(_lathe("tunic_hem", TUNIC_HEM, 0.87), top, body, Vector3.ZERO)
			_m(P.torus(0.222, 0.02, 40), "8b5a3c", body, Vector3(0, 0.43, 0), Vector3(1, 1, 0.87))
			_m(P.rbox(0.07, 0.06, 0.03, 0.01), P.GOLD, body, Vector3(0, 0.43, 0.195))
		"jacket":
			_m(P.rbox(0.09, 0.4, 0.04, 0.02), "fffaf0", body, Vector3(0, 0.5, 0.17), Vector3.ONE, Vector3(-0.08, 0, 0))
			for s in [-1, 1]:
				_m(P.rbox(0.07, 0.16, 0.03, 0.015), dark.call(top, 0.15), body, Vector3(s * 0.075, 0.64, 0.15), Vector3.ONE, Vector3(-0.35, 0, s * 0.35))
				_m(P.sphere(0.015, 12, 8), P.GOLD, body, Vector3(s * 0.06, 0.48 - 0.0, 0.19))
		"sailor":
			_m(P.rbox(0.34, 0.06, 0.24, 0.03), "2f5fa8", body, Vector3(0, 0.7, -0.06), Vector3.ONE, Vector3(-0.15, 0, 0))
			for s in [-1, 1]: _m(P.rbox(0.2, 0.05, 0.03, 0.015), "2f5fa8", body, Vector3(s * 0.06, 0.64, 0.17), Vector3.ONE, Vector3(-0.2, 0, s * 0.7))
			_m(P.cone(0.05, 0.12, 16), "e85d75", body, Vector3(0, 0.58, 0.19), Vector3.ONE, Vector3(PI, 0, 0))
	# Arms: tapered sleeves (short sleeves show the arm), mitten hands with a thumb.
	var long_sleeves: bool = not a.top in ["tee", "overalls"]
	for s in [-1, 1]:
		var sh := Node3D.new(); sh.position = Vector3(s * 0.22, 0.62, 0); body.add_child(sh)
		var arm := Node3D.new(); arm.rotation.z = s * 0.15; sh.add_child(arm)
		_m(_lathe("arm", ARM), top if long_sleeves else skin, arm, Vector3.ZERO)
		if long_sleeves: _m(P.torus(0.052, 0.012, 32), dark.call(top, 0.15), arm, Vector3(0, -0.205, 0))
		else: _m(_lathe("sleeve", SLEEVE), top if a.top == "tee" else torso_col, arm, Vector3.ZERO)
		_m(P.sphere(0.064, 28, 18), skin, arm, Vector3(0, -0.255, 0.005), Vector3(0.95, 1.05, 0.8))
		_m(P.sphere(0.028, 16, 10), skin, arm, Vector3(-s * 0.0 + 0.0, -0.235, 0.05), Vector3(1, 1.2, 1))
		if s < 0: arm_l = sh
		else: arm_r = sh
	staff = Node3D.new(); staff.position = Vector3(0.03, -0.26, 0.02); staff.rotation.x = 0.2; staff.visible = staff_visible; arm_r.add_child(staff)
	_m(P.cyl(0.025, 0.03, 0.95, 24), "a0623a", staff, Vector3(0, 0.2, 0))
	_m(P.torus(0.09, 0.022, 32), P.GOLD, staff, Vector3(0, 0.72, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	var star := _m(P.sphere(0.1, 4, 2), P.unique_mat("fff2a8", "ffd35c", 2.0), staff, Vector3(0, 0.72, 0)); star.name = "star"
	head = Node3D.new(); head.position.y = 0.7; body.add_child(head)
	face_mat = FaceShader.material()
	face_mat.set_shader_parameter("skin", Color(a.skin))
	face_mat.set_shader_parameter("eye_color", Color(a.eyeColor))
	face_mat.set_shader_parameter("brow_color", Color(a.hairColor).darkened(0.35))
	face_mat.set_shader_parameter("style", 0 if face_style == "painted" else 1)
	face_mat.set_shader_parameter("sparkle", a.eyeShape == "sparkle")
	_m(P.sphere(HEAD_R, 48, 32), face_mat, head, Vector3(0, HEAD_R * 0.92, 0))
	for s in [-1, 1]: _m(P.sphere(0.07, 28, 18), skin, head, Vector3(s * HEAD_R * 0.98, HEAD_R * 0.9, 0), Vector3(0.6, 1, 0.8))
	_build_hair(a.hair, a.hairColor, a.hat)
	call_deferred("apply_layer")
	if a.hat != "none": _build_hat(a.hat, a.hatColor)
	match a.accessory:
		"glasses":
			for s in [-1, 1]: _m(P.torus(0.08, 0.014, 32), "3a3a4a", head, Vector3(s * 0.15, HEAD_R * 0.85, HEAD_R * 0.97), Vector3.ONE, Vector3(PI / 2, 0, 0))
		"beard": _m(P.sphere(0.26, 28, 18), P.smooth(a.hairColor), head, Vector3(0, HEAD_R * 0.45, 0.14), Vector3(1, 0.7, 0.8))
		"scarf": _m(P.torus(0.17, 0.06, 32), a.hatColor, body, Vector3(0, 0.68, 0))
		"backpack": _m(P.rbox(0.3, 0.32, 0.16, 0.06), a.hatColor, body, Vector3(0, 0.52, -0.25))
		"bowtie":
			for s in [-1, 1]: _m(P.cone(0.05, 0.1, 16), "e85d75", body, Vector3(s * 0.05, 0.66, 0.19), Vector3.ONE, Vector3(0, 0, s * PI / 2))

func apply_layer() -> void:
	for m in find_children("*", "VisualInstance3D", true, false): m.layers = vis_layer

func _refresh_face() -> void:
	if face_mat == null: return
	_refresh_painted()

const MOUTH_IDS := {"smile": 0, "grin": 1, "o": 2, "calm": 3, "cat": 4, "sad": 5}
func _refresh_painted() -> void:
	var shape: String = appearance.eyeShape
	var mode := 0
	match shape:
		"happy": mode = 1
		"sleepy": mode = 4
		"wide": mode = 3
	var raise := 0.0
	match mood:
		"happy": mode = 1
		"surprised": mode = 3; raise = 1.0
		"sleepy": mode = 2
		"sad": raise = 0.4
	var mouth: String = appearance.mouth
	if mood == "happy": mouth = "grin"
	elif mood == "surprised": mouth = "o"
	elif mood == "sad": mouth = "sad"
	elif talking and fmod(t * 9.0, 2.0) > 1.0: mouth = "o"
	face_mat.set_shader_parameter("eye_mode", mode)
	face_mat.set_shader_parameter("blink", 1.0 if blink_t > 0.0 else 0.0)
	face_mat.set_shader_parameter("mouth", MOUTH_IDS.get(mouth, 0))
	face_mat.set_shader_parameter("brow_raise", raise)

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

func _build_hair(style: String, color: String, hat: String = "none") -> void:
	var g := Node3D.new(); g.position.y = HEAD_R * 0.92; head.add_child(g)
	var hm := P.smooth(color)
	_m(P.hemi(HEAD_R * 1.06, 32), hm, g, Vector3(0, HEAD_R * 0.04, -0.02), Vector3.ONE, Vector3(-0.22, 0, 0))
	# fringe: separate rounded locks across the forehead read as hair rather than a helmet
	if not style in ["spiky", "curly"] and not hat in ["beanie", "captain", "chef"]:
		var locks := [-0.95, -0.5, -0.05, 0.42, 0.88] if style != "short" else [-0.7, -0.15, 0.4, 0.85]
		for i in locks.size():
			var th: float = locks[i]
			var lk := Node3D.new(); lk.rotation = Vector3(0, th, 0); g.add_child(lk)
			var ln := 1.2 + 0.12 * sin(i * 2.3)
			_m(P.sphere(0.12, 24, 16), hm, lk, Vector3(0, HEAD_R * 0.62, HEAD_R * 0.8), Vector3(1.0, ln, 0.55), Vector3(-0.55, 0, 0))
	if style in ["bob", "long", "pigtails", "ponytail", "bun"]:
		_m(P.sphere(HEAD_R * 1.06, 28, 18), hm, g, Vector3(0, -0.02, -0.06), Vector3(1.04, 0.95, 0.95))
		for s in [-1, 1]: _m(P.sphere(0.16, 28, 18), hm, g, Vector3(s * 0.33, -0.12, 0.08), Vector3(0.7, 1.3, 0.9))
	if style == "long": _m(P.rbox(0.7, 0.75, 0.25, 0.12), hm, g, Vector3(0, -0.3, -0.25))
	if style == "pigtails":
		for s in [-1, 1]: _m(P.sphere(0.15, 28, 18), hm, g, Vector3(s * 0.47, -0.15, -0.05), Vector3(0.9, 1.4, 0.9))
	if style == "ponytail": _m(P.sphere(0.14, 28, 18), hm, g, Vector3(0, 0.0, -0.48), Vector3(0.9, 1.6, 0.9), Vector3(0.6, 0, 0))
	if style == "bun": _m(P.sphere(0.17, 28, 18), hm, g, Vector3(0, 0.42, -0.1))
	if style == "spiky":
		for n in 7:
			var a := n / 7.0 * TAU
			_m(P.cone(0.1, 0.28, 16), hm, g, Vector3(cos(a) * 0.22, 0.36, sin(a) * 0.22 - 0.05), Vector3.ONE, Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7))
	if style == "curly":
		for n in 12:
			var a := n / 12.0 * TAU
			_m(P.sphere(0.13, 28, 18), hm, g, Vector3(cos(a) * 0.36, 0.18 + (n % 2) * 0.1, sin(a) * 0.36 - 0.05))
	if style == "short": _m(P.sphere(0.12, 28, 18), hm, g, Vector3(0.05, 0.42, 0.1), Vector3(1.2, 0.5, 1))

func _build_hat(kind: String, color: String) -> void:
	var g := Node3D.new(); g.position.y = HEAD_R * 0.92; head.add_child(g)
	match kind:
		"beret": _m(P.sphere(0.36, 28, 18), color, g, Vector3(0.06, 0.36, 0), Vector3(1.1, 0.4, 1.1), Vector3(0, 0, -0.25))
		"beanie":
			_m(P.hemi(0.43, 32), color, g, Vector3(0, 0.08, 0))
			_m(P.sphere(0.08, 28, 18), "ffffff", g, Vector3(0, 0.52, 0))
		"bow":
			for s in [-1, 1]: _m(P.cone(0.1, 0.2, 16), color, g, Vector3(s * 0.12, 0.42, 0.05), Vector3.ONE, Vector3(0, 0, s * PI / 2))
			_m(P.sphere(0.05, 28, 18), color, g, Vector3(0, 0.42, 0.05))
		"sunhat":
			_m(P.cyl(0.62, 0.62, 0.03, 24), "f2d27a", g, Vector3(0, 0.3, 0))
			_m(P.cyl(0.3, 0.36, 0.24, 24), "f2d27a", g, Vector3(0, 0.42, 0))
			_m(P.cyl(0.365, 0.365, 0.06, 24), color, g, Vector3(0, 0.34, 0))
		"chef":
			_m(P.cyl(0.3, 0.28, 0.25, 24), "ffffff", g, Vector3(0, 0.4, 0))
			_m(P.sphere(0.33, 28, 18), "ffffff", g, Vector3(0, 0.6, 0), Vector3(1, 0.75, 1))
		"flowerCrown":
			for n in 9:
				var a := n / 9.0 * TAU
				_m(P.sphere(0.065, 28, 18), P.FLOWERS[n % 5], g, Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36))
		"captain":
			_m(P.cyl(0.4, 0.38, 0.22, 24), "ffffff", g, Vector3(0, 0.38, 0))
			_m(P.cyl(0.39, 0.39, 0.07, 24), "2f3f6a", g, Vector3(0, 0.3, 0))
			_m(P.box(0.4, 0.03, 0.18), "2f3f6a", g, Vector3(0, 0.28, 0.36))
			_m(P.sphere(0.05, 28, 18), P.GOLD, g, Vector3(0, 0.4, 0.4))
		"crown":
			_m(P.cyl(0.24, 0.24, 0.16, 24), P.GOLD, g, Vector3(0, 0.45, 0))
			for n in 5:
				var a := n / 5.0 * TAU
				_m(P.cone(0.05, 0.12, 16), P.GOLD, g, Vector3(cos(a) * 0.23, 0.58, sin(a) * 0.23))
			_m(P.sphere(0.04, 28, 18), "ff5a8a", g, Vector3(0, 0.46, 0.24))
		"goggles":
			_m(P.torus(0.41, 0.03, 32), "6a4a3a", g, Vector3(0, 0.2, 0), Vector3.ONE, Vector3(-0.3, 0, 0))
			for s in [-1, 1]:
				_m(P.cyl(0.09, 0.09, 0.07, 24), "c9a06e", g, Vector3(s * 0.13, 0.3, 0.33), Vector3.ONE, Vector3(PI / 2 - 0.5, 0, 0))
				_m(P.sphere(0.07, 28, 18), P.mat("8fe0ff", "3fa9d6", 0.6), g, Vector3(s * 0.13, 0.31, 0.37), Vector3(1, 1, 0.4))

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
