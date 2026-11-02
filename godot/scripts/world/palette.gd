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

## Cached toon material (shared: do not modify; use unique_mat for per-object changes).
static func mat(color, emissive = null, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [str(color), str(emissive), energy]
	if not _cache.has(key): _cache[key] = unique_mat(color, emissive, energy)
	return _cache[key]

static func unique_mat(color, emissive = null, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color if color is Color else Color(color)
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

static func capsule(r: float, len: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = len + r * 2.0; c.radial_segments = 10; c.rings = 4; return c

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
