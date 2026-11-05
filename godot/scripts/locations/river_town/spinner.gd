extends Node3D
## Turns while a machine target in the world is fed (the pumping house's flywheel once a waterwheel drives it).

var target := ""
var axis := Vector3.RIGHT
var speed := 2.4

func _process(dt: float) -> void:
	var g = get_tree().current_scene
	if g == null: return
	var mech = g.get("mech")
	if mech is Dictionary and mech.get("fed", {}).get(target, false): rotate_object_local(axis, dt * speed)
