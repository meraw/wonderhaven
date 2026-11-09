extends Node3D

const Models := preload("models.gd")
const RUNS := [[605, 895]]
const FESTA_RUN := [1110, 1200]
const SAIL := 12.0
const FAR := Vector3(70.0, 0.0, 150.0)
const OFF_COVE := Vector3(19.5, 0.0, 76.0)
const OFF_COVE_YAW := 0.35

var boat: Node3D
var last_minute := -1.0

static func runs(flags: Dictionary) -> Array:
	var out: Array = RUNS.duplicate()
	if flags.get("olive_village_festa_ready", false) or flags.get("olive_village_festa_night", false): out.append(FESTA_RUN)
	return out

static func berth(flags: Dictionary) -> Vector3:
	var moored: Vector3 = Data.location_script("olive_village").get_script_constant_map().MOORED
	return moored if flags.get("olive_village_jetty_done", false) else OFF_COVE

static func berth_yaw(flags: Dictionary) -> float:
	return PI if flags.get("olive_village_jetty_done", false) else OFF_COVE_YAW

static func facing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

static func at(minute: float, flags: Dictionary) -> Dictionary:
	var home := berth(flags)
	var home_yaw := berth_yaw(flags)
	for r in runs(flags):
		var dep := float(r[0])
		var arr := float(r[1])
		if minute >= dep and minute < dep + SAIL:
			var u := smoothstep(0.0, 1.0, (minute - dep) / SAIL)
			return {"pos": home.lerp(FAR, u), "yaw": lerp_angle(home_yaw, facing(home, FAR), minf(1.0, u * 4.0)), "shown": true, "moving": true}
		if minute >= dep + SAIL and minute < arr - SAIL:
			return {"pos": FAR, "yaw": facing(home, FAR), "shown": false, "moving": false}
		if minute >= arr - SAIL and minute < arr:
			var v := smoothstep(0.0, 1.0, (minute - (arr - SAIL)) / SAIL)
			return {"pos": FAR.lerp(home, v), "yaw": lerp_angle(facing(FAR, home), home_yaw, maxf(0.0, v * 4.0 - 3.0)), "shown": true, "moving": true}
	return {"pos": home, "yaw": home_yaw, "shown": true, "moving": false}

static func horn_due(prev_minute: float, minute: float, flags: Dictionary) -> bool:
	if prev_minute < 0.0 or minute < prev_minute or minute - prev_minute > 3.0: return false
	for r in runs(flags):
		for m in [float(r[0]), float(r[1])]:
			if prev_minute < m and minute >= m: return true
	return false

func _ready() -> void:
	name = "olive_village_ferry"
	boat = Models.ferry()
	add_child(boat)

func _process(_dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or not (g.get("state") is Dictionary): return
	var minute := float(g.state.time.minute)
	var flags: Dictionary = g.state.flags
	var s := at(minute, flags)
	boat.visible = s.shown
	boat.position = Vector3(s.pos.x, Heightfield.WATER_Y - 0.15, s.pos.z)
	boat.rotation.y = float(s.yaw)
	if horn_due(last_minute, minute, flags) and g.get("audio") != null and g.get("player") != null:
		var d := Vector2(g.player.pos.x - s.pos.x, g.player.pos.z - s.pos.z).length()
		var vol := clampf(1.0 - d / 140.0, 0.25, 1.0) * 0.42
		for k in 2:
			g.audio.play("horn", 57, vol, -1, k * 1.1)
			g.audio.play("horn", 61, vol, -1, k * 1.1)
	last_minute = minute
