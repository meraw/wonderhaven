extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const G := preload("res://scripts/locations/cliffs/ground_data.gd")
const Trains := preload("res://scripts/locations/cliffs/trains.gd")
const Life := preload("res://scripts/locations/cliffs/life.gd")
const SLIP_S := -43.8
const SLIP_N := -49.4

static func rail_ground(z: float) -> float:
	if Data.world_flags.get("cliffs_monorailRuns", false) and z < SLIP_S and z > SLIP_N:
		var a := Heightfield.height(13.6, SLIP_S)
		var b := Heightfield.height(13.6, SLIP_N)
		return lerpf(a, b, (z - SLIP_S) / (SLIP_N - SLIP_S))
	return Heightfield.height(13.6, z)

const STEP_KINDS := [3, 10, 11, 15]
const WALL_STONE := "a39a8a"
const WALL_BACK := "857d71"
const SLAB := "c9c0ae"
const WISTERIA := [[-7.92, 2.3, 22.2, 1.0, 0.0], [-12.6, 2.3, -19.86, 0.0, 1.0], [-8.0, 2.2, 3.42, 0.0, -1.0], [3.58, 2.3, 4.0, -1.0, 0.0], [-3.58, 2.3, 12.0, 1.0, 0.0]]
const QUAYS := [
	[Vector2(-14, 31), Vector2(-3, 31), Vector2(0, 1)], [Vector2(2, 31), Vector2(12, 31), Vector2(0, 1)],
	[Vector2(-5, 45), Vector2(15, 45), Vector2(0, 1)], [Vector2(-5, 48), Vector2(19, 48), Vector2(0, 1)],
	[Vector2(-10, 44), Vector2(-5, 44), Vector2(0, 1)], [Vector2(-10, 49), Vector2(-5, 49), Vector2(0, 1)],
	[Vector2(-10, 44), Vector2(-10, 49), Vector2(1, 0)], [Vector2(19, 39), Vector2(29, 39), Vector2(0, 1)],
	[Vector2(29, 20), Vector2(29, 39), Vector2(1, 0)], [Vector2(15, 39), Vector2(15, 45), Vector2(1, 0)],
	[Vector2(19, 39), Vector2(19, 45), Vector2(1, 0)], [Vector2(12, 31), Vector2(12, 23), Vector2(1, 0)],
]

static func zs(n: int) -> float: return -26.0 - 4.0 * (n - 1)

static func dress(village: Node3D) -> void:
	var game = village.get_parent()
	var C = load("res://scripts/locations/cliffs.gd")
	var root := Node3D.new()
	root.name = "cliffs_scenery"
	village.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	walls(root, C, rng)
	steps(root, C)
	monorail(root)
	props(root)
	plants(root, C, rng)
	station(root)
	rubble(root, rng)
	far_coast(root, C, rng)
	plaque(root)
	var tr := Trains.new()
	tr.setup(game)
	village.add_child(tr)
	var life := Life.new()
	life.name = "cliffs_life"
	village.add_child(life)
	life.setup(game, village)

static func wall_pieces(C, a: Vector2, b: Vector2, side: Vector2, water_ok: bool) -> Array:
	var out: Array = []
	var n := int(ceilf(a.distance_to(b) / 0.5))
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var p1 := p + side * 0.3
		var p2 := p - side * 0.3
		var h1 := Heightfield.height(p1.x, p1.y)
		var h2 := Heightfield.height(p2.x, p2.y)
		var lo_p := p1 if h1 < h2 else p2
		var hi_p := p2 if h1 < h2 else p1
		var lo := minf(h1, h2)
		var hi := maxf(h1, h2)
		if hi - lo < 0.9 or not C.walkable_area(hi_p.x, hi_p.y): continue
		var wet := lo < Heightfield.WATER_Y
		if not C.walkable_area(lo_p.x, lo_p.y) and not (water_ok and wet): continue
		out.append({"p": p, "normal": side if h1 < h2 else -side, "lo": -1.6 if wet else lo, "hi": hi, "step": a.distance_to(b) / n})
	return out

static func merge(pieces: Array) -> Array:
	var segs: Array = []
	for pc in pieces:
		if not segs.is_empty():
			var s: Dictionary = segs[-1]
			var last: Dictionary = s.pieces[-1]
			if last.normal == pc.normal and absf(float(last.lo) - float(pc.lo)) < 0.06 and absf(float(last.hi) - float(pc.hi)) < 0.06 and Vector2(last.p).distance_to(pc.p) < float(pc.step) * 1.2:
				s.pieces.append(pc)
				continue
		segs.append({"pieces": [pc]})
	return segs

static func walls(root: Node3D, C, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "dry_stone_walls"
	root.add_child(node)
	var parts := HouseKit.Parts.new(node)
	var mat := HouseKit.tinted(P.stone(WALL_STONE))
	var back := P.stone(WALL_BACK)
	var pieces: Array = []
	for n in range(1, 9):
		pieces.append_array(wall_pieces(C, Vector2(-52, zs(n)), Vector2(52, zs(n)), Vector2(0, 1), false))
	pieces.append_array(wall_pieces(C, Vector2(-52, -58), Vector2(52, -58), Vector2(0, 1), false))
	for x in [-46.0, -3.0, 3.0, 13.0, 17.0]:
		pieces.append_array(wall_pieces(C, Vector2(x, -62), Vector2(x, -26), Vector2(1, 0), false))
	for q in QUAYS:
		pieces.append_array(wall_pieces(C, q[0], q[1], q[2], true))
	for seg in merge(pieces):
		var first: Dictionary = seg.pieces[0]
		var last: Dictionary = seg.pieces[-1]
		var step := float(first.step)
		var length := Vector2(first.p).distance_to(last.p) + step
		var mid: Vector2 = (Vector2(first.p) + Vector2(last.p)) / 2.0
		var nrm: Vector2 = first.normal
		var lo := float(first.lo)
		var hi := float(first.hi)
		var yaw := atan2(nrm.x, nrm.y)
		var face := Vector3(mid.x, lo - 0.25, mid.y) + Vector3(nrm.x, 0, nrm.y) * 0.02
		var basis := Basis(Vector3.UP, yaw)
		var top := hi - lo + 0.25
		parts.stones(length, top, Transform3D(basis, face), mat, rng)
		var bc := Vector3(mid.x, lo - 0.25 + top / 2.0, mid.y) - Vector3(nrm.x, 0, nrm.y) * 0.14
		Props._add(node, P.box(length, top - 0.01, 0.3), back, bc, Vector3(0, yaw, 0))
		var cc := Vector3(mid.x, hi + 0.012, mid.y) - Vector3(nrm.x, 0, nrm.y) * 0.45
		Props._add(node, P.box(length, 0.05, 0.86), back, cc, Vector3(0, yaw, 0))
	parts.flush()

static func steps(root: Node3D, C) -> void:
	var node := Node3D.new()
	node.name = "steps"
	root.add_child(node)
	var parts := HouseKit.Parts.new(node)
	var mat := HouseKit.tinted(P.stone(SLAB))
	for i in G.AREAS.size():
		var a: Array = G.AREAS[i]
		if int(a[6]) == 0 or not STEP_KINDS.has(int(a[8])): continue
		var along_x := int(a[6]) == 1
		var run: float = (a[2] - a[0]) if along_x else (a[3] - a[1])
		var rise: float = absf(a[5] - a[4])
		if rise / run < 0.15: continue
		var n := int(ceilf(rise / 0.2))
		var up: float = 1.0 if a[5] > a[4] else -1.0
		var width: float = (a[3] - a[1]) if along_x else (a[2] - a[0])
		var low_end: float = (a[0] if up > 0.0 else a[2]) if along_x else (a[1] if up > 0.0 else a[3])
		var y_low: float = minf(a[4], a[5])
		var d := run / n
		for k in n:
			var s := low_end + up * (k + 0.5) * d
			var cx: float = s if along_x else (a[0] + a[2]) / 2.0
			var cz: float = (a[1] + a[3]) / 2.0 if along_x else s
			if C.find(cx, cz) != i: continue
			var top := y_low + (k + 1) * rise / n
			var hgt := rise / n + 0.25
			var size := Vector3(d + 0.02, hgt, width - 0.1) if along_x else Vector3(width - 0.1, hgt, d + 0.02)
			var t := 0.9 + 0.1 * fposmod(sin(k * 12.9898 + i * 4.1) * 43758.5453, 1.0)
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(size), Vector3(cx, top - hgt / 2.0, cz)), false, mat, Color(t, t, t * 0.98))
	parts.flush()

static func monorail(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "monorail"
	root.add_child(node)
	var rail := P.mat("7a7d82")
	var parts := HouseKit.Parts.new(node)
	var leg := HouseKit.tinted(P.mat("6a6d72"))
	var x := 13.35
	var z := -26.6
	var runs: bool = Data.world_flags.get("cliffs_monorailRuns", false)
	var prev := Vector3(x, rail_ground(z) + 0.42, z)
	while z > -60.8:
		z -= 0.6
		var p := Vector3(x, rail_ground(z) + 0.42, z)
		var broken := z < SLIP_S and z > SLIP_N and not runs
		if not broken:
			var mid := (prev + p) / 2.0
			var dv := p - prev
			var pitch := atan2(dv.y, -dv.z)
			Props._add(node, P.box(0.08, 0.12, dv.length() + 0.02), rail, mid, Vector3(pitch, 0, 0))
			if int(roundf(-z / 0.6)) % 2 == 0:
				var g := Heightfield.height(13.6, z)
				parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(0.06, p.y - g, 0.06)), Vector3(x, (p.y + g) / 2.0, z)), false, leg, Color.WHITE)
		prev = p
	if not runs:
		for k in 3:
			var bz := -44.0 - k * 0.5
			var g2 := Heightfield.height(13.6, bz)
			Props._add(node, P.box(0.08, 0.12, 0.7), rail, Vector3(x + 0.2 * k, g2 + 0.1, bz), Vector3(0.3 * k, 0.4 * k, 0.2))
	parts.flush()

static func props(root: Node3D) -> void:
	for pr in Data.layout.get("props", []):
		var pos := Vector3(float(pr.x), Heightfield.height(pr.x, pr.z), float(pr.z))
		var o: Node3D = null
		match String(pr.kind):
			"cliffs_boat": o = boat(String(pr.get("color", "#2f6fa8")))
			"cliffs_lemon": o = lemon_tree(int(absf(pr.x * 7.0)))
			"cliffs_pergola": o = pergola(float(pr.w), float(pr.d), int(absf(pr.x * 3.0 + pr.z)))
			"cliffs_cart": o = cart()
			"cliffs_ruin": o = ruin(float(pr.w), float(pr.d), int(absf(pr.x * 5.0 + pr.z)))
		if o == null: continue
		if pr.get("afloat", false): pos.y = Heightfield.WATER_Y - 0.52
		o.position = pos
		o.rotation.y = float(pr.get("r", 0.0))
		o.name = "%s_model" % pr.get("id", pr.kind)
		root.add_child(o)

static func boat(band: String) -> Node3D:
	var g := Node3D.new()
	var hull := SphereMesh.new()
	hull.radius = 1.0
	hull.height = 2.0
	hull.is_hemisphere = true
	hull.radial_segments = 16
	hull.rings = 6
	var white := P.mat("f4f1ea")
	Props._add(g, hull, white, Vector3(0, 0.78, 0), Vector3(PI, 0, 0), Vector3(0.72, 0.62, 2.25))
	for s in [-1.0, 1.0]:
		Props._add(g, P.box(0.07, 0.14, 4.0), P.mat(band), Vector3(s * 0.66, 0.8, 0), Vector3(0, s * 0.05, 0))
	Props._add(g, P.box(1.18, 0.04, 3.7), P.wood("8a6a48"), Vector3(0, 0.58, 0))
	Props._add(g, P.box(1.2, 0.05, 0.22), P.wood("a07a52"), Vector3(0, 0.72, -0.5))
	Props._add(g, P.box(1.2, 0.05, 0.22), P.wood("a07a52"), Vector3(0, 0.72, 0.7))
	Props._add(g, P.box(0.09, 0.62, 0.09), P.mat(band), Vector3(0, 1.0, 2.15), Vector3(-0.3, 0, 0))
	Props._add(g, P.box(0.08, 0.06, 2.4), P.wood("c9a77a"), Vector3(0.35, 0.86, 0.2), Vector3(0, 0.08, 0))
	for z in [-1.4, 1.4]:
		Props._add(g, P.box(1.8, 0.12, 0.18), P.wood("6b5238"), Vector3(0, 0.06, z))
	return g

static func lemon_tree(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Props._add(g, P.cyl(0.07, 0.1, 1.0, 8), P.wood("6b5238"), Vector3(0, 0.5, 0))
	Props._add(g, P.sphere(0.95, 12, 8), P.mat("3f6a33"), Vector3(0, 1.55, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	var fruit := P.mat("f2d23a")
	for k in 10:
		var a := rng.randf() * TAU
		var e := rng.randf_range(-0.6, 0.7)
		Props._add(g, P.sphere(0.07, 6, 4), fruit, Vector3(cos(a) * cos(e) * 0.92, 1.55 + sin(e) * 0.78, sin(a) * cos(e) * 0.92))
	return g

static func pergola(w: float, d: float, seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cane := P.wood("c9b48a")
	var n := int(w / 1.2) + 1
	for k in n:
		var x := -w / 2.0 + k * w / maxf(1.0, n - 1)
		for s in [-1.0, 1.0]:
			Props._add(g, P.box(0.035, 0.9, 0.035), cane, Vector3(x, 0.45, s * d / 2.0), Vector3(0, 0, s * 0.08))
		Props._add(g, P.box(0.03, 0.03, d + 0.1), cane, Vector3(x, 0.88, 0))
	for z in [-d / 2.0, 0.0, d / 2.0]:
		Props._add(g, P.box(w, 0.02, 0.02), cane, Vector3(0, 0.88, z))
	var stem := P.wood("6b5238")
	var parts := HouseKit.Parts.new(g)
	var leaf := HouseKit.tinted(P.mat("ffffff"))
	var blob := P.sphere(0.5, 7, 5)
	for k in int(w / 0.6):
		var x := -w / 2.0 + 0.3 + k * 0.6
		Props._add(g, P.cyl(0.025, 0.04, 0.85, 5), stem, Vector3(x, 0.42, rng.randf_range(-0.12, 0.12)), Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)))
	var m := int(w / 0.22)
	for k in m:
		if rng.randf() < 0.3: continue
		var x := -w / 2.0 + (k + 0.5) * w / m + rng.randf_range(-0.06, 0.06)
		var z := rng.randf_range(-d / 2.0, d / 2.0)
		var col := Color("86b84a").lerp(Color("5e9a38"), rng.randf())
		parts.put(blob, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(0.3, 0.12, 0.24)), Vector3(x, 0.93 + rng.randf_range(0.0, 0.06), z)), false, leaf, col)
	parts.flush()
	return g

static func ruin(w: float, d: float, seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stone := P.stone("a59a88")
	var dark := P.stone("8a8070")
	var along_x := w >= d
	var length := w if along_x else d
	var n := maxi(1, int(roundf(length / 0.42)))
	for row in 3:
		for i in n:
			if row == 2 and rng.randf() < 0.45: continue
			if row == 1 and rng.randf() < 0.15: continue
			var t := -length / 2.0 + (i + 0.5) * length / n + (0.1 if row % 2 == 1 else 0.0)
			if absf(t) > length / 2.0 - 0.12: continue
			var h := 0.3 + rng.randf() * 0.06
			var size := Vector3(length / n - 0.03, h - 0.02, minf(w, d) + 0.04)
			var pos := Vector3(t, 0.16 + row * 0.32, 0.0)
			if not along_x:
				size = Vector3(size.z, size.y, size.x)
				pos = Vector3(0.0, pos.y, t)
			Props._add(g, P.rbox(size.x, size.y, size.z, 0.04), dark if rng.randf() < 0.3 else stone, pos, Vector3(0, rng.randf_range(-0.05, 0.05), 0))
	return g

static func plaque(root: Node3D) -> void:
	if not Data.world_flags.get("cliffs_plaque", false): return
	var g := Node3D.new()
	g.name = "cliffs_plaque"
	Props._add(g, P.box(0.62, 0.42, 0.05), P.stone("4f535b"), Vector3(0, 0, 0))
	for i in 3: Props._add(g, P.box(0.44 - i * 0.08, 0.035, 0.06), P.mat("e8e2d6"), Vector3(0, 0.1 - i * 0.09, 0))
	g.position = Vector3(-7.2, 11.6, -19.72)
	root.add_child(g)

static func cart() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.box(1.0, 0.12, 1.3), P.mat("c0392b"), Vector3(0, 0.5, 0))
	Props._add(g, P.box(0.5, 0.42, 0.5), P.mat("5a5e64"), Vector3(0, 0.78, -0.4))
	Props._add(g, P.box(0.52, 0.06, 0.52), P.mat("c0392b"), Vector3(0, 1.02, -0.4))
	Props._add(g, P.box(0.9, 0.3, 0.06), P.wood("8a6a48"), Vector3(0, 0.72, 0.62))
	Props._add(g, P.box(0.08, 0.5, 0.08), P.mat("5a5e64"), Vector3(-0.3, 0.25, 0.4))
	Props._add(g, P.box(0.08, 0.5, 0.08), P.mat("5a5e64"), Vector3(-0.3, 0.25, -0.4))
	return g

static func far_from_things(x: float, z: float, d: float) -> bool:
	for n in Data.layout.nodes:
		if Vector2(n.x - x, n.z - z).length() < d: return false
	for f in Data.layout.features:
		if Vector2(f.x - x, f.z - z).length() < d: return false
	for k in Data.layout.nav_nodes:
		var p: Array = Data.layout.nav_nodes[k]
		if Vector2(p[0] - x, p[1] - z).length() < d * 0.8: return false
	return true

static func plants(root: Node3D, C, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "plants"
	root.add_child(node)
	var parts := HouseKit.Parts.new(node)
	var blob := P.sphere(0.5, 8, 5)
	var green := HouseKit.tinted(P.mat("ffffff"))
	for n in range(1, 9):
		for side: float in [-1.0, 1.0]:
			var placed := 0
			var tries := 0
			while placed < 12 and tries < 60:
				tries += 1
				var x := rng.randf_range(4.0, 45.0) * side
				var z := rng.randf_range(zs(n) - 3.6, zs(n) - 0.4)
				if C.kind_at(x, z) != int(G.KINDS.wild) or (x > -13.0 and x < -3.0 and n == 5) or not far_from_things(x, z, 1.4): continue
				var y := Heightfield.height(x, z)
				for k in 3:
					var s := rng.randf_range(0.35, 0.6)
					var col := Color("4f5e2e").lerp(Color("7a6a3e"), rng.randf() * 0.6)
					parts.put(blob, Transform3D(Basis.from_scale(Vector3(s * 1.4, s, s * 1.2)), Vector3(x + rng.randf_range(-0.4, 0.4), y + s * 0.35, z + rng.randf_range(-0.3, 0.3))), false, green, col)
				placed += 1
	var half := Data.map_size() / 2.0 - 2.0
	var scrub := 0
	var tries2 := 0
	while scrub < 170 and tries2 < 1500:
		tries2 += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if C.kind_at(x, z) != -1 or z > C.coast(x) - 1.5 or C.near_level(x, z) > -INF: continue
		var y := Heightfield.height(x, z)
		var broom := rng.randf() < 0.55
		var s := rng.randf_range(0.4, 0.75)
		var base := Color("4f6a32") if broom else Color("56654f")
		parts.put(blob, Transform3D(Basis.from_scale(Vector3(s * 1.3, s, s * 1.3)), Vector3(x, y + s * 0.3, z)), false, green, base.lerp(Color("6f7d4c"), rng.randf() * 0.4))
		if broom:
			for k in 4:
				var a := rng.randf() * TAU
				parts.put(blob, Transform3D(Basis.from_scale(Vector3.ONE * 0.14), Vector3(x + cos(a) * s * 0.5, y + s * 0.62, z + sin(a) * s * 0.5)), false, green, Color("f2cf3a"))
		scrub += 1
	var olives := 0
	var tries3 := 0
	while olives < 10 and tries3 < 400:
		tries3 += 1
		var x := rng.randf_range(22.0, 44.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var z := rng.randf_range(-2.0, 26.0)
		if C.kind_at(x, z) != -1 or C.near_level(x, z) > -INF or z > C.coast(x) - 3.0: continue
		var y := Heightfield.height(x, z)
		Props._add(node, P.cyl(0.1, 0.16, 1.3, 8), P.wood("6e5a44"), Vector3(x, y + 0.65, z), Vector3(0, 0, rng.randf_range(-0.2, 0.2)))
		Props._add(node, P.sphere(1.1, 10, 7), P.mat("6f7d5e"), Vector3(x, y + 1.9, z), Vector3.ZERO, Vector3(1.2, 0.7, 1.1))
		olives += 1
	var purple := P.mat("9b7bd4")
	var leaf := P.mat("6f9a4a")
	for w in WISTERIA:
		var wx: float = w[0]
		var wz: float = w[2]
		var out := Vector3(float(w[3]), 0, float(w[4])) * 0.08
		var along_x := absf(float(w[4])) > 0.5
		var y := Heightfield.height(wx + out.x * 6.0, wz + out.z * 6.0) + float(w[1])
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		Props._add(node, P.box(1.8, 0.08, 0.08), P.wood("6b5238"), Vector3(wx, y, wz), Vector3(0, 0.0 if along_x else PI / 2.0, 0))
		for k in 7:
			var p := Vector3(wx, y, wz) + dir * (-0.8 + k * 0.27) + out
			var hang := 0.35 + 0.25 * fposmod(sin(k * 3.7 + wx) * 437.5, 1.0)
			Props._add(node, P.cyl(0.11, 0.02, hang, 6), purple, p - Vector3(0, hang / 2.0, 0))
			Props._add(node, P.sphere(0.16, 6, 4), leaf, p + dir * 0.12 + Vector3(0, 0.05, 0))
	parts.flush()

static func station(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "station_canopy"
	root.add_child(node)
	var y := 10.0
	var iron := P.mat("4f5c55")
	Props._add(node, P.box(10.4, 0.1, 1.15), P.mat("6d7a72"), Vector3(-11.5, y + 3.02, -4.05))
	Props._add(node, P.box(10.4, 0.18, 0.05), P.mat("e8e2d2"), Vector3(-11.5, y + 2.95, -4.62))
	for k in 5:
		var x := -16.0 + k * 2.25
		Props._add(node, P.box(0.05, 0.05, 1.1), iron, Vector3(x, y + 2.7, -4.0), Vector3(-0.45, 0, 0))
	var board := Node3D.new()
	board.position = Vector3(-11.5, y + 2.55, -4.6)
	board.rotation.y = PI
	node.add_child(board)
	Props._add(board, P.box(2.6, 0.5, 0.05), P.mat("2b4f8a"), Vector3.ZERO)
	for s in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "SERENZA"
		label.font_size = 64
		label.pixel_size = 0.0055
		label.outline_size = 0
		label.modulate = Color("f6f3ea")
		label.position = Vector3(0, 0, 0.035 * s)
		label.rotation.y = 0.0 if s > 0.0 else PI
		board.add_child(label)
	for k in 2:
		Props._add(node, P.box(0.03, 0.4, 0.03), iron, Vector3(-11.5 + (k - 0.5) * 2.2, y + 2.95, -4.6))
	var rail := P.mat("4a4f4c")
	for k in 4:
		Props._add(node, P.box(0.05, 1.0, 0.05), rail, Vector3(-3.75, y + 0.5, -6.2 + k * 0.85))
	Props._add(node, P.box(0.05, 0.05, 2.7), rail, Vector3(-3.75, y + 1.0, -4.9))

static func rubble(root: Node3D, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "rubble"
	root.add_child(node)
	var parts := HouseKit.Parts.new(node)
	var mat := HouseKit.tinted(P.stone(WALL_STONE))
	var spots := [[Vector2(-54.0, -37.0), 3.0, 14], [Vector2(15.0, -46.5), 1.6, 12], [Vector2(-27.5, -37.6), 2.2, 16], [Vector2(-0.5, 32.5), 2.0, 10]]
	for sp in spots:
		var c: Vector2 = sp[0]
		for k in int(sp[2]):
			var a := rng.randf() * TAU
			var r := rng.randf() * float(sp[1])
			var x := c.x + cos(a) * r
			var z := c.y + sin(a) * r * 0.6
			var y := maxf(Heightfield.height(x, z), Heightfield.WATER_Y - 0.5)
			var s := Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.12, 0.3), rng.randf_range(0.2, 0.45))
			var t := rng.randf_range(0.8, 1.05)
			parts.put(HouseKit.unit_box(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)) * Basis.from_scale(s), Vector3(x, y + s.y * 0.4, z)), false, mat, Color(t, t, t))
	parts.flush()

static func far_height(C, x: float, z: float, half: float) -> float:
	if absf(x) <= half + 0.01 and absf(z) <= half + 0.01: return Heightfield.height(x, z)
	if z > C.coast(x): return -3.0
	var r: float = C.rock(x, z)
	var d := maxf(absf(x) - half, -z - half)
	return minf(r + 6.0 * sin(x * 0.043 + z * 0.031) * clampf(d / 60.0, 0.0, 1.0), 64.0)

static func coords(half: float) -> Array:
	var out: Array = []
	var v := -250.0
	while v < -half - 0.5:
		out.append(v)
		v += 5.0
	for k in 31: out.append(-half + k * (half * 2.0) / 30.0)
	v = half + 5.0
	while v <= 250.0:
		out.append(v)
		v += 5.0
	return out

static func far_coast(root: Node3D, C, rng: RandomNumberGenerator) -> void:
	var half := Data.map_size() / 2.0
	var xs := coords(half)
	var hs := {}
	for i in xs.size():
		for j in xs.size():
			hs[Vector2i(i, j)] = far_height(C, xs[i], xs[j], half)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := Color("8d96a3")
	var scrub := Color("6f7d4c")
	var pine := Color("4e663a")
	var col := func(x: float, z: float, h: float) -> Color:
		if h < 1.5: return rock.lerp(Color("b9ae94"), 0.3)
		var n := 0.5 + 0.5 * sin(x * 0.11 + 1.3) * cos(z * 0.09 - 0.7)
		var c := rock.lerp(scrub, clampf(n * 1.3, 0.0, 1.0))
		return c.lerp(pine, clampf((h - 25.0) / 25.0, 0.0, 0.8))
	for i in xs.size() - 1:
		for j in xs.size() - 1:
			var cx: float = (xs[i] + xs[i + 1]) / 2.0
			var cz: float = (xs[j] + xs[j + 1]) / 2.0
			if absf(cx) < half and absf(cz) < half: continue
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var all_sea := true
			for k in q:
				if float(hs[k]) > -0.6: all_sea = false
			if all_sea: continue
			var pts: Array = []
			for k in q:
				var x: float = xs[k.x]
				var z: float = xs[k.y]
				pts.append(Vector3(x, float(hs[k]), z))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for idx in tri:
					var p: Vector3 = pts[idx]
					st.set_color(col.call(p.x, p.z, p.y))
					st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "far_coast"
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var vnode := Node3D.new()
	vnode.name = "next_villages"
	root.add_child(vnode)
	var parts := HouseKit.Parts.new(vnode)
	var wall := HouseKit.tinted(P.plaster("ffffff"))
	var roof := HouseKit.tinted(P.mat("ffffff"))
	var colours := ["e9b9a6", "f1d27a", "d97b5e", "f3c9a0", "e6a3a0", "ebc96e", "efe3c4"]
	for vx in [102.2, 135.3, -96.2, -129.3]:
		var tip: float = C.coast(vx)
		for k in 14:
			var x: float = vx + rng.randf_range(-9.0, 9.0)
			var z: float = tip - rng.randf_range(4.0, 16.0)
			var y := far_height(C, x, z, half)
			if y < 0.5: continue
			var w := rng.randf_range(4.0, 6.0)
			var d := rng.randf_range(3.6, 5.0)
			var h := rng.randf_range(4.0, 7.0)
			var c := Color(String(colours[rng.randi() % colours.size()]))
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(x, y - 1.0 + h / 2.0, z)), false, wall, c)
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(w + 0.3, 0.5, d + 0.3)), Vector3(x, y - 1.0 + h + 0.25, z)), false, roof, Color("6f727a"))
		var ty := far_height(C, vx, tip - 6.0, half)
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(2.2, 14.0, 2.2)), Vector3(vx + 3.0, ty + 6.0, tip - 6.0)), false, wall, Color("b9b2a4"))
	parts.flush()
