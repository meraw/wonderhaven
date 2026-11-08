extends Node3D

var rt
var material: ShaderMaterial
var last := INF

func level() -> float:
	return last

func _process(_dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or rt == null: return
	var st = g.get("state")
	if not st is Dictionary: return
	var y: float = rt.flood_level(float(st.time.minute))
	if absf(y - last) < 0.002: return
	last = y
	for c in get_children(): (c as Node3D).position.y = y
	if material: material.set_shader_parameter("water_y", y)
