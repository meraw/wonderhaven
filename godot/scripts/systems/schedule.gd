class_name Schedule
## NPC daily routines and navigation over the village path graph.

static func schedule_for(npc: Dictionary, flags: Dictionary) -> Array:
	for w in npc.get("when", []):
		var f: String = w.flag
		var neg := f.begins_with("!")
		if neg: f = f.substr(1)
		if (not flags.get(f, false)) if neg else flags.get(f, false): return w.schedule
	return npc.schedule

static func activity_at(npc: Dictionary, minute: float, flags: Dictionary) -> Dictionary:
	var h := minute / 60.0
	for e in schedule_for(npc, flags):
		if h >= e[0] and h < e[1]: return {"node": e[2], "activity": e[3]}
	return {"node": npc.home, "activity": "sleep"}

static func _pos(id: String) -> Vector2:
	var p: Array = Data.layout.nav_nodes[id]
	return Vector2(p[0], p[1])

static func find_path(from: String, to: String, flags: Dictionary) -> Array:
	if from == to: return [to]
	var adj := {}
	for e in Data.layout.nav_edges:
		if e.size() > 2 and not flags.get(e[2], false): continue
		var d := _pos(e[0]).distance_to(_pos(e[1]))
		if not adj.has(e[0]): adj[e[0]] = []
		if not adj.has(e[1]): adj[e[1]] = []
		adj[e[0]].append([e[1], d]); adj[e[1]].append([e[0], d])
	var dist := {from: 0.0}
	var prev := {}
	var open := [from]
	while not open.is_empty():
		var cur: String = open[0]
		for n in open:
			if dist[n] < dist[cur]: cur = n
		open.erase(cur)
		if cur == to: break
		for pair in adj.get(cur, []):
			var nd: float = dist[cur] + pair[1]
			if nd < dist.get(pair[0], INF):
				dist[pair[0]] = nd; prev[pair[0]] = cur
				if not open.has(pair[0]): open.append(pair[0])
	if not prev.has(to): return []
	var path := [to]
	var c := to
	while prev.has(c): c = prev[c]; path.push_front(c)
	return path

static func nearest_node(x: float, z: float, flags: Dictionary) -> String:
	var reachable := {}
	for e in Data.layout.nav_edges:
		if e.size() > 2 and not flags.get(e[2], false): continue
		reachable[e[0]] = true; reachable[e[1]] = true
	var best := ""
	var bd := INF
	for id in Data.layout.nav_nodes:
		if not reachable.has(id): continue
		if String(id).contains(":") and not _in_room(String(id).get_slice(":", 0), x, z): continue   # spots indoors only count from inside
		var d := _pos(id).distance_to(Vector2(x, z))
		if d < bd: bd = d; best = id
	return best

static func _in_room(bid: String, x: float, z: float) -> bool:
	for b in Data.layout.buildings:
		if b.id == bid and Interiors.enterable(b):
			var r := Interiors.room(b)
			return x >= r.position.x - 0.4 and x <= r.end.x + 0.4 and z >= r.position.z - 0.4 and z <= r.end.z + 0.4
	return false
