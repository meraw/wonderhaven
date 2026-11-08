extends SceneTree

const OUT_DIR := "res://assets/icons/pieces"
const RENDER := 512
const MARGIN := 0.08
const SIZE := 128
const VIEW_DIR := Vector3(1.0, 0.85, 1.35)

var viewport: SubViewport
var holder: Node3D
var camera: Camera3D
var pieces_script
var data: Node

func _initialize() -> void:
	await process_frame
	data = root.get_node("Data")
	pieces_script = load("res://scripts/build/piece_meshes.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	viewport = SubViewport.new()
	viewport.size = Vector2i(RENDER, RENDER)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9dcf0")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 4.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	world.environment = env
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.05
	sun.light_color = Color("fff1d6")
	sun.rotation_degrees = Vector3(-48, 30, 0)
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color("cfe0ff")
	fill.rotation_degrees = Vector3(-20, -150, 0)
	viewport.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	if Outline.supported():
		var ol := Outline.create()
		camera.add_child(ol)
		(ol.material_override as ShaderMaterial).set_shader_parameter("width", 3.0)
		(ol.material_override as ShaderMaterial).set_shader_parameter("fade_start", 1000.0)
		(ol.material_override as ShaderMaterial).set_shader_parameter("fade_end", 2000.0)
		(ol.material_override as ShaderMaterial).set_shader_parameter("water_y", -1000.0)
	holder = Node3D.new()
	viewport.add_child(holder)
	_render_all()

func _render_all() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.trim_prefix("--only=")
	var done := 0
	for p in data.pieces:
		var id := String(p.id)
		if only != "" and not only.split(",").has(id): continue
		await _render(id)
		done += 1
	print("rendered %d piece icons into %s" % [done, OUT_DIR])
	quit()

func _render(id: String) -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	var piece: Node3D = pieces_script.make(id)
	holder.add_child(piece)
	await process_frame
	var box := _bounds(piece)
	var centre := box.get_center()
	var dir := VIEW_DIR.normalized()
	var radius := maxf(box.size.length() * 0.5, 0.2)
	camera.size = radius * 2.15
	camera.near = 0.01
	camera.far = radius * 8.0 + 10.0
	camera.position = centre + dir * (radius * 3.0 + 2.0)
	camera.look_at(centre, Vector3.UP)
	for i in 6: await process_frame
	var img := viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var side := int(ceil(maxf(used.size.x, used.size.y) * (1.0 + MARGIN * 2.0)))
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	square.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	square.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	square.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, id]))

func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		if not vi.visible: continue
		var b := vi.global_transform * vi.get_aabb()
		if b.size.length() < 0.0001: continue
		if first: box = b; first = false
		else: box = box.merge(b)
	if first: box = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	return box
