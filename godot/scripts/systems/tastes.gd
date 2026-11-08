class_name Tastes

static func defs() -> Dictionary: return Data.tastes.get("tastes", {})

static func of(id: String) -> Dictionary: return defs().get(id, {})

static func here() -> Array:
	var people: Array = Data.npcs_here().map(func(n): return String(n.id))
	return defs().keys().filter(func(id): return people.has(String(id)))

static func near_pos(id: String) -> Vector2:
	var n = of(id).get("near", null)
	if n is Array and n.size() >= 2: return Vector2(float(n[0]), float(n[1]))
	var h := Needs.hangout(Needs.hangouts(), String(n))
	return Vector2(float(h.x), float(h.z)) if not h.is_empty() else Vector2.INF

static func record(state: Dictionary) -> Dictionary:
	if not state.get("tastes") is Dictionary: state["tastes"] = {}
	var r: Dictionary = state.tastes
	if not r.get("known") is Dictionary: r["known"] = {}
	if not r.get("day") is Dictionary: r["day"] = {}
	return r

static func likes(id: String, pl: Dictionary) -> String:
	var t := of(id)
	if t.is_empty(): return ""
	if t.get("pieces", []).has(String(pl.id)): return "piece"
	var col := String(pl.get("color", ""))
	if col != "" and t.get("colours", []).has(col) and Commission.recolored(pl): return "colour"
	return ""

static func near(id: String, pl: Dictionary) -> bool:
	var p := near_pos(id)
	return p != Vector2.INF and Needs.center(pl).distance_to(p) <= float(Data.tastes.get("radius", 8.0))

static func fans(pieces: Array) -> Dictionary:
	var out := {}
	for id in here():
		for p in pieces:
			if likes(String(id), p) != "" and near(String(id), p):
				out[String(id)] = line(String(id), p)
				break
	return out

static func pleased(state: Dictionary, pl: Dictionary, present: Array = []) -> Array:
	var r := record(state)
	var day := int(state.get("time", {}).get("day", 1))
	var out: Array = []
	for id in here():
		if not present.is_empty() and not present.has(String(id)): continue
		if int(r.day.get(String(id), 0)) == day: continue
		if likes(String(id), pl) == "" or not near(String(id), pl): continue
		r.day[String(id)] = day
		r.known[String(id)] = true
		out.append({"npc": String(id), "line": line(String(id), pl)})
	return out

static func line(id: String, pl: Dictionary) -> String:
	return String(of(id).get("line", "")).replace("{piece}", String(Data.piece(String(pl.id)).get("name", pl.id)).to_lower())

static func gossip(state: Dictionary, roll: float) -> Dictionary:
	var r := record(state)
	var unknown: Array = here().filter(func(id): return not r.known.has(String(id)))
	if unknown.is_empty(): return {}
	unknown.sort()
	var id := String(unknown[mini(int(clampf(roll, 0.0, 0.999) * unknown.size()), unknown.size() - 1)])
	return {"id": id, "text": String(of(id).get("gossip", ""))}

static func learn(state: Dictionary, id: String) -> void: record(state).known[id] = true

static func known(state: Dictionary, id: String) -> bool: return record(state).known.has(id)

static func describe(id: String) -> String:
	var t := of(id)
	var names: Array = t.get("pieces", []).map(func(p): return Inauguration.noun(String(p), 2, Inauguration.cfg()).trim_prefix("two "))
	var cols: int = t.get("colours", []).size()
	return Inauguration.join_and(names) + (" · a favourite colour" if cols == 1 else (" · favourite colours" if cols > 1 else ""))
