extends Node3D
## Passers-by: people hurrying about Toriano on their own business, only near you (ten by day, a few at night). They
## walk the city's streets (never into rooms, onto balconies or into courtyards) at a city pace, step round you, and
## are only for looking at: they don't block you, and you can't talk to them. Wrapped up for December.

const COUNT_DAY := 10
const COUNT_NIGHT := 4
const NEAR := [16.0, 42.0]   # one appears this far from you
const FAR := 65.0            # and goes once it's this far
const SPEED := 3.0           # a city pace (villagers stroll at 2.3)
const STEPS := 7             # how many streets one walks before it's gone round a corner for good

const TOPS := ["jacket", "workjacket", "windbreaker", "suit", "sweater", "hoodie"]
const BOTTOMS := ["pants", "jeans", "skirt", "pants", "dress"]
const HATS := ["none", "none", "beanie", "beret", "drivercap", "none"]
const ACCESSORIES := ["scarf", "scarf", "none", "glasses", "none"]
const WINTER := ["#3b3f4a", "#5a4a3a", "#7a2f35", "#2f3e5a", "#a07850", "#4a5a4a", "#6a6a72", "#c9b089", "#1f2430"]

var game
var walkers: Array = []
var adj := {}          # street nav node -> [neighbours]
var pos_of := {}       # street nav node -> Vector2

## Is a nav spot out on the streets (not a room, a balcony, number 14's courtyard and terrace, or a building site)?
static func street_node(id: String) -> bool:
	for bit in [":", "bal_", "site_", "court", "terrace", "stair", "eve", "ten_"]:
		if bit in id: return false
	return true

## A walk of up to `steps` streets from `start`, never straight back the way it came; `pick` chooses among the ways
## on (an int in 0..n-1), so tests can make it repeatable.
static func route(graph: Dictionary, start: String, steps: int, pick: Callable) -> Array:
	var out: Array = [start]
	var prev := ""
	var at := start
	for i in steps:
		var ways: Array = (graph.get(at, []) as Array).filter(func(n): return n != prev)
		if ways.is_empty(): break
		prev = at; at = ways[int(pick.call(ways.size())) % ways.size()]
		out.append(at)
	return out

## Someone in winter clothes, from a number (so a crowd is varied but the same each time).
static func appearance(i: int) -> Dictionary:
	var a := func(list: Array, k: int): return list[(i * k + i / 3) % list.size()]
	return {"skin": a.call(["#ffe3cc", "#f8cfa8", "#e9b083", "#c98a5e", "#9a6442", "#6b4330"], 7), "eyeShape": a.call(["round", "calm", "sleepy", "happy"], 5),
		"eyeColor": "#3a2a1e", "hair": a.call(["short", "bob", "long", "bun", "ponytail", "curly", "spiky"], 3),
		"hairColor": a.call(["#3b2a20", "#7a4a2a", "#d9a35a", "#2a2a2a", "#9a9a9a", "#e86f5c"], 11), "mouth": a.call(["calm", "smile", "o"], 2),
		"top": a.call(TOPS, 5), "topColor": a.call(WINTER, 7), "bottom": a.call(BOTTOMS, 3), "bottomColor": a.call(WINTER, 5),
		"shoes": "boots" if i % 2 == 0 else "sneakers", "shoesColor": a.call(["#2a2220", "#5a3a2a", "#3a3a40"], 2),
		"hat": a.call(HATS, 7), "hatColor": a.call(WINTER, 3), "accessory": a.call(ACCESSORIES, 9), "accessoryColor": a.call(["#c23a32", "#e0b03a", "#3a6ac2", "#f2f2ee"], 5)}

func setup(v: Node3D) -> void:
	game = v.get_parent()
	name = "Passersby"
	for id in Data.layout.nav_nodes:
		if street_node(id): pos_of[id] = Vector2(Data.layout.nav_nodes[id][0], Data.layout.nav_nodes[id][1])
	for e in Data.layout.nav_edges:
		if not (pos_of.has(e[0]) and pos_of.has(e[1])): continue
		adj[e[0]] = adj.get(e[0], []) + [e[1]]; adj[e[1]] = adj.get(e[1], []) + [e[0]]
	for i in COUNT_DAY:
		var c := Chibi.new(Chibi.sanitize(appearance(i + 1))); c.visible = false; add_child(c)
		walkers.append({"chibi": c, "path": [], "seg": 0, "f": 0.0, "pos": Vector3.ZERO, "yaw": 0.0, "active": false, "i": i})

func _process(dt: float) -> void:
	if game == null or game.get("player") == null or game.get("traveling") or adj.is_empty(): return
	var pp: Vector3 = game.player.pos
	var pl := Vector2(pp.x, pp.z)
	var h := float(game.state.time.minute) / 60.0
	var wanted := COUNT_NIGHT if Daylight.nightness(h) > 0.5 else COUNT_DAY
	for w in walkers:
		if not w.active:
			if w.i < wanted: _start(w, pl)
			continue
		_walk(w, dt, pl)
		if w.active and (Vector2(w.pos.x, w.pos.z).distance_to(pl) > FAR or w.i >= wanted): _stop(w)

func _start(w: Dictionary, pl: Vector2) -> void:
	var near: Array = []
	for id in adj:
		var d: float = (pos_of[id] as Vector2).distance_to(pl)
		if d > NEAR[0] and d < NEAR[1]: near.append(id)
	if near.is_empty(): return
	var path := route(adj, near[randi() % near.size()], STEPS, func(n): return randi() % n)
	if path.size() < 2: return
	w.path = path; w.seg = 0; w.f = 0.0; w.active = true
	var p: Vector2 = pos_of[path[0]]
	w.pos = Vector3(p.x, game.walk.surface_at(p.x, p.y).y, p.y)
	w.chibi.visible = true

func _stop(w: Dictionary) -> void:
	w.active = false; w.chibi.visible = false

func _walk(w: Dictionary, dt: float, pl: Vector2) -> void:
	var a: Vector2 = pos_of[w.path[w.seg]]; var b: Vector2 = pos_of[w.path[w.seg + 1]]
	var len := maxf(0.1, a.distance_to(b))
	w.f += SPEED * dt / len
	if w.f >= 1.0:
		w.seg += 1; w.f = 0.0
		if w.seg >= w.path.size() - 1:   # round the last corner: gone, someone else will come along
			_stop(w); return
		a = pos_of[w.path[w.seg]]; b = pos_of[w.path[w.seg + 1]]
	var dir := (b - a).normalized()
	var p := a.lerp(b, w.f)
	# step round you: veer to one side as they pass, back onto their line once by
	var side := Vector2(-dir.y, dir.x)
	var rel := pl - p
	var near := 1.0 - smoothstep(0.6, 2.2, rel.length())
	p -= side * signf(rel.dot(side) if absf(rel.dot(side)) > 0.01 else 1.0) * near * 1.1
	w.pos = Vector3(p.x, game.walk.surface_at(p.x, p.y, w.pos.y + 0.3).y, p.y)
	w.yaw = lerp_angle(float(w.yaw), atan2(dir.x, dir.y), 1.0 - exp(-8.0 * dt))
	var c: Chibi = w.chibi
	c.position = w.pos; c.rotation.y = w.yaw
	c.animate(dt, SPEED / 4.4)
