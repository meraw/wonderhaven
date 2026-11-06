class_name Foliage
## Plant meshes and the swaying plant shader: lumpy tree canopies, layered pines, grass tufts and five-petal flowers.
## Meshes carry a grey vertex-colour gradient (dark underneath, bright on top) that tints whatever colour they are given.

const PLANT_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.03;
uniform float sway_from = 0.0;
uniform bool flat_normals = false;
uniform bool flower = false;
uniform vec4 center_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float flutter = 0.0;      // small leaf rustle along the surface (leafy masses only)
uniform float clumps = 0.0;       // painted leaf clusters on canopies and bushes (0 = off)
uniform float backlight = 0.3;    // light shining through leaves from behind
// One world for every plant: wind (xy direction, z strength, w gust), sun and weather (Atmosphere sets them).
global uniform vec4 world_wind;
global uniform vec3 world_sun_dir;
global uniform vec3 world_sun_color;   // linear
global uniform vec4 world_weather;   // x sunlit, y night, z wet, w clouds
varying float is_center;
varying vec3 lpos;
varying vec3 wpos;
varying vec3 wnrm;
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p), f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), u.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), u.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}
void vertex() {
	lpos = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.4 + origin.x * 0.37 + origin.z * 0.23;
	float k = max(0.0, VERTEX.y - sway_from);
	// Gusts roll across the island downwind, so neighbouring plants lean together in waves instead of each
	// swaying on its own beat.
	vec2 wd = normalize(world_wind.xy + vec2(0.0001));
	float wave = 0.5 + 0.5 * sin(dot(origin.xz, wd) * 0.32 - TIME * 1.7);
	wave *= 0.65 + 0.35 * sin(dot(origin.xz, vec2(wd.y, -wd.x)) * 0.11 + TIME * 0.31);
	float push = world_wind.z * (0.35 + 1.1 * wave * (0.5 + world_wind.w));
	vec3 wl = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(wd.x, 0.0, wd.y));   // wind direction in the mesh's space
	VERTEX.x += (sin(t) * 0.6 + wl.x * push) * sway * k;
	VERTEX.z += (cos(t * 0.83) * 0.36 + wl.z * push) * sway * k;
	if (flutter > 0.0) VERTEX += NORMAL * flutter * (0.4 + world_wind.z) * sin(TIME * 7.3 + dot(lpos, vec3(9.1, 7.3, 8.7)));
	if (flat_normals) NORMAL = vec3(0.0, 1.0, 0.0);
	is_center = UV.x;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;   // normalised per pixel: a vertex can carry a zero normal
}
void fragment() {
	// Leaves right in front of the camera dissolve (dithered), so a tree behind the player never fills the screen.
	float near_fade = smoothstep(1.9, 2.8, length(VERTEX));
	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (ign > near_fade) discard;
	// Never below zero: with MSAA a pixel at a blade's edge reads its colour from just outside the triangle, and pow()
	// of a negative number is NaN, which the glow spreads into a black (or magenta) square.
	vec3 c = max(COLOR.rgb * tint.rgb, vec3(0.0));
	c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	if (flower && is_center > 0.5) c = center_color.rgb;
	if (clumps > 0.0) {
		// Painted leaf clusters: soft blotches of light and shade, with sunny dabs on the upper side.
		float n = n3(lpos * 2.6) * 0.7 + n3(lpos * 6.3 + 3.7) * 0.3;
		float blot = smoothstep(0.4, 0.6, n);
		c *= mix(1.0 - 0.07 * clumps, 1.0 + 0.06 * clumps, blot);
		float up = normalize(wnrm + vec3(0.0, 0.00001, 0.0)).y;
		float dab = smoothstep(0.64, 0.7, n) * smoothstep(0.15, 0.7, up);
		c = mix(c, c * vec3(1.14, 1.13, 0.88), dab * clumps * 0.7);
	}
	if (flat_normals) {
		// Grass blades: sun-kissed tips over a cooler, deeper root.
		float tip = smoothstep(0.12, 0.38, lpos.y);
		c = mix(c * vec3(0.9, 0.96, 1.0), c * vec3(1.12, 1.08, 0.78), tip);
	}
	// Wet plants after rain: a little darker and richer.
	c *= 1.0 - 0.14 * world_weather.z;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	BACKLIGHT = c * backlight;
	// Looking toward a low sun, leaf and blade edges glow as light shines through them.
	vec3 vdir = normalize(wpos - CAMERA_POSITION_WORLD);
	float toward = pow(max(dot(vdir, normalize(world_sun_dir)), 0.0), 3.0);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float low_sun = 1.0 - 0.6 * smoothstep(0.35, 0.8, world_sun_dir.y);
	EMISSION = c * world_sun_color * toward * rim * rim * low_sun * world_weather.x * (1.0 - world_weather.y) * 0.9;
}
"""

static var _cache: Dictionary = {}
static var _shader: Shader

static func plant_material(sway: float, sway_from: float, flat_normals: bool = false, flower: bool = false) -> ShaderMaterial:
	if _shader == null: _shader = Shader.new(); _shader.code = PLANT_SHADER
	var m := ShaderMaterial.new(); m.shader = _shader
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("sway_from", sway_from)
	m.set_shader_parameter("flat_normals", flat_normals)
	m.set_shader_parameter("flower", flower)
	# Leafy masses (canopies, pines, bushes: gentle sway, real normals) rustle and show painted leaf clusters;
	# thin stems, flowers and grass keep their shape.
	var leafy := not flat_normals and not flower and sway < 0.05
	m.set_shader_parameter("flutter", 0.012 if leafy else 0.0)
	m.set_shader_parameter("clumps", 1.0 if leafy else 0.0)
	m.set_shader_parameter("backlight", 0.3 if leafy else (0.15 if flat_normals else 0.2))
	return m

static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = freq; n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

## One lumpy, smooth blob: a sphere pushed in and out by noise, slightly flattened underneath.
static func _blob(st: SurfaceTool, center: Vector3, r: float, seed: int, lo: float, hi: float, top: float, bottom: float) -> void:
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 18; sm.rings = 11
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nz := _noise(seed, 1.6 / r)
	var out := PackedVector3Array(); out.resize(v.size())
	for i in v.size():
		var p := v[i]
		var dir := p.normalized() if p.length() > 0.0001 else Vector3.UP
		var bump := 1.0 + nz.get_noise_3dv(dir * 2.0) * 0.16
		p = dir * r * bump
		if p.y < 0.0: p.y *= 0.78
		out[i] = center + p
	for t in range(0, idx.size(), 3):
		for k in [0, 1, 2]:
			var p: Vector3 = out[idx[t + k]]
			var g := clampf(inverse_lerp(bottom, top, p.y), 0.0, 1.0)
			var shade := lerpf(lo, hi, g * g * (3.0 - 2.0 * g))
			st.set_color(Color(shade, shade, shade))
			st.set_uv(Vector2.ZERO)
			st.add_vertex(p)

static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.index()
	st.generate_normals()
	return st.commit()

## Round tree canopy centred on the origin (about 1.1 m radius), made of overlapping blobs.
static func canopy(variant: int = 0) -> ArrayMesh:
	var key := "canopy%d" % variant
	if _cache.has(key): return _cache[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs := [[Vector3(0, 0, 0), 0.95], [Vector3(0.6, -0.15, 0.25), 0.68], [Vector3(-0.55, -0.1, -0.3), 0.66],
		[Vector3(0.1, 0.55, -0.05), 0.66], [Vector3(-0.25, -0.2, 0.55), 0.58], [Vector3(0.3, 0.1, -0.6), 0.55]]
	for i in blobs.size():
		var b: Array = blobs[i]
		var c: Vector3 = b[0] * 0.85
		if variant == 1: c = Vector3(-c.z, c.y, c.x)
		_blob(st, c, b[1] * 0.85, 17 + i * 7 + variant * 31, 0.55, 1.0, 1.0, -0.8)
	_cache[key] = _finish(st)
	return _cache[key]

## Small bush made of three blobs, resting on the ground at the origin.
static func bush() -> ArrayMesh:
	if _cache.has("bush"): return _cache["bush"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in [[Vector3(0, 0.32, 0), 0.42], [Vector3(0.34, 0.24, 0.12), 0.3], [Vector3(-0.3, 0.24, -0.1), 0.32], [Vector3(0.02, 0.22, 0.32), 0.26]]:
		_blob(st, b[0], b[1], int(b[1] * 100), 0.6, 1.0, 0.75, 0.0)
	_cache["bush"] = _finish(st)
	return _cache["bush"]

## Pine: three drooping tiers with wavy hems, origin at the ground, about 3 m tall at scale 1.
static func pine() -> ArrayMesh:
	if _cache.has("pine"): return _cache["pine"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [[0.75, 1.15, 1.25], [1.45, 0.88, 1.05], [2.05, 0.6, 0.95]]  # base y, radius, height
	var seg := 16
	for tier in tiers:
		var y0: float = tier[0]; var r: float = tier[1]; var h: float = tier[2]
		var apex := Vector3(0, y0 + h, 0)
		var ring: Array = []
		for i in seg + 1:
			var a := TAU * i / seg
			var wave := 0.12 * (1.0 if i % 2 == 0 else -0.6)
			ring.append(Vector3(cos(a) * r, y0 + wave * 0.6, sin(a) * r))
		var under := Vector3(0, y0 + 0.25, 0)
		for i in seg:
			var a: Vector3 = ring[i]; var b: Vector3 = ring[i + 1]
			for p in [apex, b, a]:
				var g := clampf((p.y - y0) / h, 0.0, 1.0)
				var s := lerpf(0.6, 1.0, g)
				st.set_color(Color(s, s, s)); st.set_uv(Vector2.ZERO); st.add_vertex(p)
			for p in [under, a, b]:
				st.set_color(Color(0.45, 0.45, 0.45)); st.set_uv(Vector2.ZERO); st.add_vertex(p)
	_cache["pine"] = _finish(st)
	return _cache["pine"]

## Grass tuft: five bent, tapering blades in a loose ring; dark at the root, bright at the tip.
static func grass_tuft() -> ArrayMesh:
	if _cache.has("grass"): return _cache["grass"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for b in 6:
		var a := TAU * b / 6.0 + rng.randf_range(-0.3, 0.3)
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, 0.07)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.16)
		var h := rng.randf_range(0.24, 0.42)
		var w := rng.randf_range(0.045, 0.065)
		var side := Vector3(-sin(a), 0, cos(a))
		var pts: Array = []
		for k in 4:
			var t := k / 3.0
			var c := base + lean * t * t + Vector3(0, h * t, 0)
			var ww := w * (1.0 - t)
			pts.append([c - side * ww, c + side * ww, t])
		for k in 3:
			var p0: Array = pts[k]; var p1: Array = pts[k + 1]
			var quad := [[p0[0], p0[2]], [p1[0], p1[2]], [p0[1], p0[2]], [p0[1], p0[2]], [p1[0], p1[2]], [p1[1], p1[2]]]
			for q in quad:
				var s := lerpf(0.72, 1.0, q[1])
				st.set_color(Color(s, s, s)); st.set_uv(Vector2.ZERO); st.set_normal(Vector3.UP); st.add_vertex(q[0])
	_cache["grass"] = st.commit()
	return _cache["grass"]

## Flower head: five rounded petals around a centre (UV.x = 1 marks the centre), facing up, at the origin.
static func flower_head() -> ArrayMesh:
	if _cache.has("flower"): return _cache["flower"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in 5:
		var a := TAU * p / 5.0
		var dir := Vector3(cos(a), 0, sin(a)); var side := Vector3(-sin(a), 0, cos(a))
		var n := 6
		var center := dir * 0.06 + Vector3(0, 0.012, 0)
		for k in n:
			var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
			var e0 := center + dir * cos(a0) * 0.055 + side * sin(a0) * 0.035
			var e1 := center + dir * cos(a1) * 0.055 + side * sin(a1) * 0.035
			e0.y += (e0 - center).dot(dir) * 0.25; e1.y += (e1 - center).dot(dir) * 0.25
			for q in [center, e1, e0]:
				st.set_color(Color.WHITE); st.set_uv(Vector2.ZERO); st.set_normal(Vector3.UP); st.add_vertex(q)
	var ctr := SphereMesh.new(); ctr.radius = 0.032; ctr.height = 0.04; ctr.radial_segments = 8; ctr.rings = 4
	var arr := ctr.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]; var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		for k in [0, 1, 2]:
			st.set_color(Color.WHITE); st.set_uv(Vector2(1, 0)); st.set_normal(nn[idx[t + k]]); st.add_vertex(v[idx[t + k]] + Vector3(0, 0.02, 0))
	_cache["flower"] = st.commit()
	return _cache["flower"]
