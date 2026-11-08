class_name Interiors
## Rooms you can walk into. A building with an `interior` block in layout.json gets walls with a doorway, furniture,
## a room box (for the camera and the fading roof) and nav spots so villagers can go inside. Everything here is
## pure data maths, shared by collision (WorldStatics), visuals (Props/Village), the camera and the nav graph.
##
## interior: {
##   shell: "house" | "castle",        (castle: curtain wall + keep, both with a gateway)
##   items: [[id, lx, lz, r, color?], ...]   id is a build piece id or a prop (oven, barrel, crate, throne, banner, pillar)
##   route: [[lx, lz], ...]            path from just inside the door to the spot where the owner works and sleeps
##   empty: true                       (a room someone wants help furnishing; no furniture yet)
## }
## Local coordinates are metres from the building's centre, x east, z south; r is quarter turns like build pieces.

const WALL_T := 0.22
const DOOR_W := 1.25
const DOOR_H := 2.05
const WALL_H := 2.4
## Footprints of props that aren't build pieces: [width, depth] in metres (before rotation), or a radius for round ones.
const PROPS := {"oven": [0.9, 0.8], "crate": [0.7, 0.7], "throne": [1.2, 1.0], "barrel": 0.35, "pillar": 0.32, "banner": [0.0, 0.0]}

static func enterable(b: Dictionary) -> bool: return b.has("interior")

## Unit vector pointing out of the door side, and the door's position along that wall.
static func door_info(b: Dictionary) -> Dictionary:
	var side: String = b.get("door", "S")
	var off := float(b.get("doorOffset", 0.0))
	match side:
		"N": return {"out": Vector2(0, -1), "along": Vector2(1, 0), "c": Vector2(b.x + off, b.z - b.d / 2.0)}
		"E": return {"out": Vector2(1, 0), "along": Vector2(0, 1), "c": Vector2(b.x + b.w / 2.0, b.z + off)}
		"W": return {"out": Vector2(-1, 0), "along": Vector2(0, 1), "c": Vector2(b.x - b.w / 2.0, b.z + off)}
	return {"out": Vector2(0, 1), "along": Vector2(1, 0), "c": Vector2(b.x + off, b.z + b.d / 2.0)}

## Wall rectangles (world x/z) of a w x d room centred at (cx, cz), leaving a doorway on the door side.
static func _shell(cx: float, cz: float, w: float, d: float, side: String, off: float, t: float) -> Array:
	var minX := cx - w / 2.0; var maxX := cx + w / 2.0; var minZ := cz - d / 2.0; var maxZ := cz + d / 2.0
	var out: Array = []
	var g0: float; var g1: float
	for s in ["N", "S", "E", "W"]:
		var horiz: bool = s in ["N", "S"]
		var r := {}
		match s:
			"N": r = {"minX": minX, "maxX": maxX, "minZ": minZ, "maxZ": minZ + t}
			"S": r = {"minX": minX, "maxX": maxX, "minZ": maxZ - t, "maxZ": maxZ}
			"E": r = {"minX": maxX - t, "maxX": maxX, "minZ": minZ, "maxZ": maxZ}
			"W": r = {"minX": minX, "maxX": minX + t, "minZ": minZ, "maxZ": maxZ}
		if s != side: out.append(r); continue
		var c: float = (cx if horiz else cz) + off
		g0 = c - DOOR_W / 2.0; g1 = c + DOOR_W / 2.0
		if horiz:
			out.append({"minX": r.minX, "maxX": g0, "minZ": r.minZ, "maxZ": r.maxZ})
			out.append({"minX": g1, "maxX": r.maxX, "minZ": r.minZ, "maxZ": r.maxZ})
		else:
			out.append({"minX": r.minX, "maxX": r.maxX, "minZ": r.minZ, "maxZ": g0})
			out.append({"minX": r.minX, "maxX": r.maxX, "minZ": g1, "maxZ": r.maxZ})
	return out

## All wall rectangles of a building's shell, tagged {minX, maxX, minZ, maxZ, h}.
static func walls(b: Dictionary) -> Array:
	var side: String = b.get("door", "S")
	var off := float(b.get("doorOffset", 0.0))
	var out: Array = []
	if b.interior.get("shell", "house") == "castle":
		for r in _shell(b.x, b.z, b.w, b.d, side, off, 0.5): r["h"] = 2.4; out.append(r)
		for r in _shell(b.x, b.z, b.w - 2.0, b.d - 2.0, side, off, 0.35): r["h"] = 4.2; out.append(r)
	else:
		for r in _shell(b.x, b.z, b.w, b.d, side, off, WALL_T): r["h"] = WALL_H; out.append(r)
	return out

## The walkable inside of the room (world), up to the wall tops; y is relative to the ground.
static func room(b: Dictionary, base_y: float = 0.0) -> AABB:
	var castle: bool = b.interior.get("shell", "house") == "castle"
	var w: float = (b.w - 2.0 - 0.7) if castle else (b.w - WALL_T * 2.0)
	var d: float = (b.d - 2.0 - 0.7) if castle else (b.d - WALL_T * 2.0)
	var h := 4.2 if castle else float(b.interior.get("height", WALL_H))   # "height": a tall room (a tower you climb inside)
	return AABB(Vector3(b.x - w / 2.0, base_y - 1.0, b.z - d / 2.0), Vector3(w, h + 1.0, d))

## Is someone with their feet at p in this room, on its own storey? Rooms stacked on raised floors share a footprint
## (a waiting room and the flat above it), so the roof over the one you're in fades, not the other's.
static func inside(b: Dictionary, base_y: float, p: Vector3) -> bool: return room(b, base_y).has_point(Vector3(p.x, p.y + 0.5, p.z))

## Furniture as {id, x, z, r, color, piece} in world coordinates.
static func items(b: Dictionary) -> Array:
	var out: Array = []
	if b.interior.get("empty", false) and not b.interior.has("items"): return out
	for it in b.interior.get("items", []):
		out.append({"id": str(it[0]), "x": b.x + float(it[1]), "z": b.z + float(it[2]), "r": int(it[3]) if it.size() > 3 else 0,
			"color": str(it[4]) if it.size() > 4 else "", "piece": not Data.piece(str(it[0])).is_empty()})
	return out

## Collision shape of a furniture item: a rect {minX..} or a circle {type: circle, x, z, r}; {} for walk-on items.
static func item_static(it: Dictionary) -> Dictionary:
	if it.piece:
		var d := Data.piece(it.id)
		if not d.get("solid", true) or d.get("attach", "") == "wall": return {}
		var fp := BuildGrid.footprint(d, it.r)
		var pl := {"id": it.id, "i": it.x - fp.x / 2.0, "k": it.z - fp.y / 2.0, "r": it.r, "y": 0.0}
		return BuildGrid.rect_of(d, pl)
	var p = PROPS.get(it.id, [0.6, 0.6])
	if p is float: return {"type": "circle", "x": it.x, "z": it.z, "r": p}
	if p[0] <= 0.0: return {}
	var sw: float = p[1] if it.r % 2 == 1 else p[0]
	var sd: float = p[0] if it.r % 2 == 1 else p[1]
	return {"minX": it.x - sw / 2.0, "maxX": it.x + sw / 2.0, "minZ": it.z - sd / 2.0, "maxZ": it.z + sd / 2.0}

## Nav spots for a building: "<id>:in" just inside the door, then the route, ending at "<id>:spot".
## Returns {nodes: {name: [x, z]}, edges: [[a, b], ...]}; the first edge joins the door's outdoor nav node.
static func nav(b: Dictionary) -> Dictionary:
	var nodes := {}; var edges: Array = []
	var route: Array = b.interior.get("route", [])
	if route.is_empty() or not b.has("navDoor"): return {"nodes": nodes, "edges": edges}
	var prev: String = b.navDoor
	var storey: Array = [float(b.y)] if b.has("y") else []
	for i in route.size():
		var name: String = ("%s:in" % b.id) if i == 0 else (("%s:spot" % b.id) if i == route.size() - 1 else "%s:%d" % [b.id, i])
		nodes[name] = [b.x + float(route[i][0]), b.z + float(route[i][1])] + storey
		edges.append([prev, name]); prev = name
	if route.size() == 1:
		nodes["%s:spot" % b.id] = [nodes["%s:in" % b.id][0] + 0.01, nodes["%s:in" % b.id][1]] + storey
		edges.append(["%s:in" % b.id, "%s:spot" % b.id])
	return {"nodes": nodes, "edges": edges}
