extends RefCounted

const ROCKS := [Vector2(64.0, -20.0), Vector2(63.0, 12.0), Vector2(46.0, 80.0), Vector2(39.0, 50.0), Vector2(-56.0, 42.0)]
const QUAY_Z := 41.0
const PORT := Vector2(-175.0, -20.0)
const HORN_EVERY := 150.0
const FERRY_MINUTE := 19.0 * 60.0
const CRANE_EVERY := 45.0

static func play(game, kind: String, note: int, vol: float, delay: float = 0.0) -> void:
	if game == null or game.get("audio") == null or vol <= 0.01: return
	game.audio.play(kind, note, vol, -1, delay)

static func by_distance(d: float, near: float, far: float) -> float: return clampf(1.0 - (d - near) / (far - near), 0.0, 1.0)

static func nearest_rocks(pl: Vector2) -> float:
	var best := INF
	for r in ROCKS: best = minf(best, (r as Vector2).distance_to(pl))
	return best

static func horn_due(prev_minute: float, minute: float) -> bool:
	if minute < prev_minute: return false
	return floorf(minute / HORN_EVERY) > floorf(prev_minute / HORN_EVERY) and minute >= 6.0 * 60.0 and minute < 23.0 * 60.0

static func ferry_due(prev_minute: float, minute: float) -> bool:
	return prev_minute < FERRY_MINUTE and minute >= FERRY_MINUTE

static func wave(game, vol: float) -> void:
	play(game, "hiss", 40, 0.32 * vol)
	play(game, "thud", 40, 0.18 * vol, 0.12)
	play(game, "hiss", 44, 0.18 * vol, 0.5)

static func spray(game, vol: float) -> void:
	play(game, "hiss", 50, 0.4 * vol)
	play(game, "hiss", 54, 0.25 * vol, 0.15)

static func gull_cry(game, vol: float) -> void:
	play(game, "whistle", 86, 0.18 * vol)
	play(game, "whistle", 85, 0.15 * vol, 0.2)
	play(game, "whistle", 83, 0.13 * vol, 0.4)

static func ship_horn(game, vol: float) -> void:
	play(game, "horn", 38, 0.4 * vol)
	play(game, "horn", 45, 0.3 * vol)
	play(game, "horn", 38, 0.38 * vol, 0.85)
	play(game, "horn", 45, 0.28 * vol, 0.85)

static func ferry_blast(game, vol: float) -> void:
	for k in 3:
		play(game, "horn", 41, 0.42 * vol, k * 0.8)
		play(game, "horn", 48, 0.32 * vol, k * 0.8)

static func crane(game, vol: float) -> void:
	play(game, "bell", 70, 0.08 * vol)
	play(game, "thud", 50, 0.16 * vol, 0.1)
	play(game, "bell", 66, 0.06 * vol, 0.35)

static func boat_knock(game, vol: float) -> void:
	play(game, "thud", 48, 0.14 * vol)
	play(game, "thud", 48, 0.1 * vol, 0.22)

static func clatter(game, d: float) -> void:
	var vol := by_distance(d, 2.0, 30.0) * 0.16
	for i in 7: play(game, "thud", 52 + (i * 5) % 9, vol, i * 0.045)

static func tick(life, game, dt: float, pl: Vector2, flags: Dictionary) -> void:
	if game.get("audio") == null: return
	var s: Dictionary = life.sounds
	var minute := float(game.state.time.minute)
	var prev := float(s.get("minute", minute))
	s["minute"] = minute
	s["wave"] = float(s.get("wave", 2.0)) - dt
	if float(s.wave) <= 0.0:
		var near := by_distance(nearest_rocks(pl), 4.0, 45.0)
		if near > 0.0: wave(game, near)
		s.wave = 3.2 + fmod(float(game.time) * 0.37, 2.4)
	s["gull"] = float(s.get("gull", 5.0)) - dt
	if float(s.gull) <= 0.0:
		var by_sea := by_distance(maxf(0.0, QUAY_Z - 18.0 - pl.y), 0.0, 40.0)
		if not flags.get("night", false) and by_sea > 0.0: gull_cry(game, 0.35 + 0.65 * by_sea)
		s.gull = 7.0 + fmod(float(game.time) * 1.3, 9.0)
	s["knock"] = float(s.get("knock", 4.0)) - dt
	if float(s.knock) <= 0.0:
		var by_boats := by_distance(absf(pl.y - QUAY_Z), 1.0, 10.0)
		if by_boats > 0.0: boat_knock(game, by_boats)
		s.knock = 2.5 + fmod(float(game.time) * 0.71, 3.0)
	s["crane"] = float(s.get("crane", CRANE_EVERY)) - dt
	if float(s.crane) <= 0.0:
		if not flags.get("night", false): crane(game, 0.5)
		s.crane = CRANE_EVERY + fmod(float(game.time) * 2.3, 30.0)
	if horn_due(prev, minute): ship_horn(game, 0.7)
	if ferry_due(prev, minute): ferry_blast(game, 0.8)
