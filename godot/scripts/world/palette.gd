class_name Palette
## Shared colours, cel-shaded materials and mesh helpers for the cartoon-diorama look.

const GRASS := Color("8fd16a")
const WOOD := Color("c98a55")
const WOOD_DARK := Color("9a6238")
const STONE := Color("cfc8bd")
const STONE_DARK := Color("a39c92")
const TRUNK := Color("8b5a3c")
const LEAF := Color("5cb85c")
const PINE := Color("3f9a6a")
const GOLD := Color("ffd35c")
const FLOWERS := [Color("ff7aa8"), Color("ffd84a"), Color("ffffff"), Color("b98cff"), Color("ff9a52")]

static var _cache: Dictionary = {}
static var real := true
static var _real_tex: Dictionary = {}

const PAINTED_MODES := "diffuse_lambert_wrap, specular_disabled"
const REAL_MODES := "diffuse_burley, specular_schlick_ggx"
const REAL_TEX := {"plaster": ["plaster", 1.4, 1.1], "wood": ["wood", 1.2, 0.8], "stone": ["stone", 0.9, 1.4],
	"fabric": ["knit", 0.12, 1.4], "paving": ["paving", 4.0, 0.4], "denim": ["denim", 0.14, 1.6],
	"leather": ["leather", 0.2, 1.4]}
const REAL_ROUGHNESS := {"mottle": 0.85, "smooth": 0.5}
const TEX_GAIN := 1.2
const REAL_SPECULAR := {"smooth": 0.5}
const ROUGH_SPECULAR := 0.25
const REAL_AMBIENT := 1.35
const REAL_NIGHT_AMBIENT := 1.15
const REAL_AMBIENT_WARMTH := 0.3
const REAL_SHADER_ALBEDO := 0.9

static func ambient_gain(night: float = 0.0) -> float:
	return lerpf(REAL_AMBIENT, REAL_NIGHT_AMBIENT, clampf(night, 0.0, 1.0)) if real else 1.0

static func ambient_color(ambient: Color, sun: Color, night: float = 0.0) -> Color:
	return ambient.lerp(sun, REAL_AMBIENT_WARMTH * (1.0 - clampf(night, 0.0, 1.0))) if real else ambient

static func _static_init() -> void:
	real = not OS.get_cmdline_user_args().has("--look=painted")

static func shader_code(code: String, roughness: float = -1.0, specular: float = ROUGH_SPECULAR, albedo: float = 1.0) -> String:
	if not real: return code
	var c := code.replace(PAINTED_MODES, REAL_MODES)
	if roughness >= 0.0: c = c.replace("ROUGHNESS = 1.0;", "ROUGHNESS = %.2f;\n\tSPECULAR = %.2f;\n\tALBEDO *= %.2f;" % [roughness, specular, albedo])
	return c

static func material_texture(name: String) -> Texture2D:
	if not _real_tex.has(name): _real_tex[name] = load("res://assets/textures/materials/%s.jpg" % name)
	return _real_tex[name]

## Cached material with a faint painted mottle (shared: do not modify; use unique_mat for per-object changes).
static func mat(color, emissive = null, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [str(color), str(emissive), energy]
	if not _cache.has(key): _cache[key] = texturize(unique_mat(color, emissive, energy), "mottle")
	return _cache[key]

## Shared materials with a surface texture. Kinds: plaster (walls), wood (grain), stone (cells), fabric (weave),
## mottle (default), smooth (none: skin, hair, glass).
static func detailed(color, kind: String) -> StandardMaterial3D:
	var key := "%s|%s" % [str(color), kind]
	if not _cache.has(key): _cache[key] = texturize(unique_mat(color), kind)
	return _cache[key]
static func plaster(color) -> StandardMaterial3D: return detailed(color, "plaster")
static func wood(color) -> StandardMaterial3D: return detailed(color, "wood")
static func stone(color) -> StandardMaterial3D: return detailed(color, "stone")
static func fabric(color) -> StandardMaterial3D: return detailed(color, "fabric")
static func smooth(color) -> StandardMaterial3D: return detailed(color, "smooth")
static func paving(color) -> StandardMaterial3D: return detailed(color, "paving") if real else stone(color)
static func denim(color) -> StandardMaterial3D: return detailed(color, "denim") if real else fabric(color)
static func leather(color) -> StandardMaterial3D: return detailed(color, "leather") if real else fabric(color)

# Triplanar scale (repeats per metre) for each kind; textures are grey multipliers close to 1 so colours stay true.
const DETAIL_SCALE := {"mottle": 0.6, "plaster": 0.45, "wood": 1.1, "stone": 0.9, "fabric": 4.0}
static var _detail_tex: Dictionary = {}

## Adds the kind's detail texture to a material (in place) and returns it.
static func texturize(m: StandardMaterial3D, kind: String) -> StandardMaterial3D:
	if real:
		m.roughness = float(REAL_ROUGHNESS.get(kind, 0.8))
		m.metallic_specular = float(REAL_SPECULAR.get(kind, ROUGH_SPECULAR))
		if REAL_TEX.has(kind): return _real_texturize(m, REAL_TEX[kind])
	if kind == "smooth" or not DETAIL_SCALE.has(kind): return m
	m.albedo_texture = detail_texture(kind)
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 2.0
	m.uv1_scale = Vector3.ONE * DETAIL_SCALE[kind]
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func _real_texturize(m: StandardMaterial3D, spec: Array) -> StandardMaterial3D:
	var name: String = spec[0]
	m.albedo_texture = material_texture(name + "_albedo")
	m.albedo_color = Color(m.albedo_color.r * TEX_GAIN, m.albedo_color.g * TEX_GAIN, m.albedo_color.b * TEX_GAIN, m.albedo_color.a)
	m.normal_enabled = true
	m.normal_texture = material_texture(name + "_normal")
	m.normal_scale = float(spec[2])
	m.roughness_texture = material_texture(name + "_rough")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / float(spec[1])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func detail_texture(kind: String) -> Texture2D:
	if _detail_tex.has(kind): return _detail_tex[kind]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	var nz := FastNoiseLite.new(); nz.seed = kind.hash() & 0xffff; nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_octaves = 4
	var cell := FastNoiseLite.new(); cell.seed = 5; cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB; cell.frequency = 1.0
	for y in n:
		for x in n:
			var u := float(x) / n; var v := float(y) / n
			# 4D-torus sampling keeps the noise seamless
			var t := func(nn: FastNoiseLite, f: float) -> float:
				return nn.get_noise_3d(cos(u * TAU) * f, sin(u * TAU) * f, cos(v * TAU) * f + sin(v * TAU) * f * 0.5)
			var g := 1.0
			match kind:
				"mottle": g = 0.955 + 0.045 * t.call(nz, 2.0)
				"plaster": g = 0.94 + 0.05 * t.call(nz, 3.0) + 0.02 * t.call(nz, 14.0)
				"wood":
					var ring := sin(TAU * (v * 9.0 + 0.35 * sin(TAU * u * 2.0) + 0.15 * sin(TAU * (u * 5.0 + v))))
					g = 0.93 + 0.05 * ring + 0.025 * sin(TAU * (v * 48.0 + 0.5 * sin(TAU * u * 3.0)))
				"stone":
					var c := clampf(t.call(cell, 2.4) * 1.4 + 0.6, 0.0, 1.0)
					g = 0.86 + 0.12 * smoothstep(0.0, 0.25, c) + 0.03 * t.call(nz, 6.0)
				"fabric":
					g = 0.95 + 0.03 * sin(TAU * u * 16.0) * sin(TAU * v * 16.0) + 0.02 * t.call(nz, 3.0)
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	_detail_tex[kind] = ImageTexture.create_from_image(img)
	return _detail_tex[kind]

static func unique_mat(color, emissive = null, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color if color is Color else Color(color)
	if real:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.roughness = 0.85
		m.metallic_specular = ROUGH_SPECULAR
	else:
		# Soft wrapped light and a faint rim: rounded, painterly shading instead of a hard toon terminator.
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 1.0
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.8
	if emissive != null:
		m.emission_enabled = true
		m.emission = emissive if emissive is Color else Color(emissive)
		m.emission_energy_multiplier = energy
	return m

static func glow_mat(color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color) if color is String else color
	m.albedo_color.a = alpha
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func mi(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

static func box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d); return b

static func sphere(r: float, seg: int = 14, rings: int = 10) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = rings; return s

static func hemi(r: float, seg: int = 14) -> SphereMesh:
	var s := sphere(r, seg, 6); s.is_hemisphere = true; s.height = r; return s

static func cyl(rt: float, rb: float, h: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 1; return c

static func cone(r: float, h: float, seg: int = 10) -> CylinderMesh: return cyl(0.001, r, h, seg)

static func capsule(r: float, len: float, seg: int = 10, rings: int = 4) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = len + r * 2.0; c.radial_segments = seg; c.rings = rings; return c

static func torus(r: float, tube: float, seg: int = 16) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = r - tube; t.outer_radius = r + tube; t.rings = seg; t.ring_segments = 6; return t

static func ico(r: float) -> SphereMesh: return sphere(r, 8, 5)

static var _rbox_cache: Dictionary = {}
## Box with rounded edges (vertices of a subdivided box pulled onto a rounded hull).
static func rbox(w: float, h: float, d: float, r: float = 0.06) -> Mesh:
	var key := "%.3f|%.3f|%.3f|%.3f" % [w, h, d, r]
	if _rbox_cache.has(key): return _rbox_cache[key]
	var b := BoxMesh.new(); b.size = Vector3(w, h, d); b.subdivide_width = 3; b.subdivide_height = 3; b.subdivide_depth = 3
	var arrays := b.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var hw := w / 2.0 - r
	var hh := h / 2.0 - r
	var hd := d / 2.0 - r
	for i in verts.size():
		var v := verts[i]
		var c := Vector3(clampf(v.x, -hw, hw), clampf(v.y, -hh, hh), clampf(v.z, -hd, hd))
		var dl := v - c
		if dl.length_squared() > 0.0: verts[i] = c + dl.normalized() * r
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(am, 0)
	st.generate_normals()
	var out := st.commit()
	_rbox_cache[key] = out
	return out
