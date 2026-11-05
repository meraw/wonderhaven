class_name PlayerController
extends RefCounted
## Third-person movement: camera-relative, running, hopping, step-up and wall sliding on the shared walk model.

var character: Chibi
var walk: WalkWorld
var pos: Vector3
var yaw := 0.0
var vy := 0.0
var grounded := true
var speed := 0.0
var moving := false
var walk_speed := 4.4
var run_speed := 7.2
var riding := false   # on the bicycle (Bicycle): faster, no hopping, steadier turns, a lean into them
var lean := 0.0
var body := {"x": 0.0, "z": 0.0, "r": WalkWorld.PLAYER_RADIUS}

func _init(p_char: Chibi, p_walk: WalkWorld, x: float, z: float, p_yaw: float) -> void:
	character = p_char; walk = p_walk
	teleport(x, z, p_yaw)

func teleport(x: float, z: float, p_yaw = null) -> void:
	pos = Vector3(x, walk.surface_at(x, z).y, z); vy = 0.0
	if p_yaw != null: yaw = p_yaw
	sync()

func update(dt: float, move: Vector2, run: bool, jump: bool, cam_yaw: float, enabled: bool = true) -> void:
	if not enabled: move = Vector2.ZERO; run = false; jump = false
	if riding: jump = false
	var target := (Bicycle.SPEED if riding else (run_speed if run else walk_speed)) * minf(1.0, move.length())
	speed += (target - speed) * minf(1.0, dt * 10.0)
	var fx := -sin(cam_yaw)
	var fz := -cos(cam_yaw)
	var rx := -fz
	var rz := fx
	var dx := fx * move.y + rx * move.x
	var dz := fz * move.y + rz * move.x
	var l := sqrt(dx * dx + dz * dz)
	moving = l > 0.05
	var turn := 0.0
	if moving:
		dx /= l; dz /= l
		var before := yaw
		yaw = lerp_angle(yaw, atan2(dx, dz), 1.0 - exp(-(5.0 if riding else 14.0) * dt))
		turn = wrapf(yaw - before, -PI, PI) / maxf(dt, 1e-4)
	lean = lerpf(lean, clampf(-turn * 0.12, -0.3, 0.3) if riding else 0.0, 1.0 - exp(-6.0 * dt))
	var total := speed * dt
	var steps := maxi(1, int(ceil(total / 0.12)))
	var moved_any := false
	if moving:
		for n in steps:
			var r := walk.step_move(pos, dx * total / steps, dz * total / steps, WalkWorld.PLAYER_RADIUS, body)
			if r.moved:
				moved_any = true
				var np: Vector3 = r.pos
				pos.x = np.x; pos.z = np.z
				if grounded and np.y <= pos.y + 0.46 and np.y > pos.y: pos.y = np.y
		if not moved_any:
			speed *= 0.5
			var out := walk.unstick(pos, WalkWorld.PLAYER_RADIUS, body)   # stuck inside the edge of something: ease out of it
			if not out.is_empty(): pos.x = out.x; pos.z = out.z
	var ground: float = walk.surface_at(pos.x, pos.z, pos.y).y
	if grounded and jump: vy = 6.2; grounded = false
	if not grounded or pos.y > ground + 0.02:
		vy -= 22.0 * dt
		pos.y += vy * dt
		if pos.y <= ground: pos.y = ground; vy = 0.0; grounded = true
		else: grounded = false
	else:
		pos.y = ground; grounded = true
	sync()
	character.animate(dt, speed / walk_speed if moving else 0.0, not grounded and not riding)

func sync() -> void:
	body.x = pos.x; body.z = pos.z
	character.position = pos
	character.rotation.y = yaw
	character.rotation.z = lean

func forward() -> Vector2: return Vector2(sin(yaw), cos(yaw))
