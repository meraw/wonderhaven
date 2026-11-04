extends RefCounted
## Boccapioppo (river_town): the ground has the shape docs/locations/river_town.md describes, you can't walk off the
## map, the Alpine river really separates the east bank (only the Roman bridge crosses it until the pontoon bridge
## is built), and every spot on the map can be reached.
var t
const RT := preload("res://scripts/locations/river_town.gd")

func _on(fn: Callable) -> void:
	Data.use_island("river_town")
	fn.call()
	Data.use_island("hearthglow")

func test_the_pack_is_loaded():
	t.ok(Data.location_ids().has("river_town"), "Boccapioppo is a location pack")
	var d := Data.island_def("river_town")
	t.eq(d.get("name", ""), "Boccapioppo", "its map entry is named")
	t.ok(d.get("hidden", false), "it stays off the travel map until the bus line reveals it")
	t.ok(d.get("look", {}).has("light"), "it has its own look")

func test_ground_shape():
	_on(func():
		var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
		t.ok(H.call(0, 50) < Heightfield.WALKABLE_MIN and H.call(-40, 45) < Heightfield.WALKABLE_MIN, "the Po runs along the south")
		t.ok(Heightfield.is_water(RT.alpine_center(-10.0), -10.0), "the Alpine river runs down the east side")
		t.ok(Heightfield.is_stream_cell(floor(RT.alpine_center(5.0)), 5) and Heightfield.is_stream_cell(28, 6), "the Alpine river flows: a waterwheel turns in it")
		t.ok(not Heightfield.is_stream_cell(0, 50) and not Heightfield.is_stream_cell(-24, 35) and not Heightfield.is_stream_cell(-56, 0), "the Po, the backwater and the canals are still water")
		var town: float = H.call(-20, 0)
		var crest: float = H.call(-30, RT.LEVEE_Z)
		var flood: float = H.call(-30, 31)
		t.ok(town > 0.3 and flood > Heightfield.WALKABLE_MIN and flood < town, "the floodplain lies below the town (%.2f < %.2f)" % [flood, town])
		t.ok(crest - town > 2.0 and crest - flood > 2.0, "the levee stands well above both sides (%.2f)" % crest)
		t.ok(H.call(RT.LEVEE_X, -10) - town > 2.0, "the levee turns north along the Alpine river")
		t.ok(H.call(5, RT.LEVEE_Z) < crest - 1.5, "the breach is a gap in the levee")
		t.ok(H.call(RT.PIAZZA.x, RT.PIAZZA.z) < town - 0.15, "the piazza is the lowest part of town")
		t.ok(Heightfield.is_water(RT.SUMP.x, RT.SUMP.y), "the old sump at the piazza's edge holds water")
		t.ok(Heightfield.is_water(RT.BACKWATER.x, RT.BACKWATER.z), "the backwater lies on the floodplain")
		t.ok(not Heightfield.is_water(RT.SANDBANK.x, RT.SANDBANK.z), "the sandbank reaches out into the Po")
		t.ok(H.call(RT.alpine_center(RT.ROMAN_Z), RT.ROMAN_Z) > 1.5, "the Roman bridge's walkway arches over the river")
		var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_ermes_house")[0]
		t.ok(absf(H.call(b.x, b.z) - town) < 0.15 and H.call(b.x, b.z + b.d / 2.0 + 4.5) > crest - 0.1, "the warden's house stands at the foot of the levee, the levee road just behind it")
		t.ok(absf(H.call(16.0, 31.5) - RT.DANCE_H) < 0.01 and H.call(16.0, 31.5) - H.call(16.0, 36.0) > 0.6, "the dance hall's floor is a raised platform above the floodplain"))

## Cells you can walk to from the bus stop, stepping half a metre at a time over the bare ground (buildings and
## trees left out). `cut` marks cells to treat as blocked.
func _reachable(cut: Callable = func(_x, _z): return false) -> Dictionary:
	var w := WalkWorld.new([])
	var step := 0.5
	var sp: Dictionary = Data.layout.spawn
	var start := Vector2i(roundi(sp.x / step), roundi(sp.z / step))
	var seen := {start: Heightfield.height(sp.x, sp.z)}
	var open := [start]
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n) or absi(n.x) > 140 or absi(n.y) > 140: continue
			var x := n.x * step; var z := n.y * step
			if cut.call(x, z): continue
			var s := w.can_stand(x, z, seen[c], 0.0)
			if s.is_empty(): continue
			seen[n] = s.y
			open.append(n)
	return seen

func test_you_cant_walk_off_the_map():
	_on(func():
		var seen := _reachable()
		var far := 0.0
		for c in seen: far = maxf(far, maxf(absf(c.x * 0.5), absf(c.y * 0.5)))
		t.ok(far < 55.0, "canals and the Po keep you on the map (furthest point %.1f m from the centre)" % far)
		t.ok(seen.has(Vector2i(90, 24)), "the east bank is reachable over the Roman bridge (beside the sawmill)")
		t.ok(seen.has(Vector2i(-48, 58)), "the floodplain is reachable (the houseboat)")
		t.ok(seen.has(Vector2i(10, 8)), "the town is reachable (the piazza)")
		var no_bridge := _reachable(func(x, z): return absf(z - RT.ROMAN_Z) < 2.0 and x > 20.0 and x < 38.0)
		t.ok(not no_bridge.has(Vector2i(90, 24)), "without the Roman bridge the east bank is cut off: the river is a real barrier"))

func test_every_spot_can_be_reached():
	_on(func():
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path("busStop", k, {}).is_empty(), "the nav graph reaches %s from the bus stop" % k))

func test_build_zones_fit_their_jobs():
	_on(func():
		var bridge := Data.zone("river_town_bridge")
		var ends: Dictionary = bridge.endpoints
		t.ok(not Heightfield.is_water(ends.a.minI + 0.5, ends.a.minK + 1.5) and not Heightfield.is_water(ends.b.minI + 0.5, ends.b.minK + 1.5), "the pontoon bridge site starts and ends on dry banks")
		var wet := 0
		for i in range(bridge.minI, bridge.maxI + 1): if Heightfield.is_water(i + 0.5, 13.5): wet += 1
		t.ok(wet >= 7, "the pontoon bridge has to cross real water (%d cells)" % wet)
		var works := Data.zone("river_town_works")
		var flowing := 0
		for i in range(works.minI, works.maxI + 1):
			for k in range(works.minK, works.maxK + 1): if Heightfield.is_stream_cell(i, k): flowing += 1
		t.ok(flowing >= 4, "the pump works reach the Alpine river, where a waterwheel turns (%d cells)" % flowing)
		t.ok(BuildGrid.zone_contains(works, floor(RT.SUMP.x), floor(RT.SUMP.y), 999), "the pump works include the piazza's sump")
		var breach := Data.zone("river_town_breach")
		t.ok(breach.minI <= RT.BREACH.x and breach.maxI + 1 >= RT.BREACH.y, "the breach zone spans the whole gap")
		var moor := Data.zone("river_town_mooring")
		var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_houseboat")[0]
		t.ok(BuildGrid.zone_contains(moor, floor(b.x), floor(b.z + b.d / 2.0 + 0.5), 999), "the mooring zone starts at the houseboat")
		t.ok(BuildGrid.zone_contains(moor, floor(RT.BACKWATER.x), floor(RT.BACKWATER.z - RT.BACKWATER_HALF.y), 999), "and reaches the backwater")
		for z in Data.layout.zones:
			t.ok(String(z.id).begins_with("river_town_"), "zone %s has the location's prefix" % z.id))

## Villagers and the playthrough walk the nav graph in straight lines: every edge must be walkable with the real
## collision (buildings, room walls and furniture, tree trunks, columns, posts), up ramps and over the Roman bridge.
func test_every_nav_edge_is_walkable():
	_on(func():
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		var nodes: Dictionary = Data.layout.nav_nodes
		for e in Data.layout.nav_edges:
			var a: Array = nodes[e[0]]; var b: Array = nodes[e[1]]
			var steps := maxi(1, int(Vector2(b[0] - a[0], b[1] - a[1]).length() / 0.2))
			var feet := Heightfield.height(a[0], a[1])
			var blocked := ""
			for k in range(1, steps + 1):
				var x: float = lerpf(a[0], b[0], float(k) / steps); var z: float = lerpf(a[1], b[1], float(k) / steps)
				var s := w.can_stand(x, z, feet, 0.3)
				if s.is_empty(): blocked = "at %.1f, %.1f" % [x, z]; break
				feet = s.y
			t.ok(blocked == "", "walkable: %s to %s %s" % [e[0], e[1], blocked]))

func test_scenery_props_are_drawn_and_placed():
	_on(func():
		var kinds := {}
		for p in Data.layout.props: kinds[String(p.get("tree", p.kind))] = true
		for k in ["poplar", "column", "willow", "locust", "river_town_column", "river_town_post", "river_town_logs", "lamp_post"]:
			t.ok(kinds.has(k), "the layout places %s" % k)
		for p in Data.layout.props:
			if p.get("solid", true) and p.kind != "river_town_gauge": t.ok(not Heightfield.is_water(p.x, p.z), "%s at %.1f, %.1f stands on land" % [p.get("tree", p.kind), p.x, p.z])
		var Scenery = load("res://scripts/locations/river_town/scenery.gd")
		for k in ["poplar", "column", "willow", "locust", "plane"]:
			t.ok(Scenery.canopy(k).get_surface_count() > 0, "a %s canopy mesh is built" % k))

func test_rooms_you_can_walk_into():
	_on(func():
		var rooms := ["river_town_houseboat", "river_town_dance_hall", "river_town_bar", "river_town_workshop", "river_town_ermes_house", "river_town_pierina_house", "river_town_shack"]
		for id in rooms:
			var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == id)[0]
			t.ok(Interiors.enterable(b), "%s is a room you can walk into" % id)
		var hall: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_dance_hall")[0]
		t.ok(hall.interior.get("empty", false), "the dance hall stands empty, waiting for its request")
		var feats: Array = Data.layout.features.map(func(f): return f.kind)
		t.ok(feats.has("rest") and feats.has("wardrobe"), "the houseboat has a bed to sleep in and a wardrobe")
		var boat: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_houseboat")[0]
		for f in Data.layout.features.filter(func(f): return f.kind in ["rest", "wardrobe"]):
			t.ok(Interiors.room(boat).has_point(Vector3(f.x, 0.5, f.z)), "the %s is inside the houseboat" % f.kind))
