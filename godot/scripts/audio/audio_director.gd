extends Node
## Original procedural music and sound effects. Instrument notes are synthesised into small sample buffers
## the first time they are needed (no audio files): marimba, glockenspiel, ukulele-ish pluck, soft pad, kick, shaker.

const RATE := 22050
## Original tunes. Steps are eighth notes; chords are semitones above the root, one per bar of 16 steps; melody is
## [step, semitone]. lead/arp name the instruments; arp_every is how often (in steps) the arpeggio plays; drums is
## "full", "light" (shaker only) or "" (none).
const SONGS := {
	"dawn": {"bpm": 74, "root": 62, "lead": "flute", "arp": "glock", "arp_every": 4, "drums": "", "pad": 0.11,
		"chords": [[0, 4, 7, 11], [9, 12, 16], [5, 9, 12, 16], [7, 12, 14]],
		"melody": [[0, 16], [4, 14], [6, 12], [8, 11], [16, 9], [20, 12], [24, 14], [32, 17], [36, 16], [38, 14], [40, 12], [48, 11], [52, 9], [56, 7]]},
	"hearthglow": {"bpm": 96, "root": 65, "lead": "marimba", "arp": "marimba", "arp_every": 2, "drums": "full", "pad": 0.08,
		"chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14], [0, 4, 7], [2, 5, 9], [5, 9, 12], [7, 11, 14]],
		"melody": [[0, 7], [2, 9], [4, 12], [6, 11], [8, 9], [12, 7], [16, 9], [18, 12], [20, 16], [24, 14], [28, 12], [32, 5], [34, 9], [36, 12], [38, 14], [40, 12], [44, 9], [48, 7], [50, 11], [52, 14], [56, 12], [60, 11], [64, 7], [66, 9], [68, 12], [70, 11], [72, 9], [76, 7], [80, 2], [82, 5], [84, 9], [88, 7], [92, 5], [96, 5], [98, 9], [100, 12], [102, 14], [104, 16], [108, 14], [112, 11], [114, 14], [116, 12], [120, 7]]},
	"afternoon": {"bpm": 112, "root": 67, "lead": "marimba", "arp": "pluck", "arp_every": 1, "drums": "full", "pad": 0.06,
		"chords": [[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12], [0, 4, 7], [2, 5, 9], [7, 11, 14], [0, 4, 7]],
		"melody": [[0, 12], [2, 14], [4, 16], [6, 19], [8, 16], [12, 14], [16, 11], [18, 12], [20, 14], [24, 11], [28, 7], [32, 9], [34, 12], [36, 16], [40, 14], [44, 12], [48, 9], [52, 12], [56, 14], [60, 12],
			[64, 12], [66, 16], [68, 19], [70, 21], [72, 19], [76, 16], [80, 14], [82, 12], [84, 14], [88, 17], [92, 14], [96, 16], [98, 14], [100, 12], [104, 11], [108, 14], [112, 12], [120, 7]]},
	"evening": {"bpm": 84, "root": 63, "lead": "rhodes", "arp": "pluck", "arp_every": 2, "drums": "light", "pad": 0.1,
		"chords": [[0, 4, 7, 11], [4, 7, 11, 14], [9, 12, 16, 19], [5, 9, 12, 16], [2, 5, 9, 12], [7, 11, 14, 17], [0, 4, 7, 11], [5, 9, 12, 16]],
		"melody": [[0, 14], [3, 12], [4, 11], [8, 7], [12, 9], [16, 11], [19, 12], [20, 14], [24, 16], [32, 17], [35, 16], [36, 14], [40, 12], [48, 11], [52, 9], [56, 7],
			[64, 12], [67, 14], [68, 16], [72, 19], [80, 17], [84, 16], [88, 14], [96, 12], [100, 11], [104, 9], [112, 7], [120, 4]]},
	"night": {"bpm": 72, "root": 60, "lead": "marimba", "arp": "glock", "arp_every": 4, "drums": "", "pad": 0.12,
		"chords": [[0, 4, 7, 11], [9, 12, 16], [5, 9, 12, 16], [7, 11, 14, 17]],
		"melody": [[0, 16], [6, 14], [8, 12], [16, 11], [24, 12], [32, 9], [38, 12], [40, 16], [48, 14], [56, 11]]},
	"build": {"bpm": 104, "root": 67, "lead": "glock", "arp": "marimba", "arp_every": 2, "drums": "full", "pad": 0.08,
		"chords": [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
		"melody": [[0, 12], [2, 16], [4, 19], [8, 17], [12, 16], [16, 14], [18, 17], [20, 21], [24, 19], [28, 17], [32, 16], [36, 12], [40, 14], [44, 16], [48, 19], [56, 24]]},
}
## Which tune plays in each part of the day (Daylight.part_of_day).
const DAY_SONGS := {"dawn": "dawn", "morning": "hearthglow", "afternoon": "afternoon", "evening": "evening", "night": "night"}
const INSTRUMENTS := ["marimba", "glock", "pluck", "pad", "kick", "hat", "blip", "chirp", "hiss", "thud", "flute", "rhodes"]

var cache := {}
var pool: Array = []
var next_player := 0
var song := "hearthglow"
var gain := 1.0          # music fade: crossfades between songs go through silence over a couple of seconds
var want_song := "hearthglow"
var soft := 0.0          # 0..1: rain makes the music gentler (no drums, quieter lead)
var step := 0
var song_time := 0.0
var next_step_time := 0.0
var amb_t := 1.0
var music_bus := 0
var sfx_bus := 0

func _ready() -> void:
	music_bus = _bus("Music"); sfx_bus = _bus("SFX")
	for i in 28:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)

func _bus(name: String) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus(); idx = AudioServer.bus_count - 1; AudioServer.set_bus_name(idx, name); AudioServer.set_bus_send(idx, "Master")
	return idx

func set_volumes(music: float, sfx_v: float) -> void:
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(0.0001, music * 0.55)))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(0.0001, sfx_v * 0.8)))

static func freq(midi: float) -> float: return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

func _gen(kind: String, midi: int) -> AudioStreamWAV:
	var key := "%s:%d" % [kind, midi]
	if cache.has(key): return cache[key]
	var f := freq(midi)
	var length: float = {"marimba": 0.6, "glock": 1.2, "pluck": 0.45, "pad": 2.4, "kick": 0.25, "hat": 0.06, "blip": 0.09, "hiss": 1.6, "chirp": 0.07, "thud": 0.3, "flute": 0.9, "rhodes": 1.4}.get(kind, 0.5)
	var n := int(RATE * length)
	var data := PackedByteArray(); data.resize(n * 2)
	var lp := 0.0
	var prev := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"marimba": v = sin(TAU * f * t) * exp(-t * 7.0) + 0.25 * sin(TAU * f * 4.0 * t) * exp(-t * 40.0)
			"glock": v = 0.7 * sin(TAU * f * t) * exp(-t * 2.6) + 0.25 * sin(TAU * f * 2.76 * t) * exp(-t * 9.0)
			"pluck":
				var tri := 2.0 * absf(2.0 * fmod(f * t, 1.0) - 1.0) - 1.0
				lp += (tri - lp) * (0.35 * exp(-t * 6.0) + 0.05)
				v = lp * exp(-t * 6.5)
			"pad":
				var saw := (fmod(f * t, 1.0) * 2.0 - 1.0) * 0.5 + (fmod(f * 1.004 * t, 1.0) * 2.0 - 1.0) * 0.5
				lp += (saw - lp) * 0.08
				var env := minf(1.0, t / 0.6) * minf(1.0, (length - t) / 0.9)
				v = lp * env * 0.6
			"kick":
				phase += TAU * (45.0 + 95.0 * exp(-t * 18.0)) / RATE
				v = sin(phase) * exp(-t * 14.0)
			"hat":
				var nz := randf() * 2.0 - 1.0
				v = (nz - prev) * exp(-t * 60.0) * 0.6; prev = nz
			"blip":
				var sq := 1.0 if fmod(f * t * (1.0 + t * 1.5), 1.0) < 0.5 else -1.0
				lp += (sq - lp) * 0.25
				v = lp * minf(1.0, t / 0.005) * exp(-t * 22.0) * 0.5
			"chirp": v = sin(TAU * f * t * (1.0 + t * 6.0)) * sin(PI * t / length) * 0.5
			"hiss":
				lp += ((randf() * 2.0 - 1.0) - lp) * 0.06
				v = lp * minf(1.0, t / 0.2) * minf(1.0, (length - t) / 0.8) * 1.5
			"thud":
				lp += ((randf() * 2.0 - 1.0) - lp) * 0.12
				v = (lp * 1.6 + sin(TAU * 110.0 * t) * 0.5) * exp(-t * 14.0)
			"flute":
				# soft, breathy, with a gentle vibrato that comes in after the attack
				var vib := 1.0 + 0.006 * sin(TAU * 5.4 * t) * minf(1.0, t / 0.25)
				phase += TAU * f * vib / RATE
				lp += ((randf() * 2.0 - 1.0) - lp) * 0.05
				var envf := minf(1.0, t / 0.07) * minf(1.0, (length - t) / 0.3)
				v = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.12 + lp * 0.18) * envf * 0.7
			"rhodes":
				# electric-piano-ish: warm body, a bell-like overtone and a quick tine
				v = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 3.0) + 0.18 * sin(TAU * f * 7.0 * t) * exp(-t * 28.0)) * exp(-t * 2.4) * 0.55
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	cache[key] = w
	return w

func play(kind: String, midi: int, vol: float = 0.5, bus: int = -1, delay: float = 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func(): play(kind, midi, vol, bus))
		return
	var p: AudioStreamPlayer = pool[next_player]; next_player = (next_player + 1) % pool.size()
	p.stream = _gen(kind, midi)
	p.volume_db = linear_to_db(maxf(0.0001, vol))
	p.bus = AudioServer.get_bus_name(bus if bus >= 0 else sfx_bus)
	p.play()

func update_music(game, dt: float) -> void:
	var part := Daylight.part_of_day(float(game.state.time.minute) / 60.0)
	want_song = "build" if game.mode == "build" else DAY_SONGS.get(part, "hearthglow")
	soft = lerpf(soft, clampf(game.weather_now.get("rain", 0.0) * 1.4, 0.0, 1.0), 1.0 - exp(-dt * 0.5))
	# crossfade: fade the current tune out, switch while silent, fade the new one in
	if want_song != song:
		gain = maxf(0.0, gain - dt / 1.6)
		if gain <= 0.0: song = want_song; step = 0; next_step_time = song_time
	else:
		gain = minf(1.0, gain + dt / 3.0)
	song_time += dt
	var s: Dictionary = SONGS[song]
	var step_dur: float = 60.0 / s.bpm / 2.0
	var guard := 0
	while next_step_time <= song_time and guard < 8:
		guard += 1
		if gain > 0.01: _music_step(s)
		step += 1; next_step_time += step_dur
	amb_t -= dt
	if amb_t < 0.0:
		amb_t = 0.8 + randf() * 2.5
		if game.state.flags.get("night", false):
			for i in 3: play("chirp", 100, 0.06, sfx_bus, i * 0.07)
		elif randf() < 0.7:
			var base := 93 + randi() % 6
			for i in 2 + randi() % 3: play("chirp", base + (i % 2) * 3, 0.1, sfx_bus, i * 0.09)
		var p: Vector3 = game.player.pos
		var river := maxf(0.0, 1.0 - (absf(p.z - Heightfield.river_center(p.x)) - 3.0) / 8.0)
		if river > 0.05: play("hiss", 60, 0.15 * river)
		var wet: float = game.weather_now.get("rain", 0.0)
		if wet > 0.05: play("hiss", 70, 0.3 * wet)

func _music_step(s: Dictionary) -> void:
	var beat := step % 16
	var bar: int = int(step / 16) % s.chords.size()
	var chord: Array = s.chords[bar]
	var R: int = s.root
	var g := gain
	if beat == 0:
		for nn in chord: play("pad", R + int(nn) - 12, s.pad * g, music_bus)
		play("pluck", R + int(chord[0]) - 24, 0.4 * g, music_bus)
	if beat == 8: play("pluck", R + int(chord[2]) - 24, 0.3 * g, music_bus)
	var every: int = s.arp_every
	if s.arp != "" and beat % every == 0:
		var idx: int = int(beat / every) % chord.size()
		var octave := 12 if s.arp == "glock" else (0 if beat % 4 else -12)
		var av: float = {"glock": 0.15, "pluck": 0.16, "marimba": 0.22}.get(s.arp, 0.18)
		play(s.arp, R + int(chord[idx]) + octave, av * g * lerpf(1.0, 0.7, soft), music_bus)
	var drums: String = s.drums if soft < 0.5 else ""
	if drums == "full":
		if beat % 4 == 2: play("hat", 60, 0.12 * g, music_bus)
		if beat == 0 or beat == 10: play("kick", 40, 0.35 * g, music_bus)
	elif drums == "light" and beat % 4 == 2: play("hat", 60, 0.08 * g, music_bus)
	var last := 0
	for m in s.melody: last = maxi(last, int(m[0]))
	var loop: int = int(ceil((last + 8) / 16.0)) * 16
	var ms := step % loop
	var lv: float = {"glock": 0.25, "flute": 0.3, "rhodes": 0.32}.get(s.lead, 0.4)
	for m in s.melody:
		if int(m[0]) == ms: play(s.lead, R + int(m[1]), lv * g * lerpf(1.0, 0.75, soft), music_bus)

func sfx(name: String) -> void:
	var arp := func(notes: Array, gap: float, inst: String = "glock", vol: float = 0.45):
		for i in notes.size(): play(inst, notes[i], vol, sfx_bus, i * gap)
	match name:
		"place": arp.call([72, 76, 79, 84], 0.05); play("hiss", 80, 0.12)
		"remove": play("thud", 60, 0.4); play("marimba", 60, 0.3, sfx_bus, 0.06)
		"collect": arp.call([79, 86], 0.07, "marimba", 0.5)
		"sparkle": arp.call([84, 88, 91, 96], 0.04, "glock", 0.35)
		"objective": arp.call([76, 83], 0.08, "glock", 0.45)
		"accept": arp.call([67, 72, 76], 0.09, "marimba", 0.55)
		"fanfare":
			arp.call([60, 64, 67, 72, 76, 79, 84], 0.08, "marimba", 0.6)
			for nn in [60, 64, 67, 72]: play("pad", nn, 0.15, sfx_bus, 0.5)
		"fanfare_small": arp.call([72, 76, 79, 84], 0.07, "marimba", 0.5)
		"unlock": arp.call([72, 79, 84, 88, 91], 0.06, "glock", 0.4)
		"error": play("blip", 45, 0.35); play("blip", 42, 0.3, sfx_bus, 0.1)
		"select", "tick", "blip": play("blip", 84 if name == "blip" else 88, 0.2)
		"open": arp.call([67, 74], 0.05, "marimba", 0.3)
		"close": arp.call([74, 67], 0.05, "marimba", 0.25)
		"chest": arp.call([72, 76, 79, 84, 88], 0.06, "glock", 0.45); play("thud", 50, 0.3)
		"hit": play("thud", 55, 0.6); play("marimba", 57, 0.3)
		"perfect": play("thud", 55, 0.6); arp.call([84, 91], 0.05, "glock", 0.4)
		"miss": play("marimba", 48, 0.3)
		"cast": play("hiss", 75, 0.3)
		"bite": play("blip", 72, 0.4); play("blip", 79, 0.35, sfx_bus, 0.08)
		"dig", "rustle": play("thud", 50, 0.45)
		"pick": play("marimba", 81, 0.3)
		"water": play("hiss", 85, 0.35)
		"squeak": play("chirp", 98, 0.3); play("chirp", 102, 0.25, sfx_bus, 0.07)
		"door": play("thud", 45, 0.35)
		"lever": play("blip", 67, 0.3); play("thud", 60, 0.25)
		"paint": arp.call([88, 91, 95], 0.03, "glock", 0.25)
		"undo": play("blip", 76, 0.2); play("blip", 81, 0.15, sfx_bus, 0.05)
		"gate": play("pad", 38, 0.3); arp.call([60, 67, 72], 0.2, "marimba", 0.55)
		"sail": play("hiss", 55, 0.35); arp.call([67, 71, 74, 79], 0.15, "marimba", 0.5)
		"morning": arp.call([72, 76, 79], 0.12, "glock", 0.35)
		"save": arp.call([79, 84], 0.06, "glock", 0.3)

## Cartoon "babble": short pitched syllables.
func voice(pitch: float, syllables: int) -> void:
	var base := 64 + int(round(12.0 * log(maxf(0.3, pitch)) / log(2.0)))
	for i in syllables: play("blip", base + randi() % 5 - 2, 0.28, sfx_bus, i * 0.085)
