extends RefCounted
## Casalrana's buildings (stage 2). The rice country's brick and river cobble, ochre and cream plaster with faded green
## shutters, curved terracotta roofs; the station in railway ochre with dark red trim; the bare brick church and its
## tall tower. Each returns a Node3D centred on its footprint at ground level (village.gd places it).
##
## Rooms you can walk into follow Interiors: their walls are Interiors.walls(b) up to Interiors.WALL_H, everything above
## them (upper floors, gables, roof, chimneys) fades away while you're inside (meta "fade_parts"), and window glass glows
## at night (meta "glasses"). In the layout, "eaves" is a building's wall height and "h" its full height (the camera's).
const P := preload("res://scripts/world/palette.gd")
const Tex := preload("res://scripts/locations/rice_village/textures.gd")

const OCHRE := Color("d8ae68")
const TRIM := Color("8e3b2e")       # the railway's dark red
const SHUTTER := Color("6d8466")    # faded green shutters
const BRICK := Color("b8664c")
const STONE := Color("c9bfae")
const IRON := Color("3e4743")
const WOOD := Color("8a6a50")

static func make(b: Dictionary) -> Node3D:
	if HouseKit.uses(b): return HouseKit.build(b)
	match String(b.kind):
		"rice_village_station": return station(b)
		"rice_village_upstairs": return upstairs(b)
		"rice_village_church": return church(b)
		"rice_village_tower": return tower(b)
		"rice_village_mill": return mill(b)
		"rice_village_barn": return barn(b)
		"rice_village_cowshed": return cowshed(b)
		"rice_village_shed": return shed(b)
		"rice_village_dryer": return dryer(b)
		"rice_village_row": return workers_row(b)
		"rice_village_wall": return wall(b)
		"rice_village_track": return track(b)
		"rice_village_tractor": return tractor(b)
		"rice_village_thresher": return thresher(b)
		"rice_village_paddock": return paddock(b)
	return null

## The paddock behind the cowshed: posts and two rails round it, a hay rack and a stone trough. (Its cows, the ox and
## the donkey are wildlife.gd's; the layout's box keeps you outside the rails.)
static func paddock(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var post := P.wood(Color(b.wall)); var rail := P.wood(Color(b.roof))
	var hw: float = b.w / 2.0; var hd: float = b.d / 2.0
	var corners := [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]
	for i in 4:
		var a: Vector2 = corners[i]; var c: Vector2 = corners[(i + 1) % 4]
		var n := int(ceil(a.distance_to(c) / 1.9))
		for k in n + 1:
			var q := a.lerp(c, float(k) / n)
			_add(g, P.box(0.12, 1.1, 0.12), post, Vector3(q.x, 0.55, q.y))
		var mid := (a + c) / 2.0
		for y in [0.45, 0.9]:
			_add(g, P.box(a.distance_to(c), 0.07, 0.05), rail, Vector3(mid.x, y, mid.y), Vector3(0, -atan2(c.y - a.y, c.x - a.x), 0))
	_add(g, P.box(0.5, 0.9, 1.4), P.wood("5e4636"), Vector3(hw - 0.7, 0.45, -hd + 1.6))
	_add(g, P.box(0.45, 0.4, 1.3), P.fabric("d9c27a"), Vector3(hw - 0.7, 1.0, -hd + 1.6))
	_add(g, P.box(0.6, 0.45, 1.4), P.stone("8d8a84"), Vector3(-hw + 0.8, 0.22, hd - 1.5))
	_add(g, P.box(0.48, 0.02, 1.26), P.mat("8fa6a3"), Vector3(-hw + 0.8, 0.44, hd - 1.5))
	return g

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := P.mi(mesh, mat, pos)
	m.rotation = rot; m.scale = scl
	parent.add_child(m)
	return m

static func _eaves(b: Dictionary) -> float: return float(b.get("eaves", 3.0))

static func _wall_mat(b: Dictionary) -> Material:
	return Tex.brick(Color(b.wall)) if String(b.get("finish", "plaster")) == "brick" else P.plaster(b.wall)

## Walls up to the eaves. A room you can walk into gets Interiors' walls (a doorway, a lintel, a floor) up to WALL_H
## and a band of wall above them; the band goes in `over` so it fades with the roof.
static func _body(g: Node3D, b: Dictionary, h: float, mat: Material, over: Array) -> void:
	if not Interiors.enterable(b):
		_add(g, P.box(b.w, h, b.d), mat, Vector3(0, h / 2.0, 0))
		return
	var wh := Interiors.WALL_H
	for r in Interiors.walls(b):
		_add(g, P.box(r.maxX - r.minX, wh, r.maxZ - r.minZ), mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, wh / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
	var di := Interiors.door_info(b)
	var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
	var lw := Vector3(Interiors.DOOR_W, wh - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, wh - Interiors.DOOR_H, Interiors.DOOR_W)
	_add(g, P.box(lw.x, lw.y, lw.z), mat, Vector3(dc.x, (wh + Interiors.DOOR_H) / 2.0, dc.y))
	_add(g, P.box(b.w - 0.1, 0.05, b.d - 0.1), P.wood("c9a27a"), Vector3(0, 0.025, 0))
	if h > wh + 0.01:
		var t := Interiors.WALL_T; var bh := h - wh
		for zs in [-1, 1]: over.append(_add(g, P.box(b.w, bh, t), mat, Vector3(0, wh + bh / 2.0, zs * (b.d / 2.0 - t / 2.0))))
		for xs in [-1, 1]: over.append(_add(g, P.box(t, bh, b.d - t * 2.0), mat, Vector3(xs * (b.w / 2.0 - t / 2.0), wh + bh / 2.0, 0)))
		over.append(_add(g, P.box(b.w - t * 2.0, 0.12, b.d - t * 2.0), P.wood("8a6a50"), Vector3(0, wh + 0.06, 0)))

static func _parts(g: Node3D) -> HouseKit.Parts:
	if g.has_meta("kit_parts"): return g.get_meta("kit_parts")
	var parts := HouseKit.Parts.new(g)
	parts.glass_mat = Landmarks.glass_material()
	g.set_meta("kit_parts", parts)
	return parts

static func _flush(g: Node3D, glasses: Array, over: Array) -> void:
	if not g.has_meta("kit_parts"): return
	var parts: HouseKit.Parts = g.get_meta("kit_parts")
	parts.flush()
	glasses.append_array(parts.glasses)
	over.append_array(parts.high_nodes)
	g.remove_meta("kit_parts")

static func _along(side: String, off: float) -> float:
	return off if side in ["S", "W"] else -off

static func _door_u(b: Dictionary) -> float:
	var fx := Landmarks.facade(b.w, b.d, String(b.get("door", "S")))
	var di := Interiors.door_info(b)
	var c: Vector2 = di.c - Vector2(b.x, b.z)
	return (fx.basis.inverse() * Vector3(c.x, 0.0, c.y)).x

static func _state(b: Dictionary, side: String, y: float, off: float) -> String:
	var r := float(absi(hash("%s|%s|%.1f|%.1f" % [b.get("id", ""), side, y, off])) % 1000) / 1000.0
	return "open" if r < 0.6 else ("shut" if r < 0.75 else ("ajar" if r < 0.9 else "half"))

static func _win(g: Node3D, b: Dictionary, side: String, y: float, off: float, shutter, glasses: Array, over: Array, shut: bool = false) -> void:
	var high: bool = y > Interiors.WALL_H - 0.6 and Interiors.enterable(b)
	var col: String = (Color(shutter) if shutter != null else SHUTTER).to_html(false)
	var xf := Landmarks.facade(b.w, b.d, side) * Transform3D(Basis.IDENTITY, Vector3(_along(side, off), y - 0.6, 0.0))
	_parts(g).window(xf, 0.95, 1.2, col, "shut" if shut else _state(b, side, y, off), false, high, not shut)

static func _door(g: Node3D, b: Dictionary, color: String, scale: float = 1.0) -> void:
	var fx := Landmarks.facade(b.w, b.d, String(b.get("door", "S")))
	_parts(g).door(fx * Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3(_door_u(b), 0.0, 0.0)), color, Interiors.enterable(b))

static func _roof(g: Node3D, b: Dictionary, h: float, wall_mat: Material, over: Array) -> Node3D:
	var roof := Landmarks.kit_roof(g, maxf(b.w, b.d), minf(b.w, b.d), h, b.d > b.w, Color(b.roof), wall_mat, Landmarks.seeded(b))
	over.append(roof)
	return roof

static func _chimney(g: Node3D, b: Dictionary, x: float, z: float, h: float, over: Array) -> Node3D:
	var span := minf(b.w, b.d)
	var rise := span / 2.0 * tan(HouseKit.PITCH)
	var off := absf(z) if b.w >= b.d else absf(x)
	var holder := Node3D.new(); holder.name = "chimney"; g.add_child(holder)
	var parts := HouseKit.Parts.new(holder)
	var top := parts.chimney(x, z, h + rise - off * tan(HouseKit.PITCH) - 0.3, h + rise + 0.9)
	parts.flush()
	if not g.has_meta("chimney"): g.set_meta("chimney", top)
	over.append(holder)
	return holder

static func _finish(g: Node3D, b: Dictionary, glasses: Array, over: Array) -> Node3D:
	_flush(g, glasses, over)
	g.set_meta("glasses", glasses)
	if Interiors.enterable(b): g.set_meta("fade_parts", Props.fade_parts(over))
	return g

static func _plinth(g: Node3D, b: Dictionary, color: Color, ht: float = 0.45, doors: Array = []) -> void:
	var mat := HouseKit.tinted(P.stone(color.lerp(Color(HouseKit.FOOTING_STONE), 0.5)))
	var parts := _parts(g)
	var rng := Landmarks.seeded(b)
	var gaps := doors.duplicate()
	if gaps.is_empty() and b.has("door"): gaps.append([String(b.door), _door_u(b)])
	for side in ["N", "S", "E", "W"]:
		var length: float = b.w if side in ["N", "S"] else b.d
		var fx := Landmarks.facade(b.w, b.d, side)
		var cuts: Array = []
		for gp in gaps:
			if gp[0] == side: cuts.append(float(gp[1]))
		cuts.sort()
		var start := -length / 2.0
		for u in cuts + [length / 2.0 + 0.95]:
			var stop: float = minf(u - 0.95, length / 2.0)
			if stop - start > 0.1: parts.stones(stop - start, ht, fx * Transform3D(Basis.IDENTITY, Vector3((start + stop) / 2.0, 0.0, 0.0)), mat, rng)
			start = u + 0.95

## A sign board with lettering, facing out of one side.
static func _board(g: Node3D, b: Dictionary, side: String, y: float, text: String, width: float, over: Array = []) -> void:
	var n := Node3D.new()
	Props._on_side(n, b, side, y, 0.0, 0.04)
	_add(n, P.box(width, 0.5, 0.06), P.mat("f4efe2"), Vector3.ZERO)
	_add(n, P.box(width + 0.12, 0.62, 0.04), P.mat(TRIM), Vector3(0, 0, -0.02))
	var l := Label3D.new(); l.text = text; l.font_size = 64; l.pixel_size = 0.0055; l.modulate = Color("23201c")
	l.outline_size = 0; l.position = Vector3(0, 0, 0.04); l.double_sided = false
	n.add_child(l)
	g.add_child(n)
	over.append(n)

# ---- The station ----------------------------------------------------------------------------------------------
## Two storeys in railway ochre with dark red trim; the waiting room downstairs (a room you can walk into), the
## station master's flat upstairs. A canopy on iron brackets over the platform, the name boards and a clock.
static func station(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := P.plaster(OCHRE); var over: Array = []; var glasses: Array = []
	var up: Array = []   # what fades over your flat upstairs: the roof and chimneys (its walls are the upper storey's)
	var wh := Interiors.WALL_H; var t := Interiors.WALL_T
	var fy := FLAT_Y - float(b.get("y", 0.42))   # the flat's floor, from the station's ground floor
	_body(g, b, wh, mat, over)
	# between the floors: the waiting room's ceiling below, the flat's floor above (it fades over the waiting room)
	over.append(_add(g, P.box(b.w - t * 2.0, fy - wh, b.d - t * 2.0), P.wood("8a6a50"), Vector3(0, (wh + fy) / 2.0, 0)))
	var fl := _add(g, P.box(b.w - t * 2.0, 0.03, b.d - t * 2.0), P.wood("b08a62"), Vector3(0, fy + 0.015, 0)); over.append(fl)
	# the upper storey's walls, with the flat's door at the east end by the outside stair
	var bh := h - wh
	for zs in [-1, 1]: over.append(_add(g, P.box(b.w, bh, t), mat, Vector3(0, wh + bh / 2.0, zs * (b.d / 2.0 - t / 2.0))))
	over.append(_add(g, P.box(t, bh, b.d - t * 2.0), mat, Vector3(-(b.w / 2.0 - t / 2.0), wh + bh / 2.0, 0)))
	var dz := FLAT_DOOR; var dw := Interiors.DOOR_W; var ex: float = b.w / 2.0 - t / 2.0
	var d0: float = -b.d / 2.0 + t; var d1 := dz - dw / 2.0; var d2 := dz + dw / 2.0; var d3: float = b.d / 2.0 - t
	over.append(_add(g, P.box(t, bh, d1 - d0), mat, Vector3(ex, wh + bh / 2.0, (d0 + d1) / 2.0)))
	over.append(_add(g, P.box(t, bh, d3 - d2), mat, Vector3(ex, wh + bh / 2.0, (d2 + d3) / 2.0)))
	over.append(_add(g, P.box(t, fy - wh, dw), mat, Vector3(ex, (wh + fy) / 2.0, dz)))
	over.append(_add(g, P.box(t, h - fy - Interiors.DOOR_H, dw), mat, Vector3(ex, (h + fy + Interiors.DOOR_H) / 2.0, dz)))
	var fr := P.mat("fffaf0")
	for zz in [d1 - 0.05, d2 + 0.05]: over.append(_add(g, P.box(0.3, Interiors.DOOR_H, 0.1), fr, Vector3(ex + 0.04, fy + Interiors.DOOR_H / 2.0, zz)))
	over.append(_add(g, P.box(0.3, 0.1, dw + 0.2), fr, Vector3(ex + 0.04, fy + Interiors.DOOR_H + 0.05, dz)))
	_plinth(g, b, TRIM.lightened(0.1), 0.5)
	# string course between the floors and quoins at the corners, in the dark red trim
	over.append(_add(g, P.box(b.w + 0.1, 0.16, b.d + 0.1), P.mat(TRIM), Vector3(0, wh + 0.25, 0)))
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_add(g, P.box(0.34, wh, 0.34), P.plaster(TRIM.lightened(0.15)), Vector3(c[0] * (b.w / 2.0 - 0.15), wh / 2.0, c[1] * (b.d / 2.0 - 0.15)))
		over.append(_add(g, P.box(0.34, h - wh, 0.34), P.plaster(TRIM.lightened(0.15)), Vector3(c[0] * (b.w / 2.0 - 0.15), (h + wh) / 2.0, c[1] * (b.d / 2.0 - 0.15))))
	var door_off := float(b.get("doorOffset", 0.0))
	for off in [-4.6, -1.3, 1.6, 4.6]:
		if absf(off - door_off) > 1.0: _win(g, b, "S", 1.35, off, SHUTTER, glasses, over)
		_win(g, b, "N", 1.35, off, SHUTTER, glasses, over)
		_win(g, b, "S", fy + 1.05, off, SHUTTER, glasses, over)
		_win(g, b, "N", fy + 1.05, off, SHUTTER, glasses, over)
	_win(g, b, "W", fy + 1.05, 0.0, SHUTTER, glasses, over)
	_door(g, b, "5a3a2a")
	_parts(g).door(Landmarks.facade(b.w, b.d, "N") * Transform3D(Basis.IDENTITY, Vector3(_along("N", -2.9), 0.0, 0.0)), "5a3a2a", false, false)
	var roof := _roof(g, b, h, mat, over); up.append(roof)
	up.append(_chimney(g, b, -b.w * 0.3, -0.6, h, over))
	up.append(_chimney(g, b, b.w * 0.3, 0.6, h, over))
	_board(g, b, "N", 2.95, "CASALRANA", 3.6)
	_board(g, b, "S", 2.95, "CASALRANA", 3.6, over)
	# the clock over the platform, stopped at the time of the last train that stopped
	var ck := Node3D.new(); Props._on_side(ck, b, "N", fy + 1.6, 0.0, 0.06); g.add_child(ck); over.append(ck)
	_add(ck, P.cyl(0.42, 0.42, 0.08, 24), P.mat("f7f3e8"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_add(ck, P.torus(0.42, 0.04, 24), P.mat(IRON), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_add(ck, P.box(0.04, 0.3, 0.02), P.mat(IRON), Vector3(0.06, 0.1, 0.05), Vector3(0, 0, -0.5))
	_add(ck, P.box(0.035, 0.22, 0.02), P.mat(IRON), Vector3(-0.08, -0.05, 0.05), Vector3(0, 0, 2.2))
	# the canopy over the platform, on curly iron brackets
	var cz: float = -b.d / 2.0 - 0.8
	_add(g, P.box(b.w + 1.2, 0.1, 1.7), P.wood("6f5e4f"), Vector3(0, 3.15, cz), Vector3(0.08, 0, 0))
	_add(g, P.box(b.w + 1.2, 0.22, 0.05), P.mat(TRIM), Vector3(0, 3.05, cz - 0.85))
	for x in range(-int(b.w / 2.0), int(b.w / 2.0) + 1, 2):
		_add(g, P.box(0.06, 0.06, 1.3), P.mat(IRON), Vector3(x, 2.85, cz + 0.1), Vector3(-0.55, 0, 0))
		_add(g, P.torus(0.16, 0.025, 10), P.mat(IRON), Vector3(x, 2.75, -b.d / 2.0 - 0.25), Vector3(0, PI / 2, 0))
	_outside_stair(g, b, fy)
	g.set_meta("upstairs_fade", Props.fade_parts(up))
	return _finish(g, b, glasses, over)

const FLAT_Y := 3.5       # the flat's floor (layout: the flat's "y" and the floor rice_village_flatFloor)
const FLAT_DOOR := 0.6    # the flat's door along the east wall (layout: the flat's doorOffset)

## The iron stair up the outside of the station's east end, from the forecourt to a landing at the flat's door (the
## layout's floors rice_village_flatStair and rice_village_flatLanding: x 25.0 to 26.4, the stair from z -31.6 up to
## -36.4, the landing on to -38.6).
static func _outside_stair(g: Node3D, b: Dictionary, fy: float) -> void:
	var iron := P.mat(IRON); var tread := P.wood("7a5a3e")
	var x0: float = 25.0 - b.x; var x1: float = 26.4 - b.x; var xm := (x0 + x1) / 2.0
	var z_top: float = -36.4 - b.z; var z_bot: float = -31.6 - b.z; var z_land: float = -38.6 - b.z
	var run := z_bot - z_top
	var n := 16
	for k in n:
		var f := (k + 0.5) / n
		_add(g, P.box(x1 - x0 - 0.1, 0.05, run / n + 0.04), tread, Vector3(xm, fy * (1.0 - f) - 0.03, z_top + run * f))
	var ang := atan2(fy, run)
	var len := sqrt(fy * fy + run * run)
	for xx in [x0 + 0.04, x1 - 0.04]:
		_add(g, P.box(0.06, 0.2, len), iron, Vector3(xx, fy / 2.0 - 0.1, (z_top + z_bot) / 2.0), Vector3(ang, 0, 0))
	# the railing on the open side, and the landing on its brackets
	_add(g, P.box(0.04, 0.04, len), iron, Vector3(x1 - 0.02, fy / 2.0 + 0.85, (z_top + z_bot) / 2.0), Vector3(ang, 0, 0))
	for k in 5:
		var f := (k + 0.5) / 5.0
		_add(g, P.box(0.03, 0.85, 0.03), iron, Vector3(x1 - 0.02, fy * (1.0 - f) + 0.42, z_top + run * f))
	# and on the wall side too, where the stair leaves the station's front behind
	var zf: float = b.d / 2.0
	var ff := (z_bot - zf) / run
	_add(g, P.box(0.04, 0.04, z_bot - zf), iron, Vector3(x0 + 0.02, fy * ff * 0.5 + 0.85, (zf + z_bot) / 2.0), Vector3(ang, 0, 0))
	for k in 3:
		var f2 := 1.0 - (k + 0.5) / 3.0 * ff
		_add(g, P.box(0.03, 0.85, 0.03), iron, Vector3(x0 + 0.02, fy * (1.0 - f2) + 0.42, z_top + run * f2))
	_add(g, P.box(x1 - x0, 0.08, z_top - z_land), tread, Vector3(xm, fy - 0.04, (z_top + z_land) / 2.0))
	_add(g, P.box(0.04, 0.04, z_top - z_land), iron, Vector3(x1 - 0.02, fy + 0.9, (z_top + z_land) / 2.0))
	_add(g, P.box(x1 - x0, 0.04, 0.04), iron, Vector3(xm, fy + 0.9, z_land + 0.02))
	for zz in [z_land + 0.05, z_top - 0.05]:
		_add(g, P.box(0.03, 0.9, 0.03), iron, Vector3(x1 - 0.02, fy + 0.45, zz))
		_add(g, P.box(0.05, 0.05, 1.2), iron, Vector3(x0 + 0.5, fy - 0.5, zz), Vector3(0, PI / 2, -0.7))

## Your flat upstairs: a room on the station's upper storey. The station builds its walls, floor and stair; this is
## only where its roof fades from (set in Scenery.dress, from the station's "upstairs_fade").
static func upstairs(_b: Dictionary) -> Node3D: return Node3D.new()

# ---- Houses -----------------------------------------------------------------------------------------------------
## The farm workers' houses: a long two-storey row with a door and a window above for each family, a wooden balcony
## along the upper floor reached by an outside stair, all shut up since machines replaced the workers.
static func workers_row(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := P.plaster(b.wall); var over: Array = []; var glasses: Array = []
	_add(g, P.box(b.w, h, b.d), mat, Vector3(0, h / 2.0, 0))
	var side: String = b.get("door", "E")
	var long: float = b.d if side in ["E", "W"] else b.w
	var fx := Landmarks.facade(b.w, b.d, side)
	var opp: String = {"E": "W", "W": "E", "N": "S", "S": "N"}[side]
	var parts := _parts(g)
	var shutter := SHUTTER.to_html(false)
	var n := int(long / 2.6)
	var doors: Array = []
	for k in n:
		var u := _along(side, -long / 2.0 + long * (k + 0.5) / n)
		if k % 2 == 0:
			doors.append([side, u])
			parts.door(fx * Transform3D(Basis.IDENTITY, Vector3(u, 0.0, 0.0)), "5e4636", false, false)
		else:
			parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, 0.75, 0.0)), 0.95, 1.2, shutter, "shut", false, false, false)
		parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, 3.1, 0.0)), 0.95, 1.2, shutter, "shut", false, false, false)
		parts.window(Landmarks.facade(b.w, b.d, opp) * Transform3D(Basis.IDENTITY, Vector3(u, 3.1, 0.0)), 0.95, 1.2, shutter, "shut", false, false, false)
	_plinth(g, b, Color(b.wall).darkened(0.3), 0.5, doors)
	parts.gallery(fx, long - 0.2, 2.75, -1.0)
	_roof(g, b, h, mat, over)
	for k in 3: _chimney(g, b, 0.4 if side in ["E", "W"] else -long / 2.0 + long * (k + 0.5) / 3.0, -long / 2.0 + long * (k + 0.5) / 3.0 if side in ["E", "W"] else 0.0, h, over)
	return _finish(g, b, glasses, over)

# ---- Church and tower -------------------------------------------------------------------------------------------
## Bare brick, with its gable front to the square: pilasters, a round window and a portal. The nave is a room you can
## walk into.
static func church(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var over: Array = []; var glasses: Array = []
	_body(g, b, h, mat, over)
	_plinth(g, b, STONE.darkened(0.1), 0.5)
	var front: String = b.get("door", "N")
	var fs := -1.0 if front == "N" else 1.0
	# pilasters on the front and down the long sides
	for x in [-b.w / 2.0 + 0.2, -b.w / 6.0, b.w / 6.0, b.w / 2.0 - 0.2]:
		over.append(_add(g, P.box(0.4, h + 1.6, 0.12), Tex.brick(Color(b.wall).darkened(0.08)), Vector3(x, (h + 1.6) / 2.0, fs * (b.d / 2.0 + 0.05))))
	var wh := Interiors.WALL_H
	for z in range(-int(b.d / 2.0) + 2, int(b.d / 2.0) - 1, 3):
		for xs in [-1, 1]:   # down the long sides; the part above the room's walls fades with the roof
			_add(g, P.box(0.14, wh, 0.45), Tex.brick(Color(b.wall).darkened(0.08)), Vector3(xs * (b.w / 2.0 + 0.06), wh / 2.0, z))
			over.append(_add(g, P.box(0.14, h - wh, 0.45), Tex.brick(Color(b.wall).darkened(0.08)), Vector3(xs * (b.w / 2.0 + 0.06), (h + wh) / 2.0, z)))
	# tall arched windows down the sides, high up
	for z in range(-int(b.d / 2.0) + 3, int(b.d / 2.0) - 1, 3):
		for s in ["E", "W"]:
			_parts(g).window(Landmarks.facade(b.w, b.d, s) * Transform3D(Basis.IDENTITY, Vector3(_along(s, z), 2.95, 0.0)), 0.7, 1.9, "", "open", false, Interiors.enterable(b))
	# the round window over the portal
	var rose := Node3D.new(); Props._on_side(rose, b, front, h + 0.6, 0.0, 0.08); g.add_child(rose); over.append(rose)
	_add(rose, P.torus(0.75, 0.12, 24), P.stone(STONE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	var rg := _add(rose, P.cyl(0.7, 0.7, 0.04, 24), P.unique_mat("7fa6c4", "ffcf6b", 0.0), Vector3(0, 0, -0.02), Vector3(PI / 2, 0, 0)); glasses.append(rg)
	for a in 4: _add(rose, P.box(1.4, 0.06, 0.05), P.stone(STONE), Vector3.ZERO, Vector3(0, 0, a * PI / 4))
	# the portal: a stone frame and a little gable over the door
	_door(g, b, "6b3f2a", 1.2)
	var roof := _roof(g, b, h, mat, over)
	# a stone cross on the front gable
	var cross := Node3D.new(); Props._on_side(cross, b, front, h + float(roof.get_meta("rise")) + 0.55, 0.0, -0.2); g.add_child(cross); over.append(cross)
	_add(cross, P.box(0.12, 0.8, 0.12), P.stone(STONE), Vector3.ZERO)
	_add(cross, P.box(0.5, 0.12, 0.12), P.stone(STONE), Vector3(0, 0.14, 0))
	return _finish(g, b, glasses, over)

## The bell tower: a tall brick shaft with corner pilasters and string courses, clock faces, an open bell chamber with
## its bell, and an eight-sided spire with a cross. The tallest thing for miles. Inside (a room you can walk into) the
## wooden stairs have rotted away: the ringing floor along the north wall, where the bell ropes hang, waits for The
## Bell Tower Stairs (layout: the floor rice_village_ringingFloor and the build site rice_village_tower). Everything
## above the room's walls fades while you're inside.
static func tower(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var dark := Tex.brick(Color(b.wall).darkened(0.1))
	var over: Array = []; var glasses: Array = []
	var wh := Interiors.WALL_H
	var shaft := h - 3.4
	_body(g, b, shaft, mat, over)
	_plinth(g, b, STONE.darkened(0.1), 0.6)
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var px: float = c[0] * (b.w / 2.0 - 0.12); var pz: float = c[1] * (b.d / 2.0 - 0.12)
		_add(g, P.box(0.38, wh, 0.38), dark, Vector3(px, wh / 2.0, pz))
		over.append(_add(g, P.box(0.38, h - wh, 0.38), dark, Vector3(px, (h + wh) / 2.0, pz)))
	for y in range(4, int(shaft), 4):
		over.append(_add(g, P.box(b.w + 0.12, 0.14, b.d + 0.12), P.stone(STONE), Vector3(0, y, 0)))
	for s in ["N", "S", "E", "W"]:
		for y in [3.0, 7.0]:
			var sl := Node3D.new(); Props._on_side(sl, b, s, y, 0.0, 0.01); g.add_child(sl); over.append(sl)
			_add(sl, P.box(0.22, 0.9, 0.04), P.mat("2b2622"), Vector3.ZERO)
	# clock faces on the north and south
	for s in ["N", "S"]:
		var ck := Node3D.new(); Props._on_side(ck, b, s, shaft - 1.5, 0.0, 0.04); g.add_child(ck); over.append(ck)
		_add(ck, P.cyl(0.85, 0.85, 0.06, 28), P.mat("f2ede0"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_add(ck, P.torus(0.85, 0.06, 28), P.mat(IRON), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_add(ck, P.box(0.06, 0.55, 0.02), P.mat(IRON), Vector3(0.1, 0.2, 0.04), Vector3(0, 0, -0.4))
		_add(ck, P.box(0.05, 0.4, 0.02), P.mat(IRON), Vector3(-0.12, -0.12, 0.04), Vector3(0, 0, 2.4))
	# the bell chamber: corner piers, arched openings, the bell
	over.append(_add(g, P.box(b.w + 0.2, 0.2, b.d + 0.2), P.stone(STONE), Vector3(0, shaft, 0)))
	# a middle pier on each side splits each opening in two
	for s in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		over.append(_add(g, P.box(0.26, 2.9, 0.26), dark, Vector3(s[0] * (b.w / 2.0 - 0.13), shaft + 1.45, s[1] * (b.d / 2.0 - 0.13))))
	over.append(_add(g, P.box(b.w * 0.9, 0.5, b.d * 0.9), dark, Vector3(0, h - 0.25, 0)))
	var bell := _add(g, P.cyl(0.18, 0.5, 0.75, 14), P.mat("8a6a2e"), Vector3(0, shaft + 1.6, 0))
	bell.name = "bell"; over.append(bell)
	over.append(_add(g, P.box(b.w + 0.3, 0.2, b.d + 0.3), P.stone(STONE), Vector3(0, h + 0.1, 0)))
	var spire := _add(g, P.cyl(0.03, b.w * 0.6, 4.6, 8), HouseKit.tile_material(Color(b.roof)), Vector3(0, h + 2.5, 0))
	spire.rotation.y = PI / 8; over.append(spire)
	over.append(_add(g, P.box(0.1, 0.9, 0.1), P.mat(IRON), Vector3(0, h + 5.2, 0)))
	over.append(_add(g, P.box(0.5, 0.1, 0.1), P.mat(IRON), Vector3(0, h + 5.35, 0)))
	_door(g, b, "6b3f2a")
	# inside: the ringing floor on its beams along the north wall, and the ropes hanging down to it
	var rz: float = 7.5 - b.z; var ry := RING_UP
	var iw: float = b.w - Interiors.WALL_T * 2.0
	_add(g, P.box(iw, 0.12, 1.0), P.wood("7a5a3e"), Vector3(0, ry - 0.06, rz))
	for xx in [-iw / 2.0 + 0.3, 0.0, iw / 2.0 - 0.3]: _add(g, P.box(0.14, 0.18, 1.0), P.wood("5a3d2b"), Vector3(xx, ry - 0.21, rz))
	_add(g, P.box(iw, 0.06, 0.06), P.wood("5a3d2b"), Vector3(0, ry + 0.85, rz + 0.5))
	for xx in [-0.5, 0.5]:
		_add(g, P.cyl(0.02, 0.02, shaft - ry - 0.6, 6), P.mat("c9b48a"), Vector3(xx, (shaft + ry + 0.6) / 2.0, rz - 0.1))
		for k in 3: _add(g, P.cyl(0.045, 0.045, 0.12, 8), P.mat(["b8352c", "f2ede0", "2f5fa8"][k]), Vector3(xx, ry + 0.95 + k * 0.12, rz - 0.1))
	# what's left of the old wooden stairs, heaped in a corner
	for k in 3: _add(g, P.box(0.9, 0.05, 0.2), P.wood("6a5440"), Vector3(-1.2 + k * 0.1, 0.05 + k * 0.05, 1.5 - k * 0.12), Vector3(0, 0.3 * k, 0.1))
	return _finish(g, b, glasses, over)

const RING_UP := 2.0   # the ringing floor above the tower's floor (layout: rice_village_ringingFloor, the tower site's endpoint b)

# ---- The old mill -----------------------------------------------------------------------------------------------
## Small and brick, stopped since 1961. A rusty shaft pokes out of the wall towards the canal, where the waterwheel used
## to drive it; the broken old wheel leans against the wall. Inside, the millstones and the husker.
static func mill(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var over: Array = []; var glasses: Array = []
	_body(g, b, h, mat, over)
	_plinth(g, b, STONE.darkened(0.15), 0.6)
	for s in ["E", "N"]: _win(g, b, s, 1.35, 0.0, Color("6a5a48"), glasses, over)
	for s in ["S", "N", "E", "W"]: _win(g, b, s, 3.6, 0.0, Color("6a5a48"), glasses, over)
	_door(g, b, "5e4636")
	_roof(g, b, h, mat, over)
	_chimney(g, b, 1.2, 1.0, h, over)
	# the old drive shaft through the west wall, and the broken wheel
	var rust := P.mat("8a4e2e")
	_add(g, P.cyl(0.12, 0.12, 1.4, 10), rust, Vector3(-b.w / 2.0 - 0.6, 1.0, 0.0), Vector3(0, 0, PI / 2))
	_add(g, P.cyl(0.3, 0.3, 0.12, 12), rust, Vector3(-b.w / 2.0 - 1.25, 1.0, 0.0), Vector3(0, 0, PI / 2))
	var wheel := Node3D.new(); wheel.position = Vector3(-b.w / 2.0 + 0.6, 1.25, -b.d / 2.0 - 0.45); wheel.rotation = Vector3(0.25, 0.0, 0.0)
	g.add_child(wheel)
	_add(wheel, P.torus(1.15, 0.08, 20), P.wood("6b5440"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for k in 6:
		if k == 4: continue   # a missing spoke
		_add(wheel, P.box(0.08, 2.2, 0.06), P.wood("6b5440"), Vector3.ZERO, Vector3(0, 0, k * PI / 6))
	for k in 9: _add(wheel, P.box(0.38, 0.06, 0.4), P.wood("7a6048"), Vector3(cos(k * TAU / 12) * 1.2, sin(k * TAU / 12) * 1.2, 0), Vector3(0, 0, k * TAU / 12))
	# inside: the millstones under their wooden hopper (an interior barrel holds their place)
	if Interiors.enterable(b) and b.has("millstones"):
		var ms: Array = b.millstones
		var m := Node3D.new(); m.position = Vector3(ms[0], 0, ms[1]); g.add_child(m)
		_add(m, P.cyl(0.62, 0.62, 0.32, 18), P.stone("b5ada0"), Vector3(0, 0.16, 0))
		_add(m, P.cyl(0.58, 0.6, 0.26, 18), P.stone("c8c0b2"), Vector3(0, 0.45, 0))
		_add(m, P.cyl(0.5, 0.22, 0.55, 4), P.wood("8a6a50"), Vector3(0, 0.95, 0), Vector3(0, PI / 4, 0))
	return _finish(g, b, glasses, over)

# ---- Farm buildings ---------------------------------------------------------------------------------------------
## The open barn: a brick back wall, brick piers along the open front, latticework gables, straw stacked inside.
static func barn(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var lat := Tex.lattice(Color(b.wall)); var over: Array = []
	var open: String = b.get("open", "N")
	var along_x: bool = open in ["N", "S"]
	var long: float = b.w if along_x else b.d
	var short: float = b.d if along_x else b.w
	var fs := -1.0 if open in ["N", "W"] else 1.0
	var back := Vector3(0, h / 2.0, -fs * (short / 2.0 - 0.15)) if along_x else Vector3(-fs * (short / 2.0 - 0.15), h / 2.0, 0)
	_add(g, P.box(long if along_x else 0.3, h, 0.3 if along_x else long), mat, back)
	var n := int(long / 3.2)
	for k in n + 1:
		var a := -long / 2.0 + 0.25 + (long - 0.5) * k / n
		var p := Vector3(a, h / 2.0, fs * (short / 2.0 - 0.25)) if along_x else Vector3(fs * (short / 2.0 - 0.25), h / 2.0, a)
		_add(g, P.box(0.5, h, 0.5), mat, p)
	for e in [-1, 1]:
		var p := Vector3(e * (long / 2.0 - 0.15), h / 2.0, 0) if along_x else Vector3(0, h / 2.0, e * (long / 2.0 - 0.15))
		_add(g, P.box(0.3 if along_x else short, h, short if along_x else 0.3), lat, p)
	Landmarks.kit_roof(g, maxf(b.w, b.d), minf(b.w, b.d), h, b.d > b.w, Color(b.roof), lat, Landmarks.seeded(b))
	# straw inside: a stack of rectangular bales
	for k in int(long / 1.6) - 1:
		for lvl in 2 + (k % 2):
			var u := -long / 2.0 + 1.2 + k * 1.6
			var p := Vector3(u, 0.4 + lvl * 0.8, -fs * 0.6) if along_x else Vector3(-fs * 0.6, 0.4 + lvl * 0.8, u)
			_add(g, P.rbox(1.5 if along_x else 1.1, 0.78, 1.1 if along_x else 1.5, 0.08), P.fabric("d9c27a"), p)
	return g

## The cowshed: brick below with small windows and a door, a hayloft above with latticework openings.
static func cowshed(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var lat := Tex.lattice(Color(b.wall)); var over: Array = []; var glasses: Array = []
	_add(g, P.box(b.w, h, b.d), mat, Vector3(0, h / 2.0, 0))
	var side: String = b.get("door", "W")
	var long: float = b.d if side in ["E", "W"] else b.w
	for k in 3:
		var off := -long / 2.0 + long * (k + 0.5) / 3.0
		var l := Node3D.new(); Props._on_side(l, b, side, 3.2, off, 0.03); g.add_child(l)
		_add(l, P.box(1.6, 1.1, 0.05), lat, Vector3.ZERO)
		if k == 1: continue
		var w := Node3D.new(); Props._on_side(w, b, side, 1.5, off, 0.02); g.add_child(w)
		_add(w, P.box(0.7, 0.45, 0.06), P.mat("2b2622"), Vector3.ZERO)
	var d := Node3D.new(); Props._on_side(d, b, side, 1.1, 0.0, 0.02); g.add_child(d)
	_add(d, P.box(1.8, 2.2, 0.08), P.wood("5e4636"), Vector3.ZERO)
	_add(d, P.box(0.08, 2.2, 0.1), P.wood("4a382a"), Vector3(0, 0, 0.02))
	Landmarks.kit_roof(g, maxf(b.w, b.d), minf(b.w, b.d), h, b.d > b.w, Color(b.roof), lat, Landmarks.seeded(b))
	return g

## The machine shed: brick, with big double doors (Barba Tista's shop is inside).
static func shed(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var over: Array = []; var glasses: Array = []
	_body(g, b, h, mat, over)
	_plinth(g, b, STONE.darkened(0.15), 0.45)
	var side: String = b.get("door", "W")
	var long: float = b.d if side in ["E", "W"] else b.w
	for off in [-long / 2.0 + 1.3, long / 2.0 - 1.3]: _win(g, b, side, 1.4, off, Color("6a5a48"), glasses, over)
	# the big sliding doors, pushed open beside the doorway
	var sd := Node3D.new(); Props._on_side(sd, b, side, 1.25, float(b.get("doorOffset", 0.0)) + 1.6, 0.08); g.add_child(sd)
	_add(sd, P.box(1.9, 2.5, 0.08), P.wood("6f5038"), Vector3.ZERO)
	for y in [-0.6, 0.6]: _add(sd, P.box(1.9, 0.08, 0.03), P.wood("5a4030"), Vector3(0, y, 0.05))
	_door(g, b, "6f5038")
	_roof(g, b, h, mat, over)
	return _finish(g, b, glasses, over)

## The rice dryer: a tall metal tower with ribs, a ladder, a hopper on top and a chute.
static func dryer(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var metal := P.smooth(Color(b.wall)); var dark := P.smooth(Color(b.wall).darkened(0.25))
	_add(g, P.box(b.w, h, b.d), metal, Vector3(0, h / 2.0, 0))
	for k in 5:
		var a: float = -b.w / 2.0 + b.w * (k + 0.5) / 5.0
		for zs in [-1, 1]: _add(g, P.box(0.06, h, 0.06), dark, Vector3(a, h / 2.0, zs * (b.d / 2.0 + 0.03)))
	for y in range(2, int(h), 3): _add(g, P.box(b.w + 0.1, 0.1, b.d + 0.1), dark, Vector3(0, y, 0))
	_add(g, P.cyl(0.02, b.w * 0.8, 1.2, 4), metal, Vector3(0, h + 0.6, 0), Vector3(0, PI / 4, 0))
	_add(g, P.box(0.4, 0.4, 0.4), dark, Vector3(0, h + 1.35, 0))
	for xs in [-0.25, 0.25]: _add(g, P.box(0.05, h - 0.5, 0.05), P.mat(IRON), Vector3(xs, (h - 0.5) / 2.0, b.d / 2.0 + 0.25))
	for y in range(1, int(h - 0.5), 1): _add(g, P.box(0.5, 0.04, 0.04), P.mat(IRON), Vector3(0, y, b.d / 2.0 + 0.25))
	var chute := _add(g, P.cyl(0.18, 0.18, 6.0, 8), metal, Vector3(b.w / 2.0 + 1.6, h - 3.0, 0), Vector3(0, 0, 0.6))
	chute.name = "chute"
	_add(g, P.box(1.0, 1.2, 0.9), dark, Vector3(-b.w / 2.0 - 0.6, 0.6, 0))
	return g

## A stretch of the farmstead's wall: river cobbles in herringbone with a brick cap and brick piers at the ends.
static func wall(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	_add(g, P.box(b.w, h, b.d), Tex.cobbles(), Vector3(0, h / 2.0, 0))
	_add(g, P.box(b.w + 0.08, 0.16, b.d + 0.08), Tex.brick(BRICK), Vector3(0, h + 0.08, 0))
	var along_x: bool = b.w >= b.d
	var long: float = b.w if along_x else b.d
	for e in [-1, 1]:
		var p := Vector3(e * (long / 2.0 - 0.25), (h + 0.3) / 2.0, 0) if along_x else Vector3(0, (h + 0.3) / 2.0, e * (long / 2.0 - 0.25))
		_add(g, P.box(0.55, h + 0.3, 0.55), Tex.brick(BRICK), p)
	return g

# ---- The railway bed --------------------------------------------------------------------------------------------
## Ballast, sleepers and two tracks; the model sits at the bed's top.
static func track(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	g.add_child(_rails(b.w, Color(b.wall), Color(b.roof)))
	return g

static func _rails(length: float, ballast: Color, sleeper: Color) -> Node3D:
	var g := Node3D.new()
	_add(g, P.box(length, 0.5, 3.8), P.stone(ballast), Vector3(0, -0.23, 0))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = P.box(0.24, 0.1, 2.5)
	var n := int(length / 0.7)
	mm.instance_count = n * 2
	for t in 2:
		for k in n: mm.set_instance_transform(t * n + k, Transform3D(Basis(), Vector3(-length / 2.0 + 0.35 + k * 0.7, 0.04, -1.0 + t * 2.0)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = P.wood(sleeper)
	g.add_child(mi)
	for zc in [-1.0, 1.0]:
		for side in [-0.72, 0.72]: _add(g, P.box(length, 0.1, 0.08), P.mat("8b9097"), Vector3(0, 0.14, zc + side))
	return g

# ---- Machines ---------------------------------------------------------------------------------------------------
## Barba Tista's tractor: older than he is, orange paint gone chalky, big rear wheels.
static func tractor(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var paint := P.mat("c8642e"); var tyre := P.mat("2b2826"); var hub := P.mat("d9c7a0")
	var r := Node3D.new(); r.rotation.y = float(b.get("r", 0.0)); g.add_child(r)
	_add(r, P.rbox(0.8, 0.7, 1.9, 0.1), paint, Vector3(0, 1.0, 0.2))
	_add(r, P.rbox(0.7, 0.5, 0.9, 0.08), paint, Vector3(0, 1.15, 0.95))
	_add(r, P.cyl(0.06, 0.06, 0.8, 8), P.mat(IRON), Vector3(0.2, 1.8, 0.95))
	_add(r, P.rbox(0.5, 0.12, 0.45, 0.05), P.mat("3a3632"), Vector3(0, 1.45, -0.75))
	_add(r, P.box(0.06, 0.5, 0.06), P.mat(IRON), Vector3(0, 1.75, -0.45), Vector3(0.6, 0, 0))
	for xs in [-1, 1]:
		_add(r, P.cyl(0.72, 0.72, 0.34, 18), tyre, Vector3(xs * 0.65, 0.72, -0.7), Vector3(0, 0, PI / 2))
		_add(r, P.cyl(0.36, 0.36, 0.36, 12), hub, Vector3(xs * 0.65, 0.72, -0.7), Vector3(0, 0, PI / 2))
		_add(r, P.cyl(0.36, 0.36, 0.2, 14), tyre, Vector3(xs * 0.5, 0.36, 1.1), Vector3(0, 0, PI / 2))
		_add(r, P.box(0.38, 0.06, 0.9), paint, Vector3(xs * 0.65, 1.48, -0.7))
	return g

## The old threshing machine: a long rusting box on iron wheels, with belts and a chute.
static func thresher(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var rust := P.mat("9a5a38"); var wood := P.wood("7a6048")
	var r := Node3D.new(); r.rotation.y = float(b.get("r", 0.0)); g.add_child(r)
	_add(r, P.box(1.5, 1.5, 3.6), wood, Vector3(0, 1.35, 0))
	_add(r, P.box(1.6, 0.12, 3.7), rust, Vector3(0, 2.15, 0))
	_add(r, P.cyl(0.35, 0.5, 0.9, 8), rust, Vector3(0, 2.6, -1.2))
	_add(r, P.cyl(0.15, 0.15, 2.0, 8), rust, Vector3(0.9, 1.6, 1.0), Vector3(0.9, 0, 0))
	for z in [-1.3, 1.3]:
		for xs in [-1, 1]: _add(r, P.cyl(0.45, 0.45, 0.12, 12), P.mat(IRON), Vector3(xs * 0.82, 0.45, z), Vector3(0, 0, PI / 2))
	_add(r, P.torus(0.4, 0.04, 14), P.mat(IRON), Vector3(0.8, 1.6, 0.4), Vector3(0, 0, PI / 2))
	return g
