extends RefCounted
## Boccapioppo's buildings (docs/locations/river_town.md, "Look"): brick for the church, station, sawmill and farm;
## Lombard yellow and faded orange plaster with dark green shutters for the houses; the warden's house in the river
## authority's oxblood with pale corner stones; the dance hall in white and sky-blue wood on stilts. A fresh tide line
## marks the walls the flood reached. Rooms you can walk into are built from the same wall rectangles as their
## collision (Interiors.walls), and what is above the room fades while you are inside (Props.fade_parts).
const P := preload("res://scripts/world/palette.gd")
const SHUTTER := "#3f5a3a"
const TIDE := "#8f7d5c"
const STONE := "#d8cdb8"
const UPPER := 1.9   # an upper storey's height, above the shared 2.4 m ground floor

## The model for one of the layout's buildings, or null to use the shared ones.
static func build(b: Dictionary) -> Node3D:
	match String(b.kind):
		"house": return town_house(b)
		"bar": return bar(b)
		"arcade": return arcade(b)
		"church": return church(b)
		"bike_shop": return workshop(b)
		"keeper_house": return keeper_house(b)
		"station": return station(b)
		"farm": return farm(b)
		"houseboat": return houseboat(b)
		"shack": return shack(b)
		"dance_hall": return dance_hall(b)
		"sawmill": return sawmill_office(b)
		"pumphouse": return pumphouse(b)
	return null

# ---- shared pieces -----------------------------------------------------------------------------------------------

static func _add(g: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
	return Props._add(g, mesh, mat, pos, rot, scl, shadow)

## Ground floor walls: the room's walls with a doorway and a lintel when you can walk in, a solid block otherwise.
## Returns the walls' height.
static func _ground_floor(g: Node3D, b: Dictionary, wall: Material, floor_color: String = "#d9b48a") -> float:
	var h := Interiors.WALL_H
	if Interiors.enterable(b):
		for r in Interiors.walls(b):
			_add(g, P.box(r.maxX - r.minX, h, r.maxZ - r.minZ), wall, Vector3((r.minX + r.maxX) / 2.0 - b.x, h / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
		var di := Interiors.door_info(b)
		var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
		var lw := Vector3(Interiors.DOOR_W, h - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, h - Interiors.DOOR_H, Interiors.DOOR_W)
		_add(g, P.box(lw.x, lw.y, lw.z), wall, Vector3(dc.x, (h + Interiors.DOOR_H) / 2.0, dc.y))
		_add(g, P.box(b.w - 0.1, 0.05, b.d - 0.1), P.wood(floor_color), Vector3(0, 0.025, 0), Vector3.ZERO, Vector3.ONE, false)
	else:
		_add(g, P.rbox(b.w, h, b.d, 0.05), wall, Vector3(0, h / 2.0, 0))
	return h

## A plinth of pale stone round the foot of the walls, and the flood's tide line on them.
static func _plinth_and_tide(g: Node3D, b: Dictionary, tide_y: float = 0.62) -> void:
	var stone := P.stone(STONE)
	var tide := P.mat(TIDE)
	for zs in [-1, 1]:
		_add(g, P.box(b.w + 0.16, 0.34, 0.1), stone, Vector3(0, 0.12, zs * (b.d / 2.0 + 0.03)))
		_add(g, P.box(b.w + 0.04, 0.07, 0.04), tide, Vector3(0, tide_y, zs * (b.d / 2.0 + 0.01)), Vector3.ZERO, Vector3.ONE, false)
	for xs in [-1, 1]:
		_add(g, P.box(0.1, 0.34, b.d + 0.16), stone, Vector3(xs * (b.w / 2.0 + 0.03), 0.12, 0))
		_add(g, P.box(0.04, 0.07, b.d + 0.04), tide, Vector3(xs * (b.w / 2.0 + 0.01), tide_y, 0), Vector3.ZERO, Vector3.ONE, false)

## The flood's tide line: a thin dark band round the outside of the walls at height y.
static func _tide_band(g: Node3D, b: Dictionary, y: float) -> void:
	var tide := P.mat(TIDE)
	for zs in [-1, 1]: _add(g, P.box(b.w + 0.04, 0.07, 0.04), tide, Vector3(0, y, zs * (b.d / 2.0 + 0.01)), Vector3.ZERO, Vector3.ONE, false)
	for xs in [-1, 1]: _add(g, P.box(0.04, 0.07, b.d + 0.04), tide, Vector3(xs * (b.w / 2.0 + 0.01), y, 0), Vector3.ZERO, Vector3.ONE, false)

## An upper storey above the ground floor, with a string course between. Returns its node (it fades with the roof).
static func _upper(g: Node3D, b: Dictionary, wall: Material, extra_x: float = 0.0, shift_x: float = 0.0) -> Node3D:
	var n := Node3D.new(); n.name = "upper"; g.add_child(n)
	var h0 := Interiors.WALL_H
	_add(n, P.box(b.w + extra_x, UPPER, b.d), wall, Vector3(shift_x, h0 + UPPER / 2.0, 0))
	_add(n, P.box(b.w + extra_x + 0.12, 0.12, b.d + 0.12), P.stone(STONE), Vector3(shift_x, h0 + 0.02, 0))
	return n

## Windows with shutters on every side but the door's (and beside the door when the wall is long), on each floor.
## Upper-floor windows go on `upper` (so they fade with it while you're in the room below). Returns the glass panes
## (they glow at night).
static func _windows(g: Node3D, b: Dictionary, floors: int, skip: Array = [], upper: Node3D = null) -> Array:
	var glasses: Array = []
	var enter := Interiors.enterable(b)
	for s in ["N", "S", "E", "W"]:
		if s in skip: continue
		var long: float = b.w if s in ["N", "S"] else b.d
		var offs: Array = [-long * 0.27, long * 0.27] if long > 4.6 else [0.0]
		for f in floors:
			var y := 1.4 if f == 0 else Interiors.WALL_H + 1.0
			for off in offs:
				if f == 0 and s == b.door and absf(off - float(b.get("doorOffset", 0.0))) < 1.3: continue
				var host: Node3D = upper if f > 0 and upper != null else g
				var w := Props._window(SHUTTER); Props._on_side(w, b, s, y, off); host.add_child(w); glasses.append(w.get_node("glass"))
				if f == 0 and enter:
					var wi := Props._window(); Props._on_side(wi, b, s, y, off, -Interiors.WALL_T - 0.03); wi.rotation.y += PI; g.add_child(wi); glasses.append(wi.get_node("glass"))
	return glasses

## A small balcony with an iron railing and geraniums, on the upper floor of the door side.
static func _balcony(parent: Node3D, b: Dictionary, side: String) -> void:
	var n := Node3D.new(); Props._on_side(n, b, side, Interiors.WALL_H + 0.05, 0.0, 0.0); parent.add_child(n)
	var iron := P.mat("2f3a34")
	_add(n, P.box(1.7, 0.1, 0.6), P.stone(STONE), Vector3(0, 0, 0.3))
	_add(n, P.box(1.7, 0.04, 0.04), iron, Vector3(0, 0.7, 0.58))
	for i in 9: _add(n, P.box(0.02, 0.7, 0.02), iron, Vector3(-0.8 + i * 0.2, 0.35, 0.58), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		_add(n, P.cyl(0.11, 0.08, 0.18, 8), P.mat("b5653a"), Vector3(-0.5 + i * 0.5, 0.14, 0.35))
		_add(n, P.sphere(0.15, 8, 6), P.mat("4f8f3f"), Vector3(-0.5 + i * 0.5, 0.3, 0.35), Vector3.ZERO, Vector3(1, 0.7, 1), false)
		_add(n, P.sphere(0.07, 6, 4), P.mat("d9333f"), Vector3(-0.45 + i * 0.5, 0.4, 0.42), Vector3.ZERO, Vector3.ONE, false)

## The roof: the shared gable roof (terracotta tiles in the roof shader), with a small brick chimney.
static func _roof(g: Node3D, b: Dictionary, h: float, wall: Material, w: float = -1.0, d: float = -1.0, shift: Vector3 = Vector3.ZERO) -> Node3D:
	var holder := Node3D.new(); holder.position = shift; g.add_child(holder)
	var rw: float = b.w if w < 0.0 else w
	var rd: float = b.d if d < 0.0 else d
	var roof := Props._gable_roof(holder, rw, rd, h, wall, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	var rise: float = roof.get_meta("rise")
	var cx := rw * 0.25 if rw >= rd else 0.0
	var cz := 0.0 if rw >= rd else rd * 0.25
	_add(holder, P.box(0.5, rise + 0.6, 0.5), P.plaster(b.wall), Vector3(cx, h + rise * 0.55 + 0.2, cz - 0.25 if rw >= rd else cz))
	_add(holder, P.box(0.66, 0.12, 0.66), P.stone(STONE), Vector3(cx, h + rise + 0.55, cz - 0.25 if rw >= rd else cz))
	return holder

## A painted sign board with text, on a side of the building.
static func _sign(g: Node3D, b: Dictionary, side: String, y: float, text: String, board: String = "#2f5a3e", ink: String = "#fff3d6", width: float = 2.4, offset: float = 0.0) -> Node3D:
	var n := Node3D.new(); Props._on_side(n, b, side, y, offset, 0.06); g.add_child(n)
	_add(n, P.rbox(width, 0.36, 0.08, 0.05), P.wood(board), Vector3(0, 0, 0.02))
	var txt := Label3D.new(); txt.text = text; txt.font = UiTheme.title_font(); txt.pixel_size = 0.0036
	txt.font_size = mini(52, int(width * 0.86 / (text.length() * 0.62 * txt.pixel_size)))   # the text fits its board
	txt.modulate = Color(ink); txt.outline_size = 0; txt.position = Vector3(0, 0, 0.075); txt.shaded = true
	n.add_child(txt)
	return n

static func _finish(g: Node3D, glasses: Array, over_room: Array, b: Dictionary) -> Node3D:
	g.set_meta("glasses", glasses)
	if Interiors.enterable(b): g.set_meta("fade_parts", Props.fade_parts(over_room))
	return g

# ---- the town ----------------------------------------------------------------------------------------------------

## A two-storey town house in Lombard yellow or faded orange, with green shutters, a balcony and a tiled roof.
static func town_house(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var wall := P.plaster(b.wall)
	_ground_floor(g, b, wall)
	var up := _upper(g, b, wall)
	_plinth_and_tide(g, b)
	var top := Interiors.WALL_H + UPPER
	var roof := _roof(g, b, top, wall)
	var glasses := _windows(g, b, 2, [], up)
	_balcony(up, b, b.door)
	Props._door(g, b, "6a4a30")
	return _finish(g, glasses, [up, roof], b)

## Rina's bar: two storeys of yellow plaster, a green-and-white awning over the door and the tables, a sign.
static func bar(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var wall := P.plaster(b.wall)
	_ground_floor(g, b, wall, "#b9a58a")
	var up := _upper(g, b, wall)
	_plinth_and_tide(g, b)
	var roof := _roof(g, b, Interiors.WALL_H + UPPER, wall)
	var glasses := _windows(g, b, 2, [], up)
	Props._door(g, b, "3f5a3a")
	# the awning, striped, over the whole front
	var aw := Node3D.new(); Props._on_side(aw, b, b.door, 2.15, 0.0, 0.5); g.add_child(aw)
	var n := 9; var span: float = b.w * 0.92
	for i in n:
		_add(aw, P.box(span / n, 0.05, 1.1), P.fabric(SHUTTER if i % 2 == 0 else "f4f1ea"), Vector3(-span / 2.0 + (i + 0.5) * span / n, 0, 0), Vector3(-0.3, 0, 0))
	_sign(up, b, b.door, Interiors.WALL_H + 0.35, "BAR", "#2f5a3e", "#fff3d6", 1.6)
	# a payphone on the corner wall
	var ph := Node3D.new(); Props._on_side(ph, b, "E", 1.2, 1.2, 0.12); g.add_child(ph)
	_add(ph, P.rbox(0.5, 0.7, 0.3, 0.05), P.mat("e0782f"), Vector3.ZERO)
	_add(ph, P.box(0.3, 0.2, 0.04), P.mat("2a2a2a"), Vector3(0, 0.12, 0.16))
	_add(ph, P.capsule(0.05, 0.3), P.mat("2a2a2a"), Vector3(-0.18, -0.05, 0.18), Vector3(0, 0, 0.2))
	# Mattia's photo of the monster catfish, framed by the coffee machine once it's been caught (and let go)
	if Data.world_flags.get("river_town_monster_seen", false) and Interiors.enterable(b):
		var ph2 := Node3D.new(); ph2.position = Vector3(0.4, 1.6, -b.d / 2.0 + Interiors.WALL_T + 0.03); g.add_child(ph2)
		_add(ph2, P.box(0.95, 0.7, 0.04), P.wood("6a4a30"), Vector3.ZERO)
		_add(ph2, P.box(0.82, 0.57, 0.02), P.mat("d9d4c4"), Vector3(0, 0, 0.025), Vector3.ZERO, Vector3.ONE, false)
		_add(ph2, P.sphere(0.5, 12, 8), P.mat("4a4a42"), Vector3(0.02, -0.05, 0.03), Vector3.ZERO, Vector3(0.62, 0.16, 0.02), false)
		_add(ph2, P.sphere(0.12, 8, 6), P.mat("6a6a60"), Vector3(-0.15, 0.08, 0.035), Vector3.ZERO, Vector3(0.6, 1.0, 0.1), false)
		for wsx in [-1, 1]: _add(ph2, P.box(0.22, 0.012, 0.01), P.mat("4a4a42"), Vector3(-0.36, -0.04 + wsx * 0.04, 0.04), Vector3(0, 0, wsx * 0.3), Vector3.ONE, false)
	return _finish(g, glasses, [up, roof], b)

## The arcade: a two-storey orange house whose upper floor reaches out over a covered walk on the piazza side.
static func arcade(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var wall := P.plaster(b.wall)
	var depth := 1.7
	_ground_floor(g, b, wall)
	_plinth_and_tide(g, b)
	var up := _upper(g, b, wall, depth, depth / 2.0)
	_roof(g, b, Interiors.WALL_H + UPPER, wall, b.w + depth, b.d, Vector3(depth / 2.0, 0, 0))
	var glasses := _windows(g, b, 1, ["E"])
	# the covered walk: stone columns and arches, a beamed ceiling, shop windows behind
	var stone := P.stone("e3d6bd")
	for zl in [-4.3, -1.4, 1.4, 4.3]:
		_add(g, P.cyl(0.2, 0.22, Interiors.WALL_H, 12), stone, Vector3(b.w / 2.0 + depth - 0.1, Interiors.WALL_H / 2.0, zl))
		_add(g, P.box(0.5, 0.18, 0.5), stone, Vector3(b.w / 2.0 + depth - 0.1, Interiors.WALL_H - 0.05, zl))
	_add(g, P.box(0.34, 0.3, b.d + 0.2), stone, Vector3(b.w / 2.0 + depth - 0.1, Interiors.WALL_H + 0.1, 0))
	for zl in [-2.85, 0.0, 2.85]:   # brackets under the beam between the columns
		for s in [-1, 1]: _add(g, P.box(0.2, 0.35, 0.5), stone, Vector3(b.w / 2.0 + depth - 0.1, Interiors.WALL_H - 0.2, zl + s * 1.1), Vector3(s * 0.5, 0, 0))
	_add(g, P.box(depth, 0.1, b.d), P.wood("c49a6c"), Vector3(b.w / 2.0 + depth / 2.0, Interiors.WALL_H - 0.05, 0))
	for zl in [-2.6, 2.6]:
		var shop := Props._window(); shop.position = Vector3(b.w / 2.0 + 0.02, 1.3, zl); shop.rotation.y = PI / 2; shop.scale = Vector3(1.8, 1.4, 1); g.add_child(shop)
		glasses.append(shop.get_node("glass"))
	var aw := Node3D.new(); aw.position = Vector3(b.w / 2.0 + 0.3, 2.05, 2.6); aw.rotation.y = PI / 2; g.add_child(aw)
	for i in 6: _add(aw, P.box(0.3, 0.04, 0.6), P.fabric("c0392b" if i % 2 == 0 else "f4f1ea"), Vector3(-0.75 + i * 0.3, 0, 0), Vector3(-0.35, 0, 0))
	var front := Props._window(SHUTTER); Props._on_side(front, b, "W", 3.4, 0.0); g.add_child(front); glasses.append(front.get_node("glass"))
	var e := Node3D.new(); e.position = Vector3(b.w / 2.0 + depth + 0.02, Interiors.WALL_H + 1.0, 0); e.rotation.y = PI / 2; g.add_child(e)
	for zl in [-2.8, 0.0, 2.8]:
		var w := Props._window(SHUTTER); w.position = Vector3(zl, 0, 0); e.add_child(w); glasses.append(w.get_node("glass"))
	g.set_meta("glasses", glasses)
	return g

## The red-brick church, its gable front to the street, with a square bell tower and a clock.
static func church(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var brick := P.plaster(b.wall)
	var h := 4.8
	_add(g, P.rbox(b.w, h, b.d, 0.04), brick, Vector3(0, h / 2.0, 0))
	_plinth_and_tide(g, b, 0.55)
	Props._gable_roof(g, b.w, b.d, h, brick, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	var dark := P.mat("3a2a24")
	# the front: a tall wooden door under a stone arch, a round window above, a little cross on the gable
	var front := Node3D.new(); front.position = Vector3(b.w / 2.0 + 0.03, 0, 0); front.rotation.y = PI / 2; g.add_child(front)
	_add(front, P.box(1.5, 2.4, 0.08), P.wood("5a3a24"), Vector3(0, 1.2, 0))
	var arch := MeshInstance3D.new(); arch.mesh = P.torus(0.82, 0.14, 20); arch.material_override = P.stone(STONE); arch.position = Vector3(0, 2.4, 0.02); arch.rotation.x = PI / 2; front.add_child(arch)
	_add(front, P.cyl(0.75, 0.75, 0.04, 20), P.wood("5a3a24"), Vector3(0, 2.4, 0.0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1), false)
	_add(front, P.torus(0.6, 0.1, 20), P.stone(STONE), Vector3(0, 4.3, 0.05), Vector3(PI / 2, 0, 0))
	var rose := _add(front, P.cyl(0.55, 0.55, 0.03, 20), P.unique_mat("6a8fbf", "ffcf6b", 0.0), Vector3(0, 4.3, 0.03), Vector3(PI / 2, 0, 0), Vector3.ONE, false)
	_add(front, P.box(0.08, 0.6, 0.08), P.mat("2f3a34"), Vector3(0, h + Props.roof_rise(b.w, b.d) + 0.55, -0.1))
	_add(front, P.box(0.36, 0.08, 0.08), P.mat("2f3a34"), Vector3(0, h + Props.roof_rise(b.w, b.d) + 0.65, -0.1))
	var glasses: Array = [rose]
	# tall arched windows down the sides
	for zs in [-1, 1]:
		for xl in [-3.0, -0.6, 1.8]:
			_add(g, P.box(0.6, 1.8, 0.05), dark, Vector3(xl, 2.6, zs * (b.d / 2.0 + 0.02)))
			_add(g, P.cyl(0.3, 0.3, 0.05, 12), dark, Vector3(xl, 3.5, zs * (b.d / 2.0 + 0.02)), Vector3(PI / 2, 0, 0))
	# the bell tower at the front corner
	var t := Node3D.new(); t.position = Vector3(b.w / 2.0 - 1.2, 0, -b.d / 2.0 + 1.2); g.add_child(t)
	var th := 9.6
	_add(t, P.rbox(2.4, th, 2.4, 0.04), brick, Vector3(0, th / 2.0, 0))
	for k in 4:
		var a := k * PI / 2.0
		var side := Node3D.new(); side.rotation.y = a; t.add_child(side)
		_add(side, P.box(0.9, 1.4, 0.1), dark, Vector3(0, th - 1.4, 1.2))
		_add(side, P.cyl(0.45, 0.45, 0.1, 12), dark, Vector3(0, th - 0.7, 1.2), Vector3(PI / 2, 0, 0))
		_add(side, P.box(2.6, 0.18, 0.1), P.stone(STONE), Vector3(0, th - 2.3, 1.22))
	_add(t, P.cyl(0.38, 0.5, 0.6, 12), P.mat("b08d3c"), Vector3(0, th - 1.5, 0))
	_add(t, P.box(2.8, 0.25, 2.8), P.stone(STONE), Vector3(0, th + 0.1, 0))
	var cap := MeshInstance3D.new(); cap.mesh = P.cone(2.0, 2.2, 4); cap.material_override = Props.roof_material(b.roof)
	cap.position = Vector3(0, th + 1.3, 0); cap.rotation.y = PI / 4; t.add_child(cap)
	# the clock, facing the street
	var clock := Node3D.new(); clock.position = Vector3(1.22, th - 3.2, 0); clock.rotation.y = PI / 2; t.add_child(clock)
	_add(clock, P.cyl(0.62, 0.62, 0.06, 24), P.mat("f4f1ea"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_add(clock, P.torus(0.62, 0.05, 24), P.mat("2f3a34"), Vector3(0, 0, 0.02), Vector3(PI / 2, 0, 0))
	_add(clock, P.box(0.05, 0.42, 0.02), P.mat("2f3a34"), Vector3(0, 0.17, 0.05))
	_add(clock, P.box(0.32, 0.05, 0.02), P.mat("2f3a34"), Vector3(0.13, 0, 0.05))
	g.set_meta("glasses", glasses)
	return g

## Primo's bike workshop: one storey in yellow, wheels hung on the front, a sign over the door.
static func workshop(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var wall := P.plaster(b.wall)
	_ground_floor(g, b, wall, "#a99a86")
	_plinth_and_tide(g, b)
	var roof := _roof(g, b, Interiors.WALL_H, wall)
	var glasses := _windows(g, b, 1)
	Props._door(g, b, "3f5a3a")
	_sign(g, b, b.door, 2.24, "RAMPOLDI CYCLES", "#2f5a3e", "#fff3d6", 2.6)
	var iron := P.mat("2f3a34")
	for off in [-2.2, 2.2]:
		var wh := Node3D.new(); Props._on_side(wh, b, b.door, 1.75, off, 0.12); g.add_child(wh)
		_add(wh, P.torus(0.42, 0.035, 24), iron, Vector3.ZERO, Vector3(PI / 2, 0, 0))
		for k in 4: _add(wh, P.box(0.012, 0.8, 0.012), P.mat("c9c9c9"), Vector3.ZERO, Vector3(0, 0, k * PI / 4.0), Vector3.ONE, false)
	return _finish(g, glasses, [roof], b)

## The levee warden's keeper's house: two storeys in the river authority's oxblood, pale corner stones, a plaque.
static func keeper_house(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var wall := P.plaster(b.wall)
	_ground_floor(g, b, wall, "#c9b08a")
	var up := _upper(g, b, wall)
	_plinth_and_tide(g, b, 0.5)
	var roof := _roof(g, b, Interiors.WALL_H + UPPER, wall)
	var glasses := _windows(g, b, 2, [], up)
	Props._door(g, b, "3a4a3f")
	var stone := P.stone("efe6d6")
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		for k in 7:
			var big := k % 2 == 0
			var y := 0.3 + k * 0.6
			var host: Node3D = g if y < Interiors.WALL_H else up
			_add(host, P.box(0.5 if big else 0.3, 0.3, 0.3 if big else 0.5), stone, Vector3(c[0] * (b.w / 2.0 - (0.2 if big else 0.1)), y, c[1] * (b.d / 2.0 - (0.1 if big else 0.2))))
	_sign(up, b, b.door, Interiors.WALL_H + 0.42, "KEEPER'S HOUSE No. 12", "#efe6d6", "#7a2e2a", 1.7)
	return _finish(g, glasses, [up, roof], b)

## The valley railway's little brick station: two storeys, a canopy over the platform, the town's name, a clock.
static func station(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var brick := P.plaster(b.wall)
	_ground_floor(g, b, brick)
	var up := _upper(g, b, brick)
	_plinth_and_tide(g, b, 0.4)
	_roof(g, b, Interiors.WALL_H + UPPER, brick)
	var glasses := _windows(g, b, 2, [], up)
	Props._door(g, b, "3f5a3a")
	_sign(up, b, b.door, Interiors.WALL_H + 0.3, "BOCCAPIOPPO", "#efe6d6", "#2f3a34", 3.2)
	_sign(g, b, "E", 2.2, "BOCCAPIOPPO", "#efe6d6", "#2f3a34", 2.4)
	# the platform canopy, on thin iron columns, over the track side
	var iron := P.mat("2f3a34")
	_add(g, P.box(2.4, 0.1, b.d + 0.6), P.wood("8f8a7e"), Vector3(b.w / 2.0 + 1.2, 2.75, 0), Vector3(0, 0, -0.12))
	for zl in [-1.6, 1.6]: _add(g, P.cyl(0.06, 0.06, 2.0, 8), iron, Vector3(b.w / 2.0 + 1.8, 1.7, zl))
	_add(g, P.box(2.3, 0.3, b.d + 1.0), P.stone("c9bfae"), Vector3(b.w / 2.0 + 1.2, 0.1, 0))
	var clock := Node3D.new(); clock.position = Vector3(b.w / 2.0 + 1.8, 2.45, 0); g.add_child(clock)
	for s in [-1, 1]:
		_add(clock, P.cyl(0.24, 0.24, 0.06, 16), P.mat("f4f1ea"), Vector3(s * 0.04, 0, 0), Vector3(0, 0, PI / 2))
		_add(clock, P.box(0.02, 0.16, 0.02), iron, Vector3(s * 0.08, 0.06, 0))
	_add(clock, P.box(0.04, 0.3, 0.04), iron, Vector3(0, 0.25, 0))
	g.set_meta("glasses", glasses)
	return g

## A farm courtyard: brick wings round a yard open to the east, a hayloft with a brick lattice, an arched portico.
static func farm(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var brick := P.plaster(b.wall)
	var dark := P.mat("3a2a24")
	var wing := 3.0
	var h := 3.4
	var parts := [[0.0, -b.d / 2.0 + wing / 2.0, b.w, wing], [-b.w / 2.0 + wing / 2.0, 0.0, wing, b.d - wing * 2.0], [0.0, b.d / 2.0 - wing / 2.0, b.w, wing]]
	for p in parts:
		var n := Node3D.new(); n.position = Vector3(p[0], 0, p[1]); g.add_child(n)
		_add(n, P.rbox(p[2], h, p[3], 0.04), brick, Vector3(0, h / 2.0, 0))
		Props._gable_roof(n, p[2], p[3], h, brick, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	# the hayloft lattice on the north wing, facing the yard; the portico's arches on the south wing
	for i in 8:
		for j in 3:
			_add(g, P.box(0.22, 0.16, 0.05), dark, Vector3(-4.6 + i * 1.25 + (j % 2) * 0.3, 2.2 + j * 0.38, -b.d / 2.0 + wing + 0.03))
	for i in 4:
		var x := -3.0 + i * 2.2
		_add(g, P.box(1.4, 1.7, 0.05), dark, Vector3(x, 0.85, b.d / 2.0 - wing - 0.03))
		_add(g, P.cyl(0.7, 0.7, 0.05, 14), dark, Vector3(x, 1.7, b.d / 2.0 - wing - 0.03), Vector3(PI / 2, 0, 0))
	# the yard's gate between brick pillars, closed, and straw in the yard
	for zs in [-1.6, 1.6]: _add(g, P.box(0.6, 2.2, 0.6), brick, Vector3(b.w / 2.0 - 0.3, 1.1, zs))
	for k in 6: _add(g, P.box(0.12, 1.5, 0.3), P.wood("8a6a50"), Vector3(b.w / 2.0 - 0.3, 0.8, -1.25 + k * 0.5))
	_add(g, P.box(b.w - wing - 0.6, 0.04, b.d - wing * 2.0), P.mat("c9b06a"), Vector3(wing / 2.0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	for p in [[1.0, -0.8], [3.4, 1.0]]: _add(g, P.cyl(0.6, 0.6, 1.0, 12), P.mat("d9c27a"), Vector3(p[0], 0.5, p[1]), Vector3(0, 0, PI / 2))
	return g

# ---- the floodplain ----------------------------------------------------------------------------------------------

## The houseboat, stranded on the mud: a dark green hull sunk to the waterline in silt, a white cabin with round
## windows, sky-blue trim, a stovepipe and its name on the bow. You walk into the cabin.
static func houseboat(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var white := P.wood("e9e2d0")
	var trim := P.mat("8fc0dc")
	_ground_floor(g, b, white, "#b98d5e")
	var hull := P.mat(b.roof)
	# The hull comes up to the cabin's floor and no higher inside it (it used to fill the cabin to 25 cm above the
	# floorboards, so whoever stood inside was up to their shins in it); round the cabin, its bulwarks rise to the
	# gunwale, capped in white, with a gap at the door.
	_add(g, P.rbox(b.w + 1.2, 0.65, b.d + 0.7, 0.2), hull, Vector3(-0.2, -0.33, 0))
	var white_cap := P.mat("f4f1ea")
	var bw := [[Vector3(-0.2, 0.0, -(b.d / 2.0 + 0.175)), Vector3(b.w + 1.2, 0.0, 0.35)], [Vector3(-0.2, 0.0, b.d / 2.0 + 0.175), Vector3(b.w + 1.2, 0.0, 0.35)],
		[Vector3(-b.w / 2.0 - 0.4, 0.0, 0.0), Vector3(0.8, 0.0, b.d)]]
	var gap := Interiors.DOOR_W / 2.0 + 0.1
	for zs in [-1, 1]: bw.append([Vector3(b.w / 2.0 + 0.2, 0.0, zs * (gap + (b.d / 2.0 - gap) / 2.0)), Vector3(0.4, 0.0, b.d / 2.0 - gap)])
	for piece in bw:
		var at: Vector3 = piece[0]; var sz: Vector3 = piece[1]
		_add(g, P.box(sz.x, 0.25, sz.z), hull, at + Vector3(0, 0.125, 0))
		_add(g, P.box(sz.x + 0.02, 0.05, sz.z + 0.02), white_cap, at + Vector3(0, 0.27, 0))
	if not b.get("afloat", false): _add(g, P.box(b.w + 1.24, 0.22, b.d + 0.74), P.mat("6b5a42"), Vector3(-0.2, -0.45, 0))   # mud to the waterline
	var bow := MeshInstance3D.new(); bow.mesh = P.sphere(1.0, 12, 8); bow.material_override = hull
	bow.position = Vector3(-b.w / 2.0 - 0.75, -0.2, 0); bow.scale = Vector3(0.9, 0.45, (b.d + 0.7) / 2.0); g.add_child(bow)
	for s in [-1, 1]: _add(g, P.box(b.w + 0.9, 0.06, 0.06), trim, Vector3(-0.2, Interiors.WALL_H - 0.05, s * (b.d / 2.0 + 0.02)))
	var roof := Node3D.new(); roof.name = "roof"; g.add_child(roof)
	_add(roof, P.rbox(b.w + 0.5, 0.16, b.d + 0.5, 0.06), P.mat("f4f1ea"), Vector3(0, Interiors.WALL_H + 0.08, 0))
	_add(roof, P.box(b.w + 0.56, 0.08, b.d + 0.56), trim, Vector3(0, Interiors.WALL_H + 0.02, 0))
	_add(roof, P.cyl(0.09, 0.09, 0.9, 8), P.mat("2f3a34"), Vector3(-1.6, Interiors.WALL_H + 0.6, -0.6))
	_add(roof, P.cyl(0.14, 0.1, 0.1, 8), P.mat("2f3a34"), Vector3(-1.6, Interiors.WALL_H + 1.05, -0.6))
	var glasses: Array = []
	for s in [-1, 1]:
		for xl in [-2.6, -1.2, 0.6, 2.0]:
			for inside in [false, true]:
				var pw := Node3D.new(); pw.position = Vector3(xl, 1.45, s * (b.d / 2.0 + (0.02 if not inside else -Interiors.WALL_T - 0.02))); pw.rotation.y = 0.0 if s > 0 else PI
				if inside: pw.rotation.y += PI
				g.add_child(pw)
				_add(pw, P.torus(0.28, 0.06, 18), P.mat("8fc0dc"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
				var gl := _add(pw, P.cyl(0.25, 0.25, 0.02, 16), P.unique_mat("a9ddf5", "ffcf6b", 0.0), Vector3.ZERO, Vector3(PI / 2, 0, 0), Vector3.ONE, false)
				glasses.append(gl)
	Props._door(g, b, "8fc0dc")
	var lbl := Label3D.new(); lbl.text = "SPERANZA"; lbl.font = UiTheme.title_font(); lbl.font_size = 48; lbl.pixel_size = 0.004
	lbl.modulate = Color("f4f1ea"); lbl.outline_size = 0; lbl.shaded = true
	lbl.position = Vector3(-b.w / 2.0 + 0.4, -0.05, b.d / 2.0 + 0.37); g.add_child(lbl)
	# a gangplank down from the stern to the mud (afloat, she has a jetty instead: scenery)
	if not b.get("afloat", false): _add(g, P.box(0.7, 0.06, 1.4), P.wood("9a7a5a"), Vector3(b.w / 2.0 + 0.9, 0.08, 0), Vector3(0, PI / 2, -0.18))
	return _finish(g, glasses, [roof], b)

## Gildo and Mattia's fishing shack: tarred planks, a corrugated tin roof, nets drying on poles.
static func shack(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var tar := P.wood(b.wall)
	_ground_floor(g, b, tar, "#8a6a50")
	for k in 6:   # plank seams
		for s in [-1, 1]: _add(g, P.box(b.w + 0.02, 0.03, 0.02), P.mat("3a2f26"), Vector3(0, 0.35 + k * 0.38, s * (b.d / 2.0 + 0.01)), Vector3.ZERO, Vector3.ONE, false)
	_tide_band(g, b, 0.75)   # (a band round the outside: it used to be a slab right across the room, at knee height)
	var roof := Node3D.new(); roof.name = "roof"; g.add_child(roof)
	var tin := P.mat(b.roof)
	for k in 9:
		_add(roof, P.box(b.w + 0.6, 0.05, 0.56), tin, Vector3(0, Interiors.WALL_H + 0.18 + (0.02 if k % 2 else 0.0), -b.d / 2.0 - 0.3 + k * 0.58), Vector3(-0.08, 0, 0))
	var glasses := _windows(g, b, 1, ["N", "S"])
	Props._door(g, b, "5a4a3a")
	var nets := P.fabric("8d9a7a")
	for xl in [-1.4, 0.4]:
		_add(g, P.cyl(0.05, 0.05, 2.0, 6), P.wood("6a4a30"), Vector3(xl, 1.0, b.d / 2.0 + 0.9))
	_add(g, P.box(1.9, 1.2, 0.04), nets, Vector3(-0.5, 1.2, b.d / 2.0 + 0.92))
	return _finish(g, glasses, [roof], b)

## Wanda's dance hall on stilts at the meeting of the rivers: white boards and sky-blue trim, tall windows (two
## broken by the flood), a veranda with a ramp, and its name over the door. The floor is the raised platform the
## ground script shapes; the lattice skirt hides it.
static func dance_hall(b: Dictionary) -> Node3D:
	var RT = load("res://scripts/locations/river_town.gd")   # the platform's shape (loaded here, not preloaded: that script preloads this one)
	var g := Node3D.new()
	var white := P.wood("f4f1ea")
	var blue := P.mat("8fc0dc")
	_ground_floor(g, b, white, "#c49a6c")
	# parquet in a herringbone of two tones, with flood mud on it
	for i in 7:
		_add(g, P.box(b.w - 0.6, 0.012, 0.36), P.wood("b98a5a"), Vector3(0, 0.055, -2.4 + i * 0.8), Vector3.ZERO, Vector3.ONE, false)
	var open: bool = Data.world_flags.get("river_town_hall_open", false)   # after its first dance: scrubbed, mended, lit
	if not open:
		for p in [[-1.5, 0.6, 1.4], [1.8, -1.0, 1.0], [2.6, 1.6, 0.7]]:
			_add(g, P.cyl(p[2], p[2], 0.015, 12), P.mat("7a6a50"), Vector3(p[0], 0.065, p[1]), Vector3.ZERO, Vector3(1, 1, 0.7), false)
	# the platform: lattice skirt and stilts round the floor and the veranda, from the floodplain up
	var lattice := P.wood("f4f1ea")
	var base: float = RT.FLOOD_H - RT.DANCE_H - 0.1
	var dance: Rect2 = RT.DANCE; var veranda: Rect2 = RT.DANCE_VERANDA
	var outline := [Rect2(dance.position - Vector2(b.x, b.z), dance.size), Rect2(veranda.position - Vector2(b.x, b.z), veranda.size)]
	for r in outline:
		for side in 4:
			var horiz := side < 2
			var a := Vector2(r.position.x, r.position.y + (0.0 if side == 0 else r.size.y)) if horiz else Vector2(r.position.x + (0.0 if side == 2 else r.size.x), r.position.y)
			var L: float = r.size.x if horiz else r.size.y
			var n := int(L / 0.5)
			for k in n + 1:
				var p := a + (Vector2(k * L / n, 0) if horiz else Vector2(0, k * L / n))
				_add(g, P.box(0.08, -base, 0.08), lattice, Vector3(p.x, base / 2.0, p.y), Vector3(0, 0, 0.5 if k % 2 else -0.5), Vector3.ONE, false)
			_add(g, P.box(L if horiz else 0.1, 0.12, 0.1 if horiz else L), blue, Vector3(a.x + (L / 2.0 if horiz else 0.0), -0.06, a.y + (0.0 if horiz else L / 2.0)))
		for c in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
			_add(g, P.cyl(0.13, 0.15, -base + 0.1, 8), P.wood("8a6a50"), Vector3(c.x, base / 2.0, c.y))
	# trim, roof and windows
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: _add(g, P.box(0.18, Interiors.WALL_H, 0.18), blue, Vector3(c[0] * (b.w / 2.0 - 0.05), Interiors.WALL_H / 2.0, c[1] * (b.d / 2.0 - 0.05)))
	for zs in [-1, 1]: _add(g, P.box(b.w + 0.1, 0.14, 0.06), blue, Vector3(0, Interiors.WALL_H - 0.07, zs * (b.d / 2.0 + 0.03)))
	var roof := Node3D.new(); roof.name = "roofnode"; g.add_child(roof)
	var rr := Props._gable_roof(roof, b.w, b.d, Interiors.WALL_H, white, Props.roof_material(b.roof), Color(b.roof).darkened(0.25))
	rr.scale.y = 0.7
	var glasses: Array = []
	var k := 0
	for s in ["N", "S", "E"]:
		var long: float = b.w if s in ["N", "S"] else b.d
		for off in ([-2.8, 0.0, 2.8] if long > 6.0 else [-1.4, 1.4]):
			var w := Props._window("8fc0dc"); Props._on_side(w, b, s, 1.35, off); w.scale = Vector3(1.0, 1.35, 1.0); g.add_child(w)
			k += 1
			if (k == 2 or k == 6) and not open:   # broken by the flood: dark empty panes, a shutter hanging
				var gl: MeshInstance3D = w.get_node("glass"); gl.material_override = P.mat("2a2a2e")
				var sh := w.get_child(w.get_child_count() - 1)
				if sh is MeshInstance3D: sh.rotation.z = 0.6
			else: glasses.append(w.get_node("glass"))
			var wi := Props._window(); Props._on_side(wi, b, s, 1.35, off, -Interiors.WALL_T - 0.03); wi.rotation.y += PI; wi.scale = Vector3(1.0, 1.35, 1.0); g.add_child(wi)
	Props._door(g, b, "8fc0dc")
	# the veranda: deck, railings, a canopy on posts, and a ramp down to the floodplain
	var v: Rect2 = outline[1]
	_add(g, P.box(v.size.x, 0.08, v.size.y), P.wood("c49a6c"), Vector3(v.get_center().x, 0.0, v.get_center().y), Vector3.ZERO, Vector3.ONE, false)
	for zs in [v.position.y, v.end.y]:
		_add(g, P.box(v.size.x, 0.06, 0.06), white, Vector3(v.get_center().x, 0.85, zs))
		for xk in 4: _add(g, P.box(0.06, 0.85, 0.06), white, Vector3(v.position.x + xk * v.size.x / 3.0, 0.42, zs))
	var can := Node3D.new(); can.position = Vector3(v.get_center().x - 0.1, 2.3, v.get_center().y); g.add_child(can)
	_add(can, P.box(v.size.x + 0.6, 0.08, v.size.y + 0.4), blue, Vector3.ZERO, Vector3(0, 0, 0.12))
	for zs in [v.position.y + 0.1, v.end.y - 0.1]: _add(g, P.cyl(0.06, 0.06, 2.3, 8), white, Vector3(v.position.x + 0.1, 1.15, zs))
	var ramp_len: float = veranda.position.x - 7.4
	var drop: float = RT.DANCE_H - RT.FLOOD_H
	_add(g, P.box(sqrt(ramp_len * ramp_len + drop * drop), 0.08, 1.7), P.wood("b98a5a"), Vector3(v.position.x - ramp_len / 2.0, -drop / 2.0 + 0.02, 0.0), Vector3(0, 0, atan2(drop, ramp_len)))
	# the bulbs for the dance: strung along the veranda's eaves, dark until the hall reopens, then lit every evening
	var bulbs := Node3D.new(); bulbs.name = "dance_bulbs"; g.add_child(bulbs)
	var bulb_mat := P.unique_mat("fff1b8", "ffcf6b", 2.2 if open else 0.0)
	for i in 10:
		var bz := v.position.y - 1.0 + i * (v.size.y + 2.0) / 9.0
		_add(bulbs, P.sphere(0.07, 6, 4), bulb_mat, Vector3(v.position.x + 0.15, 2.2 - 0.1 * sin(i * 0.9), bz), Vector3.ZERO, Vector3.ONE, false)
	if open:
		var li := OmniLight3D.new(); li.light_color = Color("ffcf6b"); li.light_energy = 1.1; li.omni_range = 6.0
		li.position = Vector3(v.position.x - 0.6, 2.0, v.get_center().y); bulbs.add_child(li)
	_sign(g, b, "W", Interiors.WALL_H + 0.5, "WANDA'S DANCE HALL", "#8fc0dc", "#f4f1ea", 3.2)
	return _finish(g, glasses, [roof], b)

## The drainage pumping house of 1934, dug into the levee's river side: red brick under a hipped tin roof, an arched
## window, the big outfall pipe from under the levee into the river, and its drive on the quay side, a flywheel that
## turns once something powers it (machine target "river_town_pump", a cell east of its wall).
static func pumphouse(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var brick := P.plaster(b.wall)
	var h := 2.6
	_add(g, P.rbox(b.w, h, b.d, 0.04), brick, Vector3(0, h / 2.0, 0))
	for zs in [-1, 1]: _add(g, P.box(b.w + 0.12, 0.2, 0.12), P.stone(STONE), Vector3(0, h - 0.1, zs * (b.d / 2.0 + 0.02)))
	_add(g, P.box(b.w + 0.12, 0.3, b.d + 0.12), P.stone(STONE), Vector3(0, 0.15, 0))
	_tide_band(g, b, 1.1)
	var roof := Props._gable_roof(g, b.w + 0.3, b.d + 0.3, h, brick, P.mat("8a8f8f"), Color("6f7474"))
	roof.scale.y = 0.6
	# the arched window and the door on the quay side, a sign above
	for off in [-0.9, 0.9]:
		var w := Props._window("2f3a34"); Props._on_side(w, b, "E", 1.5, off); g.add_child(w)
	_sign(g, b, "E", h - 0.45, "PUMPING HOUSE 1934", "#6f7474", "#f4f1ea", 2.4)
	# the outfall pipe: out of the levee beside the house, across the quay and over its edge into the river
	var pipe := P.mat("4f5a5a")
	var pz: float = -b.d / 2.0 - 0.75
	_add(g, P.cyl(0.32, 0.32, 5.8, 14), pipe, Vector3(2.4, 0.1, pz), Vector3(0, 0, PI / 2))
	_add(g, P.cyl(0.4, 0.4, 0.14, 14), pipe, Vector3(5.3, 0.1, pz), Vector3(0, 0, PI / 2))
	# the drive: a bearing on the east wall at shaft height, where a shaft on the quay meets it, and the flywheel beside
	var drive_z := 0.5
	_add(g, P.box(0.3, 0.45, 0.45), P.mat("3a3a40"), Vector3(b.w / 2.0 + 0.12, 0.42, drive_z))
	var fly := Node3D.new(); fly.set_script(load("res://scripts/locations/river_town/spinner.gd"))
	fly.set("target", "river_town_pump"); fly.set("axis", Vector3.UP)
	fly.position = Vector3(b.w / 2.0 + 0.12, 0.95, -0.6); fly.rotation = Vector3(0, 0, PI / 2); g.add_child(fly)
	_add(fly, P.torus(0.42, 0.06, 20), P.mat("3a3a40"), Vector3.ZERO, Vector3.ZERO)
	for k in 4: _add(fly, P.box(0.05, 0.05, 0.82), P.mat("3a3a40"), Vector3.ZERO, Vector3(0, k * PI / 4.0, 0))
	_add(fly, P.cyl(0.08, 0.08, 0.2, 8), P.mat("c0392b"), Vector3.ZERO)
	return g

# ---- the east bank -----------------------------------------------------------------------------------------------

## The sawmill's office: a small brick hut beside the open shed (the shed itself is scenery you can walk under).
static func sawmill_office(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var brick := P.plaster(b.wall)
	_ground_floor(g, b, brick)
	_plinth_and_tide(g, b, 0.45)
	_roof(g, b, Interiors.WALL_H, brick)
	var glasses := _windows(g, b, 1)
	Props._door(g, b, "6a4a30")
	_sign(g, b, b.door, Interiors.WALL_H + 0.35, "GANDINI SAWMILL", "#6a4a30", "#fff3d6", 3.2)
	g.set_meta("glasses", glasses)
	return g
