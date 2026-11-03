class_name Clock
## Day/night clock and gentle weather. One real second is one game minute: a day lasts 24 real minutes.
const MINUTES_PER_SECOND := 1.0

static func advance(t: Dictionary, dt: float) -> bool:
	var m := dt * MINUTES_PER_SECOND
	t.total += m; t.minute += m
	var new_day := false
	while t.minute >= 1440.0: t.minute -= 1440.0; t.day += 1; new_day = true
	return new_day
static func is_night(t: Dictionary) -> bool: return t.minute < 360.0 or t.minute >= 1230.0
static func daylight(t: Dictionary) -> float:
	var h: float = t.minute / 60.0
	if h < 5.0 or h > 21.5: return 0.0
	if h < 8.0: return (h - 5.0) / 3.0
	if h > 18.5: return 1.0 - (h - 18.5) / 3.0
	return 1.0
static func text(t: Dictionary) -> String:
	var h := int(t.minute / 60.0)
	var m := int(fmod(t.minute, 60.0))
	return "Day %d · %d:%02d %s" % [int(t.day), ((h + 11) % 12) + 1, m, "AM" if h < 12 else "PM"]
## Simple weather name for gameplay and the HUD: "sunny", "cloudy" or "rain" (details in Daylight.weather).
static func weather(t: Dictionary) -> String:
	var w: String = Daylight.weather(t).type
	return "sunny" if w in ["clear", "fair"] else ("rain" if w in ["drizzle", "rain"] else "cloudy")
static func sleep_until_morning(t: Dictionary) -> void:
	var skipped: float = (1440.0 - t.minute + 420.0) if t.minute >= 360.0 else (420.0 - t.minute)
	if t.minute >= 360.0: t.day += 1
	t.total += skipped; t.minute = 420.0
