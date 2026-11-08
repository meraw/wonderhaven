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
	var base_speed := 1.1
	var rest := 0.6
	var extra := 0
	var perfect_bonus := 0
	var big := false
	var tool := {}
	const GRACE := 0.012  # half the drawn needle's width: a needle touching the zone counts
	func _init(r: Rng = null, p_tool: Dictionary = {}, p_big: bool = false) -> void:
		rng = r if r else Rng.new(Time.get_ticks_usec() & 0xffff)
		tool = p_tool
		big = p_big
		width = float(p_tool.get("width", width))
		base_speed = float(p_tool.get("speed", base_speed))
		rounds = int(p_tool.get("rounds", rounds))
		rest = float(p_tool.get("pause", rest))
		extra = int(p_tool.get("yield", 0))
		perfect_bonus = int(p_tool.get("perfect_bonus", 0))
		new_round()
	func new_round() -> void:
		center = 0.3 + rng.next() * 0.4; speed = base_speed + round * 0.25; phase = rng.next() * TAU
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
			results.append(last); round += 1; pause = rest; hit_at = needle()
			return
		phase += dt * speed * PI
	func perfect_run() -> bool: return results.size() >= rounds and results.all(func(r): return r == "perfect")
	func reward() -> Dictionary:
		var good := results.filter(func(r): return r != "miss").size()
		var perf := results.filter(func(r): return r == "perfect").size()
		var out := {"wood": 1 + good + perf / 2 + (extra if good > 0 else 0)}
		if perfect_run(): out.wood += perfect_bonus
		if big and good > 0: out["beam"] = 1 + perf / 2 + maxi(extra - 1, 0) + (1 if perfect_run() else 0)
		return out

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
	var bonus := "metal"   # what a rich rock is rich in (a layout's richRock): iron-red metal, or glowing crystal
	var base_speed := 0.55
	var rest := 0.6
	var extra := 0
	var perfect_bonus := 0
	var dresses := false
	var tool := {}
	func _init(p_rich: bool = false, rr: Rng = null, p_bonus: String = "metal", p_tool: Dictionary = {}) -> void:
		rich = p_rich; bonus = p_bonus; rng = rr if rr else Rng.new(Time.get_ticks_usec() & 0xffff)
		tool = p_tool
		strikes = int(p_tool.get("strikes", strikes))
		target = p_tool.get("zone", target)
		base_speed = float(p_tool.get("speed", base_speed))
		rest = float(p_tool.get("pause", rest))
		extra = int(p_tool.get("yield", 0))
		perfect_bonus = int(p_tool.get("perfect_bonus", 0))
		dresses = bool(p_tool.get("dresses", false))
		reset()
	const GRACE := 0.02   # half the drawn ring's thickness
	func reset() -> void: r = 1.0; speed = base_speed + results.size() * 0.12
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
			results.append(last); pause = rest
			return
		r -= dt * speed
		if r < 0.05: results.append("miss"); last = "miss"; pause = rest
	func perfect_run() -> bool: return results.size() >= strikes and results.all(func(x): return x == "perfect")
	func reward() -> Dictionary:
		var hits := results.filter(func(x): return x != "miss").size()
		var perf := results.filter(func(x): return x == "perfect").size()
		var all_hit := hits >= strikes
		var out := {"stone": 1 + hits + (1 if perf >= 2 else 0) + (extra if hits > 0 else 0)}
		if bonus == "metal":   # the rusty-red rocks are iron-rich: they give more metal
			if rich and hits >= 1: out["metal"] = 2 if all_hit else 1
			elif hits >= 2: out["metal"] = 1
		else:   # rich in something else (the cove's glowing crystals); two perfect strikes find a little anywhere
			if hits >= 2 or (rich and hits >= 1): out["metal"] = 1
			if rich and hits >= 1: out[bonus] = 2 if all_hit else 1
			elif perf >= 2: out[bonus] = 1
		if perfect_run(): out.stone += perfect_bonus
		if dresses and perf > 0: out["cutstone"] = perf + (1 if perfect_run() else 0)
		return out

const FISH := [{"id": "minnow", "name": "Minnow", "weight": 5.0, "pull": 0.5}, {"id": "trout", "name": "Brown Trout", "weight": 3.0, "pull": 0.8},
	{"id": "puffer", "name": "Perch", "weight": 1.5, "pull": 1.0}, {"id": "starfin", "name": "Pike", "weight": 0.6, "pull": 1.25}]

## What can bite at a fishing spot. A layout may list its own catches ("fish": [{id, name, weight, pull, item?,
## node?, flag?, hours?}]): `item` is what you get (the shared "fish" when left out, or a boot, a tyre...), and a
## catch with `node` only bites at that spot, with `flag` only once that flag is set, with `hours` only then. An empty
## `item` is one you put straight back (a sleepy frog). Without a list of its own, a location has the shared FISH.
static func catch_table(list: Array, node_id: String, flags: Dictionary, minute: float) -> Array:
	if list.is_empty(): return FISH
	var out := list.filter(func(f): return (not f.has("node") or f.node == node_id) and (not f.has("flag") or flags.get(f.flag, false)) \
		and Clock.in_hours(f.get("hours", []), minute))
	return out if not out.is_empty() else FISH

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
	func _init(r: Rng = null, table: Array = []) -> void:
		rng = r if r else Rng.new(Time.get_ticks_usec() & 0xffff)
		wait = 1.4 + rng.next() * 2.6
		var choices: Array = table if not table.is_empty() else Minigames.FISH
		var total := 0.0
		for f in choices: total += float(f.weight)
		var x := rng.next() * total
		fish = choices[0]
		for f in choices:
			x -= float(f.weight)
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
	func reward() -> Dictionary: return {String(fish.get("item", "fish")): 1} if result == "caught" and String(fish.get("item", "fish")) != "" else {}

## "a Minnow", "an Old Boot".
static func a_name(name: String) -> String: return ("an " if name.length() > 0 and "AEIOUaeiou".contains(name[0]) else "a ") + name
