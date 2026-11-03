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
	t.eq(blockers.size(), Data.layout.buildings.size(), "one camera blocker per building")
	var sp: Dictionary = Data.layout.spawn
	for b in blockers: t.ok(not (b as AABB).has_point(Vector3(sp.x, 1.0, sp.z)), "spawn point is outside every blocker")

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
