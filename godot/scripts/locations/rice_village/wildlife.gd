extends Node3D
## Casalrana's animals (stage 4), all for looking at (nothing here blocks anyone's way):
## - grey herons and white egrets standing still in the ditches, the spring pool, the flooded plain past the edge and
##   (once it's flooded) the winter paddy; come too close and they take off with a croak and land somewhere else;
## - flocks of lapwings on the stubble that wheel up when you walk at them, flashing black and white, and settle on
##   another field;
## - now and then a V of cranes passing high over the plain, trumpeting (twice on most days, by the clock);
## - at Cascina Grande: the white Piedmontese cows, the ox and the donkey in a paddock behind the cowshed, chickens
##   pecking by the barn, and two cats that let you stroke them.
## The decisions (where a bird goes, when the cranes pass) are static functions, tested in test_rice_village.gd.
const P := preload("res://scripts/world/palette.gd")
const Sounds := preload("res://scripts/locations/rice_village/sounds.gd")

## Where herons and egrets wade: ditch puddles (rice_village.gd's PUDDLES), the spring pool's edge and the flooded
## plain past the edge.
const WADE := [Vector2(-4.9, -20.8), Vector2(-24.9, -22.1), Vector2(-48.2, -33.1), Vector2(31.0, 25.8), Vector2(43.3, 13.9),
	Vector2(-49.6, 12.4), Vector2(-13.5, 24.5), Vector2(47.4, 24.1), Vector2(-21.5, 34.6), Vector2(-25.6, 30.8),
	Vector2(60.5, 8.0), Vector2(-60.0, 18.0), Vector2(22.0, 60.0), Vector2(-30.0, 60.5), Vector2(61.0, -24.0)]
## The winter paddy once Water for the Winter has flooded it.
const PADDY := [Vector2(-29.5, 10.8), Vector2(-25.2, 15.6)]
const PADDY_FLAG := "rice_village_paddyFlooded"
## Open stubble where the lapwings feed (away from paths, buildings and the line).
const FIELDS := [Vector2(-22.0, 21.0), Vector2(30.0, 31.0), Vector2(-12.0, -33.0), Vector2(24.0, 15.0), Vector2(-27.0, -35.0), Vector2(-45.0, 0.0)]
const PADDOCK := Rect2(45.2, -3.6, 5.8, 9.4)    # behind the cowshed (its east wall is at x 44)
const HENS := Vector2(31.0, -1.2)               # between the barn front and the tractor
const SHY := {"heron": 8.0, "egret": 7.0}       # how close you can get before they fly
const LAPWING_SHY := 9.0
const CRANE_HEIGHT := 26.0
const CRANE_TIMES := [630.0, 850.0]             # minutes of the day the cranes start across (10:30, 14:10)
const CRANE_MINUTES := 40.0                     # a crossing takes this long (40 real seconds at the game's pace)

var game = null
var village: Node3D
var t := 0.0
var waders: Array = []
var flocks: Array = []
var cranes: Node3D
var crane_birds: Array = []
var herd: Array = []
var hens: Array = []
var cats: Array = []
var forced_cranes := -1.0     # screenshots and playthroughs can send the cranes over (seconds left)

# ---- Decisions (pure) ---------------------------------------------------------------------------------------

## Where a startled bird flies: the free spot farthest from you (spots in `taken` are occupied; `from` is where the
## bird is, never chosen again).
static func next_spot(spots: Array, taken: Array, player: Vector2, from: Vector2) -> Vector2:
	var best := from; var bd := -1.0
	for s in spots:
		if s == from or taken.has(s): continue
		var d: float = (s as Vector2).distance_to(player)
		if d > bd: bd = d; best = s
	return best

## Does a bird standing at `at` take off with you at `player`?
static func startled(at: Vector2, player: Vector2, shy: float) -> bool: return at.distance_to(player) < shy

## How far through a crane crossing the clock is (0..1), or -1 when no cranes are passing. Most days have two
## crossings; every third day only the afternoon one.
static func crane_pass(day: int, minute: float) -> float:
	for k in CRANE_TIMES.size():
		if k == 0 and day % 3 == 2: continue
		var start: float = CRANE_TIMES[k] + float((day * 37 + k * 11) % 50)
		if minute >= start and minute < start + CRANE_MINUTES: return (minute - start) / CRANE_MINUTES
	return -1.0

## Wading spots in use for these story flags (the winter paddy only once it's flooded).
static func wade_spots(flags: Dictionary) -> Array:
	var out: Array = WADE.duplicate()
	if flags.get(PADDY_FLAG, false): out.append_array(PADDY)
	return out

# ---- Building -----------------------------------------------------------------------------------------------

func setup(g, v: Node3D) -> void:
	game = g; village = v
	var kinds := ["heron", "egret", "heron", "egret", "egret", "heron", "egret"]
	var spots := wade_spots(_flags())
	for i in kinds.size():
		var s: Vector2 = spots[(i * 2) % spots.size()]
		var b := _wader(kinds[i])
		add_child(b.obj)
		b["at"] = s; b["kind"] = kinds[i]; b["state"] = "stand"; b["ph"] = i * 1.3; b["calm"] = 0.0
		b.obj.position = _ground(s); b.obj.rotation.y = i * 1.7
		waders.append(b)
	for f in 2:
		var flock := {"at": FIELDS[f * 3], "state": "ground", "birds": [], "t": 0.0, "calm": 0.0}
		for k in 10:
			var bird := _lapwing()
			add_child(bird.obj)
			bird["off"] = Vector2(cos(k * 2.4) * (0.6 + k * 0.25), sin(k * 2.4) * (0.6 + k * 0.25)); bird["ph"] = k * 0.7
			flock.birds.append(bird)
		flocks.append(flock)
	_build_cranes()
	_build_farm()

func _flags() -> Dictionary: return game.state.flags if game != null and game.get("state") != null else {}

func _ground(s: Vector2) -> Vector3: return Vector3(s.x, Heightfield.height(s.x, s.y), s.y)

## A wading bird: body, an S-necked head on a pivot (it stretches up now and then), legs, and wings that fold along
## the body when standing and spread to fly.
func _wader(kind: String) -> Dictionary:
	var white := kind == "egret"
	var sc := 0.78 if white else 1.0
	var plume := P.mat("f4f4f0" if white else "9aa3ab"); var dark := P.mat("2b2b30" if white else "3a3c44")
	var beak := P.mat("2a2a2a" if white else "d8b23a"); var legc := P.mat("2a2a2a" if white else "a08a52")
	var o := Node3D.new(); o.scale = Vector3.ONE * sc
	var body := P.mi(P.sphere(0.2, 12, 8), plume, Vector3(0, 0.78, 0)); body.scale = Vector3(0.9, 0.85, 1.7); o.add_child(body)
	var tail := P.mi(P.cone(0.12, 0.3, 8), plume, Vector3(0, 0.74, -0.38)); tail.rotation.x = -PI / 2 - 0.3; o.add_child(tail)
	var neck := Node3D.new(); neck.position = Vector3(0, 0.88, 0.22); o.add_child(neck)
	var n1 := P.mi(P.cyl(0.045, 0.06, 0.34, 8), plume, Vector3(0, 0.15, 0.04)); n1.rotation.x = 0.3; neck.add_child(n1)
	var head := Node3D.new(); head.position = Vector3(0, 0.33, 0.09); neck.add_child(head)
	head.add_child(P.mi(P.sphere(0.07, 10, 8), plume))
	var bk := P.mi(P.cone(0.028, 0.24, 6), beak, Vector3(0, -0.01, 0.16)); bk.rotation.x = PI / 2; head.add_child(bk)
	if not white:
		var crest := P.mi(P.cyl(0.012, 0.004, 0.2, 4), dark, Vector3(0, 0.02, -0.12)); crest.rotation.x = -PI / 2 + 0.4; head.add_child(crest)
		head.add_child(P.mi(P.box(0.145, 0.025, 0.1), dark, Vector3(0, 0.035, -0.01)))
	var legs := Node3D.new(); o.add_child(legs)
	for s in [-1, 1]:
		legs.add_child(P.mi(P.cyl(0.013, 0.013, 0.66, 4), legc, Vector3(s * 0.06, 0.33, 0.02)))
	var wings: Array = []
	for s in [-1, 1]:
		var w := Node3D.new(); w.position = Vector3(s * 0.12, 0.86, 0.04); o.add_child(w)
		var m := P.mi(P.box(0.8, 0.03, 0.42), plume, Vector3(s * 0.4, 0, -0.04)); w.add_child(m)
		w.add_child(P.mi(P.box(0.26, 0.032, 0.36), dark, Vector3(s * 0.7, 0, -0.06)))
		wings.append(w)
	return {"obj": o, "neck": neck, "legs": legs, "wings": wings, "sc": sc}

## A lapwing: a small dark bird with a white belly and a wispy crest.
func _lapwing() -> Dictionary:
	var o := Node3D.new()
	var dark := P.mat("23302c"); var white := P.mat("f2f2ec")
	o.add_child(P.mi(P.sphere(0.07, 8, 6), white, Vector3(0, 0.1, 0), false))
	var back := P.mi(P.sphere(0.072, 8, 6), dark, Vector3(0, 0.125, -0.01), false); back.scale = Vector3(1, 0.7, 1.3); o.add_child(back)
	o.add_child(P.mi(P.sphere(0.045, 8, 6), dark, Vector3(0, 0.17, 0.07), false))
	var crest := P.mi(P.cyl(0.006, 0.002, 0.08, 3), dark, Vector3(0, 0.22, 0.04), false); crest.rotation.x = -0.9; o.add_child(crest)
	var wings: Array = []
	for s in [-1, 1]:
		var w := Node3D.new(); w.position = Vector3(s * 0.05, 0.13, 0); o.add_child(w)
		w.add_child(P.mi(P.box(0.2, 0.012, 0.09), dark, Vector3(s * 0.1, 0, 0), false))
		w.add_child(P.mi(P.box(0.06, 0.014, 0.08), white, Vector3(s * 0.19, 0, 0), false))
		w.visible = false; wings.append(w)
	return {"obj": o, "wings": wings}

func _build_cranes() -> void:
	cranes = Node3D.new(); cranes.name = "cranes"; cranes.visible = false; add_child(cranes)
	# dark against the pale sky, not faded by the haze (they're seen far off)
	var grey := _clear_mat("767d84"); var black := _clear_mat("26262a"); var white := _clear_mat("dcdbd6"); var red := _clear_mat("c23a32")
	for k in 9:
		var side := 0 if k == 0 else (1 if k % 2 == 1 else -1)
		var rank := int((k + 1) / 2)
		var b := Node3D.new(); b.position = Vector3(side * rank * 2.6, 0, -rank * 2.4); cranes.add_child(b)
		var body := P.mi(P.sphere(0.3, 10, 8), grey, Vector3.ZERO, false); body.scale = Vector3(0.8, 0.7, 1.8); b.add_child(body)
		var neck := P.mi(P.cyl(0.05, 0.07, 0.9, 6), black, Vector3(0, 0.05, 0.85), false); neck.rotation.x = PI / 2; b.add_child(neck)
		b.add_child(P.mi(P.sphere(0.08, 8, 6), white, Vector3(0, 0.06, 1.3), false))
		b.add_child(P.mi(P.sphere(0.04, 6, 4), red, Vector3(0, 0.12, 1.32), false))
		var legs := P.mi(P.cyl(0.02, 0.02, 0.8, 4), black, Vector3(0, -0.02, -0.85), false); legs.rotation.x = PI / 2; b.add_child(legs)
		var wings: Array = []
		for s in [-1, 1]:
			var w := Node3D.new(); w.position = Vector3(s * 0.2, 0.05, 0); b.add_child(w)
			w.add_child(P.mi(P.box(1.0, 0.04, 0.55), grey, Vector3(s * 0.5, 0, 0), false))
			w.add_child(P.mi(P.box(0.5, 0.045, 0.45), black, Vector3(s * 1.2, 0, -0.05), false))
			wings.append(w)
		crane_birds.append({"obj": b, "wings": wings, "ph": k * 0.45})

static func _clear_mat(col: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(col); m.roughness = 1.0; m.disable_fog = true
	return m

func _build_farm() -> void:
	# the paddock: posts and two rails round it, a hay rack and a trough
	var post := P.wood("6b5440"); var rail := P.wood("8a6c50")
	var r := PADDOCK
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]; var b: Vector2 = corners[(i + 1) % 4]
		var n := int(ceil(a.distance_to(b) / 1.9))
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			add_child(P.mi(P.box(0.12, 1.1, 0.12), post, _ground(q) + Vector3(0, 0.55, 0)))
		var mid := (a + b) / 2.0
		for y in [0.45, 0.9]:
			var rl := P.mi(P.box(a.distance_to(b), 0.07, 0.05), rail, _ground(mid) + Vector3(0, y, 0))
			rl.rotation.y = -atan2(b.y - a.y, b.x - a.x); add_child(rl)
	var rack := Vector2(r.end.x - 0.7, r.position.y + 1.6)
	add_child(P.mi(P.box(0.5, 0.9, 1.4), P.wood("5e4636"), _ground(rack) + Vector3(0, 0.45, 0)))
	add_child(P.mi(P.box(0.45, 0.4, 1.3), P.fabric("d9c27a"), _ground(rack) + Vector3(0, 1.0, 0)))
	var trough := Vector2(r.position.x + 0.8, r.end.y - 1.5)
	add_child(P.mi(P.box(0.6, 0.45, 1.4), P.stone("8d8a84"), _ground(trough) + Vector3(0, 0.22, 0)))
	add_child(P.mi(P.box(0.48, 0.02, 1.26), P.mat("8fa6a3"), _ground(trough) + Vector3(0, 0.44, 0), false))
	# the herd: three white Piedmontese cows, the ox with his long horns, and the donkey
	var spots := [[Vector2(47.0, -1.6), 0.4, "cow"], [Vector2(49.4, 0.8), 2.6, "cow"], [Vector2(47.4, 3.6), -1.2, "cow"], [Vector2(49.6, 4.4), 3.6, "ox"], [Vector2(46.3, -2.2), 1.4, "donkey"]]   # the donkey by the fence, to have his ears scratched
	for s in spots:
		var a := _beast(s[2])
		a.obj.position = _ground(s[0]); a.obj.rotation.y = s[1]
		a["ph"] = herd.size() * 1.9; a["kind"] = s[2]
		add_child(a.obj); herd.append(a)
	var donkey: Dictionary = herd[4]
	_pettable("rice_village_donkey", donkey, "Scratch the donkey's ears", "The donkey leans into it and closes his eyes. He's the nativity's donkey, and he knows it.")
	# the hens
	for k in 5:
		var h := _hen(["b06a3a", "f1ece0", "8a5a32", "f1ece0", "c88a4a"][k])
		h["ph"] = k * 1.3; h["r"] = 0.6 + k * 0.35
		add_child(h.obj); hens.append(h)
	# the cats: one on the farmstead wall, one by the farmhouse door
	var c1 := _cat("8a8f96"); c1.obj.position = _ground(Vector2(36.0, 6.2)) + Vector3(0, 2.36, 0); c1.obj.rotation.y = PI; add_child(c1.obj); cats.append(c1)   # on the wall's brick cap
	var c2 := _cat("d08a4a"); c2.obj.position = _ground(Vector2(27.6, -14.55)); c2.obj.rotation.y = 0.3; add_child(c2.obj); cats.append(c2)
	_pettable("rice_village_cat1", c1, "Stroke the cat", "The grey cat purrs on the warm bricks and pretends not to care.")
	_pettable("rice_village_cat2", c2, "Stroke the cat", "The ginger cat rolls over by the door. Nonna says he's called Garibaldi.")

func _pettable(id: String, a: Dictionary, label: String, line: String) -> void:
	if game == null or not game.has_method("add_interactable"): return
	var obj: Node3D = a.obj
	game.add_interactable({"id": id, "x": func(): return obj.global_position.x, "z": func(): return obj.global_position.z, "radius": 2.6 if id.ends_with("donkey") else 1.6, "object": obj,
		"available": func(): return absf(game.player.pos.y - obj.global_position.y) < 1.6,
		"label": func(): return label, "act": func(): pet(a, line)})

func pet(a: Dictionary, line: String) -> void:
	game.effects.hearts(a.obj.global_position + Vector3(0, 0.5, 0), 3)
	game.sfx("squeak")
	a["purr"] = 1.5
	var key := "pet_%s_%d" % [a.obj.name, int(game.state.time.day)]
	if not game.state.flags.get(key, false):
		game.state.flags[key] = true
		game.toast(line, "good", 3.0)
	game.story.event("animal")

## A four-legged farm animal: body, head (it grazes and chews), legs, ears, a swishing tail; horns for cattle.
func _beast(kind: String) -> Dictionary:
	var o := Node3D.new(); o.name = "rice_village_" + kind
	var col: String = {"cow": "efe9dc", "ox": "e2d6bf", "donkey": "8c8379"}[kind]
	var hide := P.fabric(col); var dark := P.mat("3a3330"); var horn := P.mat("e8dcc0")
	var big := 1.12 if kind == "ox" else (0.78 if kind == "donkey" else 1.0)
	o.scale = Vector3.ONE * big
	o.add_child(P.mi(P.rbox(0.62, 0.62, 1.35, 0.2), hide, Vector3(0, 0.95, 0)))
	for x in [-0.2, 0.2]:
		for z in [-0.48, 0.48]:
			o.add_child(P.mi(P.cyl(0.07, 0.06, 0.66, 6), hide, Vector3(x, 0.33, z)))
			o.add_child(P.mi(P.cyl(0.065, 0.065, 0.08, 6), dark, Vector3(x, 0.04, z)))
	var head := Node3D.new(); head.position = Vector3(0, 1.08, 0.66); o.add_child(head)
	var skull := P.mi(P.rbox(0.32, 0.36, 0.5, 0.12), hide, Vector3(0, -0.05, 0.2)); skull.rotation.x = 0.5; head.add_child(skull)
	head.add_child(P.mi(P.rbox(0.28, 0.2, 0.16, 0.07), P.mat("d8c8b8" if kind != "donkey" else "d9d2c8"), Vector3(0, -0.22, 0.42)))
	for s in [-1, 1]:
		head.add_child(P.mi(P.sphere(0.03, 6, 4), dark, Vector3(s * 0.13, 0.04, 0.32)))
		if kind == "donkey":
			var ear := P.mi(P.cyl(0.03, 0.06, 0.34, 6), hide, Vector3(s * 0.1, 0.28, 0.06)); ear.rotation.z = -s * 0.25; head.add_child(ear)
		else:
			var ear := P.mi(P.box(0.16, 0.04, 0.08), hide, Vector3(s * 0.22, 0.08, 0.08)); head.add_child(ear)
			var hl := 0.34 if kind == "ox" else 0.16
			var hn := P.mi(P.cyl(0.015, 0.035, hl, 6), horn, Vector3(s * (0.16 + hl * 0.4), 0.16, 0.06)); hn.rotation.z = -s * 1.0; head.add_child(hn)
	if kind == "donkey":
		var mane := P.mi(P.box(0.06, 0.12, 0.5), dark, Vector3(0, 1.32, 0.42)); mane.rotation.x = 0.5; o.add_child(mane)
	var tail := Node3D.new(); tail.position = Vector3(0, 1.15, -0.68); o.add_child(tail)
	tail.add_child(P.mi(P.cyl(0.02, 0.02, 0.6, 4), hide, Vector3(0, -0.3, 0)))
	tail.add_child(P.mi(P.sphere(0.05, 6, 4), dark, Vector3(0, -0.6, 0)))
	return {"obj": o, "head": head, "tail": tail}

func _hen(col: String) -> Dictionary:
	var o := Node3D.new()
	var m := P.mat(col)
	o.add_child(P.mi(P.sphere(0.16, 10, 8), m, Vector3(0, 0.22, 0), false))
	var tail := P.mi(P.cone(0.09, 0.16, 6), m, Vector3(0, 0.3, -0.14), false); tail.rotation.x = -0.8; o.add_child(tail)
	var head := Node3D.new(); head.position = Vector3(0, 0.36, 0.11); o.add_child(head)
	head.add_child(P.mi(P.sphere(0.075, 8, 6), m, Vector3.ZERO, false))
	head.add_child(P.mi(P.sphere(0.035, 6, 4), P.mat("d8362e"), Vector3(0, 0.07, 0.01), false))
	var bk := P.mi(P.cone(0.022, 0.06, 5), P.mat("e8b03a"), Vector3(0, -0.01, 0.08), false); bk.rotation.x = PI / 2; head.add_child(bk)
	for s in [-1, 1]: o.add_child(P.mi(P.cyl(0.012, 0.012, 0.1, 4), P.mat("e8b03a"), Vector3(s * 0.05, 0.05, 0), false))
	return {"obj": o, "head": head}

## A sitting cat with a tail that curls and flicks.
func _cat(col: String) -> Dictionary:
	var o := Node3D.new(); o.name = "rice_village_cat_" + col
	var fur := P.fabric(col); var pale := P.mat("f2ece2")
	var body := P.mi(P.sphere(0.13, 10, 8), fur, Vector3(0, 0.12, -0.02)); body.scale = Vector3(0.9, 1.0, 1.25); o.add_child(body)
	o.add_child(P.mi(P.sphere(0.07, 8, 6), pale, Vector3(0, 0.12, 0.1)))
	var head := Node3D.new(); head.position = Vector3(0, 0.27, 0.06); o.add_child(head)
	head.add_child(P.mi(P.sphere(0.09, 10, 8), fur))
	for s in [-1, 1]:
		head.add_child(P.mi(P.cone(0.035, 0.07, 4), fur, Vector3(s * 0.05, 0.09, 0)))
		head.add_child(P.mi(P.sphere(0.014, 6, 4), P.mat("3a5a2a"), Vector3(s * 0.035, 0.015, 0.08)))
	var tail := Node3D.new(); tail.position = Vector3(0, 0.05, -0.16); o.add_child(tail)
	var tm := P.mi(P.cyl(0.022, 0.018, 0.3, 5), fur, Vector3(0.08, 0.0, -0.1)); tm.rotation = Vector3(PI / 2, 0, 0.9); tail.add_child(tm)
	return {"obj": o, "head": head, "tail": tail}

## Sends a crane crossing over now (screenshots and playthroughs).
func send_cranes() -> void: forced_cranes = CRANE_MINUTES

# ---- Every frame --------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if game == null or game.get("state") == null or game.get("traveling"): return
	t += dt
	var p3: Vector3 = game.player.pos
	var pl := Vector2(p3.x, p3.z)
	var spots := wade_spots(game.state.flags)
	for b in waders: _wade(b, dt, pl, spots)
	for f in flocks: _flock(f, dt, pl)
	_crane_frame(dt)
	_farm(dt)

func _wade(b: Dictionary, dt: float, pl: Vector2, spots: Array) -> void:
	var o: Node3D = b.obj
	b.calm = maxf(0.0, b.calm - dt)
	if b.state == "stand":
		# stock-still, now and then stretching the neck up or dipping to look into the water
		var cyc := fmod(t * 0.25 + b.ph, 6.0)
		(b.neck as Node3D).rotation.x = (-0.5 if cyc > 5.2 else 0.0) + (0.25 if cyc > 2.0 and cyc < 2.7 else 0.0)
		for w in b.wings: (w as Node3D).scale = Vector3(0.32, 1, 0.7)
		if b.calm <= 0.0 and startled(b.at, pl, SHY[b.kind]):
			var taken: Array = []
			for x in waders:
				if x != b: taken.append(x.at if x.state == "stand" else x.get("to", x.at))
			var to := next_spot(spots, taken, pl, b.at)
			if to == b.at: return
			b["from"] = Vector3(o.position); b["to"] = to; b["fly"] = 0.0; b.state = "fly"
			b["dur"] = maxf(4.0, b.at.distance_to(to) / 5.0)
			o.rotation.y = atan2(to.x - b.at.x, to.y - b.at.y)
			_call(b.kind, o.position)
	elif b.state == "fly":
		b.fly += dt
		var k := clampf(b.fly / b.dur, 0.0, 1.0)
		var end := _ground(b.to)
		var pos: Vector3 = (b.from as Vector3).lerp(end, k)
		pos.y += sin(k * PI) * minf(9.0, 3.0 + b.dur)
		o.position = pos
		var flap := sin(b.fly * (5.0 if b.kind == "heron" else 6.5)) * (0.8 if k > 0.08 and k < 0.92 else 1.1)
		for i in 2:
			var w: Node3D = b.wings[i]
			w.scale = Vector3.ONE; w.rotation.z = (1 if i == 0 else -1) * flap * 0.6
		(b.neck as Node3D).rotation.x = 0.9 if b.kind == "heron" else 0.6   # herons fly with the neck tucked in
		(b.legs as Node3D).rotation.x = -1.2 * sin(minf(1.0, k * 8.0) * PI / 2) * (1.0 - smoothstep(0.85, 1.0, k))
		if k >= 1.0:
			b.at = b.to; b.state = "stand"; b.calm = 4.0
			(b.legs as Node3D).rotation.x = 0.0
			for w in b.wings: (w as Node3D).rotation.z = 0.0

func _flock(f: Dictionary, dt: float, pl: Vector2) -> void:
	f.calm = maxf(0.0, f.calm - dt)
	if f.state == "ground":
		for b in f.birds:
			var s: Vector2 = f.at + b.off
			var hop := maxf(0.0, sin(t * 2.3 + b.ph * 3.0)) * 0.03
			b.obj.position = _ground(s) + Vector3(0, hop, 0)
			b.obj.rotation.y = b.ph * 2.0 + sin(t * 0.4 + b.ph) * 0.8
			for w in b.wings: (w as Node3D).visible = false
		if f.calm <= 0.0 and startled(f.at, pl, LAPWING_SHY):
			var other: Array = []
			for x in flocks:
				if x != f: other.append(x.at)
			f["to"] = next_spot(FIELDS, other, pl, f.at); f.t = 0.0; f.state = "wheel"
			_call("lapwing", _ground(f.at))
	else:
		f.t += dt
		var dur := 11.0
		var k := clampf(f.t / dur, 0.0, 1.0)
		var c: Vector2 = (f.at as Vector2).lerp(f.to, smoothstep(0.2, 0.9, k))
		var h := sin(minf(1.0, k * 1.15) * PI) * 7.0 + 0.2
		for b in f.birds:
			var a: float = t * 1.6 + b.ph
			var rad: float = 3.0 + (b.off as Vector2).length()
			var p := c + Vector2(cos(a), sin(a)) * rad * sin(k * PI)
			var y := Heightfield.height(p.x, p.y) + h + sin(t * 3.0 + b.ph) * 0.4
			b.obj.position = Vector3(p.x, y, p.y)
			b.obj.rotation.y = -a
			for i in 2:
				var w: Node3D = b.wings[i]
				w.visible = true; w.rotation.z = (1 if i == 0 else -1) * sin(t * 14.0 + b.ph) * 0.9
		if fmod(f.t, 2.5) < dt: _call("lapwing", Vector3(c.x, h, c.y))
		if k >= 1.0: f.at = f.to; f.state = "ground"; f.calm = 5.0

func _crane_frame(dt: float) -> void:
	var k := crane_pass(int(game.state.time.day), float(game.state.time.minute))
	if forced_cranes > 0.0:
		forced_cranes = maxf(0.0, forced_cranes - dt)
		k = 1.0 - forced_cranes / CRANE_MINUTES
	var flying := k >= 0.0 and k < 1.0
	cranes.visible = flying
	if not flying:
		cranes.set_meta("called", false)
		return
	var a := Vector3(110.0, CRANE_HEIGHT, -100.0); var b := Vector3(-110.0, CRANE_HEIGHT + 4.0, 100.0)
	cranes.position = a.lerp(b, k)
	cranes.look_at(b, Vector3.UP); cranes.rotate_object_local(Vector3.UP, PI)
	for c in crane_birds:
		for i in 2:
			(c.wings[i] as Node3D).rotation.z = (1 if i == 0 else -1) * sin(t * 2.6 + c.ph) * 0.45
	if k > 0.3 and not cranes.get_meta("called", false):
		cranes.set_meta("called", true)
		_call("crane", game.player.pos + Vector3(0, 30, 0))

func _farm(dt: float) -> void:
	for a in herd:
		# graze (head down), lift the head and chew, swish the tail
		var cyc := fmod(t * 0.12 + a.ph, 1.0)
		var down := smoothstep(0.1, 0.2, cyc) * (1.0 - smoothstep(0.55, 0.65, cyc))
		(a.head as Node3D).rotation.x = down * 0.85 + sin(t * 3.0 + a.ph) * 0.03 * (1.0 - down)
		(a.tail as Node3D).rotation.z = sin(t * 1.7 + a.ph) * 0.35
		if a.get("purr", 0.0) > 0.0:
			a.purr -= dt; (a.head as Node3D).rotation.x = -0.15
	for h in hens:
		var a: float = t * 0.25 + h.ph
		var p := HENS + Vector2(cos(a) * h.r, sin(a * 1.3) * h.r * 0.7)
		var nxt := HENS + Vector2(cos(a + 0.05) * h.r, sin((a + 0.05) * 1.3) * h.r * 0.7)
		h.obj.position = _ground(p)
		h.obj.rotation.y = atan2(nxt.x - p.x, nxt.y - p.y)
		(h.head as Node3D).rotation.x = 0.9 if fmod(t * 1.1 + h.ph, 2.2) < 0.25 else 0.0
	for c in cats:
		(c.tail as Node3D).rotation.y = sin(t * 0.9 + c.obj.position.x) * 0.5
		var purr: float = c.get("purr", 0.0)
		if purr > 0.0: c.purr = purr - dt
		(c.head as Node3D).rotation.z = sin(t * 4.0) * 0.12 if purr > 0.0 else 0.0

## A bird's call, quieter the further away it is.
func _call(kind: String, at: Vector3) -> void:
	if game == null: return
	Sounds.bird(game, kind, maxf(0.15, Sounds.by_distance(at.distance_to(game.player.pos), 8.0, 70.0)))
