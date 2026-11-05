extends RefCounted
## Toriano's landmarks, each built from its layout entry (local coordinates: origin at the building's centre, at
## its base). Shapes are merged into a few meshes per building; façades are painted by the kit's shader.

const Kit := preload("res://scripts/locations/metropolis/kit.gd")
const P := preload("res://scripts/world/palette.gd")
const Props := preload("res://scripts/world/props.gd")

const MARBLE := Color("efe4dc")
const MARBLE_SHADE := Color("ddd0c6")
const GOLD := Color("ffcf4a")
const IRON := Color("2e2b28")
const BRICK := Color("b5553f")

static func _box(g: Node3D, size: Vector3, pos: Vector3, mat: Material, name: String = "") -> MeshInstance3D:
	var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; m.mesh = bm
	m.position = pos; m.material_override = mat
	if name != "": m.name = name
	g.add_child(m)
	return m

## A pinnacle: a square shaft with a pyramid cap and a tiny statue on top.
static func pinnacle(m: Kit.Merge, base: Vector3, h: float, r: float = 0.35, col: Color = MARBLE) -> void:
	m.box(base + Vector3(0, h * 0.6 / 2.0, 0), Vector3(r * 2.0, h * 0.6, r * 2.0), col)
	m.pyramid(base + Vector3(0, h * 0.6, 0), r * 1.1, h * 0.4, col)
	m.box(base + Vector3(0, h + 0.18, 0), Vector3(0.18, 0.36, 0.18), col.darkened(0.05))

## The Golden Angel: a gilded figure with spread wings and a trumpet raised to the sky.
static func angel() -> Node3D:
	var g := Node3D.new(); g.name = "golden_angel"
	var m := Kit.Merge.new()
	m.cone(Vector3.ZERO, 0.42, 1.5, GOLD, 10)                               # robe
	m.box(Vector3(0, 1.62, 0), Vector3(0.3, 0.32, 0.3), GOLD)              # head
	for s in [-1, 1]:
		m.box(Vector3(s * 0.42, 1.25, -0.1), Vector3(0.62, 0.5, 0.06), GOLD.lightened(0.1), s * 0.35)    # wings
		m.box(Vector3(s * 0.7, 1.55, -0.12), Vector3(0.4, 0.34, 0.05), GOLD.lightened(0.1), s * 0.55)
	m.box(Vector3(0.18, 1.7, 0.35), Vector3(0.08, 0.08, 0.7), GOLD.darkened(0.1))   # trumpet
	var mat := P.unique_mat(Color.WHITE, GOLD, 0.25)
	mat.vertex_color_use_as_albedo = true; mat.vertex_color_is_srgb = true; mat.metallic = 0.5; mat.roughness = 0.35
	g.add_child(m.node(mat, "figure"))
	return g

## The nave: a room you can walk into (pews, pillars, the altar), its upper walls, roof, rows of pinnacles and the
## crossing tower with the great spire and the Golden Angel, all fading while you're inside.
static func duomo_nave(b: Dictionary) -> Node3D:
	var g := Kit.room(b, Kit.GOTHIC)
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var over := Node3D.new(); over.name = "over"; g.add_child(over)
	var m := Kit.Merge.new()
	# a steep pale roof along the nave
	m.gable(Vector3(0, h + 0.4, 0), d + 1.0, 4.0, w, MARBLE_SHADE, PI / 2.0)
	# pinnacles along both eaves
	for s in [-1, 1]:
		var n := int(w / 4.0)
		for i in n + 1:
			pinnacle(m, Vector3(-w / 2.0 + w * i / n, h + 0.4, s * (d / 2.0 + 0.2)), 3.4)
	# the crossing tower: an octagonal drum, a tall spire, the Golden Angel on top
	var tx := w * 0.16
	m.cyl(Vector3(tx, h + 1.5, 0), 5.0, 7.0, MARBLE, 8)
	for i in 8:
		var a := TAU * i / 8.0
		pinnacle(m, Vector3(tx + cos(a) * 5.0, h + 8.5, sin(a) * 5.0), 3.0)
	m.cyl(Vector3(tx, h + 8.5, 0), 1.6, 12.0, MARBLE, 8)
	m.cone(Vector3(tx, h + 20.5, 0), 1.9, 9.0, MARBLE, 8)
	over.add_child(m.node(Kit.vc_mat(), "spires"))
	var a := angel(); a.position = Vector3(tx, h + 29.4, 0); over.add_child(a)
	g.set_meta("angel", a)
	# the floor: pale marble instead of boards
	var fl := Kit.Merge.new()
	fl.box(Vector3(0, 0.03, 0), Vector3(w - 0.5, 0.04, d - 0.5), Color("e7ddd2"))
	for i in int(w / 2.0):
		fl.box(Vector3(-w / 2.0 + 1.0 + i * 2.0, 0.055, 0), Vector3(1.0, 0.01, d - 0.6), Color("cfc2b5"))
	g.add_child(fl.node(Kit.vc_mat(), "marble_floor"))
	var faded: Array = g.get_meta("fade_parts")
	g.set_meta("fade_parts", faded + Kit.fade_parts([over]))
	return g

## The west front, drawn whole by its north half (the south half is just a collider): marble buttresses with tall
## pinnacles, a gable rising over the middle, three portals and the great doorway that leads into the nave.
static func duomo_front(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	if not String(b.id).ends_with("_n"): return g
	var off := Vector3(0, 0, 0.0 - float(b.z))   # the whole front is centred on the cathedral's axis (z = 0)
	var h := float(b.h); var t := float(b.w)
	var mat := Kit.facade(MARBLE, 0.3 + h, {"style": Kit.GOTHIC, "shops": 0.0, "seed": 3.0})
	for side in [[-15.0, -2.0], [2.0, 15.0]]:
		_box(g, Vector3(t, h, side[1] - side[0]), off + Vector3(0, h / 2.0, (side[0] + side[1]) / 2.0), mat)
	_box(g, Vector3(t, h - 5.2, 4.0), off + Vector3(0, 5.2 + (h - 5.2) / 2.0, 0), mat)
	var m := Kit.Merge.new()
	m.gable(off + Vector3(0, h, 0), 30.0, 7.0, t, MARBLE, PI / 2.0)
	for zz in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:   # buttresses with pinnacles
		var bz := clampf(zz, -14.6, 14.6)
		m.box(off + Vector3(-t / 2.0 - 0.4, h / 2.0, bz), Vector3(1.0, h, 1.0), MARBLE_SHADE)
		pinnacle(m, off + Vector3(-t / 2.0 - 0.4, h, bz), 5.0 if absf(zz) > 4.0 else 7.0, 0.5)
	pinnacle(m, off + Vector3(0, h + 7.0, 0), 4.0, 0.45)
	var door := Color("3a2a22")
	for zz in [-9.0, 9.0]:   # side portals, painted shut
		m.box(off + Vector3(-t / 2.0 - 0.02, 2.0, zz), Vector3(0.06, 4.0, 2.2), door)
	m.box(off + Vector3(-t / 2.0 - 0.03, 5.1, 0), Vector3(0.1, 0.4, 4.4), MARBLE_SHADE)   # lintel over the great door
	m.box(off + Vector3(-t / 2.0 - 0.03, 2.6, -2.1), Vector3(0.12, 5.2, 0.3), MARBLE_SHADE)
	m.box(off + Vector3(-t / 2.0 - 0.03, 2.6, 2.1), Vector3(0.12, 5.2, 0.3), MARBLE_SHADE)
	# the rose window: a round of coloured glass high in the gable
	for i in 12:
		var a := TAU * i / 12.0
		m.box(off + Vector3(-t / 2.0 - 0.04, h - 3.2 + sin(a) * 1.6, cos(a) * 1.6), Vector3(0.05, 0.9, 0.9), [Color("4a6fb0"), Color("b04a4a"), Color("d9b04a")][i % 3], 0.0)
	g.add_child(m.node(Kit.vc_mat(), "front"))
	return g

## An aisle: marble walls with tall windows, its roof a terrace paved in marble slabs, pinnacles along the parapet and
## flying buttresses leaning against the nave.
static func duomo_aisle(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	_box(g, Vector3(w, h, d), Vector3(0, h / 2.0, 0), Kit.facade(MARBLE, 0.3 + h, {"style": Kit.GOTHIC, "shops": 0.0, "seed": 5.0, "floor_h": 2.6}))
	var m := Kit.Merge.new()
	for i in int(w / 1.6):   # the terrace's marble slabs
		m.box(Vector3(-w / 2.0 + 0.8 + i * 1.6, h + 0.01, 0), Vector3(1.56, 0.02, d - 0.1), MARBLE if i % 2 == 0 else MARBLE_SHADE.lightened(0.3))
	var outer := -1.0 if float(b.z) < 0.0 else 1.0   # the outer edge faces away from the nave
	var n := int(w / 4.0)
	for i in n + 1:
		var x := -w / 2.0 + w * i / n
		pinnacle(m, Vector3(x, h + 1.1, outer * (d / 2.0 - 0.2)), 4.2, 0.4)
		if i > 0 and i < n:   # a flying buttress from the parapet up to the nave wall
			for k in 5:
				var t := (k + 0.5) / 5.0
				m.box(Vector3(x, h + 1.4 + t * 6.5, outer * (d / 2.0 - 0.2) - outer * t * (d - 0.4)), Vector3(0.45, 0.6, d / 5.0 + 0.1), MARBLE_SHADE)
	g.add_child(m.node(Kit.vc_mat(), "terrace"))
	return g

## The opera house: a plain cream front with round-headed windows, a three-arched porch carrying a balcony, a
## pediment and its name on the frieze.
static func teatro(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var wall := Color(String(b.wall))
	var mat := Kit.facade(wall, 0.3 + h, {"style": Kit.ARCHED, "shops": 0.0, "seed": 9.0, "ground_h": 5.0, "floor_h": 4.2, "bay": 3.6})
	_box(g, Vector3(w, h, d - 3.0), Vector3(0, h / 2.0, -1.5), mat)
	var m := Kit.Merge.new()
	var stone := Color("e9e1d0"); var shade := Color("d6cbb6")
	var fz := d / 2.0 - 1.5
	for x in [-6.0, -2.0, 2.0, 6.0]:   # the porch's piers
		m.box(Vector3(x, 2.6, fz), Vector3(1.0, 5.2, 2.8), stone)
	for x in [-4.0, 0.0, 4.0]:   # round arches between them
		for k in 7:
			var a := PI * (k + 0.5) / 7.0
			m.box(Vector3(x + cos(a) * 1.5, 4.2 + sin(a) * 1.0, fz + 1.3), Vector3(0.6, 0.6, 0.3), stone)
	m.box(Vector3(0, 5.5, fz), Vector3(13.2, 0.6, 3.0), stone)               # the porch's top, a balcony
	Kit.railing(m, Vector3(0, 5.8, fz + 1.35), 13.0, 0.0, stone.darkened(0.08), 0.9)
	m.box(Vector3(0, h - 0.6, d / 2.0 - 2.95), Vector3(w - 2.0, 1.2, 0.2), shade)     # the frieze
	m.gable(Vector3(0, h, d / 2.0 - 3.2), 14.0, 3.0, 0.8, stone)                       # the pediment
	g.add_child(m.node(Kit.vc_mat(), "porch"))
	var roof := Kit.Merge.new(); Kit.cornice(roof, w, d - 3.0, h, stone, true)
	var rn := roof.node(Kit.vc_mat(), "roof"); rn.position.z = -1.5; g.add_child(rn)
	var name := Label3D.new(); name.text = "TEATRO CIVICO"; name.font_size = 96; name.pixel_size = 0.012
	name.modulate = Color("6b5a44"); name.outline_size = 0; name.position = Vector3(0, h - 0.6, d / 2.0 - 2.83)
	name.shaded = true; g.add_child(name)
	return g

## The castle: brick walls with swallowtail battlements, round towers at the corners, and the tall gate tower facing
## the forecourt, with a clock.
static func castello(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	_box(g, Vector3(w, h, d), Vector3(0, h / 2.0, 0), Kit.facade(BRICK, 0.3 + h, {"style": Kit.BRICK, "shops": 0.0, "seed": 2.0}))
	var m := Kit.Merge.new()
	var stone := Color("cfc6b6")
	var tower := BRICK.darkened(0.06)
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var p := Vector3(c[0] * (w / 2.0 - 2.0), 0, c[1] * (d / 2.0 - 2.0))
		m.cyl(p, 4.2, h + 3.0, tower, 16)
		m.box(p + Vector3(0, 0.6, 0), Vector3(8.8, 1.2, 8.8), stone)
		for i in 14:
			var a := TAU * i / 14.0
			_merlon(m, p + Vector3(cos(a) * 4.0, h + 3.0, sin(a) * 4.0), a + PI / 2.0, tower)
	for s in [-1, 1]:   # battlements along the walls
		for i in int(w / 1.7):
			_merlon(m, Vector3(-w / 2.0 + 0.85 + i * 1.7, h, s * (d / 2.0 - 0.3)), 0.0, BRICK)
		for i in int(d / 1.7):
			_merlon(m, Vector3(s * (w / 2.0 - 0.3), h, -d / 2.0 + 0.85 + i * 1.7), PI / 2.0, BRICK)
	# the gate tower on the east front, stepping in as it rises, with a clock and a little lantern on top
	var gx := w / 2.0 - 4.0
	var y := 0.0
	for stage in [[8.0, h + 6.0], [6.4, 6.0], [4.6, 5.0], [3.2, 4.0]]:
		m.box(Vector3(gx, y + stage[1] / 2.0, 0), Vector3(stage[0], stage[1], stage[0]), tower if stage[0] > 6.0 else tower.lightened(0.04))
		m.box(Vector3(gx, y + stage[1] + 0.2, 0), Vector3(stage[0] + 0.4, 0.4, stage[0] + 0.4), stone)
		y += stage[1] + 0.4
	m.cyl(Vector3(gx, y, 0), 1.4, 2.2, stone, 8)
	m.cone(Vector3(gx, y + 2.2, 0), 1.8, 2.5, Color("5d6a6e"), 8)
	m.box(Vector3(gx + 4.05, 2.4, 0), Vector3(0.1, 4.8, 3.2), Color("2b2018"))   # the gateway
	g.add_child(m.node(Kit.vc_mat(), "castle"))
	var face := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.6; cm.bottom_radius = 1.6; cm.height = 0.12; face.mesh = cm
	face.material_override = P.mat("f3ead6"); face.rotation.z = PI / 2.0; face.position = Vector3(gx + 4.1, h + 8.5, 0); g.add_child(face)
	for hand in [[0.0, 1.1], [PI / 2.6, 0.8]]:
		var hm := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.06, hand[1], 0.12); hm.mesh = hb
		hm.material_override = P.mat("2b2018"); hm.position = Vector3(gx + 4.2, h + 8.5, 0); hm.rotation.x = hand[0]
		hm.position += Vector3(0, cos(hand[0]) * hand[1] / 2.0, sin(hand[0]) * hand[1] / 2.0); g.add_child(hm)
	return g

## A swallowtail merlon: a block with a notch cut into its top (two little horns).
static func _merlon(m: Kit.Merge, p: Vector3, ry: float, col: Color) -> void:
	m.box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.5), col, ry)
	var b := Basis(Vector3.UP, ry)
	for s in [-1, 1]:
		m.box(p + b * Vector3(s * 0.3, 1.1, 0), Vector3(0.3, 0.4, 0.5), col, ry)

## The station: a monumental grey stone front with great arched entrances, a taller middle block, an iron and glass
## canopy on slim columns, and behind it the train shed's arched roofs over the platforms, a regional train waiting.
static func centrale(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var wall := Color(String(b.wall))
	_box(g, Vector3(w, h, d), Vector3(0, h / 2.0, 0), Kit.facade(wall, 0.3 + h, {"style": Kit.STONE, "ground_h": 9.0, "floor_h": 4.0, "bay": 4.4, "seed": 4.0}))
	var mid := 24.0
	_box(g, Vector3(mid, 6.0, d - 4.0), Vector3(0, h + 3.0, 0), Kit.facade(wall.lightened(0.04), 0.3 + h + 6.0, {"style": Kit.STONE, "ground_h": 30.0, "floor_h": 4.0, "seed": 6.0}))
	var m := Kit.Merge.new()
	var stone := wall.lightened(0.08)
	Kit.cornice(m, w, d, h, stone, true)
	Kit.cornice(m, mid, d - 4.0, h + 6.0, stone, true)
	for s in [-1, 1]:   # stone horses-and-riders on the corners of the middle block (just their plinths and shapes)
		m.box(Vector3(s * (mid / 2.0 - 1.0), h + 6.9, d / 2.0 - 2.5), Vector3(1.6, 1.8, 2.4), stone.darkened(0.1))
	# the canopy over the entrances, on slim iron columns
	var cz := d / 2.0 + 3.0
	m.box(Vector3(0, 6.2, cz), Vector3(w * 0.7, 0.25, 6.0), IRON)
	for i in 9:
		m.box(Vector3(-w * 0.35 + w * 0.7 * i / 8.0, 3.1, cz + 2.8), Vector3(0.18, 6.2, 0.18), IRON)
	g.add_child(m.node(Kit.vc_mat(), "front"))
	var glass := Kit.Merge.new()
	glass.box(Vector3(0, 6.4, cz), Vector3(w * 0.7 - 0.4, 0.1, 5.6), Color("b9d4dd"))
	var gm := Kit.vc_mat().duplicate() as StandardMaterial3D
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color = Color(1, 1, 1, 0.45)
	g.add_child(glass.node(gm, "canopy_glass"))
	# the train shed behind (north): three iron arches over the platforms, and a train
	var shed := Kit.Merge.new()
	var sz0 := -d / 2.0 - 1.0
	for bay in 3:
		var cx := -w / 2.0 + w / 6.0 + bay * w / 3.0
		for k in 10:
			var a0 := PI * k / 10.0
			var a1 := PI * (k + 1) / 10.0
			var am := (a0 + a1) / 2.0
			var r := w / 6.0 - 0.5
			shed.box(Vector3(cx + cos(am) * r, 8.0 + sin(am) * 9.0, sz0 - 9.0), Vector3(r * PI / 10.0 + 0.2, 0.3, 18.0), Color("4b5559") if k % 2 == 0 else Color("6f8a92"))
	for i in 4:   # a regional train on the middle platform: green and grey carriages
		shed.box(Vector3(-24.0 + i * 13.0, 2.0, sz0 - 6.0), Vector3(12.5, 3.4, 3.0), Color("3f6b4f") if i % 2 == 0 else Color("8f948f"))
		shed.box(Vector3(-24.0 + i * 13.0, 2.4, sz0 - 6.0 + 1.52), Vector3(10.5, 0.9, 0.04), Color("d8e2e4"))
	g.add_child(shed.node(Kit.vc_mat(), "shed"))
	return g

## The low back wing of the tenement: one storey, its roof a terrace of terracotta tiles.
static func tenement_low(b: Dictionary) -> Node3D:
	var g := Kit.block(b, Kit.PLAIN)
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var m := Kit.Merge.new()
	for i in int(w / 0.6):
		m.box(Vector3(-w / 2.0 + 0.3 + i * 0.6, h + 0.11, 0), Vector3(0.58, 0.02, d - 0.2), Color("c08a62") if i % 2 == 0 else Color("b8805a"))
	g.add_child(m.node(Kit.vc_mat(), "terrace"))
	return g
