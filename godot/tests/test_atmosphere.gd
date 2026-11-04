extends RefCounted
## Atmosphere: shared shader values are declared, the colour grade never flips colours, and wind and ambient life
## follow the hour and the weather.
var t

const TYPES := {"float": "float", "vec2": "vec2", "vec3": "vec3", "vec4": "vec4"}

func _globals(code: String) -> Array:
	var out: Array = []
	var re := RegEx.new(); re.compile("global\\s+uniform\\s+(\\w+)\\s+(\\w+)")
	for m in re.search_all(code): out.append([m.get_string(1), m.get_string(2)])
	return out

func test_shader_globals_are_declared():
	var codes := {"plants": Foliage.PLANT_SHADER, "terrain": TerrainBuilder.TERRAIN_SHADER, "water": TerrainBuilder.WATER_SHADER,
		"sky": TerrainBuilder.SKY_SHADER, "cloud shadows": Atmosphere.POST_SHADER}
	var used := 0
	for k in codes:
		for g in _globals(codes[k]):
			used += 1
			var key := "shader_globals/" + String(g[1])
			t.ok(ProjectSettings.has_setting(key), "%s uses %s, declared in project.godot" % [k, g[1]])
			if ProjectSettings.has_setting(key):
				t.eq(String(ProjectSettings.get_setting(key).get("type", "")), TYPES.get(g[0], g[0]), "%s has the declared type" % g[1])
	t.ok(used >= 10, "shaders read the shared world values (%d uses)" % used)

func test_grade_never_flips_colours():
	for w in [{}, Daylight.WEATHER.rain, Daylight.WEATHER.mist, Daylight.WEATHER.cloudy]:
		for i in 49:
			var g := Atmosphere.grade_at(i * 0.5, w)
			var curve := Atmosphere.grade_curve(g[0], g[1])
			var ok := true
			for k in range(1, curve.size()):
				var a: Color = curve[k - 1]; var b: Color = curve[k]
				ok = ok and b.r >= a.r and b.g >= a.g and b.b >= a.b and b.r <= 1.0 and a.r >= 0.0
			t.ok(ok, "grade curve rises in every channel at %.1f h" % (i * 0.5))
	var noon := Atmosphere.grade_at(12.5, Daylight.WEATHER.clear)
	t.ok((noon[0] as Color).v < 0.03 and (noon[1] as Color).v > 0.95, "midday grade stays close to neutral")
	var dusk := Atmosphere.grade_at(19.5, Daylight.WEATHER.clear)
	t.ok((dusk[1] as Color).r > (dusk[1] as Color).b, "dusk highlights are warm")

func test_wind_follows_weather():
	var calm := Atmosphere.wind_at(3, 10.0, Daylight.WEATHER.clear)
	var storm := Atmosphere.wind_at(3, 10.0, Daylight.WEATHER.rain)
	t.ok(absf(Vector2(calm.x, calm.y).length() - 1.0) < 0.001, "wind direction is a unit vector")
	t.ok(storm.z > calm.z + 0.4, "rain blows harder (%.2f vs %.2f)" % [storm.z, calm.z])
	t.eq(Atmosphere.wind_at(3, 10.0, {}), Atmosphere.wind_at(3, 10.0, {}), "wind is a pure function of the clock")
	t.ok(Atmosphere.wind_at(3, 10.0, {}) != Atmosphere.wind_at(4, 10.0, {}), "the wind changes from day to day")

func test_ambient_life_follows_the_hour():
	var noon := Atmosphere.life_at(12.0, Daylight.WEATHER.clear)
	var night := Atmosphere.life_at(23.0, Daylight.WEATHER.clear)
	var wet_night := Atmosphere.life_at(23.0, Daylight.WEATHER.rain)
	t.ok(noon.motes > 0.8 and noon.fireflies == 0.0, "sunny noon: motes, no fireflies")
	t.ok(night.fireflies > 0.8 and night.motes == 0.0, "clear night: fireflies, no motes")
	t.eq(wet_night.fireflies, 0.0, "no fireflies in the rain")
	for k in noon: t.ok(noon[k] >= 0.0 and noon[k] <= 1.0 and wet_night[k] >= 0.0 and wet_night[k] <= 1.0, "%s stays within 0..1" % k)

func test_a_location_look_tints_the_grade():
	var base := Atmosphere.grade_at(14.0, Daylight.WEATHER.clear)
	var gloomy := Atmosphere.apply_look(base, {"shade": [0.0, 0.01, 0.04], "light": [0.9, 0.93, 1.0]})
	t.ok((gloomy[0] as Color).b > (base[0] as Color).b and (gloomy[1] as Color).r < (base[1] as Color).r, "a gloomy look: bluer shadows, cooler highlights")
	t.eq(Atmosphere.apply_look(base, {}), base, "no look changes nothing")
	var curve := Atmosphere.grade_curve(gloomy[0], gloomy[1])
	var ok := true
	for k in range(1, curve.size()): ok = ok and curve[k].r >= curve[k - 1].r and curve[k].g >= curve[k - 1].g and curve[k].b >= curve[k - 1].b
	t.ok(ok, "a tinted grade still never flips colours")
