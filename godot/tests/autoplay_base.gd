extends Node
## Base for scripted playthroughs: sends real input events into the running game and records checks.
## Run: xvfb-run godot --path godot -- --autoplay=res://tests/play_xxx.gd --out=/tmp/dir

var game
var results: Array = []
var out_dir := "/tmp"
var shot_n := 0

func key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = code; ev.keycode = code; ev.pressed = pressed
	Input.parse_input_event(ev)

func tap(code: int) -> void:
	key(code, true); await frames(2); key(code, false); await frames(2)

func hold(code: int, seconds: float) -> void:
	key(code, true); await wait(seconds); key(code, false); await frames(1)

func mouse_move(p: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var ev := InputEventMouseMotion.new(); ev.position = p; ev.global_position = p; ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if _rdown else 0
	Input.parse_input_event(ev)

var _rdown := false
func mouse_button(p: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new(); ev.position = p; ev.global_position = p; ev.button_index = button; ev.pressed = pressed
	if button == MOUSE_BUTTON_RIGHT: _rdown = pressed
	Input.parse_input_event(ev)

func click(p: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	mouse_move(p); await frames(2); mouse_button(p, button, true); await frames(2); mouse_button(p, button, false); await frames(2)

func wait(seconds: float) -> void: await get_tree().create_timer(seconds).timeout
func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func check(id, label: String, ok: bool, detail: String = "") -> void:
	results.append({"id": id, "label": label, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL "), "[", id, "] ", label, " — ", detail)

func shot(name: String) -> void:
	shot_n += 1
	await frames(2)
	get_viewport().get_texture().get_image().save_png("%s/%02d-%s.png" % [out_dir, shot_n, name])

func finish() -> void:
	var fails := results.filter(func(r): return not r.ok).size()
	print("AUTOPLAY DONE: %d checks, %d failed" % [results.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)

func run(g) -> void:
	game = g
	out_dir = String(g.shot_cfg.get("out", "/tmp"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var limit := float(g.shot_cfg.get("limit", "900"))
	get_tree().create_timer(limit).timeout.connect(func(): print("AUTOPLAY TIMEOUT"); get_tree().quit(3))
	await frames(10)
	await play()
	finish()

func play() -> void:
	pass
