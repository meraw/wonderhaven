extends Node
## Original procedural music and sound effects. Instrument notes are synthesised into small sample buffers
## the first time they are needed (no audio files): marimba, glockenspiel, ukulele-ish pluck, soft pad, kick, shaker.

const RATE := 22050
const SONGS := {
	"hearthglow": {"bpm": 96, "root": 65,
		"chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14], [0, 4, 7], [2, 5, 9], [5, 9, 12], [7, 11, 14]],
		"melody": [[0, 7], [2, 9], [4, 12], [6, 11], [8, 9], [12, 7], [16, 9], [18, 12], [20, 16], [24, 14], [28, 12], [32, 5], [34, 9], [36, 12], [38, 14], [40, 12], [44, 9], [48, 7], [50, 11], [52, 14], [56, 12], [60, 11], [64, 7], [66, 9], [68, 12], [70, 11], [72, 9], [76, 7], [80, 2], [82, 5], [84, 9], [88, 7], [92, 5], [96, 5], [98, 9], [100, 12], [102, 14], [104, 16], [108, 14], [112, 11], [114, 14], [116, 12], [120, 7]]},
	"night": {"bpm": 72, "root": 60, "chords": [[0, 4, 7, 11], [9, 12, 16], [5, 9, 12, 16], [7, 11, 14, 17]],
		"melody": [[0, 16], [6, 14], [8, 12], [16, 11], [24, 12], [32, 9], [38, 12], [40, 16], [48, 14], [56, 11]]},
	"build": {"bpm": 104, "root": 67, "chords": [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
		"melody": [[0, 12], [2, 16], [4, 19], [8, 17], [12, 16], [16, 14], [18, 17], [20, 21], [24, 19], [28, 17], [32, 16], [36, 12], [40, 14], [44, 16], [48, 19], [56, 24]]},
}

var cache := {}
var pool: Array = []
var next_player := 0
var song := "hearthglow"
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
	var length: float = {"marimba": 0.6, "glock": 1.2, "pluck": 0.45, "pad": 2.4, "kick": 0.25, "hat": 0.06, "blip": 0.09, "hiss": 1.6, "chirp": 0.07, "thud": 0.3}.get(kind, 0.5)
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
	var want := "build" if game.mode == "build" else ("night" if game.state.flags.get("night", false) else "hearthglow")
	if want != song: song = want; step = 0; next_step_time = song_time
	song_time += dt
	var s: Dictionary = SONGS[song]
	var step_dur: float = 60.0 / s.bpm / 2.0
	var guard := 0
	while next_step_time <= song_time and guard < 8:
		guard += 1
		_music_step(s)
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
		if game.rain.emitting: play("hiss", 70, 0.25)

func _music_step(s: Dictionary) -> void:
	var beat := step % 16
	var bar: int = int(step / 16) % s.chords.size()
	var chord: Array = s.chords[bar]
	var R: int = s.root
	if beat == 0:
		for nn in chord: play("pad", R + int(nn) - 12, 0.12 if song == "night" else 0.08, music_bus)
		play("pluck", R + int(chord[0]) - 24, 0.4, music_bus)
	if beat == 8: play("pluck", R + int(chord[2]) - 24, 0.3, music_bus)
	if song != "night":
		if beat % 2 == 0: play("marimba", R + int(chord[(beat / 2) % chord.size()]) - (0 if beat % 4 else 12), 0.22, music_bus)
		if beat % 4 == 2: play("hat", 60, 0.12, music_bus)
		if beat == 0 or beat == 10: play("kick", 40, 0.35, music_bus)
	elif beat % 4 == 0: play("glock", R + int(chord[(beat / 4) % chord.size()]) + 12, 0.15, music_bus)
	var last := 0
	for m in s.melody: last = maxi(last, int(m[0]))
	var loop: int = int(ceil((last + 8) / 16.0)) * 16
	var ms := step % loop
	for m in s.melody:
		if int(m[0]) == ms: play("glock" if song == "build" else "marimba", R + int(m[1]), 0.25 if song == "build" else 0.4, music_bus)

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
