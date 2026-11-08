extends RefCounted
## Islands: every island's layout makes a playable world (Hearthglow and Clockwork Cove), sailing keeps what you built
## on each island, requests belong to their island, and the Cove's two machine puzzles can be solved.
var t

## Runs `fn` with another island loaded, then always switches back to Hearthglow for the other tests.
func _on(id: String, fn: Callable) -> void:
	Data.use_island(id)
	fn.call()
	Data.use_island("hearthglow")

func _islands_with_layouts() -> Array: return Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)

func test_two_islands_are_built():
	var ids := _islands_with_layouts()
	t.ok(ids.has("hearthglow") and ids.has("clockwork"), "Hearthglow and Clockwork Cove have layouts (plus any location packs)")
	t.eq(Data.island, "hearthglow", "the game starts on Hearthglow")

func test_every_island_is_a_playable_world():
	for id in _islands_with_layouts():
		_on(id, func():
			var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
			var w := WalkWorld.new(statics, func(_f): return true)
			w.floors = WorldStatics.floors()
			var sp: Dictionary = Data.layout.spawn
			t.ok(not Heightfield.is_water(sp.x, sp.z) and not w.can_stand(sp.x, sp.z, Heightfield.height(sp.x, sp.z), 0.3).is_empty(), "%s: you arrive on open ground" % id)
			for k in Data.layout.nav_nodes:
				if k == "workshopInside": continue
				var p: Array = Data.layout.nav_nodes[k]
				var feet := maxf(Heightfield.height(p[0], p[1]), WorldStatics.floor_top(p[0], p[1]))   # on a balcony or a terrace, if there's one
				t.ok(not w.can_stand(p[0], p[1], feet, 0.3).is_empty(), "%s: nav spot %s is free" % [id, k])
			for e in Data.layout.nav_edges:
				t.ok(Data.layout.nav_nodes.has(e[0]) and Data.layout.nav_nodes.has(e[1]), "%s: path %s-%s joins real spots" % [id, e[0], e[1]])
			for n in Data.npcs_here():
				t.ok(Data.layout.nav_nodes.has(n.home), "%s: %s lives here" % [id, n.id])
				for e in n.schedule: t.ok(Data.layout.nav_nodes.has(e[2]), "%s: %s's routine goes to a real spot (%s)" % [id, n.id, e[2]])
				var flags := {}   # with the story done, every gated path (harbor gate, orchard bridge) is open
				for q in Data.quests:
					for f in q.get("rewards", {}).get("flags", []): flags[f] = true
				var path := Schedule.find_path(Schedule.nearest_node(sp.x, sp.z, flags), n.home, flags)
				t.ok(not path.is_empty(), "%s: you can walk from the dock to %s's home" % [id, n.id])
			for n in Data.layout.nodes:
				if n.kind == "fish": continue
				t.ok(not Heightfield.is_water(n.x, n.z), "%s: %s is on land" % [id, n.id])
			for b in Data.layout.buildings:
				t.ok(not Heightfield.is_water(b.x, b.z), "%s: %s stands on land" % [id, b.id])
			for m in Data.layout.get("machines", []):
				t.ok(Data.layout.zones.any(func(z): return BuildGrid.zone_contains(z, m.cell[0], m.cell[1], 999)), "%s: machine %s can be reached from a build zone" % [id, m.id])
			t.ok(Data.layout.features.any(func(f): return f.kind == "boat"), "%s: a boat to sail away" % id)
			for q in Data.quests.filter(func(q): return Data.quest_island(q.id) == id):
				for o in q.objectives:
					if o.has("zone"): t.ok(not Data.zone(o.zone).is_empty(), "%s: %s builds in a real zone (%s)" % [id, q.id, o.zone])
					if o.has("npc"): t.eq(Data.npc_island(o.npc), id, "%s: %s's step is with someone on the island (%s)" % [id, q.id, o.npc])
					if o.has("hint") and not o.kind in ["build", "pieces", "commission"]: t.ok(not Heightfield.is_water(o.hint.x, o.hint.z), "%s: %s's compass hint is on land" % [id, q.id]))

func test_cove_ground():
	_on("clockwork", func():
		t.ok(Heightfield.is_stream_cell(12, -8), "the millrace by the clock tower flows")
		t.ok(not Heightfield.is_stream_cell(-10, 4), "the village isn't a stream")
		t.ok(Heightfield.is_water(2, 33), "the boat floats in the bay")
		t.ok(Heightfield.height(20, -20) > 2.0, "Gearspring Hill rises in the north-east")
		t.ok(absf(Heightfield.height(-23, -19) - Heightfield.height(-21, -20)) < 0.05, "the lighthouse cape is level")
		t.ok(Heightfield.height(12, -10) < 0.35, "the clock yard is low enough for a waterwheel's shafts"))
	t.ok(not Heightfield.is_stream_cell(12, -8) or Data.island != "hearthglow", "back on Hearthglow the cove's millrace is gone")

func _place(list: Array, statics: Array, zone_id: String, id: String, i: int, k: int, r: int = 0) -> Dictionary:
	var z := Data.zone(zone_id)
	var pl := {"uid": 900 + list.size(), "id": id, "i": float(i), "k": float(k), "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, 10.0, list, z)}
	var v := BuildGrid.validate_placement(pl, {"placements": list, "zones": [z], "statics": statics, "bodies": []})
	if v.ok: list.append(pl)
	return v

func test_cove_machines_can_be_solved():
	_on("clockwork", func():
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		var targets: Array = Data.layout.machines
		var light: Array = []
		for p in [["windmill", -21, -20, 0], ["gear", -21, -19, 0], ["shaft", -22, -19, 1], ["gear", -23, -19, 0]]:
			var v := _place(light, statics, "lighthouse", p[0], p[1], p[2], p[3])
			t.ok(v.ok, "lighthouse: %s fits at %d,%d (%s)" % [p[0], p[1], p[2], v.get("reason", "")])
		t.ok(Mechanics.solve(light, targets).fed.get("lighthouse", false), "windmill → gear → shaft → gear powers the lighthouse drive")
		t.ok(not Mechanics.solve(light.slice(0, 3), targets).fed.get("lighthouse", false), "without the last gear box it stays dark")
		var clock: Array = []
		for p in [["waterwheel", 12, -8, 0], ["shaft", 12, -9, 0], ["shaft", 12, -10, 0], ["gear", 12, -11, 0]]:
			var v := _place(clock, statics, "clockyard", p[0], p[1], p[2], p[3])
			t.ok(v.ok, "clock: %s fits at %d,%d (%s)" % [p[0], p[1], p[2], v.get("reason", "")])
		t.ok(Mechanics.solve(clock, targets).fed.get("clock", false), "waterwheel → shafts → gear drives the clock")
		var dry := clock.duplicate(); dry.remove_at(0)
		t.ok(not Mechanics.solve(dry, targets).fed.get("clock", false), "no waterwheel, no ticking"))

func test_travel_keeps_each_islands_buildings():
	var s := GameState.new_game()
	s.placements = [{"uid": 3, "id": "bridgeDeck", "i": 0.0, "k": -15.0, "r": 0, "y": 0.1}]
	Travel.leave(s, "hearthglow", "clockwork", {"x": 2, "z": 28.4, "yaw": 3.1})
	t.ok(s.island == "clockwork" and s.placements.is_empty() and s.player.z == 28.4, "arriving at the cove: nothing built there yet, standing on the dock")
	s.placements.append({"uid": 7, "id": "windmill", "i": -21.0, "k": -20.0, "r": 0, "y": 1.2})
	t.eq(Travel.max_uid(s), 7, "uids stay unique across islands")
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.ok(back.island == "clockwork" and back.away.hearthglow.placements[0].uid == 3 and back.next_uid >= 8, "a save on the cove keeps Hearthglow's bridge put away")
	Travel.leave(back, "clockwork", "hearthglow", Data.read_layout("hearthglow").spawn)
	t.ok(back.placements.size() == 1 and back.placements[0].id == "bridgeDeck" and back.away.clockwork.placements[0].id == "windmill", "sailing home: the bridge is back, the windmill stays on the cove")

func test_requests_belong_to_their_island():
	var s := GameState.new_game()
	for q in ["tool", "bridge", "workshop", "fountain", "dock"]: s.quests[q] = {"status": "done", "progress": {}}
	s.flags["arrived_clockwork"] = true
	var e := QuestEngine.new(s)
	t.eq(Data.quest_island("lighthouse"), "clockwork", "the lighthouse request is on the cove")
	t.ok(not e.story_leads().any(func(q): return q.id == "cove"), "on Hearthglow the cove's story request isn't shown as a lead")
	s.island = "clockwork"; e.invalidate()
	t.ok(e.story_leads().any(func(q): return q.id == "cove"), "on the cove, Barnaby's welcome is the next story step")
	var calls := [0]
	var check := func():
		calls[0] += 1
		return true
	var e2 := QuestEngine.new(s, {"bridge": check})
	s.quests["bridge"] = {"status": "active", "progress": {"wood": 10}, "done": {}}
	e2.objective("bridge", Data.quest("bridge").objectives[2])
	t.eq(calls[0], 0, "a Hearthglow building check isn't run while you're on the cove")
	t.ok(Shop.is_open(s, "hazel"), "Hazel's forge shop is open once you've arrived")
	t.ok(Data.npcs_here().is_empty() or Data.npcs_here().all(func(n): return Data.npc_island(n.id) == Data.island), "only the island's own villagers are here")

func test_rooms_only_count_from_inside():
	_on("clockwork", func():
		# right outside the Clock House's back wall, Barnaby's work spot inside is closest as the crow flies, but the
		# way there is round through the door: the nearest spot to start from is outside
		var n := Schedule.nearest_node(-19.0, 3.5, {})
		t.ok(not n.contains(":"), "outside a house, the nearest nav spot is outdoors (%s)" % n)
		t.eq(Schedule.nearest_node(-9.4, 4.3, {}), "clockHouse:spot", "inside it, the spot indoors is nearest"))

func test_nav_edges_go_round_buildings():
	# Walkers (villagers, and the playthrough harness) follow nav edges in straight lines: an edge that cuts through a
	# building would walk them into its walls, or in through a doorway and stuck against the back wall. Walkers have
	# a body, so the line has to clear the walls by a little more than a walker's radius.
	for id in _islands_with_layouts():
		_on(id, func():
			for e in Data.layout.nav_edges:
				var a: Array = Data.layout.nav_nodes[e[0]]; var b: Array = Data.layout.nav_nodes[e[1]]
				for bd in Data.layout.buildings:
					var inside := func(q: Array) -> bool: return absf(q[0] - bd.x) < bd.w / 2.0 and absf(q[1] - bd.z) < bd.d / 2.0
					if inside.call(a) or inside.call(b): continue   # the way into a room through its door
					var hit := false
					for k in 41:
						var t := k / 40.0
						var x: float = lerpf(a[0], b[0], t); var z: float = lerpf(a[1], b[1], t)
						var m := WalkWorld.PLAYER_RADIUS + 0.03
						if absf(x - bd.x) < bd.w / 2.0 + m and absf(z - bd.z) < bd.d / 2.0 + m: hit = true
					t.ok(not hit, "%s: the path %s-%s goes round %s" % [id, e[0], e[1], bd.id]))

func test_benches_to_rest_on():
	for id in _islands_with_layouts():
		_on(id, func():
			var benches: Array = Data.layout.features.filter(func(f): return f.kind == "bench")
			t.ok(benches.size() >= 3, "%s: a few benches to nap on (%d)" % [id, benches.size()])
			var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
			var w := WalkWorld.new(statics, func(_f): return true)
			for b in benches:
				var mine: Array = statics.filter(func(s): return s.tag == b.id)
				t.eq(mine.size(), 1, "%s: %s is solid" % [id, b.id])
				var box: Dictionary = mine[0]
				t.ok(not Heightfield.is_water(b.x, b.z), "%s: %s stands on land" % [id, b.id])
				for s in statics:
					if s.tag == b.id or s.tag == "tree": continue
					var hit := WalkWorld.circle_box(s.x, s.z, s.r, box) if s.type == "circle" else BuildGrid.overlap2(box, s, 0.02)
					t.ok(not hit, "%s: %s doesn't overlap %s" % [id, b.id, s.tag])
				var sides := 0
				for k in 8:
					var x: float = b.x + cos(k * TAU / 8.0) * 1.5; var z: float = b.z + sin(k * TAU / 8.0) * 1.5
					if not w.can_stand(x, z, Heightfield.height(x, z), 0.3).is_empty(): sides += 1
				t.ok(sides >= 4, "%s: you can walk up to %s (%d/8 sides)" % [id, b.id, sides])
				for zn in Data.layout.zones:   # (an open area, like the village streets, takes in the benches already there)
					if zn.get("open", false): continue
					t.ok(not BuildGrid.zone_contains(zn, floorf(b.x), floorf(b.z), 999), "%s: %s isn't on a build site" % [id, b.id])
			for e in Data.layout.nav_edges:
				var a: Array = Data.layout.nav_nodes[e[0]]; var c: Array = Data.layout.nav_nodes[e[1]]
				for b in benches:
					var box: Dictionary = statics.filter(func(s): return s.tag == b.id)[0]
					var through := false
					for k in 21:
						var x: float = lerpf(a[0], c[0], k / 20.0); var z: float = lerpf(a[1], c[1], k / 20.0)
						if x > box.minX - 0.3 and x < box.maxX + 0.3 and z > box.minZ - 0.3 and z < box.maxZ + 0.3: through = true
					t.ok(not through, "%s: the path %s-%s goes round %s" % [id, e[0], e[1], b.id]))

func test_every_island_supplies_what_its_requests_gather():
	# Each place's requests ask you to gather things: something on that island has to give them (a node, the
	# island's rich rock, a catch on its fishing list, or a villager's shop there). Stage 1 turned the rich rocks to
	# metal and left the cove's clock with no crystal anywhere; this would have said so.
	for id in _islands_with_layouts():
		_on(id, func():
			var have := {}
			for n in Data.layout.nodes:
				if n.has("gives"):   # a node can give its own items instead of its kind's (a location's sand, say)
					for item in n.gives: have[item] = true
					continue
				for item in WorldActions.SOURCES:
					if WorldActions.SOURCES[item].has(n.kind): have[item] = true
				if n.kind == "mine" and n.get("rich", false): have[String(Data.layout.get("richRock", "metal"))] = true
			for f in Data.layout.get("fish", []): have[String(f.get("item", "fish"))] = true   # what bites there (Minigames.catch_table)
			var shops: Dictionary = Data.shops.get("shops", {})
			for npc in Data.npcs:
				if String(npc.get("island", "hearthglow")) != id or not shops.has(npc.id): continue
				for line in shops[npc.id].get("stock", []):
					for item in line.get("items", {}): have[item] = true
			for q in Data.quests:
				if Data.quest_island(q.id) != id: continue
				for o in q.objectives:
					if o.kind == "gather": t.ok(have.has(o.item), "%s: %s asks for %s, and the island gives it" % [id, q.id, o.item]))

func test_rich_rocks_give_what_the_place_is_rich_in():
	var hit := func(m) -> void:
		for k in 3: m.results.append("good")
	var iron := Minigames.Mine.new(true, Rng.new(1)); hit.call(iron)
	t.ok(int(iron.reward().get("metal", 0)) == 2 and not iron.reward().has("crystal"), "Monteforchetta's iron-red rocks: metal")
	var glow := Minigames.Mine.new(true, Rng.new(1), "crystal"); hit.call(glow)
	t.ok(int(glow.reward().get("crystal", 0)) == 2, "the cove's glowing rocks: crystal (%s)" % str(glow.reward()))
	t.eq(Data.read_layout("clockwork").get("richRock", ""), "crystal", "the cove's layout says its rocks hold crystal")

func test_no_squeeze_between_scenery_and_walls():
	# A tree, rock or bin near a building either touches it or leaves room to walk past: a gap narrower than a
	# walker wedges you in (the bin by Elio's shop once stood 0.25 m from its corner).
	var size := {"chop": 0.45, "fruit": 0.45, "shake": 0.45, "mine": 0.75, "bin": 0.65}
	for id in _islands_with_layouts():
		_on(id, func():
			for n in Data.layout.nodes:
				if not size.has(n.kind): continue
				for b in Data.layout.buildings:
					var cx := clampf(n.x, b.x - b.w / 2.0, b.x + b.w / 2.0); var cz := clampf(n.z, b.z - b.d / 2.0, b.z + b.d / 2.0)
					var gap := Vector2(n.x - cx, n.z - cz).length() - float(size[n.kind])
					t.ok(gap <= 0.0 or gap >= WalkWorld.PLAYER_RADIUS * 2.0 + 0.05, "%s: %s and %s leave room to pass (%.2f m)" % [id, n.id, b.id, gap]))

func test_nav_edges_stay_on_dry_land():
	# Villagers walk nav edges without colliding, so an edge across water has them walking on it, and a player
	# following the same line stops at the bank. Edges behind a flag (the bridge, once built) are the exception.
	for id in _islands_with_layouts():
		_on(id, func():
			var on_floor := func(x: float, z: float) -> bool:   # a layout's walkable floors (a city's old bridge deck)
				for f in Data.layout.get("floors", []):
					var r: Array = f.rect
					if f.get("walkable", true) and x >= minf(r[0], r[2]) and x <= maxf(r[0], r[2]) and z >= minf(r[1], r[3]) and z <= maxf(r[1], r[3]): return true
				return false
			for e in Data.layout.nav_edges:
				if e.size() > 2: continue
				var a: Array = Data.layout.nav_nodes[e[0]]; var b: Array = Data.layout.nav_nodes[e[1]]
				var wet := false
				for k in 41:
					var t := k / 40.0
					var x: float = lerpf(a[0], b[0], t); var z: float = lerpf(a[1], b[1], t)
					if Heightfield.height(x, z) < Heightfield.WALKABLE_MIN and not on_floor.call(x, z): wet = true
				t.ok(not wet, "%s: the path %s-%s stays on dry land" % [id, e[0], e[1]]))
