extends RefCounted
## The travel map: places stay off it until they're unlocked, so each one turns up as a surprise, and the view widens
## to take in the places on it.
var t

func test_places_appear_when_unlocked():
	var village := {"id": "hearthglow", "built": true}
	var city := {"id": "city", "reveal": "city_open"}
	var old := {"id": "cove", "reveal": "cove_open", "hidden": true}
	t.ok(Travel.on_map(village, {}, "hearthglow"), "the starting village is on the map")
	t.ok(not Travel.on_map(city, {}, "hearthglow"), "a place you haven't unlocked isn't, not even as a locked shape")
	t.ok(Travel.on_map(city, {"city_open": true}, "hearthglow"), "it turns up once its flag is set")
	t.ok(Travel.on_map(city, {}, "city"), "the place you're in is always there")
	t.ok(not Travel.on_map(old, {"cove_open": true}, "cove"), "a hidden place never is")
	t.ok(not Travel.on_map({"id": "somewhere"}, {}, "hearthglow"), "a place with no way to unlock it stays off")

func test_every_place_starts_as_a_surprise():
	for isl in Data.islands:
		if isl.get("built", false): continue
		t.ok(isl.has("reveal") or isl.get("hidden", false), "%s waits for a flag before it shows on the map" % isl.id)
		t.ok(not Travel.on_map(isl, {}, "hearthglow"), "%s isn't on a new game's map" % isl.id)

func test_the_view_widens_as_places_appear():
	var village := {"x": 300, "y": 330, "r": 70}
	var city := {"x": 600, "y": 150, "r": 80}
	var one := Travel.map_frame([village])
	var two := Travel.map_frame([village, city])
	t.ok(is_equal_approx(one.size.x / one.size.y, 1.6) and is_equal_approx(two.size.x / two.size.y, 1.6), "the view keeps the map's proportions")
	t.ok(one.size.x < 500.0, "a lone village fills the view (%d wide)" % one.size.x)
	t.ok(two.size.x > one.size.x, "the view widens when a place appears")
	for f in [one, two]:
		t.ok(f.has_point(Vector2(300, 330)) and f.grow(-60).has_point(Vector2(300, 330 + 70)), "Monteforchetta and its name fit")
	t.ok(two.has_point(Vector2(600, 150 - 80)) and two.has_point(Vector2(600 + 80, 150)), "and so does the city")
	t.eq(Travel.map_frame([]), Rect2(0, 0, 800, 500), "with nothing on it, the whole map")

func test_stops_on_a_line():
	var a := {"id": "a", "kind": "stop", "line": "tram", "x": 0, "z": 0}
	var b := {"id": "b", "kind": "stop", "line": "tram", "x": 80, "z": 0}
	var c := {"id": "c", "kind": "stop", "line": "tram", "x": 80, "z": 60}
	var other := {"id": "x", "kind": "stop", "line": "funicular", "x": 5, "z": 5}
	var sign := {"id": "s", "kind": "sign", "x": 1, "z": 1}
	var fs := [a, sign, b, other, c]
	t.eq(Travel.stops_on(b, fs).map(func(f): return f.id), ["c", "a"], "the other stops on the line, the next one first")
	t.eq(Travel.stops_on(other, fs), [], "a line with one stop goes nowhere")
	t.ok(is_equal_approx(Travel.ride_minutes(a, b), 10.0), "80 m at tram speed is ten game minutes (%.1f)" % Travel.ride_minutes(a, b))
	t.eq(Travel.ride_minutes(a, {"x": 3, "z": 0}), 2.0, "even the shortest ride takes a couple of minutes")
