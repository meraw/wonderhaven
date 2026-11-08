extends RefCounted

const P := preload("../../world/palette.gd")
const Palazzo := preload("palazzo.gd")

const MARBLE := "efeae0"
const BLACK := "2b2b2e"
const CASTLE_STONE := "8a8a86"

static func _box(parent: Node3D, w: float, h: float, d: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props._add(parent, P.box(w, h, d), mat, pos, rot)

static func church(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var parts := HouseKit.Parts.new(g)
	var W := float(b.w)
	var D := float(b.d)
	var H := float(b.get("h", 14.0))
	var white := P.stone(MARBLE)
	var dark := Palazzo.tinted("stone")
	_box(g, W, H, D, white, Vector3(0, H / 2.0, 0))
	var y := 0.9
	while y < H - 0.3:
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(W + 0.04, 0.55, 0.04)), Vector3(0, y, D / 2.0 + 0.01)), false, dark, Color(BLACK))
		for s in [-1.0, 1.0]:
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(0.04, 0.55, D + 0.04)), Vector3(s * (W / 2.0 + 0.01), y, 0)), false, dark, Color(BLACK))
		y += 1.1
	var rise := W / 2.0 * 0.45
	var gable := PrismMesh.new()
	gable.size = Vector3(W, rise, D)
	Props._add(g, gable, white, Vector3(0, H + rise / 2.0, 0))
	for s in [-1.0, 1.0]:
		var slope := sqrt(W * W / 4.0 + rise * rise)
		var ang := atan2(rise, W / 2.0)
		_box(g, slope + 0.4, 0.12, D + 0.5, P.stone("5d636a"), Vector3(s * W / 4.0, H + rise / 2.0 + 0.08, 0), Vector3(0, 0, -s * ang))
	_box(g, 2.6, 4.0, 0.12, P.stone("d8cfbf"), Vector3(0, 2.0, D / 2.0 + 0.05))
	_box(g, 2.0, 3.4, 0.16, P.mat("2a2420"), Vector3(0, 1.7, D / 2.0 + 0.07))
	var rose := Props._add(g, P.cyl(1.5, 1.5, 0.12, 24), P.stone("d8cfbf"), Vector3(0, H - 2.6, D / 2.0 + 0.06), Vector3(PI / 2.0, 0, 0))
	rose.name = "rose_frame"
	var glass := P.unique_mat("3a3550", "ffcf6b", 0.0)
	Props._add(g, P.cyl(1.15, 1.15, 0.14, 24), glass, Vector3(0, H - 2.6, D / 2.0 + 0.08), Vector3(PI / 2.0, 0, 0))
	for k in 3:
		_box(g, 4.0 - k * 0.6, 0.18, 0.5, P.stone("cfc8bd"), Vector3(0, 0.09 + k * 0.18, D / 2.0 + 0.55 - k * 0.25))
	var tx := W / 2.0 - 1.7
	var tz := -D / 2.0 + 1.7
	var th := H + 9.0
	_box(g, 3.2, th, 3.2, white, Vector3(tx, th / 2.0, tz))
	var ty := 1.2
	while ty < th - 3.6:
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(3.24, 0.5, 3.24)), Vector3(tx, ty, tz)), false, dark, Color(BLACK))
		ty += 1.1
	for side in 4:
		var a := side * PI / 2.0
		var off := Vector3(sin(a), 0, cos(a)) * 1.62
		_box(g, 0.9 if side % 2 == 0 else 0.1, 1.8, 0.1 if side % 2 == 0 else 0.9, P.mat("231f1c"), Vector3(tx, th - 2.2, tz) + off)
	var spire := Props._add(g, P.cone(2.5, 3.2, 4), P.stone("5d636a"), Vector3(tx, th + 1.6, tz), Vector3(0, PI / 4.0, 0))
	spire.name = "spire"
	_box(g, 0.08, 0.9, 0.08, P.mat("3a3a3a"), Vector3(tx, th + 3.6, tz))
	_box(g, 0.5, 0.08, 0.08, P.mat("3a3a3a"), Vector3(tx, th + 3.8, tz))
	parts.flush()
	g.set_meta("glasses", [])
	return g

static func castle(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var parts := HouseKit.Parts.new(g)
	var W := float(b.w)
	var D := float(b.d)
	var H := float(b.get("h", 9.0))
	var stone := P.stone(CASTLE_STONE)
	var tint := Palazzo.tinted("stone")
	var t := 2.0
	_box(g, W - 2.0 * t, 0.3, D - 2.0 * t, P.stone("9a958c"), Vector3(0, 0.15, 0))
	_box(g, W, H, t, stone, Vector3(0, H / 2.0, -D / 2.0 + t / 2.0))
	var gate_x := float(b.get("gateX", -10.0))
	var gw := 3.0
	var west_len := gate_x - gw / 2.0 + W / 2.0
	_box(g, west_len, H, t, stone, Vector3(-W / 2.0 + west_len / 2.0, H / 2.0, D / 2.0 - t / 2.0))
	var east_len := W / 2.0 - (gate_x + gw / 2.0)
	_box(g, east_len, H, t, stone, Vector3(W / 2.0 - east_len / 2.0, H / 2.0, D / 2.0 - t / 2.0))
	_box(g, gw, H - 4.2, t, stone, Vector3(gate_x, 4.2 + (H - 4.2) / 2.0, D / 2.0 - t / 2.0))
	_box(g, gw - 0.4, 4.0, 0.2, P.mat("2a2622"), Vector3(gate_x, 2.0, D / 2.0 - t + 0.1))
	_box(g, t, H, D, stone, Vector3(-W / 2.0 + t / 2.0, H / 2.0, 0))
	var gap: Vector2 = Vector2(float(b.get("breachFrom", -4.0)), float(b.get("breachTo", 3.0)))
	var north_len := gap.x + D / 2.0
	var south_len := D / 2.0 - gap.y
	_box(g, t, H, north_len, stone, Vector3(W / 2.0 - t / 2.0, H / 2.0, -D / 2.0 + north_len / 2.0))
	_box(g, t, H, south_len, stone, Vector3(W / 2.0 - t / 2.0, H / 2.0, D / 2.0 - south_len / 2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in 9:
		var z := lerpf(gap.x, gap.y, (k + 0.5) / 9.0)
		var hgt := rng.randf_range(0.6, 2.4) * (1.0 - absf((k - 4.0) / 5.0)) + 0.3
		parts.put(HouseKit.unit_box(), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis.from_scale(Vector3(t * rng.randf_range(0.7, 1.0), hgt, 0.9)), Vector3(W / 2.0 - t / 2.0, hgt / 2.0, z)), false, tint, Color(CASTLE_STONE).darkened(rng.randf_range(0.0, 0.2)))
	for e in [gap.x, gap.y]:
		var jag := rng.randf_range(1.0, 2.5)
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(t, jag, 0.8)), Vector3(W / 2.0 - t / 2.0, H + jag / 2.0 - 1.5, e)), false, tint, Color(CASTLE_STONE))
	var merlon := HouseKit.unit_box()
	for side in ["n", "s", "w", "e"]:
		var length := W if side in ["n", "s"] else D
		var n := int(length / 1.3)
		for i in n:
			var u := -length / 2.0 + (i + 0.5) * length / n
			var pos := Vector3.ZERO
			match side:
				"n": pos = Vector3(u, H + 0.45, -D / 2.0 + 0.4)
				"s": pos = Vector3(u, H + 0.45, D / 2.0 - 0.4)
				"w": pos = Vector3(-W / 2.0 + 0.4, H + 0.45, u)
				"e": pos = Vector3(W / 2.0 - 0.4, H + 0.45, u)
			if side == "e" and u > gap.x - 0.5 and u < gap.y + 0.5: continue
			if side == "s" and absf(u - gate_x) < 0.1: continue
			parts.put(merlon, Transform3D(Basis.from_scale(Vector3(0.7, 0.9, 0.7)), pos), false, tint, Color(CASTLE_STONE).lightened(0.05))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var p := Vector3(cx * (W / 2.0 - 2.2), 0, cz * (D / 2.0 - 2.2))
			Props._add(g, P.cyl(2.6, 2.9, H + 3.0, 16), stone, p + Vector3(0, (H + 3.0) / 2.0, 0))
			for k in 8:
				var a := k * TAU / 8.0
				parts.put(merlon, Transform3D(Basis.from_scale(Vector3(0.75, 0.9, 0.75)), p + Vector3(cos(a) * 2.25, H + 3.45, sin(a) * 2.25)), false, tint, Color(CASTLE_STONE).lightened(0.05))
	var keep := Vector3(-W / 2.0 + 8.0, 0, -D / 2.0 + 7.5)
	_box(g, 9.0, H + 7.0, 9.0, stone, keep + Vector3(0, (H + 7.0) / 2.0, 0))
	for k in 4:
		_box(g, 0.25, 1.2, 0.1, P.mat("231f1c"), keep + Vector3(-2.0 + k * 1.3, H + 3.5, 4.55))
	_box(g, 0.1, 3.0, 0.1, P.mat("3a3a3a"), keep + Vector3(0, H + 8.5, 0))
	var flag := Node3D.new()
	flag.position = keep + Vector3(0.65, H + 9.5, 0)
	g.add_child(flag)
	var cols := ["2f8a4a", "f2efe6", "c8302c"]
	for i in 3: _box(flag, 0.4, 0.8, 0.03, P.fabric(cols[i]), Vector3(-0.4 + i * 0.4, 0, 0))
	parts.flush()
	g.set_meta("glasses", [])
	return g

static func station(b: Dictionary, base: float, ground: Callable) -> Node3D:
	var spec := b.duplicate()
	spec["floors"] = 2
	spec["painted"] = 0.15
	spec["sign"] = String(b.get("sign", "Tonnarella"))
	var g := Palazzo.build(spec, base, ground)
	var W := float(b.w)
	var D := float(b.d)
	var clock := Node3D.new()
	clock.name = "station_clock"
	clock.position = Vector3(0, 7.1, D / 2.0 + 0.12)
	g.add_child(clock)
	Props._add(clock, P.cyl(0.75, 0.75, 0.1, 24), P.mat("f2ede0"), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	Props._add(clock, P.cyl(0.82, 0.82, 0.06, 24), P.mat("2b2b2e"), Vector3(0, 0, -0.04), Vector3(PI / 2.0, 0, 0))
	_box(clock, 0.05, 0.55, 0.03, P.mat("1e1e1e"), Vector3(0, 0.22, 0.07))
	_box(clock, 0.4, 0.05, 0.03, P.mat("1e1e1e"), Vector3(0.16, 0, 0.07))
	var iron := P.mat("2f3a33")
	var cw := W - 2.0
	var depth := float(b.get("canopy", 2.8))
	for i in 7:
		var x := -cw / 2.0 + cw * i / 6.0
		Props._add(g, P.cyl(0.08, 0.1, 3.4, 8), iron, Vector3(x, 1.7, -D / 2.0 - depth + 0.3))
	_box(g, cw + 0.6, 0.1, depth + 0.4, P.mat("6f7a72"), Vector3(0, 3.5, -D / 2.0 - depth / 2.0), Vector3(-0.08, 0, 0))
	_box(g, cw + 0.6, 0.25, 0.1, iron, Vector3(0, 3.3, -D / 2.0 - depth + 0.2))
	return g

static func lighthouse(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var W := float(b.w)
	var D := float(b.d)
	var H := float(b.get("h", 24.0))
	var stone := P.stone(String(b.get("wall", "e6dfd2")))
	var quoin := P.stone("b8b0a2")
	_box(g, W + 1.0, 1.2, D + 1.0, P.stone("a39d90"), Vector3(0, 0.6, 0))
	_box(g, W, H, D, stone, Vector3(0, H / 2.0, 0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(g, 0.5, H, 0.5, quoin, Vector3(cx * (W / 2.0 - 0.2), H / 2.0, cz * (D / 2.0 - 0.2)))
	for k in range(1, 6):
		_box(g, 0.5, 0.9, 0.1, P.unique_mat(HouseKit.GLASS, "ffcf6b", 0.0), Vector3(0, k * 4.0 + 1.0, -D / 2.0 - 0.05))
	_box(g, 1.3, 2.3, 0.1, P.mat("3a2e24"), Vector3(-W / 2.0 - 0.05, 1.15 + 1.2, 0), Vector3(0, PI / 2.0, 0))
	_box(g, W + 0.8, 0.5, D + 0.8, P.stone("cfc8bd"), Vector3(0, H - 0.25, 0))
	for k in 12:
		var a := k * TAU / 12.0
		_box(g, 0.35, 0.4, 0.35, P.stone("cfc8bd"), Vector3(cos(a) * (W / 2.0 + 0.2), H - 0.7, sin(a) * (D / 2.0 + 0.2)))
	return g

static func lantern(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var over: Array = []
	var bronze := P.mat("3f5a4c")
	var glass := P.unique_mat("8fb3c4", "fff1b8", 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.85, 0.95, 0.35)
	var missing: Array = b.get("brokenPanes", [1, 4])
	var pane := 0
	for r in Interiors.walls(b):
		var w := float(r.maxX) - float(r.minX)
		var d := float(r.maxZ) - float(r.minZ)
		var c := Vector3((float(r.minX) + float(r.maxX)) / 2.0 - float(b.x), 0, (float(r.minZ) + float(r.maxZ)) / 2.0 - float(b.z))
		_box(g, w, 1.0, d, P.stone("cfc8bd"), c + Vector3(0, 0.5, 0))
		if not missing.has(pane): Props._add(g, P.box(w * 0.96, 1.3, d * 0.96), glass, c + Vector3(0, 1.65, 0), Vector3.ZERO, Vector3.ONE, false)
		pane += 1
		_box(g, maxf(w, 0.08) if w > d else 0.08, 0.08, maxf(d, 0.08) if d > w else 0.08, bronze, c + Vector3(0, 2.33, 0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(g, 0.1, 2.4, 0.1, bronze, Vector3(cx * (float(b.w) / 2.0 - 0.05), 1.2, cz * (float(b.d) / 2.0 - 0.05)))
	over.append(Props._add(g, P.box(float(b.w) + 0.3, 0.12, float(b.d) + 0.3), bronze, Vector3(0, 2.46, 0)))
	over.append(Props._add(g, P.cone(float(b.w) * 0.62, 1.4, 12), bronze, Vector3(0, 3.2, 0)))
	over.append(Props._add(g, P.sphere(0.25, 10, 8), bronze, Vector3(0, 4.05, 0)))
	_box(g, float(b.w) - 0.1, 0.05, float(b.d) - 0.1, P.stone("b8b0a2"), Vector3(0, 0.025, 0))
	var lens := Node3D.new()
	lens.name = "lens"
	lens.position = Vector3(0, 0.0, 0)
	g.add_child(lens)
	Props._add(lens, P.cyl(0.35, 0.45, 0.9, 10), P.mat("4a4a4a"), Vector3(0, 0.45, 0))
	var lens_glass := P.unique_mat("cfe6ee", "fff1b8", 0.0)
	Props._add(lens, P.cyl(0.42, 0.42, 1.0, 12), lens_glass, Vector3(0, 1.4, 0))
	g.set_meta("glasses", [])
	g.set_meta("fade_parts", Props.fade_parts(over))
	return g

static func flag_mast(parent: Node3D, pos: Vector3, height: float = 6.0) -> void:
	Props._add(parent, P.cyl(0.06, 0.09, height, 8), P.mat("e8e4dc"), pos + Vector3(0, height / 2.0, 0))
	var cols := ["2f8a4a", "f2efe6", "c8302c"]
	for i in 3: _box(parent, 0.45, 0.9, 0.03, P.fabric(cols[i]), pos + Vector3(0.3 + i * 0.45, height - 0.6, 0))
