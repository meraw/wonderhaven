extends RefCounted
## Shared systems for a location's people and requests: its own progress meter in place of the approval rating,
## what fishing and lost things turn up there, gathering spots with their own loot, label and hours, a path check
## that climbs (stairs up to a roof terrace), and the bathroom pieces.
var t

## Runs `fn` with a stand-in layout, then puts Hearthglow back.
func _with_layout(extra: Dictionary, fn: Callable) -> void:
	Data.use_island("hearthglow")
	var base: Dictionary = Data.layout.duplicate(true)
	for k in extra: base[k] = extra[k]
	Data.layout = base
	fn.call()
	Data.use_island("hearthglow")

## Runs `fn` with a stand-in location that has a meter.
func _with_meter(fn: Callable) -> void:
	var loc := {"id": "zz_paper", "name": "Paper Town", "meter": {"name": "The Evening Paper", "unit": "column inches", "short": "Inches", "icon": "📰",
		"milestones": [{"at": 25, "id": "zz_photo", "title": "A photo", "desc": "."}, {"at": 10, "id": "zz_notice", "title": "A notice", "desc": ".", "flags": ["zz_noticed"]},
			{"at": 40, "id": "zz_front", "title": "The front page", "desc": ".", "requires": {"quests": ["zz_finale"]}}]}}
	Data.islands.append(loc)
	fn.call()
	Data.islands.erase(loc)

func test_a_meter_of_its_own():
	_with_meter(func():
		var s := GameState.new_game()
		t.ok(Meter.has("zz_paper") and not Meter.has("hearthglow"), "a location can have its own meter; villages use approval")
		t.eq(Meter.progress(s, "zz_paper"), 0.0, "it starts at nothing")
		s.harmony = 30
		t.eq(Meter.progress(s, "hearthglow"), 30.0, "elsewhere progress is the approval rating")
		t.eq(Meter.next(s, "zz_paper").id, "zz_notice", "milestones come in order, whatever order they're written in")
		var got := Meter.add(s, "zz_paper", 12)
		t.eq(got.map(func(m): return m.id), ["zz_notice"], "points past a milestone reach it")
		t.eq(Meter.progress(s, "zz_paper"), 12.0, "and count on the meter")
		t.eq(int(s.harmony), 30, "not on the approval rating")
		t.eq(Meter.add(s, "zz_paper", 1), [], "a milestone is only reached once")
		t.eq(Meter.add(s, "zz_paper", 40).map(func(m): return m.id), ["zz_photo"], "one that needs a request done waits for it")
		s.quests["zz_finale"] = {"status": "done"}
		t.eq(Meter.check(s, "zz_paper").map(func(m): return m.id), ["zz_front"], "and comes once it's done")
		t.eq(Meter.next(s, "zz_paper"), {}, "then every milestone is reached")
		var saved := SaveSystem.deserialize(SaveSystem.serialize(s))
		t.eq(Meter.value(saved, "zz_paper"), 53, "the meter is saved")
		t.ok(Meter.got(saved, "zz_paper", {"id": "zz_front"}), "and so are the milestones reached")
		t.eq(Story.points_text(3, "zz_paper"), "+3 📰 column inches", "rewards there say what they're worth")
		t.eq(Story.points_text(3, "hearthglow"), "+3 💖 approval", "and approval elsewhere"))

func test_a_site_grows_with_the_meter():
	_with_meter(func():
		var s := GameState.new_game()
		var zone := {"id": "zz_roof", "minI": 0, "maxI": 4, "minK": 0, "maxK": 4, "expanded": {"minI": 0, "maxI": 9, "minK": 0, "maxK": 4, "harmony": 20}}
		s.harmony = 500
		t.ok(not BuildGrid.zone_contains(zone, 7, 2, Meter.progress(s, "zz_paper")), "approval doesn't grow a site in a place with a meter")
		Meter.add(s, "zz_paper", 20)
		t.ok(BuildGrid.zone_contains(zone, 7, 2, Meter.progress(s, "zz_paper")), "its own meter does"))

func test_what_the_line_catches_here():
	var table := [{"id": "bike", "name": "Old Bicycle", "weight": 1.0, "pull": 0.5, "item": "zz_bicycle"}]
	var f := Minigames.Fish.new(Rng.new(5), table)
	t.eq(f.fish.id, "bike", "a location's catches replace the fish")
	f.result = "caught"
	t.eq(f.reward(), {"zz_bicycle": 1}, "and give their own item")
	var trout := Minigames.Fish.new(Rng.new(5))
	trout.result = "caught"
	t.eq(trout.reward(), {"fish": 1}, "elsewhere you still catch fish")
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
		{"id": "skip", "kind": "bin", "x": 1, "z": 1, "label": "Dig through the skip", "loot": {"metal": 1, "clay": 1}, "lines": ["Old bricks and a bent pipe."]},
		{"id": "page", "kind": "fragment", "x": 3, "z": 1, "item": "zz_score_page", "name": "a page of the score", "hours": [20, 5]},
		{"id": "glove", "kind": "fragment", "x": 5, "z": 1},
		{"id": "find", "kind": "dig", "x": 7, "z": 1, "loot": {"zz_roman": 1}, "text": "A Roman coin!"},
		{"id": "fishing", "kind": "fish", "x": 9, "z": 1}]
	_with_layout({"nodes": nodes, "features": [], "lost": ["an umbrella"], "catches": [{"id": "bike", "name": "Old Bicycle", "weight": 1.0, "pull": 0.5, "item": "zz_bicycle"}]}, func():
		Data.island = "zz_elsewhere"
		var g := FakeGame.new()
		var wa := WorldActions.new(g)
		Data.island = "hearthglow"
		var by_id := func(id: String) -> Dictionary: return g.registered.filter(func(d): return d.id == id)[0]
		t.eq(by_id.call("skip").label.call(), "Dig through the skip", "a spot can say what it is")
		wa.dig_bin(nodes[0])
		t.eq(g.gained.back(), {"metal": 1, "clay": 1}, "a skip gives what it holds")
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
		t.ok(wa.gives(nodes[3], "zz_roman") and not wa.gives(nodes[0], "crystal") and wa.gives(nodes[0], "clay"), "the compass knows what each spot gives")
		t.ok(wa.gives(nodes[4], "zz_bicycle") and not wa.gives(nodes[4], "fish"), "including what the water gives here")
		g.free())

func test_a_climb_up_to_a_roof_terrace():
	# a roof terrace 3 m above the ground at x 16..24, and a build site east of it where you build a stair up to it
	var g0 := Heightfield.height(26.5, 19.5)
	var tower := {"id": "terrace", "kind": "city_block", "x": 20, "z": 20, "w": 8, "d": 8, "h": g0 + 3.0, "y": 0.0, "roof_walk": true}
	var zone := {"id": "climb", "minI": 24, "maxI": 27, "minK": 19, "maxK": 20,
		"endpoints": {"a": {"minI": 27, "maxI": 27, "minK": 19, "maxK": 20}, "b": {"minI": 22, "maxI": 23, "minK": 19, "maxK": 20, "minY": g0 + 3.0}}}
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
		var r := Validate.path_across(zone, walk)
		t.ok(r.ok, "a stair up counts as a path, though every step is a metre higher than the last")
		var pos := Vector3(27.5, g0, 19.5)
		for n in 80: pos = walk.step_move(pos, -0.1, 0.0).pos
		t.ok(pos.x < 23.0 and absf(pos.y - (g0 + 3.0)) < 0.1, "and the walker really climbs it onto the terrace (at %s)" % pos)
		list.pop_back()   # take the top stair away: the last metre is a wall
		walk.surfaces = BuildGrid.surfaces_for(list)
		t.ok(not Validate.path_across(zone, walk).ok, "a stair that stops short doesn't count")
		var low: Dictionary = zone.duplicate(true)
		low.endpoints.b = {"minI": 25, "maxI": 25, "minK": 19, "maxK": 20, "minY": g0 + 3.0}
		t.ok(not Validate.path_across(low, walk).ok, "an end that must be up high isn't reached down low"))

func test_bathroom_pieces():
	for id in ["toilet", "washbasin", "bathtub"]:
		var d := Data.piece(id)
		t.ok(not d.is_empty() and d.cat == "furniture", "%s is a piece of furniture" % id)
		t.ok(PieceMeshes.has_mesh(id), "%s has a model" % id)
		var ok := true
		for k in d.cost: ok = ok and Data.resources.has(k)
		t.ok(ok, "%s costs things you can gather" % id)
