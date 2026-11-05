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
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
	w.floors = WorldStatics.floors()
	return w

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
		t.ok(Heightfield.is_stream_cell(-157, 104) and Heightfield.is_water(-157, 104), "the west canal flows on under the old bridge")
		t.ok(absf(WorldStatics.floor_top(-157, 104) - 0.4) < 0.01, "whose stone deck carries the street over it"))

func test_the_old_bridge_and_the_quay_hold_you():
	_on(func():
		var w := _world()
		var pos := Vector3(-157, Heightfield.height(-157, 95), 95)
		for n in 100: pos = w.step_move(pos, 0.0, 0.2).pos
		t.ok(pos.z > 114.5, "you can walk over the old bridge to the bars' bank (reached z %.1f)" % pos.z)
		pos = Vector3(-116, 0.3, 86)
		for n in 60: pos = w.step_move(pos, 0.0, 0.2).pos
		t.ok(pos.z < 92.0 and not Heightfield.is_water(pos.x, pos.z), "walking at the Darsena stops at the quay (z %.2f)" % pos.z))

## Flood-fills the streets from the station in 1.5 m steps: nothing past the backdrop at the city's edge.
func test_the_edge_is_closed():
	_on(func():
		var w := _world()
		var step := 1.5
		var sp: Dictionary = Data.layout.spawn
		var start := Vector2i(roundi(sp.x / step), roundi(sp.z / step))
		var seen := {start: Heightfield.height(sp.x, sp.z)}   # cell -> the height you stand at there
		var queue: Array = [start]
		var beyond := 0
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for dvec in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dvec
				if seen.has(n): continue
				var x := n.x * step; var z := n.y * step
				if absf(x) > 186.0 or absf(z) > 186.0: beyond += 1; continue
				var s := w.can_stand(x, z, seen[c], 0.3)   # from the height of the cell you came from: over bridges, up stairs
				if s.is_empty(): continue
				seen[n] = s.y
				if absf(x) > 163.0 or absf(z) > 163.0: beyond += 1
				queue.append(n)
		t.eq(beyond, 0, "no way out past the backdrop at the city's edge")
		t.ok(seen.size() > 15000, "the streets are open (%d cells)" % seen.size()))

## Walks every nav path with the real walker, as villagers do, from the station outwards and carrying your height
## up the courtyard stair: every spot is reached, rooms upstairs included.
func test_every_nav_path_can_be_walked():
	_on(func():
		var w := _world()
		var adj := {}
		for e in Data.layout.nav_edges:
			for pair in [[e[0], e[1]], [e[1], e[0]]]:
				if not adj.has(pair[0]): adj[pair[0]] = []
				adj[pair[0]].append(pair[1])
		var start: String = P + "station"
		var p0: Array = Data.layout.nav_nodes[start]
		var at := {start: Heightfield.height(p0[0], p0[1])}   # node -> the height you reached it at
		var queue: Array = [start]
		while not queue.is_empty():
			var a: String = queue.pop_front()
			var pa: Array = Data.layout.nav_nodes[a]
			for b in adj.get(a, []):
				if at.has(b): continue
				var pb: Array = Data.layout.nav_nodes[b]
				var pos := Vector3(pa[0], at[a], pa[1])
				var goal := Vector2(pb[0], pb[1])
				for n in int(goal.distance_to(Vector2(pa[0], pa[1])) / 0.2) + 40:
					var dir := (goal - Vector2(pos.x, pos.z))
					if dir.length() < 0.15: break
					dir = dir.normalized() * minf(0.2, dir.length())
					pos = w.step_move(pos, dir.x, dir.y).pos
				if Vector2(pos.x, pos.z).distance_to(goal) < 0.5:
					at[b] = pos.y; queue.append(b)
		for k in Data.layout.nav_nodes:
			t.ok(at.has(k), "%s can be walked to from the station" % k)
		# and every path can be walked from one end or the other (villagers follow them in straight lines)
		for e in Data.layout.nav_edges:
			if not at.has(e[0]) or not at.has(e[1]): continue
			var ok := false
			for pair in [[e[0], e[1]], [e[1], e[0]]]:
				var pa: Array = Data.layout.nav_nodes[pair[0]]; var pb: Array = Data.layout.nav_nodes[pair[1]]
				var pos := Vector3(pa[0], at[pair[0]], pa[1]); var goal := Vector2(pb[0], pb[1])
				for n in int(goal.distance_to(Vector2(pa[0], pa[1])) / 0.2) + 40:
					var dir := goal - Vector2(pos.x, pos.z)
					if dir.length() < 0.15: break
					dir = dir.normalized() * minf(0.2, dir.length())
					pos = w.step_move(pos, dir.x, dir.y).pos
				ok = ok or Vector2(pos.x, pos.z).distance_to(goal) < 0.5
			t.ok(ok, "the path %s-%s can be walked" % [e[0], e[1]])
		t.ok(absf(at.get(P + "home:spot", 0.0) - 3.5) < 0.05, "your flat is up on the first floor (%.2f)" % at.get(P + "home:spot", 0.0)))

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

# ---- Stage 3: people, requests, gathering and the evening paper --------------------------------------------------

func test_villagers_and_requests_hang_together():
	_on(func():
		var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == "metropolis")
		t.eq(people.size(), 13, "thirteen villagers live in Toriano")
		for n in people:
			t.ok(String(n.id).begins_with(P), "villager %s has the prefix" % n.id)
			t.ok(Data.layout.nav_nodes.has(n.home), "%s's home %s is a nav spot" % [n.id, n.home])
			var rows: Array = n.schedule.duplicate()
			for w in n.get("when", []): rows.append_array(w.schedule)
			t.ok(rows.all(func(r): return Data.layout.nav_nodes.has(r[2])), "%s's routine only goes to nav spots" % n.id)
			t.ok(rows.all(func(r): return not String(r[2]).begins_with(P + "bal_")), "%s doesn't stand about on number 14's balcony, where they'd block the way home" % n.id)
			t.ok(n.likes.all(func(i): return Data.resources.has(i)), "%s likes real things" % n.id)
		var qs: Array = Data.quests.filter(func(q): return String(q.id).begins_with(P))
		t.eq(qs.size(), 19, "nineteen requests")
		t.eq(qs.filter(func(q): return q.get("main", false)).size(), 6, "six of them the main story")
		var made := {}   # every flag something sets
		for q in qs:
			for f in q.get("rewards", {}).get("flags", []) + q.get("onAccept", {}).get("flags", []): made[f] = true
			for o in q.objectives:
				for f in o.get("onDone", {}).get("flags", []): made[f] = true
		for m in LocationMeter.def("metropolis").get("milestones", []):
			for f in m.get("flags", []): made[f] = true
		var machines: Array = Data.layout.machines.map(func(m): return m.id)
		for q in qs:
			t.ok(Data.npc(q.giver).get("island", "") == "metropolis", "%s is asked by a Toriano villager" % q.id)
			for f in q.get("requires", {}).get("flags", []): t.ok(made.has(f), "%s waits for %s, which something sets" % [q.id, f])
			for o in q.objectives:
				if o.has("npc"): t.ok(not Data.npc(o.npc).is_empty(), "%s/%s: %s exists" % [q.id, o.id, o.npc])
				if o.has("zone"): t.ok(not Data.zone(o.zone).is_empty(), "%s/%s: site %s exists" % [q.id, o.id, o.zone])
				if o.kind == "gather": t.ok(Data.resources.has(o.item), "%s/%s gathers a real item" % [q.id, o.id])
				if o.kind == "pay": t.ok(o.items.keys().all(func(k): return Data.resources.has(k)), "%s/%s pays with real things" % [q.id, o.id])
				if o.kind == "flag": t.ok(made.has(o.flag) or o.flag == P + "on_roof", "%s/%s waits for a flag that gets set" % [q.id, o.id])
				if o.kind == "build" and String(o.check).begins_with("fed:"): t.ok(machines.has(String(o.check).substr(4)), "%s: the machine target exists" % q.id)
				if o.kind == "build" and String(o.check).begins_with("path:"): t.ok(Data.zone(String(o.check).substr(5)).has("endpoints"), "%s: the path's site has endpoints" % q.id)
			for b in q.get("onAccept", {}).get("blueprints", []) + q.get("rewards", {}).get("blueprints", []): t.ok(not Data.piece(b).is_empty(), "%s hands out real plans (%s)" % [q.id, b])
		var inches := 0
		for q in qs: inches += int(q.rewards.get("meter", 0))
		t.ok(qs.all(func(q): return int(q.rewards.get("harmony", 0)) == 0), "and none of them raise the Sindaco's approval rating")
		t.ok(inches > 120, "more column inches on offer (%d) than the front page needs" % inches)
		for sid in Data.shops.shops:
			if String(sid).begins_with(P): t.ok(Data.npc(sid).get("island", "") == "metropolis", "shop %s belongs to a Toriano villager" % sid))

func test_villagers_keep_out_of_each_others_way():
	# two people on the same spot at the same hour can't both be reached (you talk to whoever's nearer), at every
	# point in the story: before Augusto meets you, after, once you've settled in, on Christmas Eve and after it
	_on(func():
		var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == "metropolis")
		var stages := [{}, {P + "met": true}, {P + "met": true, P + "settled": true}, {P + "met": true, P + "settled": true, P + "christmas_eve": true},
			{P + "met": true, P + "settled": true, P + "christmas_eve": true, P + "angel_lit": true}]
		var clashes: Array = []
		for flags in stages:
			for m in range(0, 24 * 60, 30):
				var at := {}
				for n in people:
					var a := Schedule.activity_at(n, m + 15.0, flags)
					if a.activity == "sleep": continue
					if at.has(a.node): clashes.append("%s and %s at %s at %02d:%02d (%s)" % [at[a.node], n.id, a.node, m / 60, m % 60 + 15, flags.keys()])
					at[a.node] = n.id
		t.ok(clashes.is_empty(), "nobody shares a spot: %s" % [clashes.slice(0, 4)]))

func test_the_flat_comes_with_what_it_needs():
	_on(func():
		var q := Data.quest(P + "flat")
		var need := {}
		for id in ["bed", "table", "chair", "lamp"]:
			for k in Data.piece(id).cost: need[k] = int(need.get(k, 0)) + int(Data.piece(id).cost[k])
		var given: Dictionary = q.onAccept.get("items", {})
		t.ok(need.keys().all(func(k): return int(given.get(k, 0)) >= need[k]), "the Balcony Flat hands you enough to furnish it (%s for %s)" % [given, need]))

func test_the_evening_paper():
	_on(func():
		t.ok(not LocationMeter.def("metropolis").is_empty(), "Toriano has its own meter")
		var ms: Array = LocationMeter.def("metropolis").get("milestones", [])
		t.eq(ms.map(func(m): return int(m.at)), [10, 25, 45, 70, 90, 120], "six milestones")
		t.eq(ms.back().get("requires", {}).get("quests", []), [P + "angel"], "the front page waits for the Golden Angel")
		var roof := Data.zone(P + "roof_terrace")
		t.eq(int(roof.expanded.harmony), 70, "your weekly column widens the roof terrace")
		var s := GameState.new_game()
		s.harmony = 999
		t.ok(not BuildGrid.zone_contains(roof, -30, 123, LocationMeter.progress(s, "metropolis")), "approval earned elsewhere doesn't grow it")
		LocationMeter.add(s, "metropolis", 70)
		t.ok(BuildGrid.zone_contains(roof, -30, 123, LocationMeter.progress(s, "metropolis")), "column inches do"))

func test_gathering_spots_are_where_they_can_be_used():
	_on(func():
		var nodes: Array = Data.layout.nodes
		var count := func(kind: String) -> int: return nodes.filter(func(n): return n.kind == kind).size()
		t.ok(count.call("chop") >= 6 and count.call("mine") >= 4 and count.call("fish") >= 4 and count.call("bin") >= 5 and count.call("flowers") >= 3, "trees, marble, fishing spots, skips and flower beds")
		for n in nodes:
			t.ok(String(n.id).begins_with(P), "node %s has the prefix" % n.id)
			var b: Array = Data.layout.buildings.filter(func(x): return x.get("solid", true) and absf(n.x - x.x) < x.w / 2.0 and absf(n.z - x.z) < x.d / 2.0)
			t.ok(b.is_empty(), "%s isn't inside a building" % n.id)
			if n.kind == "fish":
				var ahead := Vector2(n.x + sin(n.facing) * 3.0, n.z + cos(n.facing) * 3.0)
				t.ok(not Heightfield.is_water(n.x, n.z) and Heightfield.is_water(ahead.x, ahead.y), "%s stands on the quay and casts into the water" % n.id)
			else: t.ok(not Heightfield.is_water(n.x, n.z), "%s is on dry ground" % n.id)
			if n.kind == "chop": t.ok(n.x < -88 and n.z < -98, "%s is a plane tree in the park" % n.id)
		t.eq(nodes.filter(func(n): return n.get("gives", {}).has(P + "score_page") and n.get("hours", []).map(func(h): return int(h)) == [20, 6]).size(), 8, "eight score pages, out only at night")
		t.ok(nodes.filter(func(n): return n.kind == "dig" and n.get("gives", {}).has(P + "roman")).size() >= 3, "Roman finds at the building sites")
		t.ok(Data.layout.fish.all(func(c): return Data.resources.has(c.get("item", "fish"))), "everything the canal gives is a real item")
		t.ok(Data.layout.fish.any(func(c): return c.get("item", "") == P + "bicycle"), "including old bicycles"))

## The builds the playthrough makes (and a player might), checked with the shared rules: each piece can go where it
## goes, and the request's check passes.
func _build(zone_id: String, list: Array) -> Array:
	var placed: Array = []
	var zone := Data.zone(zone_id)
	var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
	for e in list:
		var pl := {"uid": placed.size() + 1, "id": e[0], "i": float(e[1]), "k": float(e[2]), "r": int(e[3]) if e.size() > 3 else 0}
		pl["y"] = BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, pl.r, float(e[4]) if e.size() > 4 else 10.0, placed, zone)
		var v := BuildGrid.validate_placement(pl, {"placements": placed, "zones": [zone], "statics": statics, "bodies": []})
		t.ok(v.ok, "%s: %s at %d,%d (%s)" % [zone_id, pl.id, pl.i, pl.k, v.get("reason", "")])
		if v.ok: placed.append(pl)
	return placed

func test_the_footbridge_and_the_scaffolding_can_be_built_and_walked():
	_on(func():
		var bridge := _build(P + "footbridge", [["bridgeDeck", -113, 135, 0, 0.4], ["bridgePost", -110, 135, 0, 0.2], ["bridgeDeck", -110, 135, 0, 0.2], ["bridgeDeck", -111, 135, 0, 0.2], ["bridgeDeck", -112, 135, 0, 0.2], ["bridgeDeck", -109, 135, 0, 0.2],
			["bridgePost", -107, 135, 0, 0.2], ["bridgeDeck", -107, 135, 0, 0.2], ["bridgeDeck", -108, 135, 0, 0.2], ["bridgeDeck", -106, 135, 0, 0.2],
			["bridgePost", -104, 135, 0, 0.2], ["bridgeDeck", -104, 135, 0, 0.2], ["bridgeDeck", -105, 135, 0, 0.2], ["bridgeDeck", -103, 135, 0, 0.2], ["bridgeDeck", -102, 135, 0, 0.4]])
		var w := _world()
		t.ok(not Validate.path_across(Data.zone(P + "footbridge"), w).ok, "no way across the Naviglio before")
		w.surfaces = BuildGrid.surfaces_for(bridge)
		t.ok(Validate.path_across(Data.zone(P + "footbridge"), w).ok, "posts in the canal bed and planks across make a path")
		var climb: Array = []
		for n in 6:
			for b in n: climb.append(["stoneBlock", 75 - n, 10, 0, 0.3 + b])
			climb.append(["stairs", 75 - n, 10, 3, 0.3 + n])
		var scaffold := _build(P + "scaffold", climb)
		t.ok(not Validate.path_across(Data.zone(P + "scaffold"), _world()).ok, "no way up the cathedral before")
		w = _world(); w.surfaces = BuildGrid.surfaces_for(scaffold)
		t.ok(Validate.path_across(Data.zone(P + "scaffold"), w).ok, "a stair on stacked blocks reaches the roof terrace through the parapet's gap")
		var pos := Vector3(76.6, 0.3, 10.5)
		for n in 120: pos = w.step_move(pos, -0.1, 0.0).pos
		t.ok(pos.x < 69.0 and absf(pos.y - 6.3) < 0.1, "and the walker climbs it onto the terrace (at %s)" % pos))

func test_the_crane_and_the_angel_can_be_driven():
	_on(func():
		var wheel := _build(P + "crane", [["waterwheel", -145, 100, 0], ["shaft", -145, 99, 0]])
		t.ok(Mechanics.solve(wheel, Data.layout.machines).fed.get(P + "crane", false), "a waterwheel in the canal and a shaft drive the crane")
		var mill := _build(P + "terrace", [["windmill", 52, 9, 2, 7.0], ["shaft", 52, 8, 0, 7.0]])
		t.ok(mill.all(func(p): return absf(p.y - 6.3) < 0.01), "on the roof terrace, 6.3 m up")
		t.ok(Mechanics.solve(mill, Data.layout.machines).fed.get(P + "angel", false), "a windmill and a shaft drive the Golden Angel's floodlight"))
