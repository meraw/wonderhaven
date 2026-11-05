class_name PieceMeshes
## 3D models for every building piece, centred on their footprint. Colourable parts share one per-object tint material.
const P := preload("res://scripts/world/palette.gd")
const N := -0.5 + 0.09

static func _b(g: Node3D, mesh: Mesh, m: Material, x: float, y: float, z: float, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := P.mi(mesh, m, Vector3(x, y, z)); mi.rotation = rot; mi.scale = scl; g.add_child(mi); return mi

static func _flow(g: Node3D, a: Vector3, b: Vector3) -> void:
	var f := Node3D.new(); f.name = "flow"; f.visible = false; f.set_meta("a", a); f.set_meta("b", b); g.add_child(f)
	for n in 4:
		var d := P.mi(P.sphere(0.07, 6, 5), P.glow_mat(Color("7fe3ff"), 0.9), Vector3.ZERO, false); d.set_meta("phase", n / 4.0); f.add_child(d)

static func make(id: String, color: String = "") -> Node3D:
	var d := Data.piece(id)
	var g := Node3D.new()
	var t := P.unique_mat(color if color != "" else d.color)
	var cost: Dictionary = d.get("cost", {})
	P.texturize(t, "stone" if cost.has("stone") else ("wood" if cost.has("wood") else ("fabric" if cost.has("fabric") else "mottle")))
	var dark := P.wood(P.WOOD_DARK)
	match id:
		"bridgeDeck":
			for n in 3: _b(g, P.rbox(0.31, 0.13, 0.98, 0.03), t, -0.33 + n * 0.33, 0.075, 0)
			_b(g, P.box(1, 0.04, 0.12), dark, 0, 0.02, 0.3); _b(g, P.box(1, 0.04, 0.12), dark, 0, 0.02, -0.3)
		"bridgePost":
			_b(g, P.cyl(0.26, 0.3, 1.4, 10), t, 0, 0.7, 0); _b(g, P.cyl(0.32, 0.32, 0.1, 10), dark, 0, 1.35, 0); _b(g, P.box(1.0, 0.1, 0.16), dark, 0, 1.33, 0)
		"railing":   # hugs the outer 0.1 m of its edge, so a one-tile bridge with railings both sides still fits a walker
			var rn := -0.5 + 0.05
			for x in [-0.42, 0.0, 0.42]: _b(g, P.box(0.09, 0.7, 0.09), t, x, 0.35, rn)
			_b(g, P.box(1, 0.08, 0.1), t, 0, 0.66, rn); _b(g, P.box(1, 0.06, 0.07), t, 0, 0.35, rn)
		"floor":
			_b(g, P.rbox(0.99, 0.12, 0.99, 0.02), t, 0, 0.06, 0)
			for x in [-0.25, 0.25]: _b(g, P.box(0.02, 0.122, 0.95), P.wood("b98a5a"), x, 0.061, 0)
		"stoneBlock": _b(g, P.rbox(0.99, 0.99, 0.99, 0.06), t, 0, 0.5, 0)
		"sandbags":   # two layers of sacks, laid crosswise like a real sandbag wall
			for x in [-0.24, 0.24]: _b(g, P.rbox(0.47, 0.25, 0.96, 0.11), t, x, 0.125, 0)
			for z in [-0.24, 0.24]: _b(g, P.rbox(0.96, 0.25, 0.47, 0.11), t, 0, 0.375, z)
		"pontoon":    # a flat-bottomed boat, low in the water, with a plank deck to walk on
			_b(g, P.rbox(0.96, 0.5, 1.96, 0.18), t, 0, 0.25, 0)
			_b(g, P.box(0.98, 0.07, 1.98), dark, 0, 0.5, 0)
			for z in [-0.6, 0.0, 0.6]: _b(g, P.box(0.86, 0.08, 0.5), P.wood("b98a5a"), 0, 0.57, z)
			for z in [-0.96, 0.96]: _b(g, P.cyl(0.04, 0.05, 0.3, 6), dark, 0.38, 0.65, z)
		"foundation": _b(g, P.rbox(1.98, 0.3, 1.98, 0.05), t, 0, 0.15, 0)
		"platform":
			_b(g, P.rbox(1.98, 0.16, 1.98, 0.04), t, 0, 0.92, 0)
			for c in [[-0.85, -0.85], [0.85, -0.85], [-0.85, 0.85], [0.85, 0.85]]: _b(g, P.cyl(0.08, 0.09, 0.85, 8), dark, c[0], 0.42, c[1])
		"stairs":
			for n in 4: _b(g, P.box(0.96, 0.25 * (n + 1), 0.25), t, 0, 0.125 * (n + 1), 0.375 - n * 0.25)
		"woodWall": _b(g, P.box(1, 2.2, 0.18), t, 0, 1.1, N); _b(g, P.box(1.0, 0.12, 0.2), dark, 0, 0.06, N)
		"windowWall":
			_b(g, P.box(1, 0.8, 0.18), t, 0, 0.4, N); _b(g, P.box(1, 0.6, 0.18), t, 0, 1.9, N); _b(g, P.box(0.2, 0.8, 0.18), t, -0.4, 1.2, N); _b(g, P.box(0.2, 0.8, 0.18), t, 0.4, 1.2, N)
			_b(g, P.box(0.6, 0.8, 0.04), P.unique_mat("bfe8ff", "ffcf6b", 0.0), 0, 1.2, N).name = "glass"; _b(g, P.box(0.05, 0.8, 0.06), P.mat("ffffff"), 0, 1.2, N)
		"doorWall":
			var frame := P.mat("f3dfc1")
			_b(g, P.box(0.14, 2.2, 0.18), frame, -0.43, 1.1, N); _b(g, P.box(0.14, 2.2, 0.18), frame, 0.43, 1.1, N); _b(g, P.box(1, 0.25, 0.18), frame, 0, 2.08, N)
			var hinge := Node3D.new(); hinge.name = "hinge"; hinge.position = Vector3(-0.36, 0, N); g.add_child(hinge)
			_b(hinge, P.rbox(0.72, 1.92, 0.08, 0.03), t, 0.36, 0.97, 0); _b(hinge, P.sphere(0.04, 6, 4), P.mat(P.GOLD), 0.62, 0.95, 0.06)
		"roof": _b(g, P.cone(1.5, 1.2, 4), t, 0, 0.6, 0, Vector3(0, PI / 4, 0))
		"pillar": _b(g, P.cyl(0.18, 0.2, 2.0, 12), t, 0, 1.0, 0); _b(g, P.box(0.5, 0.12, 0.5), t, 0, 0.06, 0); _b(g, P.box(0.5, 0.12, 0.5), t, 0, 2.14, 0)
		"fence":
			for x in [-0.42, 0.0, 0.42]: _b(g, P.box(0.1, 0.75, 0.08), t, x, 0.37, N); _b(g, P.cone(0.07, 0.12, 4), t, x, 0.8, N)
			_b(g, P.box(1, 0.07, 0.06), t, 0, 0.55, N); _b(g, P.box(1, 0.07, 0.06), t, 0, 0.25, N)
		"chair":
			_b(g, P.rbox(0.5, 0.08, 0.5), t, 0, 0.45, 0); _b(g, P.rbox(0.5, 0.5, 0.08), t, 0, 0.72, -0.22)
			for c in [[-0.2, -0.2], [0.2, -0.2], [-0.2, 0.2], [0.2, 0.2]]: _b(g, P.cyl(0.03, 0.03, 0.45, 6), dark, c[0], 0.22, c[1])
		"table":
			_b(g, P.rbox(0.85, 0.08, 0.85), t, 0, 0.66, 0); _b(g, P.cyl(0.06, 0.1, 0.62), dark, 0, 0.31, 0); _b(g, P.cyl(0.25, 0.28, 0.05), dark, 0, 0.025, 0); _b(g, P.sphere(0.08), P.mat("ff8fab"), 0.15, 0.75, 0.1)
		"sofa":
			_b(g, P.rbox(1.9, 0.35, 0.6, 0.12), t, 0, 0.3, 0.05); _b(g, P.rbox(1.9, 0.5, 0.2, 0.1), t, 0, 0.6, -0.25)
			for x in [-0.9, 0.9]: _b(g, P.rbox(0.2, 0.45, 0.65, 0.08), t, x, 0.42, 0.02)
			for x in [-0.45, 0.45]: _b(g, P.rbox(0.82, 0.1, 0.5, 0.05), P.mat("ffffff"), x, 0.5, 0.08)
		"bed":
			_b(g, P.rbox(0.9, 0.35, 1.9), P.wood("d9a066"), 0, 0.2, 0); _b(g, P.rbox(0.86, 0.15, 1.3, 0.06), t, 0, 0.43, 0.25)
			_b(g, P.rbox(0.6, 0.15, 0.35, 0.07), P.mat("ffffff"), 0, 0.45, -0.65); _b(g, P.rbox(0.9, 0.7, 0.1), P.wood("c98a55"), 0, 0.4, -0.92)
		"cabinet":
			_b(g, P.rbox(0.8, 1.2, 0.6), t, 0, 0.6, 0)
			for y in [0.35, 0.8]: _b(g, P.sphere(0.035, 6, 4), P.mat(P.GOLD), 0, y, 0.31)
		"bookshelf":
			_b(g, P.rbox(0.9, 1.8, 0.5), t, 0, 0.9, -0.15)
			var cols := ["ff8fab", "6cc4ff", "7bd389", "ffd166", "b59cff"]
			for s in 3:
				for n in 5: _b(g, P.box(0.12, 0.38, 0.32), P.mat(cols[(n + s) % 5]), -0.3 + n * 0.15, 0.32 + s * 0.55, -0.06)
		"desk":
			_b(g, P.rbox(1.9, 0.08, 0.7), t, 0, 0.72, 0)
			for x in [-0.85, 0.85]: _b(g, P.rbox(0.15, 0.7, 0.62), t, x, 0.35, 0)
			_b(g, P.box(0.5, 0.02, 0.35), P.mat("e0f4ff"), -0.3, 0.77, 0)
		"lamp":
			_b(g, P.cyl(0.18, 0.2, 0.06), P.wood("5a3d2b"), 0, 0.03, 0); _b(g, P.cyl(0.025, 0.025, 1.0, 6), P.wood("5a3d2b"), 0, 0.53, 0); _b(g, P.cyl(0.12, 0.24, 0.28, 14), t, 0, 1.12, 0)
			_b(g, P.sphere(0.08), P.unique_mat("fff3b0", "ffcf6b", 0.3), 0, 1.05, 0).name = "bulb"
		"toilet":
			var chrome := P.mat("c9ced6")
			_b(g, P.cyl(0.13, 0.17, 0.36, 14), t, 0, 0.18, 0.05)
			_b(g, P.cyl(0.22, 0.15, 0.14, 16), t, 0, 0.42, 0.08, Vector3.ZERO, Vector3(1, 1, 1.25))
			_b(g, P.cyl(0.23, 0.23, 0.035, 16), P.wood("8a5a3a"), 0, 0.505, 0.08, Vector3.ZERO, Vector3(1, 1, 1.25))
			_b(g, P.rbox(0.44, 0.38, 0.2, 0.05), t, 0, 0.62, -0.3); _b(g, P.rbox(0.47, 0.05, 0.23, 0.02), t, 0, 0.835, -0.3)
			_b(g, P.cyl(0.03, 0.03, 0.03, 8), chrome, 0, 0.87, -0.3)
		"washbasin":
			var chrome := P.mat("c9ced6")
			_b(g, P.cyl(0.08, 0.13, 0.74, 12), t, 0, 0.37, -0.16)
			for x in [-0.25, 0.25]: _b(g, P.box(0.08, 0.16, 0.4), t, x, 0.84, -0.13)
			_b(g, P.box(0.58, 0.16, 0.08), t, 0, 0.84, 0.05); _b(g, P.box(0.58, 0.16, 0.08), t, 0, 0.84, -0.31); _b(g, P.box(0.5, 0.05, 0.32), t, 0, 0.78, -0.13)
			_b(g, P.box(0.42, 0.01, 0.24), P.mat("cfe9f5"), 0, 0.81, -0.13)
			_b(g, P.cyl(0.02, 0.02, 0.16, 8), chrome, 0, 0.98, -0.3); _b(g, P.box(0.035, 0.035, 0.13), chrome, 0, 1.04, -0.24)
		"bathtub":
			for x in [-0.4, 0.4]: _b(g, P.rbox(0.1, 0.46, 1.9, 0.04), t, x, 0.4, 0)
			for z in [-0.9, 0.9]: _b(g, P.rbox(0.9, 0.46, 0.1, 0.04), t, 0, 0.4, z)
			_b(g, P.box(0.8, 0.1, 1.8), t, 0, 0.22, 0)
			_b(g, P.box(0.72, 0.02, 1.72), P.mat("bfe6f5"), 0, 0.5, 0)
			for x in [-0.36, 0.36]:
				for z in [-0.82, 0.82]: _b(g, P.sphere(0.07, 8, 6), P.mat(P.GOLD), x, 0.09, z)
			_b(g, P.cyl(0.025, 0.025, 0.24, 8), P.mat("c9ced6"), 0, 0.7, -0.9); _b(g, P.box(0.04, 0.04, 0.16), P.mat("c9ced6"), 0, 0.8, -0.84)
		"rug": _b(g, P.cyl(0.95, 0.95, 0.04, 28), t, 0, 0.02, 0, Vector3.ZERO, Vector3(1, 1, 0.9)); _b(g, P.cyl(0.6, 0.6, 0.045, 24), P.mat("ffffff"), 0, 0.022, 0, Vector3.ZERO, Vector3(1, 1, 0.9))
		"counter": _b(g, P.rbox(2, 0.85, 0.8), t, 0, 0.425, 0); _b(g, P.rbox(2.05, 0.1, 0.85), P.wood("c98a55"), 0, 0.9, 0); _b(g, P.sphere(0.13), P.mat("f5c27a"), -0.5, 1.05, 0)
		"workbench":
			_b(g, P.rbox(2, 0.1, 0.8), t, 0, 0.85, 0)
			for c in [[-0.9, -0.3], [0.9, -0.3], [-0.9, 0.3], [0.9, 0.3]]: _b(g, P.box(0.1, 0.8, 0.1), dark, c[0], 0.4, c[1])
			_b(g, P.box(1.8, 0.06, 0.7), dark, 0, 0.25, 0); _b(g, P.box(0.4, 0.1, 0.12), P.mat("9aa4b5"), 0.5, 0.95, 0)
		"painting": _b(g, P.rbox(0.7, 0.55, 0.05), P.wood("c98a55"), 0, 0.35, N + 0.14); _b(g, P.box(0.58, 0.43, 0.02), t, 0, 0.35, N + 0.17); _b(g, P.sphere(0.08), P.mat("fff3b0"), 0.12, 0.42, N + 0.18)
		"tree": _b(g, P.cyl(0.12, 0.17, 1.1, 7), P.mat(P.TRUNK), 0, 0.55, 0); _b(g, P.sphere(0.7, 9, 7), t, 0, 1.6, 0); _b(g, P.sphere(0.45, 9, 7), t, 0.3, 2.1, 0.1); _b(g, P.sphere(0.42, 9, 7), t, -0.35, 1.4, 0.25)
		"flowerBed":
			_b(g, P.rbox(0.9, 0.2, 0.9), P.wood("a0623a"), 0, 0.1, 0); _b(g, P.box(0.8, 0.04, 0.8), P.wood("7a4a2a"), 0, 0.21, 0)
			for n in 8: var a := n * 0.8; var r := 0.12 + (n % 3) * 0.1; _b(g, P.sphere(0.07, 6, 4), t if n % 2 else P.mat("ffffff"), cos(a) * r, 0.32, sin(a) * r)
		"hedge": _b(g, P.rbox(0.98, 0.9, 0.98, 0.2), t, 0, 0.45, 0)
		"bench":
			_b(g, P.rbox(1.8, 0.08, 0.45), t, 0, 0.42, 0.05); _b(g, P.rbox(1.8, 0.3, 0.06), t, 0, 0.66, -0.2)
			for x in [-0.75, 0.75]: _b(g, P.box(0.08, 0.42, 0.45), P.mat("4a4a5a"), x, 0.21, 0.05)
		"statue": _b(g, P.rbox(0.7, 0.5, 0.7), t, 0, 0.25, 0); _b(g, P.sphere(0.25), t, 0, 1.6, 0); _b(g, P.cyl(0.18, 0.24, 0.6), t, 0, 1.1, 0); _b(g, P.sphere(0.12, 4, 2), P.mat(P.GOLD), 0.25, 1.75, 0)
		"signpost": _b(g, P.cyl(0.05, 0.06, 1.4, 6), dark, 0, 0.7, 0); _b(g, P.rbox(0.7, 0.22, 0.06), t, 0.15, 1.15, 0); _b(g, P.rbox(0.6, 0.2, 0.06), t, -0.12, 0.85, 0)
		"streetlight": _b(g, P.cyl(0.05, 0.08, 2.3, 8), t, 0, 1.15, 0); _b(g, P.sphere(0.18), P.unique_mat("fff3b0", "ffcf6b", 0.3), 0, 2.4, 0).name = "bulb"; _b(g, P.cone(0.26, 0.18, 8), t, 0, 2.58, 0)
		"gardenPath":
			for c in [[-0.2, -0.2, 0.28], [0.25, 0.15, 0.25], [-0.15, 0.3, 0.18], [0.3, -0.3, 0.15]]: _b(g, P.cyl(c[2], c[2], 0.05, 9), t, c[0], 0.025, c[1])
		"pond": _b(g, P.torus(0.85, 0.12, 20), P.stone("bdb5a8"), 0, 0.12, 0); _b(g, P.cyl(0.85, 0.85, 0.12, 24), P.mat("5fcde4"), 0, 0.08, 0); _b(g, P.cyl(0.12, 0.12, 0.02, 8), P.mat("5cb85c"), 0.3, 0.15, 0.2)
		"miniFountain":
			_b(g, P.cyl(0.4, 0.45, 0.35, 16), t, 0, 0.18, 0); _b(g, P.cyl(0.08, 0.1, 0.6, 8), t, 0, 0.6, 0); _b(g, P.cyl(0.22, 0.1, 0.12, 12), t, 0, 0.92, 0)
			var w := _b(g, P.cyl(0.34, 0.34, 0.03, 16), P.mat("6fd8ee"), 0, 0.34, 0); w.name = "water"; w.visible = false
			var sp := _b(g, P.sphere(0.12, 6, 4), P.glow_mat(Color("c9f6ff"), 0.7), 0, 1.1, 0); sp.name = "spray"; sp.visible = false
		"waterwheel":
			var wheel := Node3D.new(); wheel.name = "spin"; wheel.position.y = 0.6; wheel.rotation.y = PI / 2; wheel.set_meta("axis", "z"); g.add_child(wheel)
			_b(wheel, P.torus(0.55, 0.05, 18), t, 0, 0, 0, Vector3(PI / 2, 0, 0))
			for n in 8:
				var a := n * PI / 4
				_b(wheel, P.box(0.06, 1.1, 0.06), t, 0, 0, 0, Vector3(0, 0, a))
				_b(wheel, P.box(0.08, 0.22, 0.45), dark, cos(a) * 0.58, sin(a) * 0.58, 0, Vector3(0, 0, a))
			_b(g, P.cyl(0.06, 0.06, 1.0, 8), P.mat("7a7f8a"), 0, 0.6, 0, Vector3(PI / 2, 0, 0))
			for z in [-0.45, 0.45]: _b(g, P.box(0.12, 0.7, 0.12), dark, 0, 0.35, z)
		"windmill":
			_b(g, P.cyl(0.22, 0.32, 2.0, 8), t, 0, 1.0, 0); _b(g, P.cone(0.3, 0.4, 8), P.mat("e86f5c"), 0, 2.2, 0)
			var blades := Node3D.new(); blades.name = "spin"; blades.set_meta("axis", "z"); blades.position = Vector3(0, 1.85, 0.3); g.add_child(blades)
			for n in 4:
				var arm := Node3D.new(); arm.rotation.z = n * PI / 2; blades.add_child(arm); _b(arm, P.box(0.16, 0.9, 0.03), P.mat("fff7e8"), 0, 0.45, 0)
		"gear":
			_b(g, P.rbox(0.66, 0.4, 0.66), t, 0, 0.2, 0)
			var cog := Node3D.new(); cog.name = "spin"; cog.set_meta("axis", "y"); cog.position.y = 0.48; g.add_child(cog)
			_b(cog, P.cyl(0.28, 0.28, 0.1, 12), P.mat(P.GOLD), 0, 0, 0)
			for n in 10: var a := n / 10.0 * TAU; _b(cog, P.box(0.09, 0.1, 0.09), P.mat(P.GOLD), cos(a) * 0.32, 0, sin(a) * 0.32, Vector3(0, -a, 0))
			for c in [[0, -0.42], [0, 0.42], [0.42, 0], [-0.42, 0]]: _b(g, P.box(0.12, 0.12, 0.12), P.mat("7a7f8a"), c[0], 0.22, c[1])
		"shaft":
			var s := Node3D.new(); s.name = "spin"; s.set_meta("axis", "z"); s.position.y = 0.25; g.add_child(s)
			_b(s, P.cyl(0.07, 0.07, 1.0, 8), t, 0, 0, 0, Vector3(PI / 2, 0, 0))
			for z in [-0.25, 0.25]: _b(s, P.box(0.2, 0.05, 0.05), P.mat(P.GOLD), 0, 0, z)
			for z in [-0.3, 0.3]: _b(g, P.box(0.14, 0.22, 0.1), dark, 0, 0.11, z)
		"lever":
			_b(g, P.rbox(0.45, 0.2, 0.75), P.mat("7a7f8a"), 0, 0.1, 0); _b(g, P.box(0.12, 0.12, 1.0), P.wood("a0623a"), 0, 0.12, 0)
			var h := Node3D.new(); h.name = "handle"; h.position.y = 0.2; g.add_child(h)
			_b(h, P.cyl(0.03, 0.03, 0.5, 6), P.wood("5a3d2b"), 0, 0.25, 0); _b(h, P.sphere(0.08), t, 0, 0.52, 0)
		"pump":
			_b(g, P.rbox(0.75, 0.6, 0.75), t, 0, 0.3, 0); _b(g, P.cyl(0.2, 0.2, 0.3), P.mat("7a7f8a"), 0, 0.75, 0)
			_b(g, P.cyl(0.08, 0.08, 0.35, 8), P.mat(P.GOLD), 0, 0.95, 0).name = "piston"
			_b(g, P.cyl(0.1, 0.1, 0.4, 8), P.mat("7a7f8a"), -0.45, 0.25, 0, Vector3(0, 0, PI / 2)); _b(g, P.box(0.3, 0.16, 0.16), P.mat(P.GOLD), 0.42, 0.25, 0)
			_b(g, P.sphere(0.06), P.unique_mat("9aa4b5", "3fbfff", 0.0), 0, 0.62, 0.38).name = "status"
		"pipe":
			_b(g, P.cyl(0.17, 0.17, 1.0, 10), t, 0, 0.2, 0, Vector3(PI / 2, 0, 0))
			for z in [-0.45, 0.45]: _b(g, P.cyl(0.2, 0.2, 0.08, 10), P.mat("6f8296"), 0, 0.2, z, Vector3(PI / 2, 0, 0))
			_flow(g, Vector3(0, 0.2, -0.5), Vector3(0, 0.2, 0.5))
		"pipeCorner":
			_b(g, P.cyl(0.17, 0.17, 0.62, 10), t, 0, 0.2, -0.19, Vector3(PI / 2, 0, 0)); _b(g, P.cyl(0.17, 0.17, 0.62, 10), t, 0.19, 0.2, 0, Vector3(0, 0, PI / 2)); _b(g, P.sphere(0.19), t, 0, 0.2, 0)
			_flow(g, Vector3(0, 0.2, -0.5), Vector3(0.5, 0.2, 0))
		"pipeTee":
			_b(g, P.cyl(0.17, 0.17, 1.0, 10), t, 0, 0.2, 0, Vector3(0, 0, PI / 2)); _b(g, P.cyl(0.17, 0.17, 0.5, 10), t, 0, 0.2, -0.25, Vector3(PI / 2, 0, 0)); _b(g, P.sphere(0.19), t, 0, 0.2, 0)
			_flow(g, Vector3(-0.5, 0.2, 0), Vector3(0.5, 0.2, 0))
		"poweredLamp":
			_b(g, P.rbox(0.4, 0.15, 0.4), P.mat("7a7f8a"), 0, 0.075, 0); _b(g, P.cyl(0.05, 0.05, 1.2, 8), t, 0, 0.75, 0)
			_b(g, P.sphere(0.2), P.unique_mat("d0e8ff", "7fd8ff", 0.0), 0, 1.45, 0).name = "bulb"
	g.set_meta("tint", t); g.set_meta("id", id)
	return g

static func has_mesh(id: String) -> bool:
	return make(id).get_child_count() > 0

static func set_color(g: Node3D, color: String) -> void:
	(g.get_meta("tint") as StandardMaterial3D).albedo_color = Color(color)

## Animate a placed piece from its mechanical status {spinning, powered, watered, on, open, night}.
static func animate(g: Node3D, pl: Dictionary, t: float, dt: float, s: Dictionary) -> void:
	for o in g.find_children("*", "", true, false):
		match String(o.name):
			"spin":
				if s.spinning:
					if o.get_meta("axis", "z") == "y": o.rotate_y(dt * 2.6)
					else: o.rotate_object_local(Vector3(0, 0, 1), dt * 2.2)
			"flow":
				o.visible = s.watered
				if s.watered:
					var a: Vector3 = o.get_meta("a"); var b: Vector3 = o.get_meta("b")
					for d in o.get_children(): d.position = a.lerp(b, fmod(t * 1.2 + d.get_meta("phase"), 1.0))
			"piston": o.position.y = 0.95 + (absf(sin(t * 6.0)) * 0.12 if s.powered else 0.0)
			"status": (o.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0 if s.watered else (0.8 if s.powered else 0.0)
			"bulb": (o.material_override as StandardMaterial3D).emission_energy_multiplier = (3.0 if s.powered else 0.0) if pl.id == "poweredLamp" else (2.5 if s.night else 0.3)
			"handle": o.rotation.x = 0.6 if s.on else -0.6
			"hinge": o.rotation.y = lerpf(o.rotation.y, -1.5 if s.open else 0.0, minf(1.0, dt * 8.0))
			"water": o.visible = s.watered
			"spray":
				o.visible = s.watered
				if s.watered: o.position.y = 1.1 + absf(sin(t * 5.0)) * 0.25
			"glass": (o.material_override as StandardMaterial3D).emission_energy_multiplier = 1.2 if s.night else 0.0

static var _ghost_mats := {}
static func ghost(id: String, kind: String = "ok") -> Node3D:
	var g := make(id)
	set_ghost(g, kind)
	return g

static func set_ghost(g: Node3D, kind: String) -> void:
	if g.get_meta("ghost", "") == kind: return
	if _ghost_mats.is_empty():
		_ghost_mats = {"ok": P.glow_mat(Color("7dffb0"), 0.5), "bad": P.glow_mat(Color("ff7a7a"), 0.5), "plan": P.glow_mat(Color("b07cff"), 0.45)}
		for k in _ghost_mats: _ghost_mats[k].no_depth_test = false
	for m in g.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _ghost_mats[kind]; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.set_meta("ghost", kind)
