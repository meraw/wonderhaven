extends RefCounted
## Shared map shape for every location: the map's size comes from its layout (villages keep 124 m), a layout can
## paint streets, squares and quays over the grass (Ground), which the terrain draws and greenery stays off, and a
## tall building keeps the camera out up to its full height.
var t

## Runs `fn` with a stand-in layout, then puts Hearthglow back.
func _with_layout(extra: Dictionary, fn: Callable) -> void:
	Data.use_island("hearthglow")
	var base: Dictionary = Data.layout.duplicate(true)
	for k in extra: base[k] = extra[k]
	Data.layout = base
	fn.call()
	Data.use_island("hearthglow")

func test_shapes_paint_in_order():
	var shapes := [{"kind": "asphalt", "rect": [0, 0, 10, 10]}, {"kind": "setts", "circle": [5, 5, 2]},
		{"kind": "gravel", "line": [[20, 0], [20, 10]], "w": 2}, {"kind": "grass", "rect": [8, 8, 10, 10]}]
	t.eq(Ground.kind_at(-5, -5, shapes), "grass", "unpainted ground is grass")
	t.eq(Ground.kind_at(1, 1, shapes), "asphalt", "a rectangle paints its inside")
	t.eq(Ground.kind_at(5, 5.5, shapes), "setts", "a later circle covers the rectangle")
	t.eq(Ground.kind_at(20.9, 5, shapes), "gravel", "a line paints its width")
	t.eq(Ground.kind_at(21.2, 5, shapes), "grass", "and nothing beyond it")
	t.eq(Ground.kind_at(9, 9, shapes), "grass", "grass can be painted back, for a lawn in a square")
	t.ok(Ground.paved(1, 1, shapes) and not Ground.paved(9, 9, shapes), "paved means anything but grass")
	t.eq(Ground.kind_at(4, 9, [{"kind": "slabs", "rect": [10, 10, 0, 0]}]), "slabs", "rectangle corners can come in any order")

func test_bake_matches_kind_at():
	var shapes := [{"kind": "asphalt", "rect": [-10, -10, 0, 10]}, {"kind": "slabs", "circle": [5, 0, 3]}, {"kind": "gravel", "line": [[-8, 6], [8, 6]], "w": 1.5}]
	var rect := Rect2(-10, -10, 20, 20)
	var img := Ground.bake(shapes, rect)
	t.eq(img.get_size(), Vector2i(40, 40), "two texels a metre")
	var same := true
	for j in range(0, 40, 3):
		for i in range(0, 40, 3):
			var x := rect.position.x + (i + 0.5) / 2.0; var z := rect.position.y + (j + 0.5) / 2.0
			var k := int(round(img.get_pixel(i, j).r * 255.0))
			if Ground.KINDS[k] != Ground.kind_at(x, z, shapes): same = false
	t.ok(same, "every texel holds the kind of ground at its centre")

func test_villages_keep_their_size_and_grass():
	Data.use_island("clockwork")
	t.eq(Data.map_size(), 124.0, "a village is 124 m across")
	Data.use_island("hearthglow")
	# Monteforchetta (the "hearthglow" id) is a hilltop: its ground runs on down the slopes to the valley floor
	t.eq(Data.map_size(), 250.0, "Monteforchetta's ground reaches past its slopes")
	t.ok(Ground.shapes().is_empty() and not Ground.paved(0, 0), "Monteforchetta is all grass")
	var m := TerrainBuilder.build_terrain()
	t.eq(m.get_meta("height_rect"), Vector4(-125, -125, 250, 250), "its terrain covers 250 m")
	m.free()

func test_a_bigger_map():
	_with_layout({"size": 200.0}, func():
		t.eq(Data.map_size(), 200.0, "a layout can be bigger")
		var m := TerrainBuilder.build_terrain()
		t.eq(m.get_meta("height_rect"), Vector4(-100, -100, 200, 200), "the terrain covers the whole map")
		var w := TerrainBuilder.build_water(m)
		t.ok((w.mesh as PlaneMesh).size.x >= 600.0, "the sea reaches well beyond it")
		t.eq(BuildMode.view_limit(), 93.0, "build mode's view reaches across it")
		w.free(); m.free())
	t.eq(BuildMode.view_limit(), Data.map_size() / 2.0 - 7.0, "and over a village it reaches as far as its edge allows")

func test_greenery_stays_off_paving_and_in_its_area():
	var ground := [{"kind": "asphalt", "rect": [-60, -60, 60, 60]}, {"kind": "grass", "rect": [-40, -40, -10, -10]}, {"kind": "gravel", "line": [[-40, -25], [-10, -25]], "w": 3}]
	_with_layout({"ground": ground, "decor": {"radius": 50, "trees": 20, "bushes": 10, "flowers": 60, "grass": 120, "area": [-40, -40, -10, -10]}}, func():
		var d := WorldStatics.generate_decor()
		var all: Array = d.trees + d.bushes + d.flowers + d.grass
		t.ok(d.flowers.size() > 20 and d.grass.size() > 50, "the lawn gets flowers and grass (%d, %d)" % [d.flowers.size(), d.grass.size()])
		t.ok(all.all(func(p): return p.x >= -40 and p.x <= -10 and p.z >= -40 and p.z <= -10), "everything grows inside the decor area")
		t.ok(all.all(func(p): return not Ground.paved(p.x, p.z)), "nothing grows on asphalt or the gravel path"))

func test_tall_buildings_block_the_camera_to_the_top():
	_with_layout({"buildings": [{"id": "tower", "kind": "city_block", "x": 0, "z": 0, "w": 10, "d": 10, "h": 18.0}, {"id": "hut", "kind": "cottage", "x": 30, "z": 0, "w": 5, "d": 5}]}, func():
		var boxes := Props.camera_blockers()
		t.ok((boxes[0] as AABB).end.y >= 18.0, "a block 18 m tall blocks the camera up to its roof")
		t.ok((boxes[1] as AABB).end.y < 8.0, "a cottage without a height keeps the usual one"))

## Stands in for the game where WorldActions registers what you can do with the world.
class FakeGame extends Node:
	signal game_event(type: String, data: Dictionary)
	var village := {"objects": {}}
	var state := {"flags": {"boatReady": true}, "inventory": {}}
	var registered: Array = []
	func add_interactable(d: Dictionary) -> void: registered.append(d)

func test_a_departure_point_with_its_own_id():
	_with_layout({"nodes": [], "features": [{"id": "city_train", "kind": "boat", "x": 3, "z": 4, "depart_label": "Take the train"}, {"id": "boat", "kind": "boat", "x": 9, "z": 9}]}, func():
		Data.island = "zz_elsewhere"   # not Hearthglow, so none of its gardens and boars
		var g := FakeGame.new()
		WorldActions.new(g)
		Data.island = "hearthglow"
		var train: Array = g.registered.filter(func(d): return d.get("id", "") == "city_train")
		t.eq(train.size(), 1, "a departure point needn't be called boat")
		t.eq(train[0].label.call(), "Take the train", "it can say how you leave")
		var bus: Array = g.registered.filter(func(d): return d.get("id", "") == "boat")
		t.eq(bus[0].label.call(), "Catch the bus", "without a label it's still the bus")
		g.free())

func test_a_stop_offers_a_ride():
	_with_layout({"nodes": [], "features": [{"id": "stop_a", "kind": "stop", "line": "tram", "name": "Duomo", "x": 3, "z": 4, "ride_label": "Take the tram"}]}, func():
		Data.island = "zz_elsewhere"
		var g := FakeGame.new()
		WorldActions.new(g)
		Data.island = "hearthglow"
		var stop: Array = g.registered.filter(func(d): return d.get("id", "") == "stop_a")
		t.eq(stop.size(), 1, "a stop is something you can do")
		t.eq(stop[0].label.call(), "Take the tram", "it says what you ride")
		var statics := WorldStatics.build_statics({"trees": [], "bushes": [], "flowers": [], "grass": []})
		t.ok(statics.any(func(s): return s.get("tag", "") == "stop_a"), "its sign post is solid")
		g.free())

func test_raised_floors_carry_you_and_what_you_build():
	# a balcony along x 0..8 at 3.2 m, reached by stairs climbing from z 5.5 (ground) to its edge at z 1.5
	var floors := [
		{"id": "balcony", "rect": [0, 0, 8, 1.5], "top": 3.2},
		{"id": "stairs", "rect": [6, 1.5, 8, 5.5], "rise": [3.2, 0.0], "axis": "z", "bottom": -0.5}]
	var tower := {"id": "terrace", "kind": "city_block", "x": 20, "z": 20, "w": 8, "d": 8, "h": 6.5, "y": 0.0, "roof_walk": true}
	var zone := {"id": "roof", "name": "Roof terrace", "minI": 17, "maxI": 22, "minK": 17, "maxK": 22, "floorY": 6.5}
	_with_layout({"floors": floors, "buildings": [tower], "zones": [zone], "nodes": [], "features": []}, func():
		var statics := WorldStatics.build_statics({"trees": [], "bushes": [], "flowers": [], "grass": []})
		t.ok(not statics.any(func(s): return s.get("tag", "") == "terrace"), "a walkable roof isn't a wall to the sky")
		var w := WalkWorld.new(statics); w.floors = WorldStatics.floors()
		var g := Heightfield.height(3, 0.7)
		t.eq(w.surface_at(3, 0.7, g).y, g, "on the ground you walk under the balcony")
		t.ok(not w.blocked(3, 0.7, g), "and nothing stops you there")
		t.ok(absf(w.surface_at(3, 0.7, 3.2).y - 3.2) < 0.01, "up on it, you stand on the balcony")
		var pos := Vector3(7, Heightfield.height(7, 6.0), 6.0)
		for n in 34: pos = w.step_move(pos, 0.0, -0.15).pos
		t.ok(absf(pos.y - 3.2) < 0.01 and pos.z < 1.5, "the stairs take you up onto the balcony (at %s)" % pos)
		for n in 30: pos = w.step_move(pos, -0.2, 0.0).pos
		t.ok(absf(pos.y - 3.2) < 0.01 and pos.x < 3.0, "and you walk along it, up to Hearthglow's fountain (at %s)" % pos)
		t.ok(w.blocked(15.85, 20, Heightfield.height(15.85, 20)), "the terrace block stops you on the ground")
		t.ok(absf(w.surface_at(20, 20, 6.5).y - 6.5) < 0.01, "and carries you on its roof")
		t.ok(absf(BuildGrid.ground_at(19, 19) - 6.5) < 0.01 and absf(BuildGrid.ground_at(30, 30) - Heightfield.height(30.5, 30.5)) < 0.01, "pieces rest on the roof there, on the ground elsewhere")
		var ctx := {"placements": [], "zones": [zone], "statics": statics}
		var pl := {"uid": 1, "id": "pillar", "i": 19.0, "k": 19.0, "r": 0, "y": BuildGrid.suggest_bottom("pillar", 19, 19, 0, 10.0, [], zone)}
		var v := BuildGrid.validate_placement(pl, ctx)
		t.ok(v.ok and absf(pl.y - 6.5) < 0.01, "a pillar goes up on the roof terrace (%s)" % v.get("reason", ""))
		zone.erase("floorY")
		t.eq(BuildGrid.validate_placement(pl, ctx).get("reason", ""), "Too high to build safely", "without the site's floor height, up there counts as too high"))

func test_rooms_stack_on_raised_floors():
	# a shop at street level with its door on the south, and a flat above it with its door on the north balcony; both
	# say which storey they're on ("y"), so neither one's walls block the other's door
	var g := Heightfield.height(-15, 18)
	var shop := {"id": "shop", "kind": "city_block", "x": -15, "z": 18, "w": 6, "d": 5, "h": 2.6, "y": g, "door": "S", "interior": {"items": [["table", 1.5, 0, 0]]}}
	var flat := {"id": "flat", "kind": "city_block", "x": -15, "z": 18, "w": 6, "d": 5, "h": 2.6, "y": g + 3.2, "door": "N", "interior": {"items": [["table", -1.5, 0, 0]]}}
	var mass := {"id": "wing", "kind": "city_block", "x": -5, "z": 18, "w": 6, "d": 5, "h": 9.0, "solid": false}
	var floors := [{"id": "flat_floor", "rect": [-18, 15.5, -12, 20.5], "top": g + 3.2}, {"id": "balcony", "rect": [-18, 14, -12, 15.5], "top": g + 3.2}]
	_with_layout({"buildings": [shop, flat, mass], "floors": floors, "nodes": [], "features": [], "zones": []}, func():
		var statics := WorldStatics.build_statics({"trees": [], "bushes": [], "flowers": [], "grass": []})
		t.ok(not statics.any(func(st): return st.get("tag", "") in ["shop", "flat", "wing"]), "rooms on their own storey and a scenery-only wing put no walls to the sky")
		var w := WalkWorld.new(statics); w.floors = WorldStatics.floors()
		var up := g + 3.2
		var pos := Vector3(-15, g, 21.5)
		for n in 20: pos = w.step_move(pos, 0.0, -0.15).pos
		t.ok(pos.z < 19.0 and pos.y < g + 1.0, "in through the shop's south door at street level, under the flat (at %s)" % pos)
		pos = Vector3(-15, up, 14.5)
		for n in 20: pos = w.step_move(pos, 0.0, 0.15).pos
		t.ok(pos.z > 17.0 and absf(pos.y - up) < 0.01, "in through the flat's north door from the balcony (at %s)" % pos)
		pos = Vector3(-15, up, 18)
		for n in 20: pos = w.step_move(pos, 0.0, 0.15).pos
		t.ok(pos.z < 20.5 and absf(pos.y - up) < 0.01, "but not out of the flat through the shop's door below (at %s)" % pos)
		t.ok(w.blocked(-16.5, 18, up) and not w.blocked(-16.5, 18, g), "the flat's table stands upstairs, not in the shop")
		t.ok(w.blocked(-13.5, 18, g) and not w.blocked(-13.5, 18, up), "and the shop's table downstairs"))

func test_a_building_on_a_raised_floor():
	_with_layout({"buildings": [{"id": "flat", "kind": "city_block", "x": 0, "z": 0, "w": 6, "d": 5, "h": 2.6, "y": 3.2}]}, func():
		t.ok((Props.camera_blockers()[0] as AABB).end.y >= 5.8, "an upstairs flat blocks the camera up to its own roof"))
