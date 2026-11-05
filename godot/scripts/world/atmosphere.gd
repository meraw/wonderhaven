class_name Atmosphere
extends Node3D
## The air between things: one wind, one sun and one weather shared by every shader (shader globals declared in
## project.godot), a soft light bounced up from the ground, a colour grade that follows the hour, a gentle blur on
## the far distance, shadows of the clouds you can see drifting over the land, and small ambient life: dust motes
## in daylight, fireflies at night and leaves falling from the nearest tree.
## It only reads the clock, the weather and where the player is, so it works the same on every island and never
## touches rules, saves or layout. Cloud shadows, vignette and depth blur need Forward+; the rest works everywhere.

const LAYER := 1 << 3   # kept off the dialogue portrait camera (it draws layer 1 only)

var game
var bounce: DirectionalLight3D
var grade: Gradient
var post: MeshInstance3D
var motes: GPUParticles3D
var fireflies: GPUParticles3D
var leaves: GPUParticles3D
var drift := Vector2.ZERO
var _fog_drift := Vector2.ZERO
var _grade_t := 0.0
var _leaf_t := 0.0
var _round_trees: Array = []
var look: Dictionary = {}   # this location's mood (see apply_look)

# ---- Pure helpers (tested in tests/test_atmosphere.gd) ----------------------------------------------------

## Wind for a moment: x, z direction (unit) and strength (about 0.5 calm .. 1.5 stormy). The direction drifts from
## day to day and a little through each day; clouds and rain make it blow harder.
static func wind_at(day: int, hour: float, w: Dictionary) -> Vector3:
	var a := 2.4 + 0.9 * sin(day * 2.1 + 0.3) + 0.25 * sin(hour * 0.4)
	var strength := 0.55 + 0.35 * float(w.get("clouds", 0.25)) + 0.6 * float(w.get("rain", 0.0))
	return Vector3(cos(a), sin(a), strength)

## Colour grade keyframes: [hour, shadow tint (what black becomes), highlight tint (what white becomes)].
## Cool, lifted shadows and warm highlights by day; rosy at dawn and dusk; blue moonlight at night.
const GRADE := [
	[0.0, Color(0.012, 0.018, 0.045), Color(0.97, 0.98, 1.0)],
	[4.8, Color(0.012, 0.018, 0.045), Color(0.97, 0.98, 1.0)],
	[6.2, Color(0.028, 0.012, 0.035), Color(1.0, 0.975, 0.95)],
	[8.5, Color(0.008, 0.01, 0.022), Color(1.0, 0.995, 0.975)],
	[12.5, Color(0.004, 0.008, 0.018), Color(1.0, 1.0, 0.985)],
	[16.5, Color(0.008, 0.007, 0.02), Color(1.0, 0.995, 0.965)],
	[18.6, Color(0.024, 0.008, 0.03), Color(1.0, 0.98, 0.92)],
	[19.8, Color(0.028, 0.01, 0.038), Color(1.0, 0.965, 0.93)],
	[21.2, Color(0.012, 0.018, 0.045), Color(0.97, 0.98, 1.0)],
	[24.0, Color(0.012, 0.018, 0.045), Color(0.97, 0.98, 1.0)],
]

## [shadow tint, highlight tint] for a moment of the day and the weather (overcast greys it, mist lifts it).
static func grade_at(hour: float, w: Dictionary) -> Array:
	var h := fposmod(hour, 24.0)
	var i := 0
	while i < GRADE.size() - 2 and h >= float(GRADE[i + 1][0]): i += 1
	var a: Array = GRADE[i]; var b: Array = GRADE[i + 1]
	var f := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var lo: Color = (a[1] as Color).lerp(b[1], f)
	var hi: Color = (a[2] as Color).lerp(b[2], f)
	var grey := clampf((float(w.get("clouds", 0.25)) - 0.45) * 1.6, 0.0, 1.0) * (1.0 - Daylight.nightness(h))
	lo = lo.lerp(Color(0.012, 0.018, 0.028), grey * 0.7); hi = hi.lerp(Color(0.97, 0.985, 1.0), grey * 0.7)
	var mist := float(w.get("fog", 0.0))
	lo = lo.lerp(Color(0.05, 0.05, 0.06), mist * 0.5)
	return [lo, hi]

## The grade as per-channel curves (offsets 0..1): from the shadow tint to the highlight tint, with a soft S so
## colours keep their punch. Every channel stays increasing, so no colour ever flips.
static func grade_curve(lo: Color, hi: Color, steps: int = 9) -> PackedColorArray:
	var out := PackedColorArray()
	for k in steps:
		var x := float(k) / (steps - 1)
		var s := x - 0.015 * sin(TAU * x)
		out.append(Color(clampf(lerpf(lo.r, hi.r, s), 0.0, 1.0), clampf(lerpf(lo.g, hi.g, s), 0.0, 1.0), clampf(lerpf(lo.b, hi.b, s), 0.0, 1.0)))
	return out

## A location's own mood, from the `look` block of its map entry (islands.json or a pack's location.json):
## "shade": [r, g, b] added to the shadow tint, "light": [r, g, b] multiplying the highlight tint, "wind": a strength
## multiplier, "life": {"motes": x, "fireflies": x, "leaves": x} multipliers, "leafColors": the falling leaves' colours.
## Missing keys change nothing.
static func apply_look(gr: Array, lk: Dictionary) -> Array:
	var lo: Color = gr[0]; var hi: Color = gr[1]
	var sh: Array = lk.get("shade", [0, 0, 0]); var li: Array = lk.get("light", [1, 1, 1])
	lo = Color(clampf(lo.r + float(sh[0]), 0.0, 0.3), clampf(lo.g + float(sh[1]), 0.0, 0.3), clampf(lo.b + float(sh[2]), 0.0, 0.3))
	hi = Color(clampf(hi.r * float(li[0]), 0.5, 1.0), clampf(hi.g * float(li[1]), 0.5, 1.0), clampf(hi.b * float(li[2]), 0.5, 1.0))
	return [lo, hi]

## How thick the valley mist is (0..1) at an hour, from a layout's `valley_fog` block: its "morning" level from dawn
## to 8, burning off to its "day" level by 11, gathering again to its "evening" level after 19 and its "night" level
## after 21. A misty day keeps it thick whatever the hour.
static func valley_fog_at(hour: float, spec: Dictionary, w: Dictionary) -> float:
	var h := fposmod(hour, 24.0)
	var mo := float(spec.get("morning", 0.9)); var dy := float(spec.get("day", 0.1))
	var ev := float(spec.get("evening", 0.3)); var nt := float(spec.get("night", 0.45))
	var a: float
	if h < 4.0: a = nt
	elif h < 5.5: a = lerpf(nt, mo, smoothstep(4.0, 5.5, h))
	elif h < 8.0: a = mo
	elif h < 11.0: a = lerpf(mo, dy, smoothstep(8.0, 11.0, h))
	elif h < 16.0: a = dy
	elif h < 19.0: a = lerpf(dy, ev, smoothstep(16.0, 19.0, h))
	elif h < 21.0: a = lerpf(ev, nt, smoothstep(19.0, 21.0, h))
	else: a = nt
	return clampf(lerpf(a, 0.95, float(w.get("fog", 0.0)) * 0.85) + 0.15 * float(w.get("rain", 0.0)), 0.0, 1.0)

## How much of each kind of ambient life to show (0..1): motes in sunshine, fireflies on dry nights, leaves
## mostly in a breeze.
static func life_at(hour: float, w: Dictionary) -> Dictionary:
	var night := Daylight.nightness(hour)
	var rain := float(w.get("rain", 0.0))
	var sun := (1.0 - night) * float(w.get("sun", 1.0))
	var wind := wind_at(0, hour, w).z
	return {"motes": clampf(sun * (1.0 - rain * 1.5), 0.0, 1.0),
		"fireflies": clampf(night * (1.0 - rain * 2.0) * (1.0 - float(w.get("fog", 0.0)) * 0.5), 0.0, 1.0),
		"leaves": clampf(0.35 + (wind - 0.55) * 0.9, 0.0, 1.0)}

# ---- Scene ----------------------------------------------------------------------------------------------------

func setup(g) -> void:
	game = g
	name = "Atmosphere"
	look = Data.island_def(Data.island).get("look", {})
	# Light bounced up from sunlit grass: undersides (eaves, canopies, chins) pick up a warm green fill instead of
	# a flat grey.
	bounce = DirectionalLight3D.new(); bounce.name = "Bounce"
	bounce.shadow_enabled = false; bounce.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	bounce.light_specular = 0.0; bounce.light_energy = 0.0
	add_child(bounce)
	# Colour grade: per-channel curves in a 1D lookup texture (updated a few times a second).
	grade = Gradient.new()
	var gt := GradientTexture1D.new(); gt.width = 128; gt.gradient = grade
	_apply_grade(9.0, {})
	var env: Environment = game.env.environment
	env.adjustment_enabled = true
	env.adjustment_color_correction = gt
	if Outline.supported():
		# A soft blur on the far distance makes the island read like a miniature diorama.
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true; ca.dof_blur_far_distance = 60.0; ca.dof_blur_far_transition = 70.0; ca.dof_blur_amount = 0.04
		game.env.camera_attributes = ca
		post = _make_post(); game.camera.add_child(post)
	motes = _particles(70, 7.0, _dot_material(Color(1.0, 0.97, 0.85, 0.5), 0.04, true), _mote_process())
	fireflies = _particles(48, 6.0, _dot_material(Color(1.25, 1.5, 0.6), 0.1, true), _firefly_process())
	leaves = _particles(10, 7.0, _leaf_material(), _leaf_process())
	for t in game.decor.get("trees", []):
		if t.get("kind", "round") != "pine": _round_trees.append(t)

func _process(dt: float) -> void:
	if game == null or game.state == null: return
	var s: Dictionary = game.state
	var h: float = float(s.time.minute) / 60.0
	var w: Dictionary = game.weather_now
	var night := Daylight.nightness(h)
	var sunlit := (1.0 - night) * float(w.get("sun", 1.0))
	var wind := wind_at(int(s.time.get("day", 0)), h, w)
	wind.z *= float(look.get("wind", 1.0))
	var gust := 0.5 + 0.5 * sin(game.time * 0.13) * sin(game.time * 0.071 + 1.3)
	var wd := Vector2(wind.x, wind.y)
	# Clouds drift downwind (the sky and the cloud shadows read this, so they move together).
	drift -= wd * 0.006 * (0.6 + wind.z) * dt
	var sun_col: Color = game.sun.light_color
	var sky_mat: ShaderMaterial = game.env.environment.sky.sky_material
	var horizon: Color = sky_mat.get_shader_parameter("bottom_color")
	var zenith: Color = sky_mat.get_shader_parameter("top_color")
	RenderingServer.global_shader_parameter_set("world_wind", Vector4(wd.x, wd.y, wind.z, gust))
	RenderingServer.global_shader_parameter_set("world_sun_dir", Daylight.light_dir(h))
	RenderingServer.global_shader_parameter_set("world_sun_color", _lin(sun_col))
	RenderingServer.global_shader_parameter_set("world_weather", Vector4(sunlit, night, float(w.get("rain", 0.0)), float(w.get("clouds", 0.25))))
	RenderingServer.global_shader_parameter_set("world_sky_horizon", _lin(horizon))
	RenderingServer.global_shader_parameter_set("world_sky_zenith", _lin(zenith))
	RenderingServer.global_shader_parameter_set("world_cloud_drift", drift)
	# Bounce: comes up from the ground, a little away from the sun, tinted by grass and sunlight.
	var sd := Daylight.light_dir(h)
	bounce.global_transform.basis = Basis.looking_at(Vector3(-sd.x * 0.35, 1.0, -sd.z * 0.35).normalized(), Vector3.FORWARD)
	bounce.light_color = Color(0.6, 0.78, 0.45).lerp(sun_col, 0.35)
	bounce.light_energy = 0.08 * sunlit + 0.015 * night
	_grade_t -= dt
	if _grade_t <= 0.0: _grade_t = 0.25; _apply_grade(h, w)
	# Ambient life follows the player.
	var life := life_at(h, w)
	var lm: Dictionary = look.get("life", {})
	for k in life: life[k] = clampf(life[k] * float(lm.get(k, 1.0)), 0.0, 1.0)
	var p: Vector3 = game.player.pos
	motes.amount_ratio = life.motes; motes.emitting = life.motes > 0.02
	motes.global_position = game.cam.target + Vector3(0, 1.6, 0)
	fireflies.amount_ratio = life.fireflies; fireflies.emitting = life.fireflies > 0.02
	fireflies.global_position = Vector3(p.x, Heightfield.height(p.x, p.z) + 0.9, p.z)
	(leaves.process_material as ParticleProcessMaterial).gravity = Vector3(wd.x * 0.5 * wind.z, -0.45, wd.y * 0.5 * wind.z)
	_leaf_t -= dt
	if _leaf_t <= 0.0:
		_leaf_t = 2.5
		var tree := _nearest_tree(p, 16.0)
		leaves.emitting = not tree.is_empty() and life.leaves > 0.02
		leaves.amount_ratio = life.leaves
		if not tree.is_empty():
			leaves.global_position = Vector3(tree.x, Heightfield.height(tree.x, tree.z) + 2.0 * float(tree.s), tree.z)
	if post: (post.material_override as ShaderMaterial).set_shader_parameter("shadow_strength", 0.24 if game.settings.get("weather", true) else 0.12)
	# Valley mist: thick at dawn, gone by late morning; lit like the haze on the horizon, grey at night.
	var vf: MeshInstance3D = game.village.valley_fog if game.village else null
	if vf:
		_fog_drift += wd * 0.0025 * (0.5 + wind.z) * dt
		var fm := vf.material_override as ShaderMaterial
		fm.set_shader_parameter("amount", valley_fog_at(h, Data.layout.valley_fog, w))
		fm.set_shader_parameter("drift", _fog_drift)
		var fc := horizon.lerp(Color(0.97, 0.96, 0.94), 0.7).lerp(sun_col, 0.15 * sunlit)
		fm.set_shader_parameter("fog_color", fc.darkened(0.55 * night))

func _apply_grade(h: float, w: Dictionary) -> void:
	var gr := apply_look(grade_at(h, w), look)
	var cols := grade_curve(gr[0], gr[1])
	var offs := PackedFloat32Array()
	for k in cols.size(): offs.append(float(k) / (cols.size() - 1))
	grade.offsets = offs
	grade.colors = cols

func _nearest_tree(p: Vector3, max_d: float) -> Dictionary:
	var best := {}; var bd := max_d
	for t in _round_trees:
		var d := Vector2(float(t.x) - p.x, float(t.z) - p.z).length()
		if d < bd: bd = d; best = t
	return best

static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

# ---- Builders -------------------------------------------------------------------------------------------------

func _particles(amount: int, life: float, mat: Material, pm: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount; p.lifetime = life; p.preprocess = life; p.local_coords = false
	p.process_material = pm
	var q := QuadMesh.new(); q.material = mat
	q.size = Vector2.ONE * float(mat.get_meta("size", 0.1))
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 16, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = LAYER
	p.emitting = false
	add_child(p)
	return p

static func _soft_dot() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)

static func _leaf_tex() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x - n / 2.0 + 0.5) / (n / 2.0); var v := (y - n / 2.0 + 0.5) / (n / 2.0)
			var half := 0.42 * sqrt(maxf(0.0, 1.0 - v * v)) * (1.0 - 0.25 * v)   # pointed oval
			var inside := absf(u) < half
			var g := 0.85 if absf(u) < 0.05 else 1.0   # midrib
			img.set_pixel(x, y, Color(g, g, g, 1.0 if inside else 0.0))
	return ImageTexture.create_from_image(img)

func _dot_material(color: Color, size: float, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _soft_dot()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA; m.distance_fade_min_distance = 0.6; m.distance_fade_max_distance = 1.6
	m.set_meta("size", size)
	return m

func _leaf_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _leaf_tex()
	m.vertex_color_use_as_albedo = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.backlight_enabled = true; m.backlight = Color(0.35, 0.45, 0.2)
	m.set_meta("size", 0.14)
	return m

func _mote_process() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; pm.emission_box_extents = Vector3(10, 3, 10)
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.initial_velocity_min = 0.02; pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.01, 0)
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6; pm.turbulence_noise_scale = 4.0
	pm.turbulence_influence_min = 0.02; pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.5; pm.scale_max = 1.2
	pm.color_ramp = _ramp([[0.0, 0.0], [0.25, 1.0], [0.75, 1.0], [1.0, 0.0]])
	return pm

func _firefly_process() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; pm.emission_box_extents = Vector3(12, 0.7, 12)
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.initial_velocity_min = 0.05; pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.2; pm.damping_max = 0.5
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 1.2; pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.05; pm.turbulence_influence_max = 0.14
	pm.scale_min = 0.6; pm.scale_max = 1.1
	# slow blinks: glow, fade, glow again
	pm.color_ramp = _ramp([[0.0, 0.0], [0.12, 1.0], [0.3, 0.15], [0.45, 0.9], [0.62, 0.1], [0.8, 1.0], [1.0, 0.0]])
	return pm

func _leaf_process() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; pm.emission_box_extents = Vector3(1.1, 0.5, 1.1)
	pm.direction = Vector3(0, -1, 0); pm.spread = 60.0
	pm.initial_velocity_min = 0.1; pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.3, -0.45, 0.2)
	pm.damping_min = 0.3; pm.damping_max = 0.6
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 1.5; pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.1; pm.turbulence_influence_max = 0.25
	pm.angle_min = 0.0; pm.angle_max = 360.0; pm.angular_velocity_min = -120.0; pm.angular_velocity_max = 120.0
	pm.scale_min = 0.8; pm.scale_max = 1.2
	var g := Gradient.new()
	var lc: Array = look.get("leafColors", ["6fbf4a", "a8c94a", "e0a040"])   # a look's own falling leaves (autumn golds)
	g.offsets = PackedFloat32Array(range(lc.size()).map(func(k): return float(k) / maxf(1.0, lc.size() - 1)))
	g.colors = PackedColorArray(lc.map(func(c): return Color(c)))
	var gt := GradientTexture1D.new(); gt.gradient = g
	pm.color_initial_ramp = gt
	var sc := Curve.new(); sc.add_point(Vector2(0, 0)); sc.add_point(Vector2(0.08, 1)); sc.add_point(Vector2(0.85, 1)); sc.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = sc
	pm.scale_curve = ct
	return pm

## Alpha over a particle's life: [[t, alpha], ...] (colour stays white; the material gives it colour).
static func _ramp(points: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array(); var cols := PackedColorArray()
	for pt in points: offs.append(pt[0]); cols.append(Color(1, 1, 1, pt[1]))
	g.offsets = offs; g.colors = cols
	var gt := GradientTexture1D.new(); gt.gradient = g
	return gt

const POST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 shade : source_color = vec4(0.16, 0.2, 0.36, 1.0);
uniform float shadow_strength = 0.24;
uniform float vignette = 0.11;
uniform float cloud_height = 110.0;
global uniform vec3 world_sun_dir;
global uniform vec4 world_weather;   // x sunlit, y night, z wet, w clouds
global uniform vec2 world_cloud_drift;
// The sky shader's cloud noise, so the shadows on the ground belong to the clouds overhead.
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * n2(p); p = p * 2.03 + 11.7; a *= 0.5; } return v; }
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec3 view = vp.xyz / vp.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(view, 1.0)).xyz;
	float ground = step(0.0000001, d) * (1.0 - smoothstep(90.0, 180.0, length(view)));   // not the sky
	// Follow the sunbeam up to the cloud layer and see whether a cloud is there.
	vec3 sd = normalize(world_sun_dir);
	vec2 cp = wp.xz + sd.xz / max(sd.y, 0.25) * (cloud_height - wp.y);
	float n = fbm((cp / (cloud_height * 1.3) + world_cloud_drift) * 1.3);
	float clouds = world_weather.w;
	float cov = smoothstep(1.0 - clouds - 0.12, 1.0 - clouds + 0.28, n);
	float sh = cov * world_weather.x * ground * shadow_strength;
	vec2 vq = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float vig = smoothstep(0.45, 1.05, length(vq)) * vignette;
	ALBEDO = shade.rgb;
	ALPHA = clamp(sh + vig, 0.0, 0.6);
}
"""

func _make_post() -> MeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(2, 2)
	var sh := Shader.new(); sh.code = POST_SHADER
	var m := ShaderMaterial.new(); m.shader = sh
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = LAYER
	mi.name = "CloudShadows"
	return mi
