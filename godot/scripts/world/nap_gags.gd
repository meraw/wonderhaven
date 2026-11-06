class_name NapGags
extends Node3D
## The scene when you wake up from a nap on a bench (game.sleep_until). You wake slumped on the bench and, now and
## then (BenchNap picks; odds and lines in data/naps.json), the local paper you slept under blows away, you're
## soaked from the rain or from a stranger's wet umbrella left open beside you, or a villager caught staring at you
## hurries off. wake() sets the scene while the screen is still faded out; play() runs the joke once it fades in.

const P := preload("res://scripts/world/palette.gd")
const UMBRELLA_COLORS := ["e0524f", "3f7fd9", "f2b632", "5aa86b", "9b6fd1"]

var game
var gag := ""
var line := ""
var watcher = null      # the villager caught staring
var paper: Node3D       # the sheets over you
var umbrella: Node3D

func setup(g) -> void: game = g

## Where you lie on a seat (a bench in the layout, or a bench or sofa you built): the middle of it, at the seat.
static func seat_spot(seat: Dictionary) -> Vector3:
	var b := BuildGrid.bounds(seat)
	return Vector3((b.minX + b.maxX) / 2.0, float(seat.y) + 0.28, (b.minZ + b.maxZ) / 2.0)

## Whatever the last nap left behind (an umbrella, a puddle, paper, you dripping): gone by the next time you sleep.
func clear() -> void:
	for c in get_children(): remove_child(c); c.queue_free()   # out of the scene now, so new props keep their names
	var drips: Node = game.player_char.get_node_or_null("drips")
	if drips: game.player_char.remove_child(drips); drips.queue_free()
	if watcher:
		var mark: Node = watcher.character.get_node_or_null("stare")
		if mark: mark.queue_free()
	paper = null; umbrella = null; watcher = null; gag = ""; line = ""

## Called while the screen is faded out after a nap that began at clock time t0: puts you on the bench, works out the
## gag (BenchNap.pick) and sets its scene. Returns the gag's id, or "" for a quiet nap.
func wake(seat: Dictionary, t0: Dictionary) -> String:
	var s: Dictionary = game.state
	game.sit_on(seat, "sleep", true)
	var spot: Vector3 = game.player.pos
	var naps: Dictionary = Data.naps_here()
	var watchers := _watchers(spot)
	var raining: bool = game.settings.get("weather", true) and BenchNap.rained(t0, s.time, Daylight.allowed_here(), s.get("forced_weather", {}))
	var ctx := {"indoors": _indoors(spot), "rained": raining, "watchers": watchers.map(func(a): return a.def.name), "last": String(s.get("naps", {}).get("last", ""))}
	# Test-only: --napgag=<id> (or shot_cfg) picks the joke; "auto" lets the rules decide. A scripted playthrough naps
	# quietly unless it asks, so jokes at random can't upset what it's checking.
	var forced: String = String(game.shot_cfg.get("napgag", "" if game.shot_cfg.has("autoplay") else "auto"))
	gag = BenchNap.pick(naps, ctx, randf(), randf()) if forced == "auto" else forced
	if gag == "stared" and watchers.is_empty(): gag = ""
	watcher = watchers.pick_random() if gag == "stared" else null
	line = BenchNap.line(naps, gag, randf(), watcher.def.name if watcher else "")
	if gag != "": s["naps"] = {"last": gag, "gags": int(s.get("naps", {}).get("gags", 0)) + 1}
	var f := Vector3(sin(game.player.yaw), 0.0, cos(game.player.yaw))   # the way the bench faces
	var side := Vector3(f.z, 0.0, -f.x)
	match gag:
		"newspaper": _cover_with_paper(spot, f)
		"umbrella": _open_umbrella(spot, f, side); _puddle(spot, 0.45)
		"rain": _puddle(spot, 0.95)
		"stared": _place_watcher(spot, f, side)
	if gag != "":   # a view of the bench from the front, a little to one side
		game.cam.yaw = game.player.yaw + 0.55; game.cam.pitch = 0.38; game.cam.dist = 6.0
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	return gag

## Once the screen has faded back in: a beat, then the joke with the greeting and a line about it as a banner, then
## you're sitting up on the bench (move to get up). A quiet nap just shows the greeting.
func play(greet: String, sub: String) -> void:
	if gag == "":
		game.banner(greet, sub)
		await _wait(1.2)
		if not game.sitting.is_empty(): game.player_char.play("sit", true)
		return
	game.set_mode("cutscene")
	await _wait(0.7)
	game.banner(greet, line, [], 4.5)
	game.player_char.play("sit", true)
	match gag:
		"newspaper":
			game.sfx("rustle"); game.player_char.play("surprised")
			for sh in paper.get_children(): sh.set_meta("flying", true)
			get_tree().create_timer(4.0).timeout.connect(paper.queue_free)
		"rain", "umbrella":
			game.sfx("water"); _drip(game.player_char, 28.0)
			game.player_char.play("shake"); game.player_char.set_mood("sad", 3.0)
		"stared":
			watcher.character.play("surprised"); game.voice(watcher.def.get("voice", 1.0), 2)
			game.player_char.play("surprised")
			await _wait(0.7)
			var mark: Node = watcher.character.get_node_or_null("stare")
			if mark: mark.queue_free()
			watcher.hurry_t = 6.0; watcher.plan_route(watcher.goal, _dash_from_bench())
	game.emit_event("napgag", {"id": gag})
	await _wait(1.0)
	if game.mode == "cutscene": game.set_mode("explore")

func _wait(seconds: float) -> void: await get_tree().create_timer(seconds).timeout

## A sofa in your own house, or a bench indoors: under a room's roof or a roof you built.
func _indoors(p: Vector3) -> bool:
	for rm in game.cam.rooms:
		var room: AABB = rm
		if room.has_point(Vector3(p.x, room.position.y + 1.0, p.z)): return true
	for pl in game.state.placements:
		if pl.id != "roof": continue
		var b := BuildGrid.bounds(pl)
		if p.x >= b.minX and p.x <= b.maxX and p.z >= b.minZ and p.z <= b.maxZ and float(b.bottom) > p.y: return true
	return false

## Villagers who could have been standing over you: out and about (not asleep or talking), and with somewhere to
## hurry off to (their routine takes them a good way from the bench).
func _watchers(spot: Vector3) -> Array:
	return game.npcs.values().filter(func(a): return a.present and not a.talking and a.activity != "sleep" and Vector2(a.pos.x - spot.x, a.pos.z - spot.z).length() > 6.0)

## Where the watcher dashes first: straight away from the bench, a few metres, somewhere they can stand.
func _dash_from_bench() -> Vector2:
	var me := Vector2(game.player.pos.x, game.player.pos.z)
	var at := Vector2(watcher.pos.x, watcher.pos.z)
	var want := at + (at - me).normalized() * 4.0
	var ok: Dictionary = game.walk.free_spot(want.x, want.y, Rect2(), 2.5, 0.32, watcher.body)
	return Vector2(float(ok.x), float(ok.z)) if not ok.is_empty() else at

func _place_watcher(spot: Vector3, f: Vector3, side: Vector3) -> void:
	var want: Vector3 = spot + f * 0.75 - side * 1.0   # beside the bench, leaning in (the camera looks from the other side)
	var at: Dictionary = game.walk.free_spot(want.x, want.z, Rect2(), 2.5, 0.32, watcher.body)
	if at.is_empty(): at = {"x": want.x, "z": want.z}
	watcher.pos = Vector3(float(at.x), game.walk.surface_at(float(at.x), float(at.z)).y, float(at.z))
	watcher.waypoints = []; watcher.greeted = true
	watcher.yaw = atan2(spot.x - watcher.pos.x, spot.z - watcher.pos.z); watcher.sync()
	var mark := Label3D.new(); mark.name = "stare"; mark.text = "!?"; mark.font_size = 64; mark.pixel_size = 0.006
	mark.modulate = Color("5a4a6a"); mark.outline_size = 14; mark.outline_modulate = Color.WHITE
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED; mark.position = Vector3(0, 2.2, 0)
	watcher.character.add_child(mark)

# ---- The paper ---------------------------------------------------------------------------------------------------
## A few sheets of the local paper over you, as if someone had tucked you in with it. play() lets the wind take them.
func _cover_with_paper(spot: Vector3, f: Vector3) -> void:
	paper = Node3D.new(); paper.name = "NapPaper"; add_child(paper)
	paper.global_position = spot
	var yaw: float = game.player.yaw
	var w: Dictionary = game.weather_now
	var wind := Atmosphere.wind_at(int(game.state.time.day), float(game.state.time.minute) / 60.0, w)
	var away := Vector3(wind.x, 0.0, wind.y).normalized()
	if away.length() < 0.5: away = f
	var side := Vector3(f.z, 0.0, -f.x)
	# Measured on the napper (Chibi, the "sleep" pose, relative to the seat point; +z the way the bench faces): the
	# head's centre is about 0.81 m up and 0.13 m forward (nodding), the hair reaching 0.58 m from it; the seat's top is
	# 0.18 m up, and the ground 0.28 m down. One spread is draped over the head and face like a tent, one lies across
	# the lap, one on the seat beside you and one has slid off onto the ground.
	var sheets := [
		_drape([Vector2(-0.14, 1.4), Vector2(0.2, 1.42), Vector2(0.52, 1.27), Vector2(0.72, 0.98), Vector2(0.72, 0.7), Vector2(0.62, 0.48)], 0.7),
		_drape([Vector2(0.24, 0.5), Vector2(0.36, 0.3), Vector2(0.62, 0.27), Vector2(0.8, 0.22)], 0.58),
		_drape([Vector2(-0.18, 0.19), Vector2(0.28, 0.19)], 0.5),
		_drape([Vector2(0.55, -0.265), Vector2(1.0, -0.265)], 0.62)]
	var at := [Vector3.ZERO, Vector3(0.02, 0.0, 0.0), Vector3(0.58, 0.0, 0.06), Vector3(-0.42, 0.0, 0.0)]
	var turn := [0.0, 0.06, 0.35, -0.6]
	for k in sheets.size():
		var sh := PaperSheet.new(); sh.mesh_node = P.mi(sheets[k], _newsprint(), Vector3.ZERO, false)
		sh.add_child(sh.mesh_node); paper.add_child(sh)
		sh.position = side * at[k].x + Vector3(0, at[k].y, 0) + f * at[k].z
		sh.rotation = Vector3(0.0, yaw + turn[k], 0.0)
		sh.vel = away * randf_range(1.6, 2.6) + Vector3(0, randf_range(1.4, 2.2), 0) + f.rotated(Vector3.UP, randf_range(-1, 1)) * 0.4
		sh.spin = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
		sh.delay = [0.25, 0.0, 0.45, 0.6][k]

## A sheet of paper bent along a profile: points (forward, up) in the sheet's own frame (+z forward), `width` across.
## Lengthwise the page's texture runs along the bend, so a long profile reads as a double-page spread.
static func _drape(profile: Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := 0.0
	for i in range(1, profile.size()): total += (profile[i] - profile[i - 1]).length()
	var run := 0.0
	var verts: Array = []
	for i in profile.size():
		if i > 0: run += (profile[i] - profile[i - 1]).length()
		var u := run / total
		var pt: Vector2 = profile[i]
		verts.append([Vector3(-width / 2.0, pt.y, pt.x), Vector3(width / 2.0, pt.y, pt.x), u])
	for i in range(profile.size() - 1):
		var a: Array = verts[i]; var b: Array = verts[i + 1]
		var along: Vector3 = b[0] - a[0]
		var n := along.cross(Vector3.RIGHT).normalized()
		if n.y < 0.0 and absf(n.y) > 0.01: n = -n
		for v in [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [a[0], 0.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]:
			st.set_normal(n); st.set_uv(Vector2(v[1], v[2])); st.add_vertex(v[0])
	return st.commit()

static var _paper_mat: StandardMaterial3D
## Newsprint: an off-white page with a masthead, columns of grey lines and a photo.
static func _newsprint() -> StandardMaterial3D:
	if _paper_mat: return _paper_mat
	var W := 256; var H := 192
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.94, 0.92, 0.86))
	var ink := Color(0.25, 0.25, 0.28); var text := Color(0.62, 0.62, 0.64)
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	var x := 40   # the title: a row of chunky letter blocks, centred, between two rules
	while x < W - 44:
		var lw := rng.randi_range(7, 12)
		img.fill_rect(Rect2i(x, 10, lw, 16), ink)
		if rng.randf() < 0.5: img.fill_rect(Rect2i(x + 2, 15, lw - 4, 6), Color(0.94, 0.92, 0.86))
		x += lw + 3
	img.fill_rect(Rect2i(10, 32, W - 20, 2), ink); img.fill_rect(Rect2i(10, 37, W - 20, 1), ink)
	img.fill_rect(Rect2i(12, 44, W - 24, 9), Color(0.4, 0.4, 0.43))   # the headline
	for c in 3:   # three columns of text, with a photo in the middle one
		var x0 := 12 + c * 80
		for y in range(60, H - 8, 4):
			if c == 1 and y > 62 and y < 118: continue
			img.fill_rect(Rect2i(x0, y, rng.randi_range(56, 72), 2), text)
	img.fill_rect(Rect2i(92, 64, 72, 52), Color(0.66, 0.64, 0.6))
	img.fill_rect(Rect2i(104, 74, 26, 30), Color(0.48, 0.47, 0.45)); img.fill_rect(Rect2i(136, 86, 20, 18), Color(0.55, 0.54, 0.52))
	_paper_mat = StandardMaterial3D.new()   # its own material: the shared ones (P.mat) are cached and textured
	_paper_mat.albedo_texture = ImageTexture.create_from_image(img)
	_paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED; _paper_mat.roughness = 0.9
	return _paper_mat

## A sheet that lies still until play() sets it flying, then is carried off on the wind, tumbling, and goes.
class PaperSheet extends Node3D:
	var mesh_node: MeshInstance3D
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var delay := 0.0
	var t := 0.0
	func _process(dt: float) -> void:
		if not get_meta("flying", false): return
		delay -= dt
		if delay > 0.0: return
		t += dt
		position += vel * dt
		vel.y -= 0.6 * dt; vel *= 1.0 - 0.15 * dt
		rotation += spin * dt
		if t > 2.6: scale = Vector3.ONE * maxf(0.01, 1.0 - (t - 2.6) / 0.8)
		if t > 3.4: queue_free()

# ---- Wet ---------------------------------------------------------------------------------------------------------
## A stranger's umbrella, left open beside the bench to dry, leaning over you and dripping. It's gone (its owner came
## back for it) once you've walked off, or after a while.
func _open_umbrella(spot: Vector3, f: Vector3, side: Vector3) -> void:
	umbrella = TimedProp.new(); umbrella.name = "NapUmbrella"; add_child(umbrella)
	var base: Vector3 = spot + side * 0.98 + f * 0.12   # standing just off the end of the seat
	umbrella.global_position = Vector3(base.x, game.walk.surface_at(base.x, base.z).y, base.z)
	umbrella.game = game; umbrella.life = 90.0
	var lean := Node3D.new(); umbrella.add_child(lean)
	lean.transform.basis = Basis(Vector3.UP.cross(-side).normalized(), 0.3)   # tipped towards you, its canopy over your head
	var col := Color(UMBRELLA_COLORS.pick_random())
	var iron := P.mat("3a3a3a")
	lean.add_child(P.mi(P.cyl(0.012, 0.012, 1.86, 6), iron, Vector3(0, 0.93, 0)))
	lean.add_child(P.mi(_canopy(0.82, 0.34, 8, col, col.lightened(0.55)), _canopy_mat(), Vector3(0, 1.62, 0)))
	lean.add_child(P.mi(P.cyl(0.006, 0.014, 0.12, 5), iron, Vector3(0, 2.0, 0)))   # the ferrule on top
	var hook := P.mi(P.torus(0.06, 0.016, 12), P.mat("6b3a22"), Vector3(0.06, 0.03, 0)); hook.rotation = Vector3(PI / 2, 0, 0); lean.add_child(hook)
	umbrella.set_meta("edge", -side * 1.0 + Vector3(0, 1.08, 0))   # the canopy's low edge, over your shoulder
	var drip_at := Node3D.new(); umbrella.add_child(drip_at); drip_at.position = umbrella.get_meta("edge")   # its low edge, over you
	_drip(drip_at, 90.0, 0.05)

## An umbrella's canopy: `gores` panels in two alternating colours, each a little dome stretched between two ribs,
## the rim dipping at each rib's tip and lifting between them; open underneath, from the top at y = height.
static func _canopy(r: float, height: float, gores: int, a: Color, b: Color) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 4
	var cols := 6   # across each gore
	for g in gores:
		var c: Color = a if g % 2 == 0 else b
		var pts: Array = []   # [ring][col]
		for k in rings + 1:
			var row: Array = []
			var fr := float(k) / rings
			for j in cols + 1:
				var ang := TAU * (g + float(j) / cols) / gores
				var mid := sin(PI * float(j) / cols)   # 0 at the ribs, 1 between them
				var rr := r * fr * (1.0 - 0.06 * mid * fr)
				var y := height * (1.0 - fr * fr) + 0.05 * mid * fr * fr   # a dome, the panel lifting between ribs
				row.append(Vector3(cos(ang) * rr, y - height, sin(ang) * rr))
			pts.append(row)
		for k in rings:
			for j in cols:
				var q := [pts[k][j], pts[k][j + 1], pts[k + 1][j + 1], pts[k + 1][j]]
				var n: Vector3 = (q[2] - q[0]).cross(q[1] - q[3]).normalized()
				if n.y < 0.0: n = -n
				for v in [q[0], q[2], q[1], q[0], q[3], q[2]]:
					st.set_color(c); st.set_normal(n); st.add_vertex(v + Vector3(0, height, 0))
	return st.commit()

static func _canopy_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.roughness = 0.55
	return m

## Drops of water falling off something (you, or the umbrella's edge) for a while.
func _drip(on: Node3D, seconds: float, box: float = 0.22) -> void:
	var p := CPUParticles3D.new(); p.name = "drips"
	var quad := QuadMesh.new(); quad.size = Vector2(0.05, 0.1)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.62, 0.8, 1.0, 0.85); quad.material = m
	p.mesh = quad; p.amount = 30; p.lifetime = 0.6; p.local_coords = false
	p.direction = Vector3.DOWN; p.spread = 8.0; p.initial_velocity_min = 0.2; p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(box, box * 1.4, box)
	p.position = Vector3(0, 0.75, 0) if on is Chibi else Vector3.ZERO
	on.add_child(p); p.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(p): p.emitting = false; get_tree().create_timer(1.0).timeout.connect(p.queue_free))

## A puddle under the bench that dries up.
func _puddle(spot: Vector3, r: float) -> void:
	var pd := TimedProp.new(); pd.name = "NapPuddle"; pd.game = game; pd.life = 45.0; pd.fades = true; add_child(pd)
	pd.global_position = Vector3(spot.x, game.walk.surface_at(spot.x, spot.z).y + 0.015, spot.z)
	var m := P.unique_mat("5d7c99"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.45; m.roughness = 0.05
	pd.add_child(P.mi(P.cyl(r, r, 0.01, 20), m, Vector3.ZERO, false))

## A prop that stays for `life` seconds (or until you've walked well away from it), fading out if it `fades`.
class TimedProp extends Node3D:
	var game
	var life := 60.0
	var fades := false
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		var far: bool = t > 8.0 and game != null and global_position.distance_to(game.player.pos) > 15.0
		if fades:
			for mi in find_children("*", "MeshInstance3D", true, false):
				var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
				if m: m.albedo_color.a = 0.45 * clampf(1.0 - t / life, 0.0, 1.0)
		if t > life or (far and not fades):
			if game and not fades: game.effects.poof(global_position + Vector3(0, 1.0, 0))
			queue_free()
