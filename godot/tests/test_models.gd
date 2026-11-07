extends RefCounted
## The Blender models (docs/MODELS.md, tools/blender) follow the conventions ModelKit relies on: wh_<kind>_<hex>
## materials it can restyle, the origin on the ground in the middle of the footprint, a triangle budget, and for the
## rigged Sindaco a skeleton with its animations. Also checks the model lab files only name models that exist.
var t

const LAB := "res://assets/models/lab/"
const BUDGET := {"via_selciato": 45000, "sindaco": 8000, "toy_lane": 6000, "toy_piazza": 6000, "lamp_double": 2000, "cafe_set": 2000}
const HOUSE_BUDGET := 45000

func _models() -> Array:
	var out: Array = []
	for f in DirAccess.open(LAB).get_files():
		if f.ends_with(".glb"): out.append(f.get_basename())
	out.sort()
	return out

func _triangles(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n

func test_parse_material_names():
	t.eq(ModelKit.parse("wh_plaster_d8a557").kind, "plaster", "kind")
	t.ok((ModelKit.parse("wh_roof_b55a35.001").color as Color).is_equal_approx(Color("b55a35")), "colour, despite a suffix")
	t.ok(ModelKit.parse("Material.001").is_empty(), "other names are left alone")
	t.ok(ModelKit.material_for("wh_plaster_d8a557", {"d8a557": "e6d6b4"}).albedo_color.is_equal_approx(Color("e6d6b4")), "recolour")

func test_lab_models_load_with_the_games_materials():
	var names := _models()
	t.ok(names.size() >= 6, "the lab has its models (%d)" % names.size())
	for n in names:
		var node := ModelKit.load_model(LAB + n + ".glb")
		t.ok(node != null, "%s loads" % n)
		if node == null: continue
		t.root.add_child(node)
		var tris := 0
		var box := AABB()
		var first := true
		var unstyled: Array = []
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			tris += _triangles(mi.mesh)
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b); first = false
			for i in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(i) == null: unstyled.append(mi.mesh.surface_get_material(i).resource_name)
		t.ok(unstyled.is_empty(), "%s: every material is a wh_<kind>_<hex> the game restyles (not: %s)" % [n, unstyled])
		var budget: int = BUDGET.get(n, HOUSE_BUDGET)
		t.ok(tris > 0 and tris <= budget, "%s: %d triangles, within %d" % [n, tris, budget])
		t.ok(absf(box.position.y) < 0.08, "%s stands on the ground (lowest point %.2f)" % [n, box.position.y])
		var c := box.get_center()
		t.ok(absf(c.x) < 0.8 and absf(c.z) < 0.8, "%s: origin in the middle of its footprint (%.2f, %.2f)" % [n, c.x, c.z])
		if not BUDGET.has(n):   # a house: two or three storeys of a village street, its front facing +Z
			t.ok(box.size.y > 6.0 and box.size.y < 14.0, "%s is %.1f m tall" % [n, box.size.y])
		node.queue_free()

func test_the_sindaco_is_rigged_and_animated():
	var node := ModelKit.load_model(LAB + "sindaco.glb")
	t.root.add_child(node)
	var skel: Skeleton3D = node.find_children("*", "Skeleton3D", true, false).front()
	t.ok(skel != null and skel.get_bone_count() == 12, "a skeleton of 12 bones")
	var ap: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false).front()
	for a in ["idle", "walk", "talk"]: t.ok(ap != null and ap.has_animation(a), "animation %s" % a)
	if ap and ap.has_animation("walk"):
		t.ok(absf(ap.get_animation("walk").length - 1.0) < 0.1, "one stride a second")
	var mi: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false).front()
	var box: AABB = mi.get_aabb()
	t.ok(box.size.y > 1.2 and box.size.y < 1.6, "a little taller than the player (%.2f m)" % box.size.y)
	node.queue_free()

func test_lab_files_name_real_models():
	for f in ["res://tests/model_lab.json", "res://tests/model_lab_sindaco.json"]:
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(f))
		for m: Dictionary in spec.models:
			t.ok(ResourceLoader.exists(m.glb), "%s: %s exists" % [f.get_file(), m.glb])

func test_lab_look_materials():
	ModelKit.look = {}
	var plain := ModelKit.pbr_material("iron", Color("26282a"), "")
	t.ok(plain.roughness < 0.6 and plain.metallic > 0.0, "iron without textures is a plain, slightly metallic material")
	var tex_ok := FileAccess.file_exists("res://assets/textures/lab/cc0/plaster_albedo.jpg")
	if tex_ok:
		var m := ModelKit.pbr_material("plaster", Color("d9692f"), "cc0")
		t.ok(m.albedo_texture != null and m.normal_enabled and m.uv1_triplanar, "plaster gets the stucco maps, projected without UVs")
	t.ok(ModelKit.material_for("wh_plaster_d8a557") is StandardMaterial3D, "without a lab look, models keep the game's own materials")
