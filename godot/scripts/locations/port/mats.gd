extends RefCounted

const P := preload("../../world/palette.gd")

static var _mats := {}
static var _pot: CylinderMesh
static var _leaf: SphereMesh

static func tinted(kind: String) -> StandardMaterial3D:
	if not _mats.has(kind):
		var base: StandardMaterial3D
		match kind:
			"stone": base = P.stone(Color.WHITE)
			"slate": base = P.stone(Color.WHITE)
			"wood": base = P.wood(Color.WHITE)
			"leaf": base = P.mat(Color.WHITE)
			_: base = P.plaster(Color.WHITE)
		_mats[kind] = HouseKit.tinted(base)
	return _mats[kind]

static func pot_mesh() -> CylinderMesh:
	if _pot == null:
		_pot = CylinderMesh.new()
		_pot.top_radius = 0.5
		_pot.bottom_radius = 0.38
		_pot.height = 1.0
		_pot.radial_segments = 8
	return _pot

static func leaf_mesh() -> SphereMesh:
	if _leaf == null:
		_leaf = SphereMesh.new()
		_leaf.radius = 0.5
		_leaf.height = 1.0
		_leaf.radial_segments = 8
		_leaf.rings = 4
	return _leaf
