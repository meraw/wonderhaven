class_name Chibi
extends Node3D
## Chibi character: big head, short limbs, a painted face (FaceShader) that blinks and emotes, bouncy procedural animation.
const P := preload("res://scripts/world/palette.gd")
const HEAD_R := 0.4
const ACTION_LENGTH := {"watch": 1.7, "wave": 1.6, "clap": 1.4, "celebrate": 1.9, "surprised": 0.9, "chop": 0.55, "mine": 0.6, "dig": 0.7, "build": 0.9, "nod": 0.8, "shrug": 1.0, "feed": 1.0, "shake": 1.1}

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
var gait := 0.0
var stride := 0.0
var lean := 0.0
var bank := 0.0
var yaw_rate := 0.0
var last_yaw := INF
var look := 0.0
var look_target := 0.0
var next_glance := 3.0 + randf() * 4.0
var was_airborne := false
var land_age := 9.0
var impact_age := 9.0
var impact_amp := 0.0
var action_prev_p := 0.0

func _init(app: Dictionary = {}) -> void:
	set_appearance(app)

static func colour_ok(c) -> bool:
	return c is String and (c.length() == 7 or c.length() == 6) and Color.html_is_valid(c)

static func sanitize(a: Dictionary) -> Dictionary:
	var A: Dictionary = Data.appearance
	var D: Dictionary = A["default"]
	var out := {}
	var pick := func(k: String, list: Array) -> void: out[k] = a[k] if a.has(k) and list.has(a[k]) else D[k]
	var col := func(k: String) -> void: out[k] = a[k] if a.has(k) and Chibi.colour_ok(a[k]) else D[k]
	col.call("skin"); pick.call("eyeShape", A.EYE_SHAPES); col.call("eyeColor"); pick.call("hair", A.HAIR_STYLES); col.call("hairColor"); pick.call("mouth", A.MOUTHS)
	pick.call("top", A.TOPS); col.call("topColor"); pick.call("bottom", A.BOTTOMS); col.call("bottomColor"); pick.call("shoes", A.SHOES); col.call("shoesColor")
	pick.call("hat", A.HATS); col.call("hatColor"); pick.call("accessory", A.ACCESSORIES)
	var bd = a.get("body", {})
	if bd is Dictionary and not bd.is_empty():
		out["body"] = {"height": clampf(float(bd.get("height", 1.0)), 0.88, 1.12), "width": clampf(float(bd.get("width", 1.0)), 0.88, 1.15),
			"belly": clampf(float(bd.get("belly", 0.0)), 0.0, 1.0)}
	return out

## What to draw: a clothing variant (Data.appearance.variants, a location's own piece) becomes its base shape in its
## own colours (the slot's colour, or accessoryColor for an accessory, and a trim colour where the shape has one).
static func resolve(a: Dictionary) -> Dictionary:
	var V: Dictionary = Data.appearance.get("variants", {})
	var out := a.duplicate()
	for slot in ["hat", "accessory", "shoes", "top", "bottom"]:
		var v: Dictionary = V.get(String(out.get(slot, "")), {})
		if v.is_empty(): continue
		out[slot] = v.base
		if v.has("color"): out["accessoryColor" if slot == "accessory" else slot + "Color"] = v.color
		if v.has("trim"): out[slot + "Trim"] = v.trim
	return out

# Lathe profiles (radius, height), bottom to top, in body or limb space.
const TORSO := [Vector2(0, 0.27), Vector2(0.12, 0.274), Vector2(0.19, 0.3), Vector2(0.214, 0.36), Vector2(0.22, 0.44), Vector2(0.21, 0.53), Vector2(0.188, 0.6), Vector2(0.155, 0.66), Vector2(0.1, 0.71), Vector2(0, 0.735)]
const WAIST := [Vector2(0, 0.262), Vector2(0.13, 0.266), Vector2(0.198, 0.292), Vector2(0.221, 0.35), Vector2(0.224, 0.42), Vector2(0.2, 0.424), Vector2(0, 0.424)]
const SKIRT := [Vector2(0, 0.43), Vector2(0.215, 0.43), Vector2(0.235, 0.37), Vector2(0.27, 0.29), Vector2(0.29, 0.245), Vector2(0.275, 0.235), Vector2(0, 0.235)]
const DRESS := [Vector2(0, 0.47), Vector2(0.205, 0.47), Vector2(0.226, 0.41), Vector2(0.27, 0.31), Vector2(0.31, 0.21), Vector2(0.33, 0.17), Vector2(0.32, 0.155), Vector2(0, 0.155)]
const COAT_HEM := [Vector2(0, 0.43), Vector2(0.222, 0.43), Vector2(0.236, 0.34), Vector2(0.25, 0.24), Vector2(0.262, 0.15), Vector2(0.256, 0.13), Vector2(0, 0.13)]
const TUNIC_HEM := [Vector2(0, 0.43), Vector2(0.222, 0.43), Vector2(0.232, 0.36), Vector2(0.24, 0.3), Vector2(0.232, 0.285), Vector2(0, 0.285)]
const LEG := [Vector2(0, 0.04), Vector2(0.062, 0.03), Vector2(0.074, 0.0), Vector2(0.07, -0.12), Vector2(0.063, -0.24), Vector2(0.05, -0.27), Vector2(0, -0.275)]
const JEANS_LEG := [Vector2(0, 0.04), Vector2(0.084, 0.03), Vector2(0.091, 0.0), Vector2(0.093, -0.12), Vector2(0.097, -0.22), Vector2(0.1, -0.25), Vector2(0.092, -0.262), Vector2(0, -0.262)]   # baggy, falling over the shoes
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

const EYE_SIZE := 1.45
const EYE_SCALE := {"sparkle": 1.2, "wide": 1.0}
const EYE_SHAPE_SIZE := {"sparkle": 1.22, "wide": 1.55}

static func eye_scale(shape: String) -> float:
	return float(EYE_SCALE.get(shape, EYE_SIZE))

static func eye_size(shape: String) -> float:
	return eye_scale(shape) * float(EYE_SHAPE_SIZE.get(shape, 1.0))

func set_appearance(app: Dictionary) -> void:
	appearance = sanitize(app)
	var a := resolve(appearance)
	for c in get_children(): c.queue_free(); remove_child(c)
	var shape := Node3D.new(); shape.name = "shape"; add_child(shape)
	var bd: Dictionary = a.get("body", {})
	shape.scale = Vector3(float(bd.get("width", 1.0)), float(bd.get("height", 1.0)), float(bd.get("width", 1.0)))
	body = Node3D.new(); shape.add_child(body)
	var skin = P.smooth(a.skin); var top = a.topColor; var bottom = a.bottomColor; var shoes = a.shoesColor
	var bare_legs: bool = a.bottom in ["shorts", "skirt", "dress"]
	var dark := func(c, k: float = 0.25) -> Color: return Color(c).darkened(k)
	# Legs: tapered, with rounded two-tone shoes (soles a shade darker; sandals show the foot).
	for s in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(s * 0.1, 0.34, 0); body.add_child(hip)
		if a.bottom == "jeans":
			_m(_lathe("jeans_leg", JEANS_LEG), P.denim(bottom), hip, Vector3.ZERO)
			_m(P.torus(0.096, 0.014, 32), P.denim(Color(bottom).lightened(0.18)), hip, Vector3(0, -0.245, 0))
		else: _m(_lathe("leg", LEG), skin if bare_legs else bottom, hip, Vector3.ZERO)
		if a.bottom == "shorts": _m(_lathe("shorts_leg", SHORTS_LEG), bottom, hip, Vector3.ZERO)
		if a.bottom == "pants": _m(P.torus(0.066, 0.012, 32), dark.call(bottom, 0.15), hip, Vector3(0, -0.245, 0))
		if a.shoes == "sandals":
			_m(P.sphere(0.075, 28, 18), skin, hip, Vector3(0, -0.3, 0.035), Vector3(0.9, 0.5, 1.3))
			_m(P.rbox(0.15, 0.035, 0.24, 0.015), P.leather(shoes), hip, Vector3(0, -0.335, 0.03))
			_m(P.torus(0.06, 0.012, 32), P.leather(shoes), hip, Vector3(0, -0.3, 0.06), Vector3(1, 1, 0.8))
		else:
			var upper = shoes if a.shoes == "sneakers" else P.leather(shoes)
			_m(P.sphere(0.1, 28, 18), upper, hip, Vector3(0, -0.29, 0.035), Vector3(0.85, 0.55, 1.3))
			_m(P.rbox(0.17, 0.04, 0.27, 0.018), P.leather(dark.call(shoes, 0.3)), hip, Vector3(0, -0.33, 0.035))
			if a.shoes == "sneakers":
				_m(P.sphere(0.06, 28, 18), dark.call(shoes, 0.08), hip, Vector3(0, -0.3, 0.11), Vector3(1, 0.55, 0.9))
			if a.shoes == "boots":
				_m(P.cyl(0.075, 0.08, 0.15, 24), P.leather(shoes), hip, Vector3(0, -0.22, 0))
				_m(P.torus(0.078, 0.016, 32), P.leather(dark.call(shoes, 0.2)), hip, Vector3(0, -0.15, 0))
		if s < 0: leg_l = hip
		else: leg_r = hip
	# Torso: a soft bell shape in the top's colour, with the bottom garment over the hips.
	var torso_col = bottom if a.top == "overalls" else top
	_m(_lathe("torso", TORSO, 0.86), top, body, Vector3.ZERO)
	var belly := float(bd.get("belly", 0.0))
	var tummy: MeshInstance3D = null
	if belly > 0.01: tummy = _m(P.sphere(0.2, 24, 16), top, body, Vector3(0, 0.43, 0.05 + 0.04 * belly), Vector3(1.0 + 0.05 * belly, 0.82 + 0.12 * belly, 0.72 + 0.28 * belly))
	if a.bottom in ["pants", "shorts", "jeans"] or a.top == "overalls":
		_m(_lathe("waist", WAIST, 0.87), P.denim(bottom) if a.bottom == "jeans" or a.top == "overalls" else bottom, body, Vector3.ZERO)
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
			_m(P.rbox(0.25, 0.22, 0.06, 0.03), P.denim(torso_col), body, Vector3(0, 0.5, 0.17), Vector3.ONE, Vector3(-0.12, 0, 0))
			_m(P.rbox(0.09, 0.06, 0.02, 0.01), dark.call(torso_col, 0.15), body, Vector3(0, 0.5, 0.205), Vector3.ONE, Vector3(-0.12, 0, 0))
			for s in [-1, 1]:
				_m(P.rbox(0.045, 0.2, 0.3, 0.015), P.denim(torso_col), body, Vector3(s * 0.09, 0.62, 0.0), Vector3.ONE, Vector3(0, 0, -s * 0.12))
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
		"suit":   # lapels over a white shirt and a tie
			_m(P.rbox(0.1, 0.2, 0.03, 0.015), "f4f1ea", body, Vector3(0, 0.6, 0.162), Vector3.ONE, Vector3(-0.22, 0, 0))
			_m(P.sphere(0.022, 12, 8), "8a2434", body, Vector3(0, 0.672, 0.15))
			_m(P.rbox(0.045, 0.19, 0.02, 0.01), "8a2434", body, Vector3(0, 0.575, 0.178), Vector3.ONE, Vector3(-0.2, 0, 0))
			for s in [-1, 1]: _m(P.rbox(0.07, 0.22, 0.03, 0.015), dark.call(top, 0.14), body, Vector3(s * 0.072, 0.58, 0.165), Vector3.ONE, Vector3(-0.22, 0, s * 0.32))
			for y in [0.44, 0.37]: _m(P.sphere(0.014, 12, 8), dark.call(top, 0.4), body, Vector3(0.03, y, 0.19))
		"hoodie":   # oversized: a roomier body, the hood down at the back, a front pocket and drawstrings
			_m(_lathe("torso", TORSO, 0.86), top, body, Vector3(0, -0.012, 0), Vector3(1.07, 1.02, 1.07))
			_m(P.sphere(0.2, 24, 16), dark.call(top, 0.08), body, Vector3(0, 0.71, -0.14), Vector3(1.1, 0.7, 0.85))
			_m(P.rbox(0.26, 0.12, 0.04, 0.03), dark.call(top, 0.08), body, Vector3(0, 0.37, 0.2), Vector3.ONE, Vector3(0.1, 0, 0))
			_m(P.torus(0.205, 0.024, 40), dark.call(top, 0.12), body, Vector3(0, 0.285, 0), Vector3(1.07, 1, 0.92))
			for s in [-1, 1]:
				_m(P.cyl(0.008, 0.008, 0.15, 6), "f4f1ea", body, Vector3(s * 0.035, 0.6, 0.18), Vector3.ONE, Vector3(-0.25, 0, 0))
				_m(P.sphere(0.014, 8, 6), "f4f1ea", body, Vector3(s * 0.035, 0.525, 0.2))
		"windbreaker":   # colour-blocked shell: a band across the chest, a white stripe, a zip and a stand-up collar
			var tc := Color(top)
			var accent := Color.from_hsv(fposmod(tc.h + 0.42, 1.0), clampf(tc.s * 0.9, 0.35, 0.85), clampf(tc.v + 0.1, 0.4, 0.95))
			_m(P.torus(0.198, 0.05, 40), accent, body, Vector3(0, 0.56, 0), Vector3(1, 1, 0.87))
			_m(P.torus(0.217, 0.012, 40), "f4f1ea", body, Vector3(0, 0.48, 0), Vector3(1, 1, 0.87))
			_m(P.box(0.014, 0.42, 0.012), "c9ccd2", body, Vector3(0, 0.49, 0.192), Vector3.ONE, Vector3(-0.1, 0, 0))
			_m(P.torus(0.11, 0.032, 32), dark.call(top, 0.18), body, Vector3(0, 0.71, 0.0), Vector3(1, 1.3, 0.86))
		"shirt":   # a short-sleeved uniform shirt: collar points, buttons, a breast pocket and shoulder straps
			for s in [-1, 1]:
				_m(P.rbox(0.075, 0.022, 0.06, 0.01), Color(top).lightened(0.12), body, Vector3(s * 0.05, 0.69, 0.115), Vector3.ONE, Vector3(0.35, s * 0.5, 0))
				_m(P.rbox(0.09, 0.022, 0.05, 0.01), dark.call(top, 0.3), body, Vector3(s * 0.15, 0.662, 0.0), Vector3.ONE, Vector3(0, 0, -s * 0.45))
			_m(P.box(0.024, 0.36, 0.01), dark.call(top, 0.08), body, Vector3(0, 0.5, 0.19), Vector3.ONE, Vector3(-0.08, 0, 0))
			for y in [0.6, 0.5, 0.4]: _m(P.sphere(0.011, 8, 6), "f4f1ea", body, Vector3(0, y, 0.198 - absf(y - 0.45) * 0.12))
			_m(P.rbox(0.075, 0.075, 0.012, 0.01), dark.call(top, 0.06), body, Vector3(0.095, 0.56, 0.172), Vector3.ONE, Vector3(-0.2, 0.35, 0))
		"longcoat":   # a winter coat to the knees: wide lapels, a belt, two rows of buttons
			_m(_lathe("coat_hem", COAT_HEM, 0.87), top, body, Vector3.ZERO)
			for s in [-1, 1]:
				_m(P.rbox(0.09, 0.24, 0.03, 0.015), dark.call(top, 0.12), body, Vector3(s * 0.075, 0.6, 0.16), Vector3.ONE, Vector3(-0.25, 0, s * 0.4))
				for y in [0.52, 0.44, 0.36]: _m(P.sphere(0.013, 8, 6), dark.call(top, 0.4), body, Vector3(s * 0.05, y, 0.2))
			_m(P.torus(0.226, 0.016, 40), dark.call(top, 0.2), body, Vector3(0, 0.42, 0), Vector3(1, 1, 0.87))
		"workjacket":   # a long work jacket with big pockets and a corduroy collar
			_m(_lathe("tunic_hem", TUNIC_HEM, 0.87), top, body, Vector3.ZERO)
			for s in [-1, 1]:
				_m(P.rbox(0.1, 0.09, 0.03, 0.015), dark.call(top, 0.12), body, Vector3(s * 0.1, 0.36, 0.205), Vector3.ONE, Vector3(0, s * 0.35, 0))
				_m(P.rbox(0.09, 0.12, 0.03, 0.015), "5a4030", body, Vector3(s * 0.075, 0.66, 0.14), Vector3.ONE, Vector3(-0.4, 0, s * 0.4))
			for y in [0.55, 0.47, 0.39]: _m(P.sphere(0.013, 8, 6), "3a2c22", body, Vector3(0, y, 0.2))
		"sailor":
			_m(P.rbox(0.34, 0.06, 0.24, 0.03), "2f5fa8", body, Vector3(0, 0.7, -0.06), Vector3.ONE, Vector3(-0.15, 0, 0))
			for s in [-1, 1]: _m(P.rbox(0.2, 0.05, 0.03, 0.015), "2f5fa8", body, Vector3(s * 0.06, 0.64, 0.17), Vector3.ONE, Vector3(-0.2, 0, s * 0.7))
			_m(P.cone(0.05, 0.12, 16), "e85d75", body, Vector3(0, 0.58, 0.19), Vector3.ONE, Vector3(PI, 0, 0))
	# Arms: tapered sleeves (short sleeves show the arm), mitten hands with a thumb.
	var long_sleeves: bool = not a.top in ["tee", "overalls", "shirt"]
	for s in [-1, 1]:
		var sh := Node3D.new(); sh.position = Vector3(s * 0.22, 0.62, 0); body.add_child(sh)
		var arm := Node3D.new(); arm.rotation.z = s * 0.15; sh.add_child(arm)
		_m(_lathe("arm", ARM), top if long_sleeves else skin, arm, Vector3.ZERO)
		if long_sleeves: _m(P.torus(0.052, 0.012, 32), dark.call(top, 0.15), arm, Vector3(0, -0.205, 0))
		else: _m(_lathe("sleeve", SLEEVE), top if a.top in ["tee", "shirt"] else torso_col, arm, Vector3.ZERO)
		_m(P.sphere(0.064, 28, 18), skin, arm, Vector3(0, -0.255, 0.005), Vector3(0.95, 1.05, 0.8))
		_m(P.sphere(0.028, 16, 10), skin, arm, Vector3(-s * 0.0 + 0.0, -0.235, 0.05), Vector3(1, 1.2, 1))
		if s < 0: arm_l = sh
		else: arm_r = sh
	# The Geometra's clipboard (the build tool), gripped by its top edge: board, plans, the steel clip and a pencil.
	staff = Node3D.new(); staff.position = Vector3(0.03, -0.26, 0.02); staff.rotation.x = 0.2; staff.visible = staff_visible; arm_r.add_child(staff)
	_m(P.rbox(0.014, 0.27, 0.2, 0.01), "b58a5a", staff, Vector3(0.01, -0.13, 0.03))
	_m(P.box(0.006, 0.23, 0.17), "fbf8ef", staff, Vector3(0.02, -0.15, 0.03))
	for k in 4: _m(P.box(0.004, 0.006, 0.12), "8fa6c9", staff, Vector3(0.024, -0.09 - k * 0.04, 0.035))
	_m(P.rbox(0.024, 0.03, 0.08, 0.006), "c9ccd2", staff, Vector3(0.02, -0.01, 0.03))
	_m(P.cyl(0.008, 0.008, 0.16, 6), "f2c94c", staff, Vector3(0.032, -0.05, 0.1), Vector3.ONE, Vector3(0.2, 0, 0))
	head = Node3D.new(); head.position.y = 0.7; body.add_child(head)
	face_mat = FaceShader.material()
	face_mat.set_shader_parameter("skin", Color(a.skin))
	face_mat.set_shader_parameter("eye_color", Color(a.eyeColor))
	face_mat.set_shader_parameter("brow_color", Color(a.hairColor).darkened(0.35))
	face_mat.set_shader_parameter("style", 0 if face_style == "painted" else 1)
	face_mat.set_shader_parameter("sparkle", a.eyeShape == "sparkle")
	face_mat.set_shader_parameter("eye_style", {"sparkle": 1, "wide": 2}.get(a.eyeShape, 0))
	face_mat.set_shader_parameter("eye_scale", 1.0 if face_style == "painted" else eye_scale(a.eyeShape))
	_m(P.sphere(HEAD_R, 48, 32), face_mat, head, Vector3(0, HEAD_R * 0.92, 0))
	for s in [-1, 1]: _m(P.sphere(0.07, 28, 18), skin, head, Vector3(s * HEAD_R * 0.98, HEAD_R * 0.9, 0), Vector3(0.6, 1, 0.8))
	_build_hair(a.hair, a.hairColor, a.hat)
	call_deferred("apply_layer")
	if a.hat != "none": _build_hat(a.hat, a.hatColor, String(a.get("hatTrim", "")))
	match a.accessory:
		"glasses":
			for s in [-1, 1]: _m(P.torus(0.08, 0.014, 32), "3a3a4a", head, Vector3(s * 0.15, HEAD_R * 0.85, HEAD_R * 0.97), Vector3.ONE, Vector3(PI / 2, 0, 0))
		"beard": _m(P.sphere(0.26, 28, 18), P.smooth(a.hairColor), head, Vector3(0, HEAD_R * 0.45, 0.14), Vector3(1, 0.7, 0.8))
		"scarf": _m(P.torus(0.17, 0.06, 32), a.get("accessoryColor", a.hatColor), body, Vector3(0, 0.68, 0))
		"backpack": _m(P.rbox(0.3, 0.32, 0.16, 0.06), a.get("accessoryColor", a.hatColor), body, Vector3(0, 0.52, -0.25))
		"bowtie":
			for s in [-1, 1]: _m(P.cone(0.05, 0.1, 16), "e85d75", body, Vector3(s * 0.05, 0.66, 0.19), Vector3.ONE, Vector3(0, 0, s * PI / 2))
		"sash":   # the tricolour sash, from the right shoulder to the left hip, with a gold tassel
			var tilt := Basis(Vector3(0, 0, 1), -0.72)
			var nrm := tilt * Vector3.UP
			var cols := ["2e8b4a", "f4f1ea", "c8323a"]
			for k in 3: _m(P.torus(0.215, 0.019, 40), cols[k], body, Vector3(0, 0.49, 0) + nrm * (k - 1) * 0.036, Vector3(1.14, 1, 0.94), Vector3(0, 0, -0.72))
			_m(P.sphere(0.035, 12, 8), P.GOLD, body, Vector3(-0.2, 0.32, 0.12))
		"pens":   # a row of pens and a screwdriver in the chest pocket
			var pc := ["2f5fa8", "c8323a", "1d1f26", "3c9a4a"]
			for k in 4: _m(P.cyl(0.009, 0.009, 0.13, 6), pc[k], body, Vector3(-0.1 + k * 0.022, 0.6, 0.205), Vector3.ONE, Vector3(0, 0, (k - 1.5) * 0.08))
			_m(P.cyl(0.016, 0.016, 0.06, 8), "f2c94c", body, Vector3(0.09, 0.64, 0.2))
			_m(P.cyl(0.006, 0.006, 0.07, 6), "c9ccd2", body, Vector3(0.09, 0.58, 0.2))
		"discman":   # a portable CD player clipped at the hip, its lead running up to the collar
			_m(P.cyl(0.075, 0.075, 0.024, 24), "c9ccd2", body, Vector3(0.15, 0.37, 0.16), Vector3.ONE, Vector3(PI / 2, 0.65, 0))
			_m(P.cyl(0.035, 0.035, 0.026, 18), "3a4a8a", body, Vector3(0.157, 0.37, 0.168), Vector3.ONE, Vector3(PI / 2, 0.65, 0))
			_m(P.cyl(0.006, 0.006, 0.26, 4), "2a2a30", body, Vector3(0.11, 0.54, 0.17), Vector3.ONE, Vector3(-0.15, 0, 0.3))
		"apron":   # a baker's apron: bib, skirt with a pocket, neck strap and waist ties
			var ap: String = a.get("accessoryColor", "fffaf0")
			_m(P.rbox(0.25, 0.22, 0.025, 0.02), ap, body, Vector3(0, 0.56, 0.172), Vector3.ONE, Vector3(-0.14, 0, 0))
			_m(P.rbox(0.4, 0.32, 0.025, 0.04), ap, body, Vector3(0, 0.3, 0.24), Vector3.ONE, Vector3(-0.22, 0, 0))
			_m(P.rbox(0.14, 0.08, 0.012, 0.01), dark.call(ap, 0.08), body, Vector3(0, 0.28, 0.26), Vector3.ONE, Vector3(-0.22, 0, 0))
			_m(P.torus(0.115, 0.012, 24), ap, body, Vector3(0, 0.69, 0), Vector3(1, 1, 0.86))
			_m(P.torus(0.226, 0.012, 40), ap, body, Vector3(0, 0.44, 0), Vector3(1, 1, 0.87))
	_follow_belly(tummy, belly)

func _follow_belly(tummy: MeshInstance3D, belly: float) -> void:
	if tummy == null: return
	for mi in body.get_children():
		if not (mi is MeshInstance3D) or mi == tummy: continue
		var p: Vector3 = (mi as MeshInstance3D).position
		if p.z > 0.12 and p.y > 0.22 and p.y < 0.68:
			(mi as MeshInstance3D).position.z = p.z + 0.1 * belly * maxf(0.0, 1.0 - absf(p.y - 0.43) / 0.25)

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
	action = name; action_t = 0.0; action_prev_p = 0.0
	if name in ["celebrate", "clap"]: set_mood("happy", ACTION_LENGTH[name])
	if name == "surprised": set_mood("surprised", 1.2)

func stop_hold() -> void: hold = ""

func head_world_pos() -> Vector3: return head.to_global(Vector3(0, HEAD_R * 0.92, 0))

# ---- Hair ------------------------------------------------------------------------------------------------
## Hair is a sculpted cap: a sphere around the head whose points sink inside the head wherever there should be no
## hair (the face, below the hairline), so the edges form a soft, scalloped hairline with no seams. Clumps,
## a nape and style pieces (tails, buns, spikes, curls) sit on top, and everything shares a hair shader with
## fine strands and a shine band.
const HAIR_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 color : source_color = vec4(0.45, 0.28, 0.16, 1.0);
varying vec3 lp;
varying vec3 ln;
float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x), f = fract(x); return mix(h1(i), h1(i + 1.0), f * f * (3.0 - 2.0 * f)); }
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	vec3 c = color.rgb;
	float ang = atan(lp.x, lp.z);
	c *= 0.9 + 0.12 * n1(ang * 22.0 + lp.y * 3.0) + 0.05 * n1(ang * 61.0);
	float band = smoothstep(0.42, 0.55, ln.y) * smoothstep(0.78, 0.62, ln.y);
	band *= 0.6 + 0.4 * n1(ang * 9.0);
	c = mix(c, c * 1.32 + vec3(0.07), band * 0.7);
	c *= mix(0.86, 1.0, smoothstep(-0.6, 0.2, ln.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	RIM = 0.25;
	RIM_TINT = 0.8;
}
"""
static var _hair_shader: Shader
static var _hair_mats: Dictionary = {}
static var _hair_caps: Dictionary = {}

static func hair_code() -> String:
	if not P.real: return HAIR_SHADER
	return P.shader_code(HAIR_SHADER.replace("\tRIM = 0.25;\n\tRIM_TINT = 0.8;\n", "").replace("band * 0.7", "band * 0.35"), 0.45, 0.4, 1.0)

static func hair_material(color) -> ShaderMaterial:
	var key := str(color)
	if _hair_mats.has(key): return _hair_mats[key]
	if _hair_shader == null: _hair_shader = Shader.new(); _hair_shader.code = hair_code()
	var m := ShaderMaterial.new(); m.shader = _hair_shader
	m.set_shader_parameter("color", Color(color))
	_hair_mats[key] = m
	return m

## Per style: fringe height, side and back length (as the y of the head direction), bottom flare, and
## whether the fringe sweeps to one side.
const HAIR_SHAPES := {
	"short": {"fringe": 0.38, "side": -0.12, "back": -0.74, "flare": 0.0, "sweep": 0.18},
	"bob": {"fringe": 0.3, "side": -0.62, "back": -0.84, "flare": 0.08, "sweep": 0.0},
	"pigtails": {"fringe": 0.3, "side": -0.25, "back": -0.78, "flare": 0.0, "sweep": 0.0},
	"bun": {"fringe": 0.36, "side": -0.2, "back": -0.76, "flare": 0.0, "sweep": 0.12},
	"long": {"fringe": 0.3, "side": -0.7, "back": -0.95, "flare": 0.03, "sweep": 0.0},
	"spiky": {"fringe": 0.46, "side": -0.05, "back": -0.7, "flare": 0.0, "sweep": 0.0},
	"curly": {"fringe": 0.4, "side": -0.3, "back": -0.8, "flare": 0.04, "sweep": 0.0},
	"ponytail": {"fringe": 0.32, "side": -0.22, "back": -0.76, "flare": 0.0, "sweep": 0.1},
}

## How much hair grows at head direction d (0 none .. 1 full).
static func hair_amount(d: Vector3, shape: Dictionary) -> float:
	var front := smoothstep(0.05, 0.4, d.z)                     # the face side of the head
	var cheek := 1.0 - smoothstep(0.5, 0.72, absf(d.x))         # within the face's width
	var fringe: float = shape.fringe + shape.sweep * d.x + 0.045 * sin(d.x * 15.0 + 0.6) + 0.02 * sin(d.x * 31.0)
	var face := front * cheek * smoothstep(fringe + 0.045, fringe - 0.07, d.y)
	var backness := smoothstep(-0.2, -0.85, d.z)
	var low: float = lerpf(shape.side, shape.back, backness) + 0.035 * sin(atan2(d.x, d.z) * 9.0)
	var length := smoothstep(low - 0.06, low + 0.06, d.y)
	return clampf((1.0 - face) * length, 0.0, 1.0)

static func hair_cap(style: String) -> ArrayMesh:
	if _hair_caps.has(style): return _hair_caps[style]
	var shape: Dictionary = HAIR_SHAPES.get(style, HAIR_SHAPES.bob)
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 112; sm.rings = 64
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new(); nz.seed = style.hash() & 0xffff; nz.frequency = 1.0; nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for i in v.size():
		var d := v[i].normalized() if v[i].length() > 0.0001 else Vector3.UP
		var amt := hair_amount(d, shape)
		var ang := atan2(d.x, d.z)
		var clumps := 0.022 * nz.get_noise_2d(ang * 3.2, d.y * 1.4) + 0.012 * nz.get_noise_2d(ang * 9.0, d.y * 4.0)
		var top := 0.025 * smoothstep(0.3, 0.9, d.y)
		var flare: float = shape.flare * smoothstep(0.1, -0.5, d.y)
		var r := lerpf(0.965, 1.085 + clumps + top + flare, amt)
		v[i] = d * HEAD_R * r
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = null
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new(); st.create_from(am, 0); st.generate_normals()
	_hair_caps[style] = st.commit()
	return _hair_caps[style]

func _build_hair(style: String, color: String, hat: String = "none") -> void:
	var g := Node3D.new(); g.position.y = HEAD_R * 0.92; head.add_child(g)
	var hm := hair_material(color)
	_m(hair_cap(style), hm, g, Vector3.ZERO)
	var lock := func(pos: Vector3, scl: Vector3, rot: Vector3) -> void: _m(P.sphere(0.1, 24, 16), hm, g, pos, scl, rot)
	match style:
		"long":
			# a soft fall of hair down the back, in three overlapping locks that taper
			for k in 3:
				var x := (k - 1) * 0.17
				lock.call(Vector3(x, -0.36, -0.27 + absf(x) * 0.25), Vector3(1.05, 3.4, 0.75), Vector3(0.18, 0, -x * 0.5))
		"pigtails":
			for s in [-1, 1]:
				_m(P.sphere(0.05, 16, 10), P.fabric("ff8fab"), g, Vector3(s * 0.4, -0.04, -0.1))
				lock.call(Vector3(s * 0.47, -0.2, -0.12), Vector3(1.3, 2.3, 1.2), Vector3(0, 0, s * 0.35))
		"ponytail":
			_m(P.sphere(0.05, 16, 10), P.fabric("ff8fab"), g, Vector3(0, 0.06, -0.42))
			lock.call(Vector3(0, -0.12, -0.5), Vector3(1.25, 2.6, 1.15), Vector3(0.55, 0, 0))
		"bun": _m(P.sphere(0.15, 28, 18), hm, g, Vector3(0, 0.43, -0.12), Vector3(1, 0.9, 1))
		"spiky":
			for n in 9:
				var a := n / 9.0 * TAU
				_m(P.cone(0.1, 0.3, 16), hm, g, Vector3(cos(a) * 0.2, 0.34, sin(a) * 0.2 - 0.06), Vector3.ONE, Vector3(sin(a) * 0.75, 0, -cos(a) * 0.75))
		"curly":
			for n in 14:
				var a := n / 14.0 * TAU
				_m(P.sphere(0.12, 24, 16), hm, g, Vector3(cos(a) * 0.37, 0.12 + (n % 2) * 0.12, sin(a) * 0.37 - 0.04))
		"short":
			for s in [-1, 1]: lock.call(Vector3(s * 0.38, 0.0, 0.05), Vector3(0.6, 1.1, 0.9), Vector3(0, 0, s * 0.2))

func wear_hat(id: String) -> void:
	if id != "none" and not Data.appearance.HATS.has(id): return
	var old := head.get_node_or_null("hat")
	if old:
		head.remove_child(old)
		old.queue_free()
	appearance["hat"] = id
	var a := resolve(appearance)
	if String(a.hat) != "none": _build_hat(String(a.hat), String(a.hatColor), String(a.get("hatTrim", "")))
	apply_layer()

func _build_hat(kind: String, color: String, trim: String = "") -> void:
	var g := Node3D.new(); g.name = "hat"; g.position.y = HEAD_R * 0.92; head.add_child(g)
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
		"captain":   # white with a navy band; a variant with a trim colours the crown and the band itself
			_m(P.cyl(0.4, 0.38, 0.22, 24), color if trim != "" else "ffffff", g, Vector3(0, 0.38, 0))
			_m(P.cyl(0.39, 0.39, 0.07, 24), trim if trim != "" else "2f3f6a", g, Vector3(0, 0.3, 0))
			_m(P.box(0.4, 0.03, 0.18), trim if trim != "" else "2f3f6a", g, Vector3(0, 0.28, 0.36))
			_m(P.sphere(0.05, 28, 18), P.GOLD, g, Vector3(0, 0.4, 0.4))
		"drivercap":   # a bus driver's peaked cap: the crown in its colour, a black band and peak, a brass badge
			_m(P.cyl(0.41, 0.37, 0.2, 24), color, g, Vector3(0, 0.37, 0))
			_m(P.cyl(0.385, 0.385, 0.06, 24), "1d1f26", g, Vector3(0, 0.29, 0))
			_m(P.rbox(0.38, 0.025, 0.2, 0.01), "1d1f26", g, Vector3(0, 0.27, 0.37), Vector3.ONE, Vector3(0.22, 0, 0))
			_m(P.rbox(0.1, 0.06, 0.02, 0.01), P.GOLD, g, Vector3(0, 0.36, 0.385), Vector3.ONE, Vector3(-0.1, 0, 0))
		"headphones":   # over-ear headphones with orange foam pads
			for k in 9:
				var an := deg_to_rad(-80.0 + k * 20.0)
				_m(P.rbox(0.07, 0.028, 0.045, 0.01), color, g, Vector3(sin(an) * 0.45, cos(an) * 0.45, -0.02), Vector3.ONE, Vector3(0, 0, -an))
			for s in [-1, 1]:
				_m(P.cyl(0.1, 0.1, 0.05, 20), "2a2a30", g, Vector3(s * 0.455, -0.01, -0.02), Vector3.ONE, Vector3(0, 0, PI / 2))
				_m(P.sphere(0.1, 16, 12), "f08a24", g, Vector3(s * 0.415, -0.01, -0.02), Vector3(0.45, 1, 1))
		"helmet":   # a rounded helmet with a narrow brim and a peak: a traffic warden's white one, or a hard hat
			_m(P.sphere(0.41, 28, 18), color, g, Vector3(0, 0.3, 0), Vector3(1, 0.8, 1.06))
			_m(P.cyl(0.47, 0.47, 0.025, 28), color, g, Vector3(0, 0.27, 0))
			_m(P.rbox(0.34, 0.025, 0.16, 0.01), color, g, Vector3(0, 0.27, 0.4), Vector3.ONE, Vector3(0.15, 0, 0))
			_m(P.torus(0.405, 0.018, 32), Color(color).darkened(0.18), g, Vector3(0, 0.31, 0))
			_m(P.sphere(0.045, 12, 8), P.GOLD, g, Vector3(0, 0.44, 0.37))
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

static func ease_in(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * c

static func ease_out(x: float) -> float:
	var c := 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - c * c * c

static func back_out(x: float, over: float = 1.7) -> float:
	var c := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + (over + 1.0) * c * c * c + over * c * c

static func settle(age: float, amp: float, freq: float, damp: float) -> float:
	if age < 0.0: return 0.0
	return amp * exp(-age * damp) * cos(age * freq)

static func swing_pose(p: float) -> Vector2:
	var back := -3.15
	var hit := 0.1
	if p < 0.42:
		var a := ease_out(p / 0.42)
		return Vector2(lerpf(-0.4, back, a), -0.12 * a)
	if p < 0.56:
		var a := ease_in((p - 0.42) / 0.14)
		return Vector2(lerpf(back, hit, a), lerpf(-0.12, 0.32, a))
	var a := ease_out((p - 0.56) / 0.44)
	return Vector2(lerpf(hit, -0.5, a), lerpf(0.32, 0.0, a))

func _blend(rate: float, dt: float) -> float:
	return 1.0 - exp(-dt * rate)

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
	body.position = Vector3.ZERO; body.rotation = Vector3.ZERO; body.scale = Vector3.ONE; head.rotation = Vector3.ZERO
	for limb in [arm_l, arm_r, leg_l, leg_r]: limb.rotation = Vector3.ZERO
	var prev_gait := gait
	gait = lerpf(gait, minf(1.0, speed), _blend(9.0, dt))
	var accel := (gait - prev_gait) / maxf(dt, 0.0001)
	var yaw := global_rotation.y if is_inside_tree() else rotation.y
	if last_yaw != INF and dt > 0.0:
		yaw_rate = lerpf(yaw_rate, clampf(wrapf(yaw - last_yaw, -PI, PI) / dt, -12.0, 12.0), _blend(10.0, dt))
	last_yaw = yaw
	lean = lerpf(lean, 0.09 * gait - clampf(accel * 0.02, -0.12, 0.12), _blend(6.0, dt))
	bank = lerpf(bank, clampf(-yaw_rate * 0.05 * (0.25 + gait), -0.22, 0.22), _blend(8.0, dt))
	var squash := 0.0
	if gait > 0.01: stride += dt * (7.5 + speed * 4.0) * clampf(gait * 1.5, 0.0, 1.0)
	var sw := sin(stride)
	var up := absf(sw)
	var arm_sw := sin(stride - 0.4)
	leg_l.rotation.x = sw * 0.8 * gait; leg_r.rotation.x = -sw * 0.8 * gait
	arm_l.rotation.x = -arm_sw * 0.7 * gait; arm_r.rotation.x = arm_sw * 0.7 * gait
	arm_l.rotation.z = -0.1 * (1.0 - gait) - 0.06 * gait; arm_r.rotation.z = -arm_l.rotation.z
	body.position.y = up * 0.07 * gait
	squash += (pow(1.0 - up, 6.0) * 0.07 - pow(up, 6.0) * 0.035) * gait
	body.rotation.x = lean
	body.rotation.z = sw * 0.05 * gait + bank
	head.rotation.z = -sw * 0.04 * gait - bank * 0.6
	head.rotation.x = -lean * 0.5 - cos(stride * 2.0) * 0.025 * gait
	head.rotation.y = clampf(yaw_rate * 0.07, -0.45, 0.45)
	var rest := 1.0 - gait
	if rest > 0.01:
		var breath := sin(t * 2.2)
		body.position.y += breath * 0.01 * rest
		squash -= breath * 0.012 * rest
		body.rotation.z += sin(t * 0.47) * 0.03 * rest
		head.rotation.z += sin(t * 0.9) * 0.035 * rest
		arm_l.rotation.z -= breath * 0.03 * rest; arm_r.rotation.z += breath * 0.03 * rest
		next_glance -= dt
		if next_glance <= 0.0:
			next_glance = 2.5 + randf() * 5.0
			look_target = 0.0 if randf() < 0.4 else randf_range(-0.55, 0.55)
		look = lerpf(look, look_target, _blend(5.0, dt))
		if hold == "" and action == "" and not talking: head.rotation.y += look * rest
	land_age += dt
	impact_age += dt
	if airborne:
		leg_l.rotation.x = 0.5; leg_r.rotation.x = -0.3; arm_l.rotation.z = -1.2; arm_r.rotation.z = 1.2
		squash -= 0.06
	elif was_airborne: land_age = 0.0
	was_airborne = airborne
	squash += settle(land_age, 0.16, 12.0, 7.0) + settle(impact_age, impact_amp, 16.0, 9.0)
	match hold:
		"sit": body.position.y = -0.2; leg_l.rotation.x = -1.4; leg_r.rotation.x = -1.4; arm_l.rotation.x = -0.3; arm_r.rotation.x = -0.3
		"ride":
			var pedal := t * 7.0 * minf(1.0, speed)
			body.position.y = 0.32; body.rotation.z = bank * 0.5; head.rotation.z = 0.0
			leg_l.rotation.x = -1.1 + sin(pedal) * 0.45 * minf(1.0, speed); leg_r.rotation.x = -1.1 - sin(pedal) * 0.45 * minf(1.0, speed)
			arm_l.rotation.x = -1.15; arm_r.rotation.x = -1.15; arm_l.rotation.z = 0.12; arm_r.rotation.z = -0.12
		"sleep": body.position.y = -0.24; leg_l.rotation.x = -1.4; leg_r.rotation.x = -1.4; head.rotation.x = 0.35; head.rotation.z = 0.25
		"cast": arm_r.rotation.x = -1.3; arm_l.rotation.x = -1.1; arm_l.rotation.z = 0.4
		"reel": arm_r.rotation.x = -1.0 + sin(t * 14.0) * 0.15; arm_l.rotation.x = -1.0; arm_l.rotation.z = 0.4; body.rotation.x = -0.12
		"build": arm_r.rotation.x = -2.6 + sin(t * 3.0) * 0.12; arm_r.rotation.z = 0.2; arm_l.rotation.z = -0.5 - sin(t * 3.0) * 0.1
		"work": arm_r.rotation.x = -0.9 + sin(t * 7.0) * 0.5; arm_l.rotation.x = -0.6; body.rotation.x = 0.1
		"garden": body.rotation.x = 0.3; arm_l.rotation.x = -0.9 + sin(t * 4.0) * 0.2; arm_r.rotation.x = arm_l.rotation.x
		"read": arm_l.rotation.x = -1.1; arm_r.rotation.x = -1.1; arm_l.rotation.z = 0.35; arm_r.rotation.z = -0.35; head.rotation.x = 0.25
		"talk": arm_r.rotation.x = -0.4 + sin(t * 3.0) * 0.3; arm_r.rotation.z = 0.35; head.rotation.y = sin(t * 1.3) * 0.12
		"kneel":
			body.position.y = -0.3; leg_l.rotation.x = 1.25; leg_r.rotation.x = 1.25; body.rotation.x = 0.08
			arm_l.rotation.x = -1.15; arm_r.rotation.x = -1.15; arm_l.rotation.z = 0.5; arm_r.rotation.z = -0.5; head.rotation.x = 0.3
		"sing":
			var sway := sin(t * 1.4)
			head.rotation.x = -0.22; head.rotation.z = sway * 0.08; body.rotation.z = sway * 0.035
			arm_l.rotation.x = -0.75; arm_r.rotation.x = -0.75; arm_l.rotation.z = -0.55 - sway * 0.08; arm_r.rotation.z = 0.55 - sway * 0.08
		"hold_staff": arm_r.rotation.x = -0.35; arm_r.rotation.z = 0.32
		"dance":
			var step := t * 5.9
			body.rotation.y = sin(t * 0.9) * 1.4
			body.position.y = absf(sin(step)) * 0.06
			body.rotation.z = sin(step * 0.5) * 0.1
			leg_l.rotation.x = sin(step) * 0.35; leg_r.rotation.x = -sin(step) * 0.35
			arm_l.rotation.z = -1.9 + sin(step * 0.5) * 0.15; arm_l.rotation.x = -0.2
			arm_r.rotation.x = -1.1; arm_r.rotation.z = 0.5 + sin(step * 0.5) * 0.1
			head.rotation.z = sin(step * 0.5) * 0.14; head.rotation.x = -0.08
	if hold != "" and hold != "talk": squash = 0.0
	if action != "":
		action_t += dt
		var length: float = ACTION_LENGTH.get(action, 1.0)
		var p := clampf(action_t / length, 0.0, 1.0)
		var s := sin(p * PI)
		match action:
			"wave":
				var raise := back_out(minf(1.0, action_t * 4.0)) * (1.0 - ease_in((p - 0.8) / 0.2))
				arm_r.rotation.z = 2.6 * raise; arm_r.rotation.x = sin(action_t * 12.0) * 0.35 * raise
				head.rotation.z = 0.14 * raise; body.rotation.z -= 0.05 * raise
			"clap":
				arm_l.rotation.x = -1.3; arm_r.rotation.x = -1.3
				var c := absf(sin(action_t * 14.0)) * 0.5
				arm_l.rotation.z = 0.5 - c; arm_r.rotation.z = -0.5 + c
				var hop := absf(sin(action_t * 7.0))
				body.position.y += hop * 0.05; squash += (1.0 - hop) * 0.04
			"celebrate":
				if action_t < 0.18:
					var a := ease_out(action_t / 0.18)
					squash += 0.14 * a; body.position.y -= 0.05 * a
					arm_l.rotation.z = -0.6 * a; arm_r.rotation.z = 0.6 * a
				else:
					var ct := action_t - 0.18
					var jump := absf(sin(ct * 6.0))
					body.position.y += jump * 0.35
					squash += pow(1.0 - jump, 8.0) * 0.12 - jump * 0.06
					arm_l.rotation.z = -2.7; arm_r.rotation.z = 2.7
					arm_l.rotation.x = sin(ct * 12.0) * 0.2; arm_r.rotation.x = arm_l.rotation.x
					body.rotation.y = ct * 3.4
			"surprised":
				if p < 0.15: squash += 0.12 * ease_out(p / 0.15)
				else:
					var lift := sin((p - 0.15) / 0.85 * PI)
					body.position.y += lift * 0.25; squash -= lift * 0.08
					arm_l.rotation.z = -1.5 * lift; arm_r.rotation.z = 1.5 * lift; head.rotation.x -= 0.15 * lift
			"nod": head.rotation.x = sin(p * PI * 4.0) * 0.25 * (1.0 - p * 0.5)
			"shake":
				body.rotation.y = sin(action_t * 38.0) * 0.35 * s; head.rotation.z = sin(action_t * 30.0) * 0.25 * s
				arm_l.rotation.z = -0.6 * s; arm_r.rotation.z = 0.6 * s
			"shrug":
				arm_l.rotation.z = -0.9 * s; arm_r.rotation.z = 0.9 * s; head.rotation.z = 0.2 * s
				body.position.y += 0.03 * s; squash -= 0.03 * s
			"chop", "mine":
				var pose := swing_pose(p)
				arm_r.rotation.x = pose.x; arm_l.rotation.x = pose.x + 0.4; body.rotation.x += pose.y
				if action_prev_p < 0.56 and p >= 0.56: impact_age = 0.0; impact_amp = 0.09
			"build":
				var pose := swing_pose(p)
				arm_r.rotation.x = pose.x; arm_l.rotation.z = -0.4; body.rotation.x += pose.y * 0.6
				if action_prev_p < 0.56 and p >= 0.56: impact_age = 0.0; impact_amp = 0.06
			"dig":
				if p < 0.3:
					var a := ease_out(p / 0.3)
					body.rotation.x -= 0.1 * a; arm_r.rotation.x = -1.3 * a; arm_l.rotation.x = -1.3 * a
				elif p < 0.5:
					var a := ease_in((p - 0.3) / 0.2)
					body.rotation.x += lerpf(-0.1, 0.45, a); arm_r.rotation.x = lerpf(-1.3, -0.3, a); arm_l.rotation.x = arm_r.rotation.x
				else:
					var a := ease_out((p - 0.5) / 0.5)
					body.rotation.x += lerpf(0.45, 0.0, a); arm_r.rotation.x = lerpf(-0.3, 0.0, a); arm_l.rotation.x = arm_r.rotation.x
				if action_prev_p < 0.5 and p >= 0.5: impact_age = 0.0; impact_amp = 0.08
			"feed": arm_r.rotation.x = -1.2 * ease_out(s); body.rotation.x += 0.3 * s
			"watch":
				arm_l.rotation.x = -1.45 * s; arm_l.rotation.z = 0.75 * s
				head.rotation.x = 0.35 * s; head.rotation.y = 0.3 * s
		action_prev_p = p
		if action_t >= length: action = ""; action_prev_p = 0.0
	squash = clampf(squash, -0.12, 0.2)
	body.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
