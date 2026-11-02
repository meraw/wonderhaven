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
	var p := c._avoid_blockers(Vector3(0, 1, 0), Vector3(10, 3, 0))
	t.ok(p.x < 4.0 and p.x > 1.0, "camera pulled in front of the wall (x=%.2f)" % p.x)
	var free := c._avoid_blockers(Vector3(0, 1, 0), Vector3(-10, 3, 0))
	t.ok(free.is_equal_approx(Vector3(-10, 3, 0)), "unblocked camera untouched")
	var inside := c._avoid_blockers(Vector3(6, 1, 0), Vector3(16, 3, 0))
	t.ok(inside.is_equal_approx(Vector3(16, 3, 0)), "target inside a building (workshop) ignores that box")
	var by_door := c._avoid_blockers(Vector3(3.8, 1, 0), Vector3(12, 3, 0))
	t.ok(by_door.x < 4.0, "target standing right by the wall still keeps the camera out of the house (x=%.2f)" % by_door.x)
	var blockers := Props.camera_blockers()
	t.eq(blockers.size(), Data.layout.buildings.size(), "one camera blocker per building")
	var sp: Dictionary = Data.layout.spawn
	for b in blockers: t.ok(not (b as AABB).has_point(Vector3(sp.x, 1.0, sp.z)), "spawn point is outside every blocker")

func test_camera_rises_over_a_house_behind_the_player():
	var c := FollowCamera.new(null)
	c.blockers = [AABB(Vector3(4, 0, -2), Vector3(4, 4, 4))]
	var lift := c._lift_needed(Vector3(0, 1, 0), PI / 2, 0.3, 9.0)   # camera looking from +x, house in between
	t.ok(lift > 0.0 and lift < 1.2, "camera lifts above the roof (lift=%.2f)" % lift)
	t.eq(c._lift_needed(Vector3(0, 1, 0), -PI / 2, 0.3, 9.0), 0.0, "no lift when the view is clear")
