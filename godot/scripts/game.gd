extends Node3D
## The game: owns the scene, systems and modes, and runs the main loop.

var decor: Dictionary
var statics: Array
var walk: WalkWorld
var village: Village
var effects: Effects
var player_char: Chibi
var player: PlayerController
var cam: FollowCamera
var camera: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var ui: CanvasLayer
var theme_res: Theme
var prompt_panel: PanelContainer
var prompt_label: Label
var hotkeys: Label
var state: Dictionary = {"flags": {}}
var mode := "explore"
var time := 0.0
var interactables: Array = []
var target = null
var dragging := false
var shot_cfg := {}

func _ready() -> void:
	Controls.setup()
	theme_res = UiTheme.build()
	decor = WorldStatics.generate_decor()
	statics = WorldStatics.build_statics(decor)
	walk = WalkWorld.new(statics, func(f): return state.flags.get(f, false))
	env = TerrainBuilder.build_environment(); add_child(env)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 0.62; sun.light_color = Color("fff1d6")
	sun.directional_shadow_max_distance = 60.0; sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	village = Village.new(); village.name = "Village"; add_child(village); village.build(decor)
	effects = Effects.new(); add_child(effects)
	player_char = Chibi.new(Data.appearance["default"]); player_char.name = "Player"; add_child(player_char)
	var sp: Dictionary = Data.layout.spawn
	player = PlayerController.new(player_char, walk, sp.x, sp.z, sp.yaw)
	walk.dynamic.append(player.body)
	camera = Camera3D.new(); camera.fov = 45; camera.far = 500; add_child(camera); camera.current = true
	cam = FollowCamera.new(camera)
	_build_ui()
	_register_world_interactables()
	_parse_args()
	cam.update(0.016, player.pos); cam.snap()
	if shot_cfg.has("autoplay"):
		var script: Script = load(shot_cfg.autoplay)
		if script == null or not script.can_instantiate():
			push_error("Autoplay script failed to load: %s" % shot_cfg.autoplay); get_tree().quit(2); return
		var runner = script.new()
		add_child(runner)
		runner.call_deferred("run", self)

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_res; root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	prompt_panel = UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 999)
	prompt_label = UiTheme.label("", 18)
	prompt_panel.add_child(prompt_label)
	var pc := CenterContainer.new(); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.anchor_left = 0; pc.anchor_right = 1; pc.anchor_top = 1; pc.anchor_bottom = 1; pc.offset_top = -150; pc.offset_bottom = -100
	pc.add_child(prompt_panel); prompt_panel.visible = false
	root.add_child(pc)
	var hk := UiTheme.panel()
	hotkeys = UiTheme.label("", 13, UiTheme.INK2)
	hk.add_child(hotkeys)
	hk.anchor_top = 1; hk.anchor_bottom = 1; hk.offset_left = 14; hk.offset_top = -56; hk.offset_bottom = -14; hk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hk)
	set_meta("ui_root", root)

func add_interactable(rec: Dictionary) -> void:
	var r := {"radius": 1.8, "priority": 0.0, "available": func(): return true}
	r.merge(rec, true)
	interactables.append(r)

func _register_world_interactables() -> void:
	for f in Data.layout.features:
		if f.kind == "sign":
			var text: String = f.text
			add_interactable({"id": f.id, "x": f.x, "z": f.z, "object": village.objects[f.id], "label": func(): return "Read sign", "act": func(): toast(text)})

func toast(text: String) -> void:
	print("[toast] ", text)

func _pos_of(it: Dictionary, key: String) -> float:
	var v = it[key]
	return v.call() if v is Callable else v

func find_target():
	var p := player.pos
	var fwd := player.forward()
	var best = null
	var best_score := INF
	for it in interactables:
		if not it.available.call(): continue
		var dx := _pos_of(it, "x") - p.x
		var dz := _pos_of(it, "z") - p.z
		var d := sqrt(dx * dx + dz * dz)
		if d > it.radius + 0.6: continue
		var facing := (dx * fwd.x + dz * fwd.y) / d if d > 0.01 else 1.0
		if d > 1.0 and facing < 0.1: continue
		var score: float = d - facing * 0.8 - it.priority
		if score < best_score: best_score = score; best = it
	return best

func _set_highlight(obj, on: bool) -> void:
	if obj == null or not is_instance_valid(obj): return
	for m in obj.find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if not mat is StandardMaterial3D: continue
		if on:
			if not m.has_meta("orig_mat"):
				m.set_meta("orig_mat", mat)
				var c: StandardMaterial3D = mat.duplicate()
				c.emission_enabled = true; c.emission = Color("ffd98a"); c.emission_energy_multiplier = 0.35
				m.material_override = c
		elif m.has_meta("orig_mat"):
			m.material_override = m.get_meta("orig_mat"); m.remove_meta("orig_mat")

func _update_interaction() -> void:
	var prev = target
	target = find_target() if mode == "explore" else null
	if prev != null and prev != target: _set_highlight(prev.get("object"), false)
	if target != null:
		_set_highlight(target.get("object"), true)
		prompt_label.text = "[%s]  %s" % [Controls.key_label("interact"), target.label.call()]
		prompt_panel.visible = true
		if Input.is_action_just_pressed("interact"): target.act.call()
	else:
		prompt_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] or (event.button_index == MOUSE_BUTTON_LEFT and mode == "explore"):
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: cam.zoom(-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam.zoom(1)
	if event is InputEventMouseMotion and dragging:
		cam.rotate_by(event.relative.x * 0.0055, event.relative.y * 0.0055)

func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return v

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	time += dt
	if Input.is_action_pressed("cam_left"): cam.yaw += 1.8 * dt
	if Input.is_action_pressed("cam_right"): cam.yaw -= 1.8 * dt
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.15: cam.rotate_by(look.x * 2.4 * dt, look.y * 1.6 * dt)
	if mode == "explore":
		player.update(dt, move_vector(), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), cam.move_yaw(), true)
	cam.update(dt, player.pos)
	_update_interaction()
	hotkeys.text = "%s %s %s %s Move   Drag / %s %s Camera   Wheel Zoom   %s Interact   %s Hop" % [Controls.key_label("move_forward"), Controls.key_label("move_left"), Controls.key_label("move_back"), Controls.key_label("move_right"), Controls.key_label("cam_left"), Controls.key_label("cam_right"), Controls.key_label("interact"), Controls.key_label("jump")]
	village.update_world(dt, time, state.flags)
	sun.position = player.pos
	_tick_shot()

# ---- Command-line hooks for automated screenshots: godot --path godot -- --shot=out.png --pos=x,z,yaw --cam=yaw,pitch,dist --frames=N
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		shot_cfg[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if shot_cfg.has("pos"):
		var p: PackedStringArray = String(shot_cfg.pos).split(",")
		player.teleport(float(p[0]), float(p[1]), float(p[2]) if p.size() > 2 else null)
	if shot_cfg.has("cam"):
		var c: PackedStringArray = String(shot_cfg.cam).split(",")
		cam.yaw = float(c[0]); cam.pitch = float(c[1]); cam.dist = float(c[2])
		cam.limits.explore = [2.0, 120.0, 0.05, 1.5]

var _frames := 0
func _tick_shot() -> void:
	if not shot_cfg.has("shot"): return
	_frames += 1
	if _frames == int(shot_cfg.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(shot_cfg.shot)
		get_tree().quit()
