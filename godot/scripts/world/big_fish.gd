class_name BigFish
extends RefCounted

const P := preload("res://scripts/world/palette.gd")

static func make(length: float) -> Node3D:
	var g := Node3D.new()
	g.name = "big_fish"
	var back := P.mat("6f6a45", "6f6a45", 0.35)
	var belly := P.mat("ddd0a6", "ddd0a6", 0.35)
	var fin := P.mat("57533a", "57533a", 0.3)
	var L := length
	_part(g, P.sphere(1.0, 16, 10), back, Vector3(0, 0.02 * L, 0.05 * L), Vector3(0.17 * L, 0.15 * L, 0.48 * L))
	_part(g, P.sphere(1.0, 16, 10), belly, Vector3(0, -0.035 * L, 0.02 * L), Vector3(0.15 * L, 0.1 * L, 0.42 * L))
	_part(g, P.sphere(1.0, 16, 10), back, Vector3(0, 0.0, -0.36 * L), Vector3(0.23 * L, 0.12 * L, 0.2 * L))
	_part(g, P.sphere(1.0, 14, 8), belly, Vector3(0, -0.05 * L, -0.4 * L), Vector3(0.2 * L, 0.06 * L, 0.16 * L))
	_part(g, P.box(0.34 * L, 0.012 * L, 0.04 * L), P.mat("1e1c16"), Vector3(0, -0.035 * L, -0.555 * L))
	for sx in [-1.0, 1.0]:
		_part(g, P.sphere(0.035 * L, 10, 8), P.mat("f4efd8", "f4efd8", 0.6), Vector3(sx * 0.15 * L, 0.06 * L, -0.42 * L))
		_part(g, P.sphere(0.02 * L, 8, 6), P.mat("111111"), Vector3(sx * 0.17 * L, 0.065 * L, -0.435 * L))
		var w := _part(g, P.cyl(0.004 * L, 0.012 * L, 0.5 * L, 6), fin, Vector3(sx * 0.32 * L, -0.02 * L, -0.66 * L))
		w.rotation = Vector3(PI / 2, 0, 0)
		w.rotation.y = -sx * 0.7
		for k in 2:
			var c := _part(g, P.cyl(0.003 * L, 0.007 * L, 0.16 * L, 5), fin, Vector3(sx * (0.04 + 0.05 * k) * L, -0.12 * L, -0.5 * L))
			c.rotation = Vector3(0.5, 0, sx * 0.3)
		var pec := _part(g, P.box(0.16 * L, 0.012 * L, 0.1 * L), fin, Vector3(sx * 0.2 * L, -0.06 * L, -0.18 * L))
		pec.rotation = Vector3(0, sx * 0.4, sx * 0.4)
	_part(g, P.box(0.012 * L, 0.26 * L, 0.2 * L), fin, Vector3(0, 0.0, 0.6 * L))
	_part(g, P.box(0.01 * L, 0.07 * L, 0.12 * L), fin, Vector3(0, 0.15 * L, -0.08 * L))
	_part(g, P.box(0.01 * L, 0.05 * L, 0.3 * L), fin, Vector3(0, -0.11 * L, 0.3 * L))
	return g

static func _part(g: Node3D, mesh: Mesh, m: Material, at: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := P.mi(mesh, m, at)
	mi.scale = scl
	g.add_child(mi)
	return mi

static func arc(a: Vector3, b: Vector3, height: float, p: float) -> Vector3:
	return a.lerp(b, p) + Vector3(0, height * sin(PI * p), 0)

static func heading(a: Vector3, b: Vector3, height: float, p: float) -> Vector3:
	return ((b - a) + Vector3(0, height * PI * cos(PI * p), 0)).normalized()
