extends RefCounted

const P := preload("../../world/palette.gd")
const Mats := preload("mats.gd")

const GROUND := 3.6
const FLOOR := 3.0
const PITCH := 0.32
const EAVES := 0.45
const SHUTTERS := ["2f4f37", "3f5a3a", "4f6b43", "35503f"]
const SLATE := "5d636a"
const FOOTING := 0.9

static func tinted(kind: String) -> StandardMaterial3D: return Mats.tinted(kind)

static func pot_mesh() -> CylinderMesh: return Mats.pot_mesh()

static func leaf_mesh() -> SphereMesh: return Mats.leaf_mesh()

static func floors_of(b: Dictionary) -> int:
	if b.has("floors"): return int(b.floors)
	return maxi(1, int((float(b.get("h", 10.0)) - GROUND - 0.6) / FLOOR) + 1)

static func build(b: Dictionary, base: float, ground: Callable) -> Node3D:
	return _Palazzo.new(b, base, ground).make()


class _Palazzo:
	var b: Dictionary
	var base := 0.0
	var ground: Callable
	var g := Node3D.new()
	var f := Node3D.new()
	var parts: HouseKit.Parts
	var rng := RandomNumberGenerator.new()
	var W := 0.0
	var D := 0.0
	var H := 0.0
	var drop := 0.0
	var floors := 1
	var enter := false
	var party: Array = []
	var portico := 0.0
	var back := 0.0
	var wall := Color.WHITE
	var trim := Color.WHITE
	var shutter := "2f4f37"
	var over: Array = []
	var glass_mat: StandardMaterial3D
	var yaw := 0.0

	func _init(bd: Dictionary, p_base: float, p_ground: Callable) -> void:
		b = bd
		base = p_base
		ground = p_ground
		enter = Interiors.enterable(b)
		var side := String(b.get("door", "S"))
		var turned := side in ["E", "W"]
		W = float(b.d) if turned else float(b.w)
		D = float(b.w) if turned else float(b.d)
		H = float(b.get("h", 10.0))
		floors = floors_of_b()
		yaw = {"S": 0.0, "N": PI, "E": PI / 2.0, "W": -PI / 2.0}[side]
		f.rotation.y = yaw
		g.add_child(f)
		rng.seed = hash("%s|%s|%s" % [b.get("id", ""), b.x, b.z])
		parts = HouseKit.Parts.new(f)
		for s in b.get("party", []): party.append(_canonical(String(s)))
		portico = float(b.get("portico", 0.0))
		back = float(b.get("extendBack", 0.0))
		wall = Color(String(b.get("wall", "d4a24c")))
		trim = wall.lightened(0.38)
		shutter = String(b.get("shutters", SHUTTERS[rng.randi() % SHUTTERS.size()]))

	func floors_of_b() -> int:
		if b.has("floors"): return int(b.floors)
		return maxi(1, int((H - GROUND - 0.6) / FLOOR) + 1)

	func _canonical(world_side: String) -> String:
		var v: Vector3 = {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1), "E": Vector3(1, 0, 0), "W": Vector3(-1, 0, 0)}[world_side]
		var l := f.transform.basis.inverse() * v
		if absf(l.z) > absf(l.x): return "front" if l.z > 0.0 else "back"
		return "right" if l.x > 0.0 else "left"

	func facade(side: String, push: float = 0.0) -> Transform3D:
		match side:
			"back": return Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -D / 2.0 - back - push))
			"right": return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(W / 2.0 + push, 0, 0))
			"left": return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-W / 2.0 - push, 0, 0))
		return Transform3D(Basis.IDENTITY, Vector3(0, 0, D / 2.0 + push))

	func side_length(side: String) -> float:
		return W if side in ["front", "back"] else D

	func local_ground(side: String, u: float, push: float = 0.0) -> float:
		var xf := facade(side, push)
		var lp: Vector3 = xf * Vector3(u, 0.0, 0.6)
		var wp: Vector3 = f.transform * lp
		return float(ground.call(float(b.x) + wp.x, float(b.z) + wp.z)) - base

	func high_at(y: float) -> bool:
		return enter and y > Interiors.WALL_H - 0.3

	func make() -> Node3D:
		var low := 0.0
		for fx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			for fz in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				low = minf(low, maxf(-3.0, float(ground.call(float(b.x) + fx * float(b.w), float(b.z) + fz * float(b.d))) - base))
		drop = 0.0 if bool(b.get("onRoof", false)) else -low
		glass_mat = P.unique_mat(HouseKit.GLASS, "ffcf6b", 0.0)
		parts.glass_mat = glass_mat
		body()
		footing()
		bands()
		windows()
		if portico > 0.0: arcade()
		if not bool(b.get("noRoof", false)): roof()
		if bool(b.get("chimney", true)) and floors >= 2 and not bool(b.get("noRoof", false)): chimney()
		shop_sign()
		parts.flush()
		over.append_array(parts.high_nodes)
		g.set_meta("glasses", parts.glasses)
		if enter: g.set_meta("fade_parts", Props.fade_parts(over))
		return g

	func add(mesh: Mesh, mat: Material, pos: Vector3, high: bool = false, parent: Node3D = null) -> MeshInstance3D:
		var mi := Props._add(parent if parent else f, mesh, mat, pos)
		if high and enter: over.append(mi)
		return mi

	func body() -> void:
		var mat := P.plaster(wall)
		if enter:
			var wh := Interiors.WALL_H
			for r in Interiors.walls(b):
				Props._add(g, P.box(r.maxX - r.minX, wh, r.maxZ - r.minZ), mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, wh / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
			var di := Interiors.door_info(b)
			var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
			var lw := Vector3(Interiors.DOOR_W, wh - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, wh - Interiors.DOOR_H, Interiors.DOOR_W)
			Props._add(g, P.box(lw.x, lw.y, lw.z), mat, Vector3(dc.x, (wh + Interiors.DOOR_H) / 2.0, dc.y))
			Props._add(g, P.box(float(b.w) - 0.1, 0.05, float(b.d) - 0.1), P.stone(String(b.get("floorColor", "c9b49a"))), Vector3(0, 0.025, 0), Vector3.ZERO, Vector3.ONE, false)
			var upper := H - wh
			if upper > 0.05:
				over.append(Props._add(g, P.box(float(b.w), upper, float(b.d)), mat, Vector3(0, wh + upper / 2.0, 0)))
			if drop > 0.05:
				Props._add(g, P.box(float(b.w), drop, float(b.d)), P.stone(wall.darkened(0.35)), Vector3(0, -drop / 2.0, 0))
		else:
			var total := H + drop
			add(P.box(W, total, D), mat, Vector3(0, total / 2.0 - drop, 0))
		if back > 0.0:
			var tb := H + drop
			add(P.box(W, tb, back), mat, Vector3(0, tb / 2.0 - drop, -D / 2.0 - back / 2.0))
		if portico > 0.0:
			var oh := H - GROUND
			add(P.box(W, oh, portico), mat, Vector3(0, GROUND + oh / 2.0, D / 2.0 + portico / 2.0), false)
			add(P.box(W, 0.08, portico), P.plaster(wall.darkened(0.45)), Vector3(0, GROUND - 0.04, D / 2.0 + portico / 2.0), false)

	func footing() -> void:
		var mat := Mats.tinted("stone")
		var col := wall.darkened(0.42).lerp(Color("8c8478"), 0.5)
		for side in ["front", "back", "left", "right"]:
			if party.has(side): continue
			if side == "front" and enter: continue
			var length := side_length(side)
			var gl := local_ground(side, 0.0)
			var top := maxf(FOOTING, gl + FOOTING)
			var bottom := -drop
			var hgt := top - bottom
			if hgt <= 0.05: continue
			var spans: Array = [[-length / 2.0, length / 2.0]]
			if side == "front" and portico <= 0.0:
				var du := door_u()
				spans = [[-length / 2.0, du - 0.9], [du + 0.9, length / 2.0]]
			for sp in spans:
				var a: float = sp[0]
				var c: float = sp[1]
				if c - a < 0.1: continue
				parts.put(HouseKit.unit_box(), facade(side) * Transform3D(Basis.from_scale(Vector3(c - a + 0.03, hgt, 0.08)), Vector3((a + c) / 2.0, bottom + hgt / 2.0, 0.03)), false, mat, col)

	func bands() -> void:
		var mat := Mats.tinted("plaster")
		var push := portico
		for side in ["front", "back", "left", "right"]:
			if party.has(side): continue
			var length := side_length(side)
			var p := push if side == "front" else 0.0
			for k in range(1, floors):
				var y := GROUND + FLOOR * (k - 1) - 0.1
				if y < local_ground(side, 0.0, p) + 0.5: continue
				parts.put(HouseKit.unit_box(), facade(side, p) * Transform3D(Basis.from_scale(Vector3(length + 0.04, 0.14, 0.07)), Vector3(0, y, 0.035)), high_at(y), mat, trim)
			parts.put(HouseKit.unit_box(), facade(side, p) * Transform3D(Basis.from_scale(Vector3(length + 0.3, 0.3, 0.26)), Vector3(0, H - 0.15, 0.1)), high_at(H), mat, trim.darkened(0.06))

	func windows() -> void:
		for side in ["front", "back", "left", "right"]:
			if party.has(side): continue
			var length := side_length(side)
			var spacing := 2.6 if side == "front" else 3.2
			var n := maxi(1, roundi((length - 1.0) / spacing))
			var p := portico if side == "front" else 0.0
			var start := 1 if (side == "front" and portico > 0.0) else 0
			for k in range(start, floors):
				var y := 0.9 if k == 0 else GROUND + FLOOR * (k - 1) + 0.75
				for i in n:
					var u := -length / 2.0 + length * (i + 0.5) / n
					if y < local_ground(side, u, p) + 0.45: continue
					if k == 0 and side == "front" and absf(u - door_u()) < 1.2: continue
					if enter and k == 0: continue
					var painted := k > 0 and rng.randf() < float(b.get("painted", 0.3))
					if painted: painted_window(side, p, u, y)
					else: real_window(side, p, u, y, k == 0)
		if not enter and portico <= 0.0 and String(b.get("frontDoor", "yes")) != "no": front_door()

	func door_u() -> float:
		if enter:
			var di := Interiors.door_info(b)
			var c: Vector2 = di.c - Vector2(b.x, b.z)
			return (f.transform.basis.inverse() * Vector3(c.x, 0.0, c.y)).x
		return float(b.get("doorU", 0.0))

	func real_window(side: String, push: float, u: float, y: float, ground_floor: bool) -> void:
		var hi := high_at(y)
		var ww := 0.95
		var wh := 1.55 if not ground_floor else 1.1
		var fx := facade(side, push)
		parts.put(HouseKit.unit_box(), fx * Transform3D(Basis.from_scale(Vector3(ww + 0.42, wh + 0.5, 0.02)), Vector3(u, y + wh / 2.0, 0.01)), hi, Mats.tinted("plaster"), trim)
		parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, y, 0.0)), ww, wh, "" if ground_floor else shutter, _state(), ground_floor, hi, not bool(b.get("shut", false)))
		if not ground_floor and rng.randf() < 0.28: basil(fx, u, y, hi)
		if not ground_floor and side == "front" and rng.randf() < 0.12 and y < GROUND + FLOOR * 2.0:
			parts.put(HouseKit.part_mesh("balcony"), fx * Transform3D(Basis.IDENTITY, Vector3(u, y - 0.75, 0.0)), hi)

	func _state() -> String:
		if bool(b.get("shut", false)): return "shut"
		var r := rng.randf()
		return "open" if r < 0.45 else ("shut" if r < 0.7 else ("ajar" if r < 0.88 else "half"))

	func painted_window(side: String, push: float, u: float, y: float) -> void:
		var hi := high_at(y)
		var fx := facade(side, push)
		var paint := Mats.tinted("plaster")
		parts.put(HouseKit.unit_box(), fx * Transform3D(Basis.from_scale(Vector3(1.4, 2.05, 0.015)), Vector3(u, y + 0.78, 0.008)), hi, paint, trim)
		var green := Color(shutter).lightened(0.05)
		for s in [-1.0, 1.0]:
			parts.put(HouseKit.unit_box(), fx * Transform3D(Basis.from_scale(Vector3(0.47, 1.5, 0.02)), Vector3(u + s * 0.245, y + 0.78, 0.016)), hi, paint, green)
			for k in 4:
				parts.put(HouseKit.unit_box(), fx * Transform3D(Basis.from_scale(Vector3(0.43, 0.025, 0.024)), Vector3(u + s * 0.245, y + 0.2 + k * 0.38, 0.018)), hi, paint, green.darkened(0.3))
		parts.put(HouseKit.unit_box(), fx * Transform3D(Basis.from_scale(Vector3(1.55, 0.12, 0.05)), Vector3(u, y + 1.62, 0.025)), hi, paint, trim.darkened(0.12))

	func basil(fx: Transform3D, u: float, y: float, hi: bool) -> void:
		var x := u + rng.randf_range(-0.25, 0.25)
		parts.put(Mats.pot_mesh(), fx * Transform3D(Basis.from_scale(Vector3(0.24, 0.2, 0.24)), Vector3(x, y + 0.1, 0.16)), hi, Mats.tinted("plaster"), Color("b5653a"))
		var green := Color("4f8a3a").lerp(Color("6aa04a"), rng.randf())
		parts.put(Mats.leaf_mesh(), fx * Transform3D(Basis.from_scale(Vector3(0.32, 0.26, 0.3)), Vector3(x, y + 0.3, 0.16)), hi, Mats.tinted("leaf"), green)

	func front_door() -> void:
		var u := door_u()
		if local_ground("front", u) > 0.3: return
		var col := "4a3a2a" if rng.randf() < 0.5 else "3f4f3a"
		parts.door(Transform3D(Basis.IDENTITY, Vector3(u, 0.0, D / 2.0)), col, false, true, false)
		parts.put(HouseKit.unit_box(), facade("front") * Transform3D(Basis.from_scale(Vector3(1.7, 2.9, 0.03)), Vector3(u, 1.45, 0.012)), false, Mats.tinted("stone"), Color("bcb3a2"))

	func arcade() -> void:
		var stone := Mats.tinted("stone")
		var col := Color("8f877a")
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(W, 0.55, 0.5)), Vector3(0, GROUND - 0.27, D / 2.0 + portico - 0.2)), false, stone, col)
		if not enter:
			add(P.box(W - 0.1, GROUND - 0.1, 0.06), P.plaster(Color("5a4a3e")), Vector3(0, (GROUND - 0.1) / 2.0, D / 2.0 + 0.04))
			var n := maxi(1, int(W / 4.0))
			for i in n:
				var u := -W / 2.0 + W * (i + 0.5) / n
				var part := "shopfront_open" if rng.randf() < 0.4 else "shopfront"
				parts.put(HouseKit.part_mesh(part, {HouseKit.FRAME_KEY: shutter}), Transform3D(Basis.from_scale(Vector3(0.9, 1.0, 1.0)), Vector3(u, 0.0, D / 2.0 + 0.05)), false)
				parts.put(HouseKit.part_mesh(part, {HouseKit.FRAME_KEY: shutter}, true), Transform3D(Basis.from_scale(Vector3(0.9, 1.0, 1.0)), Vector3(u, 0.0, D / 2.0 + 0.05)), false, glass_mat, Color.WHITE, false)

	func roof() -> void:
		var depth := D + portico + back
		var cz := (portico - back) / 2.0
		var left := 0.02 if party.has("left") else EAVES
		var right := 0.02 if party.has("right") else EAVES
		var rw := W + left + right
		var cx := (right - left) / 2.0
		var rise := depth / 2.0 * tan(PITCH)
		var slate := Mats.tinted("slate")
		var base_col := Color(String(b.get("roof", SLATE)))
		var infill := PrismMesh.new()
		infill.size = Vector3(depth, rise, W)
		infill.left_to_right = 0.5
		var gable := add(infill, P.plaster(wall), Vector3(0, H + rise / 2.0 - 0.01, cz), true)
		gable.rotation.y = PI / 2.0
		var run := depth / 2.0 + EAVES
		var slope := run / cos(PITCH)
		var rows := int(slope / 0.3) + 1
		for sgn in [-1.0, 1.0]:
			var down := Vector3(0.0, -sin(PITCH), sgn * cos(PITCH))
			var nrm := Vector3(0.0, cos(PITCH), sgn * sin(PITCH))
			var ridge := Vector3(cx, H + rise, cz)
			var basis := Basis(Vector3.RIGHT, sgn * PITCH)
			parts.put(HouseKit.unit_box(), Transform3D(basis * Basis.from_scale(Vector3(rw, 0.06, slope)), ridge + down * slope / 2.0 - nrm * 0.02), high_at(H), slate, base_col.darkened(0.25))
			for k in rows:
				var along := minf(slope - 0.15, 0.15 + k * 0.3)
				var t := rng.randf_range(0.86, 1.12)
				var c := Color(base_col.r * t, base_col.g * t, base_col.b * t * rng.randf_range(0.97, 1.04))
				parts.put(HouseKit.unit_box(), Transform3D(basis * Basis(Vector3.RIGHT, sgn * 0.05) * Basis.from_scale(Vector3(rw, 0.035, 0.34)), ridge + down * along + nrm * 0.03), high_at(H), slate, c)
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(rw, 0.12, 0.3)), Vector3(cx, H + rise + 0.04, cz)), high_at(H), slate, base_col.darkened(0.35))

	func chimney() -> void:
		var x := rng.randf_range(-W * 0.3, W * 0.3)
		var z := rng.randf_range(-D * 0.3, -D * 0.05)
		var depth := D + portico + back
		var rise := depth / 2.0 * tan(PITCH)
		var roof_y := H + rise - absf(z - (portico - back) / 2.0) * tan(PITCH)
		parts.put(HouseKit.part_mesh("chimney_stack"), Transform3D(Basis.from_scale(Vector3(1, 1.2, 1)), Vector3(x, roof_y - 0.3, z)), high_at(H))
		parts.put(HouseKit.part_mesh("chimney_cap"), Transform3D(Basis.IDENTITY, Vector3(x, roof_y + 0.9, z)), high_at(H))

	func shop_sign() -> void:
		var text := String(b.get("sign", ""))
		if text == "": return
		var lb := Label3D.new()
		lb.text = text.to_upper()
		lb.font_size = 64
		lb.pixel_size = 0.006
		lb.modulate = Color("2b2622")
		lb.outline_size = 0
		lb.shaded = true
		lb.double_sided = false
		lb.position = Vector3(door_u(), GROUND + 0.35, D / 2.0 + portico + 0.06)
		f.add_child(lb)
