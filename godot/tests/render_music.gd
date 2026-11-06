extends SceneTree
## Renders a place's music to WAV files, so it can be listened to (and its levels checked) without playing the game:
##   godot --headless --path . -s res://tests/render_music.gd -- --island=hearthglow --out=/tmp/music [--loops=2]
##   [--flags=a,b] (story flags set, for a place whose music changes as its story goes on: "when")
## One file per song the place plays (each part of the day, and building), mixed from the same notes the game plays
## (AudioDirector.step_events) and the same synthesised instruments. Prints each song's peak and loudness before
## the file is normalised, so a song that would clip in the game shows up.

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	await process_frame   # autoloads (Data) are ready from the first frame, and only by node path in a -s script
	var island: String = args.get("island", "hearthglow")
	var out: String = args.get("out", "/tmp/music")
	DirAccess.make_dir_recursive_absolute(out)
	var music: Dictionary = root.get_node("Data").island_def(island).get("music", {})
	var AudioDirector = load("res://scripts/audio/audio_director.gd")   # loaded now: it names the Data autoload
	var ad = AudioDirector.new()
	var flags := {}
	for f in String(args.get("flags", "")).split(",", false): flags[f] = true
	var samples := {}   # each note's samples, decoded once
	var done := {}
	for part in ["dawn", "morning", "afternoon", "evening", "night", "build"]:
		var id: String = AudioDirector.song_for(part, part == "build", music, flags)
		if done.has(id): continue
		done[id] = true
		var s: Dictionary = AudioDirector.song_def(id, music)
		var loops := int(args.get("loops", "2"))
		var steps: int = AudioDirector.loop_steps(s) * loops
		var step_dur: float = 60.0 / float(s.bpm) / 2.0
		var rate: int = AudioDirector.RATE
		var buf := PackedFloat32Array(); buf.resize(int((steps * step_dur + 3.0) * rate))
		for st in steps:
			for e in AudioDirector.step_events(s, st):
				var key := "%s:%d" % [e[0], e[1]]
				if not samples.has(key):
					var w: AudioStreamWAV = ad._gen(e[0], e[1])
					# a note made at another rate (the guitar, tuned that way) is resampled to the mix's rate
					var ratio := float(w.mix_rate) / rate
					var n := w.data.size() / 2
					var f := PackedFloat32Array(); f.resize(int(n / ratio))
					for i in f.size():
						var x := i * ratio; var i0 := mini(int(x), n - 1); var i1 := mini(i0 + 1, n - 1)
						f[i] = lerpf(w.data.decode_s16(i0 * 2), w.data.decode_s16(i1 * 2), x - i0) / 32000.0
					samples[key] = f
				var src: PackedFloat32Array = samples[key]
				var at := int((st * step_dur + float(e[3])) * rate)
				var vol: float = e[2]
				for i in mini(src.size(), buf.size() - at): buf[at + i] += src[i] * vol
		var peak := 0.0; var sum := 0.0
		for v in buf: peak = maxf(peak, absf(v)); sum += v * v
		var rms := sqrt(sum / buf.size())
		var k := 0.89 / maxf(peak, 0.0001)
		var data := PackedByteArray(); data.resize(buf.size() * 2)
		for i in buf.size(): data.encode_s16(i * 2, int(clampf(buf[i] * k, -1.0, 1.0) * 32000.0))
		var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = rate; wav.data = data
		var path := "%s/%s_%s.wav" % [out, part, id]
		wav.save_to_wav(path)
		print("%-10s %-24s %3d bpm  %5.1f s  peak %.2f  rms %.3f  -> %s" % [part, id, int(s.bpm), buf.size() / float(rate), peak, rms, path])
	ad.free()
	quit()
