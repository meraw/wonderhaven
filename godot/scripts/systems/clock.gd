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
	var w: String = Daylight.weather(t, Daylight.allowed_here()).type
	return "sunny" if w in ["clear", "fair"] else ("rain" if w in ["drizzle", "rain"] else "cloudy")
static func sleep_until_morning(t: Dictionary) -> void:
	var skipped: float = (1440.0 - t.minute + 420.0) if t.minute >= 360.0 else (420.0 - t.minute)
	if t.minute >= 360.0: t.day += 1
	t.total += skipped; t.minute = 420.0

## "5 AM", "12 PM" for an hour of the day (0-24).
static func hour_num(h: float) -> String:
	var hh := int(h) % 24
	return "%d %s" % [((hh + 11) % 12) + 1, "AM" if hh < 12 else "PM"]

## "5 AM", "8 PM", "noon", "midnight" for an hour of the day (0-24).
static func hour_text(h: float) -> String:
	var hh := int(h) % 24
	if hh == 0: return "midnight"
	if hh == 12: return "noon"
	return "%d %s" % [((hh + 11) % 12) + 1, "AM" if hh < 12 else "PM"]

## Is the time inside an [from, to] window of hours? Windows can wrap past midnight ([20, 4] is 8 PM to 4 AM).
static func in_hours(h: Array, minute: float) -> bool:
	if h.size() < 2: return true
	var x := minute / 60.0; var a := float(h[0]); var b := float(h[1])
	return (x >= a and x < b) if a <= b else (x >= a or x < b)

static func hours_text(h: Array) -> String: return "between %s and %s" % [hour_text(float(h[0])), hour_text(float(h[1]))]

## Sleep (or nap) until the next time it's `hour` o'clock: tomorrow if that hour has passed today. Returns the
## minutes slept.
static func sleep_until(t: Dictionary, hour: float) -> float:
	var target := hour * 60.0
	var skipped: float = target - t.minute
	if skipped <= 1.0: skipped += 1440.0; t.day += 1
	t.total += skipped; t.minute = target
	return skipped
