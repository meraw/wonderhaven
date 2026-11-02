class_name TerrainBuilder
## Terrain mesh from the shared heightfield, with painted vertex colours; water; sky.

static func build_terrain() -> MeshInstance3D:
	var size := 124.0
	var seg := 150
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := Color("8fd16a"); var grass2 := Color("76c25a"); var grass3 := Color("a6dc74")
	var sand := Color("f0dfae"); var path := Color("e8cf9a"); var plaza := Color("dccfbd"); var bed := Color("d8c08e"); var stone := Color("bdb5a8")
	var sq: Dictionary = Data.layout.square
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
			if h < 0.12: c = c.lerp(sand, minf(1.0, (0.12 - h) * 3.0))
			if h < Heightfield.WATER_Y: c = bed
			if h > -0.25 and absf(x) < 60:
				var dp := WorldStatics.dist_to_paths(x, z)
				if dp < 1.25: c = c.lerp(path, minf(1.0, (1.25 - dp) * 2.2))
			var ds := Vector2(x - sq.x, z - sq.z).length()
			if ds < sq.r: c = c.lerp(plaza, minf(1.0, (sq.r - ds) * 1.5))
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
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.vertex_color_is_srgb = true
	mt.roughness = 1.0
	mt.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.material_override = mt
	m.name = "Terrain"
	return m

const SKY_SHADER := """
shader_type sky;
uniform vec4 top_color : source_color = vec4(0.42, 0.77, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
void sky() {
	float t = smoothstep(-0.05, 0.6, EYEDIR.y);
	COLOR = mix(bottom_color.rgb, top_color.rgb, t);
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 deep : source_color = vec4(0.18, 0.66, 0.84, 1.0);
uniform vec4 shallow : source_color = vec4(0.45, 0.82, 0.9, 1.0);
uniform float night = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float r = length(wpos.xz);
	float shore = smoothstep(62.0, 46.0, r);
	vec3 col = mix(deep.rgb, shallow.rgb, 0.35 + 0.4 * shore);
	float n = noise(wpos.xz * 0.45 + vec2(TIME * 0.25, TIME * 0.18)) * noise(wpos.xz * 0.8 - vec2(TIME * 0.2, 0.0));
	col += vec3(1.0) * smoothstep(0.42, 0.6, n) * 0.45;
	col = mix(col, col * vec3(0.35, 0.45, 0.8), night);
	ALBEDO = col;
	ROUGHNESS = 0.3;
	ALPHA = 0.82;
}
"""

static func build_water() -> MeshInstance3D:
	var p := PlaneMesh.new(); p.size = Vector2(420, 420)
	var m := MeshInstance3D.new(); m.mesh = p
	var sh := Shader.new(); sh.code = WATER_SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
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
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9dcf0")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.fog_light_color = Color("d9f2ff")
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.glow_intensity = 0.15
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new(); we.environment = env; we.name = "Environment"
	return we
