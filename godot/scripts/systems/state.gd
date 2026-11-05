class_name GameState
## The whole saved game as one plain, serialisable Dictionary.
const SAVE_VERSION := 1
const START_MINUTE := 8 * 60

static func new_game(player_name: String = "Apprentice", appearance: Dictionary = {}) -> Dictionary:
	var sp: Dictionary = Data.read_layout("hearthglow").spawn if Data.island != "hearthglow" else Data.layout.spawn
	return {
		"version": SAVE_VERSION, "name": player_name.substr(0, 16) if player_name != "" else "Apprentice",
		"appearance": Chibi.sanitize(appearance), "created": Time.get_unix_time_from_system(), "play_time": 0.0,
		"island": "hearthglow", "away": {}, "player": {"x": sp.x, "z": sp.z, "yaw": sp.yaw},
		"inventory": {}, "harmony": 0, "flags": {}, "quests": {}, "tracked": "",
		"placements": [], "next_uid": 1, "blueprints": Data.starter_blueprints.duplicate(), "new_blueprints": [],
		"clothes_owned": [], "relationships": {}, "nodes": {}, "gardens": {}, "crossings": {},
		"time": {"day": 1, "minute": float(START_MINUTE), "total": 0.0},
		"stats": {"fish": 0, "chopped": 0, "mined": 0, "dug": 0, "chests": 0, "fragments": 0, "placed": 0, "treasures": 0, "types": []},
		"unlocks_seen": [], "tutorial": Tutorial.new_state(true), "meters": {},
	}

static func clothing_unlocked(state: Dictionary, id: String) -> bool:
	return not Data.appearance.locked.has(id) or state.clothes_owned.has(id)
