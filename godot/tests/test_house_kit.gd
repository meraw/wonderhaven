extends RefCounted
var t

const PARTS := ["window", "grate", "door_arched", "doorway_arched", "door_plain", "balcony", "shopfront",
	"shopfront_open", "chimney_stack", "chimney_cap", "coppo_cap", "coppo_pan", "wall_lamp", "pot_flowers",
	"shutter_0", "shutter_110", "shutter_135", "shutter_178"]
const GLAZED := ["window", "door_arched", "balcony", "shopfront", "shopfront_open", "wall_lamp"]

func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node3D = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			if not (c is Node3D): continue
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D or c is MultiMeshInstance3D:
				var a: AABB = cx * (c as VisualInstance3D).get_aabb()
				box = a if first else box.merge(a)
				first = false
			stack.append([c, cx])
	return box

func _kit_buildings() -> Array:
	return Data.layout.buildings.filter(func(b): return HouseKit.uses(b))

func test_the_kit_has_every_part():
	for p in PARTS: t.ok(HouseKit.has_part(p), "the kit has a %s" % p)
	for p in GLAZED: t.ok(HouseKit.part_mesh(p, {}, true) != null, "%s has its glass apart, to light it at night" % p)
	var tris := 0
	for p in PARTS:
		var m := HouseKit.part_mesh(p)
		for i in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(i)
			tris += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	t.ok(tris < 6000, "the whole kit is small (%d triangles)" % tris)

func test_monteforchetta_houses_come_from_the_kit():
	var kit := _kit_buildings()
	t.ok(kit.size() >= 6, "Monteforchetta's houses and shops are kit-built (%d)" % kit.size())
	for b in kit:
		var g := HouseKit.build(b)
		var box := _bounds(g)
		var reach := HouseKit.OVERHANG + 0.5
		t.ok(box.position.x > -b.w / 2.0 - reach and box.end.x < b.w / 2.0 + reach, "%s stays on its footprint east to west" % b.id)
		t.ok(box.position.z > -b.d / 2.0 - reach and box.end.z < b.d / 2.0 + reach, "%s stays on its footprint north to south" % b.id)
		t.ok(box.end.y <= HouseKit.height(b) + 0.01, "%s is no taller than the camera thinks (%.2f)" % [b.id, box.end.y])
		t.ok(not g.get_meta("glasses", []).is_empty(), "%s has windows that light up at night" % b.id)
		t.ok(g.has_meta("chimney"), "%s has a chimney for smoke" % b.id)
		if Interiors.enterable(b):
			var parts: Array = g.get_meta("fade_parts", [])
			t.ok(parts.size() > 4, "%s fades above the room you're in" % b.id)
			t.ok(parts.any(func(p): return p[0] is MultiMeshInstance3D), "%s fades its coppi too" % b.id)
		g.free()

func test_shared_walls_have_no_windows():
	var b := {"id": "row_test", "kind": "cottage", "x": 0.0, "z": 0.0, "w": 6.0, "d": 6.0, "wall": "#e0c9a0",
		"roof": "#c46a3e", "door": "S", "party": ["E", "W"], "floors": 2}
	var g := HouseKit.build(b)
	var win := HouseKit.part_mesh("window")
	var seen := 0
	for mmi in g.find_children("*", "MultiMeshInstance3D", true, false):
		if (mmi as MultiMeshInstance3D).multimesh.mesh != win: continue
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			seen += 1
			t.ok(absf(mm.get_instance_transform(i).origin.x) < 2.95, "no window on a shared side wall")
	t.ok(seen > 4, "the front and back still have windows (%d)" % seen)
	g.free()

func test_mirrored_shutters_keep_their_shape():
	var a := HouseKit.part_mesh("shutter_0")
	var m := HouseKit.part_mesh("shutter_0", {}, false, true)
	t.eq(m.get_surface_count(), a.get_surface_count(), "a right-hand leaf has the same surfaces")
	t.ok(absf(m.get_aabb().position.x + a.get_aabb().end.x) < 0.001, "and opens the other way")

func test_camera_and_snow_know_the_kit():
	var blockers := Props.camera_blockers()
	for b in _kit_buildings():
		var tall := blockers.any(func(box: AABB): return box.has_point(Vector3(b.x, HouseKit.height(b) - 0.2, b.z)))
		t.ok(tall, "the camera stops at the top of %s" % b.id)
	t.ok(HouseKit.tile_material(Color("c46a3e")).shader.code.contains("world_snow"), "coppi take the snow")
