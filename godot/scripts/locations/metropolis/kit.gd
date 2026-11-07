extends RefCounted
## Toriano's building kit: painted façades, hipped tile roofs, and merged meshes for small parts (balconies,
## awnings, railings). A city block is a box whose windows, shutters, cornices and shopfronts are painted by
## FACADE_SHADER from its world position, so hundreds of windows cost nothing, line up across a block and light up
## after dark (docs/GRAPHICS.md: detail lives in colour, not relief). Everything here is static helpers.

const P := preload("res://scripts/world/palette.gd")
const Props := preload("res://scripts/world/props.gd")

## Façade styles (the shader's `style`).
const PLAIN := 0      # shuttered windows, shopfronts on the ground floor
const ARCHED := 1     # round-headed windows and arcades (the Galleria, the opera house)
const GOTHIC := 2     # tall pointed windows and buttress lines in pale marble (the Duomo)
const BRICK := 3      # red brick with few small windows and a merlon band (the castle)
const STONE := 4      # grey stone, great arched openings (the station)
const BLANK := 5      # backdrop: windows only, softer, no shopfronts

const FACADE_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 wall : source_color = vec4(0.85, 0.66, 0.36, 1.0);
uniform vec4 shutter : source_color = vec4(0.27, 0.38, 0.27, 1.0);
uniform vec4 base_col : source_color = vec4(0.56, 0.54, 0.51, 1.0);
uniform float base_y = 0.3;
uniform float ground_h = 4.0;
uniform float floor_h = 3.2;
uniform float bay = 3.2;
uniform float top_y = 15.0;
uniform float seed = 0.0;
uniform int style = 0;
uniform float shops = 1.0;      // 0: no shopfronts (a wall at street level)
uniform float alpha = 1.0;      // < 1 while you're in a room beneath (dithered, like the fading roofs)
global uniform vec4 world_weather;   // x sunlit, y night, z wet, w clouds
global uniform float world_snow;     // the finale's snow on the cornices and flat roofs
varying vec3 wp;
varying vec3 wn;
float hq(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hq(i), hq(i + vec2(1, 0)), f.x), mix(hq(i + vec2(0, 1)), hq(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
// A rounded (or pointed) window head: is (x, y) inside an opening of half-width hw whose straight sides rise to yt?
float opening(float x, float y, float hw, float y0, float yt, float pointed) {
	if (abs(x) > hw || y < y0) return 0.0;
	if (y < yt) return 1.0;
	float r = hw * (1.0 + pointed);
	float cx = pointed > 0.0 ? (x > 0.0 ? x - r + hw : x + r - hw) : x;
	return step(length(vec2(cx, y - yt)), r) * step(y, yt + hw * (1.0 + pointed * 1.6));
}
void fragment() {
	float night = world_weather.y;
	float wet = world_weather.z;
	vec3 c = wall.rgb;
	vec3 glow = vec3(0.0);
	float fine = 1.0 - smoothstep(0.03, 0.09, length(fwidth(wp.xz)) + length(fwidth(wp.y)));
	if (abs(wn.y) > 0.5) {   // tops and undersides: plain
		c *= wn.y > 0.0 ? 0.82 : 0.6;
		if (wn.y > 0.0) c = mix(c, vec3(0.88, 0.91, 0.95), world_snow * 0.8);
	} else {
		vec2 t2 = normalize(vec2(-wn.z, wn.x));
		float u = dot(wp.xz, t2) + seed * 7.0;
		float v = wp.y - base_y;
		float h = top_y - base_y;
		// plaster: soft blotches, streaks of rain stain under the cornice, a cooler shade near the ground
		c *= 0.9 + 0.14 * vnoise(vec2(u, v) * 0.35) + 0.05 * vnoise(vec2(u, v) * 2.3) * fine;
		c *= 1.0 - 0.07 * smoothstep(0.6, 1.0, vnoise(vec2(u * 0.9, v * 0.05))) * smoothstep(h - 4.0, h - 0.5, v);
		if (style == 3) {   // brick: courses and a few darker bricks
			float row = floor(v / 0.18); float bx = fract((u + mod(row, 2.0) * 0.14) / 0.28);
			c *= 0.88 + 0.16 * hq(vec2(floor((u + mod(row, 2.0) * 0.14) / 0.28), row));
			c = mix(c, c * 0.7, (step(fract(v / 0.18), 0.12) + step(bx, 0.07)) * fine * 0.8);
		}
		if (style == 2) c *= 0.97 + 0.05 * sin(v * 0.7 + vnoise(vec2(u, v) * 0.5) * 4.0);   // marble veins
		bool ground = v < ground_h;
		if (ground && style != 2 && style != 3) {
			// granite plinth and ground floor
			c = mix(c, base_col.rgb * (0.9 + 0.12 * vnoise(vec2(u, v) * 3.0)), style == 5 ? 0.4 : 0.85);
			c *= mix(1.0, 0.94 + 0.12 * hq(floor(vec2(u, v) * 9.0)), fine * 0.6);
			float bw = bay * 1.5;
			float cell = floor(u / bw); float f = fract(u / bw) - 0.5;
			float kind = hq(vec2(cell, seed + 3.0));
			if (style == 4) {   // the station's great arches
				float a = opening(f * bw, v, bw * 0.36, 0.0, ground_h * 0.55, 0.0);
				c = mix(c, vec3(0.12, 0.12, 0.13), a);
				glow += a * vec3(1.0, 0.75, 0.45) * 0.35 * night;
			} else if (shops > 0.5 && style != 5) {
				float o = opening(f * bw, v, bw * 0.33, 0.25, ground_h - (style == 1 ? 1.4 : 0.8), style == 1 ? 0.0 : -1.0);
				vec3 shop = kind > 0.55 ? vec3(0.16, 0.18, 0.2) : vec3(0.42, 0.43, 0.44) * (0.85 + 0.25 * step(0.5, fract(v * 6.0)));   // glass or a roller shutter
				float frame = o * (1.0 - opening(f * bw, v, bw * 0.33 - 0.08, 0.33, ground_h - (style == 1 ? 1.48 : 0.88), style == 1 ? 0.0 : -1.0));
				c = mix(c, shop, o);
				c = mix(c, vec3(0.28, 0.22, 0.16), frame);
				float lit = step(0.55, kind) * (0.35 + 0.65 * night) * step(hq(vec2(cell, 9.0)), 0.8);
				glow += o * (1.0 - frame) * lit * vec3(1.0, 0.78, 0.46) * 0.5;
			}
			c = mix(c, c * 0.78, smoothstep(0.35, 0.0, v));   // damp at the foot of the wall
		} else if (v < h - 0.9 && style != 3) {
			float fv = (v - ground_h) / floor_h;
			float fl = floor(fv); float fy = fract(fv);
			float cu = u / bay; float ci = floor(cu); float fx = fract(cu) - 0.5;
			vec2 id = vec2(ci, fl) + seed;
			float lit = step(0.62, hq(id + 5.0)) * smoothstep(0.2, 0.8, night);
			if (style == 2) {   // tall pointed windows between buttresses, two floors high
				float fv2 = v / (floor_h * 2.2); float fy2 = fract(fv2);
				float wdw = opening(fx * bay, fy2 * floor_h * 2.2, bay * 0.16, floor_h * 0.5, floor_h * 1.5, 0.6);
				c = mix(c, vec3(0.32, 0.36, 0.52), wdw * 0.85);
				glow += wdw * vec3(1.0, 0.8, 0.5) * 0.25 * night;
				c *= 1.0 - 0.12 * step(0.44, abs(fx)) * fine;   // buttress lines
			} else {
				float y0 = floor_h * 0.2; float yt = floor_h * (style == 1 ? 0.62 : 0.8);
				float wdw = opening(fx * bay, fy * floor_h, bay * 0.17, y0, yt, style == 1 ? 0.0 : -1.0);
				float sill = step(abs(fx * bay), bay * 0.22) * step(abs(fy * floor_h - y0 + 0.05), 0.07);
				// shutters: open beside the window, or closed over it
				float closed = step(0.72, hq(id + 11.0)) * (1.0 - lit);
				float side = step(bay * 0.17, abs(fx * bay)) * step(abs(fx * bay), bay * 0.33) * step(y0, fy * floor_h) * step(fy * floor_h, yt);
				vec3 glass = mix(vec3(0.18, 0.21, 0.26), vec3(0.5, 0.58, 0.68), 0.25 * (1.0 - night));
				glass = mix(glass, vec3(1.0, 0.82, 0.55), lit * 0.6);
				c = mix(c, glass, wdw);
				float slats = 0.85 + 0.15 * step(0.5, fract(fy * floor_h * 9.0));
				c = mix(c, shutter.rgb * slats, (side * (1.0 - closed) + wdw * closed) * (style == 5 ? 0.6 : 1.0));
				c = mix(c, c * 1.15 + 0.04, sill);
				glow += wdw * (1.0 - closed) * lit * vec3(1.0, 0.72, 0.4) * 0.55;
				// string course at each floor
				c = mix(c, wall.rgb * 1.12 + 0.03, step(fy * floor_h, 0.18) * 0.9);
			}
		}
		if (style == 3) {   // the castle's few small windows and its battlements band
			float fx = fract(u / 6.0) - 0.5;
			float w = opening(fx * 6.0, v, 0.45, h * 0.45, h * 0.55, 0.0);
			c = mix(c, vec3(0.15, 0.12, 0.11), w);
		}
		// cornice under the eaves: a pale band with a shadowed lip
		float cv = h - v;
		c = mix(c, wall.rgb * 1.1 + 0.05, step(cv, 0.9) * step(0.35, cv));
		c = mix(c, c * 0.62, step(cv, 0.35) * step(0.15, cv));
		c *= 1.0 - 0.22 * wet * (1.0 - smoothstep(0.0, 3.0, v));   // rain darkens the walls from the foot
	}
	if (alpha < 1.0 && fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) >= alpha) discard;
	ALBEDO = c;
	EMISSION = glow;
	ROUGHNESS = 1.0;
}
"""

static var _shader: Shader
static var _vc_mat: StandardMaterial3D

## A façade material. opts: shutter, base, ground_h, floor_h, bay, style, seed, shops, base_y.
static func facade(wall: Color, top_y: float, opts: Dictionary = {}) -> ShaderMaterial:
	if _shader == null: _shader = Shader.new(); _shader.code = Palette.shader_code(FACADE_SHADER, 0.85)
	var m := ShaderMaterial.new(); m.shader = _shader
	m.set_shader_parameter("wall", wall)
	m.set_shader_parameter("top_y", top_y)
	m.set_shader_parameter("shutter", opts.get("shutter", Color("4a6447")))
	m.set_shader_parameter("base_col", opts.get("base", Color("8f8a82")))
	m.set_shader_parameter("base_y", float(opts.get("base_y", 0.3)))
	m.set_shader_parameter("ground_h", float(opts.get("ground_h", 4.0)))
	m.set_shader_parameter("floor_h", float(opts.get("floor_h", 3.2)))
	m.set_shader_parameter("bay", float(opts.get("bay", 3.2)))
	m.set_shader_parameter("style", int(opts.get("style", PLAIN)))
	m.set_shader_parameter("seed", float(opts.get("seed", 0.0)))
	m.set_shader_parameter("shops", float(opts.get("shops", 1.0)))
	return m

## One material for merged parts that carry their own colours (balconies, awnings, rails).
static func vc_mat() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = P.unique_mat(Color.WHITE)
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.vertex_color_is_srgb = true
	return _vc_mat

## Collects coloured boxes and wedges into one mesh (one draw call for all of a building's small parts).
class Merge:
	var st := SurfaceTool.new()
	var count := 0
	func _init() -> void: st.begin(Mesh.PRIMITIVE_TRIANGLES)
	## A box centred at c, size s, turned ry around the vertical.
	func box(c: Vector3, s: Vector3, col: Color, ry: float = 0.0) -> void:
		var b := Basis(Vector3.UP, ry)
		var h := s / 2.0
		var faces := [[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
			[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
			[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)]]
		for f in faces:
			var n: Vector3 = f[0]; var a: Vector3 = f[1]; var bb: Vector3 = f[2]
			var corners := []
			for sgn in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				corners.append(c + b * (n * h + a * h * sgn[0] + bb * h * sgn[1]))
			# keep the winding facing out
			var nn: Vector3 = b * n
			var tri := [0, 1, 2, 0, 2, 3]
			if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(nn) > 0.0: tri = [0, 2, 1, 0, 3, 2]
			for i in tri:
				st.set_color(col); st.set_normal(nn); st.add_vertex(corners[i])
		count += 1
	## A triangle facing away from `center` (front faces wind clockwise in Godot, as in box()).
	func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - center) > 0.0:
			var t := b; b = c; c = t; n = -n
		var normal := -n.normalized()
		for v in [a, b, c]: st.set_color(col); st.set_normal(normal); st.add_vertex(v)
	## A square pyramid (a spire's top) on a base centred at c, half-width r, height h.
	func pyramid(c: Vector3, r: float, h: float, col: Color) -> void:
		var top := c + Vector3(0, h, 0)
		var q := [c + Vector3(-r, 0, -r), c + Vector3(r, 0, -r), c + Vector3(r, 0, r), c + Vector3(-r, 0, r)]
		var mid := c + Vector3(0, h * 0.3, 0)
		for i in 4: _tri(q[i], top, q[(i + 1) % 4], col, mid)
		count += 1
	## An upright prism with `sides` faces (a round tower, a drum), centred at c's base, radius r, height h.
	func cyl(c: Vector3, r: float, h: float, col: Color, sides: int = 12, cap: bool = true) -> void:
		for i in sides:
			var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
			var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r); var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
			var up := Vector3(0, h, 0)
			var mid := c + Vector3(0, h / 2.0, 0)
			_tri(p0, p1 + up, p1, col, mid); _tri(p0, p0 + up, p1 + up, col, mid)
			if cap: _tri(c + up, p1 + up, p0 + up, col, c)
		count += 1
	## A cone (a spire, a tent roof) on a base centred at c.
	func cone(c: Vector3, r: float, h: float, col: Color, sides: int = 10) -> void:
		var top := c + Vector3(0, h, 0)
		var mid := c + Vector3(0, h * 0.3, 0)
		for i in sides:
			var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
			_tri(c + Vector3(cos(a0) * r, 0, sin(a0) * r), top, c + Vector3(cos(a1) * r, 0, sin(a1) * r), col, mid)
		count += 1
	## A gable (a pediment, a church front's peak): a triangle w wide and h high, depth d, facing +z, base centred at c.
	func gable(c: Vector3, w: float, h: float, d: float, col: Color, ry: float = 0.0) -> void:
		var b := Basis(Vector3.UP, ry)
		var f := [Vector3(-w / 2.0, 0, d / 2.0), Vector3(w / 2.0, 0, d / 2.0), Vector3(0, h, d / 2.0)]
		var k := [Vector3(-w / 2.0, 0, -d / 2.0), Vector3(w / 2.0, 0, -d / 2.0), Vector3(0, h, -d / 2.0)]
		var t := func(v: Vector3) -> Vector3: return c + b * v
		var mid: Vector3 = t.call(Vector3(0, h * 0.3, 0))
		_tri(t.call(f[0]), t.call(f[1]), t.call(f[2]), col, mid); _tri(t.call(k[1]), t.call(k[0]), t.call(k[2]), col, mid)
		for e in [[0, 2], [2, 1]]:
			_tri(t.call(f[e[0]]), t.call(k[e[1]]), t.call(f[e[1]]), col, mid); _tri(t.call(f[e[0]]), t.call(k[e[0]]), t.call(k[e[1]]), col, mid)
		count += 1
	func node(mat: Material, name: String = "parts") -> MeshInstance3D:
		var m := MeshInstance3D.new(); m.name = name
		if count == 0: return m
		m.mesh = st.commit(); m.material_override = mat
		return m

## A low hipped roof over a w x d plan (centred, eaves at y = 0), rise metres to the ridge, oh overhang.
static func hip_roof(w: float, d: float, rise: float, oh: float = 0.4) -> ArrayMesh:
	var W := w / 2.0 + oh; var D := d / 2.0 + oh
	var r := minf(W, D)
	var a := Vector3(-W, 0, -D); var b := Vector3(W, 0, -D); var c := Vector3(W, 0, D); var e := Vector3(-W, 0, D)
	var long_x := W >= D
	var r0 := Vector3(-W + r, rise, 0) if long_x else Vector3(0, rise, -D + r)
	var r1 := Vector3(W - r, rise, 0) if long_x else Vector3(0, rise, D - r)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: Array = []
	if long_x: tris = [[a, b, r1], [a, r1, r0], [c, e, r0], [c, r0, r1], [b, c, r1], [e, a, r0]]
	else: tris = [[b, c, r1], [b, r1, r0], [e, a, r0], [e, r0, r1], [a, b, r0], [c, e, r1]]
	for t in tris:
		# front faces wind clockwise seen from outside (above): cross product pointing down
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
		if n.y > 0.0: t = [t[0], t[2], t[1]]; n = -n
		var normal := -n.normalized()
		for v in t: st.set_normal(normal); st.add_vertex(v)
	return st.commit()

## A railing of upright bars along x from -len/2 to len/2 at the origin: top rail, bottom rail, bars.
static func railing(m: Merge, c: Vector3, length: float, ry: float, col: Color, h: float = 1.0) -> void:
	var b := Basis(Vector3.UP, ry)
	m.box(c + b * Vector3(0, h, 0), Vector3(length, 0.06, 0.06), col, ry)
	m.box(c + b * Vector3(0, 0.12, 0), Vector3(length, 0.05, 0.05), col, ry)
	var n := maxi(2, int(length / 0.22))
	for i in n + 1:
		m.box(c + b * Vector3(-length / 2.0 + length * i / n, h / 2.0 + 0.06, 0), Vector3(0.03, h - 0.1, 0.03), col, ry)

const STREET := 0.3
const SHUTTERS := ["4a6447", "3f5a52", "6b4e33", "5b6d5a", "4d5c6a"]
const AWNINGS := ["8a2f2f", "2f5d3a", "2f4a6b", "b0752a", "6b2f5d"]
const TERRACOTTA := "b5653a"

## An ordinary city block: painted façade, a stone cornice, a low tile roof (or a flat one with a parapet), and on
## some blocks iron balconies and shop awnings. Deterministic from the block's position.
static func block(b: Dictionary, style: int = PLAIN) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.get("h", 15.0))
	var wall := Color(String(b.get("wall", "#d9a85b")))
	var seed := absf(float(b.x) * 0.37 + float(b.z) * 0.71)
	var hsh := func(k: float) -> float: return fposmod(sin(seed * 12.9898 + k * 78.233) * 43758.5453, 1.0)
	var shutter := Color(SHUTTERS[int(hsh.call(1.0) * SHUTTERS.size()) % SHUTTERS.size()])
	var y0 := float(b.get("y", STREET))   # a block can stand on a raised floor; its windows still line up with the street's
	var body := MeshInstance3D.new(); body.name = "walls"
	var bm := BoxMesh.new(); bm.size = Vector3(w, h, d); body.mesh = bm
	body.position.y = h / 2.0
	body.material_override = facade(wall, y0 + h, {"shutter": shutter, "style": style, "seed": seed, "shops": float(b.get("shops", 1.0)) if y0 < STREET + 0.5 else 0.0,
		"bay": float(b.get("bay", 3.0 + hsh.call(2.0) * 0.6))})
	g.add_child(body)
	var parts := Merge.new()
	var stone := Color("d9d2c4")
	cornice(parts, w, d, h, stone, b.get("flat", false) or style == BLANK, not b.get("roof_walk", false))
	if style != BLANK:
		# balconies on the first floor of the long sides, on about half the blocks
		if hsh.call(3.0) > 0.45:
			var iron := Color("2e2b28")
			for s in [-1, 1]:
				var bays := int(w / 3.2)
				for i in bays:
					if hsh.call(10.0 + i) < 0.5: continue
					var x := -w / 2.0 + (i + 0.5) * w / bays
					var y := 4.0 + 3.2 * 0.2
					parts.box(Vector3(x, y, s * (d / 2.0 + 0.45)), Vector3(1.6, 0.14, 0.9), stone)
					railing(parts, Vector3(x, y + 0.07, s * (d / 2.0 + 0.88)), 1.6, 0.0, iron, 0.9)
		# shop awnings over some street-level openings
		if float(b.get("shops", 1.0)) > 0.5 and hsh.call(4.0) > 0.4:
			var col := Color(AWNINGS[int(hsh.call(5.0) * AWNINGS.size()) % AWNINGS.size()])
			for s in [-1, 1]:
				var n := int(w / 4.8)
				for i in n:
					if hsh.call(20.0 + i + s) < 0.45: continue
					var x := -w / 2.0 + (i + 0.5) * w / n
					parts.box(Vector3(x, 3.3, s * (d / 2.0 + 0.55)), Vector3(3.0, 0.08, 1.2), col if i % 2 == 0 else col.lightened(0.15))
	g.add_child(parts.node(vc_mat()))
	if style != BLANK and not b.get("flat", false):
		var roof := MeshInstance3D.new(); roof.name = "roof"
		roof.mesh = hip_roof(w + 0.3, d + 0.3, clampf(minf(w, d) * 0.12, 1.2, 3.0), 0.2)
		roof.material_override = Props.roof_material(Color(String(b.get("roof", TERRACOTTA))))
		roof.position.y = h + 0.4
		g.add_child(roof)
	return g

## [mesh, solid material, see-through copy] for each mesh under `nodes`, for game.gd's fading roofs: façades fade
## through their own dither (`alpha`), other materials through the roof shader's dither (as `Props.fade_parts` does:
## the compatibility renderer draws alpha-hashed surfaces solid).
static func fade_parts(nodes: Array) -> Array:
	var parts: Array = []
	for nd in nodes:
		var meshes: Array = nd.find_children("*", "MeshInstance3D", true, false)
		if nd is MeshInstance3D: meshes.append(nd)
		for m in meshes:
			var solid: Material = m.material_override
			if solid == null: continue
			var faded: Material = solid.duplicate()
			if faded is StandardMaterial3D:
				faded = Props.roof_material((solid as StandardMaterial3D).albedo_color, true)
				(faded as ShaderMaterial).set_shader_parameter("plain", true)
			elif faded is ShaderMaterial and (solid as ShaderMaterial).get_shader_parameter("color") != null:
				faded = Props.roof_material((solid as ShaderMaterial).get_shader_parameter("color"), true)
			parts.append([m, solid, faded])
	return parts

## A room you can walk into, set in a city building: the storey below it (a flat upstairs stands on the cellars),
## its walls with the doorway (the same rectangles the collision uses), the storeys above it up to the building's
## top, and its roof. The storeys above and the roof fade while you're inside.
static func room(b: Dictionary, style: int = PLAIN) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var y0 := float(b.get("y", STREET))
	var wall := Color(String(b.get("wall", "#d9a85b")))
	var seed := absf(float(b.x) * 0.37 + float(b.z) * 0.71)
	var mat := facade(wall, y0 + h, {"style": style, "seed": seed, "shops": 0.0})
	var storey := minf(3.2, h)
	if y0 > STREET + 0.5:   # the cellar storey beneath an upstairs flat
		var below := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w, y0 - STREET, d); below.mesh = bm
		below.position.y = -(y0 - STREET) / 2.0; below.material_override = mat; g.add_child(below)
	for r in Interiors.walls(b):
		var wm := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(r.maxX - r.minX, storey, r.maxZ - r.minZ); wm.mesh = bx
		wm.position = Vector3((r.minX + r.maxX) / 2.0 - b.x, storey / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z); wm.material_override = mat
		g.add_child(wm)
	var di := Interiors.door_info(b)
	var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
	var lw := Vector3(Interiors.DOOR_W, storey - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, storey - Interiors.DOOR_H, Interiors.DOOR_W)
	var parts := Merge.new()
	parts.box(Vector3(dc.x, (storey + Interiors.DOOR_H) / 2.0, dc.y), lw, wall)                     # over the doorway
	parts.box(Vector3(0, 0.02, 0), Vector3(w - 0.3, 0.04, d - 0.3), Color("b98a5e"))                   # floorboards
	var dl := Vector3(di.out.x, 0, di.out.y)
	var jamb := Color("4a3a2c")
	for sgn in [-1, 1]:   # a dark door frame, so the doorway reads from the street
		var along: Vector3 = Vector3(di.along.x, 0, di.along.y) * (Interiors.DOOR_W / 2.0 + 0.05) * sgn
		parts.box(Vector3(dc.x, Interiors.DOOR_H / 2.0, dc.y) + along + dl * 0.13, Vector3(0.1, Interiors.DOOR_H, 0.1), jamb)
	g.add_child(parts.node(vc_mat()))
	var over: Array = []
	if h > storey + 0.2:
		var up := MeshInstance3D.new(); var ub := BoxMesh.new(); ub.size = Vector3(w, h - storey, d); up.mesh = ub
		up.position.y = storey + (h - storey) / 2.0; up.material_override = mat.duplicate(); g.add_child(up); over.append(up)
	var top := Merge.new()
	cornice(top, w, d, h, Color("d9d2c4"), b.get("flat", false))
	var cap := top.node(vc_mat(), "cornice"); g.add_child(cap); over.append(cap)
	if not b.get("flat", false):
		var roof := MeshInstance3D.new(); roof.name = "roof"
		roof.mesh = hip_roof(w + 0.3, d + 0.3, clampf(minf(w, d) * 0.12, 1.2, 3.0), 0.2)
		roof.material_override = Props.roof_material(Color(String(b.get("roof", TERRACOTTA))))
		roof.position.y = h + 0.4; g.add_child(roof); over.append(roof)
	g.set_meta("fade_parts", fade_parts(over))
	return g

## The stone cornice round the top of a building's walls, and on a flat roof the roof itself: grey tar paper with a
## little parapet, a chimney pot or two.
static func cornice(m: Merge, w: float, d: float, h: float, stone: Color, flat: bool, chimneys: bool = true) -> void:
	var t := 0.45
	for s in [-1, 1]:
		m.box(Vector3(0, h + 0.2, s * (d / 2.0 + 0.25 - t / 2.0)), Vector3(w + 0.5, 0.4, t), stone)
		m.box(Vector3(s * (w / 2.0 + 0.25 - t / 2.0), h + 0.2, 0), Vector3(t, 0.4, d + 0.5 - 2.0 * t), stone)
	if flat:
		m.box(Vector3(0, h + 0.05, 0), Vector3(w - 0.1, 0.1, d - 0.1), Color("6f6a64"))
		var n := (int(w * d / 120.0) + 1) if chimneys else 0
		for i in n:
			var fx := fposmod(sin(w * 3.1 + i * 7.7) * 437.0, 1.0) - 0.5; var fz := fposmod(sin(d * 5.3 + i * 3.9) * 291.0, 1.0) - 0.5
			m.box(Vector3(fx * (w - 3.0), h + 0.7, fz * (d - 3.0)), Vector3(0.7, 1.3, 0.7), Color("b3826a"))   # chimney stacks
