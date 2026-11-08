extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const STREET := 0.3
const GROUND := 4.0
const STOREY := 3.2
const BAY := 3.2
const WIN_W := 1.0
const WIN_H := 1.65
const SHOP_W := 2.3
const SHOP_H := 2.5
const BASE_H := 0.8
const DOORS := ["4a3426", "2f3a2f", "5a2f26", "3a3f4a"]

static func on() -> bool: return HouseKit.kit_style()

static func ground_of(b: Dictionary) -> float: return float(b.get("storey", GROUND))

static func storey_of(b: Dictionary) -> float: return float(b.get("storey", STOREY))

static func wall_material(wall: Color) -> StandardMaterial3D: return P.plaster(wall)

static func base_material(wall: Color) -> StandardMaterial3D: return HouseKit.tinted(P.stone(wall.darkened(0.35).lerp(Color("8a857c"), 0.5)))

static func sills(from_y: float, top: float, storey: float) -> Array:
	var out: Array = []
	var y := from_y + 0.85
	while y + WIN_H <= top - 0.35:
		out.append(y)
		y += storey
	return out

static func street_block(b: Dictionary, h: float) -> Dictionary:
	if float(b.get("y", STREET)) > STREET + 0.5: return {"sills": sills(0.0, h, storey_of(b))}
	return {"street": true, "shops": float(b.get("shops", 1.0)) > 0.5, "sills": sills(ground_of(b), h, storey_of(b))}

static func room_block(b: Dictionary, h: float, storey: float) -> Dictionary:
	var y0 := float(b.get("y", STREET))
	var o := {"sills": sills(storey, h, storey_of(b)), "high": true}
	if y0 > STREET + 0.5: o.merge({"street": true, "street_y": -(y0 - STREET), "cellar": true})
	return o

const OUT := {"S": Vector2(0, 1), "N": Vector2(0, -1), "E": Vector2(1, 0), "W": Vector2(-1, 0)}
const ALONG := {"S": Vector2(1, 0), "N": Vector2(-1, 0), "E": Vector2(0, -1), "W": Vector2(0, 1)}

static func neighbours(b: Dictionary) -> Array:
	var c := Vector2(float(b.x), float(b.z))
	var reach := maxf(float(b.w), float(b.d)) + 2.0
	return Data.layout.buildings.filter(func(o): return String(o.id) != String(b.id) and absf(float(o.x) - c.x) < reach + float(o.w) / 2.0 and absf(float(o.z) - c.y) < reach + float(o.d) / 2.0)

static func covered(b: Dictionary, side: String, u: float, near: Array) -> bool:
	var half := Vector2(float(b.w), float(b.d)) / 2.0
	var p := Vector2(float(b.x), float(b.z)) + (OUT[side] as Vector2) * (absf((OUT[side] as Vector2).dot(half)) + 0.4) + (ALONG[side] as Vector2) * u
	for o in near:
		if absf(p.x - float(o.x)) < float(o.w) / 2.0 and absf(p.y - float(o.z)) < float(o.d) / 2.0: return true
	return false

static func dress(g: Node3D, b: Dictionary, shutter: String, opts: Dictionary) -> HouseKit.Parts:
	var w := float(b.w)
	var d := float(b.d)
	var rng := Landmarks.seeded(b)
	var parts := HouseKit.Parts.new(g)
	parts.glass_mat = Landmarks.glass_material()
	var street: bool = bool(opts.get("street", false))
	var sy := float(opts.get("street_y", 0.0))
	var shops: bool = bool(opts.get("shops", false))
	var cellar: bool = bool(opts.get("cellar", false))
	var high: bool = bool(opts.get("high", false))
	var rows: Array = opts.get("sills", [])
	var base := base_material(Color(String(b.get("wall", "#d9a85b"))))
	var near := neighbours(b)
	for side in ["S", "N", "E", "W"]:
		var length := w if side in ["S", "N"] else d
		var fx := Landmarks.facade(w, d, side)
		var n := maxi(1, int(length / BAY))
		var step := length / n
		var door_at := rng.randi() % n
		var gaps: Array = []
		for i in n:
			var u := -length / 2.0 + (i + 0.5) * step
			if covered(b, side, u, near):
				gaps.append([u - step / 2.0, u + step / 2.0])
				continue
			if street:
				if cellar:
					parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, sy + 1.0, 0.0)), WIN_W, WIN_H - 0.25, "", "open", true, false, true)
				elif i == door_at or (shops and rng.randf() < 0.22):
					parts.door(fx * Transform3D(Basis.IDENTITY, Vector3(u, sy, 0.0)), DOORS[rng.randi() % DOORS.size()], false, false, false)
					gaps.append([u - 0.75, u + 0.75])
				elif shops:
					var sw := minf(step * 0.78, SHOP_W)
					parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, sy + BASE_H, 0.0)), sw, SHOP_H, "", "open", false, false, true)
					gaps.append([u - sw / 2.0 - 0.05, u + sw / 2.0 + 0.05])
				else:
					parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, sy + 1.0, 0.0)), WIN_W, WIN_H - 0.25, "", "open", true, false, true)
			for y in rows:
				parts.window(fx * Transform3D(Basis.IDENTITY, Vector3(u, float(y), 0.0)), WIN_W, WIN_H, shutter, Landmarks.shutter_state(rng), false, high, true)
		if street and not cellar: _base(parts, fx, length, sy, gaps, base, rng)
	return parts

static func _base(parts: HouseKit.Parts, fx: Transform3D, length: float, sy: float, gaps: Array, mat: Material, rng: RandomNumberGenerator) -> void:
	var box := HouseKit.unit_box()
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var spans: Array = []
	var a := -length / 2.0
	for c in cuts:
		if c[0] > a + 0.05: spans.append([a, minf(c[0], length / 2.0)])
		a = maxf(a, c[1])
	if a < length / 2.0 - 0.05: spans.append([a, length / 2.0])
	for s in spans:
		var x0: float = s[0]
		while x0 < s[1] - 0.05:
			var L := minf(rng.randf_range(0.7, 1.4), s[1] - x0)
			var t := rng.randf_range(0.9, 1.06)
			parts.put(box, fx * Transform3D(Basis.from_scale(Vector3(L - 0.02, BASE_H - 0.02, 0.09)), Vector3(x0 + L / 2.0, sy + BASE_H / 2.0, 0.035)), false, mat, Color(t, t, t))
			x0 += L

static func finish(g: Node3D, parts: HouseKit.Parts) -> void:
	parts.flush()
	var glasses: Array = g.get_meta("glasses", [])
	glasses.append_array(parts.glasses)
	g.set_meta("glasses", glasses)
