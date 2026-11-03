extends RefCounted
## Builds the look-dev scene for tests/lookdev.gd.

func run(tree: SceneTree, args: Dictionary) -> void:
	var root := tree.root
	Chibi.face_style = args.get("face", "bean")
	var world := Node3D.new(); root.add_child(world)
	var env := TerrainBuilder.build_environment(); world.add_child(env)
	env.environment.ambient_light_energy = 0.4
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 0.62; sun.light_color = Color("fff1d6")
	sun.rotation_degrees = Vector3(-50, 35, 0); sun.directional_shadow_blend_splits = true; sun.shadow_blur = 1.5; sun.light_angular_distance = 1.2
	world.add_child(sun)
	var village := Village.new(); world.add_child(village); village.build(WorldStatics.generate_decor())
	var cam := Camera3D.new(); cam.fov = 30; world.add_child(cam); cam.current = true
	if args.get("outline", "1") == "1" and Outline.supported():
		var ol := Outline.create(); cam.add_child(ol); (ol.material_override as ShaderMaterial).set_shader_parameter("width", 1.2)
	var cast: Array = [Data.appearance["default"]]
	for n in Data.npcs: cast.append(n.appearance)
	var chars: Array = []
	var view: String = args.get("view", "lineup")
	if view == "close":
		var pick := [0, 2, 6, 3]
		for i in pick.size():
			var c := Chibi.new(cast[pick[i]]); world.add_child(c)
			c.position = Vector3(-1.3 + i * 0.86, 0, 5.0); c.rotation.y = (i - 1.5) * -0.12
			chars.append(c)
		cam.fov = 24
		cam.position = Vector3(0, 1.45, 8.2); cam.look_at(Vector3(0, 0.95, 5.0))
	elif view == "lineup":
		for i in cast.size():
			var c := Chibi.new(cast[i]); world.add_child(c)
			c.position = Vector3(-3.15 + i * 0.9, 0, 5.0); c.rotation.y = (i - 3.5) * -0.06
			chars.append(c)
		cam.fov = 34
		cam.position = Vector3(0, 1.35, 11.6); cam.look_at(Vector3(0, 0.75, 5.0))
	else:
		var moods := ["neutral", "blink", "happy", "surprised", "talk", "sad"]
		for i in moods.size():
			var c := Chibi.new(cast[0]); world.add_child(c)
			c.position = Vector3(-1.85 + i * 0.74, 0, 5.0)
			match moods[i]:
				"blink": c.blink_t = 1.0
				"happy": c.mood = "happy"
				"surprised": c.mood = "surprised"
				"sad": c.mood = "sad"
				"talk": c.talking = true; c.t = 0.15
			chars.append(c)
		cam.fov = 28
		cam.position = Vector3(0, 1.3, 10.6); cam.look_at(Vector3(0, 0.95, 5.0))
	for c in chars:
		c.animate(0.0)
		c._refresh_face()
	for i in 45: await tree.process_frame
