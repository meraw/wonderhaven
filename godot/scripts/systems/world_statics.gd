class_name WorldStatics
## Decorative placement and solid colliders derived from the village layout (deterministic, same as the web version).

static func dist_to_segment(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var vx := bx - ax
	var vz := bz - az
	var l2 := vx * vx + vz * vz
	var t := clampf(((px - ax) * vx + (pz - az) * vz) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
	return Vector2(px - (ax + t * vx), pz - (az + t * vz)).length()

static func dist_to_paths(x: float, z: float) -> float:
	var d := INF
	for p in Data.layout.paths:
		for n in range(p.size() - 1):
			d = minf(d, dist_to_segment(x, z, p[n][0], p[n][1], p[n + 1][0], p[n + 1][1]))
	return d

static func _near_building(x: float, z: float, pad: float) -> bool:
	for b in Data.layout.buildings:
		if absf(x - b.x) < b.w / 2.0 + pad and absf(z - b.z) < b.d / 2.0 + pad: return true
	return false

static func _in_zone(x: float, z: float, pad: float) -> bool:
	for zn in Data.layout.zones:
		var e: Dictionary = zn.get("expanded", zn)
		if x > e.minI - pad and x < e.maxI + 1 + pad and z > e.minK - pad and z < e.maxK + 1 + pad: return true
	return false

static func _near_point(x: float, z: float, list: Array, pad: float) -> bool:
	for p in list:
		if Vector2(x - p.x, z - p.z).length() < pad: return true
	return false

static func generate_decor(seed: int = 7) -> Dictionary:
	var rng := Rng.new(seed)
	var trees: Array = []
	var bushes: Array = []
	var flowers: Array = []
	var grass: Array = []
	var points: Array = Data.layout.nodes + Data.layout.features
	var nav: Array = []
	for k in Data.layout.nav_nodes: nav.append({"x": Data.layout.nav_nodes[k][0], "z": Data.layout.nav_nodes[k][1]})
	var F: Dictionary = Data.layout.get("fountain", {"x": 1000.0, "z": 1000.0})
	var D: Dictionary = Data.layout.get("decor", {})
	var radius := float(D.get("radius", 50.0))
	# "area": [x0, z0, x1, z1] puts the greenery in that box instead of round the middle (a city's park, say).
	var area: Array = D.get("area", [])
	var boxed := not area.is_empty()
	var rx := func(lo: float, hi: float) -> float: return rng.range_f(area[0], area[2]) if boxed else rng.range_f(lo, hi)
	var rz := func(lo: float, hi: float) -> float: return rng.range_f(area[1], area[3]) if boxed else rng.range_f(lo, hi)
	var out_of_reach := func(x: float, z: float, r: float) -> bool: return not boxed and sqrt(x * x + z * z) > r
	var clear := func(x: float, z: float, pad: float) -> bool:
		var h := Heightfield.height(x, z)
		if h < Heightfield.WALKABLE_MIN + 0.25: return false
		if out_of_reach.call(x, z, radius): return false
		if Ground.paved(x, z): return false
		if Heightfield.meadow(x, z) < 0.5: return false   # a location's bare ground (stubble, mud): no trees or bushes
		if dist_to_paths(x, z) < pad + 1.2: return false
		if _near_building(x, z, pad + 1): return false
		if _in_zone(x, z, pad + 0.6): return false
		if Vector2(x - F.x, z - F.z).length() < 8 + pad: return false
		if _near_point(x, z, points, pad + 1.6) or _near_point(x, z, nav, pad + 1.4): return false
		return true
	var n := 0
	while n < 900 and trees.size() < int(D.get("trees", 95)):
		n += 1
		var x: float = rx.call(-50, 50)
		var z: float = rz.call(-48, 46)
		var r := sqrt(x * x + z * z)
		if not boxed and r < 12 and rng.next() < 0.8: continue
		if not clear.call(x, z, 0.9): continue
		var crowded := false
		for t in trees:
			if Vector2(t.x - x, t.z - z).length() < 3: crowded = true; break
		if crowded: continue
		trees.append({"x": x, "z": z, "s": rng.range_f(0.85, 1.3), "kind": "pine" if rng.next() < 0.3 else "round", "hue": rng.next()})
	# Woods: denser stands from the layout's decor.woods [{x, z, r, n, pine?}], on top of the scattered trees.
	var wi := 0
	for w in D.get("woods", []):
		wi += 1
		var placed := 0
		n = 0
		while n < int(w.n) * 25 and placed < int(w.n):
			n += 1
			var a := rng.range_f(0, TAU); var d := sqrt(rng.next()) * float(w.r)
			var x: float = float(w.x) + cos(a) * d
			var z: float = float(w.z) + sin(a) * d
			if not clear.call(x, z, 0.9): continue
			var crowded := false
			for t in trees:
				if Vector2(t.x - x, t.z - z).length() < 2.6: crowded = true; break
			if crowded: continue
			trees.append({"x": x, "z": z, "s": rng.range_f(0.95, 1.4), "kind": "pine" if rng.next() < float(w.get("pine", 0.1)) else "round", "hue": rng.next(), "wood": wi})
			placed += 1
	n = 0
	while n < 600 and bushes.size() < int(D.get("bushes", 70)):
		n += 1
		var x: float = rx.call(-48, 48)
		var z: float = rz.call(-46, 44)
		if not clear.call(x, z, 0.4): continue
		var crowded := false
		for t in trees:
			if Vector2(t.x - x, t.z - z).length() < 1.8: crowded = true; break
		if crowded: continue
		bushes.append({"x": x, "z": z, "s": rng.range_f(0.6, 1.1), "hue": rng.next()})
	n = 0
	while n < 2500 and flowers.size() < int(D.get("flowers", 520)):
		n += 1
		var x: float = rx.call(-48, 48)
		var z: float = rz.call(-46, 44)
		if Heightfield.height(x, z) < 0 or dist_to_paths(x, z) < 0.9 or _near_building(x, z, 0.3) or _in_zone(x, z, 0.2) or out_of_reach.call(x, z, 49.0) or Ground.paved(x, z): continue
		if Heightfield.meadow(x, z) < 0.5: continue
		flowers.append({"x": x, "z": z, "c": rng.int_range(0, 4), "s": rng.range_f(0.7, 1.2)})
	n = 0
	while n < 4000 and grass.size() < int(D.get("grass", 1400)):
		n += 1
		var x: float = rx.call(-49, 49)
		var z: float = rz.call(-47, 45)
		if Heightfield.height(x, z) < 0.02 or dist_to_paths(x, z) < 0.8 or _near_building(x, z, 0.1) or out_of_reach.call(x, z, 50.0) or Ground.paved(x, z): continue
		if Heightfield.meadow(x, z) < 0.5: continue
		grass.append({"x": x, "z": z, "r": rng.range_f(0, PI), "s": rng.range_f(0.6, 1.3)})
	return {"trees": trees, "bushes": bushes, "flowers": flowers, "grass": grass}

# ---- Raised floors --------------------------------------------------------------------------------------------
## Places above the ground you can walk on, and build on: a layout's "floors" and every building with a walkable
## roof ("roof_walk": true, solid up to its height "h" instead of a wall to the sky). A floor is
##   {"rect": [x0, z0, x1, z1], "top": y, "bottom"?: y (default top - 0.3, a slab you can walk under),
##    "rise"?: [y0, y1], "axis"?: "x" | "z"   (stairs: the top climbs from y0 to y1 across the rect),
##    "walkable"?: true, "solid"?: true}
## They become WalkWorld floors (game.gd), count as the ground for building (BuildGrid.ground_at), and stop
## nothing below their bottom, so you walk under a balcony but not into the block under a roof terrace. A room
## upstairs (an enterable building with "y") adds its walls here too, standing on its own storey.
static var _floors_src = null
static var _floors: Array = []

static func floors() -> Array:
	if is_same(_floors_src, Data.layout): return _floors
	_floors_src = Data.layout
	_floors = []
	for f in Data.layout.get("floors", []): _floors.append(floor_surface(f))
	for b in Data.layout.buildings:
		if Interiors.enterable(b) and b.has("y"):
			# a room with its own storey ("y": a flat off a balcony, or a shop below one at street level): its walls
			# stand on that storey only, so rooms stacked above and below keep their own doors; what it stands on is
			# the ground or a floor of the layout
			var y := float(b.y)
			for r in Interiors.walls(b):
				_floors.append({"minX": r.minX, "maxX": r.maxX, "minZ": r.minZ, "maxZ": r.maxZ, "bottom": y - 1.0, "top": y + float(r.h) + 0.6, "walkable": false, "solid": true, "tag": b.id})
			for it in Interiors.items(b):
				var st := Interiors.item_static(it)
				if st.is_empty(): continue
				if st.get("type", "") == "circle": st = {"minX": st.x - st.r, "maxX": st.x + st.r, "minZ": st.z - st.r, "maxZ": st.z + st.r}
				_floors.append({"minX": st.minX, "maxX": st.maxX, "minZ": st.minZ, "maxZ": st.maxZ, "bottom": y, "top": y + 1.2, "walkable": false, "solid": true, "tag": b.id})
			continue
		if not b.get("roof_walk", false): continue
		var base := float(b.get("y", maxf(0.0, Heightfield.height(b.x, b.z))))
		_floors.append({"minX": b.x - b.w / 2.0, "maxX": b.x + b.w / 2.0, "minZ": b.z - b.d / 2.0, "maxZ": b.z + b.d / 2.0,
			"bottom": -2.0, "top": base + float(b.h), "walkable": true, "solid": true, "tag": b.id})
	return _floors

static func floor_surface(f: Dictionary) -> Dictionary:
	var r: Array = f.rect
	var s := {"minX": minf(r[0], r[2]), "maxX": maxf(r[0], r[2]), "minZ": minf(r[1], r[3]), "maxZ": maxf(r[1], r[3]),
		"walkable": f.get("walkable", true), "solid": f.get("solid", true), "tag": String(f.get("id", "floor"))}
	if f.has("rise"):
		var y0 := float(f.rise[0]); var y1 := float(f.rise[1])
		var along_x: bool = f.get("axis", "z") == "x"
		var lo: float = s.minX if along_x else s.minZ
		var span: float = (s.maxX - s.minX) if along_x else (s.maxZ - s.minZ)
		s["top"] = maxf(y0, y1); s["bottom"] = float(f.get("bottom", minf(y0, y1) - 0.3))
		s["ramp"] = func(x: float, z: float) -> float: return lerpf(y0, y1, clampf(((x if along_x else z) - lo) / span, 0.0, 1.0))
	else:
		s["top"] = float(f.top); s["bottom"] = float(f.get("bottom", float(f.top) - 0.3))
	return s

## The highest raised floor's top at (x, z), or -INF where there's none.
static func floor_top(x: float, z: float) -> float:
	var y := -INF
	for s in floors():
		if not s.walkable or x < s.minX or x > s.maxX or z < s.minZ or z > s.maxZ: continue
		y = maxf(y, s.ramp.call(x, z) if s.has("ramp") else s.top)
	return y

static func build_statics(decor: Dictionary) -> Array:
	var out: Array = []
	for b in Data.layout.buildings:
		if not b.get("solid", true): continue   # scenery only: what you bump into there is in the layout's floors
		var minX: float = b.x - b.w / 2.0
		var maxX: float = b.x + b.w / 2.0
		var minZ: float = b.z - b.d / 2.0
		var maxZ: float = b.z + b.d / 2.0
		if b.kind == "workshop":
			var t := 0.35
			var g0: float = b.doorAt - b.doorWidth / 2.0
			var g1: float = b.doorAt + b.doorWidth / 2.0
			out.append(_box(minX, maxX, minZ, minZ + t, b.id))
			out.append(_box(minX, maxX, maxZ - t, maxZ, b.id))
			out.append(_box(minX, minX + t, minZ, maxZ, b.id))
			out.append(_box(maxX - t, maxX, minZ, g0, b.id))
			out.append(_box(maxX - t, maxX, g1, maxZ, b.id))
		elif Interiors.enterable(b):
			if b.has("y"): continue   # an upstairs room's walls and furniture are floors (floors()), on its own storey
			for r in Interiors.walls(b): out.append(_box(r.minX, r.maxX, r.minZ, r.maxZ, b.id))
			if b.interior.get("shell", "house") == "castle":
				for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: out.append({"type": "circle", "x": b.x + c[0] * b.w / 2.0, "z": b.z + c[1] * b.d / 2.0, "r": 1.15, "tag": b.id})
			for it in Interiors.items(b):
				var st := Interiors.item_static(it)
				if st.is_empty(): continue
				if st.get("type", "") == "circle": st["tag"] = b.id; out.append(st)
				else: out.append(_box(st.minX, st.maxX, st.minZ, st.maxZ, b.id))
		elif not b.get("roof_walk", false):   # a walkable roof is a raised floor instead (floors())
			out.append(_box(minX, maxX, minZ, maxZ, b.id))
	if Data.layout.has("fountain"):
		var F: Dictionary = Data.layout.fountain
		out.append({"type": "circle", "x": F.x, "z": F.z, "r": F.r + 0.2, "tag": "fountain"})
	for c in Data.layout.get("harbor_cliffs", []): out.append(_box(c.minX, c.maxX, c.minZ, c.maxZ, "cliff"))
	if Data.layout.has("harbor_gate"):
		var G: Dictionary = Data.layout.harbor_gate
		var gate := _box(G.minX, G.maxX, G.minZ, G.maxZ, "gate"); gate["flag"] = G.flag
		out.append(gate)
	for pr in Data.layout.get("props", []):   # solid scenery (lamp posts, crates, barrels...)
		if not pr.get("solid", true) or pr.kind == "pier": continue
		if pr.has("w"):   # a box w x d (a parked bus, a stretch of ruined wall), turned by r radians
			var c := cos(float(pr.get("r", 0.0))); var sn := sin(float(pr.get("r", 0.0)))
			var hw := absf(c) * float(pr.w) / 2.0 + absf(sn) * float(pr.d) / 2.0
			var hd := absf(sn) * float(pr.w) / 2.0 + absf(c) * float(pr.d) / 2.0
			out.append(_box(pr.x - hw, pr.x + hw, pr.z - hd, pr.z + hd, "prop"))
		else: out.append({"type": "circle", "x": pr.x, "z": pr.z, "r": float(pr.get("rad", 0.3)), "tag": "prop"})
	for nd in Data.layout.nodes:
		if nd.kind in ["chop", "fruit", "shake"]: out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.45, "tag": nd.id})
		elif nd.kind == "mine": out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.75, "tag": nd.id})
		elif nd.kind == "chest": out.append(_box(nd.x - 0.45, nd.x + 0.45, nd.z - 0.32, nd.z + 0.32, nd.id))
		elif nd.kind == "bin": out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.65, "tag": nd.id})
	for f in Data.layout.features:
		if f.kind in ["sign", "board", "wardrobe", "stop"]: out.append({"type": "circle", "x": f.x, "z": f.z, "r": 0.3, "tag": f.id})
		if f.kind == "boat" and f.get("model", "boat") == "bus":   # the bus you travel on: solid once it's there
			var hl := float(f.get("length", 8.6)) / 2.0 + 0.1; var hw := 1.25
			var turned := absf(sin(float(f.get("rot", 0.0)))) > 0.7
			var bx := _box(f.x - (hw if turned else hl), f.x + (hw if turned else hl), f.z - (hl if turned else hw), f.z + (hl if turned else hw), f.id)
			if f.has("flag"): bx["whileFlag"] = f.flag
			out.append(bx)
		if f.kind == "bench":
			var st := Interiors.item_static({"piece": true, "id": "bench", "x": f.x, "z": f.z, "r": int(f.get("r", 0))})
			out.append(_box(st.minX, st.maxX, st.minZ, st.maxZ, f.id))
	for t in decor.trees: out.append({"type": "circle", "x": t.x, "z": t.z, "r": 0.42 * t.s, "tag": "tree"})
	return out

static func _box(a: float, b: float, c: float, d: float, tag: String) -> Dictionary:
	return {"type": "box", "minX": a, "maxX": b, "minZ": c, "maxZ": d, "tag": tag}
