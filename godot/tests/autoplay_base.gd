extends Node
## Base for scripted playthroughs: sends real input events into the running game and records checks.
## Run: xvfb-run godot --path godot --audio-driver Dummy -- --autoplay=res://tests/play_xxx.gd --out=/tmp/dir (or play.sh)
## A scripted run is silent (the game mutes itself for --autoplay and --shot).

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

## A later place's playthrough starts where a real player would arrive (run it with --island=<id>): the earlier places'
## main stories played, with the approval, lire, plans and clothes they gave (Progress.as_if_played). Then play only
## this place. e.g. await arrive_as_if_played(["hearthglow"]) for a place Monteforchetta's bus line reaches.
func arrive_as_if_played(places: Array) -> void:
	game.load_state(Progress.as_if_played(places, Data.island, String(game.state.get("name", "Pip"))))
	await frames(20)

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

## Frames are only drawn for screenshots: on a machine with software rendering, drawing a frame takes about half a
## second and the game's own work a few milliseconds, so a playthrough that draws every frame spends nearly all its
## time drawing frames nobody looks at. play.sh runs the game with --fixed-fps 10, so every frame is 0.1 s of game time
## however long it takes to compute (the step the game caps a frame at anyway); what happens in play is unchanged.
## RENDER_ALL=1 (or --render) draws every frame, to watch a run or record it.
var draw_every_frame := false

func shot(name: String) -> void:
	shot_n += 1
	RenderingServer.render_loop_enabled = true
	await frames(3)   # two frames drawn with the world as it is now
	get_viewport().get_texture().get_image().save_png("%s/%02d-%s.png" % [out_dir, shot_n, name])
	RenderingServer.render_loop_enabled = draw_every_frame

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

## Board the ferry (E by the boat), pick an island on the map and sail; waits for the island to load. A place hidden
## from the map (the old Clockwork Cove) can't be picked, so tests reach it directly: a test-only route, not gameplay.
func sail(to: String) -> bool:
	if Data.island_def(to).get("hidden", false):
		game.panels.close(); await frames(4)
		game.travel(to)
		return await await_island(to)
	var mv: Control = game.panels.find_child("map_view", true, false)
	if mv == null: return false
	var isl: Dictionary = Data.island_def(to)
	await click(mv.get_global_rect().position + mv.call("to_screen", Vector2(isl.x, isl.y)))
	await frames(4)
	var b: Control = game.panels.find_child("sail", true, false)
	if b == null: return false
	await click(b.get_global_rect().get_center())
	return await await_island(to)

func finish() -> void:
	note("%d frames in %d s (%.0f frames a second, %d screenshots)" % [Engine.get_process_frames(), Time.get_ticks_msec() / 1000, Engine.get_process_frames() * 1000.0 / maxf(1.0, Time.get_ticks_msec()), shot_n])
	var fails := results.filter(func(r): return not r.ok).size()
	print("AUTOPLAY DONE: %d checks, %d failed" % [results.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)

func run(g) -> void:
	game = g
	out_dir = String(g.shot_cfg.get("out", "/tmp"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var limit := float(g.shot_cfg.get("limit", "900"))
	get_tree().create_timer(limit).timeout.connect(func(): print("AUTOPLAY TIMEOUT"); get_tree().quit(3))
	draw_every_frame = OS.get_environment("RENDER_ALL") == "1" or g.shot_cfg.has("render")
	RenderingServer.render_loop_enabled = draw_every_frame
	await frames(10)
	await play()
	finish()

func play() -> void:
	pass
