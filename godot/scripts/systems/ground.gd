class_name Ground
## What the ground is made of, painted over the grass by a layout's "ground" list, for places that aren't meadows
## (a city's streets, squares and quays). Shapes are painted in order, so later ones cover earlier ones:
##   {"kind": "asphalt", "rect": [x0, z0, x1, z1]}
##   {"kind": "setts", "circle": [x, z, r]}
##   {"kind": "gravel", "line": [[x, z], [x, z], ...], "w": 3}   (w: full width)
## Kinds: grass (the default everywhere), asphalt, setts (small square paving stones), slabs (big stone flags),
## gravel. The terrain shader draws each kind; greenery (grass tufts, flowers, trees) stays off paved ground.

const KINDS := ["grass", "asphalt", "setts", "slabs", "gravel"]
const TEXELS_PER_M := 2.0

static func shapes() -> Array: return Data.layout.get("ground", [])

static func contains(s: Dictionary, x: float, z: float) -> bool:
	if s.has("rect"):
		var r: Array = s.rect
		return x >= minf(r[0], r[2]) and x <= maxf(r[0], r[2]) and z >= minf(r[1], r[3]) and z <= maxf(r[1], r[3])
	if s.has("circle"):
		var c: Array = s.circle
		return Vector2(x - c[0], z - c[1]).length() <= float(c[2])
	if s.has("line"):
		var pts: Array = s.line
		var hw := float(s.get("w", 2.0)) / 2.0
		for n in range(pts.size() - 1):
			if WorldStatics.dist_to_segment(x, z, pts[n][0], pts[n][1], pts[n + 1][0], pts[n + 1][1]) <= hw: return true
	return false

## The kind of ground at (x, z): the last shape that covers it, or grass.
static func kind_at(x: float, z: float, list = null) -> String:
	var ss: Array = shapes() if list == null else list
	for n in range(ss.size() - 1, -1, -1):
		if contains(ss[n], x, z): return String(ss[n].get("kind", "grass"))
	return "grass"

static func paved(x: float, z: float, list = null) -> bool: return kind_at(x, z, list) != "grass"

## The shapes as an image over `rect` (x, z, width, depth in metres): one byte per texel, the kind's index in KINDS.
static func bake(list: Array, rect: Rect2, per_m: float = TEXELS_PER_M) -> Image:
	var w := maxi(1, int(ceil(rect.size.x * per_m)))
	var h := maxi(1, int(ceil(rect.size.y * per_m)))
	var img := Image.create(w, h, false, Image.FORMAT_R8)
	img.fill(Color(0, 0, 0))
	var to_px := func(x: float, z: float) -> Vector2: return Vector2((x - rect.position.x) * per_m, (z - rect.position.y) * per_m)
	for s in list:
		var k := maxi(0, KINDS.find(String(s.get("kind", "grass"))))
		var col := Color8(k, 0, 0)
		var box: Rect2
		if s.has("rect"):
			var r: Array = s.rect
			var a: Vector2 = to_px.call(minf(r[0], r[2]), minf(r[1], r[3])); var b: Vector2 = to_px.call(maxf(r[0], r[2]), maxf(r[1], r[3]))
			img.fill_rect(Rect2i(Vector2i(roundi(a.x), roundi(a.y)), Vector2i(roundi(b.x) - roundi(a.x), roundi(b.y) - roundi(a.y))).intersection(Rect2i(0, 0, w, h)), col)
			continue
		if s.has("circle"):
			var c: Array = s.circle
			box = Rect2(c[0] - c[2], c[1] - c[2], c[2] * 2.0, c[2] * 2.0)
		elif s.has("line"):
			var hw := float(s.get("w", 2.0)) / 2.0
			box = Rect2(s.line[0][0], s.line[0][1], 0, 0)
			for p in s.line: box = box.expand(Vector2(p[0], p[1]))
			box = box.grow(hw)
		else: continue
		var p0: Vector2 = to_px.call(box.position.x, box.position.y); var p1: Vector2 = to_px.call(box.end.x, box.end.y)
		for j in range(maxi(0, floori(p0.y)), mini(h, ceili(p1.y))):
			for i in range(maxi(0, floori(p0.x)), mini(w, ceili(p1.x))):
				if contains(s, rect.position.x + (i + 0.5) / per_m, rect.position.y + (j + 0.5) / per_m): img.set_pixel(i, j, col)
	return img
