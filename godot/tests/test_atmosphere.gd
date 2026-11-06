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

## With MSAA a pixel on a triangle's edge reads its vertex colour from just outside the triangle, a little below zero
## on dark grass roots, and pow() of a negative number is NaN: the glow spread each one into a black (or magenta)
## square on the meadow. Every shader that turns vertex colours from sRGB with pow() clamps them first.
func test_vertex_colours_never_reach_pow_below_zero():
	var codes := {"plants": Foliage.PLANT_SHADER, "terrain": TerrainBuilder.TERRAIN_SHADER, "hills": TerrainBuilder.HILLS_SHADER}
	for k in codes:
		var code: String = codes[k]
		t.ok(code.contains("pow((c"), "%s turns its vertex colours from sRGB" % k)
		t.ok(code.contains("max(COLOR.rgb"), "%s clamps its vertex colours at zero before pow()" % k)

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

func test_valley_mist_lifts_by_late_morning():
	var spec := {"morning": 0.9, "day": 0.1, "evening": 0.3, "night": 0.5}
	var clear: Dictionary = Daylight.WEATHER.clear
	t.ok(Atmosphere.valley_fog_at(6.5, spec, clear) > 0.85, "a sea of mist at dawn")
	t.ok(Atmosphere.valley_fog_at(13.0, spec, clear) < 0.15, "burnt off by early afternoon")
	t.ok(Atmosphere.valley_fog_at(9.5, spec, clear) < Atmosphere.valley_fog_at(8.0, spec, clear), "thinning through the morning")
	t.ok(Atmosphere.valley_fog_at(20.0, spec, clear) > Atmosphere.valley_fog_at(15.0, spec, clear), "gathering again in the evening")
	t.ok(absf(Atmosphere.valley_fog_at(23.9, spec, clear) - Atmosphere.valley_fog_at(0.1, spec, clear)) < 0.01, "no jump at midnight")
	var misty := {"fog": 1.0}
	t.ok(Atmosphere.valley_fog_at(13.0, spec, misty) > 0.8, "a misty day keeps it thick at noon")
	for h in 24: t.ok(Atmosphere.valley_fog_at(h, spec, Daylight.WEATHER.rain) <= 1.0, "stays within 0..1 at %d" % h)

func test_a_location_can_have_a_white_sky_haze_frost_and_a_low_sun():
	# sky: the daytime sky leans toward its colour (the horizon fully, the zenith a little over half); night stays.
	var lk := {"sky": {"color": [1.0, 1.0, 1.0], "pale": 1.0}, "haze": {"color": [1.0, 1.0, 1.0], "amount": 1.0, "near": 20, "far": 100}}
	var blue := Color(0.2, 0.5, 0.9); var dusk := Color(0.6, 0.7, 0.8)
	var day := Atmosphere.sky_look(lk, blue, dusk, 0.0)
	t.ok((day[1] as Color).is_equal_approx(Color.WHITE), "by day the horizon is the location's white")
	t.ok(day[0].b > blue.b and day[0].r > blue.r and day[0].r < 0.9, "and the zenith paler but still blue")
	var night := Atmosphere.sky_look(lk, blue, dusk, 1.0)
	t.ok(night[0] == blue and night[1] == dusk, "the night sky is untouched")
	t.eq(Atmosphere.sky_look({}, blue, dusk, 0.0), [blue, dusk], "a place without a sky block keeps the shared sky")
	# haze: its colour by day and nearer, but never further than the weather already put it.
	var hz := Atmosphere.haze(lk, dusk, 45.0, 220.0, 0.0)
	t.ok((hz.color as Color).is_equal_approx(Color.WHITE) and hz.begin == 20.0 and hz.end == 100.0, "by day the haze is white and closer")
	var misty := Atmosphere.haze(lk, dusk, 2.0, 45.0, 0.0)
	t.ok(misty.begin == 2.0 and misty.end == 45.0, "morning mist that is already closer stays")
	var dark := Atmosphere.haze(lk, dusk, 45.0, 220.0, 1.0)
	t.ok(dark.color == dusk and dark.begin == 45.0, "at night the haze is the sky's own")
	t.eq(Atmosphere.haze({}, dusk, 45.0, 220.0, 0.0), {"color": dusk, "begin": 45.0, "end": 220.0}, "a place without haze keeps the shared one")
	# frost whitens the ground through the night and early morning and is gone by late morning; ice only in the
	# small hours.
	t.eq(Atmosphere.frost_at(6.0), 1.0, "frost at dawn")
	t.ok(Atmosphere.frost_at(9.25) > 0.0 and Atmosphere.frost_at(9.25) < 1.0, "melting at 9:15")
	t.eq(Atmosphere.frost_at(11.0), 0.0, "gone by 11")
	t.eq(Atmosphere.frost_at(15.0), 0.0, "none in the afternoon")
	t.eq(Atmosphere.frost_at(23.0), 1.0, "back on a clear night")
	t.eq(Atmosphere.ice_at(5.0), 1.0, "thin ice on the puddles at 5")
	t.eq(Atmosphere.ice_at(10.0), 0.0, "melted by 10")
	t.eq(Atmosphere.ice_at(22.0), 0.0, "not yet in the evening")
	var biggest := 0.0
	for m in range(1, 1440):
		biggest = maxf(biggest, maxf(absf(Atmosphere.frost_at(m / 60.0) - Atmosphere.frost_at((m - 1) / 60.0)), absf(Atmosphere.ice_at(m / 60.0) - Atmosphere.ice_at((m - 1) / 60.0))))
	t.ok(biggest < 0.03, "frost and ice come and go gradually (largest change in a minute %.3f)" % biggest)
	# a low winter sun: the same path, lower in the sky.
	var noon_high := Daylight.sun_dir(13.0).y
	Daylight.sun_peak = 30.0
	var noon_low := Daylight.sun_dir(13.0).y
	t.ok(absf(rad_to_deg(asin(noon_low)) - 30.0) < 0.5, "a 30° sun_peak puts the sun 30° up at 13:00 (%.1f°)" % rad_to_deg(asin(noon_low)))
	t.ok(Daylight.sun_dir(6.0).x > 0.5 and Daylight.sun_dir(20.0).x < -0.5, "it still rises in the east and sets in the west")
	for h in 24: t.ok(Daylight.light_dir(h).y >= 0.12, "the light still comes from above the horizon (%d:00)" % h)
	Daylight.sun_peak = Daylight.SUN_PEAK
	t.eq(Daylight.sun_dir(13.0).y, noon_high, "and the shared sun is back to its height")
	# Casalrana uses all of it.
	var rv: Dictionary = Data.island_def("rice_village").look
	for k in ["sky", "haze", "water", "frost", "sun_peak"]: t.ok(rv.has(k), "Casalrana's look has %s" % k)
	t.ok(float(rv.sun_peak) < 40.0, "Casalrana's winter sun is low")
