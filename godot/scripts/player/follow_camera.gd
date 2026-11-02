class_name FollowCamera
extends RefCounted
## Orbit follow camera: drag or right stick to rotate, wheel/triggers to zoom, eases into build and dialogue views.

var camera: Camera3D
var yaw := PI * 1.5
var pitch := 0.5
var dist := 8.5
var cur := {"yaw": PI * 1.5, "pitch": 0.5, "dist": 8.5}
var target := Vector3.ZERO
var focus := Vector3.ZERO
var mode := "explore"
var limits := {"explore": [3.5, 16.0, 0.12, 1.25], "build": [6.0, 30.0, 0.55, 1.35], "dialogue": [2.5, 6.0, 0.1, 0.6]}
var shake := 0.0

func _init(cam: Camera3D) -> void: camera = cam

func set_mode(m: String) -> void:
	mode = m
	if m == "build": pitch = maxf(pitch, 0.95); dist = maxf(dist, 15.0)
	if m == "explore": pitch = clampf(pitch, 0.25, 0.75); dist = clampf(dist, 5.0, 11.0)

func frame_dialogue(a: Vector3, b: Vector3) -> void:
	focus = (a + b) / 2.0 + Vector3(0, 0.9, 0)
	pitch = 0.28; dist = 4.6
	# Try a few angles around the pair and keep the one whose view isn't blocked by a hill.
	var base := atan2(b.x - a.x, b.z - a.z) + PI / 2.0
	var best := base + 0.6
	var best_block := INF
	for off in [0.6, -0.6, 1.1, -1.1, 0.2, -0.2, PI - 0.6, PI + 0.6]:
		var y: float = base + off
		var cam_pos := focus + Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch)) * dist
		var block := 0.0
		for k in range(1, 9):
			var p := focus.lerp(cam_pos, k / 8.0)
			block = maxf(block, Heightfield.height(p.x, p.z) + 0.3 - p.y)
		if block < best_block - 0.05: best_block = block; best = y
	yaw = best

func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx; pitch += dy

func zoom(steps: float) -> void: dist *= pow(1.12, steps)

func clamp_limits() -> void:
	var l: Array = limits.get(mode, limits.explore)
	dist = clampf(dist, l[0], l[1]); pitch = clampf(pitch, l[2], l[3])

func update(dt: float, follow: Vector3) -> void:
	clamp_limits()
	if mode != "dialogue" and mode != "build": focus = follow + Vector3(0, 1.0, 0)
	var k := 1.0 - exp(-10.0 * dt)
	target = target.lerp(focus, k)
	cur.yaw = lerp_angle(cur.yaw, yaw, 1.0 - exp(-12.0 * dt))
	cur.pitch = lerpf(cur.pitch, pitch, 1.0 - exp(-8.0 * dt))
	cur.dist = lerpf(cur.dist, dist, 1.0 - exp(-8.0 * dt))
	var p: Vector3 = target + Vector3(sin(cur.yaw) * cos(cur.pitch), sin(cur.pitch), cos(cur.yaw) * cos(cur.pitch)) * cur.dist
	var min_y := Heightfield.height(p.x, p.z) + 0.6
	if p.y < min_y: p.y = min_y
	if shake > 0.0:
		shake -= dt
		p += Vector3(randf() - 0.5, randf() - 0.5, 0) * shake * 0.3
	camera.global_position = p
	camera.look_at(target, Vector3.UP)

func snap() -> void:
	cur.yaw = yaw; cur.pitch = pitch; cur.dist = dist; target = focus

func move_yaw() -> float: return cur.yaw
