class_name SaveSystem
## Save/load: versioned JSON files in user://, three slots plus an autosave.
const SLOTS := ["slot1", "slot2", "slot3"]
const AUTOSAVE := "autosave"

static func path(slot: String) -> String: return "user://wonderhaven_%s.json" % slot

static func serialize(state: Dictionary) -> String:
	var s := state.duplicate(true)
	s.version = GameState.SAVE_VERSION; s["saved_at"] = Time.get_unix_time_from_system()
	return JSON.stringify(s)

## Rebuild a state from saved text, filling in anything missing and dropping anything invalid.
static func deserialize(text: String) -> Dictionary:
	var raw = JSON.parse_string(text)
	if not raw is Dictionary: return {}
	var base := GameState.new_game()
	var s: Dictionary = base.duplicate(true)
	for k in raw: s[k] = raw[k]
	for k in ["flags", "quests", "relationships", "nodes", "gardens", "stats", "inventory", "time", "player", "crossings"]:
		var merged: Dictionary = base[k].duplicate(true)
		if raw.get(k) is Dictionary: merged.merge(raw[k], true)
		s[k] = merged
	for k in ["blueprints", "new_blueprints", "clothes_owned", "unlocks_seen"]:
		s[k] = (raw[k] as Array).filter(func(x): return x is String) if raw.get(k) is Array else base[k]
	s.appearance = Chibi.sanitize(raw.get("appearance", {}) if raw.get("appearance") is Dictionary else {})
	# Saves from before the guided first day: no tutorial, and no tip cards for things the player already knows.
	if raw.get("tutorial") is Dictionary:
		var t: Dictionary = Tutorial.new_state(false)
		t.merge(raw.tutorial, true)
		t.on = bool(t.on); t.step = int(t.step)
		t.seen = (t.seen as Array).filter(func(x): return x is String) if t.seen is Array else []
		t.panels = (t.panels as Array).filter(func(x): return x is String) if t.panels is Array else []
		s.tutorial = t
	else:
		s.tutorial = Tutorial.new_state(false, true)
	s.placements = _placements(raw.get("placements", []))
	# what you built on the other islands (see Travel)
	var away := {}
	if raw.get("away") is Dictionary:
		for isl in raw.away:
			if raw.away[isl] is Dictionary: away[str(isl)] = {"placements": _placements(raw.away[isl].get("placements", []))}
	s.away = away
	if not Data.has_island(str(s.get("island", "hearthglow"))): s.island = "hearthglow"
	s.next_uid = maxi(int(raw.get("next_uid", 1)), Travel.max_uid(s) + 1)
	s.harmony = int(s.harmony)
	for k in s.inventory: s.inventory[k] = int(s.inventory[k])
	s.time = {"day": int(s.time.get("day", 1)), "minute": float(s.time.get("minute", 480)), "total": float(s.time.get("total", 0))}
	s.version = GameState.SAVE_VERSION
	return s

static func _placements(list) -> Array:
	var pls: Array = []
	for p in (list if list is Array else []):
		if not p is Dictionary or Data.piece(str(p.get("id", ""))).is_empty(): continue
		var pl := {"uid": int(p.get("uid", 0)), "id": str(p.id), "i": float(p.get("i", 0)), "k": float(p.get("k", 0)), "r": posmod(int(p.get("r", 0)), 4), "y": float(p.get("y", 0))}
		if p.has("color"): pl["color"] = str(p.color)
		if p.get("state") is Dictionary: pl["state"] = p.state
		pls.append(pl)
	return pls

static func write(slot: String, state: Dictionary) -> bool:
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null: return false
	f.store_string(serialize(state)); return true

static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)): return {}
	return deserialize(FileAccess.get_file_as_string(path(slot)))

static func meta(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)): return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not raw is Dictionary: return {"slot": slot, "broken": true}
	var done := 0
	for q in raw.get("quests", {}).values():
		if q.get("status", "") == "done": done += 1
	return {"slot": slot, "name": raw.get("name", "?"), "day": int(raw.get("time", {}).get("day", 1)), "harmony": int(raw.get("harmony", 0)), "saved_at": float(raw.get("saved_at", 0)), "quests": done}

static func latest() -> String:
	var best := ""
	var t := -1.0
	for slot in [AUTOSAVE] + SLOTS:
		var m := meta(slot)
		if not m.is_empty() and not m.get("broken", false) and m.saved_at > t: t = m.saved_at; best = slot
	return best

const SETTINGS_PATH := "user://wonderhaven_settings.json"
const DEFAULT_SETTINGS := {"music": 0.6, "sfx": 0.8, "sensitivity": 1.0, "invert_y": false, "weather": true, "outlines": true, "fullscreen": false, "bindings": {}}
static func load_settings() -> Dictionary:
	var s := DEFAULT_SETTINGS.duplicate(true)
	if FileAccess.file_exists(SETTINGS_PATH):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if raw is Dictionary: s.merge(raw, true)
	return s
static func store_settings(s: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(s))
