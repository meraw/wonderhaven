class_name HouseKit
extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const KIT := "res://assets/models/kit/langhe_kit.glb"
const PITCH := 0.3665
const GROUND_FLOOR := 2.6
const FLOOR := 2.5
const OVERHANG := 0.6
const SIDE_OVERHANG := 0.28
const FOOTING := 0.75
const KINDS := ["cottage", "shop", "hut"]
const SHUTTER_KEY := "2f4f37"
const DOOR_KEYS := ["5a6b4a", "6e4428"]
const FRAME_KEY := "35503f"
const SHUTTERS := ["2f4f37", "5e7b52", "4f6b43", "6f8090", "7a4b2e", "3f5a3a"]
const DOORS := ["5a6b4a", "6e4428", "3f4f5f", "7a3b2e"]
const GLASS := "39434d"
const FOOTING_STONE := "d6ccb8"
const TILE_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 color : source_color = vec4(0.71, 0.35, 0.21, 1.0);
global uniform float world_snow;
varying float up;
void vertex() {
	up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}
void fragment() {
	vec3 c = color.rgb * COLOR.rgb;
	c = mix(c, vec3(0.88, 0.91, 0.95), world_snow * smoothstep(0.2, 0.6, up) * 0.8);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

static var _parts := {}
static var _variants := {}
static var _tile_shader: Shader
static var _box: BoxMesh

static func uses(b: Dictionary) -> bool:
	return bool(Data.layout.get("houseStyle", {}).get("kit", false)) and KINDS.has(String(b.get("kind", ""))) and not b.has("model")

static func floors_of(b: Dictionary) -> int:
	return int(b.get("floors", 1 if b.get("kind", "") == "hut" else 2))

static func wall_height(floors: int) -> float:
	return GROUND_FLOOR + FLOOR * (floors - 1) + 0.3

static func span(b: Dictionary) -> float:
	return float(b.w) if String(b.get("door", "S")) in ["E", "W"] else float(b.d)

static func height(b: Dictionary) -> float:
	return wall_height(floors_of(b)) + span(b) / 2.0 * tan(PITCH) + 1.3

static func build(b: Dictionary) -> Node3D:
	return _House.new(b).make()

static func _load() -> void:
	if not _parts.is_empty(): return
	var scene: PackedScene = load(KIT)
	var root: Node = scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var solid := ArrayMesh.new()
		var glass := ArrayMesh.new()
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var nm: String = src.resource_name if src else ""
			var target := glass if nm.begins_with("wh_glass") else solid
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(i))
			target.surface_set_name(target.get_surface_count() - 1, nm)
		_parts[String(mi.name)] = {"solid": solid, "glass": glass if glass.get_surface_count() > 0 else null}
	root.free()

static func has_part(part: String) -> bool:
	_load()
	return _parts.has(part)

static func part_mesh(part: String, recolor: Dictionary = {}, glass: bool = false, mirror: bool = false) -> ArrayMesh:
	_load()
	var key := "%s|%s|%s|%s" % [part, str(recolor), glass, mirror]
	if _variants.has(key): return _variants[key]
	var src: ArrayMesh = _parts[part]["glass" if glass else "solid"]
	if src == null: return null
	var m := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(i)
		if mirror: arrays = _mirrored(arrays)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var nm := src.surface_get_name(i)
		m.surface_set_name(i, nm)
		if not glass:
			var mat := ModelKit.material_for(nm, recolor)
			if mat: m.surface_set_material(i, mat)
	_variants[key] = m
	return m

static func _mirrored(arrays: Array) -> Array:
	var out := arrays.duplicate()
	var v: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	for i in v.size(): v[i] = Vector3(-v[i].x, v[i].y, v[i].z)
	out[Mesh.ARRAY_VERTEX] = v
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var n: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for i in n.size(): n[i] = Vector3(-n[i].x, n[i].y, n[i].z)
		out[Mesh.ARRAY_NORMAL] = n
	out[Mesh.ARRAY_TANGENT] = null
	if arrays[Mesh.ARRAY_INDEX] != null:
		var idx: PackedInt32Array = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
		for t in range(0, idx.size(), 3):
			var k := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = k
		out[Mesh.ARRAY_INDEX] = idx
	else:
		var vv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
		var cols = out[Mesh.ARRAY_COLOR]
		var nn = out[Mesh.ARRAY_NORMAL]
		for t in range(0, vv.size(), 3):
			var a := vv[t + 1]; vv[t + 1] = vv[t + 2]; vv[t + 2] = a
			if nn != null:
				var b: Vector3 = nn[t + 1]; nn[t + 1] = nn[t + 2]; nn[t + 2] = b
			if cols != null:
				var c: Color = cols[t + 1]; cols[t + 1] = cols[t + 2]; cols[t + 2] = c
		out[Mesh.ARRAY_VERTEX] = vv
		out[Mesh.ARRAY_NORMAL] = nn
		out[Mesh.ARRAY_COLOR] = cols
	return out

static func tile_material(color: Color) -> ShaderMaterial:
	if _tile_shader == null:
		_tile_shader = Shader.new()
		_tile_shader.code = P.shader_code(TILE_SHADER, 0.72, P.ROUGH_SPECULAR, P.REAL_SHADER_ALBEDO)
	var m := ShaderMaterial.new()
	m.shader = _tile_shader
	m.set_shader_parameter("color", color)
	return m

static func unit_box() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	return _box

static func tinted(m: StandardMaterial3D) -> StandardMaterial3D:
	var t := m.duplicate() as StandardMaterial3D
	t.vertex_color_use_as_albedo = true
	return t


class _House:
	var b: Dictionary
	var g := Node3D.new()
	var f := Node3D.new()
	var W := 0.0
	var D := 0.0
	var H := 0.0
	var rise := 0.0
	var floors := 2
	var enter := false
	var rng := RandomNumberGenerator.new()
	var batches := {}
	var over: Array = []
	var glasses: Array = []
	var glass_mat: StandardMaterial3D
	var wall_mat: Material
	var trim: Color
	var shutter: String
	var party: Array = []
	var door_u := 0.0
	var shop_w := 0.0
	var chimney_top := Vector3.ZERO

	func _init(bd: Dictionary) -> void:
		b = bd
		enter = Interiors.enterable(b)
		var side := String(b.get("door", "S"))
		var turned := side in ["E", "W"]
		W = float(b.d) if turned else float(b.w)
		D = float(b.w) if turned else float(b.d)
		floors = HouseKit.floors_of(b)
		H = HouseKit.wall_height(floors)
		rise = D / 2.0 * tan(HouseKit.PITCH)
		f.rotation.y = {"S": 0.0, "N": PI, "E": PI / 2.0, "W": -PI / 2.0}[side]
		g.add_child(f)
		rng.seed = hash("%s|%s|%s" % [b.get("id", ""), b.x, b.z])
		var di := Interiors.door_info(b)
		var c: Vector2 = di.c - Vector2(b.x, b.z)
		door_u = (f.transform.basis.inverse() * Vector3(c.x, 0.0, c.y)).x
		for s in b.get("party", []):
			party.append(_canonical(String(s)))
		if (b.get("kind", "") == "shop" or b.get("shopfront", false)) and W >= 4.4: shop_w = clampf(W - 1.4, 3.0, 4.2)

	func _canonical(world_side: String) -> String:
		var v: Vector3 = {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1), "E": Vector3(1, 0, 0), "W": Vector3(-1, 0, 0)}[world_side]
		var l := f.transform.basis.inverse() * v
		if absf(l.z) > absf(l.x): return "front" if l.z > 0.0 else "back"
		return "right" if l.x > 0.0 else "left"

	func facade(side: String) -> Transform3D:
		match side:
			"back": return Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -D / 2.0))
			"right": return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(W / 2.0, 0, 0))
			"left": return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-W / 2.0, 0, 0))
		return Transform3D(Basis.IDENTITY, Vector3(0, 0, D / 2.0))

	func put(mesh: Mesh, xf: Transform3D, high: bool, override: Material = null, col: Color = Color.WHITE, shadow: bool = true) -> void:
		if mesh == null: return
		var key := "%d|%s|%d" % [mesh.get_instance_id(), high, override.get_instance_id() if override else 0]
		if not batches.has(key):
			batches[key] = {"mesh": mesh, "xf": [], "col": [], "high": high, "override": override, "shadow": shadow}
		batches[key].xf.append(xf)
		batches[key].col.append(col)

	func add(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, high: bool = false, parent: Node3D = null) -> MeshInstance3D:
		var mi := Props._add(parent if parent else f, mesh, mat, pos, rot)
		if high and enter: over.append(mi)
		return mi

	func make() -> Node3D:
		var hs: Dictionary = Data.layout.get("houseStyle", {})
		wall_mat = P.plaster(b.wall)
		trim = Color(hs.get("cornice", "e8dcc4"))
		var pick: String = HouseKit.SHUTTERS[rng.randi() % HouseKit.SHUTTERS.size()]
		if hs.has("shutters") and rng.randf() < 0.5: pick = String(hs.shutters)
		shutter = String(b.get("shutters", pick)).trim_prefix("#")
		glass_mat = P.unique_mat(HouseKit.GLASS, "ffcf6b", 0.0)
		if P.real:
			glass_mat.roughness = 0.12
			glass_mat.metallic_specular = 0.6
		walls()
		footing()
		quoins(hs)
		bands()
		openings()
		roof()
		chimney()
		downpipe()
		flush()
		g.set_meta("glasses", glasses)
		g.set_meta("chimney", chimney_top)
		if enter: g.set_meta("fade_parts", Props.fade_parts(over))
		return g

	func walls() -> void:
		if enter:
			var wh := Interiors.WALL_H
			for r in Interiors.walls(b):
				Props._add(g, P.box(r.maxX - r.minX, wh, r.maxZ - r.minZ), wall_mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, wh / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
			var di := Interiors.door_info(b)
			var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
			var lw := Vector3(Interiors.DOOR_W, wh - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, wh - Interiors.DOOR_H, Interiors.DOOR_W)
			Props._add(g, P.box(lw.x, lw.y, lw.z), wall_mat, Vector3(dc.x, (wh + Interiors.DOOR_H) / 2.0, dc.y))
			Props._add(g, P.box(b.w - 0.1, 0.05, b.d - 0.1), P.wood("d9b48a"), Vector3(0, 0.025, 0), Vector3.ZERO, Vector3.ONE, false)
			var t := Interiors.WALL_T
			var bh := H - wh
			for zs in [-1, 1]: over.append(Props._add(g, P.box(b.w, bh, t), wall_mat, Vector3(0, wh + bh / 2.0, zs * (b.d / 2.0 - t / 2.0))))
			for xs in [-1, 1]: over.append(Props._add(g, P.box(t, bh, b.d - t * 2.0), wall_mat, Vector3(xs * (b.w / 2.0 - t / 2.0), wh + bh / 2.0, 0)))
			over.append(Props._add(g, P.box(b.w - t * 2.0, 0.12, b.d - t * 2.0), P.wood("8a6a50"), Vector3(0, wh + 0.06, 0)))
			var leaf := Node3D.new()
			leaf.position = Vector3(door_u - Interiors.DOOR_W / 2.0 + 0.06, 0.0, D / 2.0 - Interiors.WALL_T - 0.04)
			leaf.rotation.y = 1.75
			f.add_child(leaf)
			Props._add(leaf, P.rbox(1.1, 1.95, 0.07, 0.03), P.wood(door_color()), Vector3(0.55, 0.99, 0))
		else:
			add(P.box(W, H, D), wall_mat, Vector3(0, H / 2.0, 0))
		var infill := PrismMesh.new()
		infill.size = Vector3(D, rise, W)
		infill.left_to_right = 0.5
		add(infill, wall_mat, Vector3(0, H + rise / 2.0 - 0.01, 0), Vector3(0, PI / 2.0, 0), true)

	func door_color() -> String:
		return String(b.get("doorColor", HouseKit.DOORS[int(absf(float(b.x) * 7.0 + float(b.z) * 3.0)) % HouseKit.DOORS.size()])).trim_prefix("#")

	func high_at(y: float) -> bool:
		return enter and y > Interiors.WALL_H - 0.3

	func footing() -> void:
		var mat := HouseKit.tinted(P.stone(HouseKit.FOOTING_STONE))
		var box := HouseKit.unit_box()
		var skip := shop_w / 2.0 + 0.1 if shop_w > 0.0 else 0.85
		for side in ["front", "back", "left", "right"]:
			if party.has(side): continue
			var length := W if side in ["front", "back"] else D
			var fx := facade(side)
			var z := 0.0
			while z < HouseKit.FOOTING - 0.03:
				var h := minf(rng.randf_range(0.08, 0.17), HouseKit.FOOTING - z)
				var s := -length / 2.0 - rng.randf_range(0.0, 0.3)
				while s < length / 2.0:
					var L := rng.randf_range(0.2, 0.62)
					var a := maxf(s, -length / 2.0)
					var c := minf(s + L, length / 2.0)
					if side == "front" and a < door_u + skip and c > door_u - skip:
						if a < door_u - skip: c = door_u - skip
						else: a = maxf(a, door_u + skip)
					if c - a > 0.06:
						var depth := rng.randf_range(0.03, 0.075)
						var size := Vector3(c - a - 0.014, h - 0.014, depth + 0.03)
						var pos := Vector3((a + c) / 2.0, z + h / 2.0, depth / 2.0 - 0.015)
						var k := rng.randf_range(0.88, 1.08)
						put(box, fx * Transform3D(Basis.from_scale(size), pos), false, mat, Color(k, k * rng.randf_range(0.97, 1.0), k * rng.randf_range(0.92, 0.99)))
					s += L
				z += h

	func quoins(hs: Dictionary) -> void:
		var col = b.get("quoins", hs.get("quoins", null))
		if col == null: return
		var mat := HouseKit.tinted(P.stone(Color(col)))
		var box := HouseKit.unit_box()
		var y := 0.78
		var k := 0
		while y < H - 0.3:
			var lf := Vector2(0.56, 0.3) if k % 2 == 0 else Vector2(0.3, 0.56)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					if party.has("right" if sx > 0 else "left"): continue
					var pos := Vector3(sx * (W / 2.0 - lf.x / 2.0 + 0.04), y + 0.17, sz * (D / 2.0 - lf.y / 2.0 + 0.04))
					var t := rng.randf_range(0.92, 1.05)
					put(box, Transform3D(Basis.from_scale(Vector3(lf.x, 0.34, lf.y)), pos), high_at(y), mat, Color(t, t, t * 0.98))
			y += 0.37
			k += 1

	func bands() -> void:
		var tm := P.plaster(trim)
		for sz in [-1, 1]:
			for fl in range(1, floors):
				var y := HouseKit.GROUND_FLOOR + HouseKit.FLOOR * (fl - 1)
				add(P.box(W + 0.04, 0.16, 0.07), tm, Vector3(0, y - 0.08, sz * (D / 2.0 + 0.03)), Vector3.ZERO, true)
			add(P.box(W + 0.04, 0.22, 0.13), tm, Vector3(0, H - 0.12, sz * (D / 2.0 + 0.06)), Vector3.ZERO, true)

	func openings() -> void:
		var slots := maxi(1, roundi((W - 0.6) / 1.75))
		var xs: Array = []
		for i in slots: xs.append(-W / 2.0 + W * (i + 0.5) / slots)
		var is_shop := shop_w > 0.0
		var gap := 1.0
		if is_shop:
			gap = shop_w / 2.0 + 0.55
			shopfront()
		else:
			door()
		for x in xs:
			if absf(x - door_u) > gap: window("front", x, 0.85, 1.0, 1.3)
		var balcony_at := -1
		var wants := rng.randf() < 0.5 and not is_shop
		if floors >= 2 and bool(b.get("balcony", wants)):
			var best := 1e9
			for i in xs.size():
				if absf(xs[i] - door_u) < best:
					best = absf(xs[i] - door_u)
					balcony_at = i
		for fl in range(1, floors):
			var y := HouseKit.GROUND_FLOOR + HouseKit.FLOOR * (fl - 1)
			for i in xs.size():
				if fl == 1 and i == balcony_at: balcony(xs[i], y)
				else: window("front", xs[i], y + 0.7, 1.0, 1.4)
		if not party.has("back"):
			for x in xs:
				window("back", x, 0.85, 0.8, 1.15, "", true)
				for fl in range(1, floors): window("back", x, HouseKit.GROUND_FLOOR + HouseKit.FLOOR * (fl - 1) + 0.75, 0.8, 1.25)
		var spots: Array = [-D / 4.0, D / 4.0] if D > 4.5 else [0.0]
		for side in ["left", "right"]:
			if party.has(side): continue
			for u in spots:
				if floors == 1: window(side, u, 0.85, 0.8, 1.15)
				for fl in range(1, floors): window(side, u, HouseKit.GROUND_FLOOR + HouseKit.FLOOR * (fl - 1) + 0.75, 0.8, 1.25)
		if not is_shop:
			if rng.randf() < 0.6:
				put(HouseKit.part_mesh("wall_lamp"), Transform3D(Basis.IDENTITY, Vector3(door_u - 0.95, 2.25, D / 2.0)), false)
				put(HouseKit.part_mesh("wall_lamp", {}, true), Transform3D(Basis.IDENTITY, Vector3(door_u - 0.95, 2.25, D / 2.0)), false, glass_mat, Color.WHITE, false)
			if rng.randf() < 0.7:
				for s in [-1, 1]:
					if rng.randf() < 0.6: put(HouseKit.part_mesh("pot_flowers"), Transform3D(Basis.IDENTITY, Vector3(door_u + s * 1.05, 0.0, D / 2.0 + 0.35)), false)

	func window(side: String, u: float, zb: float, ww: float, wh: float, state: String = "", grate: bool = false) -> void:
		var hi := high_at(zb)
		var fx := facade(side)
		var xf := fx * Transform3D(Basis.from_scale(Vector3(ww, wh / 1.4, 1.0)), Vector3(u, zb, 0.0))
		put(HouseKit.part_mesh("window"), xf, hi)
		put(HouseKit.part_mesh("window", {}, true), xf, hi, glass_mat, Color.WHITE, false)
		if grate: put(HouseKit.part_mesh("grate"), xf, hi)
		var st := state
		if st == "":
			var r := rng.randf()
			st = "open" if r < 0.6 else ("shut" if r < 0.75 else ("ajar" if r < 0.9 else "half"))
		var angles: Array = {"open": [178, 178], "shut": [0, 0], "ajar": [110, 135], "half": [178, 0]}[st]
		var rc := {HouseKit.SHUTTER_KEY: shutter}
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			var leaf := HouseKit.part_mesh("shutter_%d" % angles[k], rc, false, k == 1)
			put(leaf, fx * Transform3D(Basis.from_scale(Vector3(ww, wh / 1.4, 1.0)), Vector3(u + sgn * ww / 2.0, zb, 0.0)), hi)
		if enter and not hi:
			var wi := Props._window()
			var inner := f.transform * fx * Transform3D(Basis(Vector3.UP, PI), Vector3(u, zb + wh / 2.0, -Interiors.WALL_T - 0.03))
			wi.transform = inner
			g.add_child(wi)
			glasses.append(wi.get_node("glass"))

	func balcony(u: float, y: float) -> void:
		var fx := facade("front")
		var xf := fx * Transform3D(Basis.IDENTITY, Vector3(u, y, 0.0))
		put(HouseKit.part_mesh("balcony"), xf, enter)
		put(HouseKit.part_mesh("balcony", {}, true), xf, enter, glass_mat, Color.WHITE, false)
		var rc := {HouseKit.SHUTTER_KEY: shutter}
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			put(HouseKit.part_mesh("shutter_178", rc, false, k == 1), fx * Transform3D(Basis.from_scale(Vector3(1.0, 2.0 / 1.4, 1.0)), Vector3(u + sgn * 0.5, y + 0.06, 0.0)), enter)

	func door() -> void:
		var c := door_color()
		var rc := {HouseKit.DOOR_KEYS[0]: c, HouseKit.DOOR_KEYS[1]: c}
		var part := "doorway_arched" if enter else ("door_arched" if rng.randf() < 0.6 else "door_plain")
		var xf := Transform3D(Basis.IDENTITY, Vector3(door_u, 0.0, D / 2.0))
		put(HouseKit.part_mesh(part, rc), xf, false)
		put(HouseKit.part_mesh(part, rc, true), xf, false, glass_mat, Color.WHITE, false)

	func shopfront() -> void:
		var part := "shopfront_open" if enter else "shopfront"
		var rc := {HouseKit.FRAME_KEY: String(b.get("shopFrame", HouseKit.FRAME_KEY)).trim_prefix("#")}
		var xf := Transform3D(Basis.from_scale(Vector3(shop_w / 3.0, 1.0, 1.0)), Vector3(door_u, 0.0, D / 2.0))
		put(HouseKit.part_mesh(part, rc), xf, false)
		put(HouseKit.part_mesh(part, rc, true), xf, false, glass_mat, Color.WHITE, false)
		var sign := String(b.get("sign", ""))
		if sign != "":
			var lb := Label3D.new()
			lb.text = sign.to_upper()
			lb.font_size = 56
			lb.pixel_size = 0.0045
			lb.modulate = Color("2b2622")
			lb.outline_size = 0
			lb.shaded = true
			lb.double_sided = false
			lb.position = Vector3(door_u, 2.62, D / 2.0 + 0.1)
			f.add_child(lb)
		if b.has("awning"):
			var aw := shop_w + 0.2
			var n := 9
			for i in n:
				var col: String = "ece3d0" if i % 2 == 0 else String(b.awning).trim_prefix("#")
				var x := door_u - aw / 2.0 + aw * (i + 0.5) / n
				add(P.box(aw / n, 0.03, 0.85), P.fabric(col), Vector3(x, 2.18, D / 2.0 + 0.42), Vector3(deg_to_rad(24.0), 0, 0))
				add(P.box(aw / n, 0.16, 0.025), P.fabric(col), Vector3(x, 1.93, D / 2.0 + 0.81))

	func roof() -> void:
		var left := 0.02 if party.has("left") else HouseKit.SIDE_OVERHANG
		var right := 0.02 if party.has("right") else HouseKit.SIDE_OVERHANG
		var RW := W + left + right
		var cx := (right - left) / 2.0
		var run := D / 2.0 + HouseKit.OVERHANG
		var slope := run / cos(HouseKit.PITCH)
		var ridge := Vector3(cx, H + rise, 0.0)
		var tmat := HouseKit.tile_material(Color(b.roof))
		var cap := HouseKit.part_mesh("coppo_cap")
		var pan := HouseKit.part_mesh("coppo_pan")
		var wood := P.wood("5e4632")
		var sag := float(b.get("sag", 0.04))
		var sp := sin(HouseKit.PITCH)
		var cp := cos(HouseKit.PITCH)
		for sgn in [-1.0, 1.0]:
			var down := Vector3(0.0, -sp, sgn * cp)
			var nrm := Vector3(0.0, cp, sgn * sp)
			add(P.box(RW, 0.06, slope), wood, ridge + down * slope / 2.0 - nrm * 0.03, Vector3(sgn * HouseKit.PITCH, 0, 0), true)
			var pitch_x := 0.34
			var cols := int(RW / pitch_x)
			var x0 := cx - cols * pitch_x / 2.0
			var rows := int(slope / 0.36) + 1
			for c in cols * 2 + 1:
				var is_cap := c % 2 == 1
				var u := x0 + c * pitch_x / 2.0
				var lift := sag * (1.0 - sin(PI * clampf((u - x0) / (cols * pitch_x), 0.0, 1.0)))
				for k in rows:
					var y := maxf(slope - 0.44 - k * 0.36 + rng.randf_range(-0.02, 0.02), -0.02)
					var origin := ridge + Vector3(u - cx + rng.randf_range(-0.012, 0.012), 0, 0) + down * y + nrm * ((0.045 if is_cap else 0.0) + lift)
					var basis := Basis(Vector3(-sgn, 0, 0), nrm, -down)
					basis = Basis(nrm, deg_to_rad(rng.randf_range(-2.5, 2.5))) * basis
					var roll := rng.randf()
					var t := rng.randf_range(0.9, 1.1)
					var col := Color(t, t * rng.randf_range(0.95, 1.0), t * rng.randf_range(0.9, 1.0))
					if roll < 0.05: col = Color(col.r * 0.72, col.g * 0.8, col.b * 0.62)
					elif roll < 0.11: col = Color(col.r * 1.12, col.g * 1.08, col.b)
					put(cap if is_cap else pan, Transform3D(basis, origin), true, tmat, col)
			var ez := H + rise - run * tan(HouseKit.PITCH)
			add(P.box(RW, 0.14, 0.05), wood, Vector3(cx, ez - 0.07, sgn * run - sgn * 0.02), Vector3.ZERO, true)
			add(P.cyl(0.065, 0.065, RW, 10), P.mat("a8683a"), Vector3(cx, ez - 0.1, sgn * (run + 0.05)), Vector3(0, 0, PI / 2.0), true)
			var nraf := int(W / 0.5)
			var raf := HouseKit.unit_box()
			var rmat := HouseKit.tinted(P.wood("6a4e36"))
			for i in nraf + 1:
				var x := -W / 2.0 + 0.1 + i * (W - 0.2) / nraf
				var yy := H + rise - (D / 2.0 + HouseKit.OVERHANG / 2.0) * tan(HouseKit.PITCH) - 0.13
				var rt := rng.randf_range(0.9, 1.06)
				put(raf, Transform3D(Basis(Vector3.RIGHT, sgn * HouseKit.PITCH) * Basis.from_scale(Vector3(0.085, 0.12, HouseKit.OVERHANG + 0.06)), Vector3(x, yy, sgn * (D / 2.0 + HouseKit.OVERHANG / 2.0))), true, rmat, Color(rt, rt, rt))
			for s in [-1.0, 1.0]:
				if party.has("right" if s > 0.0 else "left"): continue
				add(P.box(0.05, 0.2, slope), wood, ridge + down * slope / 2.0 + Vector3(s * RW / 2.0, -0.02, 0), Vector3(sgn * HouseKit.PITCH, 0, 0), true)
		add(P.box(RW, 0.08, 0.22), P.plaster("d8cdb8"), Vector3(cx, H + rise + 0.02, 0), Vector3.ZERO, true)
		var n := int(RW / 0.38) + 1
		var rb := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)) * Basis.from_scale(Vector3(1.3, 1.0, 0.95))
		for i in n:
			var x := cx - RW / 2.0 + i * RW / n
			var t := rng.randf_range(0.9, 1.08)
			put(cap, Transform3D(rb, Vector3(x, H + rise + 0.06, 0)), true, tmat, Color(t, t, t))

	func chimney() -> void:
		var cxp := rng.randf_range(-W * 0.3, W * 0.3)
		var cz := -D * 0.18
		var z_roof := H + rise - absf(cz) * tan(HouseKit.PITCH)
		var top := H + rise + 0.9
		var base := z_roof - 0.3
		put(HouseKit.part_mesh("chimney_stack"), Transform3D(Basis.from_scale(Vector3(1, top - base, 1)), Vector3(cxp, base, cz)), true)
		put(HouseKit.part_mesh("chimney_cap"), Transform3D(Basis.IDENTITY, Vector3(cxp, top, cz)), true)
		chimney_top = f.transform * Vector3(cxp, top + 0.6, cz)

	func downpipe() -> void:
		var s := 1.0 if not party.has("right") else -1.0
		if party.has("left") and party.has("right"): return
		var x := s * (W / 2.0 - 0.15)
		var top := H + rise - (D / 2.0 + HouseKit.OVERHANG) * tan(HouseKit.PITCH) - 0.15
		var copper := P.mat("a8683a")
		add(P.cyl(0.05, 0.05, top - 0.35, 8), copper, Vector3(x, (top + 0.25) / 2.0 + 0.05, D / 2.0 + 0.08), Vector3.ZERO, true)
		add(P.cyl(0.05, 0.05, HouseKit.OVERHANG - 0.1, 8), copper, Vector3(x, top - 0.05, D / 2.0 + 0.08 + (HouseKit.OVERHANG - 0.2) / 2.0), Vector3(PI / 2.0, 0, 0), true)

	func flush() -> void:
		for key in batches:
			var bt: Dictionary = batches[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var colored := false
			for c in bt.col:
				if c != Color.WHITE: colored = true
			mm.use_colors = colored
			mm.mesh = bt.mesh
			mm.instance_count = bt.xf.size()
			for i in bt.xf.size():
				mm.set_instance_transform(i, bt.xf[i])
				if colored: mm.set_instance_color(i, bt.col[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = bt.override
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bt.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.add_child(mmi)
			if bt.high and enter: over.append(mmi)
			if bt.override == glass_mat: glasses.append(mmi)
