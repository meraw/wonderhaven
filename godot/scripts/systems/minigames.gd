class_name Minigames
## Short gathering minigames as state machines: step(dt, press, hold) until done.

class Chop:
	var rng: Rng
	var round := 0
	var rounds := 3
	var results: Array = []
	var done := false
	var pause := 0.0
	var center := 0.5
	var width := 0.24
	var perfect := 0.07
	var speed := 1.1
	var phase := 0.0
	var last := ""
	var hit_at := -1.0   # where the needle was on the last swing; shown until the next round starts
	const GRACE := 0.012  # half the drawn needle's width: a needle touching the zone counts
	func _init(r: Rng = null) -> void:
		rng = r if r else Rng.new(Time.get_ticks_usec() & 0xffff)
		new_round()
	func new_round() -> void:
		center = 0.3 + rng.next() * 0.4; speed = 1.1 + round * 0.25; phase = rng.next() * TAU
	func needle() -> float: return 0.5 + 0.5 * sin(phase)
	## Judges a press against the needle as it was last drawn, then moves it on. The zone and needle stay put
	## during the pause so the player sees exactly where the swing landed.
	func step(dt: float, press: bool, _hold: bool = false) -> void:
		if done: return
		if pause > 0.0:
			pause -= dt
			if pause <= 0.0:
				hit_at = -1.0
				if round >= rounds: done = true
				else: new_round()
			return
		if press:
			var d := absf(needle() - center)
			last = "perfect" if d <= perfect / 2.0 + GRACE / 2.0 else ("good" if d <= width / 2.0 + GRACE else "miss")
			results.append(last); round += 1; pause = 0.6; hit_at = needle()
			return
		phase += dt * speed * PI
	func reward() -> Dictionary:
		var good := results.filter(func(r): return r != "miss").size()
		var perf := results.filter(func(r): return r == "perfect").size()
		return {"wood": 1 + good + perf / 2, "spark": 1 + perf}

class Mine:
	var rng: Rng
	var rich := false
	var strikes := 3
	var results: Array = []
	var done := false
	var pause := 0.0
	var r := 1.0
	var speed := 0.55
	var target := [0.32, 0.46]
	var last := ""
	func _init(p_rich: bool = false, rr: Rng = null) -> void:
		rich = p_rich; rng = rr if rr else Rng.new(Time.get_ticks_usec() & 0xffff); reset()
	const GRACE := 0.02   # half the drawn ring's thickness
	func reset() -> void: r = 1.0; speed = 0.55 + results.size() * 0.12
	## Judges a press against the ring as it was last drawn, then shrinks it. The ring stays where it was struck
	## during the pause.
	func step(dt: float, press: bool, _hold: bool = false) -> void:
		if done: return
		if pause > 0.0:
			pause -= dt
			if pause <= 0.0:
				if results.size() >= strikes: done = true
				else: reset()
			return
		if press:
			var mid: float = (target[0] + target[1]) / 2.0
			var inside: bool = r >= target[0] - GRACE and r <= target[1] + GRACE
			last = ("perfect" if absf(r - mid) < 0.03 + GRACE / 2.0 else "good") if inside else "miss"
			results.append(last); pause = 0.6
			return
		r -= dt * speed
		if r < 0.05: results.append("miss"); last = "miss"; pause = 0.6
	func reward() -> Dictionary:
		var hits := results.filter(func(x): return x != "miss").size()
		var perf := results.filter(func(x): return x == "perfect").size()
		var out := {"stone": 1 + hits, "spark": 1 + perf}
		if hits >= 2 or (rich and hits >= 1): out["metal"] = 1
		if rich and hits >= 1: out["crystal"] = 2 if hits >= 3 else 1
		elif perf >= 2: out["crystal"] = 1
		return out

const FISH := [{"id": "minnow", "name": "Sunny Minnow", "weight": 5.0, "pull": 0.5}, {"id": "trout", "name": "Rainbow Trout", "weight": 3.0, "pull": 0.8},
	{"id": "puffer", "name": "Puffy Pufferfish", "weight": 1.5, "pull": 1.0}, {"id": "starfin", "name": "Wishing Starfin", "weight": 0.6, "pull": 1.25}]

class Fish:
	var rng: Rng
	var phase := "wait"
	var t := 0.0
	var wait := 2.0
	var done := false
	var result := ""
	var tension := 0.4
	var progress := 0.0
	var band := [0.32, 0.74]
	var fish: Dictionary
	var pull := 0.0
	func _init(r: Rng = null) -> void:
		rng = r if r else Rng.new(Time.get_ticks_usec() & 0xffff)
		wait = 1.4 + rng.next() * 2.6
		var total := 0.0
		for f in Minigames.FISH: total += f.weight
		var x := rng.next() * total
		fish = Minigames.FISH[0]
		for f in Minigames.FISH:
			x -= f.weight
			if x <= 0.0: fish = f; break
	func step(dt: float, press: bool, hold: bool = false) -> void:
		if done: return
		t += dt
		match phase:
			"wait":
				if press: done = true; result = "early"; return
				if t >= wait: phase = "bite"; t = 0.0
			"bite":
				if press: phase = "reel"; t = 0.0; return
				if t > 1.3: done = true; result = "missed"
			"reel":
				if rng.next() < dt * 1.6: pull = (rng.next() - 0.3) * fish.pull
				tension = clampf(tension + (0.55 if hold else -0.5) * dt + pull * dt * 0.8, 0.0, 1.0)
				pull *= 1.0 - dt * 1.5
				var in_band: bool = tension >= band[0] and tension <= band[1]
				progress = maxf(0.0, progress + (0.22 if in_band else -0.08) * dt)
				if tension >= 0.99: done = true; result = "snap"
				elif progress >= 1.0: done = true; result = "caught"
				elif t > 25.0: done = true; result = "escaped"
	func reward() -> Dictionary: return {"fish": 1, "spark": 2} if result == "caught" else {}
