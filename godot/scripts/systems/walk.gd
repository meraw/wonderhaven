class_name WalkWorld
extends RefCounted
## Walkable-surface model shared by player movement and construction validation.
## Statics: {type:"circle", x, z, r} | {type:"box", minX, maxX, minZ, maxZ, flag?}
## Surfaces (from pieces): {minX, maxX, minZ, maxZ, bottom, top, walkable, solid, ramp?: Callable(x, z) -> top}

const STEP_UP := 0.45
const PLAYER_RADIUS := 0.32
const PLAYER_HEIGHT := 1.3

var statics: Array = []
var surfaces: Array = []
var dynamic: Array = []          # moving bodies: {x, z, r}
var flag_fn: Callable = func(_f): return false

func _init(p_statics: Array = [], p_flags: Callable = Callable()) -> void:
	statics = p_statics
	if p_flags.is_valid(): flag_fn = p_flags

func top_of(s: Dictionary, x: float, z: float) -> float:
	return s.ramp.call(x, z) if s.has("ramp") else s.top

## Highest walkable surface at (x, z) reachable from feet height feet_y.
func surface_at(x: float, z: float, feet_y: float = INF) -> Dictionary:
	var g := Heightfield.height(x, z)
	var y := g
	var walkable := g >= Heightfield.WALKABLE_MIN
	for s in surfaces:
		if not s.walkable or x < s.minX or x > s.maxX or z < s.minZ or z > s.maxZ: continue
		var t := top_of(s, x, z)
		if t <= feet_y + STEP_UP + 1e-6 and (t > y or not walkable):
			y = t; walkable = true
	return {"y": y, "walkable": walkable, "ground": g}

func static_active(c: Dictionary) -> bool:
	return not (c.has("flag") and flag_fn.call(c.flag))

static func circle_box(x: float, z: float, r: float, b: Dictionary) -> bool:
	var cx := clampf(x, b.minX, b.maxX)
	var cz := clampf(z, b.minZ, b.maxZ)
	return (x - cx) * (x - cx) + (z - cz) * (z - cz) < r * r

func blocked(x: float, z: float, feet_y: float, r: float = PLAYER_RADIUS, ignore = null) -> bool:
	for c in statics:
		if not static_active(c): continue
		if c.type == "circle":
			if Vector2(x - c.x, z - c.z).length() < c.r + r: return true
		elif circle_box(x, z, r, c): return true
	for s in surfaces:
		if not s.solid: continue
		var top: float = top_of(s, x, z) if s.has("ramp") else s.top
		if s.walkable and top <= feet_y + STEP_UP + 1e-6: continue
		if top <= feet_y + 0.05 or s.bottom >= feet_y + PLAYER_HEIGHT: continue
		if circle_box(x, z, r * 0.9, s): return true
	for d in dynamic:
		if is_same(d, ignore) or d.r <= 0.0: continue
		if Vector2(x - d.x, z - d.z).length() < d.r + r * 0.8: return true
	return false

## The surface if a body can stand at (x, z) coming from feet height feet_y, else an empty Dictionary.
func can_stand(x: float, z: float, feet_y: float, r: float = PLAYER_RADIUS, ignore = null) -> Dictionary:
	if blocked(x, z, feet_y, r, ignore): return {}
	var s := surface_at(x, z, feet_y)
	if not s.walkable or s.y - feet_y > STEP_UP + 1e-6: return {}
	return s

## One movement step with wall sliding. pos: Vector3 (x, feet y, z).
func step_move(pos: Vector3, dx: float, dz: float, r: float = PLAYER_RADIUS, ignore = null) -> Dictionary:
	for t in [Vector2(dx, dz), Vector2(dx, 0), Vector2(0, dz)]:
		if t.x == 0.0 and t.y == 0.0: continue
		var s := can_stand(pos.x + t.x, pos.z + t.y, pos.y, r, ignore)
		if not s.is_empty(): return {"pos": Vector3(pos.x + t.x, s.y, pos.z + t.y), "moved": true}
	return {"pos": Vector3(pos.x, surface_at(pos.x, pos.z, pos.y).y, pos.z), "moved": false}
