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
	var n := int(rec.get("built", 0))
	if n > 0: return _pick(data.get("built", []), roll).replace("{n}", str(n))
	return _pick(data.get("quiet", []), roll)

static func notes(rec: Dictionary, ctx: Dictionary, data: Dictionary) -> Array:
	var out: Array = []
	var change := int(ctx.get("harmony", 0)) - int(rec.get("harmony", 0))
	if change != 0:
		out.append(String(data.get("approval", "")).replace("{n}", str(int(ctx.get("harmony", 0)))).replace("{change}", ("+%d" % change) if change > 0 else str(change)))
	if String(ctx.get("lead", "")) != "": out.append(String(data.get("lead", "")).replace("{name}", String(ctx.lead)))
	if String(ctx.get("draft", "")) != "": out.append(String(data.get("draft", "")).replace("{items}", String(ctx.draft)))
	if int(rec.get("gathered", 0)) > 0: out.append(String(data.get("regrown", "")))
	var w := String(data.get("weather", {}).get(String(ctx.get("weather", "")), ""))
	if w != "": out.append(w)
	return out.filter(func(s): return s != "").slice(0, 3)

static func compose(rec: Dictionary, ctx: Dictionary, data: Dictionary, quests: Array, roll: float) -> Dictionary:
	return {"title": "%s · Day %d" % [String(ctx.get("paper", "The paper")), int(ctx.get("day", 1))], "headline": headline(rec, data, quests, roll), "notes": notes(rec, ctx, data)}
