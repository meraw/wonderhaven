extends RefCounted
var t

const ID := "cliffs"
const C := preload("res://scripts/locations/cliffs.gd")
const G := preload("res://scripts/locations/cliffs/ground_data.gd")
const AudioDirector := preload("res://scripts/audio/audio_director.gd")

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
			var z := _z_mid(n) - 1.5
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
		t.ok(Heightfield.height(15, -49.5) - Heightfield.height(15, -46) > 1.9, "the slip needs a way up")
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
			if n.kind == "fish":
				var f := float(n.get("facing", PI))
				t.ok(not Heightfield.is_water(n.x, n.z) and Heightfield.is_water(n.x + sin(f) * 3.0, n.z + cos(f) * 3.0), "%s stands on the edge with water in front" % n.id))

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
		var sc: Node = v.get_node_or_null("cliffs_scenery")
		t.ok(sc != null, "Serenza's scenery is dressed")
		if sc:
			var stones := 0
			for mm in sc.get_node("dry_stone_walls").find_children("*", "MultiMeshInstance3D", true, false): stones += (mm as MultiMeshInstance3D).multimesh.instance_count
			t.ok(stones > 5000, "dry-stone walls hold the terraces up (%d stones)" % stones)
			for part in ["steps", "monorail", "plants", "station_canopy", "rubble", "far_coast", "next_villages"]:
				t.ok(sc.get_node_or_null(part) != null, "the scenery has its %s" % part)
			for pr in Data.layout.props:
				if String(pr.kind).begins_with(ID + "_"): t.ok(sc.get_node_or_null("%s_model" % pr.id) != null, "%s is drawn" % pr.id)
				else: t.ok(v.objects.has(pr.id), "%s stands in the village" % pr.id)
		t.ok(v.get_node_or_null("cliffs_trains") != null, "the trains run")
		for part in ["cliffs_animals", "cliffs_sounds", "cliffs_hikers"]:
			t.ok(v.get_node_or_null(part) != null, "Serenza has its %s" % part)
		t.ok(v.window_mats.size() >= 10, "windows light up at night, the far coast's too (%d)" % v.window_mats.size())
		t.ok(v.valley_fog != null, "sea fog can fill the ravine")
		v.free())

func test_rooms_you_can_walk_into():
	_here(func():
		var rooms: Array = Data.layout.buildings.filter(func(b): return Interiors.enterable(b)).map(func(b): return b.id)
		t.eq(rooms, ["cliffs_bar", "cliffs_station", "cliffs_church", "cliffs_cellar", "cliffs_workshop", "cliffs_sanctuary"],
			"Nunzia's bar, the waiting room, the church, the cellar, Trenin's workshop and the sanctuary chapel")
		var start := Schedule.nearest_node(Data.layout.spawn.x, Data.layout.spawn.z, {})
		var pack := Data.location_script(ID)
		var fns: Array = pack.get_script_method_list().map(func(m): return m.name)
		for id in rooms:
			t.ok(not Schedule.find_path(start, id + ":spot", {}).is_empty(), "you can walk into %s" % id)
			var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == id)[0]
			var o: Node3D = Village.building_model(b, pack, fns)
			t.ok(o.get_meta("fade_parts", []).size() > 0, "%s's roof fades while you're inside" % id)
			o.free()
		var hut := Data.zone("cliffs_hut")
		var ruins: Array = Data.layout.props.filter(func(p): return String(p.kind) == "cliffs_ruin")
		var west := ruins.any(func(p): return float(p.x) < float(hut.minI) and float(p.x) > float(hut.minI) - 0.6)
		var east := ruins.any(func(p): return float(p.x) > float(hut.maxI) + 1.0)
		t.ok(not hut.is_empty() and west and east, "the hut is a roofless ruin, its build site inside its tumbled walls")
		t.ok(Data.layout.features.any(func(f): return f.kind == "wardrobe" and f.get("flag", "") == "cliffs_hutHome"), "with a wardrobe that's yours once the hut is"))

func test_slate_roofs():
	_here(func():
		t.eq(Data.layout.houseStyle.get("roofTiles", ""), "slate", "Serenza asks the house kit for slate")
		var pack := Data.location_script(ID)
		var fns: Array = pack.get_script_method_list().map(func(m): return m.name)
		for b in Data.layout.buildings.filter(func(x): return HouseKit.uses(x)):
			var o: Node3D = Village.building_model(b, pack, fns)
			var slates := 0
			var coppi := 0
			for mm in o.find_children("*", "MultiMeshInstance3D", true, false):
				var m := mm as MultiMeshInstance3D
				if not (m.material_override is ShaderMaterial): continue
				if m.multimesh.mesh == HouseKit.unit_box(): slates += m.multimesh.instance_count
				else: coppi += m.multimesh.instance_count
			t.ok(slates > 80 and coppi == 0, "%s has a slate roof (%d slates, %d coppi)" % [b.id, slates, coppi])
			t.ok(o.find_children("painted_frames", "MultiMeshInstance3D", true, false).size() > 0, "%s has painted window surrounds" % b.id)
			o.free())

func test_the_trains():
	var T := preload("res://scripts/locations/cliffs/trains.gd")
	var deps := T.departures()
	t.eq(float(deps[0].at), 310.0, "the first train at 5:10")
	t.ok(deps.all(func(d): return int(d.at) % 20 == 10), "then every twenty minutes")
	t.ok(T.standing(8 * 60 + 10.5), "the morning regional stands at the platform at 8:10, Sturlese's train")
	t.ok(T.standing(18 * 60 + 10.5), "and the evening one at 18:10")
	t.ok(T.active(3 * 60.0).is_empty(), "no trains in the small hours")
	for d in deps:
		var before := T.centre_x(d, float(d.at) - 6.0)
		var after := T.centre_x(d, float(d.at) + 6.0)
		t.ok((after - before) * float(d.dir) > 100.0, "train %d runs right through, one way" % d.n)
		if d.stops:
			t.ok(absf(T.centre_x(d, float(d.at) + 0.7) - T.STOP_X) < 0.01, "regional %d waits at the platform" % d.n)
		else:
			t.ok(not T.standing(float(d.at)), "the fast train %d doesn't stop" % d.n)
	for m in range(300, 1440, 3):
		var a := T.active(float(m))
		if a.is_empty(): continue
		t.ok(absf(float(a.x)) - T.length_of(a.dep) / 2.0 < T.SHOW, "a train is only drawn between the tunnels")

func test_the_boats_leave_the_street_open():
	_here(func():
		var boats: Array = Data.layout.props.filter(func(p): return p.kind == "cliffs_boat")
		t.eq(boats.size(), 4, "four boats winter in the main street")
		for b in boats:
			t.ok(absf(float(b.x)) - float(b.w) / 2.0 > 1.4, "%s is pulled up at the side of the street" % b.id)
			t.ok(C.kind_at(b.x, b.z) == int(G.KINDS.street), "%s is on the main street" % b.id))

func _quest(qid: String) -> Dictionary: return Data.quest(qid)

func _step(qid: String, oid: String) -> Dictionary:
	for o in _quest(qid).objectives:
		if o.id == oid: return o
	return {}

func _put(list: Array, id: String, i: int, k: int, r: int = 0) -> Dictionary:
	var pl := {"uid": 2000 + list.size(), "id": id, "i": float(i), "k": float(k), "r": r, "y": 0.0}
	pl.y = BuildGrid.suggest_bottom(id, i, k, r, BuildGrid.ground_at(i, k) + 10.0, list, {})
	list.append(pl)
	return pl

func _build_plan(qid: String, o: Dictionary, placements: Array, here: Array) -> bool:
	var zone := Data.zone(String(o.get("zone", "")))
	for pl in Plans.lay_out(o.plan, zone, placements):
		var y := BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, int(pl.r), BuildGrid.ground_at(pl.i, pl.k) + 10.0, placements, zone)
		if absf(y - float(pl.y)) > 0.01:
			t.ok(false, "%s: the ghost %s at (%d, %d) sits at %.2f, but builds at %.2f" % [qid, pl.id, pl.i, pl.k, pl.y, y])
			return false
		pl.uid = 1000 + placements.size()
		var v := BuildGrid.validate_placement(pl, {"placements": placements, "zones": Data.layout.zones, "statics": here, "bodies": [], "flags": {}})
		if not v.ok:
			t.ok(false, "%s: %s at (%d, %d) turned %d can't be built: %s" % [qid, pl.id, pl.i, pl.k, pl.r, v.reason])
			return false
		placements.append(pl)
	return true

func _brief(o: Dictionary, placements: Array, here: Array) -> Dictionary:
	var path := func(zone_id: String, only: Dictionary = {}) -> Dictionary:
		var w := WalkWorld.new(here, func(_f): return false)
		w.floors = WorldStatics.floors()
		w.surfaces = BuildGrid.surfaces_for(placements)
		return Validate.path_across(Data.zone(zone_id), w, only)
	var m := Mechanics.solve(placements, Data.layout.get("machines", []))
	return Commission.evaluate(o, {"placements": placements, "lamps": m.lamps, "fed": m.fed, "mech": m, "path": path})

func test_the_cast():
	_here(func():
		var cast: Array = Data.npcs.filter(func(n): return n.get("island", "") == ID)
		t.eq(cast.map(func(n): return n.id), ["cliffs_marta", "cliffs_settimio", "cliffs_mario", "cliffs_aurelio", "cliffs_giacomo", "cliffs_nunzia", "cliffs_fulvio"], "seven villagers")
		var nav: Dictionary = Data.layout.nav_nodes
		for n in cast:
			t.ok(String(n.get("pronoun", "")) != "", "%s has a pronoun" % n.name)
			t.ok(nav.has(String(n.home)), "%s goes home to a spot on the map" % n.name)
			var spots: Array = n.schedule.map(func(e): return String(e[2]))
			for w in n.get("when", []): spots.append_array(w.schedule.map(func(e): return String(e[2])))
			t.ok(spots.all(func(sp): return nav.has(sp)), "%s's day goes to real spots (%s)" % [n.name, ", ".join(spots.filter(func(sp): return not nav.has(sp)))])
			t.ok(n.greetings.size() >= 2 and n.topics.size() == 3 and not n.gifts.is_empty(), "%s has greetings, three topics and a gift" % n.name)
			t.ok(Data.tastes.tastes.has(n.id), "%s has tastes" % n.name)
			for item in n.likes: t.ok(Data.resources.has(item), "%s likes %s, which exists" % [n.name, item])
		var start := Schedule.nearest_node(Data.layout.spawn.x, Data.layout.spawn.z, {})
		for n in cast:
			for e in n.schedule: t.ok(not Schedule.find_path(start, String(e[2]), {}).is_empty(), "%s can walk to %s" % [n.name, e[2]])
		t.ok(Data.appearance.variants.has("cliffs_strawHat") and Data.appearance.locked.has("cliffs_captainCap"), "Serenza's clothes join the wardrobe, locked until earned"))

func test_the_requests():
	_here(func():
		var mine: Array = Data.quests.filter(func(q): return Data.quest_island(q.id) == ID)
		t.eq(mine.size(), 13, "thirteen requests")
		t.eq(mine.filter(func(q): return q.get("main", false)).size(), 6, "six of them the main story")
		for q in mine:
			for r in q.get("requires", {}).get("quests", []): t.ok(not Data.quest(r).is_empty(), "%s waits for %s, which exists" % [q.id, r])
			for c in q.rewards.get("clothes", []): t.ok(Data.appearance.variants.has(c), "%s gives %s, which exists" % [q.id, c])
			for o in q.objectives:
				if o.kind == "commission": t.ok(o.has("plan") and not o.plan.is_empty() and not Data.zone(String(o.zone)).is_empty(), "%s: \"%s\" has a site and a plan" % [q.id, o.text])
				if o.kind == "talk": t.ok(not Data.npc(String(o.npc)).is_empty(), "%s: talks to %s" % [q.id, o.npc])
				if o.kind == "gather": t.ok(Data.resources.has(String(o.item)), "%s: gathers %s" % [q.id, o.item])
		var easter := _quest("cliffs_easter")
		t.ok(easter.rewards.flags.has("olive_village_revealed"), "the finale opens the way to Liolivato")
		t.eq(easter.requires.quests, ["cliffs_welcome", "cliffs_hut", "cliffs_wall", "cliffs_monorail", "cliffs_path"], "and comes once the other five are done")
		var shops: Dictionary = Data.shops.shops
		for sid in shops:
			if not String(sid).begins_with("cliffs_"): continue
			for s in shops[sid].stock:
				if s.has("blueprint"): t.ok(not Data.piece(String(s.blueprint)).is_empty(), "%s sells the plan for %s" % [sid, s.blueprint])
				for k in s.get("items", {}): t.ok(Data.resources.has(k), "%s sells %s" % [sid, k])
		t.eq(shops.keys().filter(func(k): return String(k).begins_with("cliffs_")).size(), 4, "four shops"))

func test_every_brief_is_built_by_its_plan():
	_here(func():
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		for q in Data.quests.filter(func(x): return Data.quest_island(x.id) == ID):
			var placements: Array = []
			var cost := {}
			for o in q.objectives.filter(func(x): return x.kind == "commission"):
				t.ok(not _brief(o, [], here).done, "%s: \"%s\" isn't done before anything is built" % [q.id, o.text])
				for e in o.plan:
					var c: Dictionary = Data.piece(String(e[2])).get("cost", {})
					for k in c: cost[k] = int(cost.get(k, 0)) + int(c[k])
					t.ok(not c.has("cliffs_lemon_sapling"), "%s: no plan needs a lemon sapling before the lemon tree's milestone" % q.id)
				if not _build_plan(q.id, o, placements, here): continue
				var r := _brief(o, placements, here)
				t.ok(r.done, "%s: building its plan finishes \"%s\" (%s)" % [q.id, o.text, ", ".join(r.musts.filter(func(m): return not m.ok).map(func(m): return m.label))])
			var have := {}
			for g in q.objectives.filter(func(x): return x.kind == "gather"): have[g.item] = int(have.get(g.item, 0)) + int(g.count)
			for k in q.get("onAccept", {}).get("items", {}): have[k] = int(have.get(k, 0)) + int(q.onAccept.items[k])
			for k in cost:
				if k in ["wood", "stone", "clay", "metal", "cliffs_vine"]: t.ok(int(have.get(k, 0)) >= int(cost[k]), "%s: what it gives and has you gather pays for the %d %s its plans take" % [q.id, cost[k], k]))

func test_the_wall_and_the_steps_are_real():
	_here(func():
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		var wall := _step("cliffs_wall", "wall")
		var one: Array = []
		for i in range(-30, -25): _put(one, "drystoneWall", i, -39)
		var r := _brief(wall, one, here)
		t.ok(r.musts[0].ok and not r.musts[1].ok, "one course on the ramp closes the gap but isn't 1.8 m tall")
		var gap: Array = []
		for i in range(-30, -26): _put(gap, "drystoneWall", i, -38)
		for i in range(-30, -26): _put(gap, "drystoneWall", i, -38)
		t.ok(not _brief(wall, gap, here).musts[0].ok, "a wall with a gap in it doesn't close it")
		var w := WalkWorld.new(here, func(_f): return false)
		w.floors = WorldStatics.floors()
		for zid in ["cliffs_slip", "cliffs_gully", "cliffs_swim", "cliffs_slipway"]:
			t.ok(not Validate.path_across(Data.zone(zid), w).ok, "%s can't be crossed before you build" % zid))

func test_terraces_come_back_on_the_meter():
	_here(func():
		var s := GameState.new_game()
		var ids := func() -> Array: return C.meter_things(s).map(func(x): return String(x.flag))
		t.eq(ids.call(), [], "nothing on the hill counts at first")
		var pls: Array = []
		s.placements = pls
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		_build_plan("cliffs_wall", _step("cliffs_wall", "wall"), pls, here)
		t.eq(ids.call(), [], "a wall alone brings nothing back: something has to grow")
		_put(pls, "vinePergola", -20, -36)
		t.eq(ids.call(), ["cliffs_terrace_w3"], "the wall mended and a vine on W3: W3 is back")
		_put(pls, "hedge", -20, -40)
		t.eq(ids.call(), ["cliffs_terrace_w3", "cliffs_terrace_w4"], "and a hedge on W4 brings W4 back")
		_put(pls, "flowerBed", -30, -44)
		t.eq(ids.call().size(), 2, "green on W5 doesn't count while its wall is breached")
		for i in range(-20, -16): _put(pls, "drystoneWall", i, -43)
		t.ok(ids.call().has("cliffs_terrace_w5"), "mend W5's wall too, and it comes back")
		_put(pls, "vinePergola", 30, -41)
		t.ok(ids.call().has("cliffs_terrace_e4"), "E4 comes back with something green on it")
		s.flags["cliffs_monorailRuns"] = true
		s.flags["cliffs_sanctuaryPath"] = true
		t.ok(ids.call().has("cliffs_terrace_e5") and ids.call().has("cliffs_terrace_e6") and ids.call().has("cliffs_terrace_w7"), "the monorail brings E5 and E6 back, the sanctuary path W7")
		t.eq(LocationMeter.new_things(s, C.meter_things(s)).size(), ids.call().size(), "each counts once")
		for f in ids.call(): s.flags[f] = true
		t.eq(LocationMeter.new_things(s, C.meter_things(s)), [], "and never again")
		pls.clear()
		t.eq(C.Terraces.in_use(s), 9, "taking the planting away doesn't take a terrace back")
		var m := LocationMeter.def(ID)
		t.eq(LocationMeter.reading(m, 0), "2 of 16 terraces", "the meter starts at the two Settimio tends")
		t.eq(LocationMeter.reading(m, 14), "16 of 16 terraces", "and ends at sixteen")
		t.eq(m.milestones.map(func(u): return int(u.at)), [2, 4, 6, 8, 11, 14], "milestones at four, six, eight, ten, thirteen and sixteen terraces")
		t.eq(int(_step("cliffs_easter", "terraces").value), 8, "the finale needs ten terraces in use"))

func test_the_place_changes_with_the_story():
	_here(func():
		t.eq(Data.world_flags_of(ID, {"cliffs_boats_launched": true, "cliffs_welcomed": true}), {"cliffs_boats_launched": true}, "the boats' launch reshapes the harbour")
		var lay: Dictionary = Data.read_layout(ID)
		C.adjust(lay, {"cliffs_boats_launched": true})
		var boats: Array = lay.props.filter(func(p): return String(p.kind) == "cliffs_boat")
		t.ok(boats.all(func(p): return p.get("afloat", false) and Heightfield.height(p.x, p.z) < Heightfield.WATER_Y), "launched, the boats ride at their moorings in the harbour")
		t.ok(Data.layout.nav_edges.any(func(e): return e.size() > 2 and e[2] == "cliffs_monorailRuns"), "the path beside the monorail opens when it runs")
		t.ok(Data.layout.nav_edges.any(func(e): return e.size() > 2 and e[2] == "cliffs_sanctuaryPath"), "the mule path opens when the gully is bridged")
		var root := Node3D.new()
		var before: Dictionary = Data.world_flags
		Data.world_flags = {"cliffs_plaque": true}
		C.Scenery.plaque(root)
		var plaque: Node3D = root.get_node_or_null("cliffs_plaque")
		var cellar: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "cliffs_cellar")[0]
		t.ok(plaque != null and plaque.position.z > float(cellar.z) + float(cellar.d) / 2.0 + 0.1, "at sixteen terraces a slate plaque goes up outside the cellar door")
		Data.world_flags = before
		root.free()
		var ferry: Dictionary = Data.layout.features.filter(func(f): return f.id == "cliffs_ferry")[0]
		t.eq(ferry.get("flag", ""), "olive_village_revealed", "the ferry calls once the finale's done"))

func test_paper_naps_and_openings():
	_here(func():
		var naps := Data.naps_here()
		t.eq(naps.paper, "Il Gabbiano", "you wake under Il Gabbiano")
		t.ok(naps.gags.has("train") and naps.gags.has("sturlese") and naps.gags.has("stared"), "with the dawn train's horn and Sturlese at the other end of the bench")
		t.eq(Data.layout.inauguration.speaker, "cliffs_marta", "Marta opens what you build")
		var w := _world()
		for h in Data.layout.hangouts: t.ok(_stand(w, float(h.x), float(h.z)), "%s is somewhere you can stand" % h.name)
		var fish: Array = Data.layout.fish
		t.ok(fish.any(func(f): return f.get("item", "") == "cliffs_bream") and fish.any(func(f): return f.get("item", "") == "cliffs_mullet"), "sea bream and grey mullet bite in the harbour"))

func test_build_sites_leave_the_routes_open():
	_here(func():
		for zid in ["cliffs_tables", "cliffs_shelter", "cliffs_slipway", "cliffs_swim", "cliffs_hut", "cliffs_wall"]:
			var z := Data.zone(zid)
			var crossed: Array = []
			for e in Data.layout.nav_edges:
				var a: Array = Data.layout.nav_nodes[e[0]]
				var b: Array = Data.layout.nav_nodes[e[1]]
				var n := maxi(1, int(Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) / 0.25))
				for s in n + 1:
					var p := Vector2(a[0], a[1]).lerp(Vector2(b[0], b[1]), float(s) / n)
					if p.x > float(z.minI) - 0.3 and p.x < float(z.maxI) + 1.3 and p.y > float(z.minK) - 0.3 and p.y < float(z.maxK) + 1.3:
						crossed.append("%s-%s" % [e[0], e[1]])
						break
			t.eq(crossed, [], "what you build at %s can't block a route villagers walk" % z.name))

func test_villagers_never_share_a_spot():
	_here(func():
		var cast: Array = Data.npcs.filter(func(n): return n.get("island", "") == ID)
		var story := ["cliffs_welcomed", "cliffs_wallBuilt", "cliffs_monorailRuns", "cliffs_cellarOpen", "cliffs_boats_launched",
			"cliffs_sanctuaryPath", "cliffs_shelterBuilt", "cliffs_swimDone", "cliffs_restBuilt", "cliffs_easterDone"]
		var day_of := func(n: Dictionary, flags: Dictionary) -> Array:
			for w in n.get("when", []):
				if flags.get(w.flag, false): return w.schedule
			return n.schedule
		for step in story.size() + 1:
			var flags := {}
			for f in story.slice(0, step): flags[f] = true
			var shared: Array = []
			for a in cast.size():
				for b in range(a + 1, cast.size()):
					for e in day_of.call(cast[a], flags):
						for f in day_of.call(cast[b], flags):
							if String(e[2]) == String(f[2]) and maxf(e[0], f[0]) < minf(e[1], f[1]): shared.append("%s and %s at %s" % [cast[a].id, cast[b].id, e[2]])
			t.eq(shared, [], "no two villagers stand on one spot (so you can always talk to the one you want), %s" % (story[step - 1] if step > 0 else "on arrival"))
		var after: Dictionary = {}
		for f in story: after[f] = true
		for n in cast: t.ok(day_of.call(n, after) != day_of.call(n, after.merged({"cliffs_easterDone": false}, true)) or not n.get("when", []).any(func(w): return w.flag == "cliffs_restBuilt"), "%s goes back to a normal day after Easter" % n.name))

func test_night_lights_and_sea_fog():
	_here(func():
		var lamps: Array = Data.layout.props.filter(func(p): return String(p.kind) == "lamp_post")
		t.ok(lamps.size() >= 12, "lamp posts along the main street, the stairs, the square and the harbour (%d)" % lamps.size())
		for l in lamps:
			t.ok(C.walkable_area(float(l.x), float(l.z)), "%s stands where people walk" % l.id)
			t.ok(Heightfield.height(float(l.x), float(l.z)) > Heightfield.WATER_Y, "%s is on dry land" % l.id)
		for h in Data.layout.hangouts:
			var lit: bool = lamps.any(func(l): return Vector2(float(l.x) - float(h.x), float(l.z) - float(h.z)).length() < float(h.r) + 2.0)
			if lit: t.ok(not h.needs.has("light"), "%s has a lamp post, so it doesn't ask you for light" % h.name)
		var fog: Dictionary = Data.layout.valley_fog
		t.ok(float(fog.y) > 8.0 and float(fog.y) < 11.0, "the sea fog fills the ravine up to the station")
		t.ok(float(fog.morning) > float(fog.evening) and float(fog.day) == 0.0, "thickest in the morning, gone by day")
		var look: Dictionary = Data.island_def(ID).get("look", {})
		t.ok(look.get("weather", []).has("mist") and float(look.get("mist", 0.0)) > 0.0, "some mornings the fog rolls in from the sea"))

func test_the_terraces_look_like_they_come_back():
	_here(func():
		var Scenery: Script = load("res://scripts/locations/cliffs/scenery.gd")
		var Life: Script = load("res://scripts/locations/cliffs/life.gd")
		var v := Node3D.new()
		var root := Node3D.new()
		v.add_child(root)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2002
		Scenery.plants(root, C, rng, {"cliffs_terrace_w3": true})
		var w3: Node3D = root.find_child("brambles_w3", true, false)
		var e1: Node3D = root.find_child("brambles_e1", true, false)
		t.ok(w3 != null and not w3.visible, "W3, planted and walled, has lost its brambles")
		t.ok(e1 != null and e1.visible and e1.get_child_count() > 0, "E1, still wild, keeps them")
		var life = Life.new()
		v.add_child(life)
		life.setup(null, v)
		life._on_event("flag", {"flag": "cliffs_terrace_w2", "value": true})
		t.ok(e1.visible, "another terrace coming back leaves E1's brambles")
		life._on_event("flag", {"flag": "cliffs_terrace_e1", "value": true})
		t.ok(not e1.visible, "and they go the moment E1 comes back")
		v.free())

func test_animals():
	_here(func():
		var A: Script = load("res://scripts/locations/cliffs/animals.gd")
		var T: Script = load("res://scripts/locations/cliffs/terraces.gd")
		t.ok(A.basking(12.0) and not A.basking(7.5) and not A.basking(19.0), "lizards bask on the walls from nine to six")
		t.ok(A.swallows_out(7.0) and not A.swallows_out(21.0), "swallows are out from six to eight")
		var mains: Array = Data.quests.filter(func(q): return String(q.id).begins_with(ID + "_") and q.get("main", false)).map(func(q): return String(q.id))
		mains.sort()
		var listed: Array = A.MAIN.duplicate()
		listed.sort()
		t.eq(listed, mains, "the swallows count Serenza's main requests")
		var arrived := {"flags": {}, "quests": {}}
		t.eq(A.in_use(arrived), ["w1", "e2"], "only W1 and E2 are tended when you arrive")
		var later := {"flags": {"cliffs_terrace_w3": true, "cliffs_terrace_e1": true}, "quests": {}}
		t.eq(A.in_use(later).size(), 4, "every terrace that comes back is in use")
		t.eq(A.swallow_count(arrived), 4, "a few swallows when you arrive")
		var all := {"quests": {}}
		for q in A.MAIN: all.quests[q] = {"status": "done"}
		t.eq(A.swallow_count(all), 16, "sixteen once every main request is done")
		var spots := {}
		for id in T.TENDED + T.ORDER:
			var list: Array = A.wall_spots(String(id))
			spots[id] = list.size()
			for s in list:
				var drop := Heightfield.height(s.x, s.z - 0.5) - Heightfield.height(s.x, s.z + 0.5)
				t.ok(drop >= 1.0, "a lizard on %s clings to a wall face (%.1f m)" % [id, drop])
		var at_first := 0
		var with_two := 0
		for id in spots:
			if A.in_use(arrived).has(id): at_first += int(spots[id])
			if A.in_use(later).has(id): with_two += int(spots[id])
		t.ok(at_first >= 2, "lizards on the tended terraces from the start (%d)" % at_first)
		t.ok(with_two > at_first, "more once terraces come back (%d)" % with_two)
		var seats: Array = A.gull_seats()
		t.ok(seats.size() >= 6, "gulls sit on the boats, the quay and the breakwater (%d)" % seats.size())
		for s in seats: t.ok(s.y > Heightfield.WATER_Y, "a gull's seat is above the water (%.1f)" % s.y)
		var v := Node3D.new()
		var an = A.new()
		v.add_child(an)
		an.build(v, later)
		t.eq(an.swallows.size(), 16, "sixteen swallows are ready")
		t.eq(an.gulls.size(), seats.size() + 3, "a gull on every seat and three wheeling over the sea")
		var walls := 0
		for id in spots: walls += int(spots[id])
		t.eq(an.lizards.size(), walls, "a lizard for every wall spot")
		v.free())

func test_sounds():
	_here(func():
		var S: Script = load("res://scripts/locations/cliffs/sounds.gd")
		var Trains: Script = load("res://scripts/locations/cliffs/trains.gd")
		var horns := 0
		var m := 290.0
		while m < 1410.0:
			if not S.horn_due(m, m + 0.05).is_empty(): horns += 1
			m += 0.05
		t.eq(horns, Trains.departures().size(), "every train sounds its horn once, coming out of the tunnel")
		t.ok(S.horn_due(600.0, 640.0).is_empty(), "no horn after a long jump in time")
		t.ok(S.sea_level(Vector3(0.0, 1.0, 30.0)) > 0.8, "the sea is loud on the quay")
		t.ok(S.sea_level(Vector3(0.0, 24.0, -59.5)) == 0.0, "and silent up on the top band")
		t.ok(S.gull_level(Vector3(2.0, 1.0, 40.0), 12.0) > 0.8 and S.gull_level(Vector3(2.0, 1.0, 40.0), 23.0) == 0.0, "gulls cry over the harbour by day")
		var easter := {"cliffs_restBuilt": true}
		t.ok(S.peal_due(easter, 434.0, 435.5), "on Easter morning the church peals every quarter hour")
		t.ok(not S.peal_due(easter, 436.0, 437.0), "between quarters it's quiet")
		t.ok(not S.peal_due(easter, 734.0, 735.5), "only in the morning")
		t.ok(not S.peal_due({"cliffs_restBuilt": true, "cliffs_easterDone": true}, 434.0, 435.5), "and only until the vote")
		t.ok(not S.peal_due({}, 434.0, 435.5), "not before the rest stop is built"))

func test_hikers_after_easter():
	_here(func():
		var H: Script = load("res://scripts/locations/cliffs/hikers.gd")
		var flags := {"cliffs_monorailRuns": true, "cliffs_sanctuaryPath": true, "cliffs_easterDone": true}
		var ids: Array = H.loop(flags)
		t.ok(ids.size() > 20, "the hikers' loop runs through the village (%d spots)" % ids.size())
		t.eq(ids[0], ids[ids.size() - 1], "and back to the platform")
		for r in H.ROUTE: t.ok(ids.has(r), "it passes %s" % r)
		var edges := {}
		for e in Data.layout.nav_edges:
			edges[String(e[0]) + ">" + String(e[1])] = true
			edges[String(e[1]) + ">" + String(e[0])] = true
		var linked := true
		for i in range(1, ids.size()): linked = linked and edges.has(String(ids[i - 1]) + ">" + String(ids[i]))
		t.ok(linked, "along the village's own paths")
		t.ok(H.loop({}).is_empty() or not H.loop({}).has("muleGullyS"), "the mule path is closed to them until it's mended")
		t.ok(H.shown(flags, 600.0) and not H.shown(flags, 1100.0) and not H.shown(flags, 420.0), "hikers walk from nine to five")
		t.ok(not H.shown({}, 600.0), "only once Easter has put Serenza back on the map")
		for i in H.COUNT:
			var a := Chibi.sanitize(H.appearance(i + 2))
			t.ok(a.top == "windbreaker" and a.accessory == "backpack" and a.shoes == "boots", "hiker %d wears an anorak, boots and a rucksack" % i))

func test_the_music():
	_here(func():
		var m: Dictionary = Data.island_def(ID).get("music", {})
		var songs: Dictionary = m.get("songs", {})
		for part in ["dawn", "morning", "afternoon", "evening", "night", "build"]:
			t.ok(songs.has(String(m.parts.get(part, ""))), "Serenza has its own tune for the %s" % part)
		for id in songs:
			var s: Dictionary = songs[id]
			var used: Array = [s.lead, s.get("pad_inst", "pad"), s.get("bass_inst", "pluck")]
			if String(s.arp) != "": used.append(s.arp)
			for k in used: t.ok(k in AudioDirector.INSTRUMENTS, "%s plays a real instrument (%s)" % [id, k])
			var last := -1
			var sorted := true
			for n in s.melody:
				sorted = sorted and int(n[0]) > last
				last = int(n[0])
			t.ok(sorted and last < AudioDirector.loop_steps(s), "%s's melody is in order and fits its loop" % id)
			var loudest := 0.0
			for st in AudioDirector.loop_steps(s):
				var sum := 0.0
				for e in AudioDirector.step_events(s, st): sum += float(e[2])
				loudest = maxf(loudest, sum)
			t.ok(loudest < 1.6, "%s never piles up too loud (%.2f)" % [id, loudest])
		t.eq(AudioDirector.song_for("morning", false, m, {}), "cliffs_morning", "a plain morning")
		t.eq(AudioDirector.song_for("morning", false, m, {"cliffs_restBuilt": true}), "cliffs_easter", "Easter's tune once the rest stop is built")
		t.eq(AudioDirector.song_for("evening", false, m, {"cliffs_restBuilt": true}), "cliffs_evening", "in the mornings only")
		t.eq(AudioDirector.song_for("morning", false, m, {"cliffs_restBuilt": true, "cliffs_easterDone": true}), "cliffs_morning", "and back after the vote")
		for w in m.get("when", []):
			var f := String(w.flag)
			var set_by := Data.quests.any(func(q): return JSON.stringify(q).contains("\"" + f + "\""))
			t.ok(set_by, "%s is set by a request" % f))

func test_the_cast_dresses_in_serenza():
	_here(func():
		var settimio: Dictionary = Data.npc("cliffs_settimio")
		var nunzia: Dictionary = Data.npc("cliffs_nunzia")
		t.eq(String(Chibi.sanitize(settimio.appearance).hat), "cliffs_strawHat", "Settimio wears his straw hat")
		t.eq(String(Chibi.sanitize(nunzia.appearance).shoes), "cliffs_espadrilles", "Nunzia her espadrilles")
		t.eq(String(Chibi.resolve(Chibi.sanitize(settimio.appearance)).hat), "sunhat", "drawn as a sun hat in straw"))
