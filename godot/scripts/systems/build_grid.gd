class_name BuildGrid
## Construction rules: footprints, rotation, snapping height, support, collisions, zones. Pure (no nodes).
## A placement is {uid, id, i, k, r, y, color?, state?}; cell (i, k) spans x i..i+1, z k..k+1.

const SIDES := ["N", "E", "S", "W"]
const SIDE_DIR := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}
const MAX_HEIGHT := 7.0
const EPS := 0.02
const FREEBOARD := 0.35   # how far a floating piece (placeOn "water") stands out of the water

static func rot_side(side: String, r: int) -> String: return SIDES[(SIDES.find(side) + r) % 4]
static func def(id: String) -> Dictionary: return Data.piece(id)

static func footprint(d: Dictionary, r: int) -> Vector2:
	return Vector2(d.size[1], d.size[0]) if r % 2 == 1 else Vector2(d.size[0], d.size[1])

static func local_to_world(d: Dictionary, pl: Dictionary, u: float, v: float) -> Vector2:
	var fp := footprint(d, int(pl.r))
	var x: float = u - d.size[0] / 2.0
	var z: float = v - d.size[1] / 2.0
	for n in int(pl.r):
		var t := x; x = -z; z = t
	return Vector2(pl.i + fp.x / 2.0 + x, pl.k + fp.y / 2.0 + z)

static func world_to_local(d: Dictionary, pl: Dictionary, x: float, z: float) -> Vector2:
	var fp := footprint(d, int(pl.r))
	var lx: float = x - (pl.i + fp.x / 2.0)
	var lz: float = z - (pl.k + fp.y / 2.0)
	for n in int(pl.r):
		var t := lx; lx = lz; lz = -t
	return Vector2(lx + d.size[0] / 2.0, lz + d.size[1] / 2.0)

static func local_box(d: Dictionary) -> Array:
	if d.get("attach", "") == "wall": return [0.15, 0.19, 0.85, 0.26]
	return d.get("box", [0, 0, d.size[0], d.size[1]])

static func rect_of(d: Dictionary, pl: Dictionary, box = null) -> Dictionary:
	var b: Array = box if box != null else local_box(d)
	var a := local_to_world(d, pl, b[0], b[1])
	var c := local_to_world(d, pl, b[2], b[3])
	return {"minX": minf(a.x, c.x), "maxX": maxf(a.x, c.x), "minZ": minf(a.y, c.y), "maxZ": maxf(a.y, c.y)}

static func bounds(pl: Dictionary) -> Dictionary:
	var d := def(pl.id)
	var r := rect_of(d, pl)
	r["bottom"] = float(pl.y); r["top"] = float(pl.y) + float(d.h)
	return r

static func cells(pl: Dictionary) -> Array:
	var fp := footprint(def(pl.id), int(pl.r))
	var out: Array = []
	for a in int(fp.x):
		for b in int(fp.y): out.append(Vector2(pl.i + a, pl.k + b))
	return out

static func overlap2(a: Dictionary, b: Dictionary, e: float = EPS) -> bool:
	return a.minX < b.maxX - e and a.maxX > b.minX + e and a.minZ < b.maxZ - e and a.maxZ > b.minZ + e
static func overlap3(a: Dictionary, b: Dictionary) -> bool:
	return overlap2(a, b) and a.bottom < b.top - EPS and a.top > b.bottom + EPS
## The ground a piece in cell (i, k) rests on: the terrain, or a raised floor above it (a roof terrace, a balcony).
static func ground_at(i: float, k: float) -> float: return maxf(Heightfield.height(i + 0.5, k + 0.5), WorldStatics.floor_top(i + 0.5, k + 0.5))

## Does a piece's footprint reach inside one of the place's buildings (an open area like the village streets doesn't
## take in people's rooms; a site that is a room, like Elio's shop, is its own zone)?
static func _in_a_building(b: Dictionary) -> bool:
	for bd in Data.layout.get("buildings", []):
		if not bd.has("w"): continue
		var r := {"minX": float(bd.x) - float(bd.w) / 2.0, "maxX": float(bd.x) + float(bd.w) / 2.0, "minZ": float(bd.z) - float(bd.d) / 2.0, "maxZ": float(bd.z) + float(bd.d) / 2.0}
		if overlap2(b, r, 0.05): return true
	return false

# ---- Zones
## A zone may grow (`expanded`, at `expanded.harmony`): measured on the place's progress, the approval rating or the
## place's own meter where it has one (LocationMeter.progress).
static func zone_bounds(zone: Dictionary, harmony: float = 0) -> Dictionary:
	if zone.has("expanded") and harmony >= zone.expanded.harmony: return zone.expanded
	return zone
static func zone_contains(zone: Dictionary, i: float, k: float, harmony: float = 0) -> bool:
	var b := zone_bounds(zone, harmony)
	return i >= b.minI and i <= b.maxI and k >= b.minK and k <= b.maxK
static func zone_at(zones: Array, i: float, k: float, harmony: float = 0) -> Dictionary:
	for z in zones:
		if zone_contains(z, i, k, harmony): return z
	return {}

static func _supports_top(pl_def: Dictionary, q: Dictionary) -> bool:
	var qd := def(q.id)
	return qd.get("walkable", false) or (pl_def.get("needsSupport", false) and (qd.get("edge", false) or q.id == "pillar"))

## Where a piece rests if the cursor is over cell (i, k) and the ray hit height hit_y.
static func suggest_bottom(id: String, i: float, k: float, r: int, hit_y: float, placements: Array, zone: Dictionary = {}) -> float:
	var d := def(id)
	var probe := {"id": id, "i": i, "k": k, "r": r, "y": 0.0}
	var rect := rect_of(d, probe, [0, 0, d.size[0], d.size[1]])
	var g := -INF
	for c in cells(probe): g = maxf(g, ground_at(c.x, c.y))
	if d.get("placeOn", "") == "stream": return Heightfield.WATER_Y + 0.05
	if d.get("placeOn", "") == "water": return float_bottom(d)
	var base := g
	if d.get("span", false) and g < Heightfield.WALKABLE_MIN and zone.has("spanY"): base = zone.spanY
	var stack_top := -INF
	for q in placements:
		if not _supports_top(d, q): continue
		var qt: float = q.y + def(q.id).h
		if qt > hit_y + 0.35: continue
		if overlap2(rect, bounds(q), 0.05): stack_top = maxf(stack_top, qt)
	if stack_top > -INF and stack_top >= base - 0.01: base = stack_top
	return base

## Where a floating piece's bottom sits: low in the water, its top FREEBOARD above it.
static func float_bottom(d: Dictionary) -> float: return Heightfield.WATER_Y + FREEBOARD - float(d.h)

## Is every cell under the piece open water (a river, a pond, a backwater)?
static func _on_water(pl: Dictionary) -> bool:
	for c in cells(pl):
		if ground_at(c.x, c.y) >= Heightfield.WALKABLE_MIN: return false
	return true

# ---- Support
static func _rests_on(pl: Dictionary, q: Dictionary) -> bool:
	var d := def(pl.id)
	if not _supports_top(d, q): return false
	if absf(q.y + def(q.id).h - pl.y) > 0.05: return false
	return overlap2(rect_of(d, pl, [0, 0, d.size[0], d.size[1]]), bounds(q), 0.05)

static func _over_water(pl: Dictionary) -> bool:
	for c in cells(pl):
		if ground_at(c.x, c.y) < Heightfield.WALKABLE_MIN: return true
	return _edge_over_water(pl)

## A piece that stands on one edge of its cell (a railing, a wall, a fence): is any of that edge over water? The cell's
## middle can be dry bank while its edge is already in the stream.
static func _edge_over_water(pl: Dictionary) -> bool:
	var d := def(pl.id)
	if not d.get("edge", false): return false
	var r := rect_of(d, pl)
	var cx: float = (r.minX + r.maxX) / 2.0; var cz: float = (r.minZ + r.maxZ) / 2.0
	var along_x: bool = r.maxX - r.minX >= r.maxZ - r.minZ
	for t in [-0.4, 0.0, 0.4]:
		var x: float = cx + (t * (r.maxX - r.minX) if along_x else 0.0)
		var z: float = cz + (0.0 if along_x else t * (r.maxZ - r.minZ))
		if maxf(Heightfield.height(x, z), WorldStatics.floor_top(x, z)) < Heightfield.WALKABLE_MIN: return true
	return false

static func _base_supported(pl: Dictionary, placements: Array, sup: Dictionary, env: Dictionary) -> bool:
	var d := def(pl.id)
	if d.get("attach", "") == "wall":
		for q in placements:
			var qd := def(q.id)
			if sup.has(q.uid) and qd.get("edge", false) and qd.h >= 2 and q.i == pl.i and q.k == pl.k and int(q.r) == int(pl.r): return true
		return false
	if d.get("placeOn", "") == "stream":
		for c in cells(pl):
			if not Heightfield.is_stream_cell(c.x, c.y): return false
		return true
	if d.get("placeOn", "") == "water": return _on_water(pl) and absf(float(pl.y) - float_bottom(d)) < 0.05   # it floats
	for q in placements:
		if not is_same(q, pl) and sup.has(q.uid) and _rests_on(pl, q): return true
	if d.get("span", false) and env.get("fixed", {}).has("%d,%d" % [int(pl.i), int(pl.k)]) and absf(pl.y - env.get("spanY", 0.0)) < 0.1: return true
	if d.get("needsSupport", false): return false
	var g := -INF
	var wet := false
	for c in cells(pl):
		var h := ground_at(c.x, c.y)
		g = maxf(g, h)
		if h < Heightfield.WALKABLE_MIN: wet = true
	return absf(pl.y - g) < 0.08 and (not wet or d.get("post", false))

## Returns {supported: {uid: true}, chain: {uid: distance}}
static func compute_support(placements: Array, env: Dictionary = {}) -> Dictionary:
	var sup := {}
	var chain := {}
	for guard in 30:
		var changed := false
		for pl in placements:
			if not sup.has(pl.uid) and _base_supported(pl, placements, sup, env): sup[pl.uid] = true; changed = true
		var spans := placements.filter(func(p): return def(p.id).get("span", false))
		var dist := {}
		var queue: Array = []
		for a in spans:
			if sup.has(a.uid) and not chain.has(a.uid): dist[a.uid] = 0; queue.append(a)
		while not queue.is_empty():
			var p: Dictionary = queue.pop_front()
			var dd: int = dist[p.uid]
			if dd >= Data.span_limit: continue
			for n in spans:
				if dist.has(n.uid) or absf(n.i - p.i) + absf(n.k - p.k) != 1 or absf(n.y - p.y) > 0.3: continue
				if not _over_water(n) and not sup.has(n.uid): continue
				dist[n.uid] = dd + 1; queue.append(n)
		for uid in dist:
			if not sup.has(uid): sup[uid] = true; chain[uid] = dist[uid]; changed = true
		if not changed: break
	return {"supported": sup, "chain": chain}

static func _env_for(zone: Dictionary) -> Dictionary:
	var fixed := {}
	for s in zone.get("fixedSupports", []): fixed["%d,%d" % [int(s[0]), int(s[1])]] = true
	return {"fixed": fixed, "spanY": zone.get("spanY", 0.0)}

static func _shrink(b: Dictionary, e: float) -> Dictionary:
	return {"minX": b.minX + e, "maxX": b.maxX - e, "minZ": b.minZ + e, "maxZ": b.maxZ - e}

## ctx: {placements, zones, locked_zones?, harmony, statics, flags, bodies: [{x, z, r, y, name?}]}
static func validate_placement(pl: Dictionary, ctx: Dictionary) -> Dictionary:
	var d := def(pl.id)
	if d.is_empty(): return {"ok": false, "reason": "Unknown piece"}
	# pieces this place rules out, each with its reason (a layout's "noBuild": a city where every bed is sold out)
	var ruled: Dictionary = ctx.get("no_build", {})
	if ruled.has(pl.id): return {"ok": false, "reason": String(ruled[pl.id])}
	var cs := cells(pl)
	var harmony: float = ctx.get("harmony", 0)
	var zone := zone_at(ctx.get("zones", []), cs[0].x, cs[0].y, harmony)
	var inside := not zone.is_empty()
	if inside:
		for c in cs:
			if not zone_contains(zone, c.x, c.y, harmony): inside = false
	if not inside:
		var locked := zone_at(ctx.get("locked_zones", []), cs[0].x, cs[0].y, harmony)
		return {"ok": false, "reason": ("%s isn't open for building yet" % locked.name) if not locked.is_empty() else "Outside a building area — look for the glowing grid"}
	var b := bounds(pl)
	if zone.get("open", false) and _in_a_building(b): return {"ok": false, "reason": "That's inside someone's building. Build out in the street"}
	if b.top - float(zone.get("floorY", 0.0)) > MAX_HEIGHT: return {"ok": false, "reason": "Too high to build safely"}   # floorY: a site up on a roof
	var env := _env_for(zone)
	if d.get("placeOn", "") == "stream":
		for c in cs:
			if not Heightfield.is_stream_cell(c.x, c.y): return {"ok": false, "reason": "A waterwheel needs flowing water underneath"}
	if d.get("placeOn", "") == "water" and not _on_water(pl): return {"ok": false, "reason": "A %s floats: put it on open water" % String(d.name).to_lower()}
	var placements: Array = ctx.placements
	if not d.get("span", false) and not d.get("post", false) and not d.get("placeOn", "") in ["stream", "water"] and d.get("attach", "") != "wall":
		var on_piece := false
		for q in placements:
			if q.uid != pl.uid and _rests_on(pl, q): on_piece = true; break
		if not on_piece and _over_water(pl): return {"ok": false, "reason": "That would sink! Use bridge planks and posts over water"}
	for q in placements:
		if q.uid == pl.uid: continue
		if overlap3(b, bounds(q)): return {"ok": false, "reason": "Bumps into the %s" % String(def(q.id).name).to_lower()}
	var flags: Dictionary = ctx.get("flags", {})
	for s in ctx.get("statics", []):
		if s.has("flag") and flags.get(s.flag, false): continue
		var hit := WalkWorld.circle_box(s.x, s.z, s.r, _shrink(b, 0.05)) if s.type == "circle" else overlap2(b, s, 0.05)
		if hit: return {"ok": false, "reason": "Something is already in the way there"}
	if d.get("solid", true) and not (d.get("walkable", false) and d.h <= WalkWorld.STEP_UP):
		for body in ctx.get("bodies", []):
			if b.bottom < body.get("y", 0.0) + 1.2 and WalkWorld.circle_box(body.x, body.z, body.r, _shrink(b, 0.05)):
				return {"ok": false, "reason": ("%s is standing there" % body.name) if body.has("name") else "You're standing there!"}
	if not _supported(pl, placements, env, ctx, String(zone.get("id", ""))):
		if d.get("span", false): return {"ok": false, "reason": "Too far from a support — planks reach %d tiles. Add a bridge post, or build out from the other bank" % Data.span_limit}
		if d.get("attach", "") == "wall": return {"ok": false, "reason": "Paintings hang on walls"}
		if d.get("needsSupport", false): return {"ok": false, "reason": "Roofs need walls or pillars underneath"}
		return {"ok": false, "reason": "Needs something solid underneath"}
	return {"ok": true, "zone": zone}

static func _supported(pl: Dictionary, placements: Array, env: Dictionary, ctx: Dictionary, zone_id: String) -> bool:
	var others := placements.filter(func(q): return q.uid != pl.uid)
	var memo = ctx.get("support_memo")
	if memo is Dictionary:
		var key := "%s|%d" % [zone_id, int(pl.uid)]
		if not memo.has(key): memo[key] = support_cache(others, env)
		return supported_with(pl, others, memo[key], env)
	var all := others.duplicate()
	all.append(pl)
	return compute_support(all, env).supported.has(pl.uid)

static func support_cache(placements: Array, env: Dictionary = {}) -> Dictionary:
	var res := compute_support(placements, env)
	var sup: Dictionary = res.supported
	var chain: Dictionary = res.chain
	var spans := placements.filter(func(p): return def(p.id).get("span", false))
	var dist := {}
	var queue: Array = []
	for a in spans:
		if sup.has(a.uid) and not chain.has(a.uid): dist[a.uid] = 0; queue.append(a)
	while not queue.is_empty():
		var p: Dictionary = queue.pop_front()
		var dd: int = dist[p.uid]
		if dd >= Data.span_limit: continue
		for n in spans:
			if dist.has(n.uid) or absf(n.i - p.i) + absf(n.k - p.k) != 1 or absf(n.y - p.y) > 0.3: continue
			if not _over_water(n) and not sup.has(n.uid): continue
			dist[n.uid] = dd + 1; queue.append(n)
	return {"supported": sup, "chain": chain, "dist": dist}

static func supported_with(pl: Dictionary, placements: Array, cache: Dictionary, env: Dictionary = {}) -> bool:
	if _base_supported(pl, placements, cache.supported, env): return true
	if not def(pl.id).get("span", false) or not _over_water(pl): return false
	for n in placements:
		if not cache.dist.has(n.uid) or int(cache.dist[n.uid]) >= Data.span_limit: continue
		if absf(n.i - pl.i) + absf(n.k - pl.k) == 1 and absf(n.y - pl.y) <= 0.3: return true
	return false

static func spot(id: String, i: float, k: float, r: int, ctx: Dictionary, hit_y: float = 999.0) -> Dictionary:
	var zone := zone_at(ctx.get("zones", []), i, k, ctx.get("harmony", 0))
	var y := suggest_bottom(id, i, k, r, hit_y, ctx.placements, zone)
	var pl := {"uid": int(ctx.get("uid", -1)), "id": id, "i": i, "k": k, "r": r, "y": y}
	var v := validate_placement(pl, ctx)
	v["pl"] = pl
	return v

static func edge_rotation(d: Dictionary, i: float, k: float, point: Vector3, fallback: int) -> int:
	var off := Vector2(point.x - (i + 0.5), point.z - (k + 0.5))
	if off.length() < 0.18: return fallback
	var best := fallback
	var best_dot := -INF
	for r in 4:
		var rc := rect_of(d, {"i": i, "k": k, "r": r})
		var c := Vector2((rc.minX + rc.maxX) / 2.0 - (i + 0.5), (rc.minZ + rc.maxZ) / 2.0 - (k + 0.5))
		var dot := c.normalized().dot(off.normalized())
		if dot > best_dot + 0.001: best_dot = dot; best = r
	return best

static func validate_removal(uid: int, ctx: Dictionary) -> Dictionary:
	var placements: Array = ctx.placements
	var target := {}
	for p in placements:
		if p.uid == uid: target = p
	if target.is_empty(): return {"ok": false, "reason": "Nothing there"}
	var zone := zone_at(ctx.get("zones", []), target.i, target.k, ctx.get("harmony", 0))
	var env := _env_for(zone)
	var before: Dictionary = compute_support(placements, env).supported
	var rest := placements.filter(func(p): return p.uid != uid)
	var after: Dictionary = compute_support(rest, env).supported
	for p in rest:
		if before.has(p.uid) and not after.has(p.uid):
			return {"ok": false, "reason": "The %s rests on it — remove that first" % String(def(p.id).name).to_lower()}
	return {"ok": true}

## Walk surfaces and colliders produced by placed pieces.
static func surfaces_for(placements: Array) -> Array:
	var out: Array = []
	for pl in placements:
		var d := def(pl.id)
		if d.has("attach"): continue
		var b := bounds(pl)
		if d.get("door", false):
			var posts := [[0, 0, 0.14, 0.18], [0.86, 0, 1, 0.18]]
			if not pl.get("state", {}).get("open", false): posts.append([0.14, 0, 0.86, 0.18])
			for bx in posts:
				var s := rect_of(d, pl, bx); s.merge({"bottom": b.bottom, "top": b.top, "walkable": false, "solid": true, "uid": pl.uid}); out.append(s)
			var lintel := rect_of(d, pl, [0, 0, 1, 0.18]); lintel.merge({"bottom": b.bottom + 1.95, "top": b.top, "walkable": false, "solid": true, "uid": pl.uid}); out.append(lintel)
			continue
		var s := b.duplicate()
		s.merge({"walkable": d.get("walkable", false), "solid": d.get("solid", true), "uid": pl.uid})
		if d.get("ramp", false):
			var pdef := d; var ppl: Dictionary = pl
			s["ramp"] = func(x: float, z: float) -> float:
				var lv := world_to_local(pdef, ppl, x, z)
				var t := 1.0 - clampf(lv.y / pdef.size[1], 0.0, 1.0)
				return ppl.y + pdef.h * t
		if not d.get("solid", true) and not d.get("walkable", false): continue
		out.append(s)
	return out
