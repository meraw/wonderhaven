extends RefCounted
## Rooms you can walk into, in every place: nothing in a building's model lies across the room between the floor and
## head height. (A tide line drawn as a slab right across Gildo's shack, at knee height, once hid him below the
## waist, and the houseboat's hull filled her cabin up to people's shins.)
var t

func test_nothing_lies_across_a_room():
	var places: Array = Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)
	for id in places:
		Data.use_island(id)
		var pack := Data.location_script(id)
		var fns: Array = pack.get_script_method_list().map(func(m): return m.name) if pack else []
		var floors := WorldStatics.floors()
		for b in Data.layout.buildings:
			if not Interiors.enterable(b): continue
			var o: Node3D = Village.building_model(b, pack, fns)
			var base: float = float(b.y) if b.has("y") else (Heightfield.CASTLE_MOUND.y if b.kind == "castle" else maxf(0.0, Heightfield.height(b.x, b.z)))
			var floor_y: float = Props.CASTLE_FLOOR if b.kind == "castle" else 0.0
			var room := Interiors.room(b, 0.0)
			var rx0: float = room.position.x - b.x; var rx1: float = room.end.x - b.x
			var rz0: float = room.position.z - b.z; var rz1: float = room.end.z - b.z
			var area: float = (rx1 - rx0) * (rz1 - rz0)
			var fading := {}   # roof parts and upper storeys fade away while you're inside
			for part in o.get_meta("fade_parts", []): fading[part[0]] = true   # [mesh, solid, faded]
			for mi in o.find_children("*", "MeshInstance3D", true, false):
				if fading.has(mi) or (mi as MeshInstance3D).mesh == null: continue
				var bb := _local_aabb(mi, o)
				var top: float = bb.end.y - floor_y
				if top < 0.12 or top > 1.9: continue   # the floor itself, or up at the ceiling
				var over: float = maxf(0.0, minf(bb.end.x, rx1) - maxf(bb.position.x, rx0)) * maxf(0.0, minf(bb.end.z, rz1) - maxf(bb.position.z, rz0))
				if over < area * 0.5: continue   # furniture, a beam, a window: not across the room
				var walk_on := floors.any(func(f): return f.walkable and absf(float(f.top) - (base + bb.end.y)) < 0.15 and f.minX <= b.x and f.maxX >= b.x and f.minZ <= b.z and f.maxZ >= b.z)
				if walk_on: continue   # a raised floor you walk on (a mezzanine), not something you'd be buried in
				t.ok(false, "%s, %s: something lies right across the room %.2f m above its floor (%s)" % [id, b.id, top, mi.name])
			o.free()
	Data.use_island("hearthglow")

## A mesh's box in the building model's own space (the model isn't in the scene tree, so no global transforms).
static func _local_aabb(mi: MeshInstance3D, root: Node3D) -> AABB:
	var xf: Transform3D = mi.transform
	var p: Node = mi.get_parent()
	while p != null and p != root:
		if p is Node3D: xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf * mi.get_aabb()
