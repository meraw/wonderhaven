extends Node

const Trains := preload("res://scripts/locations/cliffs/trains.gd")
const Animals := preload("res://scripts/locations/cliffs/animals.gd")
const Life := preload("res://scripts/locations/cliffs/life.gd")
const MOUTH := 36.0
const SEA_REACH := 55.0
const HARBOUR := Vector2(2.0, 40.0)
const CHURCH := Vector2(27.6, 25.2)
const SANCTUARY := Vector2(-55.0, -57.5)
const PEAL_HOURS := [6, 11]
const PEAL_EVERY := 15
const PEAL := [72, 69, 67, 64, 62, 60]

var game = null
var village: Node3D
var cart: Node3D
var t := 0.0
var last_minute := -1.0

static func front_x(dep: Dictionary, minute: float) -> float:
	return Trains.centre_x(dep, minute) + float(dep.dir) * Trains.length_of(dep) / 2.0

static func horn_due(prev_minute: float, minute: float) -> Dictionary:
	if prev_minute < 0.0 or minute < prev_minute or minute - prev_minute > 3.0: return {}
	for dep in Trains.departures():
		if absf(minute - float(dep.at)) > 12.0: continue
		var a := front_x(dep, prev_minute) * float(dep.dir)
		var b := front_x(dep, minute) * float(dep.dir)
		if a < -MOUTH and b >= -MOUTH: return dep
	return {}

static func horn_at(dep: Dictionary) -> Vector3:
	return Vector3(-MOUTH * float(dep.dir), Trains.RAIL_Y, Trains.TRACK_Z)

static func sea_level(p: Vector3) -> float:
	var C: Script = Data.location_script("cliffs")
	var inland := maxf(0.0, C.coast(p.x) - 8.0 - p.z)
	var d := Vector2(inland, maxf(0.0, p.y - 1.0) * 0.6).length()
	return clampf(1.0 - (d - 3.0) / SEA_REACH, 0.0, 1.0)

static func gull_level(p: Vector3, hour: float) -> float:
	if hour < 6.0 or hour >= 20.0: return 0.0
	var d := Vector2(Vector2(p.x, p.z).distance_to(HARBOUR), maxf(0.0, p.y - 1.0)).length()
	return clampf(1.0 - d / 45.0, 0.0, 1.0)

static func swallow_level(p: Vector3, hour: float, count: int) -> float:
	if not Animals.swallows_out(hour) or count <= 0: return 0.0
	var d := INF
	for c in Animals.SWALLOW_SPOTS: d = minf(d, (c as Vector3).distance_to(p))
	return clampf(1.0 - d / 30.0, 0.0, 1.0) * clampf(float(count) / 16.0, 0.25, 1.0)

static func easter_morning(flags: Dictionary, minute: float) -> bool:
	return flags.get("cliffs_restBuilt", false) and not flags.get("cliffs_easterDone", false) and Clock.in_hours(PEAL_HOURS, minute)

static func peal_due(flags: Dictionary, prev_minute: float, minute: float) -> bool:
	if prev_minute < 0.0 or minute < prev_minute or minute - prev_minute > 3.0: return false
	if not easter_morning(flags, minute): return false
	return floori(minute / PEAL_EVERY) > floori(prev_minute / PEAL_EVERY)

static func bell_level(p: Vector3, at: Vector2) -> float:
	return clampf(1.0 - Vector2(p.x - at.x, p.z - at.y).length() / 140.0, 0.25, 1.0)

static func train_level(p: Vector3, minute: float) -> float:
	var a := Trains.active(minute)
	if a.is_empty(): return 0.0
	var d := Vector3(float(a.x), Trains.RAIL_Y, Trains.TRACK_Z).distance_to(p)
	var moving := 0.3 if Trains.standing(minute) else 1.0
	return clampf(1.0 - d / 60.0, 0.0, 1.0) * moving

func setup(g, v: Node3D) -> void:
	game = g
	village = v
	name = "cliffs_sounds"
	cart = v.find_child("cliffs_cart1_model", true, false) if v != null else null
	if g != null and g.has_signal("game_event"): g.game_event.connect(_on_event)

func _on_event(type: String, data: Dictionary) -> void:
	if type != "flag" or String(data.get("flag", "")) != "cliffs_easterDone" or not bool(data.get("value", true)): return
	if game == null or game.get("audio") == null or game.get("player") == null: return
	peal(CHURCH, 3, 0.0)
	peal(SANCTUARY, 3, 0.7)

func peal(at: Vector2, rounds: int, start: float) -> void:
	var lv := bell_level(game.player.pos, at)
	for r in rounds:
		for i in PEAL.size():
			game.audio.play("bell", int(PEAL[i]), 0.26 * lv, -1, start + r * 3.0 + i * 0.45)

func _process(dt: float) -> void:
	if game == null or game.get("audio") == null or game.get("player") == null or not (game.get("state") is Dictionary): return
	if game.get("traveling"): return
	var minute := float(game.state.time.minute)
	var flags: Dictionary = game.state.flags
	var p: Vector3 = game.player.pos
	var prev := last_minute
	last_minute = minute
	if peal_due(flags, prev, minute): peal(CHURCH, 1, 0.2)
	var dep := horn_due(prev, minute)
	if not dep.is_empty():
		var hv := clampf(1.0 - horn_at(dep).distance_to(p) / 120.0, 0.2, 1.0)
		var lo := 63 if dep.stops else 66
		game.audio.play("horn", lo, 0.22 * hv)
		game.audio.play("horn", lo + 4, 0.18 * hv)
		if dep.stops:
			game.audio.play("horn", lo, 0.2 * hv, -1, 1.1)
			game.audio.play("horn", lo + 4, 0.16 * hv, -1, 1.1)
	t -= dt
	if t > 0.0: return
	t = 0.6 + randf() * 0.4
	var hour := minute / 60.0
	var sea := sea_level(p)
	if sea > 0.05:
		game.audio.play("hiss", 48, 0.13 * sea)
		if randf() < 0.35: game.audio.play("thud", 34 + randi() % 3, 0.1 * sea, -1, randf() * 0.5)
	var gulls := gull_level(p, hour)
	if gulls > 0.05 and randf() < 0.3:
		for i in 1 + randi() % 2: game.audio.play("rasp", 74 + randi() % 4, 0.07 * gulls, -1, i * 0.35 + randf() * 0.1)
	var train := train_level(p, minute)
	if train > 0.05:
		game.audio.play("thud", 30, 0.12 * train)
		game.audio.play("hiss", 40, 0.08 * train, -1, 0.2)
	var swallows := swallow_level(p, hour, Animals.swallow_count(game.state))
	if swallows > 0.05 and randf() < 0.45:
		for i in 2 + randi() % 2: game.audio.play("whistle", 94 + randi() % 5, 0.07 * swallows, -1, i * 0.12 + randf() * 0.05)
	if cart != null and flags.get("cliffs_monorailRuns", false) and Clock.in_hours(Life.RUN_HOURS, minute):
		var cv := clampf(1.0 - cart.global_position.distance_to(p) / 25.0, 0.0, 1.0)
		if cv > 0.05: game.audio.play("purr", 45, 0.08 * cv)
