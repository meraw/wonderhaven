class_name Commission

const KINDS := ["pieces", "provides", "path", "fed", "lit", "recolored", "material", "kinds", "count", "taller", "sealed", "view"]
const BASIC := ["pieces"]

static func cfg() -> Dictionary: return Data.commissions

static func site(o: Dictionary) -> Dictionary:
	var zid := String(o.get("zone", ""))
	return Data.zone(zid) if zid != "" else {}

static func anywhere(o: Dictionary) -> bool: return String(o.get("zone", "")) == "" and String(o.get("hangout", "")) == ""

static func here(o: Dictionary, placements: Array) -> Array:
	var hid := String(o.get("hangout", ""))
	if hid != "":
		var h := Needs.hangout(Needs.hangouts(), hid)
		return placements.filter(func(p): return not h.is_empty() and Needs.inside(p, h))
	var z := site(o)
	if z.is_empty(): return placements.duplicate()
	return Validate.pieces_in_zone(z, placements)

static func site_text(o: Dictionary) -> String:
	var hid := String(o.get("hangout", ""))
	if hid != "": return String(Needs.hangout(Needs.hangouts(), hid).get("at", ""))
	if String(o.get("zone", "")) != "": return String(site(o).get("name", ""))
	return String(cfg().get("anywhere", "anywhere in the village"))

static func material(id: String) -> String:
	var cost: Dictionary = Data.piece(id).get("cost", {})
	var best := ""
	var most := -1
	for k in cost:
		if String(k) == "coins": continue
		if int(cost[k]) > most:
			most = int(cost[k])
			best = String(k)
	return best

static func recolored(p: Dictionary) -> bool:
	var col := String(p.get("color", ""))
	return col != "" and col != String(Data.piece(String(p.id)).get("color", ""))

static func _has(d: Dictionary, uid) -> bool: return d.has(uid) or d.has(int(uid)) or d.has(float(uid))

static func check(c: Dictionary, o: Dictionary, pieces: Array, ctx: Dictionary) -> Dictionary:
	var need := int(c.get("count", 1))
	var hit: Array = []
	var have := 0
	var ok := false
	var lamps: Dictionary = ctx.get("lamps", {})
	match String(c.get("check", "")):
		"pieces":
			var any: Array = c.get("any", [])
			hit = pieces.filter(func(p): return any.has(String(p.id)))
			have = hit.size()
			var with: Array = c.get("with", [])
			ok = have >= need and (with.is_empty() or hit.any(func(p): return with.has(String(p.id))))
		"provides":
			hit = pieces.filter(func(p): return Needs.gives(p, String(c.get("kind", "")), lamps))
			have = hit.size()
			ok = have >= need
		"lit":
			hit = pieces.filter(func(p): return _has(lamps, p.uid))
			have = hit.size()
			ok = have >= need
		"recolored":
			hit = pieces.filter(func(p): return recolored(p))
			have = hit.size()
			ok = have >= need
		"material":
			var of: Array = c.get("of", [])
			hit = pieces.filter(func(p): return of.has(material(String(p.id))))
			need = maxi(pieces.size(), 1)
			have = hit.size()
			ok = not pieces.is_empty() and hit.size() == pieces.size()
		"kinds":
			var seen := {}
			for p in pieces:
				if not seen.has(String(p.id)):
					seen[String(p.id)] = true
					hit.append(p)
			have = seen.size()
			ok = have >= need
		"count":
			hit = pieces.duplicate()
			have = hit.size()
			ok = have >= need
		"taller":
			var low := INF
			var top := -INF
			var tallest := {}
			for p in pieces:
				var b := BuildGrid.bounds(p)
				low = minf(low, float(b.bottom))
				if float(b.top) > top:
					top = float(b.top)
					tallest = p
			var height := (top - low) if not pieces.is_empty() else 0.0
			need = int(ceil(float(c.get("height", 1.0))))
			have = int(floor(height))
			ok = height >= float(c.get("height", 1.0)) - 0.001
			if not tallest.is_empty(): hit = [tallest]
		"path":
			need = 1
			var zid := String(c.get("zone", o.get("zone", "")))
			var on: Array = c.get("on", [])
			var r: Dictionary = {"ok": false}
			if ctx.has("path"): r = ctx.path.call(zid) if on.is_empty() else ctx.path.call(zid, covered(ctx.get("placements", pieces), on))
			ok = r.get("ok", false)
			have = 1 if ok else 0
			var cells := {}
			for cell in r.get("path", []): cells[Vector2i(int(cell.x), int(cell.y))] = true
			hit = pieces.filter(func(p): return BuildGrid.cells(p).any(func(cc): return cells.has(Vector2i(int(cc.x), int(cc.y)))))
		"sealed":
			need = 1
			var wall := Data.zone(String(c.get("zone", o.get("zone", ""))))
			ok = not wall.is_empty() and Validate.sealed(wall, ctx.get("placements", [])).sealed
			have = 1 if ok else 0
			hit = pieces.duplicate() if ok else []
		"view":
			var to: Array = c.get("to", [0.0, 0.0])
			var target := Vector2(float(to[0]), float(to[1]))
			var of: Array = c.get("of", [])
			var seats: Array = pieces.filter(func(p): return of.has(String(p.id)) if not of.is_empty() else Needs.gives(p, "seat", lamps))
			var all: Array = ctx.get("placements", pieces)
			var reach := float(c.get("reach", 40.0))
			hit = seats.filter(func(p): return sees(p, target, all, reach))
			have = hit.size()
			ok = have >= need
		"fed":
			need = 1
			ok = ctx.get("fed", {}).get(String(c.get("target", "")), false)
			have = 1 if ok else 0
			var mech: Dictionary = ctx.get("mech", {})
			hit = pieces.filter(func(p): return _has(mech.get("powered", {}), p.uid) or _has(mech.get("watered", {}), p.uid) or _has(mech.get("pumps", {}), p.uid) or _has(mech.get("sources", {}), p.uid))
	return {"label": String(c.get("label", "")), "check": String(c.get("check", "")), "ok": ok, "have": mini(have, need), "need": need,
		"uids": hit.map(func(p): return int(p.uid)), "who": String(c.get("who", ""))}

static func covered(placements: Array, ids: Array) -> Dictionary:
	var out := {}
	for p in placements:
		if not ids.has(String(p.id)): continue
		for cc in BuildGrid.cells(p): out[Vector2i(int(cc.x), int(cc.y))] = true
	return out

static func sees(seat: Dictionary, target: Vector2, placements: Array, reach: float) -> bool:
	var b := BuildGrid.bounds(seat)
	var from := Vector2((float(b.minX) + float(b.maxX)) / 2.0, (float(b.minZ) + float(b.maxZ)) / 2.0)
	var eye := float(b.bottom) + 1.1
	var dir := target - from
	var length := minf(dir.length(), reach)
	if length <= 0.0: return true
	dir = dir.normalized()
	var d := 0.6
	while d <= length:
		var p := from + dir * d
		if Heightfield.height(p.x, p.y) > eye: return false
		for bd in Data.layout.get("buildings", []):
			if not bd.get("solid", true) or not bd.has("w"): continue
			if absf(p.x - float(bd.x)) < float(bd.w) / 2.0 and absf(p.y - float(bd.z)) < float(bd.d) / 2.0: return false
		for q in placements:
			if int(q.uid) == int(seat.uid) or not Data.piece(String(q.id)).get("solid", true): continue
			var qb := BuildGrid.bounds(q)
			if p.x < float(qb.minX) or p.x > float(qb.maxX) or p.y < float(qb.minZ) or p.y > float(qb.maxZ): continue
			if float(qb.bottom) < eye and float(qb.top) > eye - 0.3: return false
		d += 0.25
	return true

static func _judge(o: Dictionary, pieces: Array, ctx: Dictionary) -> Dictionary:
	var musts: Array = o.get("musts", []).map(func(c): return check(c, o, pieces, ctx))
	var wishes: Array = o.get("wishes", []).map(func(c): return check(c, o, pieces, ctx))
	return {"musts": musts, "wishes": wishes, "done": not musts.is_empty() and musts.all(func(r): return r.ok), "met": musts.filter(func(r): return r.ok).size(),
		"wished": wishes.filter(func(r): return r.ok).size(), "uids": pieces.map(func(p): return int(p.uid))}

static func evaluate(o: Dictionary, ctx: Dictionary) -> Dictionary:
	var pieces := here(o, ctx.get("placements", []))
	if not anywhere(o) or pieces.is_empty(): return _judge(o, pieces, ctx)
	var best := {}
	for g in Inauguration.groups(pieces, float(cfg().get("together", 3.0))):
		var r := _judge(o, g, ctx)
		if best.is_empty() or _better(r, best): best = r
	return best

static func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.met) != int(b.met): return int(a.met) > int(b.met)
	if int(a.wished) != int(b.wished): return int(a.wished) > int(b.wished)
	return a.uids.size() > b.uids.size()

static func stamp(wishes: Array, c: Dictionary = {}) -> Dictionary:
	var names: Array = (c if not c.is_empty() else cfg()).get("stamps", ["Approved", "Approved with thanks", "Approved with honours"])
	var met := wishes.filter(func(r): return r.ok).size()
	var tier := 0 if met == 0 else (2 if met == wishes.size() else 1)
	return {"met": met, "of": wishes.size(), "tier": tier, "text": String(names[mini(tier, names.size() - 1)])}

static func bonus(wishes: Array, c: Dictionary = {}) -> Dictionary:
	var w: Dictionary = (c if not c.is_empty() else cfg()).get("wish", {})
	var hearts := {}
	var harmony := 0
	for r in wishes:
		if not r.ok: continue
		harmony += int(w.get("harmony", 0))
		var who := String(r.get("who", ""))
		if who != "": hearts[who] = int(hearts.get(who, 0)) + int(w.get("hearts", 0))
	return {"harmony": harmony, "hearts": hearts}

static func kinds_of(o: Dictionary, which: String = "musts") -> Array:
	var out: Array = []
	for c in o.get(which, []):
		var k := String(c.get("check", ""))
		if not out.has(k): out.append(k)
	return out
