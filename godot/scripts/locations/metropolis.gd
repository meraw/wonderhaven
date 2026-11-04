extends RefCounted
## Toriano (working id metropolis): the city. See docs/locations/metropolis.md. Stage 1: the ground shape and plain
## blocks for every building, so the street plan can be walked and seen; the real models come in stage 2.

## Flat city ground, with stone-walled water cut into it: the Darsena (the dock basin), the canal that feeds it from
## the west, the Naviglio dei Fiori leaving it to the south, and the duck pond in the park.
const GROUND := 0.3
const BED := -1.4
const QUAY := 0.4   # the quay walls are almost sheer
const DARSENA := Rect2(-140, 92, 48, 26)
const CANAL_A := Rect2(-200, 100, 60, 10)   # runs on under the city's edge
const CANAL_B := Rect2(-112, 118, 10, 80)   # the Naviglio dei Fiori
const POND := Vector3(-120, -126, 11)        # x, z, radius
const OLD_BRIDGE := Rect2(-160, 99, 6, 12)   # a street carried over the canal and its quay walls (solid until stage 2)

static func _outside(r: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

static func height(x: float, z: float) -> float:
	if OLD_BRIDGE.has_point(Vector2(x, z)): return GROUND
	var h := GROUND
	var d := minf(_outside(DARSENA, x, z), minf(_outside(CANAL_A, x, z), _outside(CANAL_B, x, z)))
	if d < QUAY: h = lerpf(BED, GROUND, d / QUAY) if d > 0.0 else BED
	# The pond has a soft grassy bank instead of a quay.
	var dp := Vector2(x - POND.x, z - POND.y).length() - POND.z
	if dp < 2.0:
		var t := clampf((dp + 2.5) / 4.5, 0.0, 1.0)
		h = minf(h, lerpf(-1.0, GROUND, t * t * (3.0 - 2.0 * t)))
	return h

## The two canals flow (waterwheels turn there); the Darsena and the pond are still water.
static func is_stream_cell(i: float, k: float) -> bool:
	var p := Vector2(i + 0.5, k + 0.5)
	if OLD_BRIDGE.has_point(p): return false
	return CANAL_A.has_point(p) or CANAL_B.has_point(p)

## Stage 1: every building is a plain block of its wall colour, with a darker roof and a stone plinth, at its full
## height (the camera knows it from "h"). The Duomo gets a spire for the Golden Angel so the skyline reads.
static func building(b: Dictionary) -> Node3D:
	var P := preload("res://scripts/world/palette.gd")
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.get("h", 12.0))
	var wall := Color(String(b.get("wall", "#d9a85b")))
	g.add_child(P.mi(P.box(w, 0.9, d), P.stone(wall.darkened(0.35)), Vector3(0, 0.45, 0)))
	g.add_child(P.mi(P.box(w, h - 0.9, d), P.plaster(wall), Vector3(0, 0.9 + (h - 0.9) / 2.0, 0)))
	g.add_child(P.mi(P.box(w + 0.3, 0.4, d + 0.3), P.mat(wall.darkened(0.45)), Vector3(0, h + 0.2, 0)))
	if b.kind == "duomo":
		for s in [[-0.42, -0.35], [-0.42, 0.35], [0.42, -0.35], [0.42, 0.35]]:
			g.add_child(P.mi(P.cone(1.2, 9.0, 8), P.plaster(wall), Vector3(s[0] * w, h + 4.5, s[1] * d)))
		g.add_child(P.mi(P.cone(2.4, 24.0, 8), P.plaster(wall), Vector3(0.1 * w, h + 12.0, 0)))
		g.add_child(P.mi(P.sphere(0.9, 10, 8), P.mat(P.GOLD, P.GOLD, 0.2), Vector3(0.1 * w, h + 24.6, 0)))
	return g
