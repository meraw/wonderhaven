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

var camera: Camera3D
var yaw := PI * 1.5
var pitch := 0.5
var dist := 8.5
var cur := {"yaw": PI * 1.5, "pitch": 0.5, "dist": 8.5}
var target := Vector3.ZERO
var focus := Vector3.ZERO
var mode := "explore"
var limits := {"explore": [3.5, 16.0, 0.12, 1.25], "build": [4.0, 40.0, 0.3, 1.5], "dialogue": [2.5, 6.0, 0.1, 0.6], "action": [3.0, 9.0, 0.12, 0.9]}
var shake := 0.0
var blockers: Array = []   # AABBs (buildings) the camera stays in front of
var occluders: Array = []  # [centre: Vector3, radius: float] tree canopies and bushes the dialogue view avoids
var rooms: Array = []      # AABBs of rooms you can walk into (inside walls, up to the wall tops); see Props.camera_rooms
var room_doors: Array = [] # each room's doorway, in the same order (Props.camera_room_doors)
var col_dist := 8.5        # where the camera actually sits after collision
var blend := 0.0           # seconds left of a slower blend after a mode change
var indoor_k := 0.0        # 0 outdoors .. 1 fully in the indoor cutaway view
var indoor_pitch := 0.95   # smoothed pitch the cutaway uses
var lifted := 0.5
var frame_shift := Vector2.ZERO
var _shift := Vector2.ZERO
var _views := {}
var aim := Vector3.ZERO
var _off := Vector3.ZERO
var _t := 0.0
var _near = null
var _last_follow := Vector3.INF
var _vel := Vector3.ZERO
var _last_yaw := PI * 1.5
var _yaw_rate := 0.0
var _clear_for := 0.0
var _lift_vel := 0.0
var _fat := 0.0
var cinema := {}           # a cutscene's own shot ({pos, look}): while set, the camera sits there instead (BusIntro)

const MARGIN := 0.35       # how far the camera stays from walls
const MIN_DIST := 0.15     # closest the camera comes: at the player's head, never inside a wall (the player is hidden this close; see game.gd)
const INDOOR_PITCH := 0.95 # indoors the view looks down at least this steeply (radians)
const INDOOR_DIST := [6.0, 9.0]
const DOOR_TOP := 2.1      # a doorway's height: the camera can look out through it below this
const LIFT_MAX := 1.5
const LIFT_RISE := 9.0
const LIFT_FALL := 3.0
const LIFT_KEEP := 0.55
const LIFT_NEAR := 3.5
const LIFT_HIGH := [0.9, 1.2]
const KEEP_OFF := 0.95
const PROBE_REACH := 0.3
const AHEAD := [0.35, 0.7]
const PROBES := [Vector2(0, 0), Vector2(0.28, 0), Vector2(-0.28, 0), Vector2(0, 0.22), Vector2(0, -0.18)]

func _init(cam: Camera3D) -> void: camera = cam

func set_mode(m: String) -> void:
	if m == mode: return
	blend = 0.7
	if mode in ["explore", "build"]: _views[mode] = [pitch, dist]
	mode = m
	if _views.has(m):
		pitch = _views[m][0]; dist = _views[m][1]
	elif m == "build":
		pitch = maxf(pitch, 0.95); dist = maxf(dist, 15.0)
	elif m == "explore":
		pitch = clampf(pitch, 0.25, 0.75); dist = clampf(dist, 5.0, 11.0)

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
	if not cinema.is_empty():
		camera.global_position = cinema.pos; camera.look_at(cinema.look, Vector3.UP)
		return
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
	var indoor_pv: float = cur.pitch
	if indoor_k > 0.0:
		var want := maxf(maxf(cur.pitch, INDOOR_PITCH), wall_clear_pitch(target, cur.yaw))
		indoor_pitch = lerpf(indoor_pitch, want, 1.0 - exp(-6.0 * dt)) if room_top > -INF else indoor_pitch
		indoor_pv = indoor_pitch
		dv = lerpf(cur.dist, clampf(cur.dist, INDOOR_DIST[0], INDOOR_DIST[1]), indoor_k)
	else:
		indoor_pitch = maxf(cur.pitch, INDOOR_PITCH)
	var colliding: bool = mode in ["explore", "dialogue", "action", "build"]
	if colliding: _near = _blockers_near(target, maxf(dv, cur.dist) + 6.0)
	var off_walls := _wall_push(target, cur.yaw) if mode == "explore" and room_top == -INF else Vector3.ZERO
	_off = _off.lerp(off_walls, 1.0 - exp(-8.0 * dt))
	aim = target + _off
	var looking_ahead := false
	if mode == "explore":
		_track_motion(dt, follow)
		looking_ahead = room_top == -INF and (_vel.length() > 0.3 or absf(_yaw_rate) > 0.15)
	var want_lift: float = cur.pitch
	var ahead: Array = []
	if mode == "build" and cur.pitch < LIFT_MAX: want_lift = _least_pitch(aim, cur.yaw, cur.pitch, dv, dv)
	if mode == "explore" and room_top == -INF:
		want_lift = lift_pitch(aim, cur.yaw, cur.pitch, dv)
		if looking_ahead:
			for secs in AHEAD:
				var y: float = cur.yaw + clampf(_yaw_rate * secs, -0.9, 0.9)
				var at: Vector3 = target + _vel * secs
				at += _wall_push(at, y)
				var p_at := lift_pitch(at, y, cur.pitch, dv)
				ahead.append([at, y, p_at, secs])
				want_lift = maxf(want_lift, p_at)
	lifted = maxf(lifted, cur.pitch)
	if want_lift > lifted:
		_clear_for = 0.0
		_spring_lift(want_lift, LIFT_RISE, dt)
	else:
		_clear_for += dt
		if _clear_for > 0.5: _spring_lift(want_lift, LIFT_FALL, dt)
		else: _spring_lift(lifted, LIFT_RISE, dt)
	if not mode in ["explore", "build"]: lifted = cur.pitch; _lift_vel = 0.0
	pv = lerpf(lifted, indoor_pv, indoor_k)
	var dir := _dir(cur.yaw, pv)
	var allowed: float = dv
	var soft: float = dv
	if colliding:
		allowed = clear_distance(aim, dir, dv, mode != "build")
		soft = allowed
		for a in ahead:
			var by_then: float = 1.0 - (1.0 + LIFT_RISE * a[3]) * exp(-LIFT_RISE * a[3])
			soft = minf(soft, clear_distance(a[0], _dir(a[1], lerpf(pv, maxf(pv, want_lift), by_then)), dv))
	if soft < col_dist: col_dist = minf(lerpf(col_dist, soft, 1.0 - exp(-9.0 * dt)), allowed)
	else: col_dist = settle(col_dist, soft, dt)
	_near = null
	var p: Vector3 = aim + dir * col_dist
	if colliding: p = _outside_walls(aim, p)
	var ground := maxf(Heightfield.height(p.x, p.z), Heightfield.WATER_Y) + 0.45
	if p.y < ground: p.y = ground
	if shake > 0.0:
		shake = maxf(0.0, shake - dt)
		p += Vector3(sin(_t * 41.0), sin(_t * 33.0 + 1.3), 0.0) * shake * 0.12
	camera.global_position = p
	camera.look_at(aim, Vector3.UP)
	_shift = _shift.lerp(frame_shift if mode == "build" else Vector2.ZERO, 1.0 - exp(-6.0 * dt))
	if _shift.length() > 0.0005:
		var half := p.distance_to(aim) * tan(deg_to_rad(camera.fov) / 2.0)
		var size := camera.get_viewport().get_visible_rect().size if camera.is_inside_tree() else Vector2(16, 9)
		camera.global_position -= camera.global_basis.x * _shift.x * half * size.x / maxf(size.y, 1.0) + camera.global_basis.y * _shift.y * half

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

func lift_pitch(origin: Vector3, y: float, base: float, d: float) -> float:
	if base >= LIFT_MAX: return base
	var near := _least_pitch(origin, y, base, d, minf(d, maxf(d * LIFT_KEEP, LIFT_NEAR)))
	var high := smoothstep(LIFT_HIGH[0], LIFT_HIGH[1], near)
	if high <= 0.0: return near
	return lerpf(near, _least_pitch(origin, y, near, d, d), high)

func _least_pitch(origin: Vector3, y: float, base: float, d: float, keep: float) -> float:
	if _built_clear(origin, _dir(y, base), d) >= keep - 0.01: return base
	if _built_clear(origin, _dir(y, LIFT_MAX), d) < keep - 0.01: return LIFT_MAX
	var lo := base
	var hi := LIFT_MAX
	for i in 4:
		var mid := (lo + hi) / 2.0
		if _built_clear(origin, _dir(y, mid), d) >= keep - 0.01: hi = mid
		else: lo = mid
	return hi

func _wall_push(at: Vector3, y: float) -> Vector3:
	var push := Vector3.ZERO
	var toward := Vector3(sin(y), 0.0, cos(y))
	for b in (blockers if _near == null else _near):
		var box: AABB = b
		if at.y < box.position.y or at.y > box.end.y or box.grow(-0.35).has_point(at): continue
		var away := Vector3(at.x - clampf(at.x, box.position.x, box.end.x), 0.0, at.z - clampf(at.z, box.position.z, box.end.z))
		var gap := away.length()
		if gap >= KEEP_OFF: continue
		if gap < 0.001:
			var sides := [at.x - box.position.x, box.end.x - at.x, at.z - box.position.z, box.end.z - at.z]
			var normals := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
			var nearest := 0
			for i in 4:
				if sides[i] < sides[nearest]: nearest = i
			away = normals[nearest]
			gap = -sides[nearest]
		away = away.normalized()
		push += away * (KEEP_OFF - gap) * clampf(-2.0 * away.dot(toward), 0.0, 1.0)
	return push.limit_length(KEEP_OFF + 0.4)

func _spring_lift(to: float, omega: float, dt: float) -> void:
	var c1 := lifted - to
	var c2 := _lift_vel + omega * c1
	var e := exp(-omega * dt)
	lifted = to + (c1 + c2 * dt) * e
	_lift_vel = (c2 - omega * (c1 + c2 * dt)) * e

func _track_motion(dt: float, follow: Vector3) -> void:
	var step := follow - _last_follow if _last_follow != Vector3.INF else Vector3.ZERO
	_last_follow = follow
	var v := step / maxf(dt, 0.001)
	v.y = 0.0
	if v.length() > 12.0: v = Vector3.ZERO; _vel = Vector3.ZERO
	_vel = _vel.lerp(v, 1.0 - exp(-10.0 * dt))
	var turn := angle_difference(_last_yaw, cur.yaw) / maxf(dt, 0.001)
	_last_yaw = cur.yaw
	if absf(turn) > 8.0: turn = 0.0; _yaw_rate = 0.0
	_yaw_rate = lerpf(_yaw_rate, turn, 1.0 - exp(-10.0 * dt))

func _blockers_near(origin: Vector3, reach: float) -> Array:
	var out: Array = []
	for b in blockers:
		var box: AABB = b
		var dx := maxf(maxf(box.position.x - origin.x, origin.x - box.end.x), 0.0)
		var dz := maxf(maxf(box.position.z - origin.z, origin.z - box.end.z), 0.0)
		if dx * dx + dz * dz <= reach * reach: out.append(box)
	return out

static func _dir(y: float, p: float) -> Vector3: return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))

## How far the camera can sit from `origin` along `dir` (up to `d`) without a building or the ground in the way,
## using a small bundle of rays so a thin edge can't flicker it in and out.
func clear_distance(origin: Vector3, dir: Vector3, d: float, ground: bool = true) -> float:
	var right := dir.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.001 else Vector3.RIGHT
	var up := right.cross(dir).normalized()
	var best := d
	for pr in PROBES:
		var reach: Vector3 = dir * d + right * pr.x + up * pr.y
		var len := reach.length()
		if len < 0.001: continue
		best = minf(best, _ray_clear(origin, origin, reach / len, len) * d / len)
	if ground: best = minf(best, _ground_clear(origin, dir, d))
	return clampf(best, minf(MIN_DIST, d), d)

func _built_clear(origin: Vector3, dir: Vector3, d: float) -> float:
	_fat = PROBE_REACH
	var free := _ray_clear(origin, origin, dir, d)
	_fat = 0.0
	return clampf(free, minf(MIN_DIST, d), d)

func _ground_clear(o: Vector3, dir: Vector3, d: float) -> float:
	var s := 0.5
	while s <= d:
		var q := o + dir * s
		if q.y - 0.18 * s / d < Heightfield.height(q.x, q.z) + 0.35: return s - 0.4
		s += 0.5
	return d

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
	var boxes: Array = blockers if _near == null else _near
	for b in boxes:
		var box: AABB = b
		var walls := box.grow(-0.35)
		if walls.has_point(pivot): continue   # standing inside (the workshop): that building doesn't block
		var inside_pad := box.has_point(pivot)
		var t := _ray_box(o, seg, walls if inside_pad else box.grow(_fat))
		if t < 0.0: continue
		var stop := t
		if not inside_pad:
			var grown := box.grow(MARGIN)
			if not grown.has_point(pivot): stop = _ray_box(o, seg, grown)
		free = minf(free, stop * d - 0.15)
	for b in boxes:
		var grown: AABB = (b as AABB).grow(MARGIN)
		if grown.has_point(pivot) or not grown.has_point(o + dir * free): continue
		var t := _ray_box(o, seg, grown)
		if t >= 0.0: free = minf(free, t * d - 0.15)
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
	_last_follow = Vector3.INF; _vel = Vector3.ZERO; _last_yaw = yaw; _yaw_rate = 0.0; _clear_for = 0.0; _lift_vel = 0.0
	var outdoors := mode == "explore" and room_top_at(target) == -INF
	_off = _wall_push(target, yaw) if outdoors else Vector3.ZERO
	aim = target + _off
	lifted = lift_pitch(aim, yaw, pitch, dist) if outdoors else pitch
	indoor_k = 1.0 if mode == "explore" and room_top_at(target) > -INF else 0.0
	if indoor_k > 0.0: indoor_pitch = maxf(maxf(pitch, INDOOR_PITCH), wall_clear_pitch(target, yaw)); col_dist = clampf(dist, INDOOR_DIST[0], INDOOR_DIST[1])

func move_yaw() -> float: return cur.yaw
