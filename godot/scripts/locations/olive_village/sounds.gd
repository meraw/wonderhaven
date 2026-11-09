extends Node

const SEA_REACH := 42.0
const TORRENT_REACH := 18.0
const BELL := Vector2(-38.2, -35.5)
const CASTLE := Vector2(-46.5, -63.5)
const HIVES := Vector2(52.0, -56.0)
const BELL_FROM := 7
const BELL_TO := 21

var t := 0.0
var last_minute := -1.0

static func levels(p: Vector3) -> Vector2:
	var ov: Script = Data.location_script("olive_village")
	var inland := maxf(0.0, ov.shore(p.x) - p.z)
	var sea_d := Vector2(inland, maxf(0.0, p.y - 0.5)).length()
	var sea := clampf(1.0 - (sea_d - 3.0) / SEA_REACH, 0.0, 1.0)
	var torrent := 0.0
	if p.z < ov.shore(p.x) - 3.0:
		var dx := maxf(0.0, absf(p.x - ov.torrent_center(p.z)) - ov.torrent_half(p.z))
		var dy := maxf(0.0, p.y) * 0.5
		torrent = clampf(1.0 - Vector2(dx, dy).length() / TORRENT_REACH, 0.0, 1.0)
	return Vector2(sea, torrent)

static func bell_minute(hour: int) -> int:
	return hour * 60 + 2 + (hour * 7) % 6

static func strikes(hour: int) -> int:
	return (hour + 11) % 12 + 1

static func bells_silent(flags: Dictionary) -> bool:
	return flags.get("olive_village_hive_plans", false) and not flags.get("olive_village_swarm_done", false)

static func bell_level(p: Vector3) -> float:
	return clampf(1.0 - Vector2(p.x - BELL.x, p.z - BELL.y).length() / 160.0, 0.25, 1.0)

static func bee_level(p: Vector3, hour: float) -> float:
	if hour < 8.0 or hour >= 19.0: return 0.0
	return clampf(1.0 - Vector2(p.x - HIVES.x, p.z - HIVES.y).length() / 22.0, 0.0, 1.0)

static func swift_level(p: Vector3, hour: float) -> float:
	var busy := (hour >= 18.0 and hour < 21.0) or (hour >= 6.0 and hour < 8.0)
	if not busy: return 0.0
	var d := minf(Vector2(p.x - BELL.x, p.z - BELL.y).length(), Vector2(p.x - CASTLE.x, p.z - CASTLE.y).length())
	return clampf(1.0 - d / 45.0, 0.0, 1.0)

static func bell_due(prev_minute: float, minute: float) -> int:
	if prev_minute < 0.0 or minute < prev_minute or minute - prev_minute > 3.0: return -1
	for h in range(BELL_FROM, BELL_TO + 1):
		var m := float(bell_minute(h))
		if prev_minute < m and minute >= m: return h
	return -1

func _process(dt: float) -> void:
	var g = get_tree().current_scene
	if g == null or g.get("audio") == null or g.get("player") == null or not (g.get("state") is Dictionary): return
	var minute := float(g.state.time.minute)
	var h := bell_due(last_minute, minute)
	last_minute = minute
	if h >= 0 and not bells_silent(g.state.flags):
		var lv := bell_level(g.player.pos)
		for k in strikes(h): g.audio.play("bell", 60, 0.32 * lv, -1, k * 1.7)
	t -= dt
	if t > 0.0: return
	t = 0.6 + randf() * 0.4
	var p: Vector3 = g.player.pos
	var lv := levels(p)
	if lv.x > 0.05:
		g.audio.play("hiss", 48, 0.13 * lv.x)
		if randf() < 0.35: g.audio.play("thud", 34 + randi() % 3, 0.1 * lv.x, -1, randf() * 0.5)
	if lv.y > 0.05:
		g.audio.play("hiss", 62, 0.09 * lv.y)
		for i in 4: g.audio.play("hat", 60, 0.04 * lv.y * (0.6 + randf() * 0.4), -1, randf() * 0.6)
	var hour := minute / 60.0
	var bees := bee_level(p, hour)
	if bees > 0.05: g.audio.play("purr", 50 + randi() % 3, 0.07 * bees)
	var swifts := swift_level(p, hour)
	if swifts > 0.05 and randf() < 0.45:
		for i in 2 + randi() % 2: g.audio.play("whistle", 92 + randi() % 5, 0.08 * swifts, -1, i * 0.12 + randf() * 0.05)
