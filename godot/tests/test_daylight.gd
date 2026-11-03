extends RefCounted
## Time of day and weather: parts of the day, smooth sky changes, the sun's path, weather slots and blending,
## and the tunes for each part of the day.
var t
const AudioDirector := preload("res://scripts/audio/audio_director.gd")

func test_parts_of_the_day():
	t.eq(Daylight.part_of_day(3.0), "night", "3 am is night")
	t.eq(Daylight.part_of_day(6.0), "dawn", "6 am is dawn")
	t.eq(Daylight.part_of_day(9.0), "morning", "9 am is morning")
	t.eq(Daylight.part_of_day(14.0), "afternoon", "2 pm is afternoon")
	t.eq(Daylight.part_of_day(19.0), "evening", "7 pm is evening")
	t.eq(Daylight.part_of_day(22.5), "night", "10:30 pm is night")

func test_sky_changes_gradually():
	var biggest := 0.0
	var prev := Daylight.sample(0.0)
	for m in range(1, 1441):
		var cur := Daylight.sample(m / 60.0)
		for k in ["zenith", "horizon", "sun_color", "ambient"]:
			var a: Color = prev[k]; var b: Color = cur[k]
			biggest = maxf(biggest, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
		prev = cur
	t.ok(biggest < 0.03, "no colour jumps more than 3%% in a game minute (largest %.3f)" % biggest)
	t.ok(Daylight.sample(12.0).sun_energy > Daylight.sample(2.0).sun_energy * 4.0, "noon is far brighter than 2 am")
	t.ok(Daylight.sample(19.6).horizon.r > Daylight.sample(12.0).horizon.r * 0.95 and Daylight.sample(19.6).horizon.b < Daylight.sample(12.0).horizon.b, "sunset horizon is warm")

func test_sun_and_moon_paths():
	t.ok(Daylight.sun_dir(13.0).y > 0.8, "the sun is high early in the afternoon")
	t.ok(Daylight.sun_dir(6.0).y < 0.1 and Daylight.sun_dir(6.0).x > 0.5, "it rises low in the east")
	t.ok(Daylight.sun_dir(20.0).x < -0.5, "and sets in the west")
	t.ok(Daylight.moon_dir(1.0).y > 0.5, "the moon is up at 1 am")
	for h in 24: t.ok(Daylight.light_dir(h).y >= 0.12, "the light always comes from above the horizon (%d:00)" % h)
	t.eq(Daylight.nightness(12.0), 0.0, "no night at noon")
	t.eq(Daylight.nightness(1.0), 1.0, "full night at 1 am")

func test_weather_slots_and_blending():
	t.eq(Daylight.weather({"day": 1, "minute": 600.0}).type, "clear", "the first day is sunny")
	t.eq(Clock.weather({"day": 1, "minute": 600.0}), "sunny", "and Clock reports it as sunny")
	var seen := {}
	var biggest := 0.0
	var prev := Daylight.weather({"day": 2, "minute": 0.0})
	for day in range(2, 30):
		for m in range(0, 1440, 5):
			var w := Daylight.weather({"day": day, "minute": float(m)})
			seen[w.type] = true
			for k in ["clouds", "rain", "fog"]: biggest = maxf(biggest, absf(w[k] - prev[k]))
			prev = w
	t.ok(biggest < 0.12, "weather drifts: no value jumps more than 0.12 in 5 game minutes (largest %.3f)" % biggest)
	for k in ["clear", "fair", "cloudy", "drizzle", "rain", "mist"]: t.ok(seen.has(k), "%s weather happens within a month" % k)
	for slot in range(12, 400):
		if Daylight.slot_weather(slot) == "mist": t.eq(slot % 6, 1, "mist only in the early-morning slot")
	t.eq(Daylight.weather({"day": 9, "minute": 700.0}), Daylight.weather({"day": 9, "minute": 700.0}), "the same moment always has the same weather")

func test_day_songs():
	for part in ["dawn", "morning", "afternoon", "evening", "night"]:
		var id: String = AudioDirector.DAY_SONGS[part]
		t.ok(AudioDirector.SONGS.has(id), "%s has a tune (%s)" % [part, id])
	var ids := {}
	for part in AudioDirector.DAY_SONGS: ids[AudioDirector.DAY_SONGS[part]] = true
	t.eq(ids.size(), 5, "each part of the day has its own tune")
	for id in AudioDirector.SONGS:
		var s: Dictionary = AudioDirector.SONGS[id]
		t.ok(s.lead in AudioDirector.INSTRUMENTS and (s.arp == "" or s.arp in AudioDirector.INSTRUMENTS), "%s uses known instruments" % id)
		var last := -1; var sorted := true
		for m in s.melody:
			if int(m[0]) < last: sorted = false
			last = int(m[0])
		t.ok(sorted and s.chords.size() > 0, "%s melody is in order and has chords" % id)
