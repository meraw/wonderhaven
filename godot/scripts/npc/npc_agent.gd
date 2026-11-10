class_name NpcAgent
extends RefCounted
## A villager: follows a daily routine along the path graph, plays activity animations, greets the player,
## and shows a quest marker when they have something for you.

var game
var def: Dictionary
var character: Chibi
var pos := Vector3.ZERO
var yaw := PI
var goal := ""
var activity := ""
var waypoints: Array = []
var body := {"x": 0.0, "z": 0.0, "r": 0.32}
var talking := false
var greeted := false
var idle_t := 3.0
var waited := 0.0   # how long it has stood waiting for you to get out of its way
var present := true
var hurry_t := 0.0   # seconds left of hurrying (caught staring at you on a bench: NapGags)
var riding := false   # on their bicycle (a villager with "bike" in npcs.json, on a long route outdoors: Bicycle)
var bike: Node3D      # the bicycle, shown while they ride
var rang := false     # rang the bell riding past you (again once you're well apart)
var marker_offer: Label3D
var marker_ready: Label3D
var stare_mark: Label3D
var visit := {}
var visit_t := 30.0
var held := false
var bench := {}
var seat_look_t := 0.0
var held_speed := 0.0
var hat_on := ""

func _init(g, d: Dictionary) -> void:
	game = g; def = d
	character = Chibi.new(d.appearance); character.name = d.id
	hat_on = String(character.appearance.get("hat", "none"))
	game.add_child(character)
	var a := Schedule.activity_at(def, game.state.time.minute, game.state.flags)
	var p := node_pos(a.node)
	pos = Vector3(p.x, game.walk.surface_at(p.x, p.y, node_storey(a.node)).y, p.y)
	goal = a.node; activity = a.activity
	game.walk.dynamic.append(body)
	marker_offer = _marker("!", Color("ffb93b")); marker_ready = _marker("★", Color("59c27a"))
	stare_mark = _marker("?", Color("8a5cff"))
	var first: Array = Data.needs.get("visits", {}).get("first", [10, 60])
	visit_t = lerpf(float(first[0]), float(first[1]), randf())
	sync()

func _marker(text: String, color: Color) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = 96; l.pixel_size = 0.006; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color; l.outline_modulate = Color.WHITE; l.outline_size = 24; l.no_depth_test = true; l.position.y = 2.15; l.visible = false
	l.font = UiTheme.marker_font()   # a tinted glyph, not the watercolour star
	character.add_child(l)
	return l

func node_pos(node: String) -> Vector2:
	if node == "workshopInside":
		for p in game.state.placements:
			if p.id == "workbench" and p.i >= -17 and p.i <= -10 and p.k >= 7 and p.k <= 12:
				return Vector2(p.i + 1.0, p.k + (1.0 if int(p.r) % 2 else (-0.7 if int(p.r) == 2 else 1.7)))
	var a: Array = Data.layout.nav_nodes[node]
	return Vector2(a[0], a[1])

static func node_storey(node: String) -> float:
	var i := node.find(":")
	if i < 0: return INF
	var id := node.substr(0, i)
	for b in Data.layout.buildings:
		if b.id == id: return float(b.y) if b.has("y") else INF
	return INF

func visiting() -> bool: return not visit.is_empty()

func _visit_seated() -> bool: return visiting() and visit.get("arrived", false) and String(visit.spot.get("pose", "")) == "sit"

func seated() -> bool: return _visit_seated() or bool(bench.get("arrived", false))

func leave_bench() -> void:
	if bench.get("arrived", false):
		var back: Vector2 = bench.approach
		pos = Vector3(back.x, game.walk.surface_at(back.x, back.y, float(bench.at.y) + 0.3).y, back.y)
	bench = {}

func _sit_down() -> void:
	pos = bench.at
	yaw = float(bench.yaw)
	bench["arrived"] = true

func start_visit(v: Dictionary, h: Dictionary) -> void:
	visit = v
	visit["arrived"] = false
	plan_route(Schedule.nearest_node(float(h.x), float(h.z), game.state.flags))
	waypoints.append_array(v.get("path", []))
	if v.use and String(v.spot.get("pose", "")) == "sit": waypoints.append(v.spot.at)
	goal = "visit:" + String(v.hangout)

func _arrive() -> void:
	visit["arrived"] = true
	var sp: Dictionary = visit.spot
	yaw = float(sp.get("yaw", yaw))
	if _visit_seated(): pos = Vector3(sp.at.x, float(sp.y), sp.at.y)
	if not visit.use:
		stare_mark.visible = true
		character.play("shrug")
	game.visit_arrived(self)

func end_visit() -> void:
	if _visit_seated():
		var back: Vector2 = visit.spot.approach
		pos = Vector3(back.x, game.walk.surface_at(back.x, back.y, float(visit.spot.get("y", INF))).y, back.y)
	visit = {}
	stare_mark.visible = false
	var every: Array = Data.needs.get("visits", {}).get("every", [60, 150])
	visit_t = lerpf(float(every[0]), float(every[1]), randf())
	goal = ""

func teleport_home() -> void:
	if visiting(): end_visit()
	bench = {}
	var a := Schedule.activity_at(def, game.state.time.minute, game.state.flags)
	var p := node_pos(a.node)
	pos.x = p.x; pos.z = p.y; waypoints = []; goal = a.node; activity = a.activity
	var storey := node_storey(a.node)
	if storey != INF: pos.y = game.walk.surface_at(p.x, p.y, storey).y

## The way to nav node `to`, from where they stand, or after a first dash to `via` (hurrying off: NapGags).
func plan_route(to: String, via: Vector2 = Vector2.INF) -> void:
	var flags: Dictionary = game.state.flags
	var from := Vector2(pos.x, pos.z) if via == Vector2.INF else via
	var path := Schedule.find_path(Schedule.nearest_node(from.x, from.y, flags), to, flags)
	goal = to
	if path.is_empty(): waypoints = [node_pos(to)] if via == Vector2.INF else [via, node_pos(to)]; return
	var pts: Array = [] if via == Vector2.INF else [via]
	for n in path.size():
		pts.append(node_pos(path[n]))
		if n + 1 < path.size(): pts.append_array(game.crossing_path(path[n], path[n + 1]))
	if not pts.is_empty() and pts[0].distance_to(Vector2(pos.x, pos.z)) < 0.5: pts.pop_front()
	waypoints = pts

func update(dt: float) -> void:
	var flags: Dictionary = game.state.flags
	present = not def.has("present") or flags.get(def.present, false)
	character.visible = present
	body.r = 0.32 if present else 0.0
	if not present: return
	if held:
		marker_offer.visible = false; marker_ready.visible = false
		character.animate(dt, held_speed)
		sync()
		return
	var a := Schedule.activity_at(def, game.state.time.minute, flags)
	var want := String(a.get("hat", ""))
	if want == "": want = String(def.appearance.get("hat", "none"))
	if want != hat_on:
		hat_on = want
		character.wear_hat(want)
	if visiting() and a.activity == "sleep": end_visit()
	if not visiting() and a.node != goal:
		leave_bench()
		plan_route(a.node)
	activity = a.activity
	if bench.get("arrived", false) and Vector2(pos.x - bench.at.x, pos.z - bench.at.z).length() > Seats.TAKEN_R: bench = {}
	if not bench.is_empty() and (activity != "sit" or visiting() or not game.seat_exists(String(bench.key))): leave_bench()
	seat_look_t -= dt
	if activity == "sit" and bench.is_empty() and not visiting() and not talking and waypoints.is_empty() and goal == a.node and seat_look_t <= 0.0:
		seat_look_t = 1.0
		var got: Dictionary = game.claim_seat(self)
		if not got.is_empty():
			bench = got
			bench["arrived"] = false
			waypoints = [got.approach]
	if visiting() and visit.arrived: activity = String(visit.spot.get("pose", "")) if visit.use else "stare"
	var speed := 0.0
	hurry_t = maxf(0.0, hurry_t - dt)
	var pp: Vector3 = game.player.pos
	if talking:
		if riding: _ride(false)
		if not seated(): face(pp, dt, 10.0)
	elif not waypoints.is_empty():
		var tgt: Vector2 = waypoints[0]
		var d := Vector2(tgt.x - pos.x, tgt.y - pos.z)
		var far := Vector2(pp.x - pos.x, pp.z - pos.z).length() > 40.0
		_update_riding()
		var v := 6.0 if far else (Bicycle.VILLAGER_SPEED if riding else (4.8 if hurry_t > 0.0 else 2.3))
		if d.length() < 0.15: waypoints.pop_front()
		else:
			var step := minf(d.length(), v * dt)
			var n := Vector2(pos.x, pos.z) + d.normalized() * step
			var clear := n.distance_to(Vector2(pp.x, pp.z)) > 0.62
			# it waits for you to step aside, then squeezes past: on a narrow balcony, or meeting you head-on, you can't
			if clear or waited > 2.0:
				pos.x = n.x; pos.z = n.y; speed = v / 4.4
				if clear: waited = 0.0
			else: waited += dt
			yaw = lerp_angle(yaw, atan2(d.x, d.y), 1.0 - exp(-8.0 * dt))
		if riding:
			BikeModel.animate(bike, dt, speed * 4.4, game.state.flags.get("night", false))
			var pd := Vector2(pp.x - pos.x, pp.z - pos.z).length()
			if not rang and pd < 6.0: rang = true; game.sfx("bell")   # ding-ding, riding past you
			elif pd > 12.0: rang = false
	else:
		if riding: _ride(false)
		if not bench.is_empty() and not bench.arrived: _sit_down()
		if visiting() and not visit.arrived: _arrive()
		if visiting() and visit.arrived and not talking:
			visit["left"] = float(visit.get("left", 20.0)) - dt
			if not visit.use: face(Vector3(visit.look.x, 0.0, visit.look.y), dt, 6.0)
			if float(visit.left) <= 0.0: end_visit()
		var pd := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		if seated(): pd = 99.0
		if pd < 3.2 and activity != "sleep":
			face(pp, dt, 5.0)
			if not greeted and game.mode == "explore": greeted = true; character.play("wave"); game.voice(def.get("voice", 1.0), 2)
		elif pd > 6.0: greeted = false
	var s: Dictionary = game.walk.surface_at(pos.x, pos.z, pos.y + 0.3)
	if s.walkable and not seated(): pos.y = s.y
	var hold: String = ("sit" if seated() else "talk") if talking else ("ride" if riding else ("" if speed > 0.0 else {"garden": "garden", "work": "work", "read": "read", "talk": "talk", "sleep": "sleep", "sit": "sit", "dance": "dance"}.get(activity, "")))
	if hold != "":
		if character.hold != hold: character.play(hold, true)
	elif character.hold != "": character.stop_hold()
	if speed == 0.0 and activity == "wave" and not talking:
		idle_t -= dt
		if idle_t < 0.0: character.play("wave"); idle_t = 3.0 + randf() * 3.0
	if activity == "sleep" and not talking and randf() < dt * 0.8: game.effects.zzz(pos + Vector3(0, 1.4, 0))
	character.animate(dt, speed)
	var st: String = game.story.marker_for(def.id) if game.story else ""
	marker_offer.visible = st == "offer" and not talking
	marker_ready.visible = st == "ready" and not talking
	var bob := sin(game.time * 3.0) * 0.08
	marker_offer.position.y = 2.15 + bob; marker_ready.position.y = 2.15 + bob
	sync()

## How far they still have to go along their route.
func route_left() -> float:
	var total := 0.0
	var p := Vector2(pos.x, pos.z)
	for w in waypoints: total += p.distance_to(w); p = w
	return total

## On or off the bike, by Bicycle's rule (villagers who have one, on long routes outdoors).
func _update_riding() -> void:
	if not def.has("bike"): return
	var want := Bicycle.villager_rides(def, Data.island_def(Data.island), route_left(), riding, Bicycle.indoors(pos), Bicycle.on_stairs(pos))
	if want != riding: _ride(want)

func _ride(on: bool) -> void:
	riding = on
	if on and bike == null:
		var b := Bicycle.villager_bike(def)
		bike = BikeModel.build(b.color, b.ups); character.add_child(bike)
	if bike: bike.visible = on
	if not on and character.hold == "ride": character.stop_hold()

func face(p: Vector3, dt: float, rate: float) -> void:
	yaw = lerp_angle(yaw, atan2(p.x - pos.x, p.z - pos.z), 1.0 - exp(-rate * dt))

func sync() -> void:
	body.x = pos.x; body.z = pos.z
	character.position = pos; character.rotation.y = yaw
