extends SceneTree

const DT := 1.0 / 30.0
const WALK_SPEED := 3.2

var out_dir := "/tmp/anim_reel"
var viewport: SubViewport
var camera: Camera3D
var who
var frame := 0
var time := 0.0

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var data: Node = root.get_node("Data")
	var chibi_script = load("res://scripts/world/chibi.gd")
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bfe3f5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9dcf0")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 4.0
	world.environment = env
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 50, 0)
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("9fb862")
	ground.material_override = gm
	viewport.add_child(ground)
	for i in 21:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.5 if i % 2 == 0 else 0.3, 0.12)
		post.mesh = box
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color("b8743f") if i % 2 == 0 else Color("cdc8bd")
		post.material_override = pm
		post.position = Vector3(-1.4, box.size.y / 2.0, -10.0 + i * 2.0)
		viewport.add_child(post)
	who = chibi_script.new(data.appearance["default"])
	viewport.add_child(who)
	camera = Camera3D.new()
	camera.fov = 32
	viewport.add_child(camera)
	camera.current = true
	await _play()
	print("anim reel: %d frames in %s" % [frame, out_dir])
	quit()

func _step(speed: float, yaw_rate: float = 0.0, airborne: bool = false) -> void:
	who.rotation.y += yaw_rate * DT
	var forward := Vector3(sin(who.rotation.y), 0.0, cos(who.rotation.y))
	who.position += forward * speed * WALK_SPEED * DT
	who.animate(DT, speed, airborne)
	camera.position = Vector3(who.position.x + 5.0, 1.3, who.position.z + 3.6)
	camera.look_at(Vector3(who.position.x, 0.75, who.position.z), Vector3.UP)
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("%s/%04d.png" % [out_dir, frame])
	frame += 1
	time += DT

func _hold(seconds: float, speed: float = 0.0, yaw_rate: float = 0.0) -> void:
	var n := int(round(seconds / DT))
	for i in n: await _step(speed, yaw_rate)

func _act(name: String, seconds: float) -> void:
	who.play(name)
	await _hold(seconds)

func _jump() -> void:
	var vy := 4.2
	var y := 0.0
	var first := true
	while first or y > 0.0:
		first = false
		vy -= 12.0 * DT
		y = maxf(0.0, y + vy * DT)
		who.position.y = y
		await _step(0.0, 0.0, y > 0.0)

func _play() -> void:
	who.position = Vector3(0, 0, -6.0)
	await _hold(1.0)
	await _hold(1.6, 1.0)
	await _hold(1.4)
	await _hold(1.2, 1.0, 1.3)
	await _hold(0.6, 1.0)
	await _hold(1.0)
	await _act("chop", 0.9)
	await _act("chop", 1.0)
	await _act("wave", 1.9)
	await _act("celebrate", 2.3)
	await _jump()
	await _hold(1.4)
