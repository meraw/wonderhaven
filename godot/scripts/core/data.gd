extends Node
## Game content loaded from data/*.json, edited directly (the browser version's src/data is frozen).

var layout: Dictionary
var pieces: Array
var piece_by_id: Dictionary = {}
var categories: Array
var starter_blueprints: Array
var palette: Array
var span_limit: int = 2
var npcs: Array
var npc_by_id: Dictionary = {}
var quests: Array
var quest_by_id: Dictionary = {}
var harmony_unlocks: Array
var islands: Array
var resources: Dictionary
var resource_order: Array
var appearance: Dictionary
var tutorial: Dictionary   # Godot-only: guided first day steps and tip cards (data/tutorial.json)
var shops: Dictionary      # Godot-only: what villagers buy and sell, gift lines (data/shops.json)
var naps: Dictionary       # waking up from a nap on a bench: odds and lines of the gags (data/naps.json, BenchNap)
var paper: Dictionary
var needs: Dictionary
var inauguration: Dictionary
var commissions: Dictionary
var tools: Dictionary
var tastes: Dictionary
var market: Dictionary
## The island you're on. `layout` is that island's layout (data/layout.json for Hearthglow, layout_<id>.json or a
## location pack's layout for the others); Heightfield follows it. Sailing reloads the scene with the new island.
var island := "hearthglow"
var pending_state: Dictionary = {}   # the game state carried across that reload
## A message to show once the reloaded scene is up ([title, subtitle] for a banner, or [text] for a toast): loading a
## save made in another place reloads the scene, and the old one can't show anything any more (Screens.continue_from).
var pending_message: Array = []
var rebuilding := false              # that reload rebuilds the island you're on for the story (Game.rebuild_world)
## The story flags the current island was built for: only its location script's WORLD_FLAGS (apply_world_flags).
var world_flags: Dictionary = {}
var autoplay_started := false         # a scripted playthrough keeps running across island reloads

func _init() -> void:
	load_all()

func load_all() -> void:
	layout = _read(layout_file(island))
	var p := _read("pieces")
	pieces = p.pieces; categories = p.categories; starter_blueprints = p.starter; palette = p.palette; span_limit = int(p.span_limit)
	for piece in pieces: piece_by_id[piece.id] = piece
	npcs = _read("npcs").npcs
	for n in npcs: npc_by_id[n.id] = n
	quests = _read("quests").quests
	for q in quests: quest_by_id[q.id] = q
	harmony_unlocks = _read("harmony").unlocks
	islands = _read("islands").islands
	var r := _read("resources")
	resources = r.resources; resource_order = r.order
	appearance = _read("appearance")
	tutorial = _read("tutorial")
	shops = _read("shops")
	naps = _read("naps")
	paper = _read("paper")
	needs = _read("needs")
	inauguration = _read("inauguration")
	commissions = _read("commissions")
	tools = _read("tools")
	tastes = _read("tastes")
	market = _read("market")
	var lists := {"islands": islands, "npcs": npcs, "quests": quests, "shops": shops.get("shops", {}), "resources": resources, "order": resource_order, "appearance": appearance}
	for id in location_ids():
		var dir := "%s/%s/" % [LOCATIONS, id]
		merge_pack(lists, id, {"location": _read_opt(dir + "location"), "npcs": _read_opt(dir + "npcs"), "quests": _read_opt(dir + "quests"),
			"shops": _read_opt(dir + "shops"), "resources": _read_opt(dir + "resources"), "appearance": _read_opt(dir + "appearance")})
	for n in npcs: npc_by_id[n.id] = n
	for q in quests: quest_by_id[q.id] = q
	_add_interior_nav()

# ---- Location packs ---------------------------------------------------------------------------------------------
## A location can live in its own folder, so several people can build locations at once without touching shared
## files: data/locations/<id>/ holds layout.json and, if it needs them, location.json (its map entry and look),
## npcs.json, quests.json, shops.json and resources.json, in the same shapes as the shared files. They are merged
## into the shared lists when the game loads. Its code (ground shape, its own buildings, extra scenery) lives in
## scripts/locations/<id>.gd. See docs/WORLD.md.
const LOCATIONS := "locations"

## Ids of the location packs, sorted (folders in data/locations that have a layout.json).
static func location_ids() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute("res://data/" + LOCATIONS): return out
	for d in DirAccess.get_directories_at("res://data/" + LOCATIONS):
		if FileAccess.file_exists("res://data/%s/%s/layout.json" % [LOCATIONS, d]): out.append(d)
	out.sort()
	return out

## Merges one pack into the shared lists (in place). Villagers default to living in the pack's location, its map
## entry gets the pack's id, shops and resources are added by key, and nothing already defined is replaced.
static func merge_pack(lists: Dictionary, id: String, pack: Dictionary) -> void:
	var loc: Dictionary = pack.get("location", {})
	if not loc.is_empty() and not lists.islands.any(func(i): return i.id == id):
		var entry := loc.duplicate(true); entry["id"] = id
		lists.islands.append(entry)
	for n in pack.get("npcs", {}).get("npcs", []):
		var npc: Dictionary = n.duplicate(true)
		if not npc.has("island"): npc["island"] = id
		if not lists.npcs.any(func(x): return x.id == npc.id): lists.npcs.append(npc)
	for q in pack.get("quests", {}).get("quests", []):
		if not lists.quests.any(func(x): return x.id == q.id): lists.quests.append(q)
	var sh: Dictionary = pack.get("shops", {}).get("shops", {})
	for k in sh:
		if not lists.shops.has(k): lists.shops[k] = sh[k]
	var res: Dictionary = pack.get("resources", {})
	for k in res.get("resources", {}):
		if not lists.resources.has(k): lists.resources[k] = res.resources[k]
	for k in res.get("order", res.get("resources", {}).keys()):
		if not lists.order.has(k): lists.order.append(k)
	if lists.has("appearance"): merge_variants(lists.appearance, pack.get("appearance", {}).get("variants", {}))

## Which appearance list each kind of clothing variant joins.
const VARIANT_SLOTS := {"hat": "HATS", "accessory": "ACCESSORIES", "shoes": "SHOES", "top": "TOPS", "bottom": "BOTTOMS"}

## A location's own clothes (appearance.json in its pack): {"variants": {id: {"slot", "base", "color", "trim"?, "label",
## "unlock"?}}}, each a shape that already exists (base) in its own colours. It joins that slot's list, so the
## wardrobe shows it, with its label, and stays locked (unlock is the hint) until a reward, a shop or a friend's gift
## gives it. Chibi.resolve draws it. A variant of a shape that doesn't exist is left out.
static func merge_variants(A: Dictionary, vs: Dictionary) -> void:
	if vs.is_empty(): return
	if not A.has("variants"): A["variants"] = {}
	for k in vs:
		var v: Dictionary = vs[k]
		var list: String = VARIANT_SLOTS.get(String(v.get("slot", "")), "")
		if A.variants.has(k) or list == "" or not A.get(list, []).has(v.get("base", "")): continue
		A.variants[k] = v
		A[list].append(k)
		A.labels[k] = String(v.get("label", k))
		if v.has("unlock"): A.locked[k] = String(v.unlock)

## The location's own script (scripts/locations/<id>.gd), or null when it has none.
static func location_script(id: String) -> Script:
	var path := "res://scripts/locations/%s.gd" % id
	return load(path) if ResourceLoader.exists(path) else null

## Rooms you can walk into add nav spots (inside the door, and where the owner works and sleeps) to the village graph.
func _add_interior_nav() -> void:
	for b in layout.buildings:
		if not b.has("interior"): continue
		var n: Dictionary = Interiors.nav(b)
		for k in n.nodes: layout.nav_nodes[k] = n.nodes[k]
		for e in n.edges: layout.nav_edges.append(e)

static func layout_file(id: String) -> String:
	if id == "hearthglow": return "layout"
	if FileAccess.file_exists("res://data/%s/%s/layout.json" % [LOCATIONS, id]): return "%s/%s/layout" % [LOCATIONS, id]
	return "layout_" + id
func has_island(id: String) -> bool: return FileAccess.file_exists("res://data/%s.json" % layout_file(id))
func island_def(id: String) -> Dictionary:
	for i in islands:
		if i.id == id: return i
	return {}

## Switch to another island's layout and ground (the world is rebuilt from it when the scene loads).
func use_island(id: String) -> void:
	island = id
	Heightfield.use(id)
	layout = _read(layout_file(id))
	world_flags = {}
	_add_interior_nav()

## A place can change with the story (a piazza drained, a boat launched). Its location script lists WORLD_FLAGS, the
## story flags that reshape it, and may define adjust(layout, flags) to edit its layout for the ones set; its
## scenery can read world_flags. The world is built for them, and rebuilt where you stand when one changes.
static func world_flags_of(id: String, flags: Dictionary) -> Dictionary:
	var out := {}
	var pack := location_script(id)
	if pack == null: return out
	for f in pack.get_script_constant_map().get("WORLD_FLAGS", []):
		if flags.get(f, false): out[f] = true
	return out

## Lay out the island you're on for these story flags (it only changes when they change its WORLD_FLAGS).
func apply_world_flags(flags: Dictionary) -> void:
	var wf := world_flags_of(island, flags)
	if wf == world_flags: return
	world_flags = wf
	layout = _read(layout_file(island))
	var pack = location_script(island)
	if pack != null and pack.get_script_method_list().any(func(m): return m.name == "adjust"): pack.adjust(layout, wf)
	_add_interior_nav()

## How wide the island's ground is, in metres (a square centred on 0, 0). Villages use the default; a layout can
## set "size" (a city is bigger). The terrain, its height texture and the sea follow it.
const DEFAULT_MAP_SIZE := 124.0
func map_size() -> float: return float(layout.get("size", DEFAULT_MAP_SIZE))

## Read an island's layout without switching to it (where you arrive, say).
func read_layout(id: String) -> Dictionary: return _read(layout_file(id))

## An island's nav spots, rooms included, without switching to it.
func island_nav(id: String) -> Dictionary:
	var l := read_layout(id)
	var nodes: Dictionary = l.get("nav_nodes", {}).duplicate()
	for b in l.get("buildings", []):
		if b.has("interior"):
			var n: Dictionary = Interiors.nav(b)
			for k in n.nodes: nodes[k] = n.nodes[k]
	return nodes

func npc_island(id: String) -> String: return npc(id).get("island", "hearthglow")
func quest_island(qid: String) -> String: return npc_island(quest(qid).get("giver", ""))
## Villagers who live on the island you're on.
func npcs_here() -> Array: return npcs.filter(func(n): return n.get("island", "hearthglow") == island)

func piece(id: String) -> Dictionary: return piece_by_id.get(id, {})
func npc(id: String) -> Dictionary: return npc_by_id.get(id, {})
## A villager's pronoun in the form asked for: "they" (he/she), "them" (him/her), "their" (his/her).
## From `pronoun` in npcs.json ("he" or "she"); a villager without one is "they".
func pron(id: String, form: String = "they") -> String:
	var p := String(npc(id).get("pronoun", "they"))
	var forms := {"he": {"they": "he", "them": "him", "their": "his"}, "she": {"they": "she", "them": "her", "their": "her"}}
	return forms[p].get(form, p) if forms.has(p) else form
func quest(id: String) -> Dictionary: return quest_by_id.get(id, {})
## Bench-nap odds and lines here: data/naps.json, with any keys the layout's own "naps" block sets (a city's paper).
func paper_here() -> Dictionary:
	var p: Dictionary = paper.duplicate(true)
	p.merge(layout.get("paper", {}), true)
	return p

func naps_here() -> Dictionary:
	var n: Dictionary = naps.duplicate()
	n.merge(layout.get("naps", {}), true)
	return n

func zone(id: String) -> Dictionary:
	for z in layout.zones:
		if z.id == id: return z
	return {}
func node_def(id: String) -> Dictionary:
	for n in layout.nodes:
		if n.id == id: return n
	return {}

## Like _read, for files a location pack may leave out.
func _read_opt(name: String) -> Dictionary:
	return _read(name) if FileAccess.file_exists("res://data/%s.json" % name) else {}

func _read(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
	if f == null:
		push_error("Missing data file %s" % name)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
