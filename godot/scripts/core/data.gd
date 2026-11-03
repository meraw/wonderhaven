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
## The island you're on. `layout` is that island's layout (data/layout.json for Hearthglow, layout_<id>.json for
## the others); Heightfield follows it. Sailing reloads the scene with the new island (see game.travel).
var island := "hearthglow"
var pending_state: Dictionary = {}   # the game state carried across that reload
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
	_add_interior_nav()

## Rooms you can walk into add nav spots (inside the door, and where the owner works and sleeps) to the village graph.
func _add_interior_nav() -> void:
	for b in layout.buildings:
		if not b.has("interior"): continue
		var n: Dictionary = Interiors.nav(b)
		for k in n.nodes: layout.nav_nodes[k] = n.nodes[k]
		for e in n.edges: layout.nav_edges.append(e)

static func layout_file(id: String) -> String: return "layout" if id == "hearthglow" else "layout_" + id
func has_island(id: String) -> bool: return FileAccess.file_exists("res://data/%s.json" % layout_file(id))
func island_def(id: String) -> Dictionary:
	for i in islands:
		if i.id == id: return i
	return {}

## Switch to another island's layout and ground (the world is rebuilt from it when the scene loads).
func use_island(id: String) -> void:
	island = id
	Heightfield.island = id
	layout = _read(layout_file(id))
	_add_interior_nav()

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
func quest(id: String) -> Dictionary: return quest_by_id.get(id, {})
func zone(id: String) -> Dictionary:
	for z in layout.zones:
		if z.id == id: return z
	return {}
func node_def(id: String) -> Dictionary:
	for n in layout.nodes:
		if n.id == id: return n
	return {}

func _read(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
	if f == null:
		push_error("Missing data file %s" % name)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
