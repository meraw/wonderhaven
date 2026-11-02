extends Node
## Game content loaded from data/*.json (exported from the shared content files by scripts/export-godot-data.mjs).

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

func _init() -> void:
	load_all()

func load_all() -> void:
	layout = _read("layout")
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
