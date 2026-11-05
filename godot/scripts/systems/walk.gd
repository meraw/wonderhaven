class_name WalkWorld
extends RefCounted
## Walkable-surface model shared by player movement and construction validation.
## Statics: {type:"circle", x, z, r} | {type:"box", minX, maxX, minZ, maxZ, flag?, whileFlag?}: a `flag` static stops
## blocking once that flag is set (a gate that opens); a `whileFlag` one only blocks while it's set (a bus that arrives).
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
	if c.has("whileFlag") and not flag_fn.call(c.whileFlag): return false
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
	var tries: Array = [Vector2(dx, dz), Vector2(dx, 0), Vector2(0, dz)]
	# Corner assist: caught on the end of a railing, a door post or a corner a little to one side, the step turns
	# to slip round it instead of stopping dead. Only into space the body fits; a flat wall or the water still stops you.
	for a in [0.5, -0.5, 1.0, -1.0]: tries.append(Vector2(dx, dz).rotated(a))
	for t in tries:
		if t.x == 0.0 and t.y == 0.0: continue
		var s := can_stand(pos.x + t.x, pos.z + t.y, pos.y, r, ignore)
		if not s.is_empty(): return {"pos": Vector3(pos.x + t.x, s.y, pos.z + t.y), "moved": true}
	return {"pos": Vector3(pos.x, surface_at(pos.x, pos.z, pos.y).y, pos.z), "moved": false}

## True when a body at pos can't take a step in any direction (boxed in by pieces).
func stuck(pos: Vector3, r: float = PLAYER_RADIUS, ignore = null) -> bool:
	for k in 8:
		var a := k * TAU / 8.0
		if not can_stand(pos.x + cos(a) * 0.35, pos.z + sin(a) * 0.35, pos.y, r, ignore).is_empty(): return false
	return true

## The nearest spot to (x, z) where a body can stand, can move around, and that lies outside `avoid`
## (a Rect2 in x/z, e.g. a build zone). Searches outward in rings; returns {} if nothing within max_r.
func free_spot(x: float, z: float, avoid: Rect2 = Rect2(), max_r: float = 14.0, r: float = PLAYER_RADIUS, ignore = null) -> Dictionary:
	var rad := 0.0
	while rad <= max_r:
		var n := 1 if rad == 0.0 else int(ceil(TAU * rad / 0.6))
		for k in n:
			var a := k * TAU / n
			var px := x + cos(a) * rad; var pz := z + sin(a) * rad
			if avoid.has_area() and avoid.grow(0.4).has_point(Vector2(px, pz)): continue
			var feet: float = surface_at(px, pz).y
			var s := can_stand(px, pz, feet, r, ignore)
			if s.is_empty(): continue
			if stuck(Vector3(px, s.y, pz), r, ignore): continue
			return {"x": px, "z": pz, "y": s.y}
		rad += 0.5
	return {}

