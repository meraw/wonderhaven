extends RefCounted
var t

func test_the_bakery_boars_stand_where_you_can_reach_them():
	Data.use_island("hearthglow")
	for spot in WorldActions.SQUIRREL_SPOTS:
		var p := Vector2(float(spot[0]), float(spot[1]))
		for b in Data.layout.buildings:
			var cx := clampf(p.x, b.x - b.w / 2.0, b.x + b.w / 2.0)
			var cz := clampf(p.y, b.z - b.d / 2.0, b.z + b.d / 2.0)
			t.ok(p.distance_to(Vector2(cx, cz)) >= 1.0 or b.id == "bakery", "the boar at %s has room to wander and be reached, clear of %s" % [p, b.id])

func test_a_fed_boar_goes_back_into_the_woods():
	Data.use_island("hearthglow")
	var bakery := Vector2(float(WorldActions.SQUIRREL_SPOTS[0][0]), float(WorldActions.SQUIRREL_SPOTS[0][1]))
	var woods: Array = Data.layout.get("decor", {}).get("woods", [])
	for n in WorldActions.SQUIRREL_SPOTS.size():
		var home := WorldActions.woods_home(n)
		t.ok(woods.any(func(w): return home.distance_to(Vector2(float(w.x), float(w.z))) < float(w.r)), "boar %d settles inside a wood (%s)" % [n, home])
		t.ok(home.distance_to(bakery) > 15.0, "boar %d is well away from the bakery (%.1f m)" % [n, home.distance_to(bakery)])
