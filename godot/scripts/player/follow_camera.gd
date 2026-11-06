class_name FollowCamera
extends RefCounted
## Third-person orbit camera. Drag, Q/Z or the right stick rotate it; the wheel or triggers zoom; it blends
## smoothly into the build and dialogue views.
##
## Stability rules:
## - The pivot follows the player smoothly: steadily sideways, more gently up and down, so steps and hops don't
##   bob the view.
## - Mouse look is nearly direct, with a little smoothing to remove jitter.
## - Collision is checked along several rays (centre plus four offsets) against buildings and the ground. The
##   camera pulls in at once when something comes between, so it never shows the inside of a wall, and eases back
##   out slowly so it doesn't pop.
## - The camera never changes its own pitch, except indoors: inside a room you can walk into it looks down over
##   the walls through the faded roof (a cutaway), rising just enough to clear the wall behind you.

var camera: Camera3D
var yaw := PI * 1.5
var pitch := 0.5
var dist := 8.5
var cur := {"yaw": PI * 1.5, "pitch": 0.5, "dist": 8.5}
var target := Vector3.ZERO
var focus := Vector3.ZERO
var mode := "explore"
var limits := {"explore": [3.5, 16.0, 0.12, 1.25], "build": [6.0, 30.0, 0.55, 1.35], "dialogue": [2.5, 6.0, 0.1, 0.6], "action": [3.0, 9.0, 0.12, 0.9]}
var shake := 0.0
var blockers: Array = []   # AABBs (buildings) the camera stays in front of
var occluders: Array = []  # [centre: Vector3, radius: float] tree canopies and bushes the dialogue view avoids
var rooms: Array = []      # AABBs of rooms you can walk into (inside walls, up to the wall tops); see Props.camera_rooms
var room_doors: Array = [] # each room's doorway, in the same order (Props.camera_room_doors)
var col_dist := 8.5        # where the camera actually sits after collision
var blend := 0.0           # seconds left of a slower blend after a mode change
var indoor_k := 0.0        # 0 outdoors .. 1 fully in the indoor cutaway view
var indoor_pitch := 0.95   # smoothed pitch the cutaway uses
var _t := 0.0

const MARGIN := 0.35       # how far the camera stays from walls
const MIN_DIST := 0.15     # closest the camera comes: at the player's head, never inside a wall (the player is hidden this close; see game.gd)
const INDOOR_PITCH := 0.95 # indoors the view looks down at least this steeply (radians)
const INDOOR_DIST := [6.0, 9.0]
const DOOR_TOP := 2.1      # a doorway's height: the camera can look out through it below this
const PROBES := [Vector2(0, 0), Vector2(0.28, 0), Vector2(-0.28, 0), Vector2(0, 0.22), Vector2(0, -0.18)]

func _init(cam: Camera3D) -> void: camera = cam

func set_mode(m: String) -> void:
	if m != mode: blend = 0.7
	mode = m
	if m == "build": pitch = maxf(pitch, 0.95); dist = maxf(dist, 15.0)
	if m == "explore": pitch = clampf(pitch, 0.25, 0.75); dist = clampf(dist, 5.0, 11.0)

func frame_dialogue(a: Vector3, b: Vector3) -> void:
	focus = (a + b) / 2.0 + Vector3(0, 0.9, 0)
	pitch = 0.28; dist = 4.6
	yaw = _clear_side_yaw(a, b)

## Gathering minigames: a side view of you and the tree, rock or water, a little farther out, with the pair left of
## centre so the minigame panel on the right doesn't cover them.
func frame_action(a: Vector3, b: Vector3) -> void:
	focus = (a + b) / 2.0 + Vector3(0, 0.9, 0)
	pitch = 0.3; dist = 6.4
	yaw = _clear_side_yaw(a, b)
	focus += Vector3(cos(yaw), 0.0, -sin(yaw)) * 1.5   # the screen's right: moving the focus there shifts the scene left

## Of a few angles round a pair, the one with the clearest view (no hill, house or tree in the way).
func _clear_side_yaw(a: Vector3, b: Vector3) -> float:
	var base := atan2(b.x - a.x, b.z - a.z) + PI / 2.0
	var best := base + 0.6
	var best_block := INF
	for off in [0.6, -0.6, 1.1, -1.1, 0.2, -0.2, PI - 0.6, PI + 0.6]:
		var y: float = base + off
		var dir := Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch))
		var cam_pos := focus + dir * dist
		var block := (dist - clear_distance(focus, dir, dist)) * 2.0
		block += 2.0 * _foliage_hits(focus, cam_pos)
		if block < best_block - 0.05: best_block = block; best = y
	return best

func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx; pitch += dy

func zoom(steps: float) -> void: dist *= pow(1.12, steps)

func clamp_limits() -> void:
	var l: Array = limits.get(mode, limits.explore)
	dist = clampf(dist, l[0], l[1]); pitch = clampf(pitch, l[2], l[3])

func update(dt: float, follow: Vector3) -> void:
	_t += dt
	clamp_limits()
	if mode == "explore": focus = follow + Vector3(0, 1.0, 0)
	blend = maxf(0.0, blend - dt)
	var slow := blend > 0.0
	var kxz := 1.0 - exp(-(5.0 if slow else 14.0) * dt)
	var ky := 1.0 - exp(-(4.0 if slow else 7.0) * dt)
	target = Vector3(lerpf(target.x, focus.x, kxz), lerpf(target.y, focus.y, ky), lerpf(target.z, focus.z, kxz))
	var kr := 1.0 - exp(-(6.0 if slow else 28.0) * dt)
	cur.yaw = lerp_angle(cur.yaw, yaw, kr)
	cur.pitch = lerpf(cur.pitch, pitch, kr)
	cur.dist = lerpf(cur.dist, dist, 1.0 - exp(-(5.0 if slow else 12.0) * dt))
	# Indoors: blend into a cutaway that looks down over the walls instead of hugging the back of the head.
	var room_top := room_top_at(target) if mode == "explore" else -INF
	indoor_k = lerpf(indoor_k, 1.0 if room_top > -INF else 0.0, 1.0 - exp(-4.0 * dt))
	if indoor_k < 0.002: indoor_k = 0.0
	var pv: float = cur.pitch
	var dv: float = cur.dist
	if indoor_k > 0.0:
		var want := maxf(maxf(cur.pitch, INDOOR_PITCH), wall_clear_pitch(target, cur.yaw))
		indoor_pitch = lerpf(indoor_pitch, want, 1.0 - exp(-6.0 * dt)) if room_top > -INF else indoor_pitch
		pv = lerpf(cur.pitch, indoor_pitch, indoor_k)
		dv = lerpf(cur.dist, clampf(cur.dist, INDOOR_DIST[0], INDOOR_DIST[1]), indoor_k)
	else:
		indoor_pitch = maxf(cur.pitch, INDOOR_PITCH)
	var dir := _dir(cur.yaw, pv)
	var allowed: float = dv
	if mode in ["explore", "dialogue", "action"]: allowed = clear_distance(target, dir, dv)
	col_dist = settle(col_dist, allowed, dt)
	var p: Vector3 = target + dir * col_dist
	if mode in ["explore", "dialogue", "action"]: p = _outside_walls(target, p)
	var ground := maxf(Heightfield.height(p.x, p.z), Heightfield.WATER_Y) + 0.45
	if p.y < ground: p.y = ground
	if shake > 0.0:
		shake = maxf(0.0, shake - dt)
		p += Vector3(sin(_t * 41.0), sin(_t * 33.0 + 1.3), 0.0) * shake * 0.12
	camera.global_position = p
	camera.look_at(target, Vector3.UP)

## Collision distance filter: jump in at once, ease out slowly (exponentially, and never faster than 3.5 m/s,
## so a low frame rate can't make it lurch).
static func settle(current: float, allowed: float, dt: float) -> float:
	if allowed < current: return allowed
	return minf(lerpf(current, allowed, 1.0 - exp(-2.5 * dt)), current + 3.5 * dt)

## The wall-top height of the walk-in room around `p`, or -INF when `p` isn't in one.
func room_top_at(p: Vector3) -> float:
	for rm in rooms:
		var room: AABB = rm
		if room.has_point(p): return room.end.y
	return -INF

## Pitch the view needs, looking from `origin` towards yaw `y`, to pass over the wall of the room it is in
## (with a little headroom), capped just short of straight down.
func wall_clear_pitch(origin: Vector3, y: float) -> float:
	var need := 0.0
	var hd := Vector3(sin(y), 0.0, cos(y)) * 50.0
	for rm in rooms:
		var room: AABB = rm
		if not room.has_point(origin): continue
		var to_wall := _exit_sides(origin, hd, room) * 50.0
		need = maxf(need, atan2(room.end.y + 0.4 - origin.y, maxf(to_wall - 0.1, 0.1)))
	return minf(need, 1.52)

static func _dir(y: float, p: float) -> Vector3: return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))

## How far the camera can sit from `origin` along `dir` (up to `d`) without a building or the ground in the way,
## using a small bundle of rays so a thin edge can't flicker it in and out.
func clear_distance(origin: Vector3, dir: Vector3, d: float) -> float:
	var right := dir.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.001 else Vector3.RIGHT
	var up := right.cross(dir).normalized()
	var best := d
	for pr in PROBES:
		best = minf(best, _ray_clear(origin, origin + right * pr.x + up * pr.y, dir, d))
	return clampf(best, minf(MIN_DIST, d), d)

func _ray_clear(pivot: Vector3, o: Vector3, dir: Vector3, d: float) -> float:
	var free := d
	var seg := dir * d
	# inside a room: stay within its walls, unless the line of sight to the player leaves over the top (the roof
	# fades away). Measured on the centre line: the probes are for building edges outside.
	for ri in rooms.size():
		var room: AABB = rooms[ri]
		if not room.has_point(pivot): continue
		var te := _exit_sides(pivot, seg, room)
		if te < 1.0 and pivot.y + seg.y * te < room.end.y and not _out_the_door(ri, pivot, seg):
			free = minf(free, te * d - 0.3)
	for b in blockers:
		var box: AABB = b
		if box.has_point(pivot): continue   # standing inside (the workshop): that building doesn't block
		if o != pivot and box.has_point(o): continue   # a side probe that starts inside the walls: the centre ray covers them
		var grown := box.grow(MARGIN)
		# close to a wall the margin would swallow a side probe's start and snap the camera onto your head, looking away
		# from the wall or not: there, the bare walls count
		var t := _ray_box(o, seg, box if grown.has_point(pivot) or grown.has_point(o) else grown)
		if t >= 0.0: free = minf(free, t * d - 0.15)
	var s := 0.5
	while s <= d:
		var q := o + dir * s
		if q.y < Heightfield.height(q.x, q.z) + 0.35: free = minf(free, s - 0.4); break
		s += 0.5
	return free

## Does the line from `pivot` along `seg` leave room `ri` through its doorway (with a little room either side)? Then
## the camera can stay outside behind you as you walk in, instead of snapping onto your head.
func _out_the_door(ri: int, pivot: Vector3, seg: Vector3) -> bool:
	if ri >= room_doors.size(): return false
	var dr: Dictionary = room_doors[ri]
	var a := 0 if dr.axis == "x" else 2   # the axis the line crosses the door's wall along
	var o := 2 if a == 0 else 0
	if absf(seg[a]) < 0.0001: return false
	var t: float = (float(dr.at) - pivot[a]) / seg[a]
	if t < 0.0 or t > 1.0: return false
	var q := pivot + seg * t
	var floor_y: float = (rooms[ri] as AABB).position.y + 1.0   # (a room's box starts a metre under its floor)
	return q[o] > float(dr.g0) + 0.12 and q[o] < float(dr.g1) - 0.12 and q.y < floor_y + DOOR_TOP

## Last safety net: if the camera point is inside a building's walls (and the player isn't), bring it back along
## the line to the player until it is outside.
func _outside_walls(pivot: Vector3, p: Vector3) -> Vector3:
	for b in blockers:
		var walls: AABB = (b as AABB).grow(-0.35)
		if walls.has_point(p) and not walls.has_point(pivot):
			var t := _ray_box(pivot, p - pivot, walls)
			if t >= 0.0: p = pivot + (p - pivot) * maxf(0.0, t - 0.02)
	return p

## True when something stands between `from` and `to`.
func blocked(from: Vector3, to: Vector3) -> bool:
	var v := to - from
	return v.length() > 0.01 and clear_distance(from, v.normalized(), v.length()) < v.length() - 0.01

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

## Fraction along from→from+dir where the segment leaves the box through a side wall (x or z), or 2 if it doesn't.
static func _exit_sides(from: Vector3, dir: Vector3, box: AABB) -> float:
	var t := 2.0
	for a in [0, 2]:
		var d: float = dir[a]
		if absf(d) < 0.00001: continue
		var bound: float = box.end[a] if d > 0.0 else box.position[a]
		var ta: float = (bound - from[a]) / d
		if ta >= 0.0: t = minf(t, ta)
	return t

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
	cur.yaw = yaw; cur.pitch = pitch; cur.dist = dist; target = focus; col_dist = dist; blend = 0.0
	indoor_k = 1.0 if mode == "explore" and room_top_at(target) > -INF else 0.0
	if indoor_k > 0.0: indoor_pitch = maxf(maxf(pitch, INDOOR_PITCH), wall_clear_pitch(target, yaw)); col_dist = clampf(dist, INDOOR_DIST[0], INDOOR_DIST[1])

func move_yaw() -> float: return cur.yaw
