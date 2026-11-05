class_name Daylight
## The look of each hour and the weather: parts of the day (for music), keyframed sky and light colours, the sun
## and moon's path, and smoothly changing weather. Pure functions of the game clock, so saves and tests agree.

## Parts of the day, by the hour they start.
const PARTS := [[0.0, "night"], [5.0, "dawn"], [7.5, "morning"], [12.0, "afternoon"], [17.5, "evening"], [21.0, "night"]]

static func part_of_day(hour: float) -> String:
	var out := "night"
	for p in PARTS:
		if hour >= float(p[0]): out = p[1]
	return out

## Sky and light keyframes: [hour, zenith, horizon, sun colour, sun energy, ambient colour, ambient energy].
const KEYS := [
	[0.0, "0c1433", "1e2a52", "a8bde8", 0.10, "56679f", 0.22],
	[4.6, "121b3e", "28305a", "a8bde8", 0.09, "5a6aa2", 0.22],
	[5.6, "2a3a78", "c98f96", "ffb38a", 0.14, "8a90c0", 0.26],
	[6.6, "5a8ad0", "ffc28e", "ffc890", 0.40, "b0b8d8", 0.32],
	[8.0, "6cbcf5", "d8f0ff", "fff0d8", 0.58, "c4d8ee", 0.40],
	[12.0, "58b2f5", "dcf2ff", "fff6e8", 0.64, "c9dcf0", 0.42],
	[16.5, "62b2ee", "e8f0f0", "fff0d0", 0.58, "cdd8e6", 0.40],
	[18.5, "6a9ed8", "ffd8a0", "ffc880", 0.50, "d8c8c0", 0.36],
	[19.6, "4a6aa8", "ff9a70", "ff9a60", 0.30, "b098b0", 0.30],
	[20.6, "25306a", "7a5a8a", "c0a0d0", 0.14, "707ab0", 0.25],
	[21.6, "0e1638", "222c58", "a8bde8", 0.10, "56679f", 0.22],
	[24.0, "0c1433", "1e2a52", "a8bde8", 0.10, "56679f", 0.22],
]

## Colours and energies for a moment of the day, blended smoothly between keyframes.
static func sample(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var i := 0
	while i < KEYS.size() - 2 and h >= float(KEYS[i + 1][0]): i += 1
	var a: Array = KEYS[i]; var b: Array = KEYS[i + 1]
	var f := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	return {"zenith": Color(a[1]).lerp(Color(b[1]), f), "horizon": Color(a[2]).lerp(Color(b[2]), f),
		"sun_color": Color(a[3]).lerp(Color(b[3]), f), "sun_energy": lerpf(a[4], b[4], f),
		"ambient": Color(a[5]).lerp(Color(b[5]), f), "ambient_energy": lerpf(a[6], b[6], f)}

## How much it is night (0 day .. 1 night), for stars, the moon and lit windows.
static func nightness(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= 7.0 and h <= 19.0: return 0.0
	if h > 19.0 and h < 21.5: return smoothstep(19.0, 21.5, h)
	if h > 4.5 and h < 7.0: return 1.0 - smoothstep(4.5, 7.0, h)
	return 1.0

## How high the sun climbs at 13:00, in degrees. A location's look can lower it ("sun_peak": a low winter sun and
## long shadows); Atmosphere sets it for the place you're on.
const SUN_PEAK := 62.0
static var sun_peak := SUN_PEAK

## Direction towards the sun (it rises in the east at 6:00, is highest at 13:00, sets in the west at 20:00).
static func sun_dir(hour: float) -> Vector3:
	var t := (fposmod(hour, 24.0) - 6.0) / 14.0            # 0 at sunrise, 1 at sunset
	var elev := sin(clampf(t, -0.2, 1.2) * PI) * deg_to_rad(sun_peak)
	var az := lerpf(deg_to_rad(100.0), deg_to_rad(260.0), t)  # east (x+) round the south (z+) to the west
	return Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev)).normalized()

## Direction towards the moon (up through the night, opposite the sun's path).
static func moon_dir(hour: float) -> Vector3:
	var t := fposmod(fposmod(hour, 24.0) - 20.0, 24.0) / 10.0   # 0 at 20:00, 1 at 6:00
	var elev := sin(clampf(t, -0.1, 1.1) * PI) * deg_to_rad(48.0)
	var az := lerpf(deg_to_rad(110.0), deg_to_rad(250.0), t)
	return Vector3(sin(az) * cos(elev), maxf(0.05, sin(elev)), -cos(az) * cos(elev)).normalized()

## Direction the main light comes from: the sun by day, the moon by night, fading through the horizon.
static func light_dir(hour: float) -> Vector3:
	var n := nightness(hour)
	var s := sun_dir(hour); var m := moon_dir(hour)
	var d := s.lerp(m, n).normalized()
	if d.y < 0.121:   # never from below about 7° (keeping its compass direction)
		var flat := Vector2(d.x, d.z).normalized() * sqrt(1.0 - 0.121 * 0.121)
		d = Vector3(flat.x, 0.121, flat.y)
	return d

# ---- Weather -----------------------------------------------------------------------------------------------
## Each 4-hour slot gets a weather type; the last hour of a slot blends into the next, so changes are gradual.
const SLOT_MINUTES := 240.0
const BLEND_MINUTES := 60.0
const WEATHER := {
	"clear": {"clouds": 0.12, "rain": 0.0, "fog": 0.0, "sun": 1.0},
	"fair": {"clouds": 0.4, "rain": 0.0, "fog": 0.0, "sun": 0.95},
	"cloudy": {"clouds": 0.78, "rain": 0.0, "fog": 0.12, "sun": 0.6},
	"drizzle": {"clouds": 0.86, "rain": 0.35, "fog": 0.18, "sun": 0.48},
	"rain": {"clouds": 0.95, "rain": 0.9, "fog": 0.28, "sun": 0.38},
	"mist": {"clouds": 0.3, "rain": 0.0, "fog": 0.8, "sun": 0.75},
}

static func slot_index(t: Dictionary) -> int: return int(t.day) * 6 + int(float(t.minute) / SLOT_MINUTES)

## Weather type of a slot: deterministic, mostly fair, mist only around dawn, and a sunny first day.
## `allowed` is the weather a location allows (the `weather` list in its look block, see allowed_here); any other
## weather turns into the first type listed. Empty allows everything.
static func slot_weather(slot: int, allowed: Array = []) -> String:
	var w := _slot_weather(slot)
	return w if allowed.is_empty() or allowed.has(w) else String(allowed[0])

## The weather the location you're on allows (its look block's `weather`, e.g. ["clear"]), or [] for any.
## A request can bring its own weather for a while (a storm on a finale's night): state.forced_weather = {type, until},
## `until` in the clock's total minutes. The weather type while it lasts, else "".
static func forced(state: Dictionary) -> String:
	var fw = state.get("forced_weather", {})
	if not fw is Dictionary or fw.is_empty(): return ""
	if float(state.get("time", {}).get("total", 0.0)) >= float(fw.get("until", 0.0)): return ""
	return String(fw.get("type", "")) if WEATHER.has(String(fw.get("type", ""))) else ""

## Brings `type` weather (a key of WEATHER) for the next `hours`.
static func force(state: Dictionary, type: String, hours: float) -> void:
	state["forced_weather"] = {"type": type, "until": float(state.time.total) + hours * 60.0}

static func allowed_here() -> Array: return Data.island_def(Data.island).get("look", {}).get("weather", [])

static func _slot_weather(slot: int) -> String:
	var day := int(slot / 6); var part := slot % 6
	if day <= 1: return "clear" if part < 4 else "fair"
	var x := sin(slot * 12.9898 + 4.1414) * 43758.5453
	var r := x - floorf(x)
	if part == 1 and r < 0.25: return "mist"   # 4:00–8:00
	if r < 0.36: return "clear"
	if r < 0.66: return "fair"
	if r < 0.82: return "cloudy"
	if r < 0.92: return "drizzle"
	return "rain"

## Blended weather values for the moment: clouds, rain, fog (0..1) and how much sun gets through.
static func weather(t: Dictionary, allowed: Array = []) -> Dictionary:
	var slot := slot_index(t)
	var into := fmod(float(t.minute), SLOT_MINUTES)
	var a: Dictionary = WEATHER[slot_weather(slot, allowed)]
	var f := clampf((into - (SLOT_MINUTES - BLEND_MINUTES)) / BLEND_MINUTES, 0.0, 1.0)
	var out := a.duplicate()
	if f > 0.0:
		var b: Dictionary = WEATHER[slot_weather(slot + 1, allowed)]
		f = f * f * (3.0 - 2.0 * f)
		for k in out: out[k] = lerpf(a[k], b[k], f)
	out["type"] = slot_weather(slot, allowed) if f < 0.5 else slot_weather(slot + 1, allowed)
	return out
