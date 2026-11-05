extends RefCounted
## The main line's timetable past Casalrana: pure functions of the game clock, so the trains, the level crossing,
## tests and (in stage 3) Matteo's train log all agree. One game minute is one real second, so speeds are in metres
## per game minute and a train every half hour of game time is one every half minute of play.
##
## Kinds: red-and-white regionals, white-and-green intercity expresses, long freight trains, the blue night express
## (only at night) and the bright yellow track inspection train (once a day, at dawn). None of them stop.

const CROSS_X := 2.0          # the level crossing, on the road north from the crossroads
const EAST_Z := -48.0         # Italian double track runs on the left: eastbound trains take the north track
const WEST_Z := -46.0
const LEAD := 4.0             # the barriers close this long before a train reaches the crossing
const CLEAR := 1.5            # and open this long after its tail has passed
const SPAN := 190.0           # trains are on show within this distance of the crossing
const KINDS := {
	"regional": {"speed": 24.0, "cars": 3, "car": 21.0, "loco": 0.0},
	"intercity": {"speed": 33.0, "cars": 6, "car": 23.0, "loco": 17.0},
	"freight": {"speed": 20.0, "cars": 9, "car": 12.0, "loco": 17.0},
	"night_express": {"speed": 30.0, "cars": 6, "car": 23.0, "loco": 17.0},
	"inspection": {"speed": 14.0, "cars": 2, "car": 15.0, "loco": 0.0},
}
const NAMES := {"regional": "a regional train", "intercity": "an intercity express", "freight": "a freight train",
	"night_express": "the night express", "inspection": "the yellow inspection train"}

static func _h(a: int, b: int) -> float:
	var x := sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return x - floorf(x)

static func is_night(minute: float) -> bool: return minute < 360.0 or minute >= 1230.0

static func length_of(kind: String) -> float:
	var k: Dictionary = KINDS[kind]
	return float(k.loco) + float(k.cars) * float(k.car)

## The day's trains, in order: [{minute (when its front reaches the crossing), kind, dir (+1 east, -1 west), n}].
static func trains_on(day: int) -> Array:
	var out: Array = []
	var m := 8.0 + 10.0 * _h(day, 1)
	var n := 0
	while m < 1440.0:
		var r := _h(day, n * 3 + 7)
		var kind := ""
		if is_night(m): kind = "night_express" if r < 0.4 else "freight"
		elif r < 0.5: kind = "regional"
		elif r < 0.8: kind = "intercity"
		else: kind = "freight"
		out.append({"minute": m, "kind": kind, "dir": 1 if _h(day, n * 5 + 2) < 0.5 else -1, "n": n})
		n += 1
		m += 30.0 + 14.0 * _h(day, n * 11 + 5)
	# the yellow inspection train comes through once a day at dawn, in place of the train nearest 6:20
	var best := 0
	for i in out.size():
		if absf(out[i].minute - 380.0) < absf(out[best].minute - 380.0): best = i
	out[best].kind = "inspection"
	return out

# ---- Stopping again (stage 4) ------------------------------------------------------------------------------------
## Once the finale has the trains stopping again (STOP_FLAG), the westbound regionals, which run on the platform's
## track, brake to a halt with their front at the platform's west end, wait, and pull away towards Toriano. They
## stand just short of the level crossing, so its barriers come down while the train still waits (as everyone in
## Casalrana will tell you, Italian barriers come down early).
const STOP_FLAG := "rice_village_trainStops"
const STOP_X := 6.5            # where a stopping train's front halts
const DWELL := 6.0             # minutes at the platform
const BRAKE := 3.0             # metres per minute per minute, braking and pulling away

static func stops_here(tr: Dictionary, stopping: bool) -> bool: return stopping and tr.kind == "regional" and int(tr.dir) < 0

## How far a train's front has come `dt` minutes after its timetable minute, along its direction (0 is the crossing).
static func travel(tr: Dictionary, dt: float, stopping: bool = false) -> float:
	var v: float = KINDS[tr.kind].speed
	if not stops_here(tr, stopping): return v * dt
	var p := _profile(tr)
	if dt <= p.tb: return v * dt
	if dt <= p.tb + p.tv:
		var u: float = dt - p.tb
		return p.s - p.db + v * u - BRAKE * u * u / 2.0
	if dt <= p.tg: return p.s
	if dt <= p.tg + p.tv:
		var u: float = dt - p.tg
		return p.s + BRAKE * u * u / 2.0
	return p.s + p.db + v * (dt - p.tg - p.tv)

## When (minutes after its timetable minute) a train's front has come `s` metres: the inverse of travel.
static func time_at(tr: Dictionary, s: float, stopping: bool = false) -> float:
	var v: float = KINDS[tr.kind].speed
	if not stops_here(tr, stopping): return s / v
	var p := _profile(tr)
	if s <= p.s - p.db: return s / v
	if s < p.s: return p.tb + (v - sqrt(maxf(0.0, v * v - 2.0 * BRAKE * (s - (p.s - p.db))))) / BRAKE
	if s <= p.s + p.db: return p.tg + sqrt(2.0 * (s - p.s) / BRAKE)
	return p.tg + p.tv + (s - p.s - p.db) / v

## A stopping train's timings: s where it halts, db the braking distance, tb when it starts braking, tv how long
## braking (or pulling away) takes, tg when it pulls away.
static func _profile(tr: Dictionary) -> Dictionary:
	var v: float = KINDS[tr.kind].speed
	var s := (STOP_X - CROSS_X) * float(tr.dir)
	var db := v * v / (2.0 * BRAKE)
	var tb := (s - db) / v
	var tv := v / BRAKE
	return {"s": s, "db": db, "tb": tb, "tv": tv, "tg": tb + tv + DWELL}

## Where the trains are at a moment: [{kind, dir, front (x of the train's front), length, z, n, day, stopped}].
static func on_line(day: int, minute: float, stopping: bool = false) -> Array:
	var out: Array = []
	for d in [day - 1, day, day + 1]:
		var t := minute + float(day - d) * 1440.0
		for tr in trains_on(d):
			var front: float = CROSS_X + float(tr.dir) * travel(tr, t - float(tr.minute), stopping)
			var tail: float = front - float(tr.dir) * length_of(tr.kind)
			if minf(front, tail) < SPAN and maxf(front, tail) > -SPAN:
				out.append({"kind": tr.kind, "dir": tr.dir, "front": front, "length": length_of(tr.kind),
					"z": EAST_Z if tr.dir > 0 else WEST_Z, "n": tr.n, "day": d, "stopped": stops_here(tr, stopping) and absf(front - STOP_X) < 0.01})
	return out

## Is the level crossing closed? From LEAD before a train's front reaches it until CLEAR after its tail has passed.
static func crossing_closed(day: int, minute: float, stopping: bool = false) -> bool:
	for d in [day - 1, day, day + 1]:
		var t := minute + float(day - d) * 1440.0
		for tr in trains_on(d):
			var dt: float = t - float(tr.minute)
			if dt >= time_at(tr, 0.0, stopping) - LEAD and dt <= time_at(tr, length_of(tr.kind), stopping) + CLEAR: return true
	return false

## The train going over the crossing right now, or {} (for Matteo's log in stage 3).
static func at_crossing(day: int, minute: float, stopping: bool = false) -> Dictionary:
	for tr in on_line(day, minute, stopping):
		if minf(tr.front, tr.front - tr.dir * tr.length) <= CROSS_X + 3.0 and maxf(tr.front, tr.front - tr.dir * tr.length) >= CROSS_X - 3.0: return tr
	return {}
