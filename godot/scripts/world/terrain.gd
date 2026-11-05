class_name TerrainBuilder
## Terrain mesh from the shared heightfield, with painted vertex colours; water; sky.

## The ground mesh, as wide as the layout's `size` (a city, or Monteforchetta's slopes running down to the valley
## past the playable edge).
static func build_terrain() -> MeshInstance3D:
	var size := Data.map_size()   # 124 m unless the layout says otherwise; vertex spacing stays the same
	var seg := int(round(150.0 * size / Data.DEFAULT_MAP_SIZE))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a layout's "grassColors": [main, darker, lighter] sets the meadow's colours (autumn olive and straw, say)
	var gp: Array = Data.layout.get("grassColors", ["8fd16a", "76c25a", "a6dc74"])
	var grass := Color(gp[0]); var grass2 := Color(gp[1]); var grass3 := Color(gp[2])
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
			if Data.island == "hearthglow" and x >= 7.7 and x <= 12 and z >= 0.7 and z <= 2.3: c = stone   # the mill channel's stone lining
			if Data.island == "clockwork" and x >= 9.6 and x <= 15.4 and z >= -8.4 and z <= -6.6: c = stone
			if Heightfield.has_paint():   # a location's own ground colour (alpha: how much meadow grows there)
				var g := Heightfield.paint(x, z)
				c = Color(g.r, g.g, g.b).lightened((rng.next() - 0.5) * 0.05)
				c.a = g.a
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
	var sq: Dictionary = Data.layout.get("square", {"x": 0.0, "z": 0.0, "r": 0.0})
	mt.set_shader_parameter("square", Vector3(sq.x, sq.z, sq.r))
	mt.set_shader_parameter("water_y", Heightfield.WATER_Y)
	mt.set_shader_parameter("water_r", water_radius())
	mt.set_shader_parameter("path_reach", size / 2.0 - 2.0)
	# Streets, squares and quays painted over the grass (Ground): one byte per half metre, the kind of paving.
	if not Ground.shapes().is_empty():
		var rect := Rect2(-size / 2.0, -size / 2.0, size, size)
		mt.set_shader_parameter("ground_map", ImageTexture.create_from_image(Ground.bake(Ground.shapes(), rect)))
		mt.set_shader_parameter("ground_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		mt.set_shader_parameter("has_ground", true)
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
// xy: offset from this point to the nearest cell point, z: distance to the cell edge, w: random per cell
vec4 voronoi_dir(vec2 x) {
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
	return vec4(mr, me, hash(mc));
}
"""

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 segs[32];
uniform int seg_count = 0;
uniform vec3 square = vec3(0.0, 2.0, 7.0);
uniform float water_y = -0.35;
uniform float water_r = 100000.0;   // water (and its sand and river bed) only within this distance of the centre
uniform vec4 path_col : source_color = vec4(0.91, 0.79, 0.57, 1.0);
uniform vec4 sand_col : source_color = vec4(0.95, 0.87, 0.66, 1.0);
uniform vec4 bed_col : source_color = vec4(0.78, 0.7, 0.52, 1.0);
uniform vec4 cobble_a : source_color = vec4(0.93, 0.89, 0.82, 1.0);
uniform vec4 cobble_b : source_color = vec4(0.85, 0.8, 0.74, 1.0);
uniform vec4 grout : source_color = vec4(0.72, 0.68, 0.6, 1.0);
uniform float path_reach = 60.0;   // dirt paths are drawn within this many metres of the middle (half the map)
uniform float frost = 0.0;         // hoarfrost (a location's look, by the hour: Atmosphere.frost_at)
// Paved ground (Ground): kind index per texel (0 grass, 1 asphalt, 2 setts, 3 slabs, 4 gravel).
uniform bool has_ground = false;
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform vec4 ground_rect = vec4(-62.0, -62.0, 124.0, 124.0);
// Shared world values (Atmosphere): sun direction, weather (x sunlit, y night, z wet, w clouds), sky colours (linear).
global uniform vec3 world_sun_dir;
global uniform vec4 world_weather;
global uniform vec3 world_sky_horizon;
global uniform vec3 world_sky_zenith;
varying vec3 wpos;
varying vec3 wnrm;
""" + NOISE_LIB + """
float seg_dist(vec2 p, vec4 s) { vec2 pa = p - s.xy, ba = s.zw - s.xy; float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0); return length(pa - ba * h); }
// Sine-free hashes (no rows or stripes in scattered details).
float hq(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hq2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
// Dots scattered one per cell, away from the cell edges: x distance to the dot, y random per cell.
vec2 scatter(vec2 q) { vec2 c = floor(q); vec2 o = 0.25 + 0.5 * hq2(c); return vec2(length(fract(q) - o), hq(c + 71.3)); }
// Raindrop rings in puddles: one drop per cell at a random moment, its ring spreading and fading.
float drops(vec2 q, float t) {
	vec2 c = floor(q); vec2 o = 0.3 + 0.4 * hq2(c + 9.0);
	float life = fract(t * 0.8 + hq(c + 5.1));
	return smoothstep(0.05, 0.0, abs(length(fract(q) - o) - life * 0.28)) * (1.0 - life);
}
float caustic_layer(vec2 q) { return smoothstep(0.14, 0.0, voronoi(q).y); }
// Sunlight focused by moving ripples: two drifting nets of bright lines.
float caustics(vec2 p, float t) {
	vec2 w = vec2(noise(p * 0.6 + t * 0.15), noise(p * 0.6 - t * 0.12)) * 0.6;
	float a = caustic_layer(p * 1.25 + w + vec2(t * 0.09, t * 0.05));
	float b = caustic_layer(p * 1.55 - w + vec2(-t * 0.06, t * 0.08));
	return clamp(a * 0.65 + b * 0.5, 0.0, 1.0);
}
// Paving, painted rather than modelled: each stone a slightly different tone, thin grout, a lit edge toward the sun
// and a shaded edge away from it. Fine detail fades with distance; rain darkens it and leaves puddles that mirror
// the sky.
vec3 paving(int kind, vec2 p, vec2 sp, vec2 sun2, float direct, float fine, float wet, float graze, vec3 sky_seen) {
	vec3 c;
	float puddle_amt = 0.0;
	if (kind == 1) {   // asphalt: warm mid grey, soft patches, fine grit and a few repaired squares
		c = vec3(0.29, 0.282, 0.272) * (0.88 + 0.22 * fbm(p * 0.21));
		c *= mix(1.0, 0.92 + 0.16 * noise(p * 11.0), fine);   // grit
		float mended = step(0.86, hq(floor(p * 0.33) + 17.0));
		c *= 1.0 + 0.1 * mended;
		puddle_amt = smoothstep(0.62, 0.68, fbm(p * 0.27 + 3.0));
	} else if (kind == 2) {   // setts: small square stones in staggered rows, reddish-grey porphyry
		vec2 q = p * 6.0;
		float row = floor(q.y);
		q.x += row * 0.5 + hq(vec2(row, 4.0)) * 0.3;
		vec2 cell = floor(q); vec2 f = fract(q) - 0.5;
		float h = hq(cell);
		c = mix(vec3(0.42, 0.33, 0.3), vec3(0.47, 0.44, 0.41), h) * (0.92 + 0.12 * hq(cell + 3.1));
		float edge = 0.5 - max(abs(f.x), abs(f.y));
		float lit = dot(normalize(f + 0.0001), sun2) * smoothstep(0.12, 0.02, edge);
		c *= 1.0 + lit * 0.14 * direct * fine;
		c = mix(mix(c, vec3(0.26, 0.24, 0.22), smoothstep(0.06, 0.0, edge)), c * 0.92 + 0.03, 1.0 - fine);
		puddle_amt = smoothstep(0.64, 0.7, fbm(p * 0.4 + 7.0));
	} else if (kind == 3) {   // slabs: big pale granite flags in a staggered bond
		vec2 q = p / vec2(1.4, 0.9);
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(q); vec2 f = fract(q);
		c = vec3(0.66, 0.64, 0.6) * (0.93 + 0.1 * hq(cell)) * (0.95 + 0.08 * noise(p * 4.0));
		c *= mix(1.0, 0.95 + 0.1 * noise(p * 13.0), fine);   // granite mottle
		vec2 e2 = min(f, 1.0 - f) * vec2(1.4, 0.9);
		float edge = min(e2.x, e2.y);
		c = mix(c, c * 0.72, smoothstep(0.03, 0.0, edge) * fine);
		puddle_amt = smoothstep(0.66, 0.72, fbm(p * 0.3 + 11.0));
	} else {   // gravel: pale crunchy park paths with paler pebbles lit from the sun's side
		c = vec3(0.78, 0.71, 0.58) * (0.9 + 0.14 * noise(p * 1.3));
		vec4 v = voronoi_dir(p * 5.0);
		float pd = length(v.xy);
		float peb = step(0.6, v.w) * smoothstep(0.3, 0.22, pd);
		c = mix(c, c * 1.08, peb * fine);
		c *= 1.0 + peb * dot(-v.xy / max(pd, 0.0001), sun2) * 0.12 * direct * fine;
		puddle_amt = smoothstep(0.6, 0.66, fbm(p * 0.33 + 41.0));
	}
	c *= mix(vec3(1.0), mix(vec3(1.0), vec3(1.04, 1.03, 0.97), smoothstep(0.72, 0.79, noise(sp * vec2(2.6, 14.0)))), fine * 0.5);
	c *= 1.0 - 0.3 * wet;
	float puddle = wet * puddle_amt;
	c = mix(c, mix(c * 0.45, sky_seen, 0.35 + 0.5 * graze), puddle);
	c += vec3(0.8, 0.88, 1.0) * drops(p * 2.2, TIME) * puddle * 0.3 * fine;
	return c;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	// Metres per pixel: small details fade out with distance instead of shimmering.
	float px = length(fwidth(p));
	float fine = 1.0 - smoothstep(0.025, 0.08, px);
	vec2 sun2 = normalize(world_sun_dir.xz + vec2(0.0001));   // which way the sun is, along the ground
	float direct = 0.35 + 0.65 * world_weather.x;              // how strongly sunlit details stand out
	float wet = world_weather.z;
	float graze = pow(1.0 - clamp(normalize(CAMERA_POSITION_WORLD - wpos).y, 0.0, 1.0), 2.0);   // puddles mirror more at a low angle
	vec3 sky_seen = mix(world_sky_horizon, world_sky_zenith, 0.45) * 0.85;
	vec3 c0 = COLOR.rgb;
	vec3 col = mix(c0 / 12.92, pow((c0 + 0.055) / 1.055, vec3(2.4)), step(0.04045, c0));  // vertex colours are sRGB
	// Grass: big soft light/dark patches, warm sunny patches, cooler deep patches and a fine speckle.
	col *= 0.86 + 0.26 * fbm(p * 0.18);
	col = mix(col, col * vec3(1.1, 1.06, 0.8), smoothstep(0.55, 0.78, fbm(p * 0.07 + 11.0)) * 0.55);
	col = mix(col, col * vec3(0.84, 0.97, 1.03), smoothstep(0.52, 0.78, fbm(p * 0.12 - 5.0)) * 0.55);
	col *= 0.95 + 0.1 * noise(p * 3.7);
	// Painterly hatching: short, crisp dashes all leaning one way, light warm ones and dark cool ones.
	vec2 sp = mat2(vec2(0.82, -0.57), vec2(0.57, 0.82)) * p;
	float lit_dash = smoothstep(0.7, 0.77, noise(sp * vec2(2.6, 14.0)));
	float dark_dash = smoothstep(0.72, 0.79, noise(sp * vec2(2.6, 14.0) + vec2(37.0, 11.0)));
	vec3 hatch = mix(vec3(1.0), vec3(1.09, 1.07, 0.9), lit_dash) * mix(vec3(1.0), vec3(0.88, 0.95, 1.0), dark_dash);
	col *= mix(vec3(1.0), hatch, fine);
	// Slopes turn earthier and darker, so hills and banks read by their shape; high ground dries warmer.
	float slope = 1.0 - clamp(normalize(wnrm + vec3(0.0, 0.00001, 0.0)).y, 0.0, 1.0);
	col = mix(col, col * vec3(0.9, 0.8, 0.64), smoothstep(0.06, 0.28, slope) * 0.6);
	col *= mix(vec3(1.0), vec3(1.05, 1.02, 0.86), smoothstep(0.5, 1.6, wpos.y));
	// Clover sprigs and tiny wildflowers, gathered in loose drifts, only where meadow grows (vertex alpha: a
	// location's ground paint, see Heightfield.paint).
	float meadow = COLOR.a;
	float drift = smoothstep(0.42, 0.68, fbm(p * 0.09 + 23.0));
	vec2 cl = scatter(p * 1.9);
	float clover = step(0.55 - 0.35 * drift, cl.y) * smoothstep(0.17, 0.11, cl.x) * fine * meadow;
	col = mix(col, col * vec3(0.78, 0.92, 0.86), clover * 0.55);
	vec2 fl = scatter(p * 2.2 + 31.0);
	float bloom = step(1.0 - 0.2 * drift, fl.y) * smoothstep(0.1, 0.07, fl.x) * fine * meadow;
	vec3 petal = fl.y > 0.985 ? vec3(0.95, 0.55, 0.7) : (fl.y > 0.955 ? vec3(1.0, 0.8, 0.3) : vec3(0.97, 0.96, 0.9));
	petal = mix(petal, vec3(1.0, 0.85, 0.35), smoothstep(0.04, 0.02, fl.x));   // a golden eye
	col = mix(col, petal, bloom * 0.9);
	col *= 1.0 - 0.16 * wet;   // rain darkens the grass
	// Sandy shore with a wobbly edge, darker wet sand at the waterline (only where there is water: inland slopes
	// that run below the water level stay grass).
	float wet_zone = 1.0 - smoothstep(water_r - 2.0, water_r + 2.0, length(p));
	float shore = -0.04 + (fbm(p * 0.8) - 0.5) * 0.08;
	vec3 sand = sand_col.rgb * (0.94 + 0.08 * noise(p * 5.0));
	sand = mix(sand, sand * 0.84, smoothstep(water_y + 0.25, water_y + 0.02, wpos.y));
	sand *= 1.0 - 0.2 * wet;
	col = mix(col, sand, smoothstep(shore + 0.03, shore - 0.03, wpos.y) * meadow * wet_zone);
	// River and pond beds, with caustics dancing over the shallows when the sun is out.
	float under = smoothstep(water_y + 0.02, water_y - 0.12, wpos.y) * wet_zone;
	if (under > 0.0) {
		vec3 bed = bed_col.rgb * (0.85 + 0.2 * fbm(p * 0.6));
		float depth = max(0.0, water_y - wpos.y);
		float ca = caustics(p, TIME) * smoothstep(0.0, 0.12, depth) * (1.0 - smoothstep(0.5, 1.7, depth));
		bed *= 1.0 + ca * 0.55 * world_weather.x * (1.0 - 0.7 * wet);
		col = mix(col, bed, under);
	}
	// Hoarfrost: a patchy white crust over the ground (paths and paving, drawn next, stay clear where they're walked),
	// thickest on flat open ground, never under water, with a few glints in the sun.
	if (frost > 0.001) {
		float crust = smoothstep(0.42, 0.76, fbm(p * 0.3 + 3.0) * 0.6 + noise(p * 6.0) * 0.3 + frost * 0.26);
		float flat_ground = smoothstep(0.4, 0.05, slope);
		float fz = frost * crust * (1.0 - under) * smoothstep(water_y + 0.02, water_y + 0.12, wpos.y);
		float speck = mix(1.0, 0.86 + 0.14 * smoothstep(0.3, 0.7, noise(p * 9.0)), fine);
		vec3 rime = vec3(0.86, 0.9, 0.95) * speck;
		col = mix(col, max(col, rime), fz * mix(0.4, 0.72, flat_ground));
		vec2 gl = scatter(p * 9.0 + 17.0);
		col += vec3(0.3) * step(0.965, gl.y) * smoothstep(0.08, 0.02, gl.x) * fz * fine * world_weather.x;
	}
	// Dirt paths: uneven edges, raised pebbles lit from the sun's side, a worn rim, a darker grass lip, and
	// puddles that mirror the sky after rain.
	if (has_ground) {
		vec2 guv = (p - ground_rect.xy) / ground_rect.zw;
		int kind = int(texture(ground_map, guv).r * 255.0 + 0.5);
		// Lawns and gravel meet along a soft wobble instead of the map's half-metre steps; kerbs stay straight.
		vec2 jit = (vec2(noise(p * 1.7), noise(p * 1.7 + 5.3)) - 0.5) * 0.9;
		int kj = int(texture(ground_map, guv + jit / ground_rect.zw).r * 255.0 + 0.5);
		if ((kind == 0 || kind == 4) && (kj == 0 || kj == 4)) kind = kj;
		if (kind > 0 && guv.x > 0.0 && guv.x < 1.0 && guv.y > 0.0 && guv.y < 1.0) col = mix(col, paving(kind, p, sp, sun2, direct, fine, wet, graze, sky_seen), 1.0 - under);
	}
	if (wpos.y > -0.25 && abs(p.x) < path_reach) {
		float d = 1000.0;
		for (int i = 0; i < seg_count; i++) d = min(d, seg_dist(p, segs[i]));
		float w = 1.0 + (fbm(p * 0.9) - 0.5) * 0.6;
		if (d < w + 0.6) {
			float inside = smoothstep(w + 0.06, w - 0.06, d);
			vec3 pc = path_col.rgb * (0.9 + 0.14 * noise(p * 1.3));
			pc *= mix(1.0, 0.94 + 0.12 * noise(sp * vec2(3.0, 14.0)), fine);   // raked, streaky dirt
			vec4 v = voronoi_dir(p * 3.4);
			float pd = length(v.xy);
			float is_peb = step(0.8, v.w);
			vec2 dir = -v.xy / max(pd, 0.0001);
			float pebble = is_peb * smoothstep(0.27, 0.21, pd);
			float lit = dot(dir, sun2) * smoothstep(0.06, 0.22, pd);
			// pebbles are paler than the dirt (so they read as stones sitting on it, not holes in it)
			pc = mix(pc, pc * mix(vec3(1.02, 1.0, 0.98), vec3(1.12, 1.08, 1.02), hash(v.zw)), pebble);
			pc *= 1.0 + pebble * lit * 0.22 * direct;
			float shadow = is_peb * smoothstep(0.36, 0.28, pd) * smoothstep(0.2, 0.27, pd) * max(0.0, -dot(dir, sun2));
			pc *= 1.0 - shadow * 0.3 * direct * fine;
			pc *= mix(1.0, 0.88, smoothstep(w - 0.4, w, d));
			pc *= 1.0 - 0.3 * wet;
			float pm = fbm(p * 0.33 + 41.0);
			float puddle = wet * smoothstep(0.6, 0.66, pm) * smoothstep(w - 0.15, w - 0.5, d);
			pc *= 1.0 - 0.25 * wet * smoothstep(0.55, 0.6, pm) * (1.0 - puddle);   // damp ring round each puddle
			pc = mix(pc, mix(pc * 0.4, sky_seen, 0.35 + 0.5 * graze), puddle);
			pc += vec3(0.8, 0.88, 1.0) * drops(p * 2.2, TIME) * puddle * 0.3 * fine;
			col *= 1.0 - 0.14 * smoothstep(w + 0.45, w + 0.05, d) * (1.0 - inside);
			col = mix(col, pc, inside);
		}
	}
	// Town square: domed cobblestones (lit edge toward the sun, shaded edge away), each a slightly different
	// warmth, inside a ring of curb stones.
	vec2 q = p - square.xy;
	float ds = length(q);
	float r = square.z;
	if (ds < r + 0.3) {
		vec4 v = voronoi_dir(p * 1.9);
		vec3 cc = mix(cobble_a.rgb, cobble_b.rgb, v.w) * (0.93 + 0.1 * noise(p * 6.0));
		cc *= mix(vec3(1.04, 1.0, 0.94), vec3(0.95, 0.99, 1.05), hash(vec2(v.w * 91.0, 3.0)));
		cc = mix(grout.rgb, cc, smoothstep(0.02, 0.07, v.z));
		float vd = length(v.xy);
		cc *= 0.97 + 0.06 * smoothstep(0.35, 0.0, vd);
		vec2 dir = -v.xy / max(vd, 0.0001);
		cc *= 1.0 + (1.0 - smoothstep(0.04, 0.17, v.z)) * smoothstep(0.02, 0.06, v.z) * dot(dir, sun2) * 0.14 * direct;
		float a = atan(q.y, q.x);
		float cells = floor(r * 6.2832 / 0.7);
		float u = fract(a / 6.2832 * cells);
		float ringband = smoothstep(r - 0.72, r - 0.66, ds) * smoothstep(r + 0.02, r - 0.04, ds);
		vec3 curb = mix(cobble_b.rgb, cobble_a.rgb, hash(vec2(floor(a / 6.2832 * cells), 3.0))) * 0.95;
		curb = mix(grout.rgb, curb, smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.94, u));
		cc = mix(cc, curb, ringband);
		cc *= 1.0 - 0.22 * wet;
		float puddle = wet * smoothstep(0.64, 0.7, fbm(p * 0.4 + 7.0)) * (1.0 - ringband);
		cc = mix(cc, mix(cc * 0.45, sky_seen, 0.35 + 0.5 * graze), puddle);
		cc += vec3(0.8, 0.88, 1.0) * drops(p * 2.2 + 3.0, TIME) * puddle * 0.3 * fine;
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
global uniform vec2 world_cloud_drift;   // clouds drift downwind (Atmosphere); their shadows use the same noise
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
		// stars: round dots on a 3D grid of directions, a few per patch of sky, twinkling, above the haze
		vec3 sp = d * 90.0;
		vec3 cell = floor(sp);
		float sh = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
		vec3 off = vec3(fract(sh * 13.1), fract(sh * 71.7), fract(sh * 37.3)) * 0.6 + 0.2;
		float dotd = length(fract(sp) - off);
		float star = step(0.982, sh) * smoothstep(0.17, 0.06, dotd) * smoothstep(0.08, 0.35, up);
		star *= 0.65 + 0.35 * sin(TIME * (1.5 + sh * 3.0) + sh * 60.0);
		col += vec3(0.92, 0.95, 1.0) * star * night * (1.0 - clouds);
		// sun and moon discs
		col = mix(col, sun_color.rgb * 1.6 + 0.2, smoothstep(0.99935, 0.99965, sd) * (1.0 - night) * (1.0 - clouds * 0.8));
		float moon = smoothstep(0.99905, 0.9993, md);
		col = mix(col, vec3(0.93, 0.95, 1.0), moon * night * (1.0 - clouds * 0.85));
		col += vec3(0.5, 0.6, 0.9) * pow(md, 40.0) * 0.12 * night;
		// clouds: drifting fbm on a dome, lit by the sun's colour, greyer when it rains
		if (up > 0.0) {
			vec2 uv = d.xz / (up + 0.18) * 0.9 + world_cloud_drift;
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
uniform float water_r = 100000.0;   // no water beyond this distance from the centre (inland places)
uniform float ice = 0.0;            // thin ice on shallow water (a location's look, by the hour: Atmosphere.ice_at)
uniform float foam_amount = 1.0;    // shore foam (a location's look: still paddy water has next to none)
uniform sampler2D tints : source_color, filter_linear, repeat_disable;   // a location's water colours (Heightfield.water_tint)
uniform bool has_tints = false;
// Shared world values (Atmosphere); colours are linear.
global uniform vec3 world_sun_dir;
global uniform vec3 world_sun_color;
global uniform vec4 world_weather;   // x sunlit, y night, z wet, w clouds
global uniform vec3 world_sky_horizon;
global uniform vec3 world_sky_zenith;
global uniform vec4 world_wind;
varying vec3 wpos;
""" + NOISE_LIB + """
// Smooth value noise (quintic fade: no grid creases when used for normals).
float snoise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
// Ripple height: two broad swells drifting downwind plus a fine chop, each octave turned so no grid shows.
float ripple(vec2 q, float t, vec2 wd) {
	mat2 r1 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)); mat2 r2 = mat2(vec2(0.47, -0.88), vec2(0.88, 0.47));
	return snoise(q * 0.8 + wd * t * 0.35) * 0.55 + snoise(r1 * q * 1.9 - vec2(wd.y, -wd.x) * t * 0.3) * 0.32 + snoise(r2 * q * 4.1 + wd * t * 0.8) * 0.13;
}
// Raindrop rings: one drop per cell at a random moment, its ring spreading and fading.
float rings(vec2 q, float t) {
	vec2 c = floor(q); vec2 f = fract(q);
	vec2 o = 0.3 + 0.4 * hash2(c);
	float life = fract(t * 0.8 + hash(c + 5.1));
	float d = length(f - o);
	return smoothstep(0.045, 0.0, abs(d - life * 0.28)) * (1.0 - life);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (length(wpos.xz) > water_r) discard;
	vec2 uv = (wpos.xz - hrect.xy) / hrect.zw;
	float ground = (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) ? -2.4 : texture(heights, uv).r;
	float depth = max(0.0, water_y - ground);
	vec3 col = mix(shallow.rgb, mid.rgb, smoothstep(0.0, 0.7, depth));
	col = mix(col, deep.rgb, smoothstep(0.8, 2.2, depth));
	// Silt clouding the water where the location says so (a brown river beside a clear one): its colour, lighter in
	// the shallows, and it hides the bed. Past the map's edge the edge's colours carry on.
	float murk = 0.0;
	if (has_tints) {
		vec4 tn = texture(tints, clamp(uv, vec2(0.0), vec2(1.0)));
		murk = tn.a;
		col = mix(col, tn.rgb * mix(1.06, 0.86, smoothstep(0.0, 1.6, depth)), murk);
	}
	// soft moving ripples
	float n = noise(wpos.xz * 0.5 + vec2(TIME * 0.22, TIME * 0.15)) * noise(wpos.xz * 0.9 - vec2(TIME * 0.18, 0.0));
	col += vec3(0.9, 0.97, 1.0) * smoothstep(0.36, 0.52, n) * 0.18 * (1.0 - 0.7 * murk);   // (dull on silty water)
	col *= 0.96 + 0.08 * noise(wpos.xz * 0.15 + TIME * 0.05);
	// Surface normal from the ripples (calmer far away, where detail would only shimmer).
	vec2 wd = normalize(world_wind.xy + vec2(0.0001));
	vec2 q = wpos.xz;
	float px = length(fwidth(q));
	float e = 0.12;
	float h0 = ripple(q, TIME, wd);
	vec2 slope = vec2(ripple(q + vec2(e, 0.0), TIME, wd) - h0, ripple(q + vec2(0.0, e), TIME, wd) - h0) / e;
	slope *= (0.12 + 0.14 * world_wind.z) * (1.0 - smoothstep(0.05, 0.3, px) * 0.8);
	vec3 nrm = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	// The sky's reflection, strongest at grazing angles (Fresnel): distant water mirrors the sky, while water at
	// your feet shows its depth.
	float fr = pow(1.0 - clamp(dot(nrm, v), 0.0, 1.0), 4.0);
	vec3 sky = mix(world_sky_horizon, world_sky_zenith, 0.55 + 0.35 * clamp(dot(reflect(-v, nrm), vec3(0.0, 1.0, 0.0)), 0.0, 1.0));
	col = mix(col, sky, clamp(0.04 + fr * 0.6, 0.0, 0.42) * (1.0 - 0.45 * murk));   // silty water shows its own colour more
	// raindrop rings when it rains
	float wet = world_weather.z;
	if (wet > 0.02) col += vec3(0.85, 0.92, 1.0) * (rings(q * 1.7, TIME) + rings(q * 2.3 + 0.5, TIME * 1.13)) * wet * 0.35 * (1.0 - smoothstep(0.03, 0.12, px));
	// foam hugging the shore, plus a second line lapping in and out
	float fn = fbm(wpos.xz * 1.6 + vec2(TIME * 0.3, -TIME * 0.2));
	float foam = smoothstep(0.16, 0.05, depth + (fn - 0.5) * 0.12);
	float lap = fract(depth * 3.0 - TIME * 0.35);
	foam = max(foam, smoothstep(0.08, 0.0, abs(lap - 0.5)) * smoothstep(0.55, 0.12, depth) * step(0.45, fn) * 0.8) * foam_amount;
	col = mix(col, vec3(0.97, 1.0, 1.0), foam * 0.85);
	// Thin ice on shallow water: pale and matte, crazed with fine cracks, the ripples stilled under it.
	float ic = ice * smoothstep(0.34, 0.12, depth);
	if (ic > 0.001) {
		float crack = smoothstep(0.035, 0.0, abs(noise(q * 2.3) - 0.5)) + smoothstep(0.025, 0.0, abs(noise(q * 5.1 + 7.0) - 0.5)) * 0.6;
		vec3 icec = vec3(0.78, 0.84, 0.88) * (0.94 + 0.1 * noise(q * 3.0)) * (1.0 - 0.12 * clamp(crack, 0.0, 1.0));
		col = mix(col, mix(icec, sky, 0.25), ic * 0.8);
	}
	col = mix(col, col * vec3(0.35, 0.45, 0.8), night);
	ALBEDO = col;
	ROUGHNESS = 0.4;
	// Glitter: the sun (or a silver moon) caught on ripple crests.
	float g = pow(max(dot(reflect(-v, nrm), normalize(world_sun_dir)), 0.0), 380.0);
	float lightness = world_weather.x + 0.35 * world_weather.y * (1.0 - world_weather.w);
	EMISSION = world_sun_color * g * 7.0 * lightness * (1.0 - foam) * (1.0 - 0.6 * wet) * (1.0 - ic);
	ALPHA = clamp(mix(0.5, 0.94, smoothstep(0.0, 1.0, depth)) + fr * 0.25 + foam * 0.5 + ic * 0.6, 0.0, 1.0);
	ALPHA = mix(ALPHA, 0.96, murk * 0.85);
}
"""

## How far from the centre water exists (a layout's `water_radius`; islands have the sea all round).
static func water_radius() -> float: return float(Data.layout.get("water_radius", 100000.0))

static func build_water(terrain: MeshInstance3D) -> MeshInstance3D:
	var ws := maxf(420.0, Data.map_size() * 3.4)   # the sea reaches the horizon whatever the map's size
	var p := PlaneMesh.new(); p.size = Vector2(ws, ws); p.subdivide_width = 0; p.subdivide_depth = 0
	var m := MeshInstance3D.new(); m.mesh = p
	var sh := Shader.new(); sh.code = WATER_SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.set_shader_parameter("heights", terrain.get_meta("height_tex"))
	sm.set_shader_parameter("hrect", terrain.get_meta("height_rect"))
	sm.set_shader_parameter("water_y", Heightfield.WATER_Y)
	sm.set_shader_parameter("water_r", water_radius())
	if Heightfield.has_water_tint():
		sm.set_shader_parameter("tints", ImageTexture.create_from_image(bake_water_tints(terrain.get_meta("height_rect"))))
		sm.set_shader_parameter("has_tints", true)
	m.material_override = sm
	m.position.y = Heightfield.WATER_Y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "Water"
	return m

## A location's water colours (Heightfield.water_tint) over the height map's rect (x, z, width, depth), one pixel a
## metre: the water shader blends them in by their alpha.
static func bake_water_tints(rect: Vector4) -> Image:
	var n := int(ceil(rect.z)) + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			img.set_pixel(i, j, Heightfield.water_tint(rect.x + rect.z * i / (n - 1), rect.y + rect.w * j / (n - 1)))
	return img

## Mist lying in the valley below a hilltop (a layout's `valley_fog`: {"y": top of the mist, ...}): a sheet at `y`
## that thins where the ground comes up through it, so slopes and hills rise out of a sea of fog. Atmosphere sets
## its `amount` by the hour (thick at dawn, burnt off by late morning) and its colour from the sky.
const VALLEY_FOG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 fog_color : source_color = vec4(0.93, 0.93, 0.92, 1.0);
uniform float amount = 0.0;
uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec4 hrect = vec4(-62.0, -62.0, 124.0, 124.0);
uniform float floor_y = -28.0;
uniform float top_y = -9.0;
uniform vec2 drift = vec2(0.0);
uniform float reach = 480.0;
#ifdef SOFT
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
#endif
varying vec3 wpos;
""" + NOISE_LIB + """
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = (wpos.xz - hrect.xy) / hrect.zw;
	float ground = (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) ? floor_y : texture(heights, uv).r;
#ifdef SOFT
	// Whatever is seen through the mist (the far hills, a house): how far below the top of the mist it stands.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec3 seen = (INV_VIEW_MATRIX * vec4(vp.xyz / vp.w, 1.0)).xyz;
	if (d > 0.000001) ground = max(ground, seen.y);   // (not the empty sky past the hills)
#endif
	// Rolling banks with finer wisps drifting across them; the mist is deeper where the banks pile up, so the
	// slopes come up through it along a ragged line instead of a waterline.
	float n = fbm(wpos.xz * 0.014 + drift) * 0.6 + fbm(wpos.xz * 0.05 - drift * 1.7) * 0.4;
	float depth = top_y - ground - 7.0 * (1.0 - n);
	float edge = smoothstep(0.0, 7.0, depth);
	edge *= smoothstep(reach, reach * 0.8, length(wpos.xz));
	float body = smoothstep(0.25, 0.85, n * 0.75 + amount * 0.4);
	// lit tops, cooler hollows
	ALBEDO = fog_color.rgb * mix(vec3(0.8, 0.84, 0.9), vec3(1.04), smoothstep(0.3, 0.75, n));
	ALPHA = clamp(amount * edge * body, 0.0, 0.93);
}
"""

static func build_valley_fog(spec: Dictionary, terrain: MeshInstance3D) -> MeshInstance3D:
	var p := PlaneMesh.new(); p.size = Vector2(1000.0, 1000.0)
	var m := MeshInstance3D.new(); m.mesh = p
	var sh := Shader.new()
	# depth-softened edges where the renderer can read depth (Forward+); the heights still thin it on the slopes
	sh.code = VALLEY_FOG_SHADER.replace("shader_type spatial;", "shader_type spatial;\n#define SOFT") if Outline.supported() else VALLEY_FOG_SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.set_shader_parameter("heights", terrain.get_meta("height_tex"))
	sm.set_shader_parameter("hrect", terrain.get_meta("height_rect"))
	sm.set_shader_parameter("floor_y", float(spec.get("floor", Heightfield.VALLEY_Y)))
	sm.set_shader_parameter("top_y", float(spec.get("y", -9.0)))
	sm.render_priority = -1   # under the water, leaves and particles
	m.material_override = sm
	m.position.y = float(spec.get("y", -9.0))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "ValleyFog"
	return m

## The far hills' look: vertex colours (sRGB) with vineyard rows along the contours where the alpha says vines grow.
## The rows fade to their average colour where they would be finer than a pixel, so they never shimmer.
const HILLS_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;
varying vec3 wpos;
""" + NOISE_LIB + """
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c0 = COLOR.rgb;
	vec3 col = mix(c0 / 12.92, pow((c0 + 0.055) / 1.055, vec3(2.4)), step(0.04045, c0));
	float vine = COLOR.a;
	float s = wpos.y / 1.6 + noise(wpos.xz * 0.035) * 1.8;   // rows follow the contours, wavering a little
	float fw = fwidth(s);
	float gap = smoothstep(0.18, 0.32, abs(fract(s) - 0.5));
	float fine = 1.0 - smoothstep(0.25, 0.6, fw);
	vec3 grass = vec3(0.2, 0.26, 0.09);   // the grass between the rows
	col = mix(col, mix(col, grass, mix(0.3, gap * 0.75, fine)), vine);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""

## The view beyond the playable land, from a layout's `horizon` block: {"hills": true} rings the valley with rolling
## hills patched in field and autumn vineyard colours (rows striped along the contours), {"alps": true} adds a snowy
## mountain range from the west round to the north (as seen from the Langhe on a clear day), and {"villages": n}
## puts n small hilltop villages, each with its bell tower, on the crests. All sit far out, so the haze softens them.
static func build_backdrop(spec: Dictionary) -> Node3D:
	var root := Node3D.new(); root.name = "Backdrop"
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.vertex_color_is_srgb = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP; mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hills_mat := ShaderMaterial.new(); hills_mat.shader = Shader.new(); hills_mat.shader.code = HILLS_SHADER
	var floor_y := float(spec.get("floor", Heightfield.VALLEY_Y))
	var nz := FastNoiseLite.new(); nz.seed = 31; nz.frequency = 0.012; nz.fractal_octaves = 4
	var cz := FastNoiseLite.new(); cz.seed = 77; cz.frequency = 0.012
	var hill_y := func(x: float, z: float) -> float:
		var r := Vector2(x, z).length()
		var rise := Heightfield.ss(118.0, 200.0, r) * 30.0 + Heightfield.ss(190.0, 300.0, r) * 12.0
		return floor_y - 0.3 + rise * (0.55 + 0.45 * (nz.get_noise_2d(x, z) * 0.5 + 0.5)) + 6.0 * nz.get_noise_2d(x * 2.3, z * 2.3) * Heightfield.ss(118.0, 170.0, r)
	if spec.get("hills", false):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radii := [112.0, 118.0, 126.0, 136.0, 148.0, 162.0, 178.0, 196.0, 216.0, 238.0, 262.0, 290.0, 320.0]
		var segs := 160
		# soft patches of meadow and stubble, vineyards in autumn gold, yellow and rust on the sunny sides, darker
		# woods on the tops, bluer with distance
		var meadow := Color("93a565"); var stubble := Color("b7a86e"); var woods := Color("5f7046")
		var gold := Color("c79a45"); var yellow := Color("cdb04e"); var rust := Color("b2643a")
		var grid: Array = []
		for ri in radii.size():
			var row: Array = []
			for ai in segs + 1:
				var a := TAU * ai / segs
				var r: float = radii[ri]
				var x := cos(a) * r; var z := sin(a) * r
				var y: float = hill_y.call(x, z)
				var f := cz.get_noise_2d(x, z) * 0.5 + 0.5
				var top := Heightfield.ss(0.5, 0.85, (y - floor_y) / 42.0)
				var vine := Heightfield.ss(0.48, 0.64, f) * (1.0 - top * 0.8)
				var g := cz.get_noise_2d(x * 2.7 + 300.0, z * 2.7) * 0.5 + 0.5
				var vc := gold.lerp(yellow, Heightfield.ss(0.55, 0.75, g)).lerp(rust, Heightfield.ss(0.4, 0.2, g))
				var c := meadow.lerp(stubble, Heightfield.ss(0.3, 0.5, f)).lerp(vc, vine * 0.85)
				c = c.lerp(woods, top * 0.7)
				c = c.lerp(Color("97a8bb"), Heightfield.ss(140.0, 320.0, r) * 0.55)
				c.a = vine
				row.append([Vector3(x, y, z), c])
			grid.append(row)
		for ri in radii.size() - 1:
			for ai in segs:
				var q := [grid[ri][ai], grid[ri][ai + 1], grid[ri + 1][ai], grid[ri + 1][ai + 1]]
				for v in [q[0], q[2], q[1], q[1], q[2], q[3]]:
					st.set_color(v[1]); st.add_vertex(v[0])
		st.generate_normals()
		root.add_child(Palette.mi(st.commit(), hills_mat, Vector3.ZERO, false))
		if int(spec.get("villages", 0)) > 0: root.add_child(Palette.mi(_hill_villages(int(spec.villages), hill_y), hills_mat, Vector3.ZERO, false))
	if spec.get("alps", false):
		# a range from alps_from round to alps_to (degrees; default west-south-west to north-north-east), far out across the plain
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rn := FastNoiseLite.new(); rn.seed = 5; rn.noise_type = FastNoiseLite.TYPE_SIMPLEX; rn.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		rn.frequency = 0.45; rn.fractal_octaves = 3
		var a0 := deg_to_rad(float(spec.get("alps_from", 150.0))); var a1 := deg_to_rad(float(spec.get("alps_to", 305.0)))
		var n := 260
		# rows from the far foot up to the crest and down the near side: deep enough that the slopes read as mountains
		var radii := [480.0, 462.0, 445.0, 428.0, 412.0]
		var rows: Array = []
		for i in n + 1:
			var t := float(i) / n
			var a := lerpf(a0, a1, t)
			var ends := Heightfield.ss(0.0, 0.1, t) * Heightfield.ss(1.0, 0.88, t)   # the range rises from the haze and sinks back
			# a long white line low on the horizon, with one taller pyramid standing out (`alps_peak`, degrees)
			var peak := exp(-pow((rad_to_deg(a) - float(spec.get("alps_peak", 215.0))) / 4.0, 2.0)) * 45.0
			var crest := (42.0 + 48.0 * (rn.get_noise_1d(a * 6.0) * 0.5 + 0.5) + peak) * ends
			var shoulder := (24.0 + 22.0 * (rn.get_noise_1d(a * 9.0 + 7.0) * 0.5 + 0.5) + peak * 0.4) * ends
			rows.append([a, [0.0, crest * 0.7, crest, shoulder, 0.0]])   # heights above the floor, far foot to near foot
		for i in n:
			var A: Array = rows[i]; var B: Array = rows[i + 1]
			var p := func(row: Array, k: int) -> Array:
				var a: float = row[0]
				var y: float = floor_y + float(row[1][k]) if k > 0 and k < 4 else floor_y - 4.0
				var snow := Heightfield.ss(floor_y + 34.0, floor_y + 52.0, y)
				var c := Color("7f8fa6").lerp(Color("eef3f8"), snow)
				return [Vector3(cos(a) * radii[k], y, sin(a) * radii[k]), c]
			for band in 4:
				var q := [p.call(A, band), p.call(B, band), p.call(A, band + 1), p.call(B, band + 1)]
				for v in [q[0], q[2], q[1], q[1], q[2], q[3]]:
					st.set_color(v[1]); st.add_vertex(v[0])
		st.generate_normals()
		root.add_child(Palette.mi(st.commit(), mat, Vector3.ZERO, false))
	return root

## n small villages on the hill crests round the horizon: a cluster of plastered houses under terracotta roofs
## round a bell tower, each on the highest ground near its spot. One mesh, vertex-coloured (no vines: alpha 0).
static func _hill_villages(n: int, hill_y: Callable) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var walls := [Color("e6d6b0"), Color("d9b26c"), Color("d8a58e"), Color("cdbb98"), Color("e9dfc8")]
	var roofs := [Color("b25a3a"), Color("a5523a"), Color("bd6a45")]
	for k in n:
		# the highest point near this bearing, out among the hills
		var a0 := TAU * (k + 0.5) / n + rng.randf_range(-0.25, 0.25)
		var best := Vector3(0, -1000, 0)
		for ri in 21:
			for ai in 9:
				var r := 175.0 + ri * 5.0; var a := a0 + (ai - 4) * 0.02
				var p := Vector3(cos(a) * r, 0, sin(a) * r)
				p.y = hill_y.call(p.x, p.z)
				if p.y > best.y: best = p
		var out := Vector2(best.x, best.z).normalized()
		var side := Vector2(-out.y, out.x)
		# the same distance haze as the hills under them, so they sit on the ridge instead of floating pale above it
		var haze := Heightfield.ss(140.0, 320.0, Vector2(best.x, best.z).length()) * 0.55
		var tint := func(c: Color) -> Color: return c.darkened(0.12).lerp(Color("97a8bb"), haze)
		for h in rng.randi_range(8, 13):
			var off := side * rng.randf_range(-11.0, 11.0) + out * rng.randf_range(-6.0, 6.0)
			var x := best.x + off.x; var z := best.z + off.y
			var size := Vector3(rng.randf_range(3.0, 4.6), rng.randf_range(2.6, 4.2), rng.randf_range(3.6, 5.4))
			var base := Vector3(x, float(hill_y.call(x, z)) - 1.0, z)
			var yaw := atan2(out.x, out.y) + rng.randf_range(-0.4, 0.4) + (PI / 2.0 if rng.randf() < 0.5 else 0.0)
			_add_box(st, base, size, yaw, tint.call(walls[rng.randi() % walls.size()]))
			_add_gable(st, base + Vector3(0, size.y, 0), size.x + 0.6, size.z + 0.6, size.x * 0.32, yaw, tint.call(roofs[rng.randi() % roofs.size()]))
		# the bell tower, a little off the top
		var t := Vector3(best.x + side.x * rng.randf_range(-3.0, 3.0), 0, best.z + side.y * rng.randf_range(-3.0, 3.0))
		t.y = float(hill_y.call(t.x, t.z)) - 0.8
		var th := rng.randf_range(8.5, 11.0)
		_add_box(st, t, Vector3(2.2, th, 2.2), atan2(out.x, out.y), tint.call(Color("c99a6e") if rng.randf() < 0.5 else Color("ddd0b4")))
		_add_pyramid(st, t + Vector3(0, th, 0), 2.5, 2.2, atan2(out.x, out.y), tint.call(roofs[0]))
	return st.commit()

## One flat face (a triangle or a quad), lit from the side away from `inside`, wound clockwise from outside as
## Godot expects of a front face.
static func _add_face(st: SurfaceTool, pts: Array, inside: Vector3, col: Color) -> void:
	var c := Vector3.ZERO
	for p in pts: c += p
	c /= pts.size()
	var out := c - inside
	var p0: Vector3 = pts[0]; var p1: Vector3 = pts[1]; var p2: Vector3 = pts[2]
	if (p1 - p0).cross(p2 - p0).dot(out) > 0.0:   # counter-clockwise from outside: turn it round
		pts = pts.duplicate(); pts.reverse()
		p0 = pts[0]; p1 = pts[1]; p2 = pts[2]
	var nrm := (p2 - p0).cross(p1 - p0).normalized()   # clockwise from outside, so this points out
	var tris := [0, 1, 2] if pts.size() == 3 else [0, 1, 2, 0, 2, 3]
	for i in tris:
		st.set_normal(nrm); st.set_color(col); st.add_vertex(pts[i])

## A box standing on `base` (centre of its foot), turned by `yaw`; no floor. Colours are sRGB with alpha 0.
static func _add_box(st: SurfaceTool, base: Vector3, size: Vector3, yaw: float, col: Color) -> void:
	col.a = 0.0
	var bs := Basis(Vector3.UP, yaw)
	var hx := size.x / 2.0; var hz := size.z / 2.0
	var mid := base + Vector3(0, size.y / 2.0, 0)
	var c := [base + bs * Vector3(-hx, 0, -hz), base + bs * Vector3(hx, 0, -hz), base + bs * Vector3(hx, 0, hz), base + bs * Vector3(-hx, 0, hz)]
	var t: Array = c.map(func(v): return v + Vector3(0, size.y, 0))
	for i in 4:
		var j := (i + 1) % 4
		_add_face(st, [c[i], c[j], t[j], t[i]], mid, col.darkened(0.05 * (i % 2)))
	_add_face(st, t, mid, col.darkened(0.1))

## A gabled roof over a w x d footprint centred on `top`, ridge `h` above it, along the footprint's d axis.
static func _add_gable(st: SurfaceTool, top: Vector3, w: float, d: float, h: float, yaw: float, col: Color) -> void:
	col.a = 0.0
	var bs := Basis(Vector3.UP, yaw)
	var hw := w / 2.0; var hd := d / 2.0
	var mid := top + Vector3(0, h * 0.3, 0)
	var e := [top + bs * Vector3(-hw, 0, -hd), top + bs * Vector3(hw, 0, -hd), top + bs * Vector3(hw, 0, hd), top + bs * Vector3(-hw, 0, hd)]
	var r0 := top + bs * Vector3(0, h, -hd); var r1 := top + bs * Vector3(0, h, hd)
	_add_face(st, [e[3], e[0], r0, r1], mid, col)
	_add_face(st, [e[1], e[2], r1, r0], mid, col.darkened(0.08))
	_add_face(st, [e[0], e[1], r0], mid, col.darkened(0.15))
	_add_face(st, [e[2], e[3], r1], mid, col.darkened(0.15))

static func _add_pyramid(st: SurfaceTool, top: Vector3, w: float, h: float, yaw: float, col: Color) -> void:
	col.a = 0.0
	var bs := Basis(Vector3.UP, yaw)
	var hw := w / 2.0
	var c := [top + bs * Vector3(-hw, 0, -hw), top + bs * Vector3(hw, 0, -hw), top + bs * Vector3(hw, 0, hw), top + bs * Vector3(-hw, 0, hw)]
	var apex := top + Vector3(0, h, 0)
	for i in 4: _add_face(st, [c[i], c[(i + 1) % 4], apex], top + Vector3(0, h * 0.25, 0), col.darkened(0.06 * i))

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
