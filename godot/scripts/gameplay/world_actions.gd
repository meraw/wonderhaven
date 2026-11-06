class_name WorldActions
extends RefCounted
## Everything you can do with the world itself: chop, mine, dig clay, fish, pick, shake, forage, dig where the metal detector
## beeps, open chests, pick up lost things, dig through the street bins, garden, and see off the bakery's boars.
## A layout node may say what it gives ("gives", see gives()), what it's called when you find it ("name": a lost thing,
## or what the metal detector turns up) and what its prompt says ("label"): loose rice straw is a "flowers" node that
## gives straw, labelled "Gather loose straw".
const P := preload("res://scripts/world/palette.gd")
const REGROW := {"chop": 180.0, "mine": 240.0, "clay": 150.0, "flowers": 180.0, "shake": 90.0, "fruit": 240.0, "fragment": 1440.0, "bin": 300.0, "forage": 300.0}
const SQUIRREL_SPOTS := [[-8.4, -3.2], [-13.7, -3.3], [-7.2, -6.6]]
const LABELS := {"chop": "Chop tree", "mine": "Mine rock", "clay": "Dig clay", "fish": "Fish here", "flowers": "Pick flowers", "shake": "Shake the chestnut tree", "fruit": "Pick hazelnuts", "chest": "Open chest", "fragment": "Pick up the lost thing", "bin": "Dig through the bin", "forage": "Pick the porcini"}
## What the lost things turn out to be; the first one is always the Sindaco's reading glasses. A layout's `lost` list
## replaces it there. A gathering node may also carry its own `label`, `hours` when it's out (a page blown about at
## night), `gives` (see gives: a bin's or a dig spot's finds too), `lines` (a bin) and `text` (a dig spot).
const LOST := ["the Sindaco's reading glasses", "a bunch of keys", "a dog's ball", "a single glove", "a lottery ticket (not a winner)", "a cassette of love songs", "a phone card with 200 lire left on it"]
## Copper wire from the bins, and what else comes up with it.
const BIN_LINES := ["You go in head first. Copper wire! And half a pizza.", "A tangle of copper wire, a broken radio, and a very surprised cat.",
	"Copper wire, wrapped round a videotape of a 1994 wedding. Lovely ceremony.", "Copper wire, and a strong smell of yesterday's minestrone.", "Copper wire! Elio would be proud. Your mother would not."]

var game
var hum := 0
var check_t := 0.0
var plots: Array = []
var squirrels: Array = []
var bobber: MeshInstance3D
var line: MeshInstance3D
var fishing := {}
var pending_node := {}

func _init(g) -> void:
	game = g
	for n in Data.layout.nodes: _register_node(n)
	for f in Data.layout.features: _register_feature(f)
	if not Gardening.beds().is_empty(): _build_gardens()   # Gigia's pumpkin beds, or the place's own (layout "gardens")
	if Data.island == "hearthglow": _build_squirrels()   # the bakery squirrels
	game.game_event.connect(func(type: String, data: Dictionary): if type == "flag" and data.get("flag", "") == "hasTool": refresh_all())
	bobber = P.mi(P.sphere(0.09, 10, 8), P.mat("ff5a5f")); bobber.visible = false; game.add_child(bobber)
	line = MeshInstance3D.new(); line.material_override = P.glow_mat(Color.WHITE); line.visible = false; game.add_child(line)

func state() -> Dictionary: return game.state
func now() -> float: return state().time.total
func node_state(id: String) -> Dictionary: return state().nodes.get(id, {})

func ready(n: Dictionary) -> bool:
	var s := node_state(n.id)
	if s.get("done", false): return false
	if n.has("flag") and not state().flags.get(n.flag, false): return false
	if n.has("hours") and not Clock.in_hours(n.hours, float(state().time.minute)): return false
	if n.kind == "fruit" and not state().flags.get("orchardOpen", false): return false
	# Lost things only turn up once the Sindaco has welcomed you, so new players don't pick up his glasses by accident.
	if n.kind == "fragment" and not state().flags.get("hasTool", false): return false
	return not (s.get("ready_at", -1.0) > now())

## Chests, metal-detector spots and nodes marked "once" (a particular lost thing) are gone for good once taken;
## the rest grow back.
static func regrows(n: Dictionary) -> bool: return not (n.kind in ["chest", "dig"] or n.get("once", false))

func deplete(n: Dictionary) -> void:
	if not regrows(n): state().nodes[n.id] = {"done": true}
	else: state().nodes[n.id] = {"ready_at": now() + REGROW.get(n.kind, 300.0)}
	refresh_node(n)

func _register_node(n: Dictionary) -> void:
	var nd := n
	var base := {"id": n.id, "x": n.x, "z": n.z, "object": game.village.node_visuals.get(n.id), "available": func(): return ready(nd)}
	if n.kind == "dig":
		base.merge({"radius": 0.9, "object": null, "available": func(): return ready(nd) and state().flags.get("hasTool", false),
			"label": func(): return "Dig here, the metal detector is going wild!", "act": func(): dig(nd)}, true)
		game.add_interactable(base); return
	base.merge({"radius": 2.0 if n.kind == "mine" else (1.3 if n.kind == "fish" else 1.7), "label": func(): return String(nd.get("label", LABELS[nd.kind])), "act": func(): act(nd)}, true)
	game.add_interactable(base)

func _register_feature(f: Dictionary) -> void:
	match f.kind:
		"rest": game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "radius": 1.3, "label": func(): return "Sleep", "act": func(): game.rest("bed")})
		"bench":
			var r := int(f.get("r", 0))
			var fp := BuildGrid.footprint(Data.piece("bench"), r)
			var seat := {"id": "bench", "i": f.x - fp.x / 2.0, "k": f.z - fp.y / 2.0, "r": r, "y": Heightfield.height(f.x, f.z)}
			game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "radius": 1.5, "object": game.village.objects.get(f.id), "label": func(): return "Sit or nap on the bench", "act": func(): game.rest("bench", seat)})
		# a wardrobe with a flag is yours once that's set (in a flat you rent, say)
		"wardrobe": game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "object": game.village.objects[f.id], "available": func(): return not f.has("flag") or state().flags.get(f.flag, false),
			"label": func(): return "Change outfit", "act": func(): game.open_wardrobe()})
		"board": game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "object": game.village.objects[f.id], "label": func(): return "Read the notice board", "act": func(): game.panels.notice_board()})
		# a stop on a line within this place (a tram, a funicular): ride to another stop on it (Travel.stops_on)
		"stop": game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "radius": 2.2, "object": game.village.objects.get(f.id), "label": func(): return String(f.get("ride_label", "Take a ride")), "act": func(): game.panels.stops(f)})
		# the departure point (any id; "depart_label" names how you leave, a train from a city station, say; "flag",
		# if any, is the story flag it waits for: a station where the trains only stop again after a request)
		"boat":   # a bus can be boarded anywhere along its side, not just by its middle
			var reach: float = float(f.get("length", 8.6)) / 2.0 + 0.6 if f.get("model", "boat") == "bus" else 2.6
			var fl := String(f.get("flag", ""))
			game.add_interactable({"id": f.id, "x": f.x, "z": f.z, "radius": reach, "object": game.village.objects.get(f.id), "available": func(): return state().flags.get("boatReady", false) and (fl == "" or state().flags.get(fl, false)), "label": func(): return String(f.get("depart_label", "Catch the bus")), "act": func(): game.panels.map(true)})

func _src(n: Dictionary, up: float = 1.0) -> Vector3: return Vector3(n.x, Heightfield.height(n.x, n.z) + up, n.z)

func act(n: Dictionary) -> void:
	game.player.yaw = atan2(n.x - game.player.pos.x, n.z - game.player.pos.z); game.player.sync()
	match n.kind:
		"chop": pending_node = n; game.start_minigame("chop", Minigames.Chop.new(), _src(n, 0.0))
		"mine": pending_node = n; game.start_minigame("mine", Minigames.Mine.new(n.get("rich", false), null, String(Data.layout.get("richRock", "metal"))), _src(n, 0.0))
		"fish": start_fishing(n)
		"clay":
			game.player_char.play("dig"); game.sfx("dig")
			game.give(gives(n, {"clay": 2}), _src(n)); deplete(n)
		"flowers": game.player_char.play("dig"); game.sfx("pick"); game.give(gives(n, {"flowers": 2}), _src(n)); deplete(n)
		"shake":
			game.sfx("rustle"); game.cam.shake = 0.3
			game.village.node_visuals[n.id].set_meta("shake", 0.6)
			game.give(gives(n, {"acorn": 3}), _src(n, 2.0)); deplete(n)
		"fruit": game.sfx("pick"); game.give(gives(n, {"fruit": 2}), _src(n, 2.0)); deplete(n)
		"chest": open_chest(n)
		"fragment": catch_fragment(n)
		"bin": dig_bin(n)
		"forage": game.player_char.play("dig"); game.sfx("pick"); game.give({String(n.get("item", "mushroom")): 1}, _src(n, 0.4)); deplete(n)

## A swing or strike in the minigame: the tree or rock shakes and chips fly (a miss barely moves it).
func minigame_hit(kind: String, result: String) -> void:
	var n := pending_node
	if n.is_empty(): return
	var o: Node3D = game.village.node_visuals.get(n.id)
	if o == null: return
	var hit := result != "miss"
	var z0: float = o.get_meta("rest_rz", o.rotation.z)
	o.set_meta("rest_rz", z0)
	var tw := o.create_tween()
	tw.tween_property(o, "rotation:z", z0 + (0.1 if hit else 0.03), 0.06)
	tw.tween_property(o, "rotation:z", z0 - (0.07 if hit else 0.02), 0.09)
	tw.tween_property(o, "rotation:z", z0, 0.14)
	if hit: game.effects.sparkle(_src(n, 0.8), 18 if result == "perfect" else 9, Color("c98a55") if kind == "chop" else Color("d8d0c2"), 0.25)

## Called by the game when a chop or mine minigame ends (mg is null if cancelled).
func minigame_done(kind: String, mg) -> void:
	var n := pending_node; pending_node = {}
	if kind == "fish": _fishing_done(mg); return
	if mg == null or n.is_empty(): return
	game.give(mg.reward(), _src(n))
	if kind == "chop": state().stats.chopped += 1; game.effects.poof(_src(n), Color("9fdc7a"))
	else: state().stats.mined += 1
	game.story.event(kind)   # "chop" or "mine", for requests that count trees pruned or rocks cut
	deplete(n); game.sfx("collect")

## What a node gives: its own "gives" ({item: count}) when the layout says, else the default for its kind. A
## location can dig sand where others dig clay, pick mushrooms where others pick flowers, or say what the metal
## detector turns up at a spot.
static func gives(n: Dictionary, fallback: Dictionary) -> Dictionary:
	if not n.has("gives"): return fallback
	var out := {}
	for k in n.gives: out[k] = int(n.gives[k])
	return out

func catch_fragment(n: Dictionary) -> void:
	var p := _src(n, 0.2)
	var found := int(state().stats.fragments)
	var here: Array = Data.layout.get("lost", [])   # what the lost things turn out to be in this place
	var what: String = here[found % here.size()] if not here.is_empty() else (LOST[0] if found == 0 else LOST[1 + found % (LOST.size() - 1)])
	if n.has("name"): what = String(n.name)   # a particular lost thing, named in the layout
	var got := gives(n, {"fragment": 1})
	game.give(got, null, true)
	game.toast("You found %s!" % what, "good", 2.5)
	game.effects.sparkle(p, 8, Color("ffe7a0"), 0.18); game.sfx("pick")
	if got.has("fragment"): state().stats.fragments += 1   # (a page of a score isn't a lost thing)
	deplete(n)

## Head first into a street bin: there is always copper wire, and usually something else.
func dig_bin(n: Dictionary) -> void:
	var count := int(state().stats.get("bins", 0))
	game.player_char.play("dig"); game.sfx("dig")
	var lines: Array = n.get("lines", BIN_LINES)
	game.give(gives(n, {"crystal": 1, "metal": 1} if count % 3 == 2 else {"crystal": 1}), _src(n, 1.0), true)
	game.toast(lines[count % lines.size()], "good", 3.0)
	state().stats["bins"] = count + 1
	deplete(n)

func open_chest(n: Dictionary) -> void:
	var p := _src(n, 0.8)
	game.sfx("chest"); game.player_char.play("surprised")
	var loot: Dictionary = {}
	for k in n.loot: loot[k] = int(n.loot[k])
	game.give(loot, p)
	if n.has("blueprint"): game.story.unlock_blueprints([n.blueprint], "treasure chest")
	if n.has("outfit"): game.story.unlock_clothes([n.outfit])
	state().stats.chests += 1; state().stats.treasures += 1
	deplete(n)
	game.effects.sparkle(p, 26)
	game.story.event("treasure"); game.story.event("chest")

func dig(n: Dictionary) -> void:
	var p := _src(n, 0.3)
	game.player_char.play("dig"); game.sfx("dig")
	var digs: Array = Data.layout.nodes.filter(func(x): return x.kind == "dig")
	var loot: Dictionary = gives(n, [{"crystal": 1, "coins": 8}, {"fabric": 2, "coins": 5}, {"metal": 2, "coins": 5}, {"crystal": 1, "fabric": 1, "coins": 8}, {"metal": 1, "crystal": 1, "coins": 10}][digs.find(n) % 5])
	game.give(loot, p); game.effects.sparkle(p, 22)
	if n.has("text"): game.toast(String(n.text), "good", 3.0)   # what the find is, in the layout
	elif n.has("name"): game.toast("You dig up %s!" % n.name, "good", 3.0)   # a particular find, named in the layout
	state().stats.dug += 1; state().stats.treasures += 1
	deplete(n); game.sfx("chest")
	game.story.event("treasure"); game.story.event("dig")

func start_fishing(n: Dictionary) -> void:
	var facing: float = n.get("facing", PI)
	game.player.teleport(n.x, n.z, facing)
	var fx: float = n.x + sin(facing) * 3.0
	var fz: float = n.z + cos(facing) * 3.0
	bobber.position = Vector3(fx, Heightfield.WATER_Y + 0.05, fz); bobber.visible = true; line.visible = true
	game.player_char.play("cast", true); game.sfx("cast")
	var mg := Minigames.Fish.new(null, Minigames.catch_table(Data.layout.get("fish", []), n.id, state().flags, float(state().time.minute)))
	fishing = {"mg": mg, "fx": fx, "fz": fz}
	game.start_minigame("fish", mg, Vector3(fx, Heightfield.WATER_Y, fz))

func _fishing_done(mg) -> void:
	bobber.visible = false; line.visible = false
	var f := fishing; fishing = {}
	game.player_char.stop_hold()
	if mg == null or mg.result != "caught": return
	var at := Vector3(f.fx, 0.3, f.fz)
	game.give(mg.reward(), at)
	game.effects.splash(Vector3(f.fx, Heightfield.WATER_Y + 0.1, f.fz))
	game.player_char.play("celebrate"); game.sfx("fanfare_small")
	state().stats.fish += 1
	game.toast(String(mg.fish.get("caught", "You caught %s!" % Minigames.a_name(mg.fish.name))), "good")
	game.story.event("fish")
	game.story.event("fish:" + String(mg.fish.id))   # a request can wait for one particular catch

## Which kinds of place give each item (for pointing the compass at the nearest one).
const SOURCES := {"wood": ["chop"], "stone": ["mine"], "metal": ["mine", "bin"], "crystal": ["bin"], "clay": ["clay"], "flowers": ["flowers"],
	"fish": ["fish"], "acorn": ["shake"], "fruit": ["fruit"], "fragment": ["fragment"], "mushroom": ["forage"]}

## The nearest place that gives `item` and is ready right now, or {}.
func nearest_ready(item: String) -> Dictionary:
	var kinds: Array = SOURCES.get(item, [])
	var p: Vector3 = game.player.pos
	var best := {}; var bd := INF
	for n in Data.layout.nodes:
		if not ready(n) or not (n.kind in kinds and not n.has("gives") or n.get("gives", {}).has(item)): continue
		var d := Vector2(n.x - p.x, n.z - p.z).length()
		if d < bd: bd = d; best = n
	return best

func refresh_node(n: Dictionary) -> void:
	var o: Node3D = game.village.node_visuals.get(n.id)
	if o == null: return
	var r := ready(n)
	match n.kind:
		"chop": o.visible = r; (o.get_meta("stump") as Node3D).visible = not r
		"mine": o.scale = Vector3.ONE * (1.0 if r else 0.45)
		"clay", "flowers", "fragment", "forage": o.visible = r
		"bin": (o.get_node("lid") as Node3D).rotation.x = 0.0 if r else -1.1
		"fruit": (o.get_node("fruit") as Node3D).visible = r
		"shake": (o.get_node("acorns") as Node3D).visible = r
		"chest": (o.get_node("lid") as Node3D).rotation.x = -1.9 if node_state(n.id).get("done", false) else 0.0
		"dig": o.visible = node_state(n.id).get("done", false)
	if r and o.get_meta("depleted", false): game.effects.sparkle(o.position + Vector3(0, 0.8, 0), 8, Color("bfffb0"))
	o.set_meta("depleted", not r)

func refresh_all() -> void:
	for n in Data.layout.nodes: refresh_node(n)
	refresh_gardens(); place_squirrels()

# ---- Gardens
func _build_gardens() -> void:
	for p in Gardening.beds():
		var g := Node3D.new(); g.position = Vector3(p.x, 0.17 if Data.island == "hearthglow" else Heightfield.height(p.x, p.z) + 0.03, p.z); game.add_child(g)
		var soil := P.mi(P.box(1.4, 0.03, 0.9), P.mat("7a4a2a"), Vector3(0, 0.01, 0)); g.add_child(soil)
		var pl := Node3D.new(); g.add_child(pl)
		var rec := {"def": p, "group": g, "soil": soil, "plant": pl, "stage": -99, "watered": false}
		plots.append(rec)
		var pid: String = p.id
		var seed: String = p.get("seed", "seeds")
		var crop_name: String = p.get("crop_name", "pumpkins")
		game.add_interactable({"id": pid, "x": p.x, "z": p.z, "radius": 1.1, "object": g,
			"label": func(): return {"plant": "Plant a seed", "need_seeds": "Garden bed (you need seeds)", "water": "Water the seedling", "growing": "Growing nicely…", "harvest": "Pick the " + crop_name}[Gardening.action(state().gardens, pid, state().inventory, seed)],
			"act": func(): garden_act(rec)})

func garden_act(rec: Dictionary) -> void:
	var p: Dictionary = rec.def
	var s := state()
	var seed: String = p.get("seed", "seeds")
	var a := Gardening.action(s.gardens, p.id, s.inventory, seed)
	var pos := Vector3(p.x, rec.group.position.y + 0.33, p.z)
	match a:
		"plant": Gardening.plant(s.gardens, p.id, now()); s.inventory[seed] -= 1; game.render_resources([seed]); game.player_char.play("dig"); game.sfx("dig"); game.story.event("plant"); game.toast("Planted! Now give it some water.")
		"water": Gardening.water(s.gardens, p.id, now()); game.player_char.play("feed"); game.effects.splash(pos); game.sfx("water"); game.story.event("water"); game.toast("Watered. It will grow while you explore.")
		"harvest": game.give(Gardening.harvest(s.gardens, p.id, p.get("crop", Gardening.CROP)), pos); game.sfx("pick"); game.story.event("harvest")
		"need_seeds": game.toast(String(p.get("need", "You need pumpkin seeds. Gigia sells them at her stall.")), "warn")
		_: game.toast("The little plant is soaking up the sun. Come back in a bit!")
	refresh_gardens()

func refresh_gardens() -> void:
	for rec in plots:
		var st := Gardening.plot(state().gardens, rec.def.id)
		if rec.stage == st.stage and rec.watered == st.get("watered", false): continue
		rec.stage = st.stage; rec.watered = st.get("watered", false)
		rec.soil.material_override = P.mat("5a3420" if rec.watered else "7a4a2a")
		for c in rec.plant.get_children(): c.queue_free()
		if st.stage < 0: continue
		for x in [-0.35, 0.0, 0.35]:
			if st.stage == 0: rec.plant.add_child(P.mi(P.sphere(0.06, 6, 4), P.mat("8b5a3c"), Vector3(x, 0.04, 0))); continue
			var look: String = rec.def.get("look", "pumpkin")
			if look != "pumpkin":   # winter greens: a cabbage's round head, or a leek's white stalk and green fan
				var sz: float = 0.06 + st.stage * 0.05
				if look == "cabbage":
					var hd := P.mi(P.sphere(sz, 10, 8), P.mat("7fa860" if st.stage < 3 else "9cc07a"), Vector3(x, sz * 0.8, 0)); hd.scale = Vector3(1.2, 0.9, 1.2); rec.plant.add_child(hd)
				else:
					var lh: float = 0.1 + st.stage * 0.09
					rec.plant.add_child(P.mi(P.cyl(0.02 + st.stage * 0.006, 0.025 + st.stage * 0.006, lh, 6), P.mat("ece6cf"), Vector3(x, lh / 2.0, 0)))
					for a2 in [-0.5, 0.5]:
						var lf := P.mi(P.box(0.03, lh * 1.1, 0.015), P.mat("4f7d45"), Vector3(x + a2 * 0.05, lh * 1.25, 0)); lf.rotation.z = a2 * 0.8; rec.plant.add_child(lf)
				continue
			var h: float = 0.15 + st.stage * 0.14
			rec.plant.add_child(P.mi(P.cyl(0.02, 0.025, h, 5), P.mat("4f9e45"), Vector3(x, h / 2.0, 0)))
			var leaf := P.mi(P.sphere(0.07, 6, 4), P.mat("6cc65a"), Vector3(x + 0.05, h * 0.5, 0)); leaf.scale = Vector3(1.4, 0.4, 0.8); rec.plant.add_child(leaf)
			if st.stage >= 2:   # a little green pumpkin, then a ripe orange one sitting on the soil
				var pk := P.mi(P.sphere(0.16 if st.stage == 3 else 0.08, 12, 8), P.mat("f08a2c" if st.stage == 3 else "9fbf5a"), Vector3(x, 0.12 if st.stage == 3 else 0.07, 0.12))
				pk.scale = Vector3(1.25, 0.85, 1.25); rec.plant.add_child(pk)

# ---- Squirrels
## The bakery's wild boars (internally still "squirrels", so saves and request flags keep working).
func _build_squirrels() -> void:
	for n in SQUIRREL_SPOTS.size():
		var s := Props.wild_boar()
		s.scale = Vector3.ONE * 0.9
		game.add_child(s)
		var sq := {"n": n, "obj": s, "home": Vector2(SQUIRREL_SPOTS[n][0], SQUIRREL_SPOTS[n][1]), "t": randf() * 10.0, "pos": Vector2(SQUIRREL_SPOTS[n][0], SQUIRREL_SPOTS[n][1]), "up": 0.0}
		squirrels.append(sq)
		game.add_interactable({"id": "squirrel%d" % n, "x": func(): return sq.pos.x, "z": func(): return sq.pos.y, "radius": 1.5, "object": s,
			"available": func(): return not squirrel_fed(sq.n),
			"label": func(): return "Offer a chestnut" if state().quests.get("squirrels", {}).get("status", "") == "active" and state().inventory.get("acorn", 0) > 0 else "Keep your distance from the boar",
			"act": func(): feed_squirrel(sq)})
	place_squirrels()

func squirrel_fed(n: int) -> bool: return state().flags.get("squirrelsGone", false) or state().flags.get("squirrelFed%d" % n, false)

func feed_squirrel(sq: Dictionary) -> void:
	var s := state()
	if s.quests.get("squirrels", {}).get("status", "") != "active" or s.inventory.get("acorn", 0) <= 0:
		game.sfx("squeak")
		game.toast("The boar eyes your chestnuts… Ornella might want to hear about this." if s.inventory.get("acorn", 0) > 0 else "The boar looks at your empty hands, deeply unimpressed.")
		return
	s.inventory.acorn -= 1; game.render_resources(["acorn"])
	s.flags["squirrelFed%d" % sq.n] = true
	game.player_char.play("feed"); game.sfx("squeak")
	game.effects.hearts(sq.obj.position + Vector3(0, 0.6, 0))
	game.toast("Crunch. The boar trots off towards the woods, very pleased with itself.", "good")
	place_squirrels()
	game.story.event("feed")

func place_squirrels() -> void:
	for sq in squirrels:
		if squirrel_fed(sq.n):
			sq.home = Vector2(-18.5 + [-1.2, 0.6, 0.2][sq.n], -1.0 + [0.8, 0.0, -1.2][sq.n]); sq.up = 0.0   # back at the edge of the woods
		else:
			sq.home = Vector2(SQUIRREL_SPOTS[sq.n][0], SQUIRREL_SPOTS[sq.n][1]); sq.up = 0.0

func update(dt: float) -> void:
	var s := state()
	check_t -= dt
	if check_t <= 0.0:
		check_t = 1.0
		for n in Data.layout.nodes:
			var o: Node3D = game.village.node_visuals.get(n.id)
			if o and o.get_meta("depleted", false) == ready(n): refresh_node(n)   # back, or gone (out of its hours)
		if Gardening.grow(s.gardens, now()): refresh_gardens()
	var p: Vector3 = game.player.pos
	if game.mode == "explore":
		for n in Data.layout.nodes:
			if n.kind == "fragment" and ready(n) and Vector2(n.x - p.x, n.z - p.z).length() < 1.1: catch_fragment(n)
	var best := INF
	if s.flags.get("hasTool", false):
		for n in Data.layout.nodes:
			if n.kind == "dig" and ready(n): best = minf(best, Vector2(n.x - p.x, n.z - p.z).length())
	hum = 3 if best < 3.0 else (2 if best < 7.0 else (1 if best < 13.0 else 0))
	if hum >= 2 and randf() < dt * (4.0 if hum == 3 else 1.5):
		for n in Data.layout.nodes:
			if n.kind == "dig" and ready(n) and Vector2(n.x - p.x, n.z - p.z).length() < 7.0: game.effects.sparkle(Vector3(n.x, Heightfield.height(n.x, n.z) + 0.1, n.z), 2, Color("fff2a8"), 0.2)
	for n in Data.layout.nodes:
		var o: Node3D = game.village.node_visuals.get(n.id)
		if o and o.get_meta("shake", 0.0) > 0.0:
			var sh: float = o.get_meta("shake") - dt; o.set_meta("shake", sh); o.rotation.z = sin(sh * 40.0) * 0.05
	for sq in squirrels:
		sq.t += dt
		var r := 0.2 if sq.up > 0.0 else 0.9
		sq.pos = sq.home + Vector2(sin(sq.t * 0.7 + sq.n) * r, cos(sq.t * 0.5 + sq.n * 2) * r)
		var hop := absf(sin(sq.t * 5.0)) * 0.15
		sq.obj.position = Vector3(sq.pos.x, (sq.up if sq.up > 0.0 else Heightfield.height(sq.pos.x, sq.pos.y)) + hop, sq.pos.y)
		sq.obj.rotation.y = atan2(cos(sq.t * 0.7 + sq.n) * 0.7, -sin(sq.t * 0.5 + sq.n * 2) * 0.5)
	if not fishing.is_empty():
		var mg = fishing.mg
		var dip := (-0.12 + sin(game.time * 30.0) * 0.04) if mg.phase == "bite" else (sin(game.time * 12.0) * 0.05 if mg.phase == "reel" else sin(game.time * 2.0) * 0.02)
		bobber.position.y = Heightfield.WATER_Y + 0.05 + dip
		var hand: Vector3 = game.player_char.arm_r.to_global(Vector3(0, -0.6, 0.3))
		var im := ImmediateMesh.new(); im.surface_begin(Mesh.PRIMITIVE_LINES); im.surface_add_vertex(hand); im.surface_add_vertex(bobber.position); im.surface_end()
		line.mesh = im
		if mg.phase == "reel" and game.player_char.hold != "reel": game.player_char.play("reel", true)
