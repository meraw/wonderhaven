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

const SIDE_WORDS := {"N": "north", "E": "east", "S": "south", "W": "west"}

static func sides_text(sides: Array) -> String:
	var words: Array = []
	for s in BuildGrid.SIDES:
		if sides.has(s): words.append(SIDE_WORDS[s])
	if words.size() <= 1: return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + String(words[-1])

static func port_sides(pl: Dictionary, type: String) -> Array:
	var ports := ports_of(pl)
	var out: Array = []
	for s in BuildGrid.SIDES:
		if ports.get(s, "") == type: out.append(s)
	return out

static func beside_stream(i: float, k: float) -> bool:
	if Heightfield.is_stream_cell(i, k): return true
	for side in BuildGrid.SIDES:
		var dv: Vector2i = BuildGrid.SIDE_DIR[side]
		if Heightfield.is_stream_cell(i + dv.x, k + dv.y): return true
	return false

static func fed_steps(type: String, zone: Dictionary, placements: Array, solved: Dictionary) -> Array:
	var here := placements.filter(func(p): return zone.is_empty() or (float(p.i) >= float(zone.minI) and float(p.i) <= float(zone.maxI) and float(p.k) >= float(zone.minK) and float(p.k) <= float(zone.maxK)))
	var turning := here.any(func(p): return solved.get("sources", {}).has(p.uid))
	var rows: Array = [{"label": "A waterwheel or windmill turning on this site", "ok": turning, "sub": true}]
	if type == "power":
		rows.append({"label": "Drive shafts from its orange side to the orange arrow (gear boxes turn corners)", "ok": false, "sub": true})
		return rows
	rows.append({"label": "A pump beside the water, taking the wheel's power on its orange side", "ok": here.any(func(p): return solved.get("pumps", {}).has(p.uid)), "sub": true})
	rows.append({"label": "Pipes from the pump's blue spout to the blue arrow", "ok": false, "sub": true})
	return rows

static func same_ports(a: Dictionary, b: Dictionary) -> bool:
	return ports_of(a) == ports_of(b)

static func explain(pl: Dictionary, placements: Array, inlets: Array = []) -> Dictionary:
	var m: Dictionary = Data.piece(pl.id).get("mech", {})
	if m.is_empty(): return {}
	var others := placements.filter(func(p): return p.uid != pl.uid)
	var before := solve(others, inlets)
	var probe := pl.duplicate(true)
	if m.get("switch", false) and not probe.has("state"): probe["state"] = {"on": true}
	var after := solve(others + [probe], inlets)
	var power := sides_text(port_sides(probe, "power"))
	var water := sides_text(port_sides(probe, "water"))
	var ok := false
	var text := ""
	var src := String(m.get("source", ""))
	if src == "stream":
		ok = after.sources.has(probe.uid)
		text = ("it turns in the water and sends power out of its %s sides" % power) if ok else "it won't turn here: a waterwheel has to stand in flowing water"
	elif src == "wind":
		ok = true
		text = "it turns in the wind and sends power out of its %s side" % power
	elif m.get("pump", false):
		var powered: bool = after.powered.has(probe.uid)
		var wet := beside_stream(float(probe.i), float(probe.k))
		ok = powered and wet
		if ok: text = "it pumps: water comes out of its %s side" % water
		elif not powered: text = "no power yet: its %s side takes the power and has to touch a turning axle" % power
		else: text = "it has power but no water beside it: stand it next to the flowing water"
	elif m.get("switch", false):
		ok = after.powered.has(probe.uid)
		text = "power passes through it while it's on" if ok else "no power yet: line its %s sides up with a turning axle" % power
	elif m.get("lamp", false):
		ok = after.powered.has(probe.uid)
		text = "it lights up" if ok else "no power yet: it needs a turning axle beside it"
	elif m.get("fountain", false):
		ok = after.watered.has(probe.uid)
		text = "it sprays" if ok else "dry: a wet pipe has to reach it"
	elif water != "" and power == "":
		ok = after.watered.has(probe.uid)
		text = ("water flows through it, out of its %s ends" % water) if ok else "dry: its %s ends have to meet a pump's spout or a wet pipe" % water
	else:
		ok = after.powered.has(probe.uid)
		text = ("it gets power and passes it out of its %s sides" % power) if ok else "no power yet: its %s sides have to meet a turning axle" % power
	var newly: Array = []
	var reached: Array = []
	for inlet in inlets:
		if after.fed.get(inlet.id, false) and not before.fed.get(inlet.id, false):
			var label := String(inlet.get("label", inlet.id))
			newly.append(label)
			reached.append("%s reaches %s!" % ["Power" if String(inlet.get("type", "water")) == "power" else "Water", label.left(1).to_lower() + label.substr(1)])
	return {"ok": ok, "text": text, "feeds": newly, "reached": " ".join(reached)}
