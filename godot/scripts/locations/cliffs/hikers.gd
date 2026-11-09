extends Node3D

const COUNT := 8
const SPEED := 1.4
const HOURS := [9, 17]
const ROUTE := ["platform", "top0", "sanctuary", "muleS", "W1", "stair1", "square", "breakwaterMid", "square", "street2", "platform"]
const ANORAKS := ["#c8322c", "#d8452e", "#b82a3a", "#e05a2a"]

var game = null
var points: Array = []
var marks: Array = []
var ground: Array = []
var total := 0.0
var walkers: Array = []
var clock := 0.0

static func graph(flags: Dictionary) -> Dictionary:
	var adj := {}
	for e in Data.layout.get("nav_edges", []):
		if e.size() > 2 and not flags.get(String(e[2]), false): continue
		adj[e[0]] = adj.get(e[0], []) + [e[1]]
		adj[e[1]] = adj.get(e[1], []) + [e[0]]
	return adj

static func shortest(adj: Dictionary, from: String, to: String) -> Array:
	var nodes: Dictionary = Data.layout.get("nav_nodes", {})
	var dist := {from: 0.0}
	var prev := {}
	var open: Array = [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[best]]): best = i
		var at: String = open[best]
		open.remove_at(best)
		if at == to: break
		done[at] = true
		var pa := Vector2(float(nodes[at][0]), float(nodes[at][1]))
		for n in adj.get(at, []):
			if done.has(n): continue
			var d := float(dist[at]) + pa.distance_to(Vector2(float(nodes[n][0]), float(nodes[n][1])))
			if not dist.has(n) or d < float(dist[n]):
				dist[n] = d
				prev[n] = at
				if not open.has(n): open.append(n)
	if not dist.has(to): return []
	var out: Array = [to]
	while out[0] != from: out.push_front(prev[out[0]])
	return out

static func loop(flags: Dictionary) -> Array:
	var adj := graph(flags)
	var ids: Array = [ROUTE[0]]
	for i in range(1, ROUTE.size()):
		var leg := shortest(adj, String(ROUTE[i - 1]), String(ROUTE[i]))
		if leg.is_empty(): return []
		for k in range(1, leg.size()): ids.append(leg[k])
	return ids

static func shown(flags: Dictionary, minute: float) -> bool:
	return flags.get("cliffs_easterDone", false) and Clock.in_hours(HOURS, minute)

static func appearance(i: int) -> Dictionary:
	var a := func(list: Array, k: int): return list[(i * k + i / 3) % list.size()]
	return {"skin": a.call(["#ffe3cc", "#f8cfa8", "#e9b083", "#c98a5e", "#9a6442", "#6b4330"], 7), "eyeShape": a.call(["round", "happy", "wide"], 5),
		"eyeColor": "#3a2a1e", "hair": a.call(["short", "bob", "ponytail", "curly", "bun"], 3),
		"hairColor": a.call(["#3b2a20", "#7a4a2a", "#d9a35a", "#2a2a2a", "#9a9a9a"], 11), "mouth": a.call(["calm", "smile"], 2),
		"top": "windbreaker", "topColor": a.call(ANORAKS, 3), "bottom": a.call(["pants", "shorts", "pants"], 5), "bottomColor": a.call(["#2f3e5a", "#3a3a40", "#5a4a3a"], 7),
		"shoes": "boots", "shoesColor": a.call(["#5a3a2a", "#3a3a40"], 3),
		"hat": a.call(["none", "beanie", "sunhat", "none"], 5), "hatColor": a.call(["#3a6a4a", "#2f3e5a", "#e0b03a", "#5a4a3a"], 7), "accessory": "backpack"}

func setup(g) -> void:
	game = g
	name = "cliffs_hikers"

func prepare(flags: Dictionary) -> void:
	points = []
	var nodes: Dictionary = Data.layout.get("nav_nodes", {})
	for id in loop(flags):
		points.append(Vector2(float(nodes[id][0]), float(nodes[id][1])))
	total = 0.0
	marks = [0.0]
	for i in range(1, points.size()):
		total += (points[i - 1] as Vector2).distance_to(points[i])
		marks.append(total)
	if total <= 0.0: return
	for i in COUNT:
		var c := Chibi.new(Chibi.sanitize(appearance(i + 2)))
		c.visible = false
		add_child(c)
		var lead := total * float(i / 2) / float(COUNT / 2)
		walkers.append({"chibi": c, "s": lead + float(i % 2) * 1.8, "side": 0.45 if i % 2 == 0 else -0.45, "yaw": 0.0})

func profile() -> void:
	ground = []
	var y := INF
	var s := 0.0
	while s <= total:
		var p: Vector2 = point_at(s).p
		y = game.walk.surface_at(p.x, p.y, y + 0.3 if y < INF else INF).y
		ground.append(y)
		s += 0.5

func ground_at(s: float) -> float:
	if ground.is_empty(): return INF
	var i := clampi(int(fposmod(s, total) / 0.5), 0, ground.size() - 1)
	return float(ground[i])

func point_at(s: float) -> Dictionary:
	var u := fposmod(s, total)
	var k := 1
	while k < marks.size() - 1 and float(marks[k]) < u: k += 1
	var a: Vector2 = points[k - 1]
	var b: Vector2 = points[k]
	var seg := maxf(0.01, float(marks[k]) - float(marks[k - 1]))
	var f := clampf((u - float(marks[k - 1])) / seg, 0.0, 1.0)
	return {"p": a.lerp(b, f), "dir": (b - a).normalized()}

func _process(dt: float) -> void:
	if game == null or game.get("player") == null or not (game.get("state") is Dictionary): return
	var on: bool = shown(game.state.flags, float(game.state.time.minute)) and not game.get("traveling")
	if not on:
		for w in walkers:
			w.chibi.visible = false
		return
	if walkers.is_empty() and total <= 0.0: prepare(game.state.flags)
	if walkers.is_empty(): return
	clock += dt
	if ground.is_empty() and game.get("walk") != null: profile()
	var pp: Vector3 = game.player.pos
	var pl := Vector2(pp.x, pp.z)
	for w in walkers:
		w.s = float(w.s) + SPEED * dt
		var at := point_at(float(w.s))
		var dir: Vector2 = at.dir
		var side := Vector2(-dir.y, dir.x)
		var p: Vector2 = at.p + side * float(w.side)
		var rel := pl - p
		var near := 1.0 - smoothstep(0.6, 2.2, rel.length())
		p -= side * signf(rel.dot(side) if absf(rel.dot(side)) > 0.01 else 1.0) * near * 1.1
		var base := ground_at(float(w.s))
		var y: float = game.walk.surface_at(p.x, p.y, base + 0.3).y if base < INF else Heightfield.height(p.x, p.y)
		w.yaw = lerp_angle(float(w.yaw), atan2(dir.x, dir.y), 1.0 - exp(-6.0 * dt))
		var c: Chibi = w.chibi
		c.visible = true
		c.position = Vector3(p.x, y, p.y)
		c.rotation.y = float(w.yaw)
		c.animate(dt, SPEED / 4.4)
