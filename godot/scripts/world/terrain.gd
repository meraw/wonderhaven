class_name TerrainBuilder
## Terrain mesh from the shared heightfield, with painted vertex colours; water; sky.

static func build_terrain() -> MeshInstance3D:
	var size := 124.0
	var seg := 150
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := Color("8fd16a"); var grass2 := Color("76c25a"); var grass3 := Color("a6dc74")
	var stone := Color("bdb5a8")
	var rng := Rng.new(3)
	var heights := PackedFloat32Array(); heights.resize((seg + 1) * (seg + 1))
	var colors := PackedColorArray(); colors.resize((seg + 1) * (seg + 1))
	for j in seg + 1:
		for i in seg + 1:
			var x := -size / 2.0 + size * i / seg
			var z := -size / 2.0 + size * j / seg
			var h := Heightfield.height(x, z)
			heights[j * (seg + 1) + i] = h
			var n := sin(x * 0.35) * cos(z * 0.29) * 0.5 + 0.5
			var c := grass.lerp(grass2, n * 0.6).lerp(grass3, maxf(0.0, sin(x * 0.11 + z * 0.07)) * 0.35)
			c = c.lightened((rng.next() - 0.5) * 0.04) if rng.next() > 0.5 else c.darkened((rng.next()) * 0.02)
			if x >= 7.7 and x <= 12 and z >= 0.7 and z <= 2.3: c = stone
			colors[j * (seg + 1) + i] = c
	for j in seg + 1:
		for i in seg + 1:
			var idx := j * (seg + 1) + i
			st.set_color(colors[idx])
			st.add_vertex(Vector3(-size / 2.0 + size * i / seg, heights[idx], -size / 2.0 + size * j / seg))
	for j in seg:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + 1
			var c2 := a + seg + 1
			var d := c2 + 1
			st.add_index(a); st.add_index(b); st.add_index(c2)
			st.add_index(b); st.add_index(d); st.add_index(c2)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var sh := Shader.new(); sh.code = TERRAIN_SHADER
	var mt := ShaderMaterial.new(); mt.shader = sh
	var segs := PackedVector4Array()
	for p in Data.layout.paths:
		for n in range(p.size() - 1): segs.append(Vector4(p[n][0], p[n][1], p[n + 1][0], p[n + 1][1]))
	assert(segs.size() <= 32, "terrain shader holds at most 32 path segments")
	mt.set_shader_parameter("segs", segs)
	mt.set_shader_parameter("seg_count", segs.size())
	var sq: Dictionary = Data.layout.square
	mt.set_shader_parameter("square", Vector3(sq.x, sq.z, sq.r))
	mt.set_shader_parameter("water_y", Heightfield.WATER_Y)
	m.material_override = mt
	# The same heights, as a texture, let the water shader tint by depth and draw shore foam.
	var img := Image.create(seg + 1, seg + 1, false, Image.FORMAT_RF)
	for j in seg + 1:
		for i in seg + 1: img.set_pixel(i, j, Color(heights[j * (seg + 1) + i], 0, 0))
	m.set_meta("height_tex", ImageTexture.create_from_image(img))
	m.set_meta("height_rect", Vector4(-size / 2.0, -size / 2.0, size, size))
	m.name = "Terrain"
	return m

const NOISE_LIB := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 - 3.1) * 0.15; }
// x: distance to nearest cell point, y: distance to the cell edge, z: random per cell
vec3 voronoi(vec2 x) {
	vec2 n = floor(x), f = fract(x);
	float md = 8.0; vec2 mr = vec2(0.0); vec2 mc = vec2(0.0);
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j)); vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f; float d = dot(r, r);
		if (d < md) { md = d; mr = r; mc = n + g; }
	}
	float me = 8.0;
	for (int j = -2; j <= 2; j++) for (int i = -2; i <= 2; i++) {
		vec2 g = vec2(float(i), float(j)); vec2 r = g + hash2(n + g) * 0.8 + 0.1 - f;
		if (dot(mr - r, mr - r) > 0.00001) me = min(me, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return vec3(sqrt(md), me, hash(mc));
}
"""

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 segs[32];
uniform int seg_count = 0;
uniform vec3 square = vec3(0.0, 2.0, 7.0);
uniform float water_y = -0.35;
uniform vec4 path_col : source_color = vec4(0.91, 0.79, 0.57, 1.0);
uniform vec4 sand_col : source_color = vec4(0.95, 0.87, 0.66, 1.0);
uniform vec4 bed_col : source_color = vec4(0.78, 0.7, 0.52, 1.0);
uniform vec4 cobble_a : source_color = vec4(0.93, 0.89, 0.82, 1.0);
uniform vec4 cobble_b : source_color = vec4(0.85, 0.8, 0.74, 1.0);
uniform vec4 grout : source_color = vec4(0.72, 0.68, 0.6, 1.0);
varying vec3 wpos;
""" + NOISE_LIB + """
float seg_dist(vec2 p, vec4 s) { vec2 pa = p - s.xy, ba = s.zw - s.xy; float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0); return length(pa - ba * h); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 c0 = COLOR.rgb;
	vec3 col = mix(c0 / 12.92, pow((c0 + 0.055) / 1.055, vec3(2.4)), step(0.04045, c0));  // vertex colours are sRGB
	// Grass: big soft light/dark patches, warm sunny patches and a fine speckle.
	col *= 0.86 + 0.26 * fbm(p * 0.18);
	col = mix(col, col * vec3(1.1, 1.06, 0.8), smoothstep(0.55, 0.78, fbm(p * 0.07 + 11.0)) * 0.55);
	col *= 0.95 + 0.1 * noise(p * 3.7);
	// Sandy shore with a wobbly edge, darker wet sand at the waterline, river bed below.
	float shore = -0.04 + (fbm(p * 0.8) - 0.5) * 0.08;
	vec3 sand = sand_col.rgb * (0.94 + 0.08 * noise(p * 5.0));
	sand = mix(sand, sand * 0.84, smoothstep(water_y + 0.25, water_y + 0.02, wpos.y));
	col = mix(col, sand, smoothstep(shore + 0.03, shore - 0.03, wpos.y));
	col = mix(col, bed_col.rgb * (0.85 + 0.2 * fbm(p * 0.6)), smoothstep(water_y + 0.02, water_y - 0.12, wpos.y));
	// Dirt paths: uneven edges, pebbles, a worn rim, and a slightly darker grass lip.
	if (wpos.y > -0.25 && abs(p.x) < 60.0) {
		float d = 1000.0;
		for (int i = 0; i < seg_count; i++) d = min(d, seg_dist(p, segs[i]));
		float w = 1.0 + (fbm(p * 0.9) - 0.5) * 0.6;
		if (d < w + 0.6) {
			float inside = smoothstep(w + 0.06, w - 0.06, d);
			vec3 v = voronoi(p * 3.4);
			vec3 pc = path_col.rgb * (0.9 + 0.14 * noise(p * 1.3));
			float pebble = step(0.72, v.z) * smoothstep(0.32, 0.18, v.x);
			pc = mix(pc, pc * vec3(0.86, 0.84, 0.82), pebble * 0.8);
			pc = mix(pc, pc * 1.08, pebble * smoothstep(0.18, 0.05, v.x));
			pc *= mix(1.0, 0.88, smoothstep(w - 0.4, w, d));
			col *= 1.0 - 0.14 * smoothstep(w + 0.45, w + 0.05, d) * (1.0 - inside);
			col = mix(col, pc, inside);
		}
	}
	// Town square: cobblestones inside a ring of curb stones.
	vec2 q = p - square.xy;
	float ds = length(q);
	float r = square.z;
	if (ds < r + 0.3) {
		vec3 v = voronoi(p * 1.9);
		vec3 cc = mix(cobble_a.rgb, cobble_b.rgb, v.z) * (0.93 + 0.1 * noise(p * 6.0));
		cc = mix(grout.rgb, cc, smoothstep(0.02, 0.07, v.y));
		cc *= 0.97 + 0.06 * smoothstep(0.35, 0.0, v.x);
		float a = atan(q.y, q.x);
		float cells = floor(r * 6.2832 / 0.7);
		float u = fract(a / 6.2832 * cells);
		float ringband = smoothstep(r - 0.72, r - 0.66, ds) * smoothstep(r + 0.02, r - 0.04, ds);
		vec3 curb = mix(cobble_b.rgb, cobble_a.rgb, hash(vec2(floor(a / 6.2832 * cells), 3.0))) * 0.95;
		curb = mix(grout.rgb, curb, smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.94, u));
		cc = mix(cc, curb, ringband);
		col = mix(col, cc, smoothstep(r + 0.03, r - 0.03, ds));
		col *= 1.0 - 0.12 * smoothstep(r + 0.3, r, ds) * step(r, ds);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""

const SKY_SHADER := """
shader_type sky;
uniform vec4 top_color : source_color = vec4(0.42, 0.77, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.4);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec3 moon_dir = vec3(-0.3, 0.6, -0.4);
uniform float night = 0.0;
uniform float clouds = 0.25;
uniform float cloud_dark = 0.0;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * n2(p); p = p * 2.03 + 11.7; a *= 0.5; } return v; }
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	vec3 col = mix(bottom_color.rgb, top_color.rgb, smoothstep(-0.02, 0.55, up));
	if (up < 0.0) col = mix(bottom_color.rgb, bottom_color.rgb * 0.75, smoothstep(0.0, -0.3, up));
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	// glow around the sun (warm haze near the horizon at sunrise and sunset)
	col += sun_color.rgb * (pow(sd, 10.0) * 0.28 + pow(sd, 90.0) * 0.5) * (1.0 - night) * (1.0 - clouds * 0.6);
	if (!AT_CUBEMAP_PASS) {
		// stars, twinkling, only at night and above the haze
		vec3 sp = d * 180.0;
		vec2 cell = floor(sp.xz / (abs(sp.y) + 40.0) * 60.0);
		float star = step(0.9965, h2(cell + floor(sp.y))) * smoothstep(0.08, 0.35, up);
		star *= 0.6 + 0.4 * sin(TIME * 2.0 + h2(cell) * 40.0);
		col += vec3(0.9, 0.95, 1.0) * star * night * (1.0 - clouds);
		// sun and moon discs
		col = mix(col, sun_color.rgb * 1.6 + 0.2, smoothstep(0.99935, 0.99965, sd) * (1.0 - night) * (1.0 - clouds * 0.8));
		float moon = smoothstep(0.99905, 0.9993, md);
		col = mix(col, vec3(0.93, 0.95, 1.0), moon * night * (1.0 - clouds * 0.85));
		col += vec3(0.5, 0.6, 0.9) * pow(md, 40.0) * 0.12 * night;
		// clouds: drifting fbm on a dome, lit by the sun's colour, greyer when it rains
		if (up > 0.0) {
			vec2 uv = d.xz / (up + 0.18) * 0.9 + vec2(TIME * 0.006, TIME * 0.003);
			float n = fbm(uv * 1.3);
			float cov = smoothstep(1.0 - clouds - 0.12, 1.0 - clouds + 0.28, n);
			cov *= smoothstep(0.0, 0.18, up);
			vec3 lit = mix(vec3(1.0), sun_color.rgb, 0.35) * mix(1.0, 0.42, night);
			vec3 shade = mix(top_color.rgb * 0.9 + 0.15, vec3(0.42, 0.45, 0.5), cloud_dark);
			vec3 cc = mix(lit, shade, smoothstep(0.35, 0.95, n) * 0.7 + cloud_dark * 0.4);
			cc = mix(cc, cc * vec3(0.55, 0.6, 0.8), night);
			col = mix(col, cc, cov * 0.92);
		}
	}
	COLOR = col;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform vec4 deep : source_color = vec4(0.13, 0.47, 0.74, 1.0);
uniform vec4 mid : source_color = vec4(0.22, 0.7, 0.84, 1.0);
uniform vec4 shallow : source_color = vec4(0.52, 0.9, 0.86, 1.0);
uniform float night = 0.0;
uniform float water_y = -0.35;
uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec4 hrect = vec4(-62.0, -62.0, 124.0, 124.0);
varying vec3 wpos;
""" + NOISE_LIB + """
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = (wpos.xz - hrect.xy) / hrect.zw;
	float ground = (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) ? -2.4 : texture(heights, uv).r;
	float depth = max(0.0, water_y - ground);
	vec3 col = mix(shallow.rgb, mid.rgb, smoothstep(0.0, 0.7, depth));
	col = mix(col, deep.rgb, smoothstep(0.8, 2.2, depth));
	// soft moving ripples
	float n = noise(wpos.xz * 0.5 + vec2(TIME * 0.22, TIME * 0.15)) * noise(wpos.xz * 0.9 - vec2(TIME * 0.18, 0.0));
	col += vec3(0.9, 0.97, 1.0) * smoothstep(0.36, 0.52, n) * 0.18;
	col *= 0.96 + 0.08 * noise(wpos.xz * 0.15 + TIME * 0.05);
	// foam hugging the shore, plus a second line lapping in and out
	float fn = fbm(wpos.xz * 1.6 + vec2(TIME * 0.3, -TIME * 0.2));
	float foam = smoothstep(0.16, 0.05, depth + (fn - 0.5) * 0.12);
	float lap = fract(depth * 3.0 - TIME * 0.35);
	foam = max(foam, smoothstep(0.08, 0.0, abs(lap - 0.5)) * smoothstep(0.55, 0.12, depth) * step(0.45, fn) * 0.8);
	col = mix(col, vec3(0.97, 1.0, 1.0), foam * 0.85);
	col = mix(col, col * vec3(0.35, 0.45, 0.8), night);
	ALBEDO = col;
	ROUGHNESS = 0.4;
	ALPHA = clamp(mix(0.5, 0.94, smoothstep(0.0, 1.0, depth)) + foam * 0.5, 0.0, 1.0);
}
"""

static func build_water(terrain: MeshInstance3D) -> MeshInstance3D:
	var p := PlaneMesh.new(); p.size = Vector2(420, 420); p.subdivide_width = 0; p.subdivide_depth = 0
	var m := MeshInstance3D.new(); m.mesh = p
	var sh := Shader.new(); sh.code = WATER_SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.set_shader_parameter("heights", terrain.get_meta("height_tex"))
	sm.set_shader_parameter("hrect", terrain.get_meta("height_rect"))
	sm.set_shader_parameter("water_y", Heightfield.WATER_Y)
	m.material_override = sm
	m.position.y = Heightfield.WATER_Y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "Water"
	return m

static func build_environment() -> WorldEnvironment:
	var env := Environment.new()
	var sky := Sky.new()
	var sh := Shader.new(); sh.code = SKY_SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32   # ambient light comes from a colour, so the sky's reflection map can be tiny
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9dcf0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	# Contact shadows under eaves, trees and furniture (Forward+ / Mobile only).
	env.ssao_enabled = not compat
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	# Soft atmospheric haze so distant hills fade into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("cfe6f7")
	env.fog_density = 0.55
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 220.0
	env.fog_depth_curve = 1.6
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	if compat:
		# The compatibility renderer has no SSAO and lights a little hotter: tone it down to match.
		env.tonemap_exposure = 0.85
		env.adjustment_saturation = 1.0
	var we := WorldEnvironment.new(); we.environment = env; we.name = "Environment"
	return we
