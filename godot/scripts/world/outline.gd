class_name Outline
## Screen-space ink lines: finds depth and normal edges and darkens them, giving shapes crisp, storybook outlines.
## Lines take the colour of what they outline (darkened), so they read as soft ink, not black wire. Forward+ only
## (it needs the normal buffer); call create() and add the result as a child of the camera.

const CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform float width = 1.0;
uniform float strength = 0.85;
uniform float fade_start = 35.0;
uniform float fade_end = 90.0;
uniform float water_y = -0.4;

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
vec3 nrm(vec2 uv) { return texture(normal_tex, uv).xyz * 2.0 - 1.0; }

void fragment() {
	vec2 px = width / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float dc = lin_depth(uv, INV_PROJECTION_MATRIX);
	vec3 nc = nrm(uv);
	float de = 0.0; float ne = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		float d = lin_depth(uv + offs[i], INV_PROJECTION_MATRIX);
		// only the nearer side of an edge draws the line, so lines hug the front object
		de = max(de, (d - dc) / max(dc, 0.5));
		ne = max(ne, 1.0 - dot(nc, nrm(uv + offs[i])));
	}
	float edge = max(smoothstep(0.04, 0.12, de), smoothstep(0.35, 0.7, ne) * 0.8);
	edge *= 1.0 - smoothstep(fade_start, fade_end, dc);
	// no lines on things under the water surface (the water itself is drawn later and has no depth)
	vec4 vp = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz / vp.w, 1.0)).xyz;
	edge *= smoothstep(water_y - 0.05, water_y + 0.05, wp.y);
	vec3 c = texture(screen_tex, uv).rgb;
	ALBEDO = c * 0.38;
	ALPHA = edge * strength;
}
"""

const LAYER := 1 << 3   # kept off layer 1 so the dialogue portrait camera does not draw it

static func supported() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

static func create() -> MeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(2, 2)
	var sh := Shader.new(); sh.code = CODE
	var m := ShaderMaterial.new(); m.shader = sh
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = LAYER
	mi.name = "Outline"
	return mi
