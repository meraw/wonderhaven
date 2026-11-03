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
	t.eq(_islands_with_layouts(), ["hearthglow", "clockwork"], "Hearthglow and Clockwork Cove have layouts")
	t.eq(Data.island, "hearthglow", "the game starts on Hearthglow")

func test_every_island_is_a_playable_world():
	for id in _islands_with_layouts():
		_on(id, func():
			var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
			var w := WalkWorld.new(statics, func(_f): return true)
			var sp: Dictionary = Data.layout.spawn
			t.ok(not Heightfield.is_water(sp.x, sp.z) and not w.can_stand(sp.x, sp.z, Heightfield.height(sp.x, sp.z), 0.3).is_empty(), "%s: you arrive on open ground" % id)
			for k in Data.layout.nav_nodes:
				if k == "workshopInside": continue
				var p: Array = Data.layout.nav_nodes[k]
				t.ok(not w.can_stand(p[0], p[1], Heightfield.height(p[0], p[1]), 0.3).is_empty(), "%s: nav spot %s is free" % [id, k])
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
					if o.has("hint") and not o.kind in ["build", "pieces"]: t.ok(not Heightfield.is_water(o.hint.x, o.hint.z), "%s: %s's compass hint is on land" % [id, q.id]))

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
	for q in ["tool", "bridge", "workshop", "decree", "dock"]: s.quests[q] = {"status": "done", "progress": {}}
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
	s.quests["bridge"] = {"status": "active", "progress": {"wood": 10, "spark": 8}, "done": {}}
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
