extends RefCounted
var t

func test_the_journey_rides_from_one_place_to_the_next():
	t.eq(Journey.progress(0.0), 0.0, "the bus waits while the map fades in")
	t.ok(Journey.progress(Journey.FADE + Journey.RIDE / 2.0) > 0.45 and Journey.progress(Journey.FADE + Journey.RIDE / 2.0) < 0.55, "halfway through the ride it's halfway there")
	t.eq(Journey.progress(Journey.length()), 1.0, "and it arrives before the card fades out")
	t.ok(Journey.alpha(0.0) == 0.0 and Journey.alpha(Journey.FADE + 1.0) == 1.0 and Journey.alpha(Journey.length()) == 0.0, "the card fades in and out")
	t.ok(Journey.length() < 6.0, "the whole journey takes a few seconds (%.1f)" % Journey.length())
	t.eq(Journey.caption("hearthglow", "river_town"), "Monteforchetta  →  Boccapioppo", "it says where you're going")

func test_the_road_goes_through_monteforchetta():
	var s := GameState.new_game()
	var g := {"state": s}
	var v := Panels.MapView.new()
	v.game = g
	v.size = Vector2(800, 430)
	v.trip_from = "hearthglow"
	v.trip_to = "river_town"
	t.eq(v.trip_route().size(), 2, "from Monteforchetta the bus drives straight there")
	v.trip_from = "river_town"
	v.trip_to = "rice_village"
	var r: Array = v.trip_route()
	t.eq(r.size(), 3, "between two other places it goes by Monteforchetta, where the roads meet")
	t.ok(v.trip_point(r, 0.0).distance_to(r[0]) < 0.01 and v.trip_point(r, 1.0).distance_to(r[2]) < 0.01, "and runs from one end to the other")
	t.ok(v._shown().any(func(i): return i.id == "rice_village"), "the place you're going to is on the map")
	v.free()
