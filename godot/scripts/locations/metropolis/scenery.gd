extends RefCounted
## Toriano's scenery, added after the buildings (metropolis.gd's dress): the raised floors drawn as what they are
## (balconies, iron railings, the courtyard stair, parapets, the old bridge), and later the streets' furniture.

const Kit := preload("res://scripts/locations/metropolis/kit.gd")
const Trams := preload("res://scripts/locations/metropolis/trams.gd")
const Glow := preload("res://scripts/locations/metropolis/glow.gd")

const IRON := Color("2e2b28")
const SLAB := Color("bdb6aa")
const OCHRE := Color("d9a85b")
const MARBLE := Color("efe4dc")
const BRIDGE := Color("b8ad9c")

static func dress(v: Node3D) -> void:
	floors(v)
	galleria(v)
	trams(v)
	street(v)

## The tram line: rails, overhead wire, three trams running round it, stopping at the stops, and the traffic.
static func trams(v: Node3D) -> void:
	var loop: Array = Data.layout.get("metropolis_tram_loop", []).map(func(p): return Vector2(p[0], p[1]))
	if loop.is_empty(): return
	v.add_child(Trams.line(loop))
	var stops: Array = Data.layout.features.filter(func(f): return f.kind == "stop").map(func(f): return Vector2(f.x, f.z))
	var t := Trams.new()
	v.add_child(t)
	t.setup(v.get_parent(), loop, stops, 3, 5)   # and five cars in the traffic

## Every floor of the layout, drawn by its "look": slab (a stone balcony on iron brackets), rail (iron railing),
## parapet (a plastered low wall), balustrade (marble), stair (stone steps), deck and stone_parapet (the old bridge),
## none (inside a building, which draws itself).
static func floors(v: Node3D) -> void:
	var m := Kit.Merge.new()
	for f in Data.layout.get("floors", []):
		var look := String(f.get("look", "slab"))
		if look == "none": continue
		var s := WorldStatics.floor_surface(f)
		var w: float = s.maxX - s.minX; var d: float = s.maxZ - s.minZ
		var c := Vector3((s.minX + s.maxX) / 2.0, 0, (s.minZ + s.maxZ) / 2.0)
		var along_x := w >= d
		var length := maxf(w, d)
		var ry := 0.0 if along_x else PI / 2.0
		match look:
			"slab":
				m.box(c + Vector3(0, s.top - 0.11, 0), Vector3(w, 0.22, d), SLAB)
				var n := int(length / 1.8)
				for i in n + 1:   # iron brackets under the slab, against the wall side
					var t := -length / 2.0 + length * i / maxf(1.0, n)
					var off := Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)
					m.box(c + off + Vector3(0, s.top - 0.45, 0), Vector3(0.06, 0.45, 0.06), IRON)
			"rail":
				Kit.railing(m, c + Vector3(0, s.bottom, 0), length, ry, IRON, s.top - s.bottom)
			"parapet":
				m.box(c + Vector3(0, (s.bottom + s.top) / 2.0, 0), Vector3(w, s.top - s.bottom, d), OCHRE)
				m.box(c + Vector3(0, s.top + 0.04, 0), Vector3(w + 0.08, 0.08, d + 0.08), SLAB)
			"balustrade":
				m.box(c + Vector3(0, s.bottom + 0.1, 0), Vector3(w, 0.2, d), MARBLE)
				m.box(c + Vector3(0, s.top - 0.06, 0), Vector3(w + 0.06, 0.12, d + 0.06), MARBLE)
				var nb := int(length / 0.35)
				for i in nb:
					var t := -length / 2.0 + length * (i + 0.5) / nb
					var off := Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)
					m.box(c + off + Vector3(0, (s.bottom + s.top) / 2.0, 0), Vector3(0.12, s.top - s.bottom - 0.3, 0.12), MARBLE.darkened(0.04))
			"stair":
				var y0 := float(f.rise[0]); var y1 := float(f.rise[1])
				var steps := int(absf(y1 - y0) / 0.18)
				for i in steps:
					var t0 := float(i) / steps; var t1 := float(i + 1) / steps
					var top := lerpf(y0, y1, t1) if y1 > y0 else lerpf(y0, y1, t0)
					var a := lerpf(s.minZ if not along_x else s.minX, s.maxZ if not along_x else s.maxX, t0)
					var b := lerpf(s.minZ if not along_x else s.minX, s.maxZ if not along_x else s.maxX, t1)
					var mid := (a + b) / 2.0
					var bot: float = s.bottom
					var pos := Vector3(c.x, (bot + top) / 2.0, mid) if not along_x else Vector3(mid, (bot + top) / 2.0, c.z)
					var size := Vector3(w, top - bot, b - a) if not along_x else Vector3(b - a, top - bot, d)
					m.box(pos, size, SLAB.darkened(0.03 * (i % 2)))
				# an iron handrail on the open side, in short stepped lengths with posts
				var segs := maxi(2, int(length / 1.2))
				for i in segs:
					var tm := (i + 0.5) / segs
					var y := lerpf(y0, y1, tm) + 0.95
					var at := lerpf(s.minZ if not along_x else s.minX, s.maxZ if not along_x else s.maxX, tm)
					var pos := Vector3(s.maxX - 0.05, y, at) if not along_x else Vector3(at, y, s.maxZ - 0.05)
					m.box(pos, Vector3(length / segs + 0.02, 0.05, 0.05), IRON, ry)
					m.box(pos - Vector3(0, 0.48, 0), Vector3(0.04, 0.95, 0.04), IRON)
			"deck":
				m.box(c + Vector3(0, s.top - 0.25, 0), Vector3(w + 0.4, 0.5, d), BRIDGE)
				# a shallow stone arch under the deck, spanning the canal along z
				var n := 9
				for i in n:
					var a0 := PI * i / n; var a1 := PI * (i + 1) / n
					var zc: float = c.z - cos((a0 + a1) / 2.0) * d / 2.0
					var yc: float = s.top - 0.5 - sin((a0 + a1) / 2.0) * 1.4
					m.box(Vector3(c.x, yc + 0.25, zc), Vector3(w + 0.2, 0.5 + 1.4 * (1.0 - sin((a0 + a1) / 2.0)), d / n + 0.05), BRIDGE.darkened(0.08))
			"hoarding":   # a building site's board fence, pasted with posters
				m.box(c + Vector3(0, (s.bottom + s.top) / 2.0 + 0.5, 0), Vector3(w, s.top - s.bottom - 1.0, d), Color("8a7a62"))
				var np := int(length / 2.6)
				for i in np:
					var t := -length / 2.0 + length * (i + 0.5) / np
					var off := Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)
					var pc: Color = [Color("d94a3a"), Color("f2d36a"), Color("4a7ab0"), Color("efe9df"), Color("3f8a5a")][(i * 7 + int(c.x)) % 5]
					for sgn in [-1, 1]:
						var face := Vector3(0, 0, sgn * (d / 2.0 + 0.01)) if along_x else Vector3(sgn * (w / 2.0 + 0.01), 0, 0)
						m.box(c + off + face + Vector3(0, 1.4, 0), Vector3(1.6, 1.1, 0.02) if along_x else Vector3(0.02, 1.1, 1.6), pc)
			"stone_parapet":
				m.box(c + Vector3(0, (s.bottom + s.top) / 2.0 + 0.15, 0), Vector3(w, s.top - s.bottom - 0.3, d), BRIDGE)
				m.box(c + Vector3(0, s.top + 0.05, 0), Vector3(w + 0.1, 0.1, d + 0.1), BRIDGE.lightened(0.1))
	var node := m.node(Kit.vc_mat(), "floors")
	v.add_child(node)

# ---- The Galleria's glass roof ---------------------------------------------------------------------------------
const GAL_TOP := 16.3          # the blocks' cornice: where the vaults spring
const GAL_IRON := Color("3d4a46")
const GLASS := Color("c8e2ea")

static func _glass_mat() -> StandardMaterial3D:
	var m := Kit.vc_mat().duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A barrel vault of iron ribs and glass over an arm of the Galleria, along x (along_x) or z, from a to b, with the
## arm's centre line at c (the other coordinate) and half-width r.
static func _vault(iron: Kit.Merge, glass: Kit.Merge, along_x: bool, a: float, b: float, c: float, r: float) -> void:
	var segs := 10
	var ribs := int((b - a) / 3.0)
	for i in ribs + 1:
		var t := a + (b - a) * i / ribs
		for k in segs:
			var am := PI * (k + 0.5) / segs
			var off := cos(am) * r; var y := GAL_TOP + sin(am) * r
			var pos := Vector3(t, y, c + off) if along_x else Vector3(c + off, y, t)
			iron.box(pos, Vector3(0.12, 0.12, r * PI / segs + 0.05) if along_x else Vector3(r * PI / segs + 0.05, 0.12, 0.12), GAL_IRON, 0.0)
	for k in segs:   # glass skin, one strip per segment along the whole arm
		var am := PI * (k + 0.5) / segs
		var off := cos(am) * (r - 0.05); var y := GAL_TOP + sin(am) * (r - 0.05)
		var tilt := absf(cos(am))
		var pos := Vector3((a + b) / 2.0, y, c + off) if along_x else Vector3(c + off, y, (a + b) / 2.0)
		var th := 0.04 + 0.3 * tilt
		glass.box(pos, Vector3(b - a, th, r * PI / segs) if along_x else Vector3(r * PI / segs, th, b - a), GLASS)
	# the ridge and the two springing beams
	iron.box(Vector3((a + b) / 2.0, GAL_TOP + r, c) if along_x else Vector3(c, GAL_TOP + r, (a + b) / 2.0), Vector3(b - a, 0.2, 0.2) if along_x else Vector3(0.2, 0.2, b - a), GAL_IRON)

## A triumphal arch closing the end of an arm above the street: a wall with a great round opening.
static func _gal_arch(m: Kit.Merge, x: float, z: float, along_x: bool, r: float, wall: Color) -> void:
	var span := r * 2.0
	var top := GAL_TOP + r + 1.2
	var spring := 9.0
	var size_wall := Vector3(0.9, top - (spring + r), span) if along_x else Vector3(span, top - (spring + r), 0.9)
	m.box(Vector3(x, (spring + r + top) / 2.0, z), size_wall, wall)
	for k in 12:   # the arch's voussoirs, and the wall's spandrels beside them
		var am := PI * (k + 0.5) / 12.0
		var off := cos(am) * r * 0.82; var y := spring + sin(am) * r * 0.82
		var fill := (spring + r) - y
		var p := Vector3(x, y + fill / 2.0 + 0.3, z + off) if along_x else Vector3(x + off, y + fill / 2.0 + 0.3, z)
		m.box(p, Vector3(0.95, fill + 0.6, r * 1.64 / 12.0 + 0.05) if along_x else Vector3(r * 1.64 / 12.0 + 0.05, fill + 0.6, 0.95), wall.darkened(0.03))
	var sides := [Vector3(x, (spring + r) / 2.0 + 4.0, z - r * 0.91), Vector3(x, (spring + r) / 2.0 + 4.0, z + r * 0.91)] if along_x else [Vector3(x - r * 0.91, (spring + r) / 2.0 + 4.0, z), Vector3(x + r * 0.91, (spring + r) / 2.0 + 4.0, z)]
	for p in sides:   # the piers above the shops, up to where the arch springs
		m.box(p, Vector3(0.95, spring + r - 8.0, r * 0.18) if along_x else Vector3(r * 0.18, spring + r - 8.0, 0.95), wall)

static func galleria(v: Node3D) -> void:
	if not Data.layout.buildings.any(func(b): return b.kind == "galleria"): return
	var iron := Kit.Merge.new(); var glass := Kit.Merge.new(); var stone := Kit.Merge.new()
	var r := 6.0
	_vault(iron, glass, false, -87.0, -64.0, -10.0, r)
	_vault(iron, glass, false, -52.0, -30.0, -10.0, r)
	_vault(iron, glass, true, -40.0, -16.0, -58.0, r)
	_vault(iron, glass, true, -4.0, 20.0, -58.0, r)
	# the octagonal dome over the crossing: a drum, eight ribs up to a lantern, glass between them
	var c := Vector3(-10.0, GAL_TOP, -58.0)
	var wall := Color("e8cf9a")
	for i in 8:
		var a0 := TAU * i / 8.0 + PI / 8.0; var a1 := TAU * (i + 1) / 8.0 + PI / 8.0
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * 8.6
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * 8.6
		var mid := (p0 + p1) / 2.0
		stone.box(mid + Vector3(0, 1.0, 0), Vector3(p0.distance_to(p1), 2.0, 0.6), wall, -atan2(p1.z - p0.z, p1.x - p0.x))
		for k in 8:   # each rib, a stack of short pieces curving up to the lantern
			var t := (k + 0.5) / 8.0
			var rad := 8.6 * cos(t * PI / 2.0); var y := 2.0 + 10.0 * sin(t * PI / 2.0)
			iron.box(c + Vector3(cos(a0) * rad, y, sin(a0) * rad), Vector3(0.18, 1.6, 0.18), GAL_IRON)
	glass.cone(c + Vector3(0, 2.0, 0), 8.5, 10.4, GLASS, 8)
	stone.cyl(c + Vector3(0, 11.6, 0), 1.4, 1.6, wall, 8)
	stone.cone(c + Vector3(0, 13.2, 0), 1.7, 1.6, Color("5d6a6e"), 8)
	# the arches at the ends of the north-south arm, over the square and the opera street
	_gal_arch(stone, -10.0, -30.0, false, r, wall)
	_gal_arch(stone, -10.0, -87.0, false, r, wall)
	_gal_arch(stone, -40.0, -58.0, true, r, wall)
	_gal_arch(stone, 20.0, -58.0, true, r, wall)
	v.add_child(iron.node(Kit.vc_mat(), "galleria_iron"))
	v.add_child(stone.node(Kit.vc_mat(), "galleria_stone"))
	var gn := glass.node(_glass_mat(), "galleria_glass")
	gn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(gn)

# ---- Street furniture (the layout's props of Toriano's own kinds; their colliders come from the shared props) ---
static func _props(kind: String) -> Array: return Data.layout.get("props", []).filter(func(p): return p.kind == "metropolis_" + kind)

static func street(v: Node3D) -> void:
	var glow := Glow.new(); glow.name = "LampGlow"; glow.village = v; v.add_child(glow)
	_trees(v); _lamps(v, glow); _christmas_tree(v, glow); _string_lights(v, glow)
	var m := Kit.Merge.new()
	for p in _props("kiosk"): _kiosk(m, p)
	for p in _props("payphone"): _payphone(m, p)
	for p in _props("car"): _car(m, p)
	for p in _props("skip"): _skip(m, p)
	for p in _props("sand"): m.cone(_at(p), 1.5, 1.1, Color("cdb88e"), 10)
	for p in _props("marble"): _marble(m, p)
	for p in _props("crane_old"): v.add_child(crane(p))
	for p in _props("barge"): _barge(m, p)
	for p in _props("cart_old"): _cart(m, p)
	for p in _props("flea"): _flea(m, p)
	v.add_child(m.node(Kit.vc_mat(), "street_things"))

static func _at(p: Dictionary) -> Vector3: return Vector3(float(p.x), Heightfield.height(p.x, p.z), float(p.z))
## A point offset in the prop's own frame (x along it, z across), turned by its r.
static func _o(p: Dictionary, local: Vector3) -> Vector3: return _at(p) + Basis(Vector3.UP, float(p.get("r", 0.0))) * local

## Plane trees, bare for December: a mottled trunk, five limbs reaching up and out, twigs, a few last brown leaves
## and the seed balls that hang on through the winter. One mesh, instanced for every tree.
static func _trees(v: Node3D) -> void:
	var list := _props("plane")
	if list.is_empty(): return
	var mesh := plane_mesh()
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = list.size()
	for i in list.size():
		var p: Dictionary = list[i]
		var sc := float(p.get("s", 1.0))
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(p.x) * 0.37).scaled(Vector3.ONE * sc), _at(p)))
	var inst := MultiMeshInstance3D.new(); inst.multimesh = mm; inst.material_override = Kit.vc_mat(); inst.name = "plane_trees"
	v.add_child(inst)

## One bare plane tree, standing at the origin (also the park's trees you prune, see gathering.gd).
static func plane_mesh() -> Mesh:
	var m := Kit.Merge.new()
	var bark := Color("a59a80"); var patch := Color("c9c2a6"); var dark := Color("7d735f")
	m.cyl(Vector3(0, 0, 0), 0.32, 2.2, bark, 8, false)
	m.cyl(Vector3(0, 2.2, 0), 0.26, 1.6, bark.lightened(0.05), 8, false)
	for i in 6: m.box(Vector3(cos(i * 1.9) * 0.27, 0.6 + i * 0.5, sin(i * 1.9) * 0.27), Vector3(0.22, 0.3, 0.22), patch)   # pale bark patches
	for b in 5:
		var a := TAU * b / 5.0 + 0.4
		var r := 0.2; var y := 3.4
		for k in 7:
			r += 0.42; y += 0.55 - k * 0.04
			var sz := 0.2 - k * 0.02
			m.box(Vector3(cos(a) * r, y, sin(a) * r), Vector3(sz, 0.62, sz), dark if k > 3 else bark)
			if k > 2 and k % 2 == 1:   # twigs
				for tw in [-0.7, 0.7]:
					m.box(Vector3(cos(a + tw * 0.4) * (r + 0.35), y + 0.25, sin(a + tw * 0.4) * (r + 0.35)), Vector3(0.07, 0.5, 0.07), dark)
		m.box(Vector3(cos(a) * (r + 0.2), y - 0.6, sin(a) * (r + 0.2)), Vector3(0.12, 0.12, 0.12), Color("6b4a2a"))   # a seed ball
		m.box(Vector3(cos(a + 0.3) * (r - 0.4), y - 0.2, sin(a + 0.3) * (r - 0.4)), Vector3(0.32, 0.06, 0.26), Color("b07a3a"))   # a last leaf
	return m.node(Kit.vc_mat()).mesh

## Street lamps: a dark green pole with a curved arm and a lantern whose sodium bulb glows orange after dusk
## (glow.gd follows the village's lamp glow).
static func _lamps(v: Node3D, glow) -> void:
	var list := _props("lamp")
	if list.is_empty(): return
	var poles := Kit.Merge.new(); var bulbs := Kit.Merge.new()
	var green := Color("33443a")
	for p in list:
		poles.box(_o(p, Vector3(0, 0.2, 0)), Vector3(0.36, 0.4, 0.36), green, float(p.r))
		poles.box(_o(p, Vector3(0, 2.9, 0)), Vector3(0.14, 5.6, 0.14), green, float(p.r))
		for k in 4:   # the arm curving out over the street
			poles.box(_o(p, Vector3(0, 5.6 + k * 0.12, 0.25 + k * 0.28)), Vector3(0.09, 0.09, 0.32), green, float(p.r))
		poles.box(_o(p, Vector3(0, 5.85, 1.35)), Vector3(0.5, 0.18, 0.5), green, float(p.r))
		poles.pyramid(_o(p, Vector3(0, 5.94, 1.35)), 0.3, 0.25, green)
		bulbs.box(_o(p, Vector3(0, 5.66, 1.35)), Vector3(0.34, 0.2, 0.34), Color.WHITE, float(p.r))
	v.add_child(poles.node(Kit.vc_mat(), "lamp_posts"))
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("ffb55a"); bm.emission_enabled = true; bm.emission = Color("ff9a3c"); bm.emission_energy_multiplier = 0.15
	var bulb := bulbs.node(bm, "street_lamp_bulbs"); bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(bulb)
	glow.bulbs.append(bm)

## The big Christmas tree in the cathedral square: tiers of dark fir, coloured lights and a gold star.
static func _christmas_tree(v: Node3D, glow) -> void:
	for p in _props("xmas_tree"):
		var m := Kit.Merge.new(); var lights := Kit.Merge.new()
		var base := _at(p)
		m.box(base + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), Color("8a2f2f"))   # a red-wrapped base
		m.cyl(base + Vector3(0, 0.8, 0), 0.35, 1.6, Color("6b4a2a"), 8)
		for t in 6:
			var y := 2.0 + t * 1.9; var r := 3.6 - t * 0.55
			m.cone(base + Vector3(0, y, 0), r, 3.0, Color("2f5a3c").lightened(0.03 * (t % 2)), 12)
			for k in 10:
				var a := TAU * k / 10.0 + t * 0.6
				lights.box(base + Vector3(cos(a) * r * 0.78, y + 0.5, sin(a) * r * 0.78), Vector3(0.22, 0.22, 0.22), [Color("ff5a4a"), Color("ffd84a"), Color("6ab0ff"), Color("ffffff")][(k + t) % 4])
		m.pyramid(base + Vector3(0, 13.4, 0), 0.25, 1.4, Color("ffcf4a"))
		v.add_child(m.node(Kit.vc_mat(), "christmas_tree"))
		var lm := Kit.vc_mat().duplicate() as StandardMaterial3D
		lm.emission_enabled = true; lm.emission_energy_multiplier = 1.2; lm.emission = Color(1, 0.85, 0.6)
		var ln := lights.node(lm, "christmas_lights"); ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(ln)
		glow.twinkle.append(lm)

## Christmas lights strung across the Galleria's two arms and number 14's courtyard: strands of small bulbs sagging
## between the walls, lit with the street lamps after dusk.
static func _string_lights(v: Node3D, glow) -> void:
	var m := Kit.Merge.new()
	var strands: Array = []
	for z in range(-84, -30, 6):   # across the long arm, between its glass walls
		if z < -64 or z > -52: strands.append([Vector3(-16, 7.5, z), Vector3(-4, 7.5, z)])
	for x in range(-38, 20, 6):    # and across the cross arm
		if x < -16 or x > -4: strands.append([Vector3(x, 7.5, -64), Vector3(x, 7.5, -52)])
	for z in [108.0, 112.0, 116.0]:   # over the courtyard, from the west balcony to the east
		strands.append([Vector3(-44.6, 6.4, z), Vector3(-31.4, 6.4, z)])
	var cols := [Color("ffd27a"), Color("ff7a5a"), Color("ffe9b0"), Color("7ab8ff")]
	for st in strands:
		var a: Vector3 = st[0]; var b: Vector3 = st[1]
		var n := int(a.distance_to(b) / 0.6)
		for i in n + 1:
			var f := float(i) / n
			m.box(a.lerp(b, f) - Vector3(0, 3.6 * f * (1.0 - f), 0), Vector3(0.12, 0.12, 0.12), cols[i % cols.size()])   # 0.9 m of sag
	var lm := Kit.vc_mat().duplicate() as StandardMaterial3D
	lm.emission_enabled = true; lm.emission_energy_multiplier = 0.5; lm.emission = Color(1, 0.86, 0.62)
	var ln := m.node(lm, "string_lights"); ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(ln)
	glow.twinkle.append(lm)

static func _kiosk(m: Kit.Merge, p: Dictionary) -> void:
	var green := Color("3f5a48")
	var r := float(p.r)
	m.box(_o(p, Vector3(0, 1.2, 0)), Vector3(2.6, 2.4, 2.0), green, r)
	m.box(_o(p, Vector3(0, 2.55, 0)), Vector3(3.4, 0.18, 2.8), green.darkened(0.2), r)
	for i in 5:   # magazines pegged along the front
		m.box(_o(p, Vector3(-1.0 + i * 0.5, 1.6, 1.01)), Vector3(0.38, 0.5, 0.03), [Color("d94a3a"), Color("f2d36a"), Color("4a7ab0"), Color("efe9df"), Color("e07ab0")][i], r)
	m.box(_o(p, Vector3(0, 0.9, 1.05)), Vector3(2.4, 0.08, 0.3), Color("cfc6b6"), r)

static func _payphone(m: Kit.Merge, p: Dictionary) -> void:
	var r := float(p.r)
	m.box(_o(p, Vector3(0, 0.9, 0)), Vector3(0.12, 1.8, 0.12), Color("8f948f"), r)
	m.box(_o(p, Vector3(0, 1.9, 0.2)), Vector3(0.9, 0.9, 0.6), Color("e07a2a"), r)   # the orange hood
	m.box(_o(p, Vector3(0, 1.55, 0.32)), Vector3(0.36, 0.5, 0.18), Color("6f6a64"), r)
	m.box(_o(p, Vector3(0.12, 1.62, 0.43)), Vector3(0.08, 0.3, 0.06), Color("2b2826"), r)

## A small boxy car of the late 1990s: body, cabin with dark windows, black bumpers and wheels.
static func _car(m: Kit.Merge, p: Dictionary) -> void:
	var col := Color(String(p.get("color", "#b03a2e")))
	var r := float(p.r)
	m.box(_o(p, Vector3(0, 0.6, 0)), Vector3(3.5, 0.65, 1.55), col, r)
	m.box(_o(p, Vector3(-0.25, 1.17, 0)), Vector3(2.0, 0.55, 1.42), col.lightened(0.05), r)
	m.box(_o(p, Vector3(-0.25, 1.17, 0)), Vector3(2.04, 0.36, 1.46), Color("2c3a44"), r)   # windows all round
	for x in [-1.18, 1.18]:
		for z in [-0.72, 0.72]:
			m.box(_o(p, Vector3(x, 0.33, z)), Vector3(0.56, 0.5, 0.2), Color("1d1d1d"), r)
	for x in [-1.78, 1.78]:
		m.box(_o(p, Vector3(x, 0.45, 0)), Vector3(0.1, 0.18, 1.5), Color("2b2826"), r)
	m.box(_o(p, Vector3(1.76, 0.72, 0.5)), Vector3(0.05, 0.14, 0.24), Color("fff2c8"), r)
	m.box(_o(p, Vector3(1.76, 0.72, -0.5)), Vector3(0.05, 0.14, 0.24), Color("fff2c8"), r)

static func _skip(m: Kit.Merge, p: Dictionary) -> void:
	var r := float(p.r)
	m.box(_o(p, Vector3(0, 0.55, 0)), Vector3(3.2, 1.1, 1.8), Color("d98a2a"), r)
	for i in 6:   # rubble, bricks and a bent bicycle wheel poking out
		m.box(_o(p, Vector3(-1.1 + i * 0.45, 1.18, -0.4 + (i % 3) * 0.35)), Vector3(0.4, 0.22, 0.3), [Color("b5653a"), Color("9a948c"), Color("c9a46a")][i % 3], r + i * 0.4)
	m.box(_o(p, Vector3(0.6, 1.45, 0.3)), Vector3(0.05, 0.7, 0.7), Color("3a3836"), r)

static func _marble(m: Kit.Merge, p: Dictionary) -> void:
	var s := float(p.get("s", 1.0))
	m.box(_at(p) + Vector3(0, 0.5 * s, 0), Vector3(1.6, 1.0, 1.2) * s, Color("efe7e0"), float(p.r))
	m.box(_at(p) + Vector3(0, 1.0 * s + 0.01, 0), Vector3(1.3, 0.02, 0.9) * s, Color("ddd0c6"), float(p.r))

## The old crane by the canal's mouth: a rusty iron mast and a jib leaning out over the water, its hook hanging. The
## jib (with the hook and a marble block, shown once the crane is driven) turns on the mast: see works.gd.
static func crane(p: Dictionary) -> Node3D:
	var g := Node3D.new(); g.name = "metropolis_crane"
	g.position = _at(p); g.rotation.y = float(p.r)
	var rust := Color("8a4a32")
	var m := Kit.Merge.new()
	m.box(Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 1.8), Color("6f6a64"))
	m.box(Vector3(0, 4.2, 0), Vector3(0.45, 7.6, 0.45), rust)
	m.box(Vector3(0, 1.0, -0.9), Vector3(1.2, 1.2, 0.8), rust.darkened(0.2))   # the winch house
	g.add_child(m.node(Kit.vc_mat(), "mast"))
	var jib := Node3D.new(); jib.name = "jib"; g.add_child(jib)
	var j := Kit.Merge.new()
	for k in 9:   # rising as it reaches over the water
		j.box(Vector3(0, 7.2 + k * 0.28, 0.6 + k * 0.85), Vector3(0.3, 0.3, 0.9), rust.darkened(0.05 * (k % 2)))
	j.box(Vector3(0, 6.6, 8.1), Vector3(0.04, 3.6, 0.04), Color("2b2826"))
	jib.add_child(j.node(Kit.vc_mat(), "arm"))
	var hook := Node3D.new(); hook.name = "hook"; hook.position = Vector3(0, 4.7, 8.1); jib.add_child(hook)
	var h := Kit.Merge.new()
	h.box(Vector3.ZERO, Vector3(0.3, 0.3, 0.3), Color("2b2826"))
	hook.add_child(h.node(Kit.vc_mat(), "hook"))
	var block := Kit.Merge.new()
	block.box(Vector3(0, -1.0, 0), Vector3(1.6, 1.1, 1.1), Color("efe7e0")); block.box(Vector3(0, -0.4, 0), Vector3(0.04, 0.6, 0.04), Color("2b2826"))
	var bl := block.node(Kit.vc_mat(), "block"); bl.visible = false; hook.add_child(bl)
	return g

static func _barge(m: Kit.Merge, p: Dictionary) -> void:
	var col := Color(String(p.get("color", "#6b3f2a")))
	var y := Heightfield.WATER_Y + 0.15
	var c := Vector3(float(p.x), y, float(p.z))
	var b := Basis(Vector3.UP, float(p.r))
	m.box(c + b * Vector3(0, 0, 0), Vector3(14.0, 0.9, 3.4), col, float(p.r))
	m.box(c + b * Vector3(0, 0.5, 0), Vector3(13.6, 0.12, 3.0), Color("8a7a62"), float(p.r))
	m.box(c + b * Vector3(-4.5, 1.2, 0), Vector3(3.0, 1.4, 2.4), Color("efe9df"), float(p.r))
	m.box(c + b * Vector3(1.5, 0.95, 0), Vector3(4.0, 0.8, 2.2), Color("efe7e0"), float(p.r))   # a marble block in the hold

static func _cart(m: Kit.Merge, p: Dictionary) -> void:
	var r := float(p.r); var wood := Color("8a5a3a")
	m.box(_o(p, Vector3(0, 0.95, 0)), Vector3(1.8, 0.7, 1.1), wood, r)
	for s in [-1, 1]: m.cyl(_o(p, Vector3(0, 0.0, s * 0.62)), 0.45, 0.08, Color("3a2a1e"), 10)
	m.cyl(_o(p, Vector3(-0.3, 1.3, 0)), 0.38, 0.32, Color("2b2826"), 10)   # the brazier
	m.box(_o(p, Vector3(0.6, 2.2, 0)), Vector3(0.08, 1.8, 0.08), wood, r)
	m.box(_o(p, Vector3(0.1, 3.05, 0.05)), Vector3(1.9, 0.08, 1.3), Color("b03a2e"), r + 0.15)   # a torn, tilted awning

static func _flea(m: Kit.Merge, p: Dictionary) -> void:
	var r := float(p.r)
	m.box(_o(p, Vector3(0, 0.75, 0)), Vector3(2.6, 0.1, 1.2), Color("8a7a62"), r)
	for s in [-1, 1]:
		for t in [-1, 1]: m.box(_o(p, Vector3(s * 1.2, 0.37, t * 0.5)), Vector3(0.08, 0.74, 0.08), Color("5a4a3a"), r)
	for i in 6:   # old junk: a gramophone horn, books, a lamp, a clock, cups
		m.box(_o(p, Vector3(-1.0 + i * 0.4, 0.95, -0.2 + (i % 2) * 0.35)), Vector3(0.3, 0.3 + (i % 3) * 0.12, 0.25), [Color("c9a46a"), Color("8a2f2f"), Color("4a6fb0"), Color("efe9df"), Color("3f6b4f"), Color("b5653a")][i], r)
	m.cyl(_o(p, Vector3(0, 0.8, 0)), 0.04, 1.8, Color("5a4a3a"), 6)
	m.cone(_o(p, Vector3(0, 2.5, 0)), 1.7, 0.6, Color("2f5d3a"), 10)
