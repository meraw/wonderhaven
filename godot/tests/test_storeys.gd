extends RefCounted
var t

const REACH_Y := 1.6

func test_every_feature_can_be_reached_from_where_you_stand():
	var places: Array = Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)
	for id in places:
		Data.use_island(id)
		var floors := WorldStatics.floors()
		for f in Data.layout.get("features", []):
			var y = WorldActions.feature_y(f)
			if y == null: continue
			var heights := _stand_heights(float(f.x), float(f.z), floors)
			t.ok(heights.any(func(h): return absf(h - float(y)) <= REACH_Y), "%s, %s at %.2f: nowhere to stand within reach (%s)" % [id, f.id, float(y), str(heights)])
	Data.use_island("hearthglow")

func test_the_waiting_room_bench_is_not_on_the_flat_storey():
	Data.use_island("rice_village")
	var bench: Dictionary = {}
	for f in Data.layout.features:
		if f.id == "rice_village_waitingBench": bench = f
	t.ok(not bench.is_empty(), "the waiting-room bench is in Casalrana's layout")
	if not bench.is_empty():
		var y = WorldActions.feature_y(bench)
		t.ok(y != null and absf(3.5 - float(y)) > REACH_Y, "the bench's prompt is a storey below the flat's floor (%s)" % str(y))
	Data.use_island("hearthglow")

func test_villagers_stand_on_their_rooms_storey():
	var places: Array = Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)
	for id in places:
		Data.use_island(id)
		var walk := WalkWorld.new([])
		walk.floors = WorldStatics.floors()
		for k in Data.layout.nav_nodes:
			var storey := NpcAgent.node_storey(k)
			if storey == INF: continue
			var n: Array = Data.layout.nav_nodes[k]
			var y: float = walk.surface_at(float(n[0]), float(n[1]), storey).y
			t.ok(absf(y - storey) <= WalkWorld.STEP_UP, "%s, %s: a villager there stands at %.2f, not on the room's storey %.2f" % [id, k, y, storey])
	Data.use_island("hearthglow")

func test_matteo_reads_in_the_waiting_room_not_in_the_flat_above():
	Data.use_island("rice_village")
	var walk := WalkWorld.new([])
	walk.floors = WorldStatics.floors()
	var n: Array = Data.layout.nav_nodes["rice_village_station:spot"]
	var y: float = walk.surface_at(float(n[0]), float(n[1]), NpcAgent.node_storey("rice_village_station:spot")).y
	t.ok(absf(3.5 - y) > REACH_Y, "the waiting room's spot is a storey below the flat's floor (%.2f)" % y)
	Data.use_island("hearthglow")

func _stand_heights(x: float, z: float, floors: Array) -> Array:
	var out: Array = []
	for a in 9:
		var px := x; var pz := z
		if a > 0:
			px += cos(a * PI / 4.0) * 1.2; pz += sin(a * PI / 4.0) * 1.2
		var g := Heightfield.height(px, pz)
		if g >= Heightfield.WALKABLE_MIN: out.append(g)
		for s in floors:
			if not s.walkable or px < s.minX or px > s.maxX or pz < s.minZ or pz > s.maxZ: continue
			out.append(s.ramp.call(px, pz) if s.has("ramp") else float(s.top))
	return out
