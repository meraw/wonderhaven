class_name Inauguration

static func cfg() -> Dictionary:
	var c: Dictionary = Data.inauguration.duplicate(true)
	c.merge(Data.layout.get("inauguration", {}), true)
	return c

static func speaker() -> String: return String(cfg().get("speaker", ""))

static func on() -> bool: return WorkDay.on(Data.island) and speaker() != ""

static func _ids(state: Dictionary) -> Dictionary:
	var out := {}
	var r := WorkDay.record(state)
	if r.get("placed") is Array:
		for u in r.placed: out[int(u)] = true
	return out

static func placed(state: Dictionary, uid: int) -> void:
	var r := WorkDay.record(state)
	if not r.get("placed") is Array: r["placed"] = []
	if not _ids(state).has(uid): r.placed.append(uid)

static func removed(state: Dictionary, uid: int) -> void:
	var r := WorkDay.record(state)
	if r.get("placed") is Array: r["placed"] = r.placed.filter(func(u): return int(u) != uid)

static func pending(state: Dictionary, placements: Array) -> Array:
	var ids := _ids(state)
	return placements.filter(func(p): return ids.has(int(p.uid)))

static func groups(pieces: Array, gap: float) -> Array:
	var out: Array = []
	var left: Array = pieces.duplicate()
	while not left.is_empty():
		var g: Array = [left.pop_front()]
		var i := 0
		while i < g.size():
			var c := Needs.center(g[i])
			var keep: Array = []
			for p in left:
				if Needs.center(p).distance_to(c) <= gap: g.append(p)
				else: keep.append(p)
			left = keep
			i += 1
		out.append(g)
	return out

static func _met_by(group: Array, village: Dictionary) -> Array:
	var uids := {}
	for p in group: uids[int(p.uid)] = true
	var out: Array = []
	for n in village.get("needs", []):
		if n.met and uids.has(int(n.uid)): out.append(String(n.key))
	return out

static func subject(pieces: Array, village: Dictionary, c: Dictionary) -> Array:
	var best: Array = []
	var score := -1.0
	for g in groups(pieces, float(c.get("cluster", 3.0))):
		var s: float = g.size() + 3.0 * _met_by(g, village).size()
		if s > score: score = s; best = g
	return best

static func noun(id: String, n: int, c: Dictionary) -> String:
	var name := String(Data.piece(id).get("name", id)).to_lower()
	var forms: Array = c.get("nouns", {}).get(id, [])
	var one := String(forms[0]) if forms.size() == 2 else (("an " if "aeiou".contains(name.substr(0, 1)) else "a ") + name)
	var plural_end := "es" if name.ends_with("s") or name.ends_with("x") or name.ends_with("sh") or name.ends_with("ch") else "s"
	var many := String(forms[1]) if forms.size() == 2 else name + plural_end
	if n == 1: return one
	var words: Array = c.get("numbers", [])
	return "%s %s" % [String(words[n]) if n < words.size() and String(words[n]) != "" else str(n), many]

static func join_and(parts: Array) -> String:
	if parts.size() <= 1: return "" if parts.is_empty() else String(parts[0])
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + String(parts[-1])

static func what(ids: Array, c: Dictionary) -> String:
	var order: Array = []
	var count := {}
	for id in ids:
		if not count.has(id): order.append(id)
		count[id] = int(count.get(id, 0)) + 1
	var ranked: Array = []
	for i in order.size(): ranked.append([order[i], int(count[order[i]]), i])
	ranked.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))
	var shown := int(c.get("kinds_shown", 3))
	var parts: Array = []
	var rest := 0
	for i in ranked.size():
		if i < shown: parts.append(noun(String(ranked[i][0]), int(ranked[i][1]), c))
		else: rest += int(ranked[i][1])
	if rest > 0: parts.append(String(c.get("others", "{n} other pieces")).replace("{n}", str(rest)))
	return join_and(parts)

static func facts(group: Array, hs: Array, village: Dictionary, opts: Array, c: Dictionary) -> Dictionary:
	var counts := {}
	for p in group:
		for h in hs:
			if Needs.inside(p, h): counts[String(h.id)] = int(counts.get(String(h.id), 0)) + 1
	var hang := ""
	var most := 0
	for hid in counts:
		if int(counts[hid]) > most: most = int(counts[hid]); hang = String(hid)
	if most * 2 < group.size(): hang = ""
	var h := Needs.hangout(hs, hang)
	var usable := 0
	var stares := 0
	var low := INF
	var perch := -INF
	var kinds := {}
	var colours := 0
	for p in group:
		var mine: Array = opts.filter(func(o): return int(o.uid) == int(p.uid))
		if mine.any(func(o): return o.use): usable += 1
		elif not mine.is_empty(): stares += 1
		var b := BuildGrid.bounds(p)
		low = minf(low, float(b.bottom))
		perch = maxf(perch, float(b.bottom))
		kinds[String(p.id)] = true
		var col := String(p.get("color", ""))
		if col != "" and col != String(Data.piece(String(p.id)).get("color", "")): colours += 1
	var ids: Array = group.map(func(p): return String(p.id))
	return {"n": group.size(), "uids": group.map(func(p): return int(p.uid)), "ids": ids, "hangout": hang,
		"place": String(h.get("at", c.get("place", ""))), "who": String(h.get("who", "")), "needs": _met_by(group, village),
		"usable": usable, "stares": stares, "perch": (perch - low) if group.size() > 0 else 0.0, "kinds": kinds.size(), "colours": colours,
		"what": what(ids, c), "piece": String(Data.piece(String(ids[0])).get("name", ids[0])).to_lower() if not ids.is_empty() else ""}

static func body_kind(f: Dictionary, c: Dictionary) -> String:
	if String(f.hangout) != "" and String(f.who) != "" and String(f.who) == String(c.get("speaker", "")): return "own"
	if not f.needs.is_empty(): return "need"
	if int(f.stares) > 0 and int(f.usable) == 0: return "art"
	if float(f.perch) >= float(c.get("tall", 2.5)): return "tall"
	if int(f.colours) > 0: return "colour"
	if int(f.n) >= int(c.get("many", 6)): return "many"
	if int(f.n) == 1: return "single"
	return "plain"

static func _pick(list: Array, roll: float) -> String:
	if list.is_empty(): return ""
	return String(list[mini(int(clampf(roll, 0.0, 0.999) * list.size()), list.size() - 1)])

static func capital(s: String) -> String: return s.substr(0, 1).to_upper() + s.substr(1)

static func fill(text: String, f: Dictionary, hs: Array) -> String:
	var noticed := Needs.line(hs, String(f.needs[0])) if not f.get("needs", []).is_empty() else ""
	return text.replace("{What}", capital(String(f.get("what", "")))).replace("{what}", String(f.get("what", ""))).replace("{place}", String(f.get("place", ""))) \
		.replace("{noticed}", noticed).replace("{n}", str(int(f.get("n", 0)))).replace("{piece}", String(f.get("piece", "")))

static func speech(f: Dictionary, hs: Array, c: Dictionary, rolls: Array) -> Array:
	var r: Array = rolls + [0.0, 0.0, 0.0]
	var body: Array = c.get("body", {}).get(body_kind(f, c), [])
	return [fill(_pick(c.get("open", []), r[0]), f, hs), fill(_pick(body, r[1]), f, hs), fill(_pick(c.get("close", []), r[2]), f, hs)]

static func grade(f: Dictionary, c: Dictionary) -> float:
	var g: Dictionary = c.get("grade", {})
	var v := float(g.get("base", 6.0))
	v += mini(f.needs.size(), int(g.get("need_max", 3))) * float(g.get("need", 1.0))
	v += mini(int(f.kinds) - 1, int(g.get("kind_max", 3))) * float(g.get("kind", 0.5))
	if int(f.usable) > 0: v += float(g.get("usable", 0.5))
	if int(f.colours) > 0: v += float(g.get("colour", 0.5))
	v = maxf(v, float(g.get("min", 5.0)))
	return round(v * 2.0) / 2.0

static func grade_text(v: float, c: Dictionary) -> String:
	if v > 10.0: return String(c.get("grade", {}).get("lode", "10 e lode"))
	var whole := int(floor(v))
	return "%d%s/10" % [whole, "½" if v - whole >= 0.5 else ""]

static func mood(f: Dictionary) -> String:
	if int(f.usable) == 0 and int(f.stares) > 0: return "puzzled"
	if not f.needs.is_empty() or int(f.usable) > 0: return "cheer"
	return "polite"

static func reactions(f: Dictionary, crowd: Array, c: Dictionary, roll: float, fans: Dictionary = {}) -> Array:
	var m := mood(f)
	var out: Array = []
	var spoke := {}
	for i in crowd.size():
		var id := String(crowd[i])
		var anim := "shrug" if m == "puzzled" else ("clap" if m == "polite" or i % 2 == 1 else "celebrate")
		var r := {"npc": id, "mood": m, "anim": anim, "line": "", "heart": false}
		if id == String(f.who) and id != String(c.get("speaker", "")) and m != "puzzled":
			r.line = _pick(c.get("thanks", []), roll); r.heart = true; r.anim = "celebrate"; spoke[i] = true
		elif fans.has(id) and id != String(c.get("speaker", "")):
			r.line = String(fans[id]); r.heart = true; r.anim = "celebrate"; r["taste"] = true; spoke[i] = true
		out.append(r)
	var others: Array = []
	for i in out.size():
		if not spoke.has(i): others.append(i)
	if not others.is_empty() and spoke.size() < 2:
		var k: int = others[mini(int(clampf(roll, 0.0, 0.999) * others.size()), others.size() - 1)]
		out[k].line = _pick(c.get("comments", {}).get(m, []), fmod(roll * 7.31, 1.0))
	return out

static func summary(f: Dictionary, g: float, c: Dictionary) -> Dictionary:
	return {"what": String(f.what), "place": String(f.place), "hangout": String(f.hangout), "n": int(f.n), "grade": grade_text(g, c), "score": g}

static func remember(state: Dictionary, opening: Dictionary) -> void:
	if not state.get("openings") is Array: state["openings"] = []
	var o := opening.duplicate()
	o["day"] = int(state.get("time", {}).get("day", 1))
	state.openings.append(o)

static func _stand(walk: WalkWorld, p: Vector2, low: float) -> Dictionary:
	var s := walk.surface_at(p.x, p.y)
	if not s.walkable or absf(float(s.y) - low) > 1.2: return {}
	var ok := walk.can_stand(p.x, p.y, float(s.y), 0.32)
	if ok.is_empty() or walk.stuck(Vector3(p.x, float(ok.y), p.y), 0.32): return {}
	return {"x": p.x, "y": float(ok.y), "z": p.y}

static func stage(walk: WalkWorld, group: Array, crowd_n: int) -> Dictionary:
	if group.is_empty(): return {}
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	var low := INF
	for p in group:
		var b := BuildGrid.bounds(p)
		minx = minf(minx, b.minX); maxx = maxf(maxx, b.maxX); minz = minf(minz, b.minZ); maxz = maxf(maxz, b.maxZ)
		low = minf(low, float(b.bottom))
	var c := Vector2((minx + maxx) / 2.0, (minz + maxz) / 2.0)
	var half := Vector2(maxx - minx, maxz - minz).length() / 2.0
	for extra in [1.0, 1.6, 2.4]:
		var r: float = half + extra
		var ok: Array = []
		for k in 16:
			var d := Vector2(sin(k * TAU / 16.0), cos(k * TAU / 16.0))
			ok.append(not _stand(walk, c + d * r, low).is_empty() and not _stand(walk, c + d * (r + 2.5), low).is_empty())
		var front := -1
		var best := -1
		for k in 16:
			if not ok[k]: continue
			var run := 0
			for s in [1, -1]:
				for j in range(1, 5):
					if ok[(k + s * j + 16) % 16]: run += 1
					else: break
			if run > best: best = run; front = k
		if front == -1: continue
		var a: float = front * TAU / 16.0
		return _arrange(walk, group, c, low, half, r, a, crowd_n)
	return {}

static func _spot_at(walk: WalkWorld, c: Vector2, low: float, r: float, a: float, taken: Array, gap: float) -> Dictionary:
	var s := _stand(walk, c + Vector2(sin(a), cos(a)) * r, low)
	if s.is_empty(): return {}
	for t in taken:
		if Vector2(float(s.x) - t.x, float(s.z) - t.z).length() < gap: return {}
	return s

static func _arrange(walk: WalkWorld, group: Array, c: Vector2, low: float, half: float, r: float, a: float, crowd_n: int) -> Dictionary:
	var d := Vector2(sin(a), cos(a))
	var taken: Array = []
	var speaker_at := Vector3.INF
	var side := 1.0
	for off in [0.9, -0.9, 1.3, -1.3, 0.0]:
		var s := _spot_at(walk, c, low, r, a + off / r, taken, 0.8)
		if s.is_empty(): continue
		speaker_at = Vector3(float(s.x), float(s.y), float(s.z))
		side = 1.0 if off >= 0.0 else -1.0
		break
	if speaker_at == Vector3.INF: return {}
	taken.append(speaker_at)
	var player_at := Vector3.INF
	for off in [-0.9 * side, -1.3 * side, 1.8 * side, 0.0]:
		var s := _spot_at(walk, c, low, r, a + off / r, taken, 0.8)
		if not s.is_empty(): player_at = Vector3(float(s.x), float(s.y), float(s.z)); break
	if player_at != Vector3.INF: taken.append(player_at)
	var crowd: Array = []
	for ring in [1.4, 2.4, 3.4]:
		var rr: float = r + ring
		var step: float = 0.9 / rr
		var off := 0.75 + (0.0 if ring < 2.0 else step * 0.5)
		while off <= 2.3 and crowd.size() < crowd_n:
			for sd in [1.0, -1.0]:
				if crowd.size() >= crowd_n: break
				var s := _spot_at(walk, c, low, rr, a + sd * off, taken, 0.8)
				if s.is_empty(): continue
				var at := Vector3(float(s.x), float(s.y), float(s.z))
				crowd.append(at); taken.append(at)
			off += step
		if crowd.size() >= crowd_n: break
	var side_v := Vector2(d.y, -d.x)
	var cams: Array = []
	for v in [[6.5, 0.0, 2.9], [5.5, 1.6, 2.6], [7.5, -1.6, 3.2], [4.5, 0.0, 2.4], [9.0, 0.0, 3.6]]:
		var p: Vector2 = c + d * (r + float(v[0])) + side_v * float(v[1])
		cams.append(Vector3(p.x, low + float(v[2]), p.y))
	var look2 := c + d * (r * 0.3)
	var rib := c + d * maxf(r - 0.55, half + 0.35)
	return {"center": Vector3(c.x, low, c.y), "yaw": a, "radius": r, "speaker": speaker_at, "player": player_at, "crowd": crowd,
		"cams": cams, "look": Vector3(look2.x, low + 1.0, look2.y), "ribbon": Vector3(rib.x, low, rib.y), "ribbon_w": clampf(half * 1.2, 1.2, 2.4)}
