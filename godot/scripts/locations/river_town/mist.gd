extends MeshInstance3D
## A thin mist on the water at dawn only (docs/locations/river_town.md, "Light"): a sheet just above the rivers, the
## backwater and the canals, below the floodplain and the town, so the ground hides it everywhere but over the water.
## It gathers before sunrise, lies there until about half past seven, and has burned off by half past nine.

const Y := Heightfield.WATER_Y + 0.32

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float amount = 0.0;
uniform vec4 mist_color : source_color = vec4(0.96, 0.95, 0.92, 1.0);
varying vec3 wpos;
""" + TerrainBuilder.NOISE_LIB + """
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// soft banks drifting slowly downstream, with finer wisps across them
	float n = fbm(wpos.xz * 0.06 + vec2(TIME * 0.012, TIME * 0.005)) * 0.7 + fbm(wpos.xz * 0.21 - vec2(TIME * 0.025, 0.0)) * 0.3;
	float a = smoothstep(0.32, 0.72, n) * amount * (1.0 - smoothstep(160.0, 240.0, length(wpos.xz)));
	ALBEDO = mist_color.rgb;
	ALPHA = a * 0.7;
}
"""

## How thick the mist is (0..1) at an hour of the day.
static func amount_at(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h < 4.5 or h > 9.5: return 0.0
	if h < 5.5: return smoothstep(4.5, 5.5, h)
	if h < 7.5: return 1.0
	return 1.0 - smoothstep(7.5, 9.5, h)

static func make() -> MeshInstance3D:
	var m: MeshInstance3D = load("res://scripts/locations/river_town/mist.gd").new()
	var p := PlaneMesh.new(); p.size = Vector2(520.0, 520.0)
	m.mesh = p
	var sh := Shader.new(); sh.code = SHADER
	var sm := ShaderMaterial.new(); sm.shader = sh
	sm.render_priority = -1   # under the leaves and particles
	m.material_override = sm
	m.position.y = Y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "river_town_mist"
	return m

func _process(_dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or not (g.get("state") is Dictionary): return
	var h := float(g.state.time.minute) / 60.0
	var a := amount_at(h)
	visible = a > 0.001
	if visible: (material_override as ShaderMaterial).set_shader_parameter("amount", a)
