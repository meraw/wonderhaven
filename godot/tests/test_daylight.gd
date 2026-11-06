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

func test_a_location_can_have_short_winter_days():
	t.eq(Daylight.light_hour(18.3), 18.3, "with the usual day, the light follows the clock")
	Daylight.sunrise = 7.5; Daylight.sunset = 17.0
	t.ok(absf(Daylight.light_hour(17.0) - 20.0) < 0.001 and absf(Daylight.light_hour(7.5) - 6.0) < 0.001, "sunset and sunrise land where the usual day has them")
	t.eq(Daylight.nightness(12.0), 0.0, "midday is still day")
	t.ok(Daylight.sun_dir(17.5).y < 0.0, "the sun has set by half past five")
	t.ok(Daylight.nightness(18.5) > 0.6, "and it's dark by half past six (%.2f)" % Daylight.nightness(18.5))
	t.ok(Daylight.nightness(7.0) > 0.5, "winter mornings are dark at seven (%.2f)" % Daylight.nightness(7.0))
	t.eq(Daylight.part_of_day(18.5), "evening", "but the clock's parts of the day stay as they are")
	t.eq(Daylight.part_of_day(13.0), "afternoon", "")
	Daylight.sunrise = Daylight.SUNRISE; Daylight.sunset = Daylight.SUNSET
	t.eq(Daylight.nightness(18.5), 0.0, "and everywhere else the evening is still light")

func test_a_location_can_have_foggy_mornings():
	var count := func() -> int:
		var n := 0
		for day in range(2, 202):
			if Daylight.slot_weather(day * 6 + 1) == "mist": n += 1
		return n
	var usual: int = count.call()
	Daylight.mist_odds = 0.7
	var foggy: int = count.call()
	Daylight.mist_odds = Daylight.MIST_ODDS
	t.ok(usual < 80, "most places have a misty early morning now and then (%d of 200)" % usual)
	t.ok(foggy > 120, "a foggy city has one most days (%d of 200)" % foggy)
	t.eq(count.call(), usual, "and the usual odds come back")

func test_snow_only_when_a_request_brings_it():
	var keys: Array = Daylight.WEATHER.clear.keys(); keys.sort()
	for w in Daylight.WEATHER:
		var k: Array = Daylight.WEATHER[w].keys(); k.sort()
		t.eq(k, keys, "%s has the same values as the rest (so weathers blend)" % w)
	t.eq(float(Daylight.WEATHER.snow.snow), 1.0, "snow is snow")
	var any := false
	for slot in range(12, 12 + 600):
		if Daylight.slot_weather(slot) == "snow": any = true
	t.ok(not any, "it never snows by itself")
	var st := {"time": {"day": 3, "minute": 1100.0, "total": 3 * 1440.0 + 1100.0}}
	Daylight.force(st, "snow", 12.0)
	t.eq(Daylight.forced(st), "snow", "a request can bring it (the finale's surprise)")
	st.time.total += 13 * 60.0
	t.eq(Daylight.forced(st), "", "and it stops when its hours are up")

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

func test_a_location_can_limit_its_weather():
	# A location's look block can list the weather it allows; anything else turns into the first type listed.
	var kept := {}
	for day in range(2, 30):
		for m in range(0, 1440, 30):
			var tm := {"day": day, "minute": float(m)}
			t.eq(Daylight.weather(tm, ["clear"]).type, "clear", "only clear weather where only clear is allowed (day %d, %d min)" % [day, m])
			t.eq(Daylight.weather(tm, ["clear"]).rain, 0.0, "and never a drop of rain")
			var two: String = Daylight.weather(tm, ["fair", "clear"]).type
			t.ok(two in ["fair", "clear"], "two allowed types stay within them (%s)" % two)
			kept[two] = true
	t.ok(kept.has("fair") and kept.has("clear"), "both allowed types still happen")
	t.eq(Daylight.weather({"day": 9, "minute": 700.0}, []), Daylight.weather({"day": 9, "minute": 700.0}), "an empty list allows everything")
	t.eq(Daylight.allowed_here(), [], "Monteforchetta allows any weather")

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

func test_a_location_can_bring_its_own_music():
	# "music" in a map entry: its own songs, and which one plays in each part of the day; parts it leaves out keep
	# the shared tunes, and build mode keeps the building tune unless it names its own.
	var music := {"songs": {"x_dawn": {"bpm": 60, "root": 60, "lead": "flute", "arp": "", "drums": "", "pad": 0.1, "length": 96,
		"chords": [[0, 4, 7]], "melody": [[0, 12], [8, 7]]}}, "parts": {"dawn": "x_dawn"}}
	t.eq(AudioDirector.song_for("dawn", false, music), "x_dawn", "dawn plays the location's own tune")
	t.eq(AudioDirector.song_for("evening", false, music), AudioDirector.DAY_SONGS.evening, "a part it leaves out keeps the shared tune")
	t.eq(AudioDirector.song_for("dawn", true, music), "build", "build mode keeps the building tune")
	t.eq(AudioDirector.song_for("morning", false, {}), AudioDirector.DAY_SONGS.morning, "a place without music plays the shared tunes")
	t.eq(AudioDirector.song_def("x_dawn", music).bpm, 60, "the location's song is found by id")
	t.eq(AudioDirector.song_def("night", music), AudioDirector.SONGS.night, "and the shared ones still are")
	t.eq(AudioDirector.loop_steps(AudioDirector.song_def("x_dawn", music)), 96, "length leaves a pause after the phrase")
	t.eq(AudioDirector.loop_steps(AudioDirector.SONGS.night), 64, "songs without a length repeat right after their melody")
	# Casalrana: sparse, quiet themes of its own for every part of the day, with long pauses between phrases.
	var rv: Dictionary = Data.island_def("rice_village").get("music", {})
	var ids := {}
	for part in AudioDirector.DAY_SONGS:
		var id := AudioDirector.song_for(part, false, rv)
		t.ok(rv.songs.has(id), "Casalrana has its own %s tune (%s)" % [part, id])
		ids[id] = true
		var s := AudioDirector.song_def(id, rv)
		t.ok(s.lead in AudioDirector.INSTRUMENTS and (s.arp == "" or s.arp in AudioDirector.INSTRUMENTS), "%s uses known instruments" % id)
		t.eq(s.drums, "", "%s has no drums" % id)
		var last := 0
		for m in s.melody: last = maxi(last, int(m[0]))
		t.ok(AudioDirector.loop_steps(s) >= last + 48, "%s rests at least three bars after its phrase" % id)
	t.eq(ids.size(), 5, "each part of the day has its own Casalrana tune")

func test_the_story_can_change_the_music():
	var music := {"songs": {}, "parts": {"evening": "town_evening", "night": "town_night"},
		"when": [{"flag": "done", "parts": {}}, {"flag": "eve", "parts": {"evening": "carols"}}]}
	t.eq(AudioDirector.song_for("evening", false, music, {}), "town_evening", "the usual evening tune")
	t.eq(AudioDirector.song_for("evening", false, music, {"eve": true}), "carols", "a story flag swaps in its own")
	t.eq(AudioDirector.song_for("night", false, music, {"eve": true}), "town_night", "only for the parts it names")
	t.eq(AudioDirector.song_for("evening", false, music, {"eve": true, "done": true}), "town_evening", "and the first flag that's set wins: back to normal")
	t.eq(AudioDirector.song_for("evening", false, music), "town_evening", "without flags, as before")

func test_toriano_plays_its_own_city_pop():
	var lt: Dictionary = Data.island_def("metropolis")
	var m: Dictionary = lt.get("music", {})
	t.ok(not m.is_empty(), "Toriano brings its own music")
	for part in ["dawn", "morning", "afternoon", "evening", "night"]:
		var id := AudioDirector.song_for(part, false, m, {})
		t.ok(m.songs.has(id), "%s plays Toriano's own %s" % [part, id])
	t.eq(AudioDirector.song_for("evening", false, m, {"metropolis_christmas_eve": true}), "metropolis_xmas", "sleigh bells on Christmas Eve")
	t.eq(AudioDirector.song_for("night", false, m, {"metropolis_christmas_eve": true, "metropolis_angel_on": true}), "metropolis_finale", "the finale's own tune once the angel lights up")
	for id in m.songs:
		var s: Dictionary = m.songs[id]
		t.ok(s.chords.size() >= 4 and s.melody.size() >= 10 and s.bpm >= 60, "%s is a whole tune" % id)

func test_monteforchetta_plays_its_own_pop():
	# Monteforchetta's music (its map entry's "music"): its own tune for every part of the day and for building, on
	# instruments the synthesiser knows, with the drum and bass patterns of late-1990s Italian pop.
	var mf: Dictionary = Data.island_def("hearthglow").get("music", {})
	var ids := {}
	for part in ["dawn", "morning", "afternoon", "evening", "night"]:
		var id := AudioDirector.song_for(part, false, mf)
		t.ok(mf.songs.has(id), "Monteforchetta has its own %s tune (%s)" % [part, id])
		ids[id] = true
	t.eq(ids.size(), 5, "each part of the day has its own Monteforchetta tune")
	t.ok(mf.songs.has(AudioDirector.song_for("morning", true, mf)), "and its own building tune")
	for id in mf.songs:
		var s: Dictionary = mf.songs[id]
		var insts: Array = [s.lead, s.get("pad_inst", "pad"), s.get("bass_inst", "pluck")]
		if s.arp != "": insts.append(s.arp)
		for c in s.get("comp", []): insts.append(c.inst)
		t.ok(insts.all(func(i): return i in AudioDirector.INSTRUMENTS), "%s uses known instruments %s" % [id, insts])
		t.ok(s.drums in ["", "full", "light", "pop", "dance", "ballad"], "%s has a known drum pattern (%s)" % [id, s.drums])
		var last := -1; var sorted := true
		for m in s.melody:
			if int(m[0]) < last: sorted = false
			last = int(m[0])
		t.ok(sorted, "%s melody is in order" % id)
		var peak := 0.0
		for st in AudioDirector.loop_steps(s):
			var sum := 0.0
			for e in AudioDirector.step_events(s, st): sum += float(e[2])
			peak = maxf(peak, sum)
		t.ok(peak < 1.6, "%s never stacks too many loud notes on one step (%.2f)" % [id, peak])

func test_pop_patterns():
	var song := {"bpm": 120, "root": 60, "lead": "piano", "arp": "", "drums": "pop", "pad": 0.05, "bass_style": "eighths", "bass_inst": "bass",
		"comp": [{"inst": "guitar", "steps": [0, 3], "octave": 0, "vol": 0.1, "spread": 0.01}], "lift": 2,
		"chords": [[0, 4, 7]], "melody": [[0, 12]]}
	var kinds := func(st: int) -> Array: return AudioDirector.step_events(song, st).map(func(e): return e[0])
	t.ok(kinds.call(2).has("snare") and kinds.call(6).has("snare") and not kinds.call(4).has("snare"), "pop: the snare is on the backbeat")
	t.ok(kinds.call(0).has("kick") and kinds.call(1).has("hat") and kinds.call(1).has("bass"), "a kick on the beat, eighth-note hats and bass")
	var strum: Array = AudioDirector.step_events(song, 3).filter(func(e): return e[0] == "guitar")
	t.eq(strum.size(), 3, "the guitar strums the whole chord on its steps")
	t.ok(strum[2][3] > strum[0][3], "one string after another")
	t.eq(AudioDirector.step_events(song, 1, 1.0).filter(func(e): return e[0] in ["kick", "snare", "hat"]).size(), 0, "rain takes the drums away")
	var first: Array = AudioDirector.step_events(song, 0).filter(func(e): return e[0] == "piano")
	var second: Array = AudioDirector.step_events(song, AudioDirector.loop_steps(song)).filter(func(e): return e[0] == "piano")
	t.eq(int(second[0][1]) - int(first[0][1]), 2, "the second time round goes up a tone")
	song.drums = "dance"; song.bass_style = "offbeat"
	t.ok(kinds.call(0).has("kick") and kinds.call(2).has("kick") and kinds.call(2).has("clap") and kinds.call(1).has("openhat"), "dance: four on the floor, claps, open hats")
	t.ok(not kinds.call(0).has("bass") and kinds.call(1).has("bass"), "and the bass on the offbeat")
	# the shared tunes play as before: pad and a low pluck on the downbeat, the kick and shaker of "full"
	var old: Array = AudioDirector.step_events(AudioDirector.SONGS.hearthglow, 0).map(func(e): return e[0])
	t.ok(old.has("pad") and old.has("pluck") and old.has("kick"), "the shared tunes keep their parts")

func test_pop_instruments_play_in_tune():
	# Each pitched instrument sounds the note asked for: the strongest repeat in its waveform (autocorrelation), at
	# the rate it plays back at, is within a few cents of the note. The plucked guitar especially, whose loop length
	# would otherwise be rounded to whole samples.
	var ad = AudioDirector.new()
	for inst in ["guitar", "piano", "bass", "saw", "strings"]:
		for midi in [45, 62, 69, 81]:
			if inst == "bass" and midi > 62: continue
			var w: AudioStreamWAV = ad._gen(inst, midi)
			var n := mini(w.data.size() / 2, 6000)
			var x := PackedFloat32Array(); x.resize(n)
			for i in n: x[i] = w.data.decode_s16(i * 2) / 32000.0
			var want: float = AudioDirector.freq(midi)
			var lag_want: float = w.mix_rate / want
			var best := 0.0; var best_lag := 0
			for lag in range(int(lag_want * 0.9), int(lag_want * 1.1) + 2):
				var c := 0.0
				for i in range(400, n - lag): c += x[i] * x[i + lag]
				if c > best: best = c; best_lag = lag
			# refine between whole samples (parabola through the neighbours)
			var cm := 0.0; var cp := 0.0
			for i in range(400, n - best_lag - 1): cm += x[i] * x[i + best_lag - 1]; cp += x[i] * x[i + best_lag + 1]
			var den := cm - 2.0 * best + cp
			var lag_f: float = best_lag + (0.5 * (cm - cp) / den if absf(den) > 0.000001 else 0.0)
			var cents := 1200.0 * log(w.mix_rate / lag_f / want) / log(2.0)
			t.ok(absf(cents) < 12.0, "%s %d is in tune (%+.1f cents)" % [inst, midi, cents])
	ad.free()

func test_a_song_is_made_ready_before_it_plays():
	# Synthesising a piano or string note takes tens of milliseconds, so a song's notes are made on a worker thread
	# while the last tune fades out: once that's done, every note the song plays is ready.
	var ad = AudioDirector.new()
	ad.music = Data.island_def("hearthglow").get("music", {})
	ad._warm("hearthglow_evening")
	ad._warmed()
	var s: Dictionary = AudioDirector.song_def("hearthglow_evening", ad.music)
	var missing := 0
	for st in AudioDirector.loop_steps(s) * 2:   # twice: the evening tune comes round a tone higher
		for e in AudioDirector.step_events(s, st):
			if not ad.cache.has("%s:%d" % [e[0], e[1]]): missing += 1
	t.eq(missing, 0, "every note of the evening tune is ready, in both keys")
	t.eq(AudioDirector.synth("piano", 60).data, AudioDirector.synth("piano", 60).data, "a note comes out the same every time")
	ad.free()

## The dance hall's instruments, and bars of other lengths (a waltz's 3/4), for Boccapioppo's music; songs that don't
## say keep their 16-step bars.
func test_dance_hall_instruments_and_waltz_bars():
	for k in ["accordion", "clarinet", "upright"]:
		var w := AudioDirector.synth(k, 57)
		var peak := 0
		for i in range(0, w.data.size(), 2): peak = maxi(peak, absi(w.data.decode_s16(i)))
		t.ok(k in AudioDirector.INSTRUMENTS and peak > 3000, "the %s sounds (peak %d)" % [k, peak])
	var waltz := {"bpm": 150, "root": 60, "lead": "accordion", "arp": "", "drums": "", "pad": 0.0, "bar": 12, "bass_inst": "upright",
		"chords": [[0, 4, 7], [7, 11, 14]], "melody": [[0, 12]]}
	var bass := func(st: int) -> Array: return AudioDirector.step_events(waltz, st).filter(func(e): return e[0] == "upright")
	t.ok(bass.call(0).size() == 1 and bass.call(6).size() == 1 and bass.call(8).is_empty(), "a waltz's bass: on the first beat of each 3/4 bar")
	t.eq(int(bass.call(12)[0][1]), 60 + 7 - 24, "its chord changes every 12 steps")
	t.eq(AudioDirector.loop_steps(waltz), 12, "and it loops on whole bars")
	var hb: Array = AudioDirector.step_events(AudioDirector.SONGS.hearthglow, 8).filter(func(e): return e[0] == "pluck" and int(e[1]) < 60)
	t.eq(hb.size(), 1, "a 16-step song keeps its second bass note on step 8")

## The speakers are looked after: nothing reaches them above -1 dB (a limiter on the master bus, added once however
## often the scene reloads), and the scripts that start the game for playthroughs and screenshots start it without a
## sound card, since a playthrough runs many times faster than real time.
func test_the_speakers_are_looked_after():
	AudioDirector.limit_master(); AudioDirector.limit_master()
	var lims: Array = []
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter: lims.append(AudioServer.get_bus_effect(0, i))
	t.eq(lims.size(), 1, "one limiter on the master bus, however often the music starts")
	t.ok(lims.size() == 1 and lims[0].ceiling_db <= -1.0, "it keeps the sound below -1 dB")
	for sh in ["play.sh", "shot.sh", "lookdev.sh"]:
		var starts := 0
		for line in FileAccess.get_file_as_string("res://" + sh).split("\n"):
			if line.contains("xvfb-run") and not line.strip_edges().begins_with("#"):
				starts += 1
				t.ok(line.contains("--audio-driver Dummy"), "%s starts the game without a sound card" % sh)
		t.ok(starts > 0, "%s still starts the game" % sh)
