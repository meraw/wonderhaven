class_name Staging
extends RefCounted

static func zone_centre(zone: Dictionary) -> Vector2:
	return Vector2((float(zone.minI) + float(zone.maxI) + 1.0) / 2.0, (float(zone.minK) + float(zone.maxK) + 1.0) / 2.0)

static func anchor(spec: Dictionary, placements: Array) -> Vector2:
	var at: Dictionary = spec.get("at", {})
	var zone: Dictionary = Data.zone(String(at.get("zone", "")))
	if zone.is_empty():
		var p: Array = at.get("point", [0.0, 0.0])
		return Vector2(float(p[0]), float(p[1]))
	var inside := Validate.pieces_in_zone(zone, placements)
	var want: Array = at.get("pieces", [])
	var chosen := inside.filter(func(pl): return want.has(String(pl.id)))
	if chosen.is_empty(): chosen = inside
	if chosen.is_empty(): return zone_centre(zone)
	var sum := Vector2.ZERO
	for pl in chosen:
		var b := BuildGrid.bounds(pl)
		sum += Vector2((float(b.minX) + float(b.maxX)) / 2.0, (float(b.minZ) + float(b.maxZ)) / 2.0)
	return sum / float(chosen.size())

static func frame(spec: Dictionary, origin: Vector2) -> Dictionary:
	var a: Array = spec.get("audience", [0.0, 1.0])
	var fwd := Vector2(float(a[0]), float(a[1]))
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector2(0.0, 1.0)
	return {"origin": origin, "fwd": fwd, "right": Vector2(-fwd.y, fwd.x)}

static func to_world(fr: Dictionary, off) -> Vector2:
	var o := Vector2(float(off[0]), float(off[1]))
	return fr.origin + fr.right * o.x + fr.fwd * o.y

static func yaw_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, to.y - from.y)

static func free_spot(want: Vector2, is_free: Callable, step: float = 0.35, rings: int = 5) -> Vector2:
	if is_free.call(want): return want
	for ring in range(1, rings + 1):
		var n := ring * 8
		for k in n:
			var a := TAU * float(k) / float(n)
			var p := want + Vector2(cos(a), sin(a)) * step * float(ring)
			if is_free.call(p): return p
	return want

static func candle_points(spec: Dictionary) -> Array:
	var c: Dictionary = spec.get("candles", {})
	var out: Array = []
	var n := int(c.get("count", 0))
	if n <= 0: return out
	var a: Array = c.get("from", [0.0, 0.0])
	var b: Array = c.get("to", a)
	var pa := Vector2(float(a[0]), float(a[1]))
	var pb := Vector2(float(b[0]), float(b[1]))
	for i in n:
		var k := 0.5 if n == 1 else float(i) / float(n - 1)
		out.append(pa.lerp(pb, k))
	return out

static func lit_count(spec: Dictionary, seconds: float) -> int:
	var c: Dictionary = spec.get("candles", {})
	var n := int(c.get("count", 0))
	var every := float(c.get("every", 0.4))
	if seconds < 0.0 or n <= 0: return 0
	if every <= 0.0: return n
	return mini(n, int(floor(seconds / every)) + 1)

static func beat(spec: Dictionary, line: int) -> Dictionary:
	for b in spec.get("beats", []):
		if int(b.get("line", -1)) == line: return b
	return {}

static func entering(spec: Dictionary, line: int) -> Array:
	return spec.get("actors", []).filter(func(a): return int(a.get("beat", 0)) == line)

static func cast_ids(spec: Dictionary) -> Array:
	var out: Array = []
	for a in spec.get("actors", []):
		if a.has("npc"): out.append(String(a.npc))
	return out

static func crowd_spots(fr: Dictionary, spec: Dictionary, n: int) -> Array:
	var c: Dictionary = spec.get("crowd", {})
	var at: Array = c.get("at", [0.0, 4.0])
	var gap := float(c.get("gap", 1.0))
	var per_row := maxi(1, int(c.get("per_row", 4)))
	var out: Array = []
	var given: Array = c.get("spots", [])
	for i in mini(n, given.size()): out.append(to_world(fr, given[i]))
	var rest := n - out.size()
	for i in rest:
		var row := i / per_row
		var in_row := mini(per_row, rest - row * per_row)
		var col := i % per_row
		var x := float(at[0]) + (float(col) - float(in_row - 1) / 2.0) * gap + (0.5 * gap if row % 2 == 1 else 0.0)
		var z := float(at[1]) + float(row) * gap * 0.9
		out.append(to_world(fr, [x, z]))
	return out

static func entry_point(spec: Dictionary, actor: Dictionary) -> Array:
	if actor.has("from"): return actor.from
	var at: Array = actor.get("at", [0.0, 0.0])
	var e: Array = spec.get("enter", [0.0, 5.0])
	return [float(at[0]) + float(e[0]), float(at[1]) + float(e[1])]

static func melody(m: Dictionary) -> Array:
	var out: Array = []
	var step := float(m.get("step", 0.5))
	var vol := float(m.get("vol", 0.3))
	var kind := String(m.get("kind", "flute"))
	var t := float(m.get("delay", 0.0))
	for n in m.get("notes", []):
		var note := int(n[0]) if n is Array else int(n)
		var beats := float(n[1]) if n is Array and n.size() > 1 else 1.0
		if note > 0: out.append([kind, note, vol, t])
		t += beats * step
	return out

static func walk_step(from: Vector2, to: Vector2, speed: float, dt: float) -> Vector2:
	var d := to - from
	var s := speed * dt
	if d.length() <= s: return to
	return from + d.normalized() * s
