class_name SunHold
extends RefCounted

const HOLD_DEG := 6.0
const JUMP_DEG := 1.0
const CATCH_UP_DEG_PER_S := 6.0
const SETTLED_DEG := 0.05
const STILL_MOVE_M_PER_S := 0.05
const STILL_TURN_DEG_PER_S := 0.5

var shown := Vector3.ZERO
var last_target := Vector3.ZERO
var catching := false

static func view_moving(before: Transform3D, after: Transform3D, dt: float) -> bool:
	if dt <= 0.0: return false
	var moved := before.origin.distance_to(after.origin) / dt
	var turned := rad_to_deg(before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())) / dt
	return moved > STILL_MOVE_M_PER_S or turned > STILL_TURN_DEG_PER_S

func step(target: Vector3, moving: bool, dt: float) -> Vector3:
	var want := target.normalized()
	var jumped := last_target == Vector3.ZERO or rad_to_deg(last_target.angle_to(want)) > JUMP_DEG
	last_target = want
	if shown == Vector3.ZERO or jumped or moving:
		shown = want; catching = false
		return shown
	var lag := rad_to_deg(shown.angle_to(want))
	if lag > HOLD_DEG: catching = true
	if catching:
		var turn := CATCH_UP_DEG_PER_S * dt
		if turn >= lag - SETTLED_DEG:
			shown = want; catching = false
		else:
			shown = shown.slerp(want, turn / lag).normalized()
	return shown
