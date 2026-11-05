extends Node3D
## Casalrana's requests out in the world (stage 3), the parts that are location code:
## - walking up to the level crossing on your first day (Welcome to Casalrana's first step);
## - the trains you watch go by at the crossing, for Matteo's Train Log (one event per kind of train, "rice_village_saw_<kind>");
## - patching the flat's leaking roof from inside the flat (The Flat above the Station), with the clay and wood you gathered;
## - pulling the bell ropes on the tower's ringing floor (The Bell Tower Stairs, and any time after), and the church
##   bells pealing for the living nativity and the finale;
## - changing your outfit at the flat's old wardrobe once the flat is yours;
## - the canal filling once the sluice is rebuilt, and the winter paddy flooding once water reaches its inlet (Water for
##   the Winter). Both beds are below walkable ground from the start, so walking and building don't change: only the
##   water shows.
## The requests themselves are data (data/locations/rice_village/quests.json); this only turns what you do here into
## their events and shows what they change.
const P := preload("res://scripts/world/palette.gd")
const TT := preload("res://scripts/locations/rice_village/timetable.gd")
const Sounds := preload("res://scripts/locations/rice_village/sounds.gd")
const PEAL_FLAGS := ["rice_village_nativityDone", "rice_village_trainStops"]   # the church bells ring out for these

const CROSSING := Vector2(2.0, -45.0)          # the middle of the level crossing
const WATCH_RANGE := 16.0                       # how close you stand to note a train down
const CANAL_X := -40.0
const WINTER := Rect2(-33.6, 7.6, 12.2, 10.8)   # the winter paddy (rice_village.gd)
const WATER_Y := -0.12                          # the filled canal and the flooded paddy: over their beds, under the banks
const ROPES := Vector2(-14.0, 7.6)              # where the bell ropes hang over the ringing floor
const RING_Y := 2.42
const FLAT := Rect2(13.2, -40.3, 11.6, 4.6)     # inside the flat upstairs
const FLAT_Y := 3.5
const ROOF_COST := {"clay": 4, "wood": 4}
const WARDROBE := Vector2(13.65, -39.55)        # the flat's old wardrobe: change your outfit there once the flat is yours

var game = null
var village: Node3D
var near_crossing := false
var noted: Dictionary = {}        # trains already noted down, "day:n"
var canal: MeshInstance3D
var paddy: MeshInstance3D
var ringing := 0.0

func setup(g, v: Node3D) -> void:
	game = g; village = v
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b9cfda"); mat.roughness = 0.06; mat.metallic = 0.35
	canal = P.mi(P.box(4.7, 0.02, 108.0), mat, Vector3(CANAL_X, WATER_Y, 0.0), false); canal.name = "canal_water"; add_child(canal)
	paddy = P.mi(P.box(WINTER.size.x - 0.2, 0.02, WINTER.size.y - 0.2), mat, Vector3(WINTER.get_center().x, WATER_Y, WINTER.get_center().y), false)
	paddy.name = "paddy_water"; add_child(paddy)
	refresh_water()
	if g == null: return
	if g.has_signal("game_event"): g.game_event.connect(_on_event)
	if g.has_method("add_interactable"):
		g.add_interactable({"id": "rice_village_roof", "x": FLAT.get_center().x, "z": FLAT.get_center().y, "radius": 7.0, "priority": -1.0,
			"available": func(): return in_flat() and step_current("rice_village_flat", "roof"),
			"label": func(): return "Patch the leaking roof (4 clay, 4 wood)", "act": func(): patch_roof()})
		# (a priority, so a bed you put beside it doesn't take the prompt while you face the wardrobe)
		g.add_interactable({"id": "rice_village_wardrobe", "x": WARDROBE.x, "z": WARDROBE.y, "y": FLAT_Y, "radius": 1.6, "priority": 0.8,
			"available": func(): return game.state.flags.get("rice_village_flatHome", false) and game.screens != null,
			"label": func(): return "Change outfit", "act": func(): game.screens.creator(true)})
		g.add_interactable({"id": "rice_village_ropes", "x": ROPES.x, "z": ROPES.y, "radius": 1.8,
			"available": func(): return game.player.pos.y > RING_Y - 0.4 and game.state.quests.has("rice_village_stairs"),
			"label": func(): return "Pull the bell ropes", "act": func(): ring()})

func _on_event(type: String, data: Dictionary) -> void:
	if type != "flag": return
	refresh_water()
	if data.get("flag", "") in PEAL_FLAGS and data.get("value", false): Sounds.peal(game)

func refresh_water() -> void:
	var flags: Dictionary = game.state.flags if game != null and game.get("state") != null else {}
	canal.visible = flags.get("rice_village_canalFull", false)
	paddy.visible = flags.get("rice_village_paddyFlooded", false)

## Is this request's step the one you're on?
func step_current(qid: String, oid: String) -> bool:
	if game.state.quests.get(qid, {}).get("status", "") != "active": return false
	var e: QuestEngine = game.story.engine
	for o in Data.quest(qid).get("objectives", []):
		if o.id == oid: return e.is_current(qid, o) and not e.objective(qid, o).done
	return false

func in_flat() -> bool:
	var p: Vector3 = game.player.pos
	return p.y > FLAT_Y - 0.5 and FLAT.has_point(Vector2(p.x, p.z))

func patch_roof() -> void:
	if not Inventory.spend(game.state.inventory, ROOF_COST):
		game.toast("You need 4 clay for the tiles and 4 wood for the battens.", "warn", 3.0)
		return
	game.render_resources(ROOF_COST.keys())
	game.player_char.play("dig"); game.sfx("place")
	game.toast("New tiles, new battens, and the bucket can go back under the sink. The roof's sound.", "good", 3.5)
	game.story.event("rice_village_roofPatched")
	game.build.rebuild_grid()

func ring() -> void:
	ringing = 7.0
	Sounds.peal(game); game.cam.shake = 0.15
	game.toast("Dong... dang... dong! The bells ring out across the plain.", "good", 3.0)
	game.story.event("rice_village_peal")

func _process(dt: float) -> void:
	if game == null or game.get("state") == null or game.get("traveling"): return
	var p: Vector3 = game.player.pos
	var d := Vector2(p.x - CROSSING.x, p.z - CROSSING.y).length()
	# your first walk up the road: reaching the crossing
	var near := d < 4.5
	if near and not near_crossing and game.state.quests.get("rice_village_welcome", {}).get("status", "") == "active": game.story.event("rice_village_atCrossing")
	near_crossing = near
	# a train going over the crossing while you're watching: one note per train, for Matteo's log
	if d < WATCH_RANGE and game.state.quests.get("rice_village_trainlog", {}).get("status", "") == "active":
		var tr := TT.at_crossing(int(game.state.time.day), float(game.state.time.minute), game.state.flags.get(TT.STOP_FLAG, false))
		if not tr.is_empty():
			var key := "%d:%d" % [tr.day, tr.n]
			if not noted.has(key):
				noted[key] = true
				game.story.event("rice_village_saw_" + String(tr.kind))
	# the bell swings while it rings
	if ringing > 0.0:
		ringing = maxf(0.0, ringing - dt)
		var tower: Node3D = village.objects.get("rice_village_tower")
		var bell: Node3D = tower.get_node_or_null("bell") if tower else null
		if bell: bell.rotation.x = sin(ringing * 3.2) * 0.5 * minf(1.0, ringing / 3.0)
