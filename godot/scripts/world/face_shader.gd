class_name FaceShader
## The chibi face, painted onto the front of the head sphere by a shader: crisp at any size, flush with the head,
## and driven by a few parameters (blink, eye mode, mouth, look direction) instead of separate meshes.

const CODE := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 skin : source_color = vec4(0.97, 0.81, 0.66, 1.0);
uniform vec4 eye_color : source_color = vec4(0.23, 0.16, 0.12, 1.0);
uniform vec4 line_color : source_color = vec4(0.2, 0.12, 0.1, 1.0);
uniform vec4 brow_color : source_color = vec4(0.35, 0.22, 0.15, 1.0);
uniform vec4 mouth_color : source_color = vec4(0.62, 0.22, 0.27, 1.0);
uniform vec4 blush_color : source_color = vec4(1.0, 0.55, 0.6, 1.0);
uniform int style = 1;          // 0 glossy eyes, 1 bean (dot) eyes
uniform int eye_mode = 0;       // 0 open, 1 happy arcs, 2 closed line, 3 wide, 4 sleepy (half-lidded)
uniform float blink = 0.0;      // 0 open .. 1 shut
uniform int mouth = 0;          // 0 smile, 1 grin, 2 o, 3 calm, 4 cat, 5 sad
uniform vec2 look = vec2(0.0);  // pupil offset
uniform bool sparkle = false;
uniform int eye_style = 0;      // dot eyes: 0 round dots, 1 sparkly, 2 big & shiny
uniform float brow_raise = 0.0;
uniform float highlight = 0.0;  // interaction highlight glow
uniform float eye_scale = 1.0;
varying vec3 op;

float ellipse(vec2 p, vec2 r) { return (length(p / r) - 1.0) * min(r.x, r.y); }
float arc(vec2 p, vec2 c, float r, float th) { return abs(length(p - c) - r) - th; }
float fill(float d) { float w = max(fwidth(d), 0.0015); return 1.0 - smoothstep(-w, w, d); }

void vertex() { op = VERTEX; }

void fragment() {
	vec3 n = normalize(op);
	vec3 col = skin.rgb;
	vec3 emit = vec3(0.0);
	if (n.z > 0.15) {
		vec2 p = n.xy;
		// blush
		for (int s = -1; s <= 1; s += 2) {
			float b = length((p - vec2(float(s) * 0.56, -0.24)) / vec2(0.17, 0.09));
			col = mix(col, blush_color.rgb, (1.0 - smoothstep(0.4, 1.0, b)) * 0.45);
		}
		for (int s = -1; s <= 1; s += 2) {
			float sx = float(s);
			vec2 e = p - vec2(sx * 0.34, -0.04);
			vec2 r = (style == 0 ? vec2(0.12, 0.165) : vec2(0.07, 0.095)) * eye_scale;
			if (eye_mode == 3) r *= 1.15;
			float open = 1.0 - blink;
			if (eye_mode == 4) open = min(open, 0.5);
			bool lid = eye_mode == 1 || eye_mode == 2 || open < 0.12;
			if (eye_mode == 1) {
				// happy: upward arcs  ^ ^
				float d = arc(e, vec2(0.0, -0.05), r.x * 0.9, 0.022);
				d = max(d, -(e.y + 0.02));
				col = mix(col, line_color.rgb, fill(d));
			} else if (lid) {
				// closed: a soft downward curve
				float d = arc(e, vec2(0.0, 0.1), r.x * 1.25, 0.02);
				d = max(d, e.y + 0.02 - 0.0);
				d = max(d, abs(e.x) - r.x * 1.05);
				col = mix(col, line_color.rgb, fill(d));
			} else {
				vec2 rr = vec2(r.x, r.y * open);
				vec2 ec = e - vec2(0.0, -r.y * (1.0 - open));
				float d = ellipse(ec, rr);
				if (style == 0) {
					// glossy iris: dark at the top, bright toward the bottom, darker pupil, bold upper lash line
					float g = clamp((ec.y + rr.y) / (2.0 * rr.y), 0.0, 1.0);
					vec3 iris = mix(eye_color.rgb * 1.35 + 0.06, eye_color.rgb * 0.45, g);
					float pupil = ellipse(ec - look * 0.04 - vec2(0.0, -0.01), vec2(0.06, 0.085) * vec2(1.0, open));
					iris = mix(iris, line_color.rgb * 0.8, fill(pupil) * 0.85);
					float rim = fill(d) * (1.0 - fill(d + 0.018));
					iris = mix(iris, line_color.rgb, rim);
					float lash = fill(max(abs(d + 0.006) - 0.016, -(ec.y - rr.y * 0.15)));
					col = mix(col, iris, fill(d));
					col = mix(col, line_color.rgb, lash);
					// outer lash flick
					vec2 fl = ec - vec2(sx * rr.x * 0.95, rr.y * 0.55);
					float flick = ellipse(vec2(fl.x * 0.7 - sx * fl.y * 0.6, fl.y), vec2(0.035, 0.012));
					col = mix(col, line_color.rgb, fill(flick) * step(0.3, open));
					// highlights
					float h1 = length(ec - vec2(-sx * 0.035 + look.x * 0.02, rr.y * 0.38)) - 0.042 * open;
					float h2 = length(ec - vec2(sx * 0.045, -rr.y * 0.45)) - 0.018 * open;
					float hl = max(fill(h1), fill(h2) * 0.9);
					if (sparkle) hl = max(hl, fill(length(ec - vec2(-sx * 0.05, -rr.y * 0.1)) - 0.012));
					col = mix(col, vec3(1.0), hl);
					emit += vec3(0.25) * hl;
				} else {
					// dot eyes, in three looks that are easy to tell apart
					float k = eye_style == 2 ? 1.55 : (eye_style == 1 ? 1.22 : 1.0);
					vec2 er = vec2(r.x, r.y) * k;
					if (eye_mode == 3) er *= 1.12;
					vec2 sr = vec2(er.x, er.y * open);
					vec2 ecc = e - vec2(0.0, -er.y * (1.0 - open));
					float dd = ellipse(ecc, sr);
					vec3 ink = mix(line_color.rgb, eye_color.rgb, eye_style == 2 ? 0.8 : 0.45);
					if (eye_style == 2) {
						// big & shiny: coloured iris, darker at the top, with a lash line
						float g = clamp((ecc.y + sr.y) / (2.0 * sr.y), 0.0, 1.0);
						ink = mix(eye_color.rgb * 1.25 + 0.05, eye_color.rgb * 0.45, g);
						col = mix(col, ink, fill(dd));
						col = mix(col, line_color.rgb, fill(ellipse(ecc - vec2(0.0, -sr.y * 0.1), sr * vec2(0.45, 0.5))) * 0.85);
						col = mix(col, line_color.rgb, fill(max(abs(dd + 0.006) - 0.013, -(ecc.y - sr.y * 0.25))));
					} else {
						col = mix(col, ink, fill(dd));
					}
					// highlights
					float hs = er.x * (eye_style == 2 ? 0.34 : 0.3);
					float h1 = length(ecc - vec2(-sx * er.x * 0.28, sr.y * 0.42)) - hs * open;
					float hl = fill(h1);
					if (eye_style >= 1) hl = max(hl, fill(length(ecc - vec2(sx * er.x * 0.32, -sr.y * 0.4)) - er.x * 0.14 * open));
					if (eye_style == 1) {
						// a four-point star glint
						vec2 sp = ecc - vec2(-sx * er.x * 0.22, sr.y * 0.3);
						float star = min(abs(sp.x) * 0.22 + abs(sp.y), abs(sp.y) * 0.22 + abs(sp.x)) - er.x * 0.16;
						hl = max(hl, fill(star));
					}
					col = mix(col, vec3(1.0), hl);
					emit += vec3(0.25) * hl;
					// sleepy: a heavy lid across the top of the half-open eye
					if (eye_mode == 4) col = mix(col, line_color.rgb, fill(max(abs(ecc.y - sr.y + 0.004) - 0.014, abs(ecc.x) - er.x * 1.2)));
				}
			}
			// brow: a short soft arc
			vec2 bp = p - vec2(sx * 0.34, 0.22 + brow_raise * 0.06);
			float bd = arc(bp, vec2(0.0, -0.18), 0.2, 0.017);
			bd = max(bd, abs(bp.x) - 0.1);
			bd = max(bd, -(bp.y + 0.06));   // top of the ring only
			col = mix(col, brow_color.rgb, fill(bd));
		}
		// mouth
		vec2 m = p - vec2(0.0, -0.33);
		float md = 1.0;
		vec3 mc = line_color.rgb;
		if (mouth == 0) { md = max(arc(m, vec2(0.0, 0.08), 0.115, 0.018), m.y - 0.02); }
		else if (mouth == 1) {
			md = max(ellipse(m - vec2(0.0, 0.01), vec2(0.11, 0.09)), m.y - 0.01);
			mc = mouth_color.rgb;
			float tongue = ellipse(m - vec2(0.0, -0.07), vec2(0.06, 0.035));
			col = mix(col, mc, fill(md));
			col = mix(col, vec3(1.0, 0.55, 0.6), fill(max(tongue, md)));
			md = abs(md + 0.008) - 0.008;
			mc = line_color.rgb;
		}
		else if (mouth == 2) { md = ellipse(m, vec2(0.045, 0.06)); mc = mouth_color.rgb; col = mix(col, mc, fill(md)); md = abs(md + 0.006) - 0.007; mc = line_color.rgb; }
		else if (mouth == 3) { md = max(abs(m.y + 0.005 - m.x * m.x * 2.4) - 0.015, abs(m.x) - 0.075); }
		else if (mouth == 4) { md = min(max(arc(m, vec2(-0.052, 0.035), 0.052, 0.016), m.y - 0.02), max(arc(m, vec2(0.052, 0.035), 0.052, 0.016), m.y - 0.02)); }
		else if (mouth == 5) { md = max(arc(m, vec2(0.0, -0.1), 0.09, 0.016), -(m.y + 0.04)); }
		col = mix(col, mc, fill(md));
	}
	ALBEDO = col;
	EMISSION = emit + vec3(1.0, 0.85, 0.55) * highlight * 0.35;
	ROUGHNESS = 1.0;
	RIM = 0.25;
	RIM_TINT = 0.8;
}
"""

static var _shader: Shader

static func material() -> ShaderMaterial:
	if _shader == null: _shader = Shader.new(); _shader.code = CODE
	var m := ShaderMaterial.new(); m.shader = _shader
	return m
