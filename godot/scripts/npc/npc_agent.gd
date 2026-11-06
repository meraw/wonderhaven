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
var present := true
var hurry_t := 0.0   # seconds left of hurrying (caught staring at you on a bench: NapGags)
var riding := false   # on their bicycle (a villager with "bike" in npcs.json, on a long route outdoors: Bicycle)
var bike: Node3D      # the bicycle, shown while they ride
var rang := false     # rang the bell riding past you (again once you're well apart)
var marker_offer: Label3D
var marker_ready: Label3D

func _init(g, d: Dictionary) -> void:
	game = g; def = d
	character = Chibi.new(d.appearance); character.name = d.id
	game.add_child(character)
	var a := Schedule.activity_at(def, game.state.time.minute, game.state.flags)
	var p := node_pos(a.node)
	pos = Vector3(p.x, game.walk.surface_at(p.x, p.y).y, p.y)
	goal = a.node; activity = a.activity
	game.walk.dynamic.append(body)
	marker_offer = _marker("!", Color("ffb93b")); marker_ready = _marker("★", Color("59c27a"))
	sync()

func _marker(text: String, color: Color) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = 96; l.pixel_size = 0.006; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color; l.outline_modulate = Color.WHITE; l.outline_size = 24; l.no_depth_test = true; l.position.y = 2.15; l.visible = false
	l.font = UiTheme.main_font()
	character.add_child(l)
	return l

func node_pos(node: String) -> Vector2:
	if node == "workshopInside":
		for p in game.state.placements:
			if p.id == "workbench" and p.i >= -17 and p.i <= -10 and p.k >= 7 and p.k <= 12:
				return Vector2(p.i + 1.0, p.k + (1.0 if int(p.r) % 2 else (-0.7 if int(p.r) == 2 else 1.7)))
	var a: Array = Data.layout.nav_nodes[node]
	return Vector2(a[0], a[1])

func teleport_home() -> void:
	var a := Schedule.activity_at(def, game.state.time.minute, game.state.flags)
	var p := node_pos(a.node)
	pos.x = p.x; pos.z = p.y; waypoints = []; goal = a.node; activity = a.activity

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
	var a := Schedule.activity_at(def, game.state.time.minute, flags)
	if a.node != goal: plan_route(a.node)
	activity = a.activity
	var speed := 0.0
	hurry_t = maxf(0.0, hurry_t - dt)
	var pp: Vector3 = game.player.pos
	if talking:
		if riding: _ride(false)
		face(pp, dt, 10.0)
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
			if n.distance_to(Vector2(pp.x, pp.z)) > 0.62: pos.x = n.x; pos.z = n.y; speed = v / 4.4
			yaw = lerp_angle(yaw, atan2(d.x, d.y), 1.0 - exp(-8.0 * dt))
		if riding:
			BikeModel.animate(bike, dt, speed * 4.4, game.state.flags.get("night", false))
			var pd := Vector2(pp.x - pos.x, pp.z - pos.z).length()
			if not rang and pd < 6.0: rang = true; game.sfx("bell")   # ding-ding, riding past you
			elif pd > 12.0: rang = false
	else:
		if riding: _ride(false)
		var pd := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		if pd < 3.2 and activity != "sleep":
			face(pp, dt, 5.0)
			if not greeted and game.mode == "explore": greeted = true; character.play("wave"); game.voice(def.get("voice", 1.0), 2)
		elif pd > 6.0: greeted = false
	var s: Dictionary = game.walk.surface_at(pos.x, pos.z, pos.y + 0.3)
	if s.walkable: pos.y = s.y
	var hold: String = "talk" if talking else ("ride" if riding else ("" if speed > 0.0 else {"garden": "garden", "work": "work", "read": "read", "talk": "talk", "sleep": "sleep"}.get(activity, "")))
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
