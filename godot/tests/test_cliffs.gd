extends RefCounted
var t

const ID := "cliffs"
const C := preload("res://scripts/locations/cliffs.gd")
const G := preload("res://scripts/locations/cliffs/ground_data.gd")

const TERRACE_TOP := -26.0
const TERRACE_DEPTH := 4.0

func _here(fn: Callable) -> void:
	Data.use_island(ID)
	fn.call()
	Data.use_island("hearthglow")

func _world() -> WalkWorld:
	return WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return false)

func _stand(w: WalkWorld, x: float, z: float) -> bool:
	return not w.can_stand(x, z, Heightfield.height(x, z), 0.3).is_empty()

func _level(n: int) -> float: return 10.0 + 2.0 * n

func _z_mid(n: int) -> float: return TERRACE_TOP - TERRACE_DEPTH * (n - 1) - 2.0

func _blocked_cells() -> Dictionary:
	var out := {}
	var r := WalkWorld.PLAYER_RADIUS
	for s in WorldStatics.build_statics(WorldStatics.generate_decor()):
		var x0: float; var x1: float; var z0: float; var z1: float
		if s.type == "circle":
			x0 = s.x - s.r - r; x1 = s.x + s.r + r; z0 = s.z - s.r - r; z1 = s.z + s.r + r
		else:
			x0 = s.minX - r; x1 = s.maxX + r; z0 = s.minZ - r; z1 = s.maxZ + r
		for i in range(int(floorf(x0)) - 1, int(ceilf(x1)) + 1):
			for k in range(int(floorf(z0)) - 1, int(ceilf(z1)) + 1):
				var cx := i + 0.5; var cz := k + 0.5
				var hit := false
				if s.type == "circle": hit = Vector2(cx - s.x, cz - s.z).length() < s.r + r
				else: hit = cx > x0 and cx < x1 and cz > z0 and cz < z1
				if hit: out[Vector2i(i, k)] = true
	return out

func _walk(a: Vector2, b: Vector2) -> bool:
	var y := Heightfield.height(a.x, a.y)
	for s in range(1, 5):
		var p := a.lerp(b, s / 4.0)
		var h := Heightfield.height(p.x, p.y)
		if h < Heightfield.WALKABLE_MIN or h - y > WalkWorld.STEP_UP: return false
		y = h
	return true

func _reach(from: Vector2) -> Dictionary:
	var blocked := _blocked_cells()
	var start := Vector2i(int(floorf(from.x)), int(floorf(from.y)))
	var seen := {start: true}
	var queue: Array = [start]
	var head := 0
	var half := int(Data.map_size() / 2.0) - 1
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or blocked.has(n) or absi(n.x) > half or absi(n.y) > half: continue
			if _walk(Vector2(c.x + 0.5, c.y + 0.5), Vector2(n.x + 0.5, n.y + 0.5)):
				seen[n] = true
				queue.append(n)
	return seen

func _cell(x: float, z: float) -> Vector2i: return Vector2i(int(floorf(x)), int(floorf(z)))

func test_it_is_a_location_pack():
	t.ok(Data.location_ids().has(ID), "Serenza is a location pack")
	var isl := Data.island_def(ID)
	t.eq(isl.get("name", ""), "Serenza", "its map entry is named")
	t.eq(isl.get("reveal", ""), "port_lighthouse_lit", "Tonnarella's finale reveals it")
	t.ok(not Travel.on_map(isl, {}, "hearthglow"), "it stays off the travel map until then")
	t.ok(Travel.on_map(isl, {"port_lighthouse_lit": true}, "hearthglow"), "and shows once the lighthouse is lit")
	t.ok(Travel.on_map(isl, {}, ID), "and always while you're there")
	t.eq(isl.get("bikes", true), false, "it's all steps: no bicycles")
	t.eq(isl.get("day", {}).get("hold", true), false, "the clock never holds at dusk")
	var weather: Array = isl.get("look", {}).get("weather", [])
	for w in ["clear", "drizzle", "mist"]: t.ok(weather.has(w), "%s weather can come" % w)
	for w in ["rain", "snow", "cloudy"]: t.ok(not weather.has(w), "no %s in Serenza's spring" % w)

func test_you_arrive_on_the_platform():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		t.ok(_stand(w, sp.x, sp.z), "you step off the train onto the platform")
		t.eq(C.kind_at(sp.x, sp.z), int(G.KINDS.platform), "the spawn is on the platform")
		t.eq(Data.layout.get("arrive", {}), Data.layout.spawn, "arriving later puts you on the same platform")
		var first: Array = Data.layout.features.filter(func(f): return f.kind == "boat" and not f.has("flag"))
		t.eq(first.size(), 1, "one departure point from the start")
		t.eq(first[0].get("depart_label", ""), "Take the train", "it's the train")
		t.ok(Vector2(first[0].x - sp.x, first[0].z - sp.z).length() < 2.0, "where you arrive")
		var later: Array = Data.layout.features.filter(func(f): return f.kind == "boat" and f.has("flag"))
		t.eq(later.size(), 1, "and one more after the finale")
		t.eq(later[0].flag, "olive_village_revealed", "the ferry waits for the finale")
		t.eq(later[0].get("depart_label", ""), "Take the ferry", "it's the ferry")
		t.eq(C.kind_at(later[0].x, later[0].z), int(G.KINDS.quay), "at the landing on the breakwater")
		t.ok(_stand(w, later[0].x, later[0].z), "which you can stand on"))

func test_you_can_walk_everywhere_the_village_needs():
	_here(func():
		var sp: Dictionary = Data.layout.spawn
		var seen := _reach(Vector2(sp.x, sp.z))
		var places := {"the harbour square": Vector2(0, 26), "Nunzia's door": Vector2(-7.3, 24.5), "the church rocks": Vector2(18, 37),
			"the breakwater": Vector2(5, 46.5), "the ferry landing": Vector2(-7.5, 46.5), "the beach": Vector2(-20, 33),
			"the belvedere": Vector2(19.5, 12.8), "the main street": Vector2(0, 10), "under the arch": Vector2(0, -8),
			"the cellar square": Vector2(0, -21), "the top of the terraces": Vector2(0, -60), "the sanctuary": Vector2(-52, -53),
			"the mule path above the gully": Vector2(-48.5, -45), "the gully": Vector2(-50, -37), "the slip": Vector2(15, -46)}
		for name in places:
			var p: Vector2 = places[name]
			t.ok(seen.has(_cell(p.x, p.y)), "you can walk to %s" % name)
		for n in range(1, 9):
			var z := _z_mid(n)
			t.ok(seen.has(_cell(-25.5, z)), "you can walk onto terrace W%d" % n)
			t.ok(seen.has(_cell(8.5, z)), "and onto E%d by the stair" % n)
			t.ok(seen.has(_cell(30.5, z)), "and along E%d past the monorail" % n)
		var off := {"the railway": Vector2(-20, -8.25), "the cliff above the houses": Vector2(40, 0), "the ridge": Vector2(-56, -20)}
		for name in off:
			var p: Vector2 = off[name]
			t.ok(not seen.has(_cell(p.x, p.y)), "you can't walk onto %s" % name))

func test_walls_you_cant_climb():
	_here(func():
		for n in range(2, 9):
			var lo := _z_mid(n - 1)
			var hi := _z_mid(n)
			t.ok(Heightfield.height(-40.5, hi) - Heightfield.height(-40.5, lo) > 1.9, "terrace W%d stands 2 m above W%d" % [n, n - 1])
			t.ok(not _walk(Vector2(-40.5, TERRACE_TOP - TERRACE_DEPTH * (n - 1) + 0.6), Vector2(-40.5, TERRACE_TOP - TERRACE_DEPTH * (n - 1) - 0.6)), "and its wall can't be climbed")
		t.ok(not _walk(Vector2(-48.5, -37.5), Vector2(-48.5, -39.6)), "from the gully you can't climb up to the mule path's north side")
		t.ok(_walk(Vector2(-48.5, -34.6), Vector2(-48.5, -35.6)), "but you can walk down into it from the south side")
		t.ok(Heightfield.height(-48.5, -39.6) - Heightfield.height(-48.5, -37.5) > 2.0, "the gully needs steps and a bridge")
		t.ok(not _walk(Vector2(15, -48.6), Vector2(15, -49.6)), "from the slip you can't climb to the monorail's path above")
		t.ok(Heightfield.height(15, -49.5) - Heightfield.height(15, -46) > 2.0, "the slip needs a way up")
		t.ok(not _stand(_world(), -12, -8.25), "the railway's ledge is no place to walk")
		t.ok(Heightfield.height(0, -8.25) < 5.0, "the main street runs under the railway arch"))

func test_sixteen_terraces():
	_here(func():
		for n in range(1, 9):
			var z := _z_mid(n)
			for x in [-25.5, 8.5, 30.5]:
				t.ok(absf(Heightfield.height(x, z) - _level(n)) < 0.01, "terrace %d at x %.1f is level at %.0f m" % [n, x, _level(n)])
		t.eq(C.kind_at(-25.5, _z_mid(1)), int(G.KINDS.tended), "W1, Settimio's lemons, is tended")
		t.eq(C.kind_at(30.5, _z_mid(2)), int(G.KINDS.tended), "E2, Settimio's vines, is tended")
		var wild := 0
		for n in range(1, 9):
			for x in [-25.5, 30.5]:
				if C.kind_at(x, _z_mid(n)) == int(G.KINDS.wild): wild += 1
		t.eq(wild, 14, "the other fourteen have gone back to bramble")
		var breaches := 0
		for a in G.AREAS:
			if int(a[8]) == int(G.KINDS.breach): breaches += 1
		t.eq(breaches, 7, "seven walls have fallen: W4's and the six terraces you bring back yourself")
		t.ok(absf(Heightfield.height(0, -60) - 27.0) < 0.01, "the stair tops out among the pines")
		t.ok(absf(Heightfield.height(-52, -53) - 29.5) < 0.01, "and the sanctuary stands above it"))

func test_water_where_the_design_puts_it():
	_here(func():
		for p in [Vector2(5, 36), Vector2(-8, 40), Vector2(0, 55), Vector2(-50, 50), Vector2(50, 50)]:
			t.ok(Heightfield.is_water(p.x, p.y), "water at %s" % str(p))
		for p in [Vector2(0, 26), Vector2(5, 46.5), Vector2(-20, 32), Vector2(22, 30)]:
			t.ok(not Heightfield.is_water(p.x, p.y), "dry land at %s" % str(p))
		t.ok(Heightfield.is_water(5, 44) and Heightfield.is_water(5, 49), "the breakwater has the harbour on one side and the sea on the other")
		t.ok(not Heightfield.is_water(-20, 30) and Heightfield.is_water(-20, 45), "the beach runs down into the sea")
		for k in range(31, 35):
			t.ok(Heightfield.is_water(-0.5, k + 0.5), "the old slipway is broken: water at z %d" % k)
		for n in Data.layout.nodes:
			if n.kind == "fish": t.ok(Heightfield.is_water(n.x, n.z), "%s is in the water" % n.id))

func test_build_sites():
	_here(func():
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		for id in ["cliffs_hut", "cliffs_plot", "cliffs_wall"]:
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
		t.eq(Data.zone("cliffs_plot").get("unlock", {}).get("flag", ""), "cliffs_homePlot", "your terrace opens with the hut")
		for id in ["cliffs_slip", "cliffs_gully"]:
			var zn := Data.zone(id)
			var a: Dictionary = zn.endpoints.a; var b: Dictionary = zn.endpoints.b
			var ya := Heightfield.height(a.minI + 0.5, a.minK + 0.5)
			var yb := Heightfield.height(b.minI + 0.5, b.minK + 0.5)
			t.ok(C.walkable_area(a.minI + 0.5, a.minK + 0.5) and C.walkable_area(b.maxI + 0.5, b.maxK + 0.5), "%s's ends are on the path" % id)
			t.ok(yb - ya > 1.5, "%s climbs from one end to the other (%.1f m)" % [id, yb - ya])
		for id in ["cliffs_slipway", "cliffs_swim"]:
			var zn := Data.zone(id)
			var a: Dictionary = zn.endpoints.a; var b: Dictionary = zn.endpoints.b
			t.ok(not Heightfield.is_water(a.minI + 0.5, a.minK + 0.5), "%s starts on dry land" % id)
			t.ok(Heightfield.is_water(b.minI + 0.5, b.minK + 0.5), "%s ends in the water" % id)
		var terraces: Array = Data.layout.zones.filter(func(z): return String(z.id).begins_with("cliffs_terrace_"))
		t.eq(terraces.size(), 13, "every abandoned terrace but your own is an open build site")
		for zn in terraces:
			t.ok(not zn.has("unlock"), "%s is open from the start" % zn.id)
			var off := 0
			for i in range(int(zn.minI), int(zn.maxI) + 1):
				for k in range(int(zn.minK), int(zn.maxK) + 1):
					if Heightfield.is_water(i + 0.5, k + 0.5) or not C.walkable_area(i + 0.5, k + 0.5): off += 1
			t.eq(off, 0, "%s lies on the terrace" % zn.id))

func test_every_nav_spot_can_be_walked_to():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		var start := Schedule.nearest_node(sp.x, sp.z, {})
		t.eq(start, "platform", "the walk starts on the platform")
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path(start, k, {}).is_empty(), "the nav graph reaches %s" % k)
		for e in Data.layout.nav_edges:
			if e.size() > 2: continue
			var a: Array = Data.layout.nav_nodes[e[0]]; var b: Array = Data.layout.nav_nodes[e[1]]
			var open := true; var on_foot := true
			for s in 41:
				var x: float = lerpf(a[0], b[0], s / 40.0); var z: float = lerpf(a[1], b[1], s / 40.0)
				if not _stand(w, x, z) or not C.walkable_area(x, z): open = false
			var pa := Vector2(a[0], a[1]); var pb := Vector2(b[0], b[1])
			var steps := int(ceilf(pa.distance_to(pb) / 0.5))
			for s in steps:
				var p := pa.lerp(pb, float(s) / steps); var q := pa.lerp(pb, float(s + 1) / steps)
				if not _walk(p, q) or not _walk(q, p): on_foot = false
			t.ok(open, "the way from %s to %s is open ground" % [e[0], e[1]])
			t.ok(on_foot, "and has no wall to climb or drop down (%s to %s)" % [e[0], e[1]])
		var gated: Array = Data.layout.nav_edges.filter(func(e): return e.size() > 2)
		t.eq(gated.map(func(e): return e[2]), ["cliffs_monorailRuns", "cliffs_sanctuaryPath"], "the slip and the gully wait for their requests"))

func test_the_ground_is_painted():
	_here(func():
		t.ok(Heightfield.has_paint(), "Serenza paints its own ground")
		t.eq(Heightfield.meadow(0, 26), 0.0, "the harbour square is paved")
		t.eq(Heightfield.meadow(0, 10), 0.0, "and so is the main street")
		t.eq(Heightfield.meadow(-25.5, _z_mid(1)), 0.0, "Settimio's terraces are tended")
		t.ok(Heightfield.meadow(-25.5, _z_mid(5)) > 0.0, "the abandoned ones are going back to green")
		var decor := WorldStatics.generate_decor()
		t.ok(decor.trees.all(func(tr): return not C.walkable_area(tr.x, tr.z)), "no trees on the lanes and terraces")
		t.ok(decor.trees.size() > 10, "scrub and pines on the cliffs (%d)" % decor.trees.size()))

func test_ids_and_models():
	_here(func():
		for kind in ["buildings", "zones", "nodes", "features"]:
			for e in Data.layout[kind]: t.ok(String(e.id).begins_with(ID + "_"), "%s %s starts with %s_" % [kind, e.id, ID])
		var pack := Data.location_script(ID)
		var fns: Array = pack.get_script_method_list().map(func(m): return m.name)
		for b in Data.layout.buildings:
			var model: Node3D = Village.building_model(b, pack, fns)
			t.ok(model != null and model.get_child_count() > 0, "%s has a model" % b.id)
			if model: model.free())

func test_the_village_builds():
	_here(func():
		var v := Village.new()
		v.build(WorldStatics.generate_decor())
		for b in Data.layout.buildings:
			t.ok(v.objects.has(b.id), "%s is built" % b.id)
		t.ok(absf(v.objects.cliffs_arch.position.y - 7.8) < 0.01, "the arch carries the railway over the main street")
		t.ok(absf(v.objects.cliffs_track_w.position.y - 9.0) < 0.01, "on its ledge above the houses")
		v.free())
