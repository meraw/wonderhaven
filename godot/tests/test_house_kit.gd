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

func _touches(b: Dictionary, side: String) -> bool:
	for o in Data.layout.buildings:
		if o == b: continue
		var ox := minf(b.x + b.w / 2.0, o.x + o.w / 2.0) - maxf(b.x - b.w / 2.0, o.x - o.w / 2.0)
		var oz := minf(b.z + b.d / 2.0, o.z + o.d / 2.0) - maxf(b.z - b.d / 2.0, o.z - o.d / 2.0)
		match side:
			"E": if absf((o.x - o.w / 2.0) - (b.x + b.w / 2.0)) < 0.05 and oz > 1.0: return true
			"W": if absf((b.x - b.w / 2.0) - (o.x + o.w / 2.0)) < 0.05 and oz > 1.0: return true
			"S": if absf((o.z - o.d / 2.0) - (b.z + b.d / 2.0)) < 0.05 and ox > 1.0: return true
			"N": if absf((b.z - b.d / 2.0) - (o.z + o.d / 2.0)) < 0.05 and ox > 1.0: return true
	return false

func test_the_village_core_is_dense_and_clear():
	var kit := _kit_buildings()
	t.ok(kit.size() >= 16, "Monteforchetta has a village core of kit houses (%d)" % kit.size())
	var rows := kit.filter(func(b): return b.has("party"))
	t.ok(rows.size() >= 4, "some houses stand in attached rows (%d)" % rows.size())
	for b in rows:
		for s in b.party: t.ok(_touches(b, String(s)), "%s shares its %s wall with a neighbour" % [b.id, s])
	var sq: Dictionary = Data.layout.square
	for b in kit.filter(func(b): return not Interiors.enterable(b)):
		var near_path := INF
		var near_node := INF
		var near_square := INF
		for i in 9:
			for k in 9:
				var x: float = b.x - b.w / 2.0 + b.w * i / 8.0
				var z: float = b.z - b.d / 2.0 + b.d * k / 8.0
				near_path = minf(near_path, WorldStatics.dist_to_paths(x, z))
				near_square = minf(near_square, Vector2(x - sq.x, z - sq.z).length() - float(sq.r))
				for n in Data.layout.nodes: near_node = minf(near_node, Vector2(x - n.x, z - n.z).length())
		t.ok(near_path > 1.3, "%s keeps off the lanes (%.2f m)" % [b.id, near_path])
		t.ok(near_node > 1.4, "%s leaves every resource spot reachable (%.2f m)" % [b.id, near_node])
		t.ok(near_square > 0.0, "%s stands round the piazza, not on it" % b.id)

func _building(id: String) -> Dictionary:
	for b in Data.layout.buildings:
		if b.id == id: return b
	return {}

func _coppi(g: Node) -> int:
	var n := 0
	for mmi in g.find_children("*", "MultiMeshInstance3D", true, false):
		if (mmi as MultiMeshInstance3D).material_override is ShaderMaterial: n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n

func test_landmarks_are_restyled_with_the_kit():
	t.ok(HouseKit.kit_style(), "Monteforchetta builds with the kit")
	var ws := _building("workshop")
	var w := Props.workshop(ws)
	for nm in ["walls", "clutter", "signGear"]: t.ok(w.find_child(nm, true, false) != null, "the workshop keeps its %s" % nm)
	t.ok(_coppi(w) > 200, "the workshop has a coppi roof (%d tiles)" % _coppi(w))
	t.ok((w.get_meta("fade_parts", []) as Array).any(func(p): return p[0] is MultiMeshInstance3D), "its coppi fade while you're inside")
	t.ok(not w.get_meta("glasses", []).is_empty(), "its windows light at night")
	w.free()
	var ch := Props.church(_building("odessaHouse"))
	t.ok(_coppi(ch) > 100, "the church has a coppi roof (%d tiles)" % _coppi(ch))
	t.ok(ch.get_meta("glasses", []).size() >= 2, "the rose window and side windows glow at night")
	ch.free()
	var cb := _building("castle")
	var c := Props.castle(cb)
	var room := Interiors.room(cb)
	var lamps := c.find_children("*", "OmniLight3D", true, false)
	t.ok(lamps.size() >= 2, "the castle hall has lamps")
	for l in lamps:
		var p: Vector3 = (l as OmniLight3D).position + Vector3(cb.x, 0.0, cb.z)
		t.ok(room.has_point(Vector3(p.x, room.position.y + 1.0, p.z)), "a hall lamp hangs inside the hall")
		t.ok(not (l as OmniLight3D).shadow_enabled, "and casts no shadows, for speed")
	t.ok(not c.get_meta("fade_parts", []).is_empty(), "the keep's roof still fades while you're inside")
	t.ok(not c.get_meta("glasses", []).is_empty(), "the keep's windows and lamps glow at night")
	c.free()
