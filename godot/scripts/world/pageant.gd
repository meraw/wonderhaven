class_name Pageant
extends Node3D

const P := preload("res://scripts/world/palette.gd")
const WALK_SPEED := 1.6
const ANIMAL_SPEED := 1.1

var game
var playing := false
var spec: Dictionary = {}
var fr: Dictionary = {}
var walkers: Array = []
var held: Array = []
var moved: Array = []
var props: Array = []
var worn: Array = []
var candles: Array = []
var candle_t := -1.0
var singers: Array = []
var note_t := 0.0
var clock := 0.0
var line_now := -1
var cam_from := Vector3.ZERO
var cam_to := Vector3.ZERO
var look := Vector3.ZERO
var push := 0.0
var push_to := 0.12
var back := {}
var framed := false
var last := {}

func setup(g) -> void: game = g

func play(s: Dictionary, lines: Array, speaker) -> void:
	playing = true
	framed = false
	spec = s
	clock = 0.0
	line_now = -1
	last = {"lines": lines.size(), "beats": [], "placed": {}}
	fr = Staging.frame(s, Staging.anchor(s, game.state.placements))
	back = {"x": game.player.pos.x, "z": game.player.pos.z, "yaw": game.player.yaw}
	game.dialogue.visible = false
	await game._fade(true).finished
	_stage(speaker)
	_frame_camera()
	game.emit_event("pageant_start", {"at": fr.origin})
	game._fade(false)
	await _wait(0.6)
	for i in lines.size():
		_beat(i)
		game.dialogue.visible = true
		await game.dialogue.say([lines[i]])
	game.dialogue.visible = false
	await _wait(float(s.get("hold", 1.6)))
	await game._fade(true).finished
	_restore(speaker)
	game.dialogue.visible = true
	game._fade(false)
	game.emit_event("pageant_end", last)
	playing = false

func _ground(p: Vector2) -> Vector3:
	var g := Heightfield.height(p.x, p.y)
	var s: Dictionary = game.walk.surface_at(p.x, p.y, g + 0.6)
	return Vector3(p.x, float(s.y) if s.walkable else g, p.y)

func _free(p: Vector2) -> bool:
	return not game.walk.blocked(p.x, p.y, Heightfield.height(p.x, p.y), 0.25)

func _spot(off) -> Vector2: return Staging.free_spot(Staging.to_world(fr, off), _free)

func _face_point(a: Dictionary, at: Vector2) -> Vector2:
	if a.has("face"): return Staging.to_world(fr, a.face)
	return at + fr.fwd

func _agent(id: String):
	var a = game.npcs.get(id)
	if a == null or not a.present: return null
	return a

func _hold(a) -> void:
	if a.has_method("leave_bench"): a.leave_bench()
	held.append({"agent": a, "pos": a.pos, "yaw": a.yaw, "waypoints": a.waypoints.duplicate(), "talking": a.talking})
	if a.visiting(): a.end_visit()
	if a.riding: a._ride(false)
	a.held = true
	a.held_speed = 0.0
	a.waypoints = []
	a.character.stop_hold()
	a.stare_mark.visible = false

func _put(a, p: Vector2, yaw: float) -> void:
	a.pos = _ground(p)
	a.yaw = yaw
	a.sync()

func _stage(speaker) -> void:
	walkers = []
	singers = []
	candle_t = -1.0
	var cast := Staging.cast_ids(spec)
	var talker_id := String(speaker.def.id) if speaker else ""
	if speaker:
		_hold(speaker)
		var sp := _spot(spec.get("speaker", [1.0, 4.6]))
		_put(speaker, sp, Staging.yaw_to(sp, fr.origin))
	var me := _spot(spec.get("player", [-1.0, 4.6]))
	game.player.teleport(me.x, me.y, Staging.yaw_to(me, fr.origin))
	game.player_char.stop_hold()
	var crowd: Array = game.npcs.values().filter(func(a): return a.present and String(a.def.id) != talker_id and not cast.has(String(a.def.id)))
	var spots := Staging.crowd_spots(fr, spec, crowd.size())
	for i in crowd.size():
		var a = crowd[i]
		_hold(a)
		var p := Staging.free_spot(spots[i], _free)
		_put(a, p, Staging.yaw_to(p, fr.origin))
	for a in spec.get("actors", []):
		var at := _spot(a.get("at", [0.0, 0.0]))
		var start := Staging.free_spot(Staging.to_world(fr, Staging.entry_point(spec, a)), _free)
		var face := _face_point(a, at)
		var w := {"spec": a, "to": at, "yaw": Staging.yaw_to(at, face), "moving": false, "arrived": false, "every_t": 1.0}
		if a.has("npc"):
			var ag = _agent(String(a.npc))
			if ag == null: continue
			_hold(ag)
			w["agent"] = ag
			_put(ag, start, Staging.yaw_to(start, at))
			_wear(ag.character, String(a.get("wear", "")), String(a.get("color", "#6a7fb0")))
		elif a.has("node"):
			var n: Node3D = game.village.find_child(String(a.node), true, false) if game.village else null
			if n == null: continue
			moved.append({"node": n, "xf": n.global_transform, "visible": n.visible})
			w["node"] = n
			n.global_position = _ground(start)
			n.rotation.y = Staging.yaw_to(start, at)
		else: continue
		last.placed[String(a.get("npc", a.get("node", "")))] = [at.x, at.y]
		walkers.append(w)
	for pr in spec.get("props", []): _prop(pr)
	for c in Staging.candle_points(spec): _candle(c)

func _beat(i: int) -> void:
	line_now = i
	var b := Staging.beat(spec, i)
	last.beats.append(i)
	for w in walkers:
		if int(w.spec.get("beat", 0)) == i:
			w.moving = true
	if b.get("candles", false): candle_t = 0.0
	push_to = float(b.get("push", push_to))
	for id in b.get("sing", []):
		var a = _agent(String(id))
		if a == null: continue
		singers.append(a)
		a.character.play("sing", true)
		a.character.set_talking(true)
	if b.has("melody") and game.audio:
		for e in Staging.melody(b.melody): game.audio.play(String(e[0]), int(e[1]), float(e[2]), -1, float(e[3]))
	if b.has("event"): game.emit_event("scene_cue", {"cue": String(b.event), "at": fr.origin})
	if b.has("react"): _react(String(b.react), String(b.get("player", "")))

func _react(anim: String, me: String) -> void:
	var n := 0
	for h in held:
		var a = h.agent
		if a == null or singers.has(a): continue
		a.character.play(anim)
		n += 1
	for s in singers:
		s.character.stop_hold()
		s.character.set_talking(false)
		s.character.play(anim)
	n += singers.size()
	singers = []
	last["reacted"] = n
	if me != "": game.player_char.play(me)
	if game.audio and anim == "clap":
		for i in 14: game.audio.play("clap", 58 + randi() % 10, 0.2, -1, randf() * 1.6)
	game.effects.sparkle(Vector3(fr.origin.x, _ground(fr.origin).y + 2.0, fr.origin.y), 18, Color("ffe7a0"), 0.22)

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += minf(get_tree().root.get_process_delta_time(), 0.1)

func _process(dt: float) -> void:
	if not playing: return
	dt = minf(dt, 0.1)
	clock += dt
	for w in walkers:
		if not w.moving: continue
		var a: Dictionary = w.spec
		var animal: bool = w.has("node")
		var cur: Vector2
		if animal: cur = Vector2(w.node.global_position.x, w.node.global_position.z)
		else: cur = Vector2(w.agent.pos.x, w.agent.pos.z)
		var speed := float(a.get("speed", ANIMAL_SPEED if animal else WALK_SPEED))
		var nxt := Staging.walk_step(cur, w.to, speed, dt)
		var going := nxt.distance_to(w.to) > 0.01
		var heading: float = Staging.yaw_to(cur, w.to) if going else float(w.yaw)
		if animal:
			var n: Node3D = w.node
			var g := _ground(nxt)
			n.global_position = Vector3(nxt.x, g.y + (absf(sin(clock * 7.0)) * 0.04 if going else 0.0), nxt.y)
			n.rotation.y = lerp_angle(n.rotation.y, heading, 1.0 - exp(-6.0 * dt))
			n.rotation.z = sin(clock * 7.0) * 0.03 if going else 0.0
		else:
			var ag = w.agent
			ag.pos = _ground(nxt)
			ag.yaw = lerp_angle(ag.yaw, heading, 1.0 - exp(-8.0 * dt))
			ag.held_speed = speed / 4.4 if going else 0.0
		if not going and not w.arrived:
			w.arrived = true
			if not animal:
				var pose := String(a.get("pose", ""))
				if pose != "": w.agent.character.play(pose, true)
		if w.arrived and not animal and a.has("every"):
			w.every_t = float(w.every_t) - dt
			if float(w.every_t) <= 0.0:
				w.every_t = float(a.every.get("s", 3.0))
				w.agent.character.play(String(a.every.get("anim", "nod")))
	if candle_t >= 0.0:
		candle_t += dt
		var n := Staging.lit_count(spec, candle_t)
		for i in candles.size():
			if i < n and not candles[i].lit: _light(candles[i])
	for c in candles:
		if not c.lit: continue
		var f := 0.85 + 0.15 * sin(clock * 11.0 + float(c.ph)) * sin(clock * 7.3 + float(c.ph) * 2.0)
		(c.flame as Node3D).scale = Vector3(1.0, f, 1.0)
		if c.light: (c.light as OmniLight3D).light_energy = float(spec.get("candles", {}).get("energy", 0.9)) * f
	if not singers.is_empty():
		note_t -= dt
		if note_t <= 0.0:
			note_t = 0.7
			for s in singers: _note(s.character.head_world_pos() + Vector3(0, 0.3, 0))
	if not framed: return
	push = minf(1.0, push + dt / 16.0)
	var target := cam_from.lerp(look, push_to)
	cam_to = cam_to.lerp(target, 1.0 - exp(-0.8 * dt))
	game.cam.cinema = {"pos": cam_from.lerp(cam_to, smoothstep(0.0, 1.0, push)), "look": look}

func _frame_camera() -> void:
	var c: Dictionary = spec.get("camera", {})
	var lk: Array = c.get("look", [0.0, 0.8])
	var lp := Staging.to_world(fr, lk)
	look = Vector3(lp.x, _ground(fr.origin).y + float(c.get("look_up", 0.9)), lp.y)
	var dist := float(c.get("dist", 7.5))
	var up := float(c.get("up", 2.6))
	var pick := Vector3.INF
	var fallback := Vector3.INF
	var best := -1.0
	for lift in c.get("lifts", [1.0, 1.4, 1.9]):
		for side in c.get("sides", [0.0, 0.3, -0.3, 0.6, -0.6]):
			for k in [1.0, 0.85, 1.2]:
				var dir: Vector2 = (fr.fwd as Vector2).rotated(-float(side))
				var p := look + Vector3(dir.x, 0.0, dir.y) * dist * float(k) + Vector3(0, up * float(lift), 0)
				p.y = maxf(p.y, Heightfield.height(p.x, p.z) + 1.2)
				var v: Vector3 = p - look
				var clear: float = game.cam.clear_distance(look, v.normalized(), v.length())
				var inside: bool = game.walk.blocked(p.x, p.z, Heightfield.height(p.x, p.z), 0.3)
				if clear >= v.length() - 0.01 and not inside and not game.cam.blocked(p, look):
					pick = p
					break
				if clear > best:
					best = clear
					fallback = look + v.normalized() * maxf(clear - 0.3, 2.0)
			if pick != Vector3.INF: break
		if pick != Vector3.INF: break
	if pick == Vector3.INF: pick = fallback
	framed = true
	cam_from = pick
	cam_to = pick
	push = 0.0
	push_to = float(c.get("push", 0.12))
	last["camera"] = [pick.x, pick.y, pick.z]
	game.cam.cinema = {"pos": cam_from, "look": look}

func _wear(ch: Chibi, what: String, color: String) -> void:
	if what == "": return
	var m := P.fabric(color)
	var wood := P.mat("8a6a48")
	var g := Node3D.new()
	g.name = "pageant_" + what
	match what:
		"veil":
			ch.head.add_child(g)
			var shell := P.mi(P.hemi(Chibi.HEAD_R * 1.14, 20), m, Vector3(0, 0.02, -0.04))
			shell.scale = Vector3(1.04, 1.12, 1.08)
			g.add_child(shell)
			g.add_child(P.mi(P.box(Chibi.HEAD_R * 1.9, Chibi.HEAD_R * 1.5, 0.05), m, Vector3(0, -Chibi.HEAD_R * 0.55, -Chibi.HEAD_R * 0.98)))
			for s in [-1.0, 1.0]:
				g.add_child(P.mi(P.box(0.06, Chibi.HEAD_R * 1.3, Chibi.HEAD_R * 1.1), m, Vector3(s * Chibi.HEAD_R * 1.06, -Chibi.HEAD_R * 0.45, -Chibi.HEAD_R * 0.35)))
		"staff":
			ch.add_child(g)
			g.position = Vector3(0.36, 0.0, 0.14)
			g.add_child(P.mi(P.cyl(0.025, 0.03, 1.55, 8), wood, Vector3(0, 0.78, 0)))
		"crook":
			ch.add_child(g)
			g.position = Vector3(0.36, 0.0, 0.14)
			g.add_child(P.mi(P.cyl(0.022, 0.026, 1.45, 8), wood, Vector3(0, 0.72, 0)))
			var a := P.mi(P.cyl(0.022, 0.022, 0.2, 8), wood, Vector3(0.07, 1.5, 0))
			a.rotation.z = -1.0
			g.add_child(a)
			var b := P.mi(P.cyl(0.022, 0.022, 0.16, 8), wood, Vector3(0.16, 1.47, 0))
			b.rotation.z = 0.5
			g.add_child(b)
		"lantern":
			ch.add_child(g)
			g.position = Vector3(0.34, 0.5, 0.12)
			g.add_child(P.mi(P.box(0.12, 0.16, 0.12), P.mat("2b2826")))
			g.add_child(P.mi(P.box(0.09, 0.11, 0.09), P.unique_mat("ffd27a", "ffc04a", 1.6), Vector3(0, 0, 0), false))
		_:
			g.free()
			return
	worn.append(g)

func _prop(pr: Dictionary) -> void:
	var at := Staging.to_world(fr, pr.get("at", [0.0, 0.0]))
	var root := Node3D.new()
	root.name = "pageant_" + String(pr.get("kind", "prop"))
	add_child(root)
	root.global_position = _ground(at)
	root.rotation.y = Staging.yaw_to(at, at + fr.fwd)
	match String(pr.get("kind", "")):
		"manger":
			var wood := P.mat("7a5a3a")
			for s in [-1.0, 1.0]:
				var leg := P.mi(P.box(0.06, 0.36, 0.5), wood, Vector3(s * 0.38, 0.18, 0))
				root.add_child(leg)
			root.add_child(P.mi(P.box(0.82, 0.18, 0.4), wood, Vector3(0, 0.36, 0)))
			root.add_child(P.mi(P.box(0.76, 0.06, 0.34), P.mat("d8bd6a"), Vector3(0, 0.46, 0)))
			var bundle := P.mi(P.sphere(0.12, 12, 8), P.fabric("f4ecdc"), Vector3(0, 0.52, 0.0))
			bundle.scale = Vector3(1.5, 0.75, 0.9)
			root.add_child(bundle)
			root.add_child(P.mi(P.sphere(0.06, 10, 8), P.mat("f2c8a8"), Vector3(0.16, 0.56, 0.0)))
		"bale":
			root.add_child(P.mi(P.box(0.7, 0.36, 0.42), P.mat("d8bd6a"), Vector3(0, 0.18, 0)))
		_: pass
	props.append(root)

func _candle(p: Vector2) -> void:
	var root := Node3D.new()
	root.name = "pageant_candle"
	add_child(root)
	root.global_position = _ground(p)
	root.add_child(P.mi(P.cyl(0.075, 0.08, 0.16, 10), P.mat("e9dfc9"), Vector3(0, 0.08, 0)))
	root.add_child(P.mi(P.cyl(0.05, 0.05, 0.12, 10), P.mat("f6f0e2"), Vector3(0, 0.22, 0)))
	var flame := Node3D.new()
	flame.position = Vector3(0, 0.3, 0)
	flame.visible = false
	root.add_child(flame)
	var fm := P.mi(P.sphere(0.03, 8, 6), P.unique_mat("ffb347", "ffa030", 3.0), Vector3(0, 0.03, 0), false)
	fm.scale = Vector3(0.8, 1.8, 0.8)
	flame.add_child(fm)
	var li: OmniLight3D = null
	if candles.size() % 2 == 0:
		li = OmniLight3D.new()
		li.light_color = Color("ffb862")
		li.omni_range = float(spec.get("candles", {}).get("range", 3.2))
		li.light_energy = 0.0
		li.shadow_enabled = false
		li.visible = false
		li.position = Vector3(0, 0.45, 0)
		root.add_child(li)
	candles.append({"root": root, "flame": flame, "light": li, "lit": false, "ph": float(candles.size()) * 1.7})

func _light(c: Dictionary) -> void:
	c.lit = true
	(c.flame as Node3D).visible = true
	if c.light: (c.light as OmniLight3D).visible = true
	game.effects.sparkle((c.root as Node3D).global_position + Vector3(0, 0.35, 0), 4, Color("ffd27a"), 0.12)

func _note(at: Vector3) -> void:
	var l := Label3D.new()
	l.text = "♪" if randf() < 0.6 else "♫"
	l.font_size = 64
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("6a4a8a")
	l.outline_modulate = Color.WHITE
	l.outline_size = 12
	add_child(l)
	l.global_position = at + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", at.y + 0.9, 1.8)
	tw.tween_property(l, "modulate:a", 0.0, 1.8).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

func lit() -> int: return candles.filter(func(c): return c.lit).size()

func _restore(speaker) -> void:
	for s in singers: s.character.set_talking(false)
	singers = []
	for h in held:
		var a = h.agent
		a.character.stop_hold()
		a.character.visible = a.present
		a.held = false
		a.held_speed = 0.0
		a.pos = h.pos
		a.yaw = h.yaw
		a.waypoints = h.waypoints
		a.talking = bool(h.talking)
		a.sync()
	held = []
	for m in moved:
		var n: Node3D = m.node
		n.global_transform = m.xf
		n.visible = bool(m.visible)
	moved = []
	for g in worn:
		if is_instance_valid(g): g.get_parent().remove_child(g); g.queue_free()
	worn = []
	for pr in props: pr.queue_free()
	props = []
	for c in candles: (c.root as Node3D).queue_free()
	candles = []
	walkers = []
	candle_t = -1.0
	framed = false
	game.cam.cinema = {}
	game.player.teleport(float(back.x), float(back.z), float(back.yaw))
	if speaker: speaker.talking = true
