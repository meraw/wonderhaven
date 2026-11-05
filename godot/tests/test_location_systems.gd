extends RefCounted
## Small general tools a location's requests can use (they came with Boccapioppo's stage 3, any location can use
## them): a path check and a "sealed" check for any build zone, pieces that float, what a resource node gives, what
## bites at a fishing spot, a request's own weather, and a location's own progress meter. Toriano's stage 3 added
## milestones that wait for a request, build sites that grow with a meter, gathering spots with their own label,
## hours and lines, lost things named per place, a path check that climbs stairs, and the bathroom pieces.
var t

func _zone(i0: int, i1: int, k0: int, k1: int, extra: Dictionary = {}) -> Dictionary:
	var z := {"id": "zz_test", "name": "Test", "minI": i0, "maxI": i1, "minK": k0, "maxK": k1,
		"endpoints": {"a": {"minI": i0, "maxI": i1, "minK": k0, "maxK": k0}, "b": {"minI": i0, "maxI": i1, "minK": k1, "maxK": k1}}}
	z.merge(extra, true)
	return z

func _place(list: Array, id: String, i: int, k: int, y: float, r: int = 0) -> void:
	list.append({"uid": 500 + list.size(), "id": id, "i": float(i), "k": float(k), "r": r, "y": y})

func test_a_wall_seals_a_zone_only_when_it_is_whole_and_high_enough():
	# a strip of Hearthglow's orchard, 4 cells wide: water would have to cross it from row -40 to row -36
	var ground := -INF
	for i in range(0, 4):
		for k in range(-40, -35): ground = maxf(ground, BuildGrid.ground_at(i, k))
	var zone := _zone(0, 3, -40, -36, {"seal": ground + 1.4})
	var r := Validate.sealed(zone, [])
	t.ok(not r.sealed and r.gap.size() >= 5, "with nothing built, water gets through (a gap of %d cells)" % r.gap.size())
	var wall: Array = []
	for i in range(0, 4):   # a stone block, then sandbags stacked until the wall stands as high as the seal
		var y := BuildGrid.ground_at(i, -38)
		_place(wall, "stoneBlock", i, -38, y); y += 1.0
		while y < float(zone.seal): _place(wall, "sandbags", i, -38, y); y += 0.5
	t.ok(Validate.sealed(zone, wall).sealed, "a whole wall of stone blocks topped with sandbags seals it")
	var low := wall.filter(func(p): return p.id == "stoneBlock")
	t.ok(not Validate.sealed(zone, low).sealed, "a wall that's too low doesn't")
	var holed := wall.filter(func(p): return not (p.i == 2.0))
	var hr := Validate.sealed(zone, holed)
	t.ok(not hr.sealed and hr.gap.any(func(c): return c.x == 2 and c.y == -38), "a wall with a hole lets the water through the hole")
	var floating := wall.duplicate(); floating[0] = {"uid": 900, "id": "stoneBlock", "i": 0.0, "k": -38.0, "r": 0, "y": BuildGrid.ground_at(0, -38) + 0.6}
	t.ok(not Validate.sealed(zone, floating).sealed, "a block that doesn't reach the ground leaves a gap under it")

func test_pontoons_float_and_carry_you_across():
	var zone := Data.zone("bridge")   # Hearthglow's crossing over the stream
	var d := Data.piece("pontoon")
	t.ok(not d.is_empty() and d.get("placeOn", "") == "water" and d.get("walkable", false), "the Pontoon is a walkable piece placed on water")
	var y := BuildGrid.suggest_bottom("pontoon", 0, -19, 0, 5.0, [], zone)
	t.ok(absf(y + float(d.h) - (Heightfield.WATER_Y + BuildGrid.FREEBOARD)) < 0.001, "it floats with its deck just out of the water")
	var ctx := {"placements": [], "zones": [zone], "statics": []}
	var on_water := {"uid": 1, "id": "pontoon", "i": 0.0, "k": -19.0, "r": 0, "y": y}
	t.ok(BuildGrid.validate_placement(on_water, ctx).ok, "it can be moored on the stream")
	var on_land := {"uid": 2, "id": "pontoon", "i": 0.0, "k": -16.0, "r": 0, "y": BuildGrid.float_bottom(d)}
	var v := BuildGrid.validate_placement(on_land, ctx)
	t.ok(not v.ok and String(v.reason).contains("floats"), "not on dry ground: %s" % v.get("reason", ""))
	# a row of pontoons from bank to bank is a path you can walk
	var row: Array = []
	for k in [-21, -19, -17]: row.append({"uid": 10 + row.size(), "id": "pontoon", "i": 0.0, "k": float(k), "r": 0, "y": y})
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
	w.surfaces = BuildGrid.surfaces_for(row)
	t.ok(Validate.path_across(zone, w).ok, "a row of pontoons across the stream is a walkable crossing")
	var deck := {"uid": 30, "id": "bridgeDeck", "i": 0.0, "k": -18.0, "r": 0, "y": y + float(d.h)}
	t.ok(BuildGrid.compute_support(row + [deck]).supported.has(30), "planks laid on a pontoon are held up by it")

func test_sandbags_stack_into_a_wall():
	var d := Data.piece("sandbags")
	t.ok(not d.is_empty() and d.get("walkable", false) and float(d.h) < 1.0, "Sandbags are a low piece you can stack")
	for k in d.cost: t.ok(Data.resources.has(k), "Sandbags cost %s, a known material" % k)
	t.ok(not Data.starter_blueprints.has("sandbags") and not Data.starter_blueprints.has("pontoon"), "both come as plans from requests, not from the start")

func test_a_node_can_say_what_it_gives():
	t.eq(WorldActions.gives({"kind": "clay"}, {"clay": 2}), {"clay": 2}, "a clay pit gives clay")
	t.eq(WorldActions.gives({"kind": "clay", "gives": {"river_town_sand": 3.0}}, {"clay": 2}), {"river_town_sand": 3}, "or what the layout says: sand from a sandbank")

func test_what_bites_at_a_fishing_spot():
	t.eq(Minigames.catch_table([], "spot", {}, 600.0), Minigames.FISH, "without a list of its own, a place has the shared fish")
	var list := [{"id": "carp", "name": "Carp", "weight": 4.0, "pull": 0.7}, {"id": "boot", "name": "old boot", "weight": 1.0, "pull": 0.2, "item": "zz_boot"},
		{"id": "monster", "name": "monster", "weight": 1000.0, "pull": 2.0, "node": "deep", "flag": "night_fishing", "hours": [20, 4]}]
	var day := Minigames.catch_table(list, "deep", {"night_fishing": true}, 600.0)
	t.ok(day.size() == 2, "the monster doesn't bite by day")
	var night := Minigames.catch_table(list, "deep", {"night_fishing": true}, 22 * 60.0)
	t.ok(night.size() == 3, "it bites at night, at its spot, once the request allows it")
	t.ok(Minigames.catch_table(list, "shallow", {"night_fishing": true}, 22 * 60.0).size() == 2, "...and only at its spot")
	var mg := Minigames.Fish.new(Rng.new(3), [list[2]])
	mg.result = "caught"
	t.eq(mg.fish.id, "monster", "the fish comes from the spot's table")
	var boot := Minigames.Fish.new(Rng.new(3), [list[1]]); boot.result = "caught"
	t.eq(boot.reward(), {"zz_boot": 1}, "a catch can give its own item")
	var fish := Minigames.Fish.new(Rng.new(3), [list[0]]); fish.result = "caught"
	t.eq(fish.reward(), {"fish": 1}, "a fish gives fish")

func test_a_request_can_bring_its_own_weather():
	var s := {"time": {"day": 1, "minute": 1200.0, "total": 5000.0}}
	t.eq(Daylight.forced(s), "", "no weather of its own to begin with")
	Daylight.force(s, "rain", 6)
	t.eq(Daylight.forced(s), "rain", "a storm starts")
	s.time.total = 5000.0 + 5.9 * 60.0
	t.eq(Daylight.forced(s), "rain", "and lasts the hours it was given")
	s.time.total = 5000.0 + 6.1 * 60.0
	t.eq(Daylight.forced(s), "", "then the usual weather comes back")
	s["forced_weather"] = {"type": "hail", "until": 99999.0}
	t.eq(Daylight.forced(s), "", "an unknown kind of weather is ignored")

func test_a_location_can_have_its_own_meter():
	var m := {"name": "Gauge", "icon": "🌊", "reward": "%d cm off", "display": {"from": 7.4, "per_point": -0.01, "format": "%.2f m"},
		"milestones": [{"at": 100, "id": "a", "title": "A", "desc": ""}, {"at": 300, "id": "b", "title": "B", "desc": ""}]}
	t.eq(LocationMeter.reading(m, 0), "7.40 m", "it reads from its starting point")
	t.eq(LocationMeter.reading(m, 160), "5.80 m", "points move the reading (down, for a gauge)")
	t.eq(LocationMeter.next_milestone(m, 100).id, "b", "the next milestone")
	t.eq(LocationMeter.between(m, 50, 320).map(func(u): return u.id), ["a", "b"], "milestones passed on the way")
	t.ok(LocationMeter.reward_text(m, 100).contains("100 cm off"), "a reward reads in the meter's own words")
	var s := GameState.new_game()
	t.ok(s.has("meters") and LocationMeter.points(s, "anywhere") == 0, "a new game has no points on any meter")
	LocationMeter.add(s, "anywhere", 40)
	LocationMeter.add(s, "anywhere", 2)
	t.eq(LocationMeter.points(s, "anywhere"), 42, "points add up per location")
	t.eq(LocationMeter.points(SaveSystem.deserialize(SaveSystem.serialize(s)), "anywhere"), 42, "and survive a save")
	t.ok(LocationMeter.def("hearthglow").is_empty(), "Monteforchetta keeps the approval rating")

func test_a_place_can_change_with_the_story():
	t.eq(Data.world_flags_of("hearthglow", {"river_town_launched": true}), {}, "a place without WORLD_FLAGS never changes")
	t.eq(Data.world_flags_of("river_town", {"river_town_launched": true, "hasTool": true}), {"river_town_launched": true}, "only the flags its location script lists reshape it")
	var before = Data.layout
	Data.apply_world_flags({"hasTool": true, "river_town_launched": true})
	t.ok(is_same(Data.layout, before), "flags that don't reshape the place you're on leave its layout alone")

func test_a_particular_lost_thing_is_found_once():
	t.ok(WorldActions.regrows({"kind": "clay"}) and WorldActions.regrows({"kind": "fragment"}), "clay pits and the shared lost things come back")
	t.ok(not WorldActions.regrows({"kind": "fragment", "once": true}) and not WorldActions.regrows({"kind": "chest"}), "a node marked once, like a chest, is gone for good")

func test_villagers_walk_across_what_you_bridged():
	var had := Data.layout.has("crossings")
	var saved = Data.layout.get("crossings")
	Data.layout["crossings"] = [{"a": "zzWest", "b": "zzEast", "zone": "zz_bridge"}]
	var built := {"zz_bridge": [[3, 1], [4, 1], [5, 2]]}
	t.eq(Schedule.crossing("zzWest", "zzEast", built), [Vector2(3.5, 1.5), Vector2(4.5, 1.5), Vector2(5.5, 2.5)], "from the a side to the b side, cell by cell")
	t.eq(Schedule.crossing("zzEast", "zzWest", built)[0], Vector2(5.5, 2.5), "and back the other way")
	t.eq(Schedule.crossing("zzWest", "zzElsewhere", built), [], "not on other paths")
	t.eq(Schedule.crossing("zzWest", "zzEast", {}), [], "nor before anything is built there")
	if had: Data.layout["crossings"] = saved
	else: Data.layout.erase("crossings")

# ---- From Toriano's stage 3 ---------------------------------------------------------------------------------------

## Runs `fn` with a stand-in layout, then puts Hearthglow back.
func _with_layout(extra: Dictionary, fn: Callable) -> void:
	Data.use_island("hearthglow")
	var base: Dictionary = Data.layout.duplicate(true)
	for k in extra: base[k] = extra[k]
	Data.layout = base
	fn.call()
	Data.use_island("hearthglow")

## Runs `fn` with a stand-in location whose meter has a milestone that waits for a request.
func _with_meter(fn: Callable) -> void:
	var loc := {"id": "zz_paper", "name": "Paper Town", "meter": {"name": "The Evening Paper", "icon": "📰",
		"milestones": [{"at": 10, "id": "zz_notice", "title": "A notice", "desc": "."}, {"at": 40, "id": "zz_front", "title": "The front page", "desc": ".", "requires": {"quests": ["zz_finale"]}, "waits": "the finale"}]}}
	Data.islands.append(loc)
	fn.call()
	Data.islands.erase(loc)

func test_a_milestone_can_wait_for_a_request():
	_with_meter(func():
		var s := GameState.new_game()
		var front := {"id": "zz_front", "requires": {"quests": ["zz_finale"]}}
		LocationMeter.add(s, "zz_paper", 45)
		t.ok(not LocationMeter.requirements_met(s, front), "with the points but not the finale, the front page waits")
		t.eq(LocationMeter.waiting(s, "zz_paper"), [], "and isn't due")
		s.quests["zz_finale"] = {"status": "done"}
		t.eq(LocationMeter.waiting(s, "zz_paper").map(func(u): return u.id), ["zz_front"], "once the finale is done, it's due")
		s.unlocks_seen.append("zz_front")
		t.eq(LocationMeter.waiting(s, "zz_paper"), [], "and comes only once"))

func test_build_sites_grow_with_a_place_s_meter():
	_with_meter(func():
		var s := GameState.new_game()
		var zone := {"id": "zz_roof", "minI": 0, "maxI": 4, "minK": 0, "maxK": 4, "expanded": {"minI": 0, "maxI": 9, "minK": 0, "maxK": 4, "harmony": 20}}
		s.harmony = 500
		t.eq(LocationMeter.progress(s, "hearthglow"), 500.0, "elsewhere progress is the approval rating")
		t.ok(not BuildGrid.zone_contains(zone, 7, 2, LocationMeter.progress(s, "zz_paper")), "approval doesn't grow a site in a place with its own meter")
		LocationMeter.add(s, "zz_paper", 20)
		t.ok(BuildGrid.zone_contains(zone, 7, 2, LocationMeter.progress(s, "zz_paper")), "its meter does"))

func test_a_catch_s_name_reads_right():
	t.eq(Minigames.a_name("Old Boot"), "an Old Boot", "an old boot")
	t.eq(Minigames.a_name("Carp"), "a Carp", "a carp")

## Stands in for the game where WorldActions hands out what you find.
class FakeGame extends Node:
	class Fx:
		func sparkle(_a = null, _b = null, _c = null, _d = null) -> void: pass
		func play(_a = null, _b = null) -> void: pass
		func event(_a = null, _b = null) -> void: pass
	signal game_event(type: String, data: Dictionary)
	var village := {"objects": {}, "node_visuals": {}}
	var state := {"flags": {"hasTool": true}, "inventory": {}, "nodes": {}, "time": {"minute": 600.0, "total": 0.0}, "stats": {"fragments": 0, "bins": 0, "dug": 0, "treasures": 0}}
	var registered: Array = []
	var gained: Array = []
	var toasts: Array = []
	var effects := Fx.new()
	var player_char := Fx.new()
	var story := Fx.new()
	func add_interactable(d: Dictionary) -> void: registered.append(d)
	func give(items: Dictionary, _at = null, _quiet := false) -> void: gained.append(items)
	func toast(text: String, _kind := "", _secs := 0.0) -> void: toasts.append(text)
	func sfx(_name: String) -> void: pass

func test_gathering_spots_of_their_own():
	var nodes := [
		{"id": "skip", "kind": "bin", "x": 1, "z": 1, "label": "Dig through the skip", "gives": {"metal": 1, "clay": 2}, "lines": ["Old bricks and a bent pipe."]},
		{"id": "page", "kind": "fragment", "x": 3, "z": 1, "gives": {"zz_score_page": 1}, "name": "a page of the score", "hours": [20, 5]},
		{"id": "glove", "kind": "fragment", "x": 5, "z": 1},
		{"id": "find", "kind": "dig", "x": 7, "z": 1, "gives": {"zz_roman": 1}, "text": "A Roman coin!"}]
	_with_layout({"nodes": nodes, "features": [], "lost": ["an umbrella"]}, func():
		Data.island = "zz_elsewhere"   # not Hearthglow, so none of its gardens and boars
		var g := FakeGame.new()
		var wa := WorldActions.new(g)
		Data.island = "hearthglow"
		t.eq(g.registered.filter(func(d): return d.id == "skip")[0].label.call(), "Dig through the skip", "a spot can say what it is")
		wa.dig_bin(nodes[0])
		t.eq(g.gained.back(), {"metal": 1, "clay": 2}, "a skip gives what it holds")
		t.eq(g.toasts.back(), "Old bricks and a bent pipe.", "with its own lines")
		t.ok(not wa.ready(nodes[1]), "a page blown about at night isn't out by day")
		g.state.time.minute = 22 * 60.0
		t.ok(wa.ready(nodes[1]), "but is after dark")
		wa.catch_fragment(nodes[1])
		t.eq(g.gained.back(), {"zz_score_page": 1}, "and is a page, not a lost thing")
		t.eq(g.toasts.back(), "You found a page of the score!", "it says what it is")
		t.eq(int(g.state.stats.fragments), 0, "it doesn't count as a lost thing")
		wa.catch_fragment(nodes[2])
		t.eq(g.toasts.back(), "You found an umbrella!", "lost things are what people lose here")
		wa.dig(nodes[3])
		t.eq(g.gained.back(), {"zz_roman": 1}, "a dig spot can hold a find of its own")
		t.eq(g.toasts.back(), "A Roman coin!", "and say what it is")
		g.free())

func test_a_climb_up_to_a_roof_terrace():
	# a roof terrace 3 m above the ground at x 16..24, and a build site east of it where you build a stair up to it
	var g0 := Heightfield.height(26.5, 19.5)
	var tower := {"id": "terrace", "kind": "city_block", "x": 20, "z": 20, "w": 8, "d": 8, "h": g0 + 3.0, "y": 0.0, "roof_walk": true}
	var zone := {"id": "climb", "minI": 24, "maxI": 27, "minK": 19, "maxK": 20,
		"endpoints": {"a": {"minI": 27, "maxI": 27, "minK": 19, "maxK": 20}, "b": {"minI": 22, "maxI": 23, "minK": 19, "maxK": 20, "y": g0 + 3.0}}}
	_with_layout({"buildings": [tower], "zones": [zone], "floors": [], "nodes": [], "features": []}, func():
		var walk := WalkWorld.new(WorldStatics.build_statics({"trees": [], "bushes": [], "flowers": [], "grass": []})); walk.floors = WorldStatics.floors()
		t.ok(not Validate.path_across(zone, walk).ok, "no way up before you build one")
		# a stair climbing west, a metre a cell: on the ground, then on one block, then on two
		var list: Array = []
		var uid := 1
		for n in 3:
			var i := 26 - n
			for b in n: list.append({"uid": uid, "id": "stoneBlock", "i": float(i), "k": 19.0, "r": 0, "y": g0 + b}); uid += 1
			list.append({"uid": uid, "id": "stairs", "i": float(i), "k": 19.0, "r": 3, "y": g0 + n}); uid += 1
		walk.surfaces = BuildGrid.surfaces_for(list)
		t.ok(Validate.path_across(zone, walk).ok, "a stair up counts as a path, though every step is a metre higher than the last")
		var pos := Vector3(27.5, g0, 19.5)
		for n in 80: pos = walk.step_move(pos, -0.1, 0.0).pos
		t.ok(pos.x < 23.0 and absf(pos.y - (g0 + 3.0)) < 0.1, "and the walker really climbs it onto the terrace (at %s)" % pos)
		list.pop_back()   # take the top stair away: the last metre is a wall
		walk.surfaces = BuildGrid.surfaces_for(list)
		t.ok(not Validate.path_across(zone, walk).ok, "a stair that stops short doesn't count")
		var low: Dictionary = zone.duplicate(true)
		low.endpoints.b = {"minI": 25, "maxI": 25, "minK": 19, "maxK": 20, "y": g0 + 3.0}
		t.ok(not Validate.path_across(low, walk).ok, "an end that must be up high isn't reached down low"))

func test_bathroom_pieces():
	for id in ["toilet", "washbasin", "bathtub"]:
		var d := Data.piece(id)
		t.ok(not d.is_empty() and d.cat == "furniture", "%s is a piece of furniture" % id)
		t.ok(PieceMeshes.has_mesh(id), "%s has a model" % id)
		var ok := true
		for k in d.cost: ok = ok and Data.resources.has(k)
		t.ok(ok, "%s costs things you can gather" % id)
