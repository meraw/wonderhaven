class_name Effects
extends Node3D
## One-shot particle bursts: sparkles, poofs, magic swirls, hearts, splashes, smoke, zzz.

static var _tex: Dictionary = {}

static func _make_tex(kind: String) -> ImageTexture:
	if _tex.has(kind): return _tex[kind]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x - n / 2.0 + 0.5) / (n / 2.0)
			var dy := (y - n / 2.0 + 0.5) / (n / 2.0)
			var a := 0.0
			match kind:
				"star":
					var r := sqrt(dx * dx + dy * dy)
					var ang := atan2(dy, dx)
					var edge := 0.35 + 0.6 * pow(absf(cos(ang * 2.0)), 6.0)
					a = clampf((edge - r) * 6.0, 0.0, 1.0) + clampf(1.0 - r * 2.2, 0.0, 1.0)
				"puff": a = clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0) * 0.9
				"heart":
					var hx := dx * 1.2
					var hy := -dy * 1.2 + 0.25
					var v := pow(hx * hx + hy * hy - 0.5, 3.0) - hx * hx * pow(hy, 3.0)
					a = 1.0 if v < 0.0 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t

func _burst(pos: Vector3, kind: String, color: Color, amount: int, life: float, size: float, velocity: float, spread: float, gravity: float, dir: Vector3 = Vector3.UP, box: float = 0.2, additive: bool = true) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _make_tex(kind)
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.amount = amount; p.lifetime = life; p.one_shot = true; p.explosiveness = 0.9
	p.direction = dir; p.spread = spread; p.initial_velocity_min = velocity * 0.5; p.initial_velocity_max = velocity
	p.gravity = Vector3(0, gravity, 0); p.damping_min = 1.0; p.damping_max = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = box
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.2
	var ramp := Gradient.new(); ramp.set_color(0, color); ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)

func sparkle(pos: Vector3, count: int = 14, color: Color = Color("fff2a8"), size: float = 0.28) -> void:
	_burst(pos, "star", color, count, 1.0, size, 2.2, 60.0, -2.0)
func poof(pos: Vector3, color: Color = Color.WHITE) -> void:
	_burst(pos + Vector3(0, 0.2, 0), "puff", color, 10, 0.8, 0.6, 1.6, 80.0, 0.0, Vector3.UP, 0.3, false)
func magic(pos: Vector3, height: float = 1.2) -> void:
	_burst(pos + Vector3(0, height * 0.4, 0), "star", Color("c9a8ff"), 22, 1.1, 0.3, 1.6, 180.0, 0.6, Vector3.UP, 0.6)
	_burst(pos, "star", Color("fff2a8"), 12, 0.9, 0.25, 2.5, 30.0, -1.0)
func hearts(pos: Vector3, count: int = 4) -> void:
	_burst(pos, "heart", Color("ff7aa8"), count, 1.4, 0.3, 1.2, 25.0, 0.3, Vector3.UP, 0.3, false)
func splash(pos: Vector3) -> void:
	_burst(pos, "puff", Color("bff3ff"), 12, 0.8, 0.18, 3.5, 35.0, -7.0, Vector3.UP, 0.2, false)
func smoke(pos: Vector3) -> void:
	_burst(pos, "puff", Color(0.95, 0.95, 0.95, 0.7), 2, 2.6, 0.5, 0.7, 15.0, 0.1, Vector3(0.2, 1, 0.1), 0.05, false)
func zzz(pos: Vector3) -> void:
	_burst(pos, "puff", Color("e8f0ff"), 1, 1.5, 0.25, 0.5, 10.0, 0.0, Vector3(0.3, 1, 0), 0.0, false)
