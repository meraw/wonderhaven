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
	match String(b.kind):
		"rice_village_station": return station(b)
		"rice_village_house": return house(b)
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
	return null

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

## A window on one side: frame, glass (glows at night), shutters. Windows above the room's walls go in `over`.
static func _win(g: Node3D, b: Dictionary, side: String, y: float, off: float, shutter, glasses: Array, over: Array, shut: bool = false) -> void:
	var w := Props._window(shutter)
	Props._on_side(w, b, side, y, off)
	g.add_child(w)
	if shut:   # closed shutters: the farm workers' houses have been empty for years
		var sh := _add(w, P.rbox(0.9, 0.92, 0.05, 0.03), P.mat(Color(shutter if shutter != null else SHUTTER).darkened(0.08)), Vector3(0, 0, 0.1))
		for yy in [-0.25, 0.0, 0.25]: _add(sh, P.box(0.8, 0.03, 0.02), P.mat(Color(shutter if shutter != null else SHUTTER).darkened(0.25)), Vector3(0, yy, 0.03))
	else:
		glasses.append(w.get_node("glass"))
	if y > Interiors.WALL_H - 0.6 and Interiors.enterable(b): over.append(w)

static func _roof(g: Node3D, b: Dictionary, h: float, wall_mat: Material, over: Array) -> Node3D:
	var roof := Props._gable_roof(g, b.w, b.d, h, wall_mat, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	over.append(roof)
	return roof

static func _chimney(g: Node3D, x: float, z: float, top: float, over: Array) -> void:
	over.append(_add(g, P.rbox(0.5, 1.4, 0.5, 0.04), Tex.brick(BRICK), Vector3(x, top - 0.7, z)))
	over.append(_add(g, P.box(0.66, 0.12, 0.66), P.stone(STONE), Vector3(x, top + 0.04, z)))

static func _finish(g: Node3D, b: Dictionary, glasses: Array, over: Array) -> Node3D:
	g.set_meta("glasses", glasses)
	if Interiors.enterable(b): g.set_meta("fade_parts", Props.fade_parts(over))
	return g

## A plinth along the walls' foot (split round the doorway of a room you can walk into).
static func _plinth(g: Node3D, b: Dictionary, color: Color, ht: float = 0.45) -> void:
	var m := P.plaster(color)
	if Interiors.enterable(b):
		for r in Interiors.walls(b):
			var out := Vector2(signf(((r.minX + r.maxX) / 2.0) - b.x), signf(((r.minZ + r.maxZ) / 2.0) - b.z))
			var horiz: bool = (r.maxX - r.minX) > (r.maxZ - r.minZ)
			var pos := Vector3((r.minX + r.maxX) / 2.0 - b.x + (0.0 if horiz else out.x * 0.03), ht / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z + (out.y * 0.03 if horiz else 0.0))
			_add(g, P.box(r.maxX - r.minX + (0.06 if horiz else 0.0), ht, r.maxZ - r.minZ + (0.0 if horiz else 0.06)), m, pos)
	else:
		_add(g, P.box(b.w + 0.06, ht, b.d + 0.06), m, Vector3(0, ht / 2.0, 0))

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
	_body(g, b, h, mat, over)
	_plinth(g, b, TRIM.lightened(0.1), 0.5)
	# string course between the floors and quoins at the corners, in the dark red trim
	over.append(_add(g, P.box(b.w + 0.1, 0.16, b.d + 0.1), P.mat(TRIM), Vector3(0, Interiors.WALL_H + 0.25, 0)))
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_add(g, P.box(0.34, Interiors.WALL_H, 0.34), P.plaster(TRIM.lightened(0.15)), Vector3(c[0] * (b.w / 2.0 - 0.15), Interiors.WALL_H / 2.0, c[1] * (b.d / 2.0 - 0.15)))
		over.append(_add(g, P.box(0.34, h - Interiors.WALL_H, 0.34), P.plaster(TRIM.lightened(0.15)), Vector3(c[0] * (b.w / 2.0 - 0.15), (h + Interiors.WALL_H) / 2.0, c[1] * (b.d / 2.0 - 0.15))))
	var door_off := float(b.get("doorOffset", 0.0))
	for off in [-4.6, -1.3, 1.6, 4.6]:
		if absf(off - door_off) > 1.0: _win(g, b, "S", 1.35, off, SHUTTER, glasses, over)
		_win(g, b, "N", 1.35, off, SHUTTER, glasses, over)
		_win(g, b, "S", 3.95, off, SHUTTER, glasses, over)
		_win(g, b, "N", 3.95, off, SHUTTER, glasses, over)
	for s in ["E", "W"]: _win(g, b, s, 3.95, 0.0, SHUTTER, glasses, over)
	Props._door(g, b, "5a3a2a", null)
	# the platform door (shut: you go through the waiting room)
	var pd := Node3D.new(); Props._on_side(pd, b, "N", 0.95, -2.9, 0.02); g.add_child(pd)
	_add(pd, P.rbox(1.1, 1.9, 0.08, 0.03), P.wood("5a3a2a"), Vector3.ZERO)
	_roof(g, b, h, mat, over)
	_chimney(g, -b.w * 0.3, -0.6, h + 2.2, over)
	_chimney(g, b.w * 0.3, 0.6, h + 2.2, over)
	_board(g, b, "N", 2.95, "CASALRANA", 3.6)
	_board(g, b, "S", 2.95, "CASALRANA", 3.6, over)
	# the clock over the platform, stopped at the time of the last train that stopped
	var ck := Node3D.new(); Props._on_side(ck, b, "N", 4.75, 0.0, 0.06); g.add_child(ck); over.append(ck)
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
	return _finish(g, b, glasses, over)

# ---- Houses -----------------------------------------------------------------------------------------------------
## Plaster houses: the crossing keeper's cottage, the farmhouse, the farm office, the presbytery. Two storeys when
## their eaves are tall; "balcony": true adds the wooden balcony along the upper floor on the door side.
static func house(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := _wall_mat(b); var over: Array = []; var glasses: Array = []
	var shutter := Color(b.get("shutter", SHUTTER.to_html()))
	_body(g, b, h, mat, over)
	_plinth(g, b, Color(b.wall).darkened(0.25), 0.4)
	var two := h > 3.6
	var door_off := float(b.get("doorOffset", 0.0))
	for s in ["N", "S", "E", "W"]:
		var long: float = b.w if s in ["N", "S"] else b.d
		var n := maxi(1, int(long / 2.6))
		for k in n:
			var off := -long / 2.0 + long * (k + 0.5) / n
			if s == b.get("door", "S") and absf(off - door_off) < 1.1:
				if two: _win(g, b, s, 3.85, off, shutter, glasses, over)
				continue
			_win(g, b, s, 1.35, off, shutter, glasses, over)
			if two: _win(g, b, s, 3.85, off, shutter, glasses, over)
	if two: over.append(_add(g, P.box(b.w + 0.08, 0.12, b.d + 0.08), P.plaster(Color(b.wall).darkened(0.12)), Vector3(0, Interiors.WALL_H + 0.3, 0)))
	if b.has("door"): Props._door(g, b, "6a4a34", null)
	if b.get("balcony", false) and two:
		var bal := Node3D.new(); Props._on_side(bal, b, b.door, 3.0, 0.0, 0.0); g.add_child(bal); over.append(bal)
		var blen: float = b.w if b.door in ["N", "S"] else b.d
		_add(bal, P.box(blen - 0.4, 0.1, 1.1), P.wood(WOOD), Vector3(0, 0, 0.55))
		_add(bal, P.box(blen - 0.4, 0.06, 0.06), P.wood(WOOD), Vector3(0, 0.95, 1.05))
		for x in range(int(-(blen - 0.6) / 2.0), int((blen - 0.6) / 2.0) + 1):
			_add(bal, P.box(0.05, 0.95, 0.05), P.wood(WOOD), Vector3(x, 0.48, 1.05))
		for x in [-(blen - 0.6) / 2.0, 0.0, (blen - 0.6) / 2.0]:
			_add(bal, P.box(0.08, 0.08, 1.0), P.wood(WOOD), Vector3(x, -0.25, 0.5), Vector3(-0.5, 0, 0))
	_roof(g, b, h, mat, over)
	if b.get("chimney", true): _chimney(g, b.w * 0.25 if b.w >= b.d else 0.4, -0.4 if b.w >= b.d else b.d * 0.25, h + Props.roof_rise(b.w, b.d) + 0.4, over)
	if b.has("board"): _board(g, b, b.door, 2.75, String(b.board), 2.6, over)
	return _finish(g, b, glasses, over)

## The farm workers' houses: a long two-storey row with a door and a window above for each family, a wooden balcony
## along the upper floor reached by an outside stair, all shut up since machines replaced the workers.
static func workers_row(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := P.plaster(b.wall); var over: Array = []; var glasses: Array = []
	_add(g, P.box(b.w, h, b.d), mat, Vector3(0, h / 2.0, 0))
	_plinth(g, b, Color(b.wall).darkened(0.3), 0.5)
	var side: String = b.get("door", "E")
	var long: float = b.d if side in ["E", "W"] else b.w
	var n := int(long / 2.6)
	for k in n:
		var off := -long / 2.0 + long * (k + 0.5) / n
		if k % 2 == 0:
			var d := Node3D.new(); Props._on_side(d, b, side, 0.95, off, 0.02); g.add_child(d)
			_add(d, P.rbox(1.0, 1.9, 0.08, 0.03), P.wood("5e4636"), Vector3.ZERO)
		else:
			_win(g, b, side, 1.35, off, SHUTTER, glasses, over, true)
		_win(g, b, side, 3.7, off, SHUTTER, glasses, over, true)
	var opp: String = {"E": "W", "W": "E", "N": "S", "S": "N"}[side]
	for k in n: _win(g, b, opp, 3.7, -long / 2.0 + long * (k + 0.5) / n, SHUTTER, glasses, over, true)
	var bal := Node3D.new(); Props._on_side(bal, b, side, 2.75, 0.0, 0.0); g.add_child(bal)
	_add(bal, P.box(long - 0.2, 0.1, 1.0), P.wood(WOOD), Vector3(0, 0, 0.5))
	_add(bal, P.box(long - 0.2, 0.06, 0.06), P.wood(WOOD), Vector3(0, 0.95, 0.98))
	for x in range(int(-(long - 0.4) / 2.0), int((long - 0.4) / 2.0) + 1): _add(bal, P.box(0.05, 0.95, 0.05), P.wood(WOOD), Vector3(x, 0.48, 0.98))
	# the outside stair up to the balcony, at the south end
	for s in 8:
		_add(bal, P.box(0.9, 0.08, 0.3), P.wood(WOOD), Vector3(long / 2.0 - 0.45 - s * 0.32, -0.33 * (8 - s) + 0.05, 0.5))
	_roof(g, b, h, mat, over)
	for k in 3: _chimney(g, 0.4, -long / 2.0 + long * (k + 0.5) / 3.0 if side in ["E", "W"] else 0.0, h + Props.roof_rise(b.w, b.d) + 0.4, over)
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
	for z in range(-int(b.d / 2.0) + 2, int(b.d / 2.0) - 1, 3):
		for xs in [-1, 1]: _add(g, P.box(0.14, h, 0.45), Tex.brick(Color(b.wall).darkened(0.08)), Vector3(xs * (b.w / 2.0 + 0.06), h / 2.0, z))
	# tall arched windows down the sides, high up
	for z in range(-int(b.d / 2.0) + 3, int(b.d / 2.0) - 1, 3):
		for s in ["E", "W"]:
			var w := Node3D.new(); Props._on_side(w, b, s, 3.9, z, 0.03); g.add_child(w); over.append(w)
			_add(w, P.box(0.7, 1.9, 0.06), P.stone(STONE), Vector3.ZERO)
			var gl := _add(w, P.box(0.5, 1.7, 0.04), P.unique_mat("8fb8cf", "ffcf6b", 0.0), Vector3(0, 0, 0.03)); glasses.append(gl)
			_add(w, P.cyl(0.35, 0.35, 0.06, 12), P.stone(STONE), Vector3(0, 0.95, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1))
	# the round window over the portal
	var rose := Node3D.new(); Props._on_side(rose, b, front, h + 0.6, 0.0, 0.08); g.add_child(rose); over.append(rose)
	_add(rose, P.torus(0.75, 0.12, 24), P.stone(STONE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	var rg := _add(rose, P.cyl(0.7, 0.7, 0.04, 24), P.unique_mat("7fa6c4", "ffcf6b", 0.0), Vector3(0, 0, -0.02), Vector3(PI / 2, 0, 0)); glasses.append(rg)
	for a in 4: _add(rose, P.box(1.4, 0.06, 0.05), P.stone(STONE), Vector3.ZERO, Vector3(0, 0, a * PI / 4))
	# the portal: a stone frame and a little gable over the door
	var por := Node3D.new(); Props._on_side(por, b, front, 0.0, float(b.get("doorOffset", 0.0)), 0.06); g.add_child(por)
	for x in [-0.85, 0.85]: _add(por, P.box(0.25, 2.5, 0.2), P.stone(STONE), Vector3(x, 1.25, 0))
	_add(por, P.box(2.0, 0.25, 0.25), P.stone(STONE), Vector3(0, 2.55, 0))
	_add(por, P.cyl(0.02, 1.15, 0.6, 3), P.stone(STONE), Vector3(0, 2.95, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.4))
	Props._door(g, b, "6b3f2a", null)
	_roof(g, b, h, mat, over)
	# a stone cross on the front gable
	var cross := Node3D.new(); Props._on_side(cross, b, front, h + Props.roof_rise(b.w, b.d) + 0.55, 0.0, -0.2); g.add_child(cross); over.append(cross)
	_add(cross, P.box(0.12, 0.8, 0.12), P.stone(STONE), Vector3.ZERO)
	_add(cross, P.box(0.5, 0.12, 0.12), P.stone(STONE), Vector3(0, 0.14, 0))
	return _finish(g, b, glasses, over)

## The bell tower: a tall brick shaft with corner pilasters and string courses, clock faces, an open bell chamber with
## its bell, and an eight-sided spire with a cross. The tallest thing for miles.
static func tower(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := _eaves(b)
	var mat := Tex.brick(Color(b.wall)); var dark := Tex.brick(Color(b.wall).darkened(0.1))
	var shaft := h - 3.4
	_add(g, P.box(b.w, shaft, b.d), mat, Vector3(0, shaft / 2.0, 0))
	_add(g, P.box(b.w + 0.1, 0.6, b.d + 0.1), P.stone(STONE.darkened(0.1)), Vector3(0, 0.3, 0))
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_add(g, P.box(0.38, h, 0.38), dark, Vector3(c[0] * (b.w / 2.0 - 0.12), h / 2.0, c[1] * (b.d / 2.0 - 0.12)))
	for y in range(4, int(shaft), 4):
		_add(g, P.box(b.w + 0.12, 0.14, b.d + 0.12), P.stone(STONE), Vector3(0, y, 0))
	for s in ["N", "S", "E", "W"]:
		for y in [3.0, 7.0]:
			var sl := Node3D.new(); Props._on_side(sl, b, s, y, 0.0, 0.01); g.add_child(sl)
			_add(sl, P.box(0.22, 0.9, 0.04), P.mat("2b2622"), Vector3.ZERO)
	# clock faces on the north and south
	for s in ["N", "S"]:
		var ck := Node3D.new(); Props._on_side(ck, b, s, shaft - 1.5, 0.0, 0.04); g.add_child(ck)
		_add(ck, P.cyl(0.85, 0.85, 0.06, 28), P.mat("f2ede0"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_add(ck, P.torus(0.85, 0.06, 28), P.mat(IRON), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_add(ck, P.box(0.06, 0.55, 0.02), P.mat(IRON), Vector3(0.1, 0.2, 0.04), Vector3(0, 0, -0.4))
		_add(ck, P.box(0.05, 0.4, 0.02), P.mat(IRON), Vector3(-0.12, -0.12, 0.04), Vector3(0, 0, 2.4))
	# the bell chamber: corner piers, arched openings, the bell
	_add(g, P.box(b.w + 0.2, 0.2, b.d + 0.2), P.stone(STONE), Vector3(0, shaft, 0))
	# a middle pier on each side splits each opening in two
	for s in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		_add(g, P.box(0.26, 2.9, 0.26), dark, Vector3(s[0] * (b.w / 2.0 - 0.13), shaft + 1.45, s[1] * (b.d / 2.0 - 0.13)))
	_add(g, P.box(b.w * 0.9, 0.5, b.d * 0.9), dark, Vector3(0, h - 0.25, 0))
	var bell := _add(g, P.cyl(0.18, 0.5, 0.75, 14), P.mat("8a6a2e"), Vector3(0, shaft + 1.6, 0))
	bell.name = "bell"
	_add(g, P.box(b.w + 0.3, 0.2, b.d + 0.3), P.stone(STONE), Vector3(0, h + 0.1, 0))
	var spire := _add(g, P.cyl(0.03, b.w * 0.6, 4.6, 8), P.mat(Color(b.roof)), Vector3(0, h + 2.5, 0))
	spire.rotation.y = PI / 8
	_add(g, P.box(0.1, 0.9, 0.1), P.mat(IRON), Vector3(0, h + 5.2, 0))
	_add(g, P.box(0.5, 0.1, 0.1), P.mat(IRON), Vector3(0, h + 5.35, 0))
	return g

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
	Props._door(g, b, "5e4636", null)
	_roof(g, b, h, mat, over)
	_chimney(g, 1.2, 1.0, h + Props.roof_rise(b.w, b.d) + 0.6, over)
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
	Props._gable_roof(g, b.w, b.d, h, lat, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
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
	Props._gable_roof(g, b.w, b.d, h, lat, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
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
	Props._door(g, b, "6f5038", null)
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
