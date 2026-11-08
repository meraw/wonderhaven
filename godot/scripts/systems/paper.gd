class_name MorningPaper

static func _pick(list: Array, roll: float) -> String:
	if list.is_empty(): return ""
	return String(list[mini(int(roll * list.size()), list.size() - 1)])

static func headline(rec: Dictionary, data: Dictionary, quests: Array, roll: float) -> String:
	var done: Array = rec.get("quests", [])
	if not done.is_empty():
		var q: Dictionary = {}
		for d in quests:
			if done.has(String(d.get("id", ""))) and (q.is_empty() or d.get("main", false)): q = d
		if not q.is_empty():
			if q.has("headline"): return String(q.headline)
			return _pick(data.get("done", []), roll).replace("{title}", String(q.get("title", "")))
	var op: Dictionary = rec.get("opened", {}) if rec.get("opened") is Dictionary else {}
	if not op.is_empty() and not data.get("opened", []).is_empty():
		var w := String(op.get("what", ""))
		return _pick(data.opened, roll).replace("{What}", w.substr(0, 1).to_upper() + w.substr(1)).replace("{what}", w).replace("{place}", String(op.get("place", "")))
	var n := int(rec.get("built", 0))
	if n > 0: return _pick(data.get("built", []), roll).replace("{n}", str(n))
	return _pick(data.get("quiet", []), roll)

static func notes(rec: Dictionary, ctx: Dictionary, data: Dictionary) -> Array:
	var out: Array = []
	for n in ctx.get("noticed", []): out.append(String(data.get("noticed", "Noticed: {line}")).replace("{line}", String(n)) if out.is_empty() else String(n))
	var op: Dictionary = rec.get("opened", {}) if rec.get("opened") is Dictionary else {}
	if not op.is_empty(): out.append(String(data.get("verdict", "")).replace("{grade}", String(op.get("grade", ""))))
	var change := int(ctx.get("harmony", 0)) - int(rec.get("harmony", 0))
	if change != 0:
		out.append(String(data.get("approval", "")).replace("{n}", str(int(ctx.get("harmony", 0)))).replace("{change}", ("+%d" % change) if change > 0 else str(change)))
	if String(ctx.get("lead", "")) != "": out.append(String(data.get("lead", "")).replace("{name}", String(ctx.lead)))
	if String(ctx.get("draft", "")) != "": out.append(String(data.get("draft", "")).replace("{items}", String(ctx.draft)))
	if int(rec.get("gathered", 0)) > 0: out.append(String(data.get("regrown", "")))
	var w := String(data.get("weather", {}).get(String(ctx.get("weather", "")), ""))
	if w != "": out.append(w)
	return out.filter(func(s): return s != "").slice(0, maxi(3, ctx.get("noticed", []).size() + 1))

static func compose(rec: Dictionary, ctx: Dictionary, data: Dictionary, quests: Array, roll: float) -> Dictionary:
	return {"title": "%s · Day %d" % [String(ctx.get("paper", "The paper")), int(ctx.get("day", 1))], "headline": headline(rec, data, quests, roll), "notes": notes(rec, ctx, data)}
