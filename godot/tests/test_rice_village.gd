extends RefCounted
## Casalrana (rice_village), stage 1: the ground and the map make a playable world. You arrive at the bus stop, can
## walk everywhere the village needs, can't walk onto the railway except at the level crossing, and the canal, the
## spring pool and the winter paddy are where the design puts them. Build sites are on dry ground, the weather is
## always clear, and the ground is painted (stubble, gravel, brick) rather than meadow. See docs/locations/rice_village.md.
var t

const ID := "rice_village"
const RV := preload("res://scripts/locations/rice_village.gd")

## Runs `fn` with Casalrana loaded, then always switches back to Monteforchetta for the other tests.
func _here(fn: Callable) -> void:
	Data.use_island(ID)
	fn.call()
	Data.use_island("hearthglow")

func _world() -> WalkWorld:
	return WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return false)

func _stand(w: WalkWorld, x: float, z: float) -> bool:
	return not w.can_stand(x, z, Heightfield.height(x, z), 0.3).is_empty()

func test_it_is_a_location_pack():
	t.ok(Data.location_ids().has(ID), "Casalrana is a location pack")
	var isl := Data.island_def(ID)
	t.eq(isl.get("name", ""), "Casalrana", "its map entry is named")
	t.ok(isl.get("hidden", false), "it stays off the travel map until the bus line reaches it")
	t.eq(isl.get("look", {}).get("weather", []), ["clear"], "its look allows only clear weather")

func test_you_arrive_at_the_bus_stop():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		t.ok(_stand(w, sp.x, sp.z), "you step off the bus onto open ground")
		var stop: Array = Data.layout.features.filter(func(f): return f.kind == "boat")
		t.eq(stop.size(), 1, "one departure point")
		t.eq(stop[0].id, "boat", "the engine finds the departure point by its id")
		t.ok(Vector2(stop[0].x - sp.x, stop[0].z - sp.z).length() < 2.6, "the bus stop is where you arrive")
		t.eq(Data.layout.get("arrive", {}), Data.layout.spawn, "arriving later puts you at the same stop"))

func test_every_nav_spot_can_be_walked_to():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		var start := Schedule.nearest_node(sp.x, sp.z, {})
		t.eq(start, "busStop", "the walk starts at the bus stop")
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path(start, k, {}).is_empty(), "the nav graph reaches %s" % k)
		# walkers follow each edge in a straight line: no water or obstacles along the way
		for e in Data.layout.nav_edges:
			var a: Array = Data.layout.nav_nodes[e[0]]; var b: Array = Data.layout.nav_nodes[e[1]]
			var ok := true
			for s in 41:
				var x: float = lerpf(a[0], b[0], s / 40.0); var z: float = lerpf(a[1], b[1], s / 40.0)
				if not _stand(w, x, z): ok = false
			t.ok(ok, "the way from %s to %s is open ground" % [e[0], e[1]]))

func test_the_railway_is_closed_except_at_the_crossing():
	_here(func():
		var w := _world()
		for x in [-50.0, -20.0, -3.0, 8.0, 19.0, 45.0]:
			t.ok(not _stand(w, x, RV.RAIL_Z), "no walking on the line at x %.0f" % x)
		t.ok(_stand(w, 2.0, RV.RAIL_Z), "the level crossing is open")
		var a: Array = Data.layout.nav_nodes.crossingS; var b: Array = Data.layout.nav_nodes.crossingN
		t.ok(a[1] > RV.RAIL_Z and b[1] < RV.RAIL_Z, "the crossing joins both sides of the line")
		var tracks: Array = Data.layout.buildings.filter(func(bd): return bd.kind == "rice_village_track")
		t.eq(tracks.size(), 2, "the railway bed is two blocks with the crossing between them")
		t.ok(tracks.all(func(bd): return float(bd.top) < 1.5), "the camera can look over the railway bed"))

func test_water_where_the_design_puts_it():
	_here(func():
		t.ok(Heightfield.is_water(RV.CANAL_X, 0.0) and Heightfield.is_water(RV.CANAL_X, -30.0), "the canal can't be walked")
		var dry := 0; var puddles := 0
		for z in range(-50, 51):
			var h := Heightfield.height(RV.CANAL_X, float(z))
			if h > Heightfield.WATER_Y: dry += 1
			else: puddles += 1
		t.ok(dry > 60 and puddles > 10, "the canal is drained: a muddy bed with puddles (%d dry, %d puddles)" % [dry, puddles])
		t.ok(Heightfield.is_stream_cell(-41, 0) and Heightfield.is_stream_cell(-40, -30), "the canal flows for waterwheels")
		t.ok(not Heightfield.is_stream_cell(-30, 0) and not Heightfield.is_stream_cell(2, -6), "the fields and the village don't")
		var wc := RV.WINTER.get_center()
		t.ok(Heightfield.is_water(wc.x, wc.y) and Heightfield.height(wc.x, wc.y) > Heightfield.WATER_Y, "the winter paddy is sunken and dry until it's flooded")
		t.ok(Heightfield.height(RV.POOL.x, RV.POOL.y) < Heightfield.WATER_Y - 0.4, "the spring pool is deep water")
		var mirrors := RV.PUDDLES.filter(func(p): return Heightfield.height(p.x, p.y) < Heightfield.WATER_Y)
		t.eq(mirrors.size(), RV.PUDDLES.size(), "every puddle in the stubble shows the sky")
		t.ok(Heightfield.is_water(0.0, 58.0) and Heightfield.is_water(-58.0, 0.0), "past the edge the plain runs on as flooded paddies")
		t.ok(not Heightfield.is_water(2.0, -6.0) and absf(Heightfield.height(2.0, -6.0) - RV.PAD) < 0.01, "the crossroads is flat ground")
		for n in Data.layout.nodes:
			if n.kind == "fish": t.ok(Heightfield.is_water(n.x, n.z), "%s is in the spring pool" % n.id))

func test_build_sites_are_on_dry_ground():
	_here(func():
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		for id in ["rice_village_plot", "rice_village_platform", "rice_village_churchyard", "rice_village_bench"]:
			var zn := Data.zone(id)
			t.ok(not zn.is_empty(), "%s exists" % id)
			var wet := 0; var blocked := 0
			for i in range(int(zn.minI), int(zn.maxI) + 1):
				for k in range(int(zn.minK), int(zn.maxK) + 1):
					if Heightfield.is_water(i + 0.5, k + 0.5): wet += 1
					var cell := {"minX": i + 0.05, "maxX": i + 0.95, "minZ": k + 0.05, "maxZ": k + 0.95}
					for s in statics:
						var hit := WalkWorld.circle_box(s.x, s.z, s.r, cell) if s.type == "circle" else BuildGrid.overlap2(cell, s)
						if hit: blocked += 1; break
			t.eq(wet, 0, "%s is dry ground" % id)
			t.eq(blocked, 0, "%s is clear of buildings and scenery" % id)
		for id in ["rice_village_mill", "rice_village_paddy", "rice_village_sluice"]:
			var zn := Data.zone(id)
			var flowing := false
			for i in range(int(zn.minI), int(zn.maxI) + 1):
				for k in range(int(zn.minK), int(zn.maxK) + 1):
					if Heightfield.is_stream_cell(i, k): flowing = true
			t.ok(flowing, "%s reaches the canal" % id)
		var plot := Data.zone("rice_village_plot")
		t.eq(plot.get("unlock", {}).get("flag", ""), "rice_village_homePlot", "your yard opens with your flat"))

func test_always_clear():
	_here(func():
		t.eq(Daylight.allowed_here(), ["clear"], "Casalrana allows only clear weather")
		for day in range(1, 20):
			for m in range(0, 1440, 60):
				t.eq(Clock.weather({"day": day, "minute": float(m)}), "sunny", "clear skies on day %d at %d:00" % [day, m / 60]))
	t.eq(Daylight.allowed_here(), [], "back in Monteforchetta any weather can come")

func test_the_ground_is_painted():
	_here(func():
		t.ok(Heightfield.has_ground_paint(), "Casalrana paints its own ground")
		t.eq(Heightfield.meadow(15.0, 28.0), 0.0, "harvested paddies are bare stubble")
		t.eq(Heightfield.meadow(2.0, -20.0), 0.0, "and so are the roads")
		t.ok(Heightfield.meadow(RV.POOL.x + 5.5, RV.POOL.y) > 0.5, "the spring pool's grove stays green")
		var stubble := Heightfield.ground(15.0, 28.0)
		t.ok(stubble.r > stubble.g and stubble.g > stubble.b, "stubble is pale gold-brown")
		var yard := Heightfield.ground(28.0, -7.0)
		t.ok(yard.r > yard.g + 0.1, "the farmstead's yard is brick")
		var decor := WorldStatics.generate_decor()
		t.eq(decor.flowers.size(), 0, "no flowers in late November")
		t.eq(decor.trees.size(), 0, "no stock trees: Casalrana's trees come from its own script")
		t.ok(decor.grass.all(func(g): return Heightfield.meadow(g.x, g.z) >= 0.5), "grass tufts only in the grove"))

func test_ids_carry_the_location_prefix():
	_here(func():
		for kind in ["buildings", "zones", "nodes"]:
			for e in Data.layout[kind]: t.ok(String(e.id).begins_with(ID + "_"), "%s %s starts with %s_" % [kind, e.id, ID])
		for f in Data.layout.features:
			t.ok(f.id == "boat" or String(f.id).begins_with(ID + "_"), "feature %s starts with %s_" % [f.id, ID])
		for b in Data.layout.buildings:
			var model: Node3D = RV.building(b)
			t.ok(model != null, "%s has a model" % b.id)
			if model: model.free())
