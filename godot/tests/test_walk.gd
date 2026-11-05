extends RefCounted
var t

func test_terrain_shape():
	t.ok(absf(Heightfield.height(0, 2)) < 0.05, "village core is flat")
	t.ok(Heightfield.height(0, -18) < Heightfield.WALKABLE_MIN, "river is water")
	t.ok(Heightfield.height(0, -14.5) >= Heightfield.WALKABLE_MIN, "south bank walkable")
	t.ok(Heightfield.height(0, -21.5) >= Heightfield.WALKABLE_MIN, "north bank walkable")
	t.ok(Heightfield.height(0, -60) < Heightfield.WALKABLE_MIN, "the hill falls away past the edge")
	t.ok(Heightfield.height(0, -115) < -25.0 and Heightfield.height(112, 0) < -25.0, "down to the valley floor far below")

func test_bridge_zone_has_six_water_cells():
	var z: Dictionary = Data.zone("bridge")
	var water := []
	for k in range(int(z.minK), int(z.maxK) + 1):
		if Heightfield.height(0.5, k + 0.5) < Heightfield.WALKABLE_MIN: water.append(k)
	t.eq(water, [-21, -20, -19, -18, -17, -16], "water cells")

func test_decor_is_deterministic_with_woods():
	var d := WorldStatics.generate_decor()
	var d2 := WorldStatics.generate_decor()
	t.eq([d.trees.size(), d.bushes.size(), d.flowers.size(), d.grass.size()], [d2.trees.size(), d2.bushes.size(), d2.flowers.size(), d2.grass.size()], "the same scenery every time")
	t.ok(d.trees[7].x == d2.trees[7].x and d.trees[7].z == d2.trees[7].z, "tree by tree")
	var woods: Array = d.trees.filter(func(tr): return tr.has("wood"))
	t.ok(woods.size() >= 25, "the layout's woods are planted (%d trees)" % woods.size())
	for w in Data.layout.decor.woods:
		t.ok(woods.any(func(tr): return Vector2(tr.x - w.x, tr.z - w.z).length() <= float(w.r)), "trees in the wood at %s, %s" % [w.x, w.z])
	t.ok(d.trees.all(func(tr): return Heightfield.height(tr.x, tr.z) >= Heightfield.WALKABLE_MIN), "no tree stands on the slopes or in the stream")

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

func test_flagged_statics():
	# a `flag` static (a gate) stops blocking once its flag is set; a `whileFlag` one (the bus) only blocks while set
	var on := [false]
	var gate := {"type": "box", "minX": 0.0, "maxX": 1.0, "minZ": 0.0, "maxZ": 1.0, "flag": "open"}
	var w := WalkWorld.new([gate], func(f): return f == "open" and on[0])
	t.ok(w.blocked(0.5, 0.5, 0.2), "gate closed")
	on[0] = true
	t.ok(not w.blocked(0.5, 0.5, 0.2), "gate open")
	var ready := [false]
	var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
	var bus: Dictionary = Data.layout.features.filter(func(f): return f.id == "boat")[0]
	var w2 := WalkWorld.new(statics, func(f): return f == "boatReady" and ready[0])
	t.ok(not w2.blocked(bus.x, bus.z, 0.2), "no city bus yet: you can walk where it will stand")
	ready[0] = true
	t.ok(w2.blocked(bus.x, bus.z, 0.2), "once it's there, it's solid")
	t.ok(not w2.blocked(Data.layout.nav_nodes.dockStart[0], Data.layout.nav_nodes.dockStart[1], 0.3), "the stop beside it stays free")

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

func test_step_aside_when_a_villager_lands_on_you():
	# A villager sent home while you slept (or by loading a save) can be put right where you stand. Every step that
	# keeps you inside their body is refused, so you couldn't walk out; step_aside finds the nearest spot to move from.
	var w := WalkWorld.new([], func(_f): return false)
	var me := {"x": 10.0, "z": 5.0, "r": WalkWorld.PLAYER_RADIUS}
	var her := {"x": 10.45, "z": 5.0, "r": 0.32}
	w.dynamic = [me, her]
	var at := Vector3(10, w.surface_at(10, 5).y, 5)
	t.ok(not w.step_move(at, -0.1, 0.0, WalkWorld.PLAYER_RADIUS, me).moved, "inside her, even a step away from her is refused")
	var spot := w.step_aside(at, WalkWorld.PLAYER_RADIUS, me)
	t.ok(not spot.is_empty() and not w.blocked(spot.x, spot.z, spot.y, WalkWorld.PLAYER_RADIUS, me), "step_aside finds a free spot (%s)" % str(spot))
	t.ok(not spot.is_empty() and Vector2(spot.x - 10.0, spot.z - 5.0).length() < 1.0, "close by")
	t.ok(w.step_aside(Vector3(12, w.surface_at(12, 5).y, 5), WalkWorld.PLAYER_RADIUS, me).is_empty(), "with nobody on you, you stay put")

func test_unstick_after_stepping_off_the_side_of_a_stair():
	# a stair rising along z with an open side: step off it halfway up and you land beside it, still touching its edge
	var w := WalkWorld.new([], func(_f): return false)
	w.floors = [WorldStatics.floor_surface({"rect": [10.0, 0.0, 11.6, 10.0], "rise": [0.3, 3.5], "axis": "z", "bottom": 0.0})]
	var g: float = w.surface_at(9.85, 5.0).y
	var at := Vector3(9.85, g, 5.0)
	t.ok(w.blocked(at.x, at.z, at.y), "beside the stair at its foot's height, you're touching its side")
	t.ok(not w.step_move(at, -0.05, -0.1).moved, "and every short step that leaves you touching it is refused")
	var out := w.unstick(at)
	t.ok(not out.is_empty() and not w.blocked(out.x, out.z, at.y), "unstick finds a spot just clear of it (%s)" % str(out))
	t.ok(not out.is_empty() and out.x < 9.85 and absf(float(out.y) - g) < 0.01 and Vector2(out.x - at.x, out.z - at.z).length() <= 0.5, "beside you, on the ground, not up on the stair")
	t.ok(w.unstick(Vector3(8.0, w.surface_at(8.0, 5.0).y, 5.0)).is_empty(), "standing clear, you stay put")
