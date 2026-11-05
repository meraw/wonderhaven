extends RefCounted
## Casalrana's surface textures, painted in code like the shared ones (palette.gd): running-bond brick, river cobbles
## laid in herringbone (the old farmstead walls), and brick latticework with holes (barn gables), plus bare twigs for
## winter trees. Colour textures, so the bricks and stones vary; materials are cached per colour.
const P := preload("res://scripts/world/palette.gd")

static var _cache: Dictionary = {}

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10007.0

static func _mat(tex: Texture2D, scale: Vector3, key: String) -> StandardMaterial3D:
	if _cache.has(key): return _cache[key]
	var m := P.unique_mat(Color.WHITE)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

## Running-bond brick: courses of long bricks in slightly different reds, with pale mortar. One tile is four courses
## and two bricks: about 0.84 m wide and 0.6 m tall.
static func brick(base: Color) -> StandardMaterial3D:
	var key := "brick|" + base.to_html()
	if _cache.has(key): return _cache[key]
	var w := 64; var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var mortar := Color("d8cdb8")
	for y in h:
		var row := int(y / 16)
		for x in w:
			var xx := (x + (8 if row % 2 == 1 else 0) * 2) % w
			var col := int(xx / 32)
			var in_mortar := (y % 16) < 2 or (xx % 32) < 2
			if in_mortar: img.set_pixel(x, y, mortar); continue
			var t := _hash(col + row * 7, row)
			var c := base.darkened(0.12 * t).lightened(0.08 * _hash(row, col * 3 + 1))
			img.set_pixel(x, y, c.lerp(Color("6e4a3a"), 0.1 * _hash(x / 6, y / 6)))
	img.generate_mipmaps()
	return _mat(ImageTexture.create_from_image(img), Vector3(1.19, 1.67, 1.19), key)

## River cobbles laid in herringbone rows, each row leaning the other way, in grey-brown mortar.
static func cobbles() -> StandardMaterial3D:
	var key := "cobbles"
	if _cache.has(key): return _cache[key]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var mortar := Color("6f6556")
	for y in n:
		var row := int(y / 16)
		var a := 0.75 if row % 2 == 0 else -0.75
		var yy := float(y % 16) - 7.5
		for x in n:
			var u := float(x) * cos(a) + yy * sin(a)
			var v := -float(x) * sin(a) + yy * cos(a)
			var cu := floorf(u / 6.4)
			var du := u - (cu + 0.5) * 6.4
			var e := (du / 2.9) * (du / 2.9) + (v / 6.8) * (v / 6.8)
			if e < 1.0:
				var t := _hash(int(cu) + 50, row)
				var stone := Color("cfc6b4").lerp(Color("9d9384"), t).lerp(Color("d1ad86"), 0.35 * _hash(row, int(cu)))
				img.set_pixel(x, y, stone.lightened(0.15 * (1.0 - e)).darkened(0.12 * e))
			else:
				img.set_pixel(x, y, mortar)
	img.generate_mipmaps()
	return _mat(ImageTexture.create_from_image(img), Vector3(1.0, 1.0, 1.0), key)

## Brick latticework: bricks laid with square gaps between them, the gaps see-through (barn and hayloft gables).
static func lattice(base: Color) -> StandardMaterial3D:
	var key := "lattice|" + base.to_html()
	if _cache.has(key): return _cache[key]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var row := int(y / 16)
		for x in n:
			var xx := (x + (16 if row % 2 == 1 else 0)) % n
			var hole := (y % 16) >= 3 and (y % 16) <= 13 and (xx % 32) >= 18 and (xx % 32) <= 30
			if hole: img.set_pixel(x, y, Color(0, 0, 0, 0)); continue
			var c := base.darkened(0.1 * _hash(int(xx / 32) + row * 5, row))
			if (y % 16) < 2: c = Color("d8cdb8")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := _mat(ImageTexture.create_from_image(img), Vector3(1.6, 1.6, 1.6), key)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Bare winter twigs: a tangle of thin dark lines, see-through between them, for the crowns of leafless trees
## (poplars, alders, mulberries). Blended rather than cut out, so from afar a crown reads as a soft grey haze of twigs
## instead of vanishing.
static func twigs(base: Color) -> StandardMaterial3D:
	var key := "twigs|" + base.to_html()
	if _cache.has(key): return _cache[key]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(base.r, base.g, base.b, 0.0))
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for k in 340:
		var p := Vector2(rng.randf() * n, rng.randf() * n)
		var dir := Vector2.UP.rotated(rng.randf_range(-0.9, 0.9))
		var length := rng.randf_range(20.0, 76.0)
		var thick := 1 if rng.randf() < 0.6 else 2
		for s in int(length):
			var q := p + dir * s
			dir = dir.rotated(rng.randf_range(-0.12, 0.12))
			for t in thick:
				var px := int(fposmod(q.x + t, n)); var py := int(fposmod(q.y, n))
				img.set_pixel(px, py, Color(base.r, base.g, base.b, 0.95).darkened(rng.randf() * 0.2))
	img.generate_mipmaps()
	var m := _mat(ImageTexture.create_from_image(img), Vector3(0.6, 0.6, 0.6), key)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = false
	return m
