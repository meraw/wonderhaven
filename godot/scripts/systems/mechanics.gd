class_name Mechanics
## Power flows from waterwheels (in flowing water) and windmills through shafts, gear boxes and switched-on levers;
## powered pumps beside water push it through connected pipes to fountains.

static func ports_of(pl: Dictionary) -> Dictionary:
	var m: Dictionary = Data.piece(pl.id).get("mech", {})
	var out := {}
	for side in m.get("ports", {}): out[BuildGrid.rot_side(side, int(pl.r))] = m.ports[side]
	return out

## inlets: machine targets [{id, cell: [i, k], side, type?}]: fed when a watered pipe (type "water", the default) or a
## powered shaft/gear (type "power") at that cell has a port facing that side (a fountain's inlet, a lighthouse's drive).
static func solve(placements: Array, inlets: Array = []) -> Dictionary:
	var nodes := placements.filter(func(p):
		var m: Dictionary = Data.piece(p.id).get("mech", {})
		return not m.is_empty() and not (m.get("switch", false) and not p.get("state", {}).get("on", false)))
	var at := {}
	for n in nodes:
		var key := "%d,%d" % [int(n.i), int(n.k)]
		if not at.has(key): at[key] = []
		at[key].append(n)
	var neighbours := func(n: Dictionary, type: String) -> Array:
		var out: Array = []
		var ports := ports_of(n)
		for side in BuildGrid.SIDES:
			if ports.get(side, "") != type: continue
			var dv: Vector2i = BuildGrid.SIDE_DIR[side]
			for m in at.get("%d,%d" % [int(n.i) + dv.x, int(n.k) + dv.y], []):
				if absf(m.y - n.y) > 0.7: continue
				if ports_of(m).get(BuildGrid.OPPOSITE[side], "") == type: out.append(m)
		return out
	var flood := func(starts: Array, type: String) -> Dictionary:
		var seen := {}
		var queue: Array = starts.duplicate()
		for s in starts: seen[s.uid] = true
		while not queue.is_empty():
			for m in neighbours.call(queue.pop_front(), type):
				if not seen.has(m.uid): seen[m.uid] = true; queue.append(m)
		return seen
	var sources := nodes.filter(func(n):
		var s: String = Data.piece(n.id).mech.get("source", "")
		return s == "wind" or (s == "stream" and Heightfield.is_stream_cell(n.i, n.k)))
	var powered: Dictionary = flood.call(sources, "power")
	var pumps := nodes.filter(func(n):
		if not Data.piece(n.id).mech.get("pump", false) or not powered.has(n.uid): return false
		if Heightfield.is_stream_cell(n.i, n.k): return true
		for side in BuildGrid.SIDES:
			var dv: Vector2i = BuildGrid.SIDE_DIR[side]
			if Heightfield.is_stream_cell(n.i + dv.x, n.k + dv.y): return true
		return false)
	var watered: Dictionary = flood.call(pumps, "water")
	var fed := {}
	for inlet in inlets:
		fed[inlet.id] = false
		var type: String = inlet.get("type", "water")
		var net: Dictionary = powered if type == "power" else watered
		for n in at.get("%d,%d" % [int(inlet.cell[0]), int(inlet.cell[1])], []):
			if net.has(n.uid) and ports_of(n).get(inlet.side, "") == type: fed[inlet.id] = true
	var lamps := {}
	var fountains := {}
	for n in nodes:
		var m: Dictionary = Data.piece(n.id).mech
		if m.get("lamp", false) and powered.has(n.uid): lamps[n.uid] = true
		if m.get("fountain", false) and watered.has(n.uid): fountains[n.uid] = true
	var src := {}
	for s in sources: src[s.uid] = true
	var pm := {}
	for p in pumps: pm[p.uid] = true
	return {"powered": powered, "watered": watered, "pumps": pm, "sources": src, "fed": fed, "lamps": lamps, "fountains": fountains}
