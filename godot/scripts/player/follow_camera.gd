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
var blockers: Array = []   # AABBs (buildings) the camera rises over (or, failing that, pulls in front of)
var lift := 0.0            # extra pitch currently added to clear a building
var occluders: Array = []  # [centre: Vector3, radius: float] tree canopies and bushes the dialogue view avoids

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
		if not _avoid_blockers(focus, cam_pos).is_equal_approx(cam_pos): block += 5.0
		block += 2.0 * _foliage_hits(focus, cam_pos)
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
	var avoid := mode == "explore" or mode == "dialogue"
	# Rise over a house behind the player (fast up, slow down) rather than zooming into their face.
	var need := _lift_needed(target, cur.yaw, cur.pitch, cur.dist) if avoid and mode == "explore" else 0.0
	lift = lerpf(lift, need, 1.0 - exp(-(10.0 if need > lift else 2.0) * dt))
	var pitch_now: float = minf(1.4, cur.pitch + lift)
	var p: Vector3 = target + Vector3(sin(cur.yaw) * cos(pitch_now), sin(pitch_now), cos(cur.yaw) * cos(pitch_now)) * cur.dist
	if avoid: p = _avoid_blockers(target, p)
	var min_y := Heightfield.height(p.x, p.z) + 0.6
	if p.y < min_y: p.y = min_y
	if shake > 0.0:
		shake -= dt
		p += Vector3(randf() - 0.5, randf() - 0.5, 0) * shake * 0.3
	camera.global_position = p
	camera.look_at(target, Vector3.UP)

## How many canopies or bushes the line from a to b passes through.
func _foliage_hits(a: Vector3, b: Vector3) -> int:
	var n := 0
	var ab := b - a
	var l2 := ab.length_squared()
	for o in occluders:
		var c: Vector3 = o[0]; var r: float = o[1]
		var t := clampf((c - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
		if (a + ab * t).distance_to(c) < r: n += 1
	return n

## Smallest extra pitch (in 0.1 steps) that gives a clear view over the buildings, or 0.
func _lift_needed(from: Vector3, y: float, p: float, d: float) -> float:
	for k in 13:
		var pk := minf(1.4, p + k * 0.1)
		var to := from + Vector3(sin(y) * cos(pk), sin(pk), cos(y) * cos(pk)) * d
		if _avoid_blockers(from, to).is_equal_approx(to): return pk - p
	return 0.0

## Pulls the camera toward the target when a building sits between them. Buildings get a small margin, dropped
## when the target stands within it (a villager by their door); a target inside the walls (the workshop) skips it.
const MARGIN := 0.35
func _avoid_blockers(from: Vector3, to: Vector3) -> Vector3:
	var dir := to - from
	var len := dir.length()
	if len < 0.01: return to
	var hit := 1.0
	for b in blockers:
		var box: AABB = b
		if box.has_point(from): continue
		var grown := box.grow(MARGIN)
		var t := _ray_box(from, dir, box if grown.has_point(from) else grown)
		if t >= 0.0 and t < hit: hit = t
	if hit >= 1.0: return to
	var d := hit * len
	return from + dir / len * (d - 0.25 if d > 1.0 else d * 0.75)

## Fraction along from→from+dir where the segment first enters the box, or -1.
static func _ray_box(from: Vector3, dir: Vector3, box: AABB) -> float:
	var t0 := 0.0; var t1 := 1.0
	for a in 3:
		var o: float = from[a]; var d: float = dir[a]
		var lo: float = box.position[a]; var hi: float = box.end[a]
		if absf(d) < 0.00001:
			if o < lo or o > hi: return -1.0
			continue
		var ta := (lo - o) / d; var tb := (hi - o) / d
		if ta > tb: var tmp := ta; ta = tb; tb = tmp
		t0 = maxf(t0, ta); t1 = minf(t1, tb)
		if t0 > t1: return -1.0
	return t0

func snap() -> void:
	cur.yaw = yaw; cur.pitch = pitch; cur.dist = dist; target = focus

func move_yaw() -> float: return cur.yaw
