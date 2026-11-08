class_name WorkDay

const MORNING := 7.0
const NAPS := [["🕛", "Noon", 12.0], ["☀️", "Afternoon", 15.0]]

static func def(island: String) -> Dictionary: return Data.island_def(island).get("day", {})

static func on(island: String) -> bool: return not def(island).is_empty()

static func hold_minute(d: Dictionary) -> float: return float(d.get("holdAt", 20.5)) * 60.0

static func holds(d: Dictionary) -> bool: return not d.is_empty() and bool(d.get("hold", false))

static func dusk(t: Dictionary, d: Dictionary) -> bool:
	var m := float(t.get("minute", 0.0))
	return not d.is_empty() and m >= hold_minute(d) - 60.0 and m < hold_minute(d) + 120.0

static func held(t: Dictionary, d: Dictionary) -> bool:
	return holds(d) and float(t.minute) >= hold_minute(d) - 0.01

static func advance(t: Dictionary, seconds: float, d: Dictionary) -> void:
	if not holds(d):
		Clock.advance(t, seconds)
		return
	var room := hold_minute(d) - float(t.minute)
	if room <= 0.0: return
	var m := minf(seconds * Clock.MINUTES_PER_SECOND, room)
	t.total = float(t.total) + m
	t.minute = float(t.minute) + m

static func next_morning(t: Dictionary) -> float:
	var skip := MORNING * 60.0 - float(t.minute)
	if skip <= 0.0: skip += 1440.0
	return float(t.total) + skip

static func regrow_at(t: Dictionary, d: Dictionary, minutes: float) -> float:
	if String(d.get("regrow", "")) == "overnight": return next_morning(t)
	return float(t.total) + minutes

static func to_dusk(t: Dictionary, d: Dictionary) -> void:
	var gap := hold_minute(d) - float(t.minute)
	if d.is_empty() or gap <= 0.0: return
	t.total = float(t.total) + gap
	t.minute = float(t.minute) + gap

static func ends_day(t: Dictionary, started: int, hour: float, d: Dictionary) -> bool:
	var wakes := int(t.get("day", 1)) + (1 if hour * 60.0 - float(t.get("minute", 0.0)) <= 1.0 else 0)
	return not d.is_empty() and wakes > started

static func sleep_options(minute: float, d: Dictionary) -> Array:
	var out: Array = []
	var hold := hold_minute(d)
	var naps: Array = NAPS.duplicate()
	naps.append(["🌇", "Dusk", hold / 60.0])
	for n in naps:
		var at: float = float(n[2]) * 60.0
		if at <= hold + 0.01 and at > minute + 30.0:
			out.append({"id": "wake_%d" % int(n[2]), "icon": n[0], "label": n[1], "hour": float(n[2]), "ends_day": false})
	out.append({"id": "wake_tomorrow", "icon": "🌅", "label": "Tomorrow morning", "hour": MORNING, "ends_day": true})
	return out

static func new_record(state: Dictionary) -> Dictionary:
	return {"day": int(state.get("time", {}).get("day", 1)), "built": 0, "gathered": 0, "quests": [], "harmony": int(state.get("harmony", 0)),
		"coins": int(state.get("inventory", {}).get("coins", 0))}

static func record(state: Dictionary) -> Dictionary:
	if not state.get("today") is Dictionary or state.today.is_empty(): state["today"] = new_record(state)
	return state.today

static func note(state: Dictionary, key: String, value = 1) -> void:
	var r := record(state)
	if value is String: (r[key] as Array).append(value)
	else: r[key] = int(r.get(key, 0)) + int(value)
