extends Node3D
## The game: owns the scene, systems and modes, and runs the main loop.

signal game_event(type: String, data: Dictionary)

var settings: Dictionary
var state: Dictionary
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
var ui_root: Control
var hud: Hud
var toasts: VBoxContainer
var hud_res: HBoxContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var hotkeys: Label
var hotkey_row: HBoxContainer
var banner_box: VBoxContainer
var dialogue: DialogueUI
var minigame: MinigameUI
var panels: Panels
var build: BuildMode
var story: Story
var actions: WorldActions
var screens = null
var audio = null
var npcs: Dictionary = {}
var piece_root := Node3D.new()
var piece_nodes: Dictionary = {}
var mech: Dictionary = {"powered": {}, "watered": {}, "pumps": {}, "sources": {}, "fed": {}, "lamps": {}, "fountains": {}}
var interactables: Array = []
var target = null
var mode := "explore"
var time := 0.0
var started := false
var sitting := {}
var dragging := false
var drag_moved := false
var _drag_dist := 0.0
var rain: GPUParticles3D
var smoke_t := 0.0
var last_autosave := -100.0
var shot_cfg := {}
var roof_alpha := 1.0   # the workshop's roof (kept for tests)
var roof_fade: Dictionary = {}   # building id -> roof opacity
var guide: Guide
var nap_gags: NapGags
var outline: MeshInstance3D
var outline_override := ""   # look-dev renders force outlines on or off without touching saved settings
var interact_cooldown := 0.0

func _ready() -> void:
	settings = SaveSystem.load_settings()
	for a in OS.get_cmdline_user_args():   # look-dev overrides, read before any character is built
		if a.begins_with("--face="): Chibi.face_style = a.trim_prefix("--face=")
		if a.begins_with("--outline="): outline_override = a.trim_prefix("--outline=")
	Controls.setup(settings.bindings)
	# Arriving from another island (or loading a save made on one): the state came across the scene reload.
	var arriving: Dictionary = Data.pending_state
	Data.pending_state = {}
	var start_island := "hearthglow"   # --island=<id> starts there (screenshots, playthrough tests)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--island=") and Data.has_island(a.trim_prefix("--island=")): start_island = a.trim_prefix("--island=")
	if arriving.is_empty() and Data.island != start_island: Data.use_island(start_island)
	state = arriving if not arriving.is_empty() else GameState.new_game()
	if arriving.is_empty() and start_island != "hearthglow":
		var sp0: Dictionary = Data.layout.spawn
		state.island = start_island; state.player = {"x": sp0.x, "z": sp0.z, "yaw": sp0.yaw}
		state.tutorial = Tutorial.new_state(false, true)
	Data.apply_world_flags(state.flags)   # the place as the story has left it (a location's WORLD_FLAGS)
	decor = WorldStatics.generate_decor()
	statics = WorldStatics.build_statics(decor)
	walk = WalkWorld.new(statics, func(f): return state.flags.get(f, false))
	walk.floors = WorldStatics.floors()   # balconies, roof terraces and decks from the layout
	env = TerrainBuilder.build_environment(); add_child(env)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 0.62; sun.light_color = Color("fff1d6")
	sun.directional_shadow_max_distance = 70.0; sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.directional_shadow_blend_splits = true; sun.shadow_blur = 1.5; sun.shadow_opacity = 0.85; sun.light_angular_distance = 1.2
	add_child(sun)
	village = Village.new(); village.name = "Village"; add_child(village); village.build(decor)
	effects = Effects.new(); add_child(effects)
	nap_gags = NapGags.new(); nap_gags.name = "NapGags"; add_child(nap_gags); nap_gags.setup(self)
	player_char = Chibi.new(state.appearance); player_char.name = "Player"; player_char.vis_layer = 2; add_child(player_char); player_char.apply_layer()
	var sp: Dictionary = Data.layout.spawn
	player = PlayerController.new(player_char, walk, sp.x, sp.z, sp.yaw)
	walk.dynamic.append(player.body)
	camera = Camera3D.new(); camera.fov = 45; camera.far = 500; add_child(camera); camera.current = true
	if Outline.supported():
		outline = Outline.create(); camera.add_child(outline); _apply_outline()
		get_viewport().size_changed.connect(_fit_outline); _fit_outline()
	cam = FollowCamera.new(camera)
	cam.blockers = Props.camera_blockers()
	cam.rooms = Props.camera_rooms()
	cam.occluders = village.occluders
	piece_root.name = "Placements"; add_child(piece_root)
	_build_ui()
	build = BuildMode.new(); build.name = "BuildMode"; add_child(build); build.setup(self)
	story = Story.new(self)
	guide = Guide.new(self)
	for d in Data.npcs_here():
		var a := NpcAgent.new(self, d)
		npcs[d.id] = a
		var ag := a
		add_interactable({"id": "npc:" + d.id, "x": func(): return ag.pos.x, "z": func(): return ag.pos.z, "radius": 1.9, "priority": 0.6, "object": null,
			"available": func(): return ag.present, "label": func(): return "Talk to " + ag.def.name, "act": func(): story.talk(ag)})
	for f in Data.layout.features:
		if f.kind == "sign":
			var text: String = f.text
			add_interactable({"id": f.id, "x": f.x, "z": f.z, "object": village.objects[f.id], "label": func(): return "Read sign", "act": func(): toast(text, "", 4.0)})
	actions = WorldActions.new(self)
	_make_rain()
	_load_optional_modules()
	apply_settings()
	_parse_args()
	cam.update(0.016, player.pos); cam.snap()
	_update_world_time(0.0)   # the sky, light and fog for the hour from the first frame (the title screen doesn't tick the clock)
	if not arriving.is_empty():
		load_state(state)
		begin_play()
		if Data.rebuilding: Data.rebuilding = false; cam.update(0.016, player.pos); cam.snap(); _fade(false)   # rebuilt where you stand
		else: _arrived()
	elif screens and ((not shot_cfg.has("autoplay") and not shot_cfg.has("skiptitle")) or shot_cfg.has("title")): screens.title()
	else: begin_play()
	if shot_cfg.has("autoplay") and not Data.autoplay_started:
		Data.autoplay_started = true
		var script: Script = load(shot_cfg.autoplay)
		if script == null or not script.can_instantiate(): push_error("Autoplay script failed to load"); get_tree().quit(2); return
		# The runner lives beside the game scene, so it keeps going when sailing reloads the scene.
		var runner = script.new(); get_tree().root.add_child.call_deferred(runner); runner.call_deferred("run", self)

func _load_optional_modules() -> void:
	if ResourceLoader.exists("res://scripts/ui/screens.gd"):
		screens = load("res://scripts/ui/screens.gd").new(); screens.name = "Screens"; ui_root.add_child(screens); screens.setup(self)
	if ResourceLoader.exists("res://scripts/audio/audio_director.gd"):
		audio = load("res://scripts/audio/audio_director.gd").new(); audio.name = "Audio"; add_child(audio)
	if ResourceLoader.exists("res://scripts/world/animals.gd"):
		var an = load("res://scripts/world/animals.gd").new(); an.name = "Animals"; add_child(an); an.setup(self)
	if ResourceLoader.exists("res://scripts/world/atmosphere.gd"):
		var at = load("res://scripts/world/atmosphere.gd").new(); add_child(at); at.setup(self)

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	ui_root = Control.new(); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.theme = UiTheme.build(); ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	hud = Hud.new(); hud.name = "Hud"; ui_root.add_child(hud); hud.setup(self)
	var rp := UiTheme.panel(); rp.position = Vector2(14, 14); rp.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(rp)
	hud_res = HBoxContainer.new(); hud_res.add_theme_constant_override("separation", 8); rp.add_child(hud_res)
	prompt_panel = UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 999); prompt_label = UiTheme.label("", 18); prompt_panel.add_child(prompt_label)
	var pc := CenterContainer.new(); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.anchor_right = 1; pc.anchor_top = 1; pc.anchor_bottom = 1; pc.offset_top = -150; pc.offset_bottom = -100
	pc.add_child(prompt_panel); prompt_panel.visible = false; ui_root.add_child(pc)
	var hk := UiTheme.panel(); hk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey_row = HBoxContainer.new(); hotkey_row.add_theme_constant_override("separation", 12); hk.add_child(hotkey_row)
	hotkeys = UiTheme.label("", 13, UiTheme.INK2); hotkeys.visible = false; hotkey_row.add_child(hotkeys)   # plain-text copy of the bar
	hk.anchor_top = 1; hk.anchor_bottom = 1; hk.offset_left = 14; hk.offset_top = -56; hk.offset_bottom = -14; hk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(hk)
	toasts = VBoxContainer.new(); toasts.anchor_left = 0.5; toasts.anchor_right = 0.5; toasts.offset_left = -300; toasts.offset_right = 300; toasts.offset_top = 72
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui_root.add_child(toasts)
	banner_box = VBoxContainer.new(); banner_box.anchor_right = 1; banner_box.anchor_top = 0.22; banner_box.anchor_bottom = 0.22; banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui_root.add_child(banner_box)
	dialogue = DialogueUI.new(); ui_root.add_child(dialogue); dialogue.setup(self)
	minigame = MinigameUI.new(); ui_root.add_child(minigame); minigame.setup(self)
	panels = Panels.new(); ui_root.add_child(panels); panels.setup(self)

# ---- Feedback ------------------------------------------------------------------------------------
func toast(text: String, kind: String = "", life: float = 2.8) -> void:
	print("[toast] ", text)
	var bg := Color("effff4") if kind == "good" else (Color("fff0f0") if kind == "warn" else UiTheme.CREAM)
	var bd := Color("9fe0b5") if kind == "good" else (Color("ffb3b3") if kind == "warn" else UiTheme.LINE)
	var p := UiTheme.panel(bg, bd, 999)
	var l := UiTheme.label(text, 15, Color("2f8a52") if kind == "good" else (Color("b34a4a") if kind == "warn" else UiTheme.INK))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if text.length() > 70: l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 560
	p.add_child(l); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new(); c.add_child(p); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(c)
	while toasts.get_child_count() > 5: var old := toasts.get_child(0); toasts.remove_child(old); old.queue_free()
	var tw := create_tween(); tw.tween_interval(life); tw.tween_property(c, "modulate:a", 0.0, 0.4); tw.tween_callback(c.queue_free)

func banner(title: String, sub: String = "", rewards: Array = [], seconds: float = 3.2) -> void:
	print("[banner] ", title, " — ", sub)
	for c in banner_box.get_children(): c.queue_free()
	var t := UiTheme.label(title, 44, Color.WHITE); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", UiTheme.PINK_DARK); t.add_theme_constant_override("outline_size", 14)
	banner_box.add_child(t)
	if sub != "":
		var sl := UiTheme.label(sub, 20); sp_wrap(sl)
		var sp := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 999 if sub.length() <= 70 else 24); sp.add_child(sl)
		var cc := CenterContainer.new(); cc.add_child(sp); banner_box.add_child(cc)
	if not rewards.is_empty():
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER
		for r in rewards: var rp := UiTheme.panel(Color("fff7cf"), UiTheme.GOLD, 999); rp.add_child(UiTheme.label(r, 13)); row.add_child(rp)
		banner_box.add_child(row)
	banner_box.scale = Vector2(0.3, 0.3); banner_box.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x / 2.0, 40)
	var tw := banner_box.create_tween(); tw.tween_property(banner_box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds); tw.tween_property(banner_box, "modulate:a", 0.0, 0.4); tw.tween_callback(func(): for c in banner_box.get_children(): c.queue_free())
	banner_box.modulate.a = 1.0

## A long banner subtitle wraps onto a few centred lines instead of running off the screen.
static func sp_wrap(l: Label) -> void:
	if l.text.length() <= 70: return
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 640; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func emit_event(type: String, data: Dictionary = {}) -> void: game_event.emit(type, data)
func sfx(name: String) -> void: if audio: audio.sfx(name)
func voice(pitch: float, syllables: int) -> void: if audio: audio.voice(pitch, syllables)

func render_resources(pop: Array = []) -> void:
	for c in hud_res.get_children(): hud_res.remove_child(c); c.queue_free()   # remove first so new chips keep their names
	for id in Data.resource_order:
		var n: int = int(state.inventory.get(id, 0))
		var money: bool = id == "coins"   # always shown, in gold
		if not money and n <= 0: continue
		var chip := UiTheme.panel(Color("fff7cf") if money else Color.WHITE, UiTheme.GOLD if money else Color("f3dfc0"), 999)
		chip.name = "res_" + id
		chip.add_child(UiTheme.label(("%s %s" % [Data.resources[id].icon, Money.lire(n)]) if money else ("%s %d" % [Data.resources[id].icon, n]), 15))
		hud_res.add_child(chip)
		if pop.has(id):
			chip.pivot_offset = Vector2(30, 14)
			var tw := chip.create_tween(); tw.tween_property(chip, "scale", Vector2(1.3, 1.3), 0.12); tw.tween_property(chip, "scale", Vector2.ONE, 0.25)

func give(items: Dictionary, source = null, quiet: bool = false) -> void:
	Inventory.add(state.inventory, items)
	render_resources(items.keys())
	if not quiet:
		for id in items:
			if items[id] > 0: toast("+" + Money.amount(id, int(items[id])), "good", 1.8)
	if source is Vector3: effects.sparkle(source, 10)
	emit_event("gain", {"items": items})

func set_flag(f: String, v: bool = true) -> void:
	if state.flags.get(f, false) == v: return
	state.flags[f] = v
	emit_event("flag", {"flag": f, "value": v})
	if Data.world_flags_of(Data.island, state.flags) != Data.world_flags: request_rebuild()
	if f == Bicycle.OWNED or Bicycle.UPGRADES.values().has(f): refresh_bike()

# ---- The bicycle (Bicycle, BikeModel) -----------------------------------------------------------------------------
var bike_node: Node3D = null
var ride_dist := 0.0
var coasting := false   # stopped pedalling on the bike (the freewheel ticked)

## The bike under the player, as the story has it (owned, its upgrades and paint), shown while you ride.
func refresh_bike() -> void:
	if bike_node: bike_node.queue_free(); bike_node = null
	if not Bicycle.owned(state.flags): return
	bike_node = BikeModel.build(Bicycle.color(state), Bicycle.upgrades(state.flags))
	player_char.add_child(bike_node)
	bike_node.visible = player.riding

func toggle_bike() -> void:
	if player.riding: dismount(); return
	var why := Bicycle.cant_mount(state.flags, Data.island_def(Data.island), Bicycle.indoors(player.pos), Bicycle.on_stairs(player.pos))
	if why == "" and not sitting.is_empty(): why = "Stand up first."
	if why != "":
		if Bicycle.owned(state.flags): toast(why, "warn", 2.0)
		return
	if bike_node == null: refresh_bike()
	player.riding = true; ride_dist = 0.0
	bike_node.visible = true
	player_char.play("ride", true)
	sfx("select")

## Off the bike: by choice, or by itself (quiet) to talk, build, gather or sleep, indoors and on stairs.
func dismount(quiet: bool = false) -> void:
	if not player.riding: return
	player.riding = false
	if bike_node: bike_node.visible = false
	if player_char.hold == "ride": player_char.stop_hold()
	if not quiet: sfx("select")

func update_bike(dt: float) -> void:
	if not player.riding: return
	if mode in ["dialogue", "build", "minigame", "cutscene"] or not sitting.is_empty() or Bicycle.indoors(player.pos) or Bicycle.on_stairs(player.pos):
		dismount(true); return
	if player.moving: coasting = false
	elif not coasting and player.speed > 2.0: coasting = true; sfx("freewheel")   # stop pedalling: tick-tick-tick
	var before := ride_dist
	ride_dist += player.speed * dt
	if before < 25.0 and ride_dist >= 25.0: story.event("bike_ride")   # a request can ask you to try it out
	BikeModel.animate(bike_node, dt, player.speed, state.flags.get("night", false))

func ring_bell() -> void:
	sfx("bell")
	for a in npcs.values():
		if a.present and Vector2(a.pos.x - player.pos.x, a.pos.z - player.pos.z).length() < 8.0: a.character.play("wave")

func repaint_bike() -> void:
	state["bike_color"] = Bicycle.next_color(Bicycle.color(state))
	refresh_bike(); sfx("paint")

## The story changed the place you're on (one of its location's WORLD_FLAGS: a piazza drained, a boat launched).
## It is built again where you stand once the conversation that did it has ended, the way sailing rebuilds the
## world for another island: the state crosses a scene reload and the layout is laid out for the new flags.
var rebuild_pending := false
func request_rebuild() -> void:
	rebuild_pending = true
	if story == null or not story.busy: rebuild_world.call_deferred()

func rebuild_world() -> void:
	if not rebuild_pending or traveling: return
	rebuild_pending = false
	if build.active: build.close()
	set_mode("cutscene")
	await _fade(true).finished
	snapshot()
	traveling = true
	Data.pending_state = state
	Data.rebuilding = true
	get_tree().reload_current_scene()

# ---- Modes ---------------------------------------------------------------------------------------
func set_mode(m: String) -> void:
	mode = m
	if m != "explore": prompt_panel.visible = false

func enter_dialogue(agent) -> void:
	if mode == "build": build.close()
	set_mode("dialogue")
	agent.talking = true
	dialogue.start(agent)
	cam.set_mode("dialogue"); cam.frame_dialogue(player.pos, agent.pos)
	player.yaw = atan2(agent.pos.x - player.pos.x, agent.pos.z - player.pos.z); player.sync()
	hud.tracker.visible = false

func exit_dialogue() -> void:
	for a in npcs.values(): a.talking = false
	dialogue.end()
	interact_cooldown = 0.35
	cam.set_mode("explore"); set_mode("explore")
	hud.tracker.visible = true

## Gathering minigames play in a small panel at the side while the camera watches you work.
func start_minigame(kind: String, mg, target: Vector3 = Vector3.INF) -> void:
	set_mode("minigame")
	minigame.start(kind, mg)
	if target != Vector3.INF: cam.set_mode("action"); cam.frame_action(player.pos, target)
	emit_event("minigame", {"kind": kind})

func minigame_done(kind: String, mg) -> void:
	set_mode("explore")
	cam.set_mode("explore")
	interact_cooldown = 0.35
	actions.minigame_done(kind, mg)

## Beds and benches: pick when to wake up (dawn, morning, noon, evening or night). A bench can also just be sat on.
func rest(where: String = "bed", seat = null) -> void:
	if mode != "explore": return
	panels.sleep(where, seat)

## On a bench (`seat`: the bench in the layout, or a bench or sofa you built) you wake up on it, and now and then
## to a joke (NapGags: the paper you slept under blows away, you're soaked, someone was staring).
func sleep_until(hour: float, where: String = "bed", seat = null) -> void:
	panels.close()
	set_mode("cutscene")
	stand_up()
	await _fade(true).finished
	nap_gags.clear()
	var t0: Dictionary = state.time.duplicate()
	Clock.sleep_until(state.time, hour)
	send_villagers_home()
	var gag := ""
	var on_bench: bool = where == "bench" and seat is Dictionary
	if on_bench: gag = nap_gags.wake(seat, t0)
	actions.refresh_all()
	_fade(false)
	set_mode("explore")
	var greet: String = "Good morning!" if hour >= 5 and hour < 12 else ("Good afternoon!" if hour < 17 else ("Good evening!" if hour < 21 else "Good night!"))
	var sub: String = ("You wake up on the bench. " if where == "bench" else "") + Clock.text(state.time)
	if not on_bench: banner(greet, sub)
	sfx("morning")
	autosave("rest", true)
	emit_event("slept", {"hour": hour, "where": where, "gag": gag})
	if on_bench: nap_gags.play(greet, sub)   # the greeting comes with the joke, if there is one

## Ride from one stop to another on a line within this place (Travel.stops_on): the screen fades, the clock moves
## on by the ride's length, and you step off at the other stop.
func ride_to(from: Dictionary, to: Dictionary) -> void:
	panels.close()
	set_mode("cutscene")
	stand_up()
	await _fade(true).finished
	Clock.advance(state.time, Travel.ride_minutes(from, to) / Clock.MINUTES_PER_SECOND)
	var spot := walk.free_spot(float(to.x), float(to.z), Rect2(), 6.0, WalkWorld.PLAYER_RADIUS, player.body)
	if not spot.is_empty(): player.teleport(spot.x, spot.z)
	cam.snap()
	_fade(false)
	set_mode("explore")
	toast(String(to.get("arrive_text", String(to.get("name", "")))))
	emit_event("rode", {"from": from.id, "to": to.id})

func _fade(on: bool) -> Tween:
	var r: ColorRect = ui_root.get_node_or_null("Fade")
	if r == null:
		r = ColorRect.new(); r.name = "Fade"; r.color = Color(1, 0.97, 0.92, 0); r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui_root.add_child(r)
	var tw := create_tween(); tw.tween_property(r, "color:a", 1.0 if on else 0.0, 0.5)
	return tw

## Change outfit anywhere you're settled: by the guest room's wardrobe, or at your own home once it's built.
func open_wardrobe() -> void:
	if screens == null or mode != "explore": return
	var w: Dictionary = {}
	for f in Data.layout.features:
		if f.kind == "wardrobe": w = f
	var near_inn := not w.is_empty() and Vector2(player.pos.x - w.x, player.pos.z - w.z).length() < 6.0
	var plot := Data.zone("plot")
	var at_home: bool = state.flags.get("ownHome", false) and not plot.is_empty() and BuildGrid.zone_contains(plot, floorf(player.pos.x), floorf(player.pos.z), state.harmony)
	if near_inn or at_home: screens.creator(true)
	else: toast("Change your outfit at the guest house wardrobe%s." % (", or at home" if state.flags.get("ownHome", false) else ""))

func sail_to(isl: Dictionary) -> void:
	panels.close()
	if isl.id == Data.island: toast("You are already in %s!" % isl.name); return
	if Data.has_island(isl.id): travel(isl.id); return
	set_mode("cutscene"); sfx("sail")
	await _fade(true).finished
	await get_tree().create_timer(0.6).timeout
	_fade(false)
	banner(isl.name, "Coming soon!", ["Aldo drives you round the valley and back.", "Thank you for playing the Monteforchetta chapter!"], 6.0)
	set_flag("sailedOnce")
	player_char.play("celebrate")
	set_mode("explore")
	autosave("travel", true)

## Sail to another island: this island's buildings are put away in the save, the state crosses a scene reload,
## and the world is rebuilt from the new island's layout. You arrive at its spawn point (the dock).
func travel(id: String) -> void:
	if build.active: build.close()
	set_mode("cutscene"); sfx("sail")
	await _fade(true).finished
	snapshot()
	var dest := Data.read_layout(id)
	Travel.leave(state, Data.island, id, dest.get("arrive", dest.spawn))   # where the ferry lands
	traveling = true
	Data.pending_state = state
	Data.use_island(id)
	get_tree().reload_current_scene()

## Just arrived (from a voyage or by loading a save made on this island).
func _arrived() -> void:
	var first: bool = not state.flags.get("arrived_" + Data.island, false)
	set_flag("arrived_" + Data.island)
	var isl := Data.island_def(Data.island)
	_fade(false)
	if first and Data.island != "hearthglow": banner(isl.get("name", ""), isl.get("desc", ""), [], 5.0); sfx("fanfare")
	else: toast("⛵ %s" % isl.get("name", ""), "good", 2.5)
	autosave("travel", true)

func to_title() -> void:
	autosave("quit", true)
	get_tree().reload_current_scene()

func on_quest_completed(qid: String) -> void:
	match qid:
		"bridge": actions.refresh_all(); effects.sparkle(Vector3(0.5, 0.5, -18), 50, Color("fff2a8"), 0.35)
		"workshop": effects.sparkle(Vector3(-13, 2, 10), 40)
		"fountain": effects.sparkle(Vector3(0, 2.5, 2), 60, Color("bff3ff"))
		"dock":
			for f in Data.layout.features:
				if f.id == "boat": effects.sparkle(Vector3(f.x, 1.5, f.z), 50)
			get_tree().create_timer(4.4).timeout.connect(func(): banner("The city bus is running!", "A new stop is on your map (%s): catch the bus at the turnaround" % Controls.key_label("map"), [], 5.0))
		"lighthouse": effects.sparkle(Vector3(-24, 7.5, -21), 50, Color("fff2a8"), 0.4); toast("The lighthouse turns again! Its beam sweeps the bay at night.", "good", 4.0)
		"clocktower":
			effects.sparkle(Vector3(12, 6, -13), 50); sfx("gate")
			get_tree().create_timer(4.4).timeout.connect(func(): banner("Clockwork Cove is ticking again!", "The clock and the lighthouse run. More of the cove's story is coming.", [], 5.0))
	for a in npcs.values():
		if a.present and Vector2(a.pos.x - player.pos.x, a.pos.z - player.pos.z).length() < 12.0: a.character.play("clap" if randf() < 0.5 else "celebrate")

## Path cells of the bridge the player built, so villagers walk across it (Hearthglow's, and a layout's
## "crossings": Schedule.crossing).
func crossing_path(a: String, b: String) -> Array:
	var dir := 0
	if a == "bridgeS" and b == "bridgeN": dir = 1
	elif a == "bridgeN" and b == "bridgeS": dir = -1
	if dir == 0: return Schedule.crossing(a, b, state.crossings)
	var cells: Array = state.crossings.get("bridge", [])
	var pts := cells.map(func(c): return Vector2(c[0] + 0.5, c[1] + 0.5))
	if dir < 0: pts.reverse()
	return pts

# ---- Saving --------------------------------------------------------------------------------------
func snapshot() -> Dictionary:
	state.player = {"x": player.pos.x, "z": player.pos.z, "yaw": player.yaw}
	return state

func save_to(slot: String) -> bool:
	var ok := SaveSystem.write(slot, snapshot())
	toast(("💾 Autosaved" if slot == SaveSystem.AUTOSAVE else "💾 Game saved") if ok else "Could not save", "good" if ok else "warn", 1.8)
	if ok: sfx("save")
	return ok

func autosave(reason: String, force: bool = false) -> void:
	if not started: return
	if not force and time - last_autosave < 20.0: return
	last_autosave = time
	save_to(SaveSystem.AUTOSAVE)

func load_from(slot: String) -> bool:
	var s := SaveSystem.read(slot)
	if s.is_empty(): toast("That save is empty", "warn"); return false
	load_state(s)
	toast("📂 Game loaded", "good")
	return true

func load_state(s: Dictionary) -> void:
	if build.active: build.close()
	# a save made on another island, or on this one at another point of its story: rebuild the world for it
	if s.get("island", "hearthglow") != Data.island or Data.world_flags_of(Data.island, s.get("flags", {})) != Data.world_flags:
		traveling = true
		Data.pending_state = s
		Data.use_island(s.get("island", "hearthglow"))
		get_tree().reload_current_scene()
		return
	state = s
	story.attach(s)
	player_char.set_appearance(s.appearance)
	player_char.show_staff(s.flags.get("hasTool", false))
	player.teleport(s.player.x, s.player.z, s.player.yaw)
	dismount(true); refresh_bike()
	rebuild_all_pieces()
	send_villagers_home()
	actions.refresh_all()
	build.history.clear()
	render_resources(); hud.render_harmony(); hud.render_tracker()
	guide.reset()

## Villagers go straight to where their routine puts them now (after a sleep, or loading a save). One can land right
## where you stand, and you couldn't walk out of them, so you step aside.
func send_villagers_home() -> void:
	for a in npcs.values(): a.teleport_home(); a.sync()
	var spot := walk.step_aside(player.pos, WalkWorld.PLAYER_RADIUS, player.body)
	if not spot.is_empty(): player.teleport(spot.x, spot.z)

func begin_play() -> void:
	started = true
	hud.visible = true
	refresh_bike()
	render_resources(); hud.render_harmony(); hud.render_tracker()
	set_mode("explore")
	guide.reset()

func apply_settings() -> void:
	Controls.setup(settings.bindings)
	_apply_outline()
	_apply_window()
	if audio: audio.set_volumes(settings.music, settings.sfx)
	SaveSystem.store_settings(settings)

# ---- Zones and blueprints ------------------------------------------------------------------------
func zone_unlocked(zone: Dictionary) -> bool:
	var u: Dictionary = zone.get("unlock", {})
	if u.has("flag") and not state.flags.get(u.flag, false): return false
	if u.has("quest") and not state.quests.has(u.quest): return false
	return true

func zone_plan_visible(zone: Dictionary) -> bool:
	if not zone_unlocked(zone): return false
	var u: Dictionary = zone.get("unlock", {})
	if u.has("quest") and state.quests.get(u.quest, {}).get("status", "") != "active": return false
	if zone.id == "dock" and state.flags.get("boatReady", false): return false
	return true

func blueprint_hint(id: String) -> String: return story.engine.blueprint_hint(id)
func build_goals(zone: Dictionary) -> Dictionary: return story.build_goals(zone)

# ---- Construction --------------------------------------------------------------------------------
func placement_ctx(placements = null) -> Dictionary:
	var bodies := [{"x": player.pos.x, "z": player.pos.z, "r": 0.3, "y": player.pos.y}]
	for a in npcs.values():
		if a.present: bodies.append({"x": a.pos.x, "z": a.pos.z, "r": 0.3, "y": a.pos.y, "name": a.def.name})
	return {"placements": placements if placements != null else state.placements, "zones": Data.layout.zones.filter(func(z): return zone_unlocked(z)),
		"locked_zones": Data.layout.zones.filter(func(z): return not zone_unlocked(z)), "harmony": state.harmony, "statics": statics, "flags": state.flags, "bodies": bodies,
		"no_build": Data.layout.get("noBuild", {})}

func _find_pl(uid: int) -> Dictionary:
	for p in state.placements:
		if p.uid == uid: return p
	return {}

func commit_place(pl: Dictionary, animate: bool = true, check_cost: bool = true) -> Dictionary:
	var others: Array = state.placements.filter(func(p): return p.uid != pl.uid)
	var v := BuildGrid.validate_placement(pl, placement_ctx(others))
	if not v.ok: return v
	var cost: Dictionary = Data.piece(pl.id).cost
	if check_cost and not Inventory.can_afford(state.inventory, cost): return {"ok": false, "reason": "Not enough materials"}
	if check_cost: Inventory.spend(state.inventory, cost)
	state.placements.append(pl)
	state.next_uid = maxi(int(state.next_uid), int(pl.uid) + 1)
	state.stats.placed += 1
	_add_piece_node(pl, animate)
	if animate: player_char.play("build"); sfx("place")
	render_resources(cost.keys())
	on_build_changed({"action": "place", "pl": pl, "zone": v.zone})
	return {"ok": true}

func commit_remove(uid: int, refund: bool = true) -> Dictionary:
	var v := BuildGrid.validate_removal(uid, placement_ctx())
	if not v.ok: return v
	var pl := _find_pl(uid)
	state.placements = state.placements.filter(func(p): return p.uid != uid)
	if refund: Inventory.add(state.inventory, Data.piece(pl.id).cost)
	var n: Node3D = piece_nodes.get(uid)
	if n: effects.poof(n.position, Color("e9ddff")); n.queue_free(); piece_nodes.erase(uid)
	sfx("remove")
	render_resources(Data.piece(pl.id).cost.keys())
	on_build_changed({"action": "remove", "pl": pl})
	return {"ok": true}

func commit_move(uid: int, to: Dictionary) -> Dictionary:
	var pl := _find_pl(uid)
	if pl.is_empty(): return {"ok": false, "reason": "That piece is gone"}
	var cand := pl.duplicate(true); cand.merge(to, true)
	var others: Array = state.placements.filter(func(p): return p.uid != uid)
	if to.i != pl.i or to.k != pl.k or to.y != pl.y:
		var rm := BuildGrid.validate_removal(uid, placement_ctx())
		if not rm.ok: return rm
	var v := BuildGrid.validate_placement(cand, placement_ctx(others))
	if not v.ok: return v
	pl.merge(to, true)
	_sync_piece(pl)
	effects.sparkle(piece_nodes[uid].position + Vector3(0, 0.4, 0), 8, Color("c9a8ff"))
	sfx("place")
	on_build_changed({"action": "move", "pl": pl, "zone": v.zone})
	return {"ok": true}

func commit_recolor(uid: int, color: String) -> Dictionary:
	var pl := _find_pl(uid)
	if pl.is_empty(): return {"ok": false, "reason": "That piece is gone"}
	if color == "": pl.erase("color")
	else: pl["color"] = color
	PieceMeshes.set_color(piece_nodes[uid], color if color != "" else Data.piece(pl.id).color)
	effects.sparkle(piece_nodes[uid].position + Vector3(0, 0.5, 0), 10, Color(color) if color != "" else Color.WHITE)
	sfx("paint")
	on_build_changed({"action": "recolor", "pl": pl})
	return {"ok": true}

func toggle_lever(uid: int) -> void:
	var p := _find_pl(uid)
	var st: Dictionary = p.get("state", {}); st["on"] = not st.get("on", false); p["state"] = st
	sfx("lever")
	on_build_changed({"action": "switch"})

func _add_piece_node(pl: Dictionary, animate: bool) -> void:
	var n := PieceMeshes.make(pl.id, pl.get("color", ""))
	n.set_meta("uid", pl.uid)
	piece_root.add_child(n); piece_nodes[pl.uid] = n
	_sync_piece(pl)
	if animate:
		n.scale = Vector3.ONE * 0.01
		var tw := n.create_tween(); tw.tween_property(n, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK); tw.tween_property(n, "scale", Vector3.ONE, 0.12)
		effects.magic(n.position, minf(2.0, float(Data.piece(pl.id).h) + 0.5))

func _sync_piece(pl: Dictionary) -> void:
	var n: Node3D = piece_nodes.get(pl.uid)
	if n == null: return
	var fp := BuildGrid.footprint(Data.piece(pl.id), int(pl.r))
	n.position = Vector3(pl.i + fp.x / 2.0, pl.y, pl.k + fp.y / 2.0)
	n.rotation.y = -int(pl.r) * PI / 2.0

func rebuild_all_pieces() -> void:
	for c in piece_root.get_children(): c.queue_free()
	piece_nodes.clear()
	for pl in state.placements: _add_piece_node(pl, false)
	on_build_changed({"action": "load"})

## Cells where a machine delivers water or power to something in the world (layout `machines`; Hearthglow's
## fountain inlet too).
func machine_targets() -> Array:
	var out: Array = []
	if Data.layout.has("fountain"):
		var F: Dictionary = Data.layout.fountain
		out.append({"id": "fountain", "cell": F.inlet.cell, "side": F.inlet.side, "type": "water"})
	out.append_array(Data.layout.get("machines", []))
	return out

func on_build_changed(ev: Dictionary) -> void:
	walk.surfaces = BuildGrid.surfaces_for(state.placements)
	mech = Mechanics.solve(state.placements, machine_targets())
	_refresh_piece_interactables()
	build.refresh_plan()
	emit_event("build", ev)
	if ev.get("action", "") != "load": autosave("build")

func _refresh_piece_interactables() -> void:
	interactables = interactables.filter(func(it): return not it.get("piece", false))
	for pl in state.placements:
		var d := Data.piece(pl.id)
		if not d.has("interact"): continue
		var b := BuildGrid.bounds(pl)
		var rec := {"id": "pl:%d" % pl.uid, "piece": true, "x": (b.minX + b.maxX) / 2.0, "z": (b.minZ + b.maxZ) / 2.0, "y": float(pl.y), "radius": 1.3, "object": piece_nodes.get(pl.uid)}
		var ppl: Dictionary = pl
		match d.interact:
			"door":
				rec["label"] = func(): return "Close door" if ppl.get("state", {}).get("open", false) else "Open door"
				rec["act"] = func():
					var st: Dictionary = ppl.get("state", {}); st["open"] = not st.get("open", false); ppl["state"] = st
					sfx("door"); walk.surfaces = BuildGrid.surfaces_for(state.placements)
			"lever":
				rec["label"] = func(): return "Switch lever off" if ppl.get("state", {}).get("on", false) else "Switch lever on"
				rec["act"] = func(): toggle_lever(ppl.uid)
			"sit":
				var napping: bool = ppl.id in ["bench", "sofa"]   # long enough to nap on
				rec["label"] = func(): return "Sit or nap" if napping else "Sit down"
				rec["act"] = func():
					if napping: rest("bench", ppl)
					else: sit_on(ppl)
			"sleep":
				rec["label"] = func(): return "Sleep"
				rec["act"] = func(): rest("bed")
		if rec.has("act"): add_interactable(rec)

## Sit on a seat (pose "sleep" to wake up slumped on a bench); moving gets you up again, back where you stood.
func sit_on(pl: Dictionary, pose: String = "sit", quiet: bool = false) -> void:
	sitting = {"back": player.pos}
	player.pos = NapGags.seat_spot(pl)
	player.yaw = -int(pl.r) * PI / 2.0; player.sync()
	player_char.play(pose, true)
	if not quiet: toast("Ahh, cozy. Move to stand up.")

func stand_up() -> void:
	if sitting.is_empty(): return
	var back: Vector3 = sitting.back
	sitting = {}
	player.teleport(back.x, back.z)
	player_char.stop_hold()

# ---- Interaction ---------------------------------------------------------------------------------
func add_interactable(rec: Dictionary) -> void:
	var r := {"radius": 1.8, "priority": 0.0, "available": func(): return true}
	r.merge(rec, true)
	interactables.append(r)

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
		if it.has("y") and absf(float(it.y) - p.y) > 1.6: continue   # on another storey (a bed in the flat upstairs)
		var facing := (dx * fwd.x + dz * fwd.y) / d if d > 0.01 else 1.0
		if d > 1.0 and facing < 0.1: continue
		var score: float = d - facing * 0.8 - it.priority
		if score < best_score: best_score = score; best = it
	return best

func _set_highlight(obj, on: bool) -> void:
	if obj == null or not is_instance_valid(obj): return
	for m in obj.find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if on:
			if mat is StandardMaterial3D and not m.has_meta("orig_mat"):
				m.set_meta("orig_mat", mat)
				var c: StandardMaterial3D = mat.duplicate()
				c.emission_enabled = true; c.emission = Color("ffd98a"); c.emission_energy_multiplier = 0.35
				m.material_override = c
		elif m.has_meta("orig_mat"):
			m.material_override = m.get_meta("orig_mat"); m.remove_meta("orig_mat")

func _update_interaction() -> void:
	var prev = target
	target = find_target() if mode == "explore" and sitting.is_empty() else null
	if prev != null and prev != target: _set_highlight(prev.get("object"), false)
	if target != null:
		_set_highlight(target.get("object"), true)
		prompt_label.text = "[%s]  %s" % [Controls.key_label("interact"), target.label.call()]
		prompt_panel.visible = true
		if Input.is_action_just_pressed("interact") and interact_cooldown <= 0.0: target.act.call()
	else:
		prompt_panel.visible = false

# ---- Input ---------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if mode == "build" and event is InputEventMouse: build.mouse = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed)):
		toggle_fullscreen(); get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton:
		var rot_button: bool = event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] or (event.button_index == MOUSE_BUTTON_LEFT and mode == "explore")
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag_dist = 0.0; drag_moved = false   # every new press starts fresh, so a click after a camera drag still counts
			dragging = rot_button
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and mode in ["explore", "build"]: cam.zoom(-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mode in ["explore", "build"]: cam.zoom(1)
	if event is InputEventMouseMotion and dragging and mode in ["explore", "build"]:
		_drag_dist += event.relative.length()
		if _drag_dist > 6.0: drag_moved = true
		var sens: float = 0.0055 * settings.sensitivity
		if drag_moved: cam.rotate_by(event.relative.x * sens, event.relative.y * sens * (-1.0 if settings.invert_y else 1.0))
	if mode == "build": build.handle_input(event)
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		dragging = false

func move_vector() -> Vector2: return Input.get_vector("move_left", "move_right", "move_back", "move_forward")

# ---- Loop ----------------------------------------------------------------------------------------
var traveling := false   # between switching islands and the scene reload: the old world must not update

func _process(dt: float) -> void:
	if traveling: return
	if story: story.engine.invalidate()   # live quest checks look at the world: recompute them once a frame
	dt = minf(dt, 0.1)
	time += dt
	interact_cooldown -= dt
	if mode in ["title", "creator"]:
		if screens: screens.update(dt)
		_tick_shot(); return
	if mode in ["explore", "build"]:
		if Input.is_action_pressed("cam_left"): cam.yaw += 1.8 * dt
		if Input.is_action_pressed("cam_right"): cam.yaw -= 1.8 * dt
		var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if look.length() > 0.15: cam.rotate_by(look.x * 2.4 * dt * settings.sensitivity, look.y * 1.6 * dt)
	_update_world_time(dt)
	match mode:
		"explore":
			if not sitting.is_empty():
				if move_vector().length() > 0.3 or Input.is_action_just_pressed("jump"): stand_up()
				else: player_char.animate(dt)
			else:
				player.update(dt, move_vector(), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), cam.move_yaw(), true)
			if Input.is_action_just_pressed("bike"): toggle_bike()
			elif player.riding and Input.is_action_just_pressed("bell") and Bicycle.has(state.flags, "bell"): ring_bell()
			elif player.riding and Input.is_action_just_pressed("recolor") and Bicycle.has(state.flags, "paint"): repaint_bike()
			if Input.is_action_just_pressed("build"):
				if build.open(): set_mode("build")
			elif Input.is_action_just_pressed("inventory"): panels.inventory()
			elif Input.is_action_just_pressed("journal"): panels.journal()
			elif Input.is_action_just_pressed("map"): panels.map()
			elif Input.is_action_just_pressed("progress"): panels.progress()
			elif Input.is_action_just_pressed("wardrobe"): open_wardrobe()
			elif Input.is_action_just_pressed("pause"): panels.pause()
		"build":
			player_char.animate(dt)
			build.update(dt)
			if not build.active: set_mode("explore")
		_:
			player_char.animate(dt)
			if mode == "dialogue": dialogue.update(dt)
			if mode == "minigame": minigame.update(dt)
			if mode == "menu": panels.update(dt)
	update_bike(dt)
	for a in npcs.values(): a.update(dt)
	actions.update(dt)
	cam.update(dt, player.pos)
	if mode == "explore": player_char.visible = cam.col_dist > 0.85   # a wall right behind: don't fill the view with the back of the head
	_update_interaction()
	_update_hotkeys()
	guide.update(dt)
	hud.tick(dt)
	hud.update_compass(guide.target())
	_world_reactions(dt)
	var vflags: Dictionary = state.flags.duplicate(); vflags["fountainFlowing"] = mech.fed.get("fountain", false)
	for id in mech.fed: vflags["fed:" + id] = mech.fed[id]
	village.update_world(dt, time, vflags)
	for pl in state.placements:
		var n: Node3D = piece_nodes.get(pl.uid)
		if n: PieceMeshes.animate(n, pl, time, dt, {"spinning": mech.powered.has(pl.uid) or mech.sources.has(pl.uid), "powered": mech.powered.has(pl.uid), "watered": mech.watered.has(pl.uid), "on": pl.get("state", {}).get("on", false), "open": pl.get("state", {}).get("open", false), "night": state.flags.get("night", false)})
	sun.position = build.focus if mode == "build" else player.pos
	toasts.offset_top = 160 if mode == "build" else 72
	hotkeys.get_parent().visible = mode == "explore"
	if audio: audio.update_music(self, dt)
	_tick_shot()

## The key list grows as the guided day introduces each part of the game. Drawn as little key chips.
func _update_hotkeys() -> void:
	var k := func(a): return Controls.key_label(a)
	var tut: Dictionary = state.get("tutorial", {})
	var entries: Array = [["%s%s%s%s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")], "Move"],
		["Drag/%s%s" % [k.call("cam_left"), k.call("cam_right")], "Camera"], [k.call("interact"), "Interact"]]
	if state.flags.get("hasTool", false) and Tutorial.revealed(tut, "key:build"): entries.append([k.call("build"), "Build"])
	var progress_name: String = String(LocationMeter.def(Data.island).get("name", "Approval")).trim_prefix("The ")
	for pair in [["inventory", "Bag"], ["journal", "Journal"], ["map", "Map"], ["progress", progress_name]]:
		if Tutorial.revealed(tut, "key:" + pair[0]): entries.append([k.call(pair[0]), pair[1]])
	if Bicycle.owned(state.flags) and Bicycle.allowed(Data.island_def(Data.island)):
		entries.append([k.call("bike"), "Get off" if player.riding else "Bike"])
		if player.riding and Bicycle.has(state.flags, "bell"): entries.append([k.call("bell"), "Bell"])
		if player.riding and Bicycle.has(state.flags, "paint"): entries.append([k.call("recolor"), "Repaint"])
	entries.append([k.call("pause"), "Menu"])
	var t: String = " · ".join(entries.map(func(e): return "%s %s" % e))
	if t == hotkeys.text: return
	hotkeys.text = t
	for c in hotkey_row.get_children():
		if c != hotkeys: c.queue_free()
	for e in entries:
		var item := HBoxContainer.new(); item.add_theme_constant_override("separation", 5); hotkey_row.add_child(item)
		var chip := UiTheme.panel(Color.WHITE, Color("f0d6ae"), 8)
		var cs: StyleBoxFlat = chip.get_theme_stylebox("panel").duplicate(); cs.content_margin_left = 6; cs.content_margin_right = 6; cs.content_margin_top = 1; cs.content_margin_bottom = 2; cs.shadow_size = 0; cs.border_width_bottom = 4
		chip.add_theme_stylebox_override("panel", cs)
		chip.add_child(UiTheme.label(e[0], 13, UiTheme.PINK_DARK)); item.add_child(chip)
		item.add_child(UiTheme.label(e[1], 13, UiTheme.INK2))

## Sky, light, fog and rain follow the clock: keyframed colours through dawn, day, dusk and night, the sun and
## moon crossing the sky, and weather that drifts between clear, fair, cloudy, drizzle, rain and morning mist.
var weather_now: Dictionary = {}
var look_here: Dictionary = {}   # the look block of the place you're on (its map entry)
var _look_island := ""
func _update_world_time(dt: float) -> void:
	var s := state
	if mode != "menu": Clock.advance(s.time, dt); s.play_time += dt
	var night := Clock.is_night(s.time)
	if night != s.flags.get("night", false): s.flags["night"] = night
	var h: float = s.time.minute / 60.0
	var look := Daylight.sample(h)
	var nt := Daylight.nightness(h)
	var forced: String = shot_cfg.get("weather", "")   # screenshots: --weather=rain etc.
	if forced == "" and settings.weather: forced = Daylight.forced(s)   # a request's own weather (Daylight.force)
	var w: Dictionary = Daylight.weather(s.time, Daylight.allowed_here()) if settings.weather and forced == "" else Daylight.WEATHER.get(forced if forced != "" else "clear", Daylight.WEATHER.clear).duplicate()
	if not w.has("type"): w["type"] = forced if forced != "" else "clear"
	# ease the weather values too, so switching the setting or loading a save doesn't snap the sky
	for k in ["clouds", "rain", "fog", "sun"]:
		weather_now[k] = lerpf(weather_now.get(k, w[k]), w[k], 1.0 - exp(-dt * 0.8))
	weather_now["type"] = w.type
	var clouds: float = weather_now.clouds; var wet: float = weather_now.rain; var fog: float = weather_now.fog
	var grey := clampf((clouds - 0.4) * 1.1, 0.0, 0.7)
	sun.light_energy = look.sun_energy * weather_now.sun
	sun.light_color = look.sun_color.lerp(Color("d8dde2"), grey * 0.6)
	var ld := Daylight.light_dir(h)
	sun.global_transform.basis = Basis.looking_at(-ld, Vector3.UP if absf(ld.y) < 0.99 else Vector3.FORWARD)
	var e: Environment = env.environment
	e.ambient_light_energy = look.ambient_energy * lerpf(1.0, 0.92, grey)
	e.ambient_light_color = look.ambient.lerp(Color("c4cad0"), grey * 0.5)
	var sky_mat: ShaderMaterial = e.sky.sky_material
	var top: Color = look.zenith.lerp(Color("8f9cab"), grey)
	var bottom: Color = look.horizon.lerp(Color("c3cbd3"), grey)
	if _look_island != Data.island: _look_island = Data.island; look_here = Data.island_def(Data.island).get("look", {})
	var tb := Atmosphere.sky_look(look_here, top, bottom, nt); top = tb[0]; bottom = tb[1]   # a location's own sky
	sky_mat.set_shader_parameter("top_color", top); sky_mat.set_shader_parameter("bottom_color", bottom)
	sky_mat.set_shader_parameter("sun_dir", Daylight.sun_dir(h)); sky_mat.set_shader_parameter("moon_dir", Daylight.moon_dir(h))
	sky_mat.set_shader_parameter("sun_color", look.sun_color); sky_mat.set_shader_parameter("night", nt)
	sky_mat.set_shader_parameter("clouds", clouds); sky_mat.set_shader_parameter("cloud_dark", wet)
	e.fog_light_color = bottom.lerp(top, 0.25).lerp(Color("eef1f4"), fog * 0.55)
	e.fog_depth_curve = lerpf(1.6, 0.9, fog)
	# morning mist and rain pull the haze in close
	e.fog_depth_begin = lerpf(45.0, 2.0, fog)
	e.fog_depth_end = lerpf(220.0, 45.0, fog)
	e.fog_density = lerpf(0.55, 0.92, fog)
	var hz := Atmosphere.haze(look_here, e.fog_light_color, e.fog_depth_begin, e.fog_depth_end, nt)   # and its haze
	e.fog_light_color = hz.color; e.fog_depth_begin = hz.begin; e.fog_depth_end = hz.end
	(village.water.material_override as ShaderMaterial).set_shader_parameter("night", nt)
	rain.emitting = wet > 0.05
	rain.amount_ratio = clampf(wet, 0.05, 1.0)
	rain.position = camera.global_position + Vector3(0, 8, 0)
	var icon: String = "🌙" if night else ({"rain": "🌧️", "drizzle": "🌦️", "cloudy": "☁️", "mist": "🌫️", "fair": "⛅"}.get(weather_now.type, "☀️"))
	hud.clock_label.text = "%s %s%s" % [icon, Clock.text(s.time), ("  📟 " + ["beep", "beep beep", "BEEP BEEP BEEP"][actions.hum - 1]) if actions.hum > 0 else ""]

func _world_reactions(dt: float) -> void:
	if Data.layout.has("fountain") and state.flags.get("fountainFlowing", false) != mech.fed.get("fountain", false): set_flag("fountainFlowing", mech.fed.get("fountain", false))
	smoke_t -= dt
	if smoke_t < 0.0:
		smoke_t = 0.5
		for pair in [["bakery", state.flags.get("squirrelsGone", false)], ["odessaHouse", true], ["fernHouse", state.flags.get("orchardOpen", false)], ["playerHouse", state.flags.get("toolGiven", false)]]:
			var o: Node3D = village.objects.get(pair[0])
			if pair[1] and o and o.has_meta("chimney"): effects.smoke(o.to_global(o.get_meta("chimney")))
	# Roofs dissolve over the room you're standing in, on its storey (and over a room while you furnish it).
	var p := player.pos
	for bd in Data.layout.buildings:
		var o: Node3D = village.objects.get(bd.id)
		if o == null or not o.has_meta("fade_parts"): continue
		var room: AABB = Interiors.room(bd, o.position.y) if Interiors.enterable(bd) else AABB(Vector3(bd.x - bd.w / 2.0 + 0.3, -1.0, bd.z - bd.d / 2.0 + 0.3), Vector3(bd.w - 0.6, 4.0, bd.d - 0.6))
		var in_room: bool = Interiors.inside(bd, o.position.y, p) if Interiors.enterable(bd) else room.has_point(Vector3(p.x, room.position.y + 1.0, p.z))
		var inside: bool = in_room or (build.active and build.current_zone.get("id", "") == bd.id)
		var a0: float = roof_fade.get(bd.id, 1.0)
		var a1: float = lerpf(a0, 0.0 if inside else 1.0, minf(1.0, dt * 6.0))
		if a1 > 0.995: a1 = 1.0
		roof_fade[bd.id] = a1
		if a1 == a0 and (a1 == 1.0 or a1 < 0.001): continue
		var fading := a1 < 0.99
		for part in o.get_meta("fade_parts"):
			var mi: MeshInstance3D = part[0]
			var m: Material = part[2] if fading else part[1]
			if mi.material_override != m: mi.material_override = m
			if not fading: continue
			if m is ShaderMaterial: m.set_shader_parameter("alpha", a1)
			else: m.albedo_color.a = a1
	roof_alpha = roof_fade.get("workshop", 1.0)

func _make_rain() -> void:
	rain = GPUParticles3D.new(); rain.amount = 1500; rain.lifetime = 1.6; rain.emitting = false; rain.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new(); pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; pm.emission_box_extents = Vector3(25, 1, 25)
	pm.direction = Vector3(0, -1, 0); pm.initial_velocity_min = 12.0; pm.initial_velocity_max = 15.0; pm.gravity = Vector3(0, -2, 0); pm.spread = 3.0
	rain.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.03, 0.4)
	var m := Palette.glow_mat(Color("cfe8ff"), 0.6); m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; q.material = m
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA; m.distance_fade_min_distance = 1.5; m.distance_fade_max_distance = 5.0   # no giant streaks right at the lens
	rain.draw_pass_1 = q
	add_child(rain)

# ---- Command-line hooks: -- --shot=out.png --pos=x,z,yaw --cam=yaw,pitch,dist --frames=N | --autoplay=res://tests/play_x.gd --out=dir
## Fullscreen when asked for; otherwise the window opens maximized (project setting) and can be resized freely.
func _apply_window() -> void:
	if DisplayServer.get_name() == "headless" or shot_cfg.has("shot") or shot_cfg.has("autoplay"): return
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if settings.get("fullscreen", false) and not full: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not settings.get("fullscreen", false) and full: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

## Pause menu "I'm stuck": back to the layout's safe spot (safeSpot, a nav node), wherever you were.
func unstick() -> void:
	var safe: String = Data.layout.get("safeSpot", "cottageDoor")
	var door: Array = Data.layout.nav_nodes.get(safe, [Data.layout.spawn.x, Data.layout.spawn.z])
	var spot := walk.free_spot(float(door[0]), float(door[1]), Rect2(), 10.0, WalkWorld.PLAYER_RADIUS, player.body)
	if spot.is_empty(): return
	if not sitting.is_empty(): sitting = {}; player_char.stop_hold()   # up off the bench, without stepping back to it
	player.teleport(spot.x, spot.z); cam.snap()
	effects.sparkle(player.pos + Vector3(0, 1, 0), 16)
	toast(Data.layout.get("safeText", "Back at the guest house."))

func toggle_fullscreen() -> void:
	settings.fullscreen = not settings.get("fullscreen", false)
	apply_settings()

func _apply_outline() -> void:
	if outline: outline.visible = (outline_override == "1") if outline_override != "" else settings.get("outlines", true)

## Ink lines scale with the screen so they read the same at 720p and 1440p.
func _fit_outline() -> void:
	if outline: (outline.material_override as ShaderMaterial).set_shader_parameter("width", clampf(float(get_window().size.y) / 600.0, 1.2, 3.0))

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
	if shot_cfg.has("time"): state.time.minute = float(shot_cfg.time) * 60.0

var _frames := 0
func _tick_shot() -> void:
	if not shot_cfg.has("shot"): return
	_frames += 1
	if _frames == int(shot_cfg.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(shot_cfg.shot)
		get_tree().quit()
