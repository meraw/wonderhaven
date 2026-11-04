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
	Data.use_island("hearthglow")
	t.eq(Data.map_size(), 124.0, "a village is 124 m across")
	t.ok(Ground.shapes().is_empty() and not Ground.paved(0, 0), "Hearthglow is all grass")
	var m := TerrainBuilder.build_terrain()
	t.eq(m.get_meta("height_rect"), Vector4(-62, -62, 124, 124), "Hearthglow's terrain covers 124 m")
	m.free()

func test_a_bigger_map():
	_with_layout({"size": 200.0}, func():
		t.eq(Data.map_size(), 200.0, "a layout can be bigger")
		var m := TerrainBuilder.build_terrain()
		t.eq(m.get_meta("height_rect"), Vector4(-100, -100, 200, 200), "the terrain covers the whole map")
		var w := TerrainBuilder.build_water(m)
		t.ok((w.mesh as PlaneMesh).size.x >= 600.0, "the sea reaches well beyond it")
		w.free(); m.free())

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
