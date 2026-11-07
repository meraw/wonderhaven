extends RefCounted
## Checks on generated art meshes: faces point outward (or lighting and culling break) and shader limits hold.
var t

## Fraction of triangles whose generated normal points away from `center` (1.0 = all outward).
func _outward(mesh: Mesh, center: Vector3) -> float:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var good := 0
	for i in v.size():
		if n[i].dot(v[i] - center) > 0.0: good += 1
	return float(good) / maxf(1.0, v.size())

func test_canopy_and_bush_face_outward():
	t.ok(_outward(Foliage.canopy(0), Vector3.ZERO) > 0.95, "canopy normals point outward")
	t.ok(_outward(Foliage.canopy(1), Vector3.ZERO) > 0.95, "canopy variant normals point outward")
	t.ok(_outward(Foliage.bush(), Vector3(0, 0.3, 0)) > 0.9, "bush normals point outward")

func test_roof_faces_outward():
	# Top of the slab faces up, the underside (soffit) faces down: both visible with back-face culling.
	var roof: Mesh = Props.gable_roof_mesh(6.0, 5.0, 1.6, 0.45, 0.14)
	var arr := roof.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var top_ok := true; var under_ok := true; var tops := 0; var unders := 0
	for i in v.size():
		if absf(v[i].y - 1.74) < 0.001: tops += 1; top_ok = top_ok and (n[i].y > 0.3 or absf(n[i].x) > 0.9)
		if absf(v[i].y - 1.6) < 0.001 and absf(v[i].z) < 0.001: unders += 1; under_ok = under_ok and (n[i].y < -0.3 or absf(n[i].x) > 0.9)
	t.ok(tops > 0 and top_ok, "roof top faces up")
	t.ok(unders > 0 and under_ok, "roof underside faces down")

func test_paths_fit_terrain_shader():
	var n := 0
	for p in Data.layout.paths: n += p.size() - 1
	t.ok(n <= 32, "terrain shader has room for every path segment (%d)" % n)

func test_camera_stops_in_front_of_buildings():
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, -2), Vector3(4, 5, 4))]
	var east := Vector3(1, 0.2, 0).normalized()
	var d := c.clear_distance(Vector3(0, 1, 0), east, 10.0)
	t.ok(d < 4.0 and d >= FollowCamera.MIN_DIST, "camera stays in front of the wall (d=%.2f)" % d)
	t.eq(c.clear_distance(Vector3(0, 1, 0), Vector3(-1, 0.2, 0).normalized(), 10.0), 10.0, "unblocked view keeps its distance")
	t.ok(c.clear_distance(Vector3(0, 1, 0), Vector3(-1, -0.2, 0).normalized(), 10.0) < 6.0, "the ground blocks a view that dips into it")
	t.eq(c.clear_distance(Vector3(6, 1, 0), east, 10.0), 10.0, "inside a building (the workshop) that building doesn't block")
	t.ok(c.clear_distance(Vector3(3.8, 1, 0), east, 10.0) <= FollowCamera.MIN_DIST + 0.01, "right by the wall the camera comes in close instead of into the house")
	t.ok(c.blocked(Vector3(0, 1, 0), Vector3(10, 3, 0)) and not c.blocked(Vector3(0, 1, 0), Vector3(-10, 3, 0)), "blocked() agrees")
	var blockers := Props.camera_blockers()
	var towers: int = Data.layout.buildings.filter(func(b): return b.kind == "church").size()   # a church's bell tower gets a box of its own
	t.eq(blockers.size(), Data.layout.buildings.size() + towers, "one camera blocker per building (two for a church)")
	# the bell tower is tall, but the nave isn't: building in Elio's shop, north of the church, the camera can look over it
	for b in Data.layout.buildings.filter(func(b): return b.kind == "church"):
		var low := blockers.filter(func(x: AABB): return x.has_point(Vector3(b.x - b.w / 2.0 + 0.5, 7.5, b.z)))
		t.ok(low.is_empty(), "nothing blocks the camera above the nave at 7.5 m")
	var sp: Dictionary = Data.layout.spawn
	for b in blockers: t.ok(not (b as AABB).has_point(Vector3(sp.x, 1.0, sp.z)), "spawn point is outside every blocker")

func test_camera_near_a_wall_looking_away():
	# Walking along a house, a metre from its wall, with the camera looking out the other way: nothing is between, so
	# it keeps its distance (a side ray starting inside the wall's margin used to snap it onto your head).
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, -2), Vector3(4, 5, 4))]
	var away := c.clear_distance(Vector3(3.0, 1, 0), Vector3(-1, 0.3, 0).normalized(), 8.0)
	t.ok(away > 7.0, "a metre from the wall, looking away from it: the camera stays out (d=%.2f)" % away)
	var along := c.clear_distance(Vector3(3.1, 1, 0), Vector3(0, 0.3, 1).normalized(), 8.0)
	t.ok(along > 1.5, "looking along the wall: no snap onto your head (d=%.2f)" % along)
	# walking in through a door, the camera behind you can stay outside, looking in through the doorway
	c.rooms = [AABB(Vector3(10, -1, 0), Vector3(6, 3.6, 4))]   # a room x 10..16, z 0..4, its door in the south wall
	c.room_doors = [{"axis": "z", "at": 4.0, "g0": 12.4, "g1": 13.6}]
	var through := c.clear_distance(Vector3(13, 1, 3.5), FollowCamera._dir(0.0, 0.3), 7.0)
	t.ok(through > 4.0, "stepping in, the camera looks through the doorway (d=%.2f)" % through)
	var wall := c.clear_distance(Vector3(11, 1, 3.5), FollowCamera._dir(0.0, 0.3), 7.0)
	t.ok(wall < 1.0, "beside the door it still stops at the wall (d=%.2f)" % wall)

func test_camera_eases_out_and_never_tilts_itself():
	# In at once, out slowly: after a wall stops blocking, the camera takes a while to go back, without jumps.
	var d := FollowCamera.settle(9.0, 2.0, 1.0 / 60.0)
	t.eq(d, 2.0, "pulls in at once")
	var biggest := 0.0
	for i in 60:
		var nd := FollowCamera.settle(d, 9.0, 1.0 / 60.0); biggest = maxf(biggest, nd - d); d = nd
	t.ok(biggest < 0.3 and d > 4.0 and d < 9.0, "eases back out smoothly (largest step %.2f, after 1 s %.2f)" % [biggest, d])
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, -2), Vector3(4, 4, 4))]
	c.pitch = 0.3
	c.clamp_limits()
	t.eq(c.pitch, 0.3, "a house behind the player doesn't change the pitch the player chose")

func test_camera_never_ends_inside_walls():
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, -2), Vector3(4, 5, 4))]
	var p := c._outside_walls(Vector3(0, 1, 0), Vector3(5, 2, 0))
	t.ok(not (c.blockers[0] as AABB).grow(-0.35).has_point(p) and p.x < 4.4, "a point inside the walls is brought back out (x=%.2f)" % p.x)

func test_camera_stays_inside_a_room():
	var c := FollowCamera.new(null)
	c.rooms = [AABB(Vector3(0, -1, 0), Vector3(8, 3.6, 6))]   # walls up to y = 2.6
	var pivot := Vector3(4, 1, 3)
	var level := c.clear_distance(pivot, Vector3(1, 0.1, 0).normalized(), 9.0)
	t.ok(level < 4.0, "looking sideways, the camera stops inside the wall (d=%.2f)" % level)
	var steep := c.clear_distance(pivot, Vector3(0.3, 1.0, 0).normalized(), 9.0)
	t.ok(steep > 5.0, "looking down from above, it may rise out over the faded roof (d=%.2f)" % steep)
	var enterable: int = Data.layout.buildings.filter(func(b): return b.kind == "workshop" or Interiors.enterable(b)).size()
	t.eq(Props.camera_rooms().size(), enterable, "every building you can walk into is a camera room")

func test_indoor_cutaway_looks_over_the_walls():
	var c := FollowCamera.new(null)
	c.rooms = [AABB(Vector3(0, -1, 0), Vector3(8, 3.4, 6))]   # walls up to y = 2.4
	t.ok(absf(c.room_top_at(Vector3(4, 1, 3)) - 2.4) < 0.001, "inside the room the camera knows the wall height")
	t.eq(c.room_top_at(Vector3(-2, 1, 3)), -INF, "outside it isn't indoors")
	var pivot := Vector3(4, 1, 5.6)   # back against the south wall, camera looking from the south
	var usual := c.clear_distance(pivot, FollowCamera._dir(0.0, 0.5), 7.5)
	t.ok(usual < 1.0, "at the usual pitch the wall right behind pins the camera to the head (d=%.2f)" % usual)
	var p := c.wall_clear_pitch(pivot, 0.0)
	var over := c.clear_distance(pivot, FollowCamera._dir(0.0, p), 7.5)
	t.ok(p > FollowCamera.INDOOR_PITCH and over > 7.0, "the cutaway tilts down enough to rise over that wall (pitch %.2f, d=%.2f)" % [p, over])
	var hall := FollowCamera.new(null)
	hall.rooms = [AABB(Vector3(0, -0.1, 0), Vector3(8, 5.2, 6))]   # a throne room with walls 3.2 m above the head
	var door := Vector3(0.39, 1.9, 3)   # just inside the doorway, camera looking back out of it
	var hp := hall.wall_clear_pitch(door, -PI / 2)
	var hd := hall.clear_distance(door, FollowCamera._dir(-PI / 2, hp), 7.5)
	t.ok(hd > 7.0, "even in the doorway of a tall hall the view rises over the wall (pitch %.2f, d=%.2f)" % [hp, hd])
	var mid := c.wall_clear_pitch(Vector3(4, 1, 3), 0.0)
	t.ok(mid < FollowCamera.INDOOR_PITCH, "in the middle of the room the usual cutaway pitch already clears the walls (needs %.2f)" % mid)

func test_camera_rays_ignore_a_thin_miss():
	# A building just beside the line of sight still gets a little room thanks to the probe rays, so walking past
	# a corner doesn't make the camera flick in and out.
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, 0.1), Vector3(2, 5, 2))]   # starts 0.1 m to the side of the centre ray
	var d := c.clear_distance(Vector3(0, 1, 0), Vector3(1, 0, 0), 10.0)
	t.ok(d < 4.0, "the side probes catch a corner that the centre ray just misses (d=%.2f)" % d)

func test_character_lathes_face_outward():
	t.ok(_outward(Chibi._lathe("torso", Chibi.TORSO, 0.86), Vector3(0, 0.5, 0)) > 0.9, "torso normals point outward")
	t.ok(_outward(Chibi._lathe("leg", Chibi.LEG), Vector3(0, -0.12, 0)) > 0.9, "leg normals point outward")
	t.ok(_outward(Chibi._lathe("jeans_leg", Chibi.JEANS_LEG), Vector3(0, -0.12, 0)) > 0.9, "baggy jeans' normals point outward")

func test_face_follows_mood_and_blink():
	var c := Chibi.new({})
	var fm: ShaderMaterial = c.face_mat
	t.ok(fm != null, "characters have a painted face")
	c.set_mood("happy")
	t.eq(fm.get_shader_parameter("eye_mode"), 1, "happy shows ^^ eyes")
	t.eq(fm.get_shader_parameter("mouth"), 1, "happy shows a grin")
	c.set_mood("neutral"); c.blink_t = 0.1; c._refresh_face()
	t.eq(fm.get_shader_parameter("blink"), 1.0, "blinking closes the eyes")
	c.free()

func test_castle_hall_floor_is_level():
	# The throne room floor and its rugs sit just above the mound; the ground must not poke through anywhere inside.
	var castle: Dictionary = Data.layout.buildings.filter(func(b): return b.kind == "castle")[0]
	var worst_above := -INF; var worst_below := INF
	for i in 41:
		for k in 41:
			var x: float = castle.x - castle.w / 2.0 + castle.w * i / 40.0
			var z: float = castle.z - castle.d / 2.0 + castle.d * k / 40.0
			var h := Heightfield.height(x, z)
			worst_above = maxf(worst_above, h - Heightfield.CASTLE_MOUND.y)
			if Interiors.room(castle).has_point(Vector3(x, 0.0, z)): worst_below = minf(worst_below, h - Heightfield.CASTLE_MOUND.y)
	t.ok(worst_above < Props.CASTLE_FLOOR - 0.005, "no ground above the castle floor (highest %.3f m over the mound)" % worst_above)
	t.ok(worst_below > -0.001, "the throne room's ground is level with the mound (lowest %.3f)" % worst_below)

func test_villagers_pronouns_and_skin():
	# Every villager says whether they're he or she, so the interface never falls back to "they" for one person,
	# and the Italian villagers (everyone but Clockwork Cove's old cast) have fair to tan skin.
	for n in Data.npcs:
		t.ok(String(n.get("pronoun", "")) in ["he", "she"], "%s has a pronoun" % n.name)
		if Data.npc_island(n.id) == "clockwork": continue
		var c := Color(n.appearance.skin)
		t.ok(c.get_luminance() > 0.6, "%s's skin is fair or tan (%s)" % [n.name, n.appearance.skin])
	t.eq([Data.pron("captain"), Data.pron("captain", "them"), Data.pron("captain", "their")], ["he", "him", "his"], "Aldo: he, him, his")
	t.eq([Data.pron("mabel"), Data.pron("mabel", "them"), Data.pron("mabel", "their")], ["she", "her", "her"], "Ornella: she, her, her")

func test_the_cast_wear_their_own_clothes():
	# Each Monteforchetta villager's outfit is made of pieces that exist, so none falls back to the default look,
	# and every piece builds a character without errors.
	var A: Dictionary = Data.appearance
	for n in Data.npcs:
		if Data.npc_island(n.id) != "hearthglow": continue
		var app: Dictionary = n.appearance
		var kept := Chibi.sanitize(app)
		for k in ["top", "bottom", "shoes", "hat", "accessory"]:
			t.eq(kept[k], app[k], "%s keeps their %s (%s)" % [n.name, k, app[k]])
	for slot in [["top", "TOPS"], ["bottom", "BOTTOMS"], ["hat", "HATS"], ["accessory", "ACCESSORIES"]]:
		for piece in A[slot[1]]:
			var c := Chibi.new({slot[0]: piece})
			t.ok(c.body != null and c.body.get_child_count() > 4, "%s %s builds" % [slot[0], piece])
			c.free()
	# Rewards and unlock hints name real pieces.
	var all: Array = A.TOPS + A.BOTTOMS + A.SHOES + A.HATS + A.ACCESSORIES
	for k in A.locked: t.ok(all.has(k), "the unlock hint for %s is for a real piece" % k)
	for q in Data.quests:
		for c in q.get("rewards", {}).get("clothes", []): t.ok(all.has(c), "%s gives a real piece (%s)" % [q.id, c])
	for u in Data.harmony_unlocks:
		for c in u.get("clothes", []): t.ok(all.has(c), "the %d milestone gives a real piece (%s)" % [int(u.at), c])
	t.eq(A.default.top, "windbreaker", "the new Geometra arrives in a windbreaker")

func test_materials_are_physically_based_with_the_chosen_textures():
	t.ok(Palette.real, "the game uses physically based materials (pass --look=painted for the old look)")
	var plaster := Palette.plaster("d9a65a")
	t.eq(plaster.specular_mode, BaseMaterial3D.SPECULAR_SCHLICK_GGX, "plaster has real specular")
	t.ok(plaster.normal_enabled and plaster.albedo_texture != null and plaster.roughness_texture != null, "plaster has the stucco maps")
	t.ok(plaster.uv1_triplanar, "maps are projected without UVs")
	for kind in Palette.REAL_TEX:
		var spec: Array = Palette.REAL_TEX[kind]
		for map in ["albedo", "normal", "rough"]:
			t.ok(Palette.material_texture("%s_%s" % [spec[0], map]) != null, "%s %s map is imported" % [spec[0], map])
	t.ok(Palette.mat("8a8a8a").normal_texture == null, "plain-colour parts stay untextured")
	t.ok(Palette.shader_code("render_mode diffuse_lambert_wrap, specular_disabled;").contains("specular_schlick_ggx"), "custom shaders switch to real specular")

func test_realistic_materials_get_a_warm_ambient_fill():
	t.ok(Palette.ambient_gain() > 1.0, "the ambient light is stronger with realistic materials")
	var c := Palette.ambient_color(Color("c9dcf0"), Color("fff0d8"))
	t.ok(c.r > Color("c9dcf0").r and c.b < Color("c9dcf0").b, "and leans toward the sun's colour")
	t.ok(Palette.mat("8a8a8a").metallic_specular < 0.5, "rough surfaces reflect less of the sky")
