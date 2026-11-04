extends RefCounted
## Toriano (metropolis), stage 1: the ground and the street plan. The canals and the Darsena hold water with quays
## you can't fall off, the old bridge carries you over the west canal, every nav spot can be reached on foot from the
## station, the edge of the city keeps you in, and the build sites sit where their requests will need them.
var t
const P := "metropolis_"

func _on(fn: Callable) -> void:
	Data.use_island("metropolis")
	fn.call()
	Data.use_island("hearthglow")

func _world() -> WalkWorld:
	return WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)

func test_the_city_is_big_and_paved():
	_on(func():
		t.eq(Data.map_size(), 372.0, "three times as wide as a village")
		t.eq(Ground.kind_at(-10, 4), "slabs", "the cathedral square is stone slabs")
		t.eq(Ground.kind_at(40, -95), "setts", "the tram tracks run in setts")
		t.eq(Ground.kind_at(60, -98.5), "asphalt", "beside them, asphalt")
		t.eq(Ground.kind_at(-38, 112), "setts", "the courtyard of number 14 is setts")
		t.eq(Ground.kind_at(-140, -140), "grass", "the park is grass")
		t.eq(Ground.kind_at(-106.5, -126), "gravel", "with a gravel path round the pond")
		t.ok(Data.layout.paths.is_empty() and Data.layout.square.r < 0.0, "no village dirt paths or cobbled ring")
		var d := WorldStatics.generate_decor()
		t.ok(d.trees.size() >= 20 and d.trees.all(func(p): return p.x < -88 and p.z < -98 and not Ground.paved(p.x, p.z)), "trees grow in the park only (%d)" % d.trees.size()))

func test_water_and_quays():
	_on(func():
		for p in [[-116, 105], [-170, 105], [-107, 160], [-120, -126]]:
			t.ok(Heightfield.is_water(p[0], p[1]), "water at %s" % [p])
		for p in [[-116, 88], [-116, 121], [-170, 96], [-99, 160], [-115, 160], [-10, 4], [120, -132]]:
			t.ok(not Heightfield.is_water(p[0], p[1]) and absf(Heightfield.height(p[0], p[1]) - 0.3) < 0.01, "level dry ground at %s" % [p])
		t.ok(Heightfield.height(-116, 92.2) < Heightfield.WALKABLE_MIN, "the quay wall drops straight into the Darsena")
		t.ok(Heightfield.is_stream_cell(-108, 150) and Heightfield.is_stream_cell(-148, 104), "both canals flow, for waterwheels")
		t.ok(not Heightfield.is_stream_cell(-116, 105) and not Heightfield.is_stream_cell(-120, -126), "the Darsena and the pond are still")
		t.ok(not Heightfield.is_stream_cell(-157, 104), "no water flows on the old bridge"))

func test_the_old_bridge_and_the_quay_hold_you():
	_on(func():
		var w := _world()
		var pos := Vector3(-157, Heightfield.height(-157, 95), 95)
		for n in 100: pos = w.step_move(pos, 0.0, 0.2).pos
		t.ok(pos.z > 114.5, "you can walk over the old bridge to the bars' bank (reached z %.1f)" % pos.z)
		pos = Vector3(-116, 0.3, 86)
		for n in 60: pos = w.step_move(pos, 0.0, 0.2).pos
		t.ok(pos.z < 92.0 and not Heightfield.is_water(pos.x, pos.z), "walking at the Darsena stops at the quay (z %.2f)" % pos.z))

## Flood-fills the streets from the station in 1.5 m steps: every nav spot is reached and nothing past the backdrop.
func test_every_spot_is_reachable_and_the_edge_is_closed():
	_on(func():
		var w := _world()
		var step := 1.5
		var sp: Dictionary = Data.layout.spawn
		var start := Vector2i(roundi(sp.x / step), roundi(sp.z / step))
		var seen := {start: true}
		var queue: Array = [start]
		var beyond := 0
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for dvec in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dvec
				if seen.has(n): continue
				var x := n.x * step; var z := n.y * step
				if absf(x) > 186.0 or absf(z) > 186.0: beyond += 1; continue
				if w.can_stand(x, z, Heightfield.height(x, z), 0.3).is_empty(): continue
				seen[n] = true
				if absf(x) > 163.0 or absf(z) > 163.0: beyond += 1
				queue.append(n)
		t.eq(beyond, 0, "no way out past the backdrop at the city's edge")
		for k in Data.layout.nav_nodes:
			var p: Array = Data.layout.nav_nodes[k]
			var c := Vector2i(roundi(p[0] / step), roundi(p[1] / step))
			var near := false
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]: near = near or seen.has(c + Vector2i(dx, dz))
			t.ok(near, "%s can be reached on foot from the station" % k))

func test_build_sites_sit_where_their_requests_need_them():
	_on(func():
		var fb := Data.zone(P + "footbridge")
		for k in range(fb.minK, fb.maxK + 1):
			t.ok(not Heightfield.is_water(fb.minI + 0.5, k + 0.5) and not Heightfield.is_water(fb.maxI + 0.5, k + 0.5), "the footbridge's ends are on the quays (row %d)" % k)
			t.ok(Heightfield.is_water(-107.5, k + 0.5), "and the Naviglio runs between them (row %d)" % k)
		var crane := Data.zone(P + "crane")
		var flowing := 0
		for i in range(crane.minI, crane.maxI + 1):
			for k in range(crane.minK, crane.maxK + 1):
				if Heightfield.is_stream_cell(i, k): flowing += 1
		t.ok(flowing >= 6, "the crane's site reaches the flowing canal for a waterwheel (%d cells)" % flowing)
		var yard := Data.zone(P + "courtyard")
		t.ok(yard.minI >= -46 and yard.maxI < -30 and yard.minK >= 104 and yard.maxK < 120, "the courtyard site is inside the courtyard")
		for zn in Data.layout.zones:
			t.ok(zn.id.begins_with(P), "zone %s has the location's prefix" % zn.id)
			t.ok(absf(zn.minI) < 163 and absf(zn.maxI) < 163 and absf(zn.minK) < 163 and absf(zn.maxK) < 163, "%s is inside the city" % zn.id))

func test_ids_carry_the_location_prefix():
	_on(func():
		for b in Data.layout.buildings: t.ok(String(b.id).begins_with(P), "building %s" % b.id)
		for f in Data.layout.features: t.ok(String(f.id).begins_with(P), "feature %s" % f.id)
		for k in Data.layout.nav_nodes:
			if not String(k).contains(":"): t.ok(String(k).begins_with(P), "nav spot %s" % k)
		t.eq(Data.island_def("metropolis").get("reveal", ""), "rice_village_trainStops", "the map entry opens when the regional train stops at the rice village again"))
