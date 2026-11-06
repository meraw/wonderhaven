extends RefCounted
## Toriano's own gathering spots, drawn in their own frame (the village puts them in place and the shared code
## animates them): the park's plane trees to prune (a pink ribbon marks the ones ready), marble offcuts in the
## works yard, builders' skips, the depot's scrap pile and the flea-market stall (each with a "lid", a tarp or cloth
## the shared code flips back once you've rummaged), and the pages of Gino's score. Anything else uses the shared
## models (lost things, fishing spots, flower patches, dig spots).

const Kit := preload("res://scripts/locations/metropolis/kit.gd")
const Scenery := preload("res://scripts/locations/metropolis/scenery.gd")
const Props := preload("res://scripts/world/props.gd")

static func node(n: Dictionary) -> Node3D:
	match String(n.kind):
		"chop": return plane_tree(n)
		"mine": return offcuts(n)
		"bin":
			if String(n.id).ends_with("flea"): return flea_stall()
			if String(n.id).ends_with("scrap"): return scrap_pile()
			return skip()
		"fragment":
			if n.has("item"): return page(n)
	return null

## A bare plane tree, a little smaller than the avenue ones, with a pink ribbon round the trunk while it wants pruning.
static func plane_tree(n: Dictionary) -> Node3D:
	var g := Node3D.new()
	var mi := MeshInstance3D.new(); mi.mesh = Scenery.plane_mesh(); mi.material_override = Kit.vc_mat(); g.add_child(mi)
	mi.rotation.y = float(n.x) * 0.37
	g.scale = Vector3.ONE * 0.85
	var ribbon: Node3D = Props.add_ribbon(g)
	ribbon.scale = Vector3(1.7, 1.0, 1.7)
	return g

## Offcuts of pink-veined marble stacked by the masons.
static func offcuts(n: Dictionary) -> Node3D:
	var m := Kit.Merge.new()
	var white := Color("efe7e0"); var vein := Color("d9b8b0")
	var r := float(n.x) * 0.9
	m.box(Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 0.9), white, r)
	m.box(Vector3(0.15, 0.82, 0.05), Vector3(0.8, 0.45, 0.6), white.darkened(0.04), r + 0.5)
	m.box(Vector3(-0.45, 0.2, 0.55), Vector3(0.5, 0.4, 0.45), vein, r + 1.1)
	m.box(Vector3(0.0, 0.605, 0.0), Vector3(1.0, 0.02, 0.06), vein.darkened(0.1), r + 0.3)
	var g := Node3D.new(); g.add_child(m.node(Kit.vc_mat(), "marble"))
	return g

## A builder's skip, yellow and battered, with a tarp over it.
static func skip() -> Node3D:
	var g := Node3D.new()
	var m := Kit.Merge.new()
	var yellow := Color("d9a03a")
	m.box(Vector3(0, 0.08, 0), Vector3(2.4, 0.16, 1.3), yellow.darkened(0.25))
	for s in [-1, 1]:
		m.box(Vector3(0, 0.6, s * 0.62), Vector3(2.6, 1.0, 0.08), yellow)
		m.box(Vector3(s * 1.27, 0.6, 0), Vector3(0.08, 1.0, 1.3), yellow.darkened(0.1))
	for i in 5:   # bricks, a pipe, a bent bicycle wheel poking out
		m.box(Vector3(-0.9 + i * 0.45, 0.95, -0.3 + (i % 3) * 0.3), Vector3(0.4, 0.22, 0.3), [Color("b5653a"), Color("9a948c"), Color("c9a46a")][i % 3], i * 0.4)
	g.add_child(m.node(Kit.vc_mat(), "skip"))
	g.add_child(_lid(Vector3(2.5, 0.04, 1.2), Color("3f6b4f"), Vector3(0, 1.12, -0.6)))
	return g

## The tram depot's scrap pile: coils of old overhead wire, a rusty bogie, under a canvas sheet.
static func scrap_pile() -> Node3D:
	var g := Node3D.new()
	var m := Kit.Merge.new()
	var copper := Color("b5653a"); var rust := Color("6f4a3a")
	for i in 4: m.cyl(Vector3(-0.6 + i * 0.4, 0.1 + (i % 2) * 0.2, (i % 3) * 0.25 - 0.25), 0.32, 0.18, copper.darkened(0.08 * (i % 2)), 12)
	m.box(Vector3(0.3, 0.25, 0.4), Vector3(1.2, 0.5, 0.5), rust)
	m.box(Vector3(-0.2, 0.55, 0.0), Vector3(0.12, 0.9, 0.12), Color("4a4a4a"), 0.6)
	g.add_child(m.node(Kit.vc_mat(), "scrap"))
	g.add_child(_lid(Vector3(2.0, 0.03, 1.4), Color("7a6a4a"), Vector3(0, 0.75, -0.7)))
	return g

## The flea-market stall: a trestle table of old things under a green umbrella, with a dust sheet over the fabric.
static func flea_stall() -> Node3D:
	var g := Node3D.new()
	var m := Kit.Merge.new()
	m.box(Vector3(0, 0.75, 0), Vector3(2.6, 0.1, 1.2), Color("8a7a62"))
	for s in [-1, 1]:
		for t in [-1, 1]: m.box(Vector3(s * 1.2, 0.37, t * 0.5), Vector3(0.08, 0.74, 0.08), Color("5a4a3a"))
	for i in 6:   # a gramophone horn, books, a lamp, a clock, cups, bolts of cloth
		m.box(Vector3(-1.0 + i * 0.4, 0.95, -0.2 + (i % 2) * 0.35), Vector3(0.3, 0.3 + (i % 3) * 0.12, 0.25), [Color("c9a46a"), Color("8a2f2f"), Color("4a6fb0"), Color("efe9df"), Color("3f6b4f"), Color("b5653a")][i])
	m.cyl(Vector3(0, 0.8, 0), 0.04, 1.8, Color("5a4a3a"), 6)
	m.cone(Vector3(0, 2.5, 0), 1.7, 0.6, Color("2f5d3a"), 10)
	g.add_child(m.node(Kit.vc_mat(), "stall"))
	g.add_child(_lid(Vector3(1.2, 0.03, 1.1), Color("d9cbb0"), Vector3(0.6, 1.25, -0.55)))
	return g

## A sheet hinged along its back edge at `at`, lying flat (closed) at rotation 0; the shared code tips it back.
static func _lid(size: Vector3, col: Color, at: Vector3) -> Node3D:
	var lid := Node3D.new(); lid.name = "lid"; lid.position = at
	var m := Kit.Merge.new()
	m.box(Vector3(0, 0, size.z / 2.0), size, col)
	lid.add_child(m.node(Kit.vc_mat(), "sheet"))
	return lid

## A page of the score, lying on the pavement and catching the streetlight.
static func page(n: Dictionary) -> Node3D:
	var g := Node3D.new()
	var paper := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.32, 0.01, 0.44); paper.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("f3ead8"); mat.emission_enabled = true; mat.emission = Color("fff4d8"); mat.emission_energy_multiplier = 0.6
	paper.material_override = mat
	paper.position.y = 0.02; paper.rotation = Vector3(0.08, float(n.x) * 1.7, 0.05)
	g.add_child(paper)
	var m := Kit.Merge.new()   # staves
	for k in 5: m.box(Vector3(0, 0.03, -0.15 + k * 0.075), Vector3(0.26, 0.004, 0.008), Color("3a3836"))
	var st := m.node(Kit.vc_mat(), "staves"); st.rotation.y = paper.rotation.y; g.add_child(st)
	return g
