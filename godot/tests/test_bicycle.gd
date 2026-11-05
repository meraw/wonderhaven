extends RefCounted
## The bicycle (Bicycle, BikeModel, PlayerController.riding): owned and upgraded through story flags, ridden
## anywhere outdoors where bikes are allowed, faster than running, off by itself indoors and on stairs.
var t

func test_owning_it_and_where_it_goes():
	t.ok(not Bicycle.owned({}) and Bicycle.owned({"hasBike": true}), "you own it once the story gives you hasBike")
	t.ok(Bicycle.allowed({}) and Bicycle.allowed(Data.island_def("hearthglow")), "bikes are allowed unless a place says no")
	t.ok(not Bicycle.allowed({"bikes": false}), "a place's map entry can say bikes: false")
	t.eq(Bicycle.cant_mount({}, {}, false, false), "You don't have a bike yet.", "no bike, no ride")
	t.ok(Bicycle.cant_mount({"hasBike": true}, {"bikes": false}, false, false) != "", "not where bikes aren't allowed")
	t.ok(Bicycle.cant_mount({"hasBike": true}, {}, true, false) != "" and Bicycle.cant_mount({"hasBike": true}, {}, false, true) != "", "not indoors, not on stairs")
	t.eq(Bicycle.cant_mount({"hasBike": true}, {}, false, false), "", "anywhere else outdoors")

func test_upgrades_and_paint():
	t.eq(Bicycle.upgrades({"hasBike": true}), [], "it comes plain")
	t.eq(Bicycle.upgrades({"bikeBell": true, "bikeLamp": true}), ["bell", "lamp"], "upgrades are story flags")
	var seen := {}
	var c: String = Bicycle.COLORS[0]
	for i in Bicycle.COLORS.size():
		seen[c] = true; c = Bicycle.next_color(c)
	t.ok(seen.size() == Bicycle.COLORS.size() and c == Bicycle.COLORS[0], "repainting goes through every colour and back")
	t.eq(Bicycle.color({}), Bicycle.COLORS[0], "an old save's bike has the first colour")
	var s := GameState.new_game()
	s.bike_color = Bicycle.COLORS[2]
	t.eq(Bicycle.color(SaveSystem.deserialize(SaveSystem.serialize(s))), Bicycle.COLORS[2], "the paint job survives a save")
	var bike := BikeModel.build(Bicycle.COLORS[0], ["basket", "lamp", "rack", "paint"])
	t.ok(bike.get_node_or_null("basket") != null and bike.get_node_or_null("lamp") != null, "the basket and the lamp show on the bike")
	BikeModel.animate(bike, 0.1, 10.0, true)
	t.ok((bike.get_node("lamp/beam") as SpotLight3D).visible, "the dynamo lamp shines while you ride at night")
	BikeModel.animate(bike, 0.1, 0.0, true)
	t.ok(not (bike.get_node("lamp/beam") as SpotLight3D).visible, "...and not when you stop")
	bike.free()

func test_riding_is_faster_and_doesnt_hop():
	# a straight, gently sloping run of open ground, heading east (camera yaw -90°)
	var start := Vector2.INF
	for z in range(-50, 50, 5):
		for x0 in range(-55, 15, 5):
			var ok := true
			for d in 34:
				var h := Heightfield.height(x0 + d, z)
				if h < Heightfield.WALKABLE_MIN or absf(h - Heightfield.height(x0 + d + 1, z)) > 0.2: ok = false; break
			if ok: start = Vector2(x0, z); break
		if start != Vector2.INF: break
	t.ok(start != Vector2.INF, "found open ground to ride on at %s" % start)
	var w := WalkWorld.new([])
	var who := Chibi.new({})
	var pc := PlayerController.new(who, w, start.x, start.y, PI / 2.0)
	var east := -PI / 2.0
	for i in 5: pc.update(0.1, Vector2(0, 1), true, false, east)
	var run_from: Vector3 = pc.pos
	for i in 10: pc.update(0.1, Vector2(0, 1), true, false, east)
	var ran := run_from.distance_to(pc.pos)
	pc.riding = true
	for i in 5: pc.update(0.1, Vector2(0, 1), false, false, east)
	var ride_from: Vector3 = pc.pos
	for i in 10: pc.update(0.1, Vector2(0, 1), false, true, east)
	var rode := ride_from.distance_to(pc.pos)
	t.ok(rode > ran * 1.5, "riding covers more ground than running (%.1f m against %.1f m in a second)" % [rode, ran])
	t.ok(pc.grounded, "no hopping on a bike")
	who.free()

func test_off_by_itself_indoors():
	var bakery: Dictionary = {}
	for b in Data.layout.buildings:
		if Interiors.enterable(b): bakery = b; break
	var base := maxf(0.0, Heightfield.height(bakery.x, bakery.z))
	t.ok(Bicycle.indoors(Vector3(bakery.x, base, bakery.z)), "inside %s counts as indoors" % bakery.id)
	t.ok(not Bicycle.indoors(Vector3(bakery.x, base, bakery.z + bakery.d / 2.0 + 3.0)), "the street outside doesn't")

func test_its_keys():
	for a in ["bike", "bell"]:
		t.ok(Controls.DEFAULTS.has(a) and Controls.LABELS.has(a) and Controls.PAD.has(a), "%s has a key, a label and a gamepad button" % a)
	var used := {}
	for a in Controls.DEFAULTS:
		for k in Controls.DEFAULTS[a]:
			t.ok(not used.has(k), "%s's key isn't also %s's" % [a, used.get(k, "")])
			used[k] = a
	var pads := {}
	for a in Controls.PAD:
		t.ok(not pads.has(Controls.PAD[a]), "%s's gamepad button isn't also %s's" % [a, pads.get(Controls.PAD[a], "")])
		pads[Controls.PAD[a]] = a
