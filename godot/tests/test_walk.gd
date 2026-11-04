extends RefCounted
var t

func test_terrain_shape():
	t.ok(absf(Heightfield.height(0, 2)) < 0.05, "village core is flat")
	t.ok(Heightfield.height(0, -18) < Heightfield.WALKABLE_MIN, "river is water")
	t.ok(Heightfield.height(0, -14.5) >= Heightfield.WALKABLE_MIN, "south bank walkable")
	t.ok(Heightfield.height(0, -21.5) >= Heightfield.WALKABLE_MIN, "north bank walkable")
	t.ok(Heightfield.height(0, -60) < Heightfield.WALKABLE_MIN, "sea around the island")

func test_bridge_zone_has_six_water_cells():
	var z: Dictionary = Data.zone("bridge")
	var water := []
	for k in range(int(z.minK), int(z.maxK) + 1):
		if Heightfield.height(0.5, k + 0.5) < Heightfield.WALKABLE_MIN: water.append(k)
	t.eq(water, [-21, -20, -19, -18, -17, -16], "water cells")

func test_decor_matches_web_version():
	var d := WorldStatics.generate_decor()
	t.eq([d.trees.size(), d.bushes.size(), d.flowers.size(), d.grass.size()], [95, 70, 520, 1400], "same counts as the web version")
	t.ok(absf(d.trees[0].x - 22.9822) < 0.001 and absf(d.trees[0].z + 23.7653) < 0.001, "same first tree (%s)" % str(d.trees[0]))
	t.ok(absf(d.trees[50].x + 15.5284) < 0.001, "same 51st tree")

func test_river_blocks_but_bank_is_walkable():
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()))
	var p := Vector3(0, Heightfield.height(0, -14.5), -14.5)
	for n in 40: p = w.step_move(p, 0, -0.1).pos
	t.ok(p.z > -15.1, "stopped at the water's edge (z=%.2f)" % p.z)
	t.ok(w.step_move(p, 0.1, 0).moved, "can slide along the bank")

func test_deck_makes_water_walkable_and_walls_block():
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()))
	w.surfaces = [{"minX": -0.5, "maxX": 1.5, "minZ": -22.0, "maxZ": -14.0, "bottom": 0.0, "top": 0.15, "walkable": true, "solid": true}]
	var p := Vector3(0.5, 0, -14.5)
	for n in 90: p = w.step_move(p, 0, -0.1).pos
	t.ok(p.z < -21.5, "crossed on the deck (z=%.2f)" % p.z)
	w.surfaces = [{"minX": 3.0, "maxX": 3.2, "minZ": 0.0, "maxZ": 4.0, "bottom": 0.0, "top": 2.2, "walkable": false, "solid": true}]
	p = Vector3(2, 0, 2)
	for n in 30: p = w.step_move(p, 0.1, 0).pos
	t.ok(p.x < 3.0, "wall stops the player")

func test_nav_nodes_are_free():
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
	for id in Data.layout.nav_nodes:
		if id == "workshopInside": continue
		var p: Array = Data.layout.nav_nodes[id]
		t.ok(not w.can_stand(p[0], p[1], Heightfield.height(p[0], p[1]), 0.3).is_empty(), "nav node %s" % id)

func test_harbor_gate_flag():
	var open := [false]
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(f): return f == "harborOpen" and open[0])
	t.ok(w.blocked(5, 34.7, 0.2), "gate closed")
	open[0] = true
	t.ok(not w.blocked(5, 34.7, 0.2), "gate open")

func test_free_spot_steps_off_a_build_site():
	# a body boxed in by solid pieces is stuck; free_spot finds open ground outside the zone
	var w := WalkWorld.new([], func(_f): return false)
	w.surfaces = []
	for c in [Vector2(9, 5), Vector2(11, 5), Vector2(10, 4), Vector2(10, 6)]:
		w.surfaces.append({"minX": c.x - 0.5, "maxX": c.x + 0.5, "minZ": c.y - 0.5, "maxZ": c.y + 0.5, "top": 2.2, "bottom": 0.0, "walkable": false, "solid": true})
	t.ok(w.stuck(Vector3(10, 0, 5)), "walled in on four sides is stuck")
	var zone := Rect2(8, 3, 5, 5)
	var spot := w.free_spot(10, 5, zone)
	t.ok(not spot.is_empty() and not zone.grow(0.4).has_point(Vector2(spot.x, spot.z)), "the free spot is outside the build zone (%s)" % str(spot))
	t.ok(not w.stuck(Vector3(spot.x, spot.y, spot.z)), "and you can move from there")
