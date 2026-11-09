extends Node
## Original procedural music and sound effects. Instrument notes are synthesised into small sample buffers
## the first time they are needed (no audio files): marimba, glockenspiel, ukulele-ish pluck, soft pad, kick, shaker,
## and for pop: a plucked guitar, piano, synth bass, a bright saw lead, strings, snare, handclap and open hi-hat; and
## for the dance hall: an accordion, a clarinet and a plucked double bass.

const RATE := 22050
## Original tunes. Steps are eighth notes; chords are semitones above the root, one per bar of 16 steps; melody is
## [step, semitone]. lead/arp name the instruments; arp_every is how often (in steps) the arpeggio plays; drums is
## "full", "light" (shaker only), "pop" (kick, snare on the backbeat, eighth-note hats), "dance" (a kick on every beat,
## claps on the backbeat, open hats on the offbeats), "ballad" (a half-time backbeat) or "" (none). Optional: length
## (steps before the melody repeats, so a phrase can be followed by silence), bass (volume of the low notes, 1 by
## default), bass_style ("" root and fifth, "eighths", "quarters" or "offbeat"), bass_inst (default "pluck"),
## pad_every (bars between pad chords, 1), pad_inst (default "pad"), comp ([{inst, steps, octave, vol, spread}]:
## chords struck on those steps of each bar, notes spread by that many seconds, a strummed guitar say) and lift
## (semitones the whole song goes up every second time round: the pop key change), lead_vol (the melody's volume, 1),
## bar (steps in a bar, 16 by default: 12 is two bars of a waltz in 3/4, with the second bass note on its step 6).
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

## A location can bring its own music: "music" in its map entry (islands.json or a pack's location.json), as
## {"songs": {id: song}, "parts": {part of the day or "build": song id}}. Its songs have the shape of SONGS; a part
## it leaves out keeps the shared tune. "when": [{flag, parts}] lets the story change them: the first entry whose
## flag is set swaps in its parts (sleigh bells on Christmas Eve, a finale's own tune); an empty parts goes back.
static func song_for(part: String, building: bool, music: Dictionary, flags: Dictionary = {}, festa: bool = false) -> String:
	var parts: Dictionary = music.get("parts", {})
	for w in music.get("when", []):
		if flags.get(String(w.get("flag", "")), false):
			parts = parts.merged(w.get("parts", {}), true)
			break
	if building: return String(parts.get("build", "build"))
	if festa and parts.has("gathering"): return String(parts.gathering)
	return String(parts.get(part, DAY_SONGS.get(part, "hearthglow")))

## A song by id: the location's own first, then the shared ones.
static func song_def(id: String, music: Dictionary) -> Dictionary:
	var own: Dictionary = music.get("songs", {})
	return own[id] if own.has(id) else SONGS.get(id, SONGS.hearthglow)

## Steps before a song's melody repeats.
static func loop_steps(s: Dictionary) -> int:
	var last := 0
	for m in s.melody: last = maxi(last, int(m[0]))
	var bl := int(s.get("bar", 16))
	return maxi(int(s.get("length", 0)), int(ceil((last + 8) / float(bl))) * bl)
const INSTRUMENTS := ["marimba", "glock", "pluck", "pad", "kick", "hat", "blip", "chirp", "hiss", "thud", "flute", "rhodes", "bell", "horn", "rasp", "whistle",
	"guitar", "piano", "bass", "saw", "strings", "snare", "clap", "openhat", "accordion", "clarinet", "upright", "cluck", "bawk", "purr",
	"mandolin", "brass", "tuba"]
## Sounds of a place, for its location code (play(kind, note, volume)): "bell" a church bell with its hum and minor
## third, ringing long; "horn" a reedy horn (two at once make a train's two-tone horn); "rasp" a harsh, falling croak;
## "whistle" a note that slides up and back (a bird's call).

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
var bird_t := 4.0        # seconds to the next birdsong
var last_call := -1      # the last bird's call (BIRD_CALLS), so the same one never sings twice running
var hen_t := 2.0         # seconds to the next cluck from the nearest chicken
var music: Dictionary = {}   # the location's own music ("music" in its map entry)
var music_island := ""
var music_bus := 0
var sfx_bus := 0
var warm_song := ""      # the song whose notes are being made ready in the background
var warm_task := -1
var warm_out := {}       # filled by the worker thread, merged into the cache once it's done

func _ready() -> void:
	music_bus = _bus("Music"); sfx_bus = _bus("SFX")
	limit_master()
	for i in 40:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)

## Nothing reaches the speakers above -1 dB: a limiter on the master bus catches the rare moment when many notes peak
## together (a quest's fanfare over the music with both volumes turned right up), where the sound card would
## otherwise clip it. Normal play peaks well below it, so it doesn't change the sound. Once: the buses outlive the scene.
static func limit_master() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter: return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)

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
	if not cache.has(key): cache[key] = synth(kind, midi)
	return cache[key]

## One note of an instrument, synthesised. Static and with its own random numbers, so songs can be made ready on a
## worker thread (see _warm) while the last tune fades out.
static func synth(kind: String, midi: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("%s:%d" % [kind, midi])
	var f := freq(midi)
	var length: float = {"marimba": 0.6, "glock": 1.2, "pluck": 0.45, "pad": 2.4, "kick": 0.25, "hat": 0.06, "blip": 0.09, "hiss": 1.6, "chirp": 0.07, "cluck": 0.13, "bawk": 0.34, "purr": 0.9, "thud": 0.3, "flute": 0.9, "rhodes": 1.4,
		"bell": 3.6, "horn": 0.9, "rasp": 0.4, "whistle": 0.36, "guitar": 1.3, "piano": 1.6, "bass": 0.45, "saw": 0.42, "strings": 2.6, "snare": 0.22,
		"clap": 0.2, "openhat": 0.3, "accordion": 0.8, "clarinet": 0.9, "upright": 0.7, "mandolin": 0.9, "brass": 0.8, "tuba": 0.6}.get(kind, 0.5)
	var n := int(RATE * length)
	var data := PackedByteArray(); data.resize(n * 2)
	var lp := 0.0
	var prev := 0.0
	var phase := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	# a plucked string (Karplus-Strong): a burst of soft noise circulating in a delay line one period long
	var ks := PackedFloat32Array(); var ks_i := 0
	var play_rate := RATE
	if kind == "guitar":
		# the loop is whole samples long, less half a sample for averaging each sample with the next, so play the note
		# back at the rate that puts it exactly in tune
		var period := maxi(2, int(round(RATE / f + 0.5)))
		ks.resize(period)
		play_rate = int(round(f * (period - 0.5)))
		var sm := 0.0
		for j in ks.size(): sm += ((rng.randf() * 2.0 - 1.0) - sm) * 0.55; ks[j] = sm
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
				var nz := rng.randf() * 2.0 - 1.0
				v = (nz - prev) * exp(-t * 60.0) * 0.6; prev = nz
			"blip":
				var sq := 1.0 if fmod(f * t * (1.0 + t * 1.5), 1.0) < 0.5 else -1.0
				lp += (sq - lp) * 0.25
				v = lp * minf(1.0, t / 0.005) * exp(-t * 22.0) * 0.5
			"chirp": v = sin(TAU * f * t * (1.0 + t * 6.0)) * sin(PI * t / length) * 0.5
			"cluck", "bawk":
				# a hen: a nasal, buzzy pulse (narrow pulse wave through a soft filter, with breath), its pitch falling for
				# a cluck, rising then falling for the long "bawk"
				var bend := (1.25 - 0.45 * t / length) if kind == "cluck" else (0.9 + 0.5 * sin(PI * minf(1.0, t / length * 1.3)))
				phase += f * bend / RATE
				var pulse := 1.0 if fmod(phase, 1.0) < 0.22 else -0.28
				lp += ((pulse + (rng.randf() * 2.0 - 1.0) * 0.35) - lp) * 0.32
				prev += (lp - prev) * 0.5
				var envc := minf(1.0, t / 0.008) * (exp(-t * 18.0) if kind == "cluck" else minf(1.0, (length - t) / 0.12))
				v = prev * envc * 0.8
			"purr":
				# a cat's purr: low breathy noise pulsing about 26 times a second
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.04
				var throb := 0.5 + 0.5 * sin(TAU * 26.0 * t)
				v = (lp * 2.4 + sin(TAU * f * t) * 0.15) * throb * throb * minf(1.0, t / 0.1) * minf(1.0, (length - t) / 0.25) * 0.8
			"hiss":
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.06
				v = lp * minf(1.0, t / 0.2) * minf(1.0, (length - t) / 0.8) * 1.5
			"thud":
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.12
				v = (lp * 1.6 + sin(TAU * 110.0 * t) * 0.5) * exp(-t * 14.0)
			"flute":
				# soft, breathy, with a gentle vibrato that comes in after the attack
				var vib := 1.0 + 0.006 * sin(TAU * 5.4 * t) * minf(1.0, t / 0.25)
				phase += TAU * f * vib / RATE
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.05
				var envf := minf(1.0, t / 0.07) * minf(1.0, (length - t) / 0.3)
				v = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.12 + lp * 0.18) * envf * 0.7
			"rhodes":
				# electric-piano-ish: warm body, a bell-like overtone and a quick tine
				v = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 3.0) + 0.18 * sin(TAU * f * 7.0 * t) * exp(-t * 28.0)) * exp(-t * 2.4) * 0.55
			"bell":
				# a cast bell's partials: the hum an octave down, the strike note, a minor third, a fifth, the octave
				# and a bright nominal, each dying away at its own pace
				v = (0.5 * sin(TAU * f * 0.5 * t) * exp(-t * 0.6) + 0.6 * sin(TAU * f * t) * exp(-t * 1.1) + 0.35 * sin(TAU * f * 1.19 * t) * exp(-t * 1.4)
					+ 0.25 * sin(TAU * f * 1.5 * t) * exp(-t * 2.0) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 2.6) + 0.18 * sin(TAU * f * 2.74 * t) * exp(-t * 4.5)) * minf(1.0, t / 0.004) * 0.6
			"horn":
				# reedy: a square and a slightly sharp square through a soft filter, held, with a short swell and release
				var sq1 := 1.0 if fmod(f * t, 1.0) < 0.5 else -1.0
				var sq2 := 1.0 if fmod(f * 1.006 * t, 1.0) < 0.5 else -1.0
				lp += ((sq1 + sq2) * 0.5 - lp) * 0.12
				v = lp * minf(1.0, t / 0.04) * minf(1.0, (length - t) / 0.15) * 0.45
			"rasp":
				# a harsh croak: a falling sawtooth roughened by noise
				var saw2 := fmod(f * (1.0 - 0.25 * t / length) * t, 1.0) * 2.0 - 1.0
				lp += ((saw2 * (0.55 + 0.45 * rng.randf())) - lp) * 0.3
				v = lp * minf(1.0, t / 0.02) * pow(1.0 - t / length, 1.5) * 0.7
			"whistle":
				# a pure note sliding up and back down
				phase += TAU * f * (1.0 + 0.3 * sin(PI * t / length)) / RATE
				v = sin(phase) * sin(PI * t / length) * 0.5
			"guitar":
				var cur := ks[ks_i]; var nxt := ks[(ks_i + 1) % ks.size()]
				ks[ks_i] = (cur + nxt) * 0.5 * 0.995
				ks_i = (ks_i + 1) % ks.size()
				v = cur * 0.75 * minf(1.0, (length - t) / 0.1)
			"piano":
				# struck strings: partials a touch sharp of true harmonics, the high ones dying first, and a hammer knock
				v = 0.0
				for h in range(1, 7):
					v += sin(TAU * f * h * (1.0 + 0.0004 * h * h) * t) * exp(-t * (1.6 + h * 1.1)) / pow(h, 1.15)
				v = (v * 0.42 + (rng.randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.12) * minf(1.0, t / 0.003) * minf(1.0, (length - t) / 0.2)
			"bass":
				# synth bass: a sawtooth through a two-pole filter that closes after the attack
				var saw := fmod(f * t, 1.0) * 2.0 - 1.0
				var cut := 0.035 + 0.22 * exp(-t * 14.0)
				lp += (saw - lp) * cut; prev += (lp - prev) * cut
				v = prev * minf(1.0, t / 0.004) * (0.6 + 0.4 * exp(-t * 5.0)) * minf(1.0, (length - t) / 0.05) * 1.3
			"saw":
				# a bright lead: two detuned saws with a little vibrato, through a soft filter
				var vb := 1.0 + 0.004 * sin(TAU * 5.5 * t) * minf(1.0, t / 0.2)
				phase += f * vb / RATE; ph2 += f * 1.006 * vb / RATE
				lp += ((fmod(phase, 1.0) + fmod(ph2, 1.0) - 1.0) - lp) * 0.2
				v = lp * minf(1.0, t / 0.01) * (0.65 + 0.35 * exp(-t * 6.0)) * minf(1.0, (length - t) / 0.08) * 0.55
			"strings":
				# an ensemble: three detuned saws, a slow swell, a gentle vibrato
				var vs := 1.0 + 0.003 * sin(TAU * 5.0 * t)
				phase += f * vs / RATE; ph2 += f * 1.005 * vs / RATE; ph3 += f * 0.996 * vs / RATE
				lp += ((fmod(phase, 1.0) + fmod(ph2, 1.0) + fmod(ph3, 1.0) - 1.5) / 1.5 - lp) * 0.07
				v = lp * minf(1.0, t / 0.4) * minf(1.0, (length - t) / 0.8) * 0.7
			"snare":
				var nz2 := rng.randf() * 2.0 - 1.0
				lp += (nz2 - lp) * 0.35
				v = ((nz2 - lp) * exp(-t * 20.0) * 0.9 + sin(TAU * 190.0 * t) * exp(-t * 35.0) * 0.5) * 0.8
			"clap":
				# three quick slaps and a short tail, in bright noise
				var nz3 := rng.randf() * 2.0 - 1.0
				lp += (nz3 - lp) * 0.4
				var ce := 0.0
				for k in 3: if t >= k * 0.011: ce += exp(-(t - k * 0.011) * 160.0)
				ce += exp(-maxf(0.0, t - 0.022) * 22.0) * 0.45 * float(t >= 0.022)
				v = (nz3 - lp) * ce * 0.8
			"openhat":
				var nz4 := rng.randf() * 2.0 - 1.0
				v = (nz4 - prev) * exp(-t * 13.0) * 0.4; prev = nz4
			"accordion":
				# two reeds a little apart (the musette's wobble) and one an octave down, through a soft filter, with the
				# bellows' push at the start
				var r1 := 0.68 if fmod(f * t, 1.0) < 0.32 else -0.32
				var r2 := 0.68 if fmod(f * 1.0055 * t, 1.0) < 0.32 else -0.32
				var r3 := 0.6 if fmod(f * 0.5 * t, 1.0) < 0.4 else -0.4
				lp += ((r1 + r2) * 0.5 + r3 * 0.3 - lp) * 0.22
				v = lp * minf(1.0, t / 0.05) * (0.85 + 0.15 * minf(1.0, t / 0.3)) * minf(1.0, (length - t) / 0.12) * 0.9
			"clarinet":
				# woody: odd harmonics only, a breath of air, and a vibrato that comes in after the attack
				var vbc := 1.0 + 0.005 * sin(TAU * 5.0 * t) * minf(1.0, t / 0.3)
				phase += TAU * f * vbc / RATE
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.04
				v = ((sin(phase) + 0.33 * sin(3.0 * phase) + 0.17 * sin(5.0 * phase) + 0.07 * sin(7.0 * phase)) * 0.5 + lp * 0.08) * minf(1.0, t / 0.06) * minf(1.0, (length - t) / 0.25) * 0.65
			"upright":
				# a plucked double bass: a round fundamental, overtones that die quickly, and the thump of the finger
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.1
				v = ((sin(TAU * f * t) + 0.45 * sin(TAU * 2.0 * f * t) * exp(-t * 6.0) + 0.2 * sin(TAU * 3.0 * f * t) * exp(-t * 12.0)) * exp(-t * 3.2) * 0.75
					+ lp * exp(-t * 60.0) * 0.3) * minf(1.0, t / 0.006) * minf(1.0, (length - t) / 0.08)
			"mandolin":
				var tick := fmod(t, 1.0 / 12.5)
				var stroke := exp(-tick * 22.0) * (0.55 + 0.45 * exp(-t * 2.5))
				var body := 0.0
				for h in range(1, 7):
					var fade := exp(-tick * h * 6.0)
					body += (sin(TAU * f * h * t) + sin(TAU * f * 1.003 * h * t)) * fade / pow(h, 1.3)
				v = body * stroke * minf(1.0, t / 0.002) * minf(1.0, (length - t) / 0.1) * 0.22
			"brass":
				var vbb := 1.0 + 0.004 * sin(TAU * 5.2 * t) * minf(1.0, t / 0.25)
				phase += f * vbb / RATE
				var sawb := fmod(phase, 1.0) * 2.0 - 1.0
				var open := 0.06 + 0.22 * minf(1.0, t / 0.04) * (0.6 + 0.4 * exp(-t * 6.0))
				lp += (sawb - lp) * open; prev += (lp - prev) * open
				v = prev * minf(1.0, t / 0.025) * (0.8 + 0.2 * exp(-t * 4.0)) * minf(1.0, (length - t) / 0.12) * 0.8
			"tuba":
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.05
				v = ((sin(TAU * f * t) + 0.5 * sin(TAU * 2.0 * f * t) + 0.22 * sin(TAU * 3.0 * f * t) + 0.08 * sin(TAU * 4.0 * f * t)) * 0.55
					+ lp * exp(-t * 30.0) * 0.25) * minf(1.0, t / 0.035) * (0.75 + 0.25 * exp(-t * 5.0)) * minf(1.0, (length - t) / 0.1)
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = play_rate; w.stereo = false; w.data = data
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
	if music_island != Data.island: music_island = Data.island; music = Data.island_def(Data.island).get("music", {})
	want_song = song_for(part, game.mode == "build", music, game.state.flags, game.festa_now())
	soft = lerpf(soft, clampf(game.weather_now.get("rain", 0.0) * 1.4, 0.0, 1.0), 1.0 - exp(-dt * 0.5))
	# crossfade: fade the current tune out, switch while silent (once the new tune's notes are ready), fade it in
	if want_song != song:
		if warm_song != want_song: _warm(want_song)
		gain = maxf(0.0, gain - dt / 1.6)
		if gain <= 0.0 and (warm_task == -1 or WorkerThreadPool.is_task_completed(warm_task)):
			_warmed()
			song = want_song; step = 0; next_step_time = song_time
	else:
		gain = minf(1.0, gain + dt / 3.0)
	song_time += dt
	var s: Dictionary = song_def(song, music)
	var step_dur: float = 60.0 / s.bpm / 2.0
	var guard := 0
	while next_step_time <= song_time and guard < 8:
		guard += 1
		if gain > 0.01: _music_step(s)
		step += 1; next_step_time += step_dur
	var songbirds: bool = Data.island_def(Data.island).get("look", {}).get("songbirds", true)   # (a look's "songbirds": false: a city in December)
	var night: bool = game.state.flags.get("night", false)
	bird_t -= dt
	if bird_t < 0.0:
		# now and then, not all the time: a bird somewhere, a different one each time (crickets at night)
		var hour := float(game.state.time.minute) / 60.0
		bird_t = bird_gap(hour, night, randf())
		if songbirds:
			if night:
				for i in 3: play("chirp", 100, 0.04, sfx_bus, i * 0.07)
			elif game.weather_now.get("rain", 0.0) < 0.3:
				last_call = next_call(last_call, randi())
				for n in bird_call(last_call, randi()): play(n[0], n[1], n[2], sfx_bus, n[3])
	hen_t -= dt
	if hen_t < 0.0:
		hen_t = 1.5 + randf() * 3.5
		var hen := _nearest_chicken(game)
		if hen < HEN_RANGE and not night:
			var loud := 0.32 * (1.0 - hen / HEN_RANGE)
			for n in hen_clucks(randi()): play(n[0], n[1], n[2] * loud, sfx_bus, n[3])
	amb_t -= dt
	if amb_t < 0.0:
		amb_t = 0.8 + randf() * 2.5
		var p: Vector3 = game.player.pos
		var river := maxf(0.0, 1.0 - (absf(p.z - Heightfield.river_center(p.x)) - 3.0) / 8.0) if Data.island == "hearthglow" else 0.0
		if river > 0.05: play("hiss", 60, 0.15 * river)
		var wet: float = game.weather_now.get("rain", 0.0)
		if wet > 0.05: play("hiss", 70, 0.3 * wet)

## Birdsong: the calls of a few different birds, each sung a little differently every time.
## 0 a blackbird's fluting phrase, 1 a great tit's two-note "tea-cher", 2 a wren's fast trill, 3 a finch's falling run,
## 4 a robin's thin, wandering warble.
const BIRD_CALLS := 5
const HEN_RANGE := 14.0   # chickens are heard within this many metres

## Seconds until the next bird: busiest at dawn and in the morning, quieter in the afternoon, rare in the evening.
static func bird_gap(hour: float, night: bool, r: float) -> float:
	if night: return 3.0 + r * 5.0   # crickets
	var busy := 0.7 if hour < 11.0 else (1.0 if hour < 17.0 else 1.6)
	return (7.0 + r * 14.0) * busy

## The next bird to sing: any but the last one.
static func next_call(last: int, r: int) -> int:
	var c := absi(r) % (BIRD_CALLS - 1)
	return c + 1 if c >= last and last >= 0 else c

## The notes of one call: [[instrument, note, volume, delay]].
static func bird_call(kind: int, r: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = r
	var out: Array = []
	var t := 0.0
	match kind:
		0:   # blackbird: 3 to 5 low, mellow whistles on a pentatonic scale, unevenly spaced
			var scale := [79, 81, 84, 86, 88, 91]
			for i in rng.randi_range(3, 5):
				out.append(["whistle", scale[rng.randi() % scale.size()], 0.06, t]); t += rng.randf_range(0.16, 0.3)
		1:   # great tit: high-low, two to four times
			var hi := rng.randi_range(93, 96)
			for i in rng.randi_range(2, 4):
				out.append(["chirp", hi, 0.05, t]); out.append(["chirp", hi - rng.randi_range(4, 6), 0.045, t + 0.11]); t += 0.3
		2:   # wren: a quick trill of tiny chirps
			var n0 := rng.randi_range(96, 99)
			for i in rng.randi_range(6, 10):
				out.append(["chirp", n0 + (i % 3) - 1, 0.035, t]); t += 0.055
		3:   # finch: a falling run, then a flourish
			var top := rng.randi_range(96, 100)
			for i in rng.randi_range(4, 6):
				out.append(["chirp", top - i, 0.04, t]); t += 0.075
			out.append(["whistle", top - 2, 0.04, t + 0.05])
		_:   # robin: thin high whistles wandering up and down
			var nn := rng.randi_range(90, 95)
			for i in rng.randi_range(3, 5):
				nn += rng.randi_range(-3, 3)
				out.append(["whistle", nn, 0.035, t]); t += rng.randf_range(0.2, 0.34)
	return out

## A hen's remark: a few clucks, sometimes ending in a long "bawk".
static func hen_clucks(r: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = r
	var out: Array = []
	var t := 0.0
	var base := rng.randi_range(66, 70)
	for i in rng.randi_range(2, 4):
		out.append(["cluck", base + rng.randi_range(-1, 1), 1.0, t]); t += rng.randf_range(0.16, 0.26)
	if rng.randf() < 0.35: out.append(["bawk", base + 2, 1.0, t + 0.05])
	return out

## How far the player is from the nearest chicken (INF where there are none).
func _nearest_chicken(game) -> float:
	var an = game.get_node_or_null("Animals")
	if an == null or not "chickens" in an: return INF
	var p: Vector3 = game.player.pos
	var best := INF
	for c in an.chickens: best = minf(best, Vector2(c.x - p.x, c.z - p.z).length())
	return best

## Start making a song's notes in the background (synthesising a piano or string note takes tens of milliseconds,
## too long to do the moment it first plays).
func _warm(id: String) -> void:
	_warmed()
	warm_song = id
	var s: Dictionary = song_def(id, music)
	var todo := {}
	for st in loop_steps(s) * (2 if int(s.get("lift", 0)) != 0 else 1):
		for e in step_events(s, st):
			var key := "%s:%d" % [e[0], e[1]]
			if not cache.has(key): todo[key] = [e[0], e[1]]
	if todo.is_empty(): return
	var out := {}
	warm_out = out
	var notes: Array = todo.values()
	warm_task = WorkerThreadPool.add_task(func():
		for kv in notes: out["%s:%d" % kv] = synth(kv[0], kv[1]))

## Wait for the background notes (if any) and keep them.
func _warmed() -> void:
	if warm_task == -1: return
	WorkerThreadPool.wait_for_task_completion(warm_task)
	warm_task = -1
	cache.merge(warm_out)
	warm_out = {}

func _exit_tree() -> void: _warmed()

func _music_step(s: Dictionary) -> void:
	for e in step_events(s, step, soft):
		play(e[0], e[1], e[2] * gain, music_bus, e[3])

## The notes one step of a song plays: [instrument, midi note, volume, delay in seconds]. Pure, so it can be tested
## and rendered offline. soft (0..1) is how much rain has softened the music.
static func step_events(s: Dictionary, step: int, soft: float = 0.0) -> Array:
	var out: Array = []
	var bl := int(s.get("bar", 16))
	var beat := step % bl
	var bar: int = int(step / bl) % s.chords.size()
	var chord: Array = s.chords[bar]
	var loop := loop_steps(s)
	var R: int = int(s.root) + int(s.get("lift", 0)) * (int(step / loop) % 2)
	var bass: float = float(s.get("bass", 1.0))
	var bi: String = s.get("bass_inst", "pluck")
	if beat == 0 and int(step / bl) % maxi(1, int(s.get("pad_every", 1))) == 0:
		for nn in chord: out.append([s.get("pad_inst", "pad"), R + int(nn) - 12, float(s.pad), 0.0])
	if bass > 0.0:
		var low := R + int(chord[0]) - 24
		match String(s.get("bass_style", "")):
			"eighths": out.append([bi, low, (0.3 if beat % 2 == 0 else 0.22) * bass, 0.0])
			"quarters": if beat % 2 == 0: out.append([bi, low, 0.3 * bass, 0.0])
			"offbeat": if beat % 2 == 1: out.append([bi, low + (12 if beat % 4 == 3 else 0), 0.3 * bass, 0.0])
			_:
				if beat == 0: out.append([bi, low, 0.4 * bass, 0.0])
				if beat == int(bl / 2.0): out.append([bi, R + int(chord[2 % chord.size()]) - 24, 0.3 * bass, 0.0])
	var every: int = int(s.get("arp_every", 2))
	if s.arp != "" and beat % every == 0:
		var idx: int = int(beat / every) % chord.size()
		var octave := 12 if s.arp == "glock" else (0 if beat % 4 else -12)
		var av: float = {"glock": 0.15, "pluck": 0.16, "marimba": 0.22, "guitar": 0.2, "piano": 0.14}.get(s.arp, 0.18)
		out.append([s.arp, R + int(chord[idx]) + octave, av * lerpf(1.0, 0.7, soft), 0.0])
	for c in s.get("comp", []):
		if not c.get("steps", []).has(beat): continue
		for i in chord.size():
			out.append([c.get("inst", "guitar"), R + int(chord[i]) + int(c.get("octave", 0)), float(c.get("vol", 0.12)) * lerpf(1.0, 0.7, soft), i * float(c.get("spread", 0.0))])
	var drums: String = s.drums if soft < 0.5 else ""
	match drums:
		"full":
			if beat % 4 == 2: out.append(["hat", 60, 0.12, 0.0])
			if beat == 0 or beat == 10: out.append(["kick", 40, 0.35, 0.0])
		"light": if beat % 4 == 2: out.append(["hat", 60, 0.08, 0.0])
		"pop":
			if beat % 4 == 0 or beat == 7: out.append(["kick", 40, 0.36, 0.0])
			if beat % 4 == 2: out.append(["snare", 60, 0.24, 0.0])
			out.append(["hat", 60, 0.08 if beat % 2 == 0 else 0.05, 0.0])
		"dance":
			if beat % 2 == 0: out.append(["kick", 40, 0.38, 0.0])
			if beat % 4 == 2: out.append(["clap", 60, 0.22, 0.0])
			if beat % 2 == 1: out.append(["openhat", 60, 0.07, 0.0])
		"ballad":
			if beat == 0 or beat == 8 or beat == 11: out.append(["kick", 40, 0.3, 0.0])
			if beat == 4 or beat == 12: out.append(["snare", 60, 0.16, 0.0])
			if beat % 2 == 0: out.append(["hat", 60, 0.05, 0.0])
	var ms := step % loop
	var lv: float = {"glock": 0.25, "flute": 0.3, "rhodes": 0.32, "piano": 0.34, "saw": 0.2, "guitar": 0.3, "mandolin": 0.32, "brass": 0.3}.get(s.lead, 0.4) * float(s.get("lead_vol", 1.0))
	for m in s.melody:
		if int(m[0]) == ms: out.append([s.lead, R + int(m[1]), lv * lerpf(1.0, 0.75, soft), 0.0])
	return out

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
		"cluck": play("cluck", 68, 0.35); play("cluck", 69, 0.3, sfx_bus, 0.18); play("bawk", 70, 0.32, sfx_bus, 0.4)
		"purr": play("purr", 40, 0.4)
		"door": play("thud", 45, 0.35)
		"lever": play("blip", 67, 0.3); play("thud", 60, 0.25)
		"paint": arp.call([88, 91, 95], 0.03, "glock", 0.25)
		"undo": play("blip", 76, 0.2); play("blip", 81, 0.15, sfx_bus, 0.05)
		"gate": play("pad", 38, 0.3); arp.call([60, 67, 72], 0.2, "marimba", 0.55)
		"sail": play("hiss", 55, 0.35); arp.call([67, 71, 74, 79], 0.15, "marimba", 0.5)
		"morning": arp.call([72, 76, 79], 0.12, "glock", 0.35)
		"save": arp.call([79, 84], 0.06, "glock", 0.3)
		"bell": arp.call([91, 91], 0.14, "glock", 0.5)   # ring ring
		"freewheel":   # the freewheel ticking as the bike rolls on without pedalling, slowing down
			for i in 8: play("hat", 60, 0.08 * (1.0 - i * 0.09), sfx_bus, i * (0.045 + i * 0.012))

## Cartoon "babble": short pitched syllables.
func voice(pitch: float, syllables: int) -> void:
	var base := 64 + int(round(12.0 * log(maxf(0.3, pitch)) / log(2.0)))
	for i in syllables: play("blip", base + randi() % 5 - 2, 0.28, sfx_bus, i * 0.085)
