extends Node
## Base for scripted playthroughs: sends real input events into the running game and records checks.
## Run: xvfb-run godot --path godot -- --autoplay=res://tests/play_xxx.gd --out=/tmp/dir

var game
var results: Array = []
var out_dir := "/tmp"
var shot_n := 0

var _ctrl := false
func key(code: int, pressed: bool) -> void:
	if code == KEY_CTRL: _ctrl = pressed
	var ev := InputEventKey.new(); ev.physical_keycode = code; ev.keycode = code; ev.pressed = pressed; ev.ctrl_pressed = _ctrl
	Input.parse_input_event(ev)

func tap(code: int) -> void:
	key(code, true); await frames(2); key(code, false); await frames(2)

func hold(code: int, seconds: float) -> void:
	key(code, true); await wait(seconds); key(code, false); await frames(1)

func mouse_move(p: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	Input.warp_mouse(p)
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
	note(("PASS " if ok else "FAIL ") + "[%s] %s — %s" % [str(id), label, detail])

## A progress line, written straight to <out>/progress.log (the console output is buffered until the end).
func note(msg: String) -> void:
	var f := FileAccess.open(out_dir + "/progress.log", FileAccess.READ_WRITE if FileAccess.file_exists(out_dir + "/progress.log") else FileAccess.WRITE)
	if f == null: return
	f.seek_end(); f.store_line("%s  %s" % [Time.get_time_string_from_system(), msg]); f.close()

func shot(name: String) -> void:
	shot_n += 1
	await frames(2)
	get_viewport().get_texture().get_image().save_png("%s/%02d-%s.png" % [out_dir, shot_n, name])

## After sailing, the scene reloads with the new island. Waits for it, then follows the new game.
func await_island(id: String, max_s: float = 90.0) -> bool:
	var old_id: int = game.get_instance_id()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		await frames(2)
		var cur = get_tree().current_scene
		if cur != null and cur.get_instance_id() != old_id and cur.get("started") == true and Data.island == id:
			game = cur
			await frames(20)
			return true
	return false

## Board the ferry (E by the boat), pick an island on the map and sail; waits for the island to load.
func sail(to: String) -> bool:
	var mv: Control = game.panels.find_child("map_view", true, false)
	if mv == null: return false
	var isl: Dictionary = Data.island_def(to)
	await click(mv.get_global_rect().position + Vector2(isl.x, isl.y) * (mv.size / Vector2(800, 500)))
	await frames(4)
	var b: Control = game.panels.find_child("sail", true, false)
	if b == null: return false
	await click(b.get_global_rect().get_center())
	return await await_island(to)

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
