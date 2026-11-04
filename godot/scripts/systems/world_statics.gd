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
	var hearth := Data.island == "hearthglow"
	var clear := func(x: float, z: float, pad: float) -> bool:
		var h := Heightfield.height(x, z)
		if h < Heightfield.WALKABLE_MIN + 0.25: return false
		if Heightfield.meadow(x, z) < 0.5: return false   # a location's bare ground (stubble, paving): no trees or bushes
		if sqrt(x * x + z * z) > radius: return false
		if dist_to_paths(x, z) < pad + 1.2: return false
		if _near_building(x, z, pad + 1): return false
		if _in_zone(x, z, pad + 0.6): return false
		if Vector2(x - F.x, z - F.z).length() < 8 + pad: return false
		if _near_point(x, z, points, pad + 1.6) or _near_point(x, z, nav, pad + 1.4): return false
		if hearth and z > 33 and z < 37: return false   # Hearthglow's harbor wall
		return true
	var n := 0
	while n < 900 and trees.size() < int(D.get("trees", 95)):
		n += 1
		var x := rng.range_f(-50, 50)
		var z := rng.range_f(-48, 46)
		var r := sqrt(x * x + z * z)
		if r < 12 and rng.next() < 0.8: continue
		if not clear.call(x, z, 0.9): continue
		var crowded := false
		for t in trees:
			if Vector2(t.x - x, t.z - z).length() < 3: crowded = true; break
		if crowded: continue
		trees.append({"x": x, "z": z, "s": rng.range_f(0.85, 1.3), "kind": "pine" if rng.next() < 0.3 else "round", "hue": rng.next()})
	n = 0
	while n < 600 and bushes.size() < int(D.get("bushes", 70)):
		n += 1
		var x := rng.range_f(-48, 48)
		var z := rng.range_f(-46, 44)
		if not clear.call(x, z, 0.4): continue
		var crowded := false
		for t in trees:
			if Vector2(t.x - x, t.z - z).length() < 1.8: crowded = true; break
		if crowded: continue
		bushes.append({"x": x, "z": z, "s": rng.range_f(0.6, 1.1), "hue": rng.next()})
	n = 0
	while n < 2500 and flowers.size() < int(D.get("flowers", 520)):
		n += 1
		var x := rng.range_f(-48, 48)
		var z := rng.range_f(-46, 44)
		if Heightfield.height(x, z) < 0 or dist_to_paths(x, z) < 0.9 or _near_building(x, z, 0.3) or _in_zone(x, z, 0.2) or sqrt(x * x + z * z) > 49: continue
		if Heightfield.meadow(x, z) < 0.5: continue
		flowers.append({"x": x, "z": z, "c": rng.int_range(0, 4), "s": rng.range_f(0.7, 1.2)})
	n = 0
	while n < 4000 and grass.size() < 1400:
		n += 1
		var x := rng.range_f(-49, 49)
		var z := rng.range_f(-47, 45)
		if Heightfield.height(x, z) < 0.02 or dist_to_paths(x, z) < 0.8 or _near_building(x, z, 0.1) or sqrt(x * x + z * z) > 50: continue
		if Heightfield.meadow(x, z) < 0.5: continue
		grass.append({"x": x, "z": z, "r": rng.range_f(0, PI), "s": rng.range_f(0.6, 1.3)})
	return {"trees": trees, "bushes": bushes, "flowers": flowers, "grass": grass}

static func build_statics(decor: Dictionary) -> Array:
	var out: Array = []
	for b in Data.layout.buildings:
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
			for r in Interiors.walls(b): out.append(_box(r.minX, r.maxX, r.minZ, r.maxZ, b.id))
			if b.interior.get("shell", "house") == "castle":
				for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: out.append({"type": "circle", "x": b.x + c[0] * b.w / 2.0, "z": b.z + c[1] * b.d / 2.0, "r": 1.15, "tag": b.id})
			for it in Interiors.items(b):
				var st := Interiors.item_static(it)
				if st.is_empty(): continue
				if st.get("type", "") == "circle": st["tag"] = b.id; out.append(st)
				else: out.append(_box(st.minX, st.maxX, st.minZ, st.maxZ, b.id))
		else:
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
		if pr.get("solid", true) and pr.kind != "pier": out.append({"type": "circle", "x": pr.x, "z": pr.z, "r": float(pr.get("rad", 0.3)), "tag": "prop"})
	for nd in Data.layout.nodes:
		if nd.kind in ["chop", "fruit", "shake"]: out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.45, "tag": nd.id})
		elif nd.kind == "mine": out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.75, "tag": nd.id})
		elif nd.kind == "chest": out.append(_box(nd.x - 0.45, nd.x + 0.45, nd.z - 0.32, nd.z + 0.32, nd.id))
		elif nd.kind == "bin": out.append({"type": "circle", "x": nd.x, "z": nd.z, "r": 0.65, "tag": nd.id})
	for f in Data.layout.features:
		if f.kind in ["sign", "board", "wardrobe"]: out.append({"type": "circle", "x": f.x, "z": f.z, "r": 0.3, "tag": f.id})
		if f.kind == "bench":
			var st := Interiors.item_static({"piece": true, "id": "bench", "x": f.x, "z": f.z, "r": int(f.get("r", 0))})
			out.append(_box(st.minX, st.maxX, st.minZ, st.maxZ, f.id))
	for t in decor.trees: out.append({"type": "circle", "x": t.x, "z": t.z, "r": 0.42 * t.s, "tag": "tree"})
	return out

static func _box(a: float, b: float, c: float, d: float, tag: String) -> Dictionary:
	return {"type": "box", "minX": a, "maxX": b, "minZ": c, "maxZ": d, "tag": tag}
