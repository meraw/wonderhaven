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

## Where the trains are at a moment: [{kind, dir, front (x of the train's front), length, z, n, day}].
static func on_line(day: int, minute: float) -> Array:
	var out: Array = []
	for d in [day - 1, day, day + 1]:
		var t := minute + float(day - d) * 1440.0
		for tr in trains_on(d):
			var k: Dictionary = KINDS[tr.kind]
			var front: float = CROSS_X + float(tr.dir) * float(k.speed) * (t - float(tr.minute))
			var tail: float = front - float(tr.dir) * length_of(tr.kind)
			if minf(front, tail) < SPAN and maxf(front, tail) > -SPAN:
				out.append({"kind": tr.kind, "dir": tr.dir, "front": front, "length": length_of(tr.kind),
					"z": EAST_Z if tr.dir > 0 else WEST_Z, "n": tr.n, "day": d})
	return out

## Is the level crossing closed? From LEAD before a train's front reaches it until CLEAR after its tail has passed.
static func crossing_closed(day: int, minute: float) -> bool:
	for d in [day - 1, day, day + 1]:
		var t := minute + float(day - d) * 1440.0
		for tr in trains_on(d):
			var dt: float = t - float(tr.minute)
			if dt >= -LEAD and dt <= length_of(tr.kind) / float(KINDS[tr.kind].speed) + CLEAR: return true
	return false

## The train going over the crossing right now, or {} (for Matteo's log in stage 3).
static func at_crossing(day: int, minute: float) -> Dictionary:
	for tr in on_line(day, minute):
		if minf(tr.front, tr.front - tr.dir * tr.length) <= CROSS_X + 3.0 and maxf(tr.front, tr.front - tr.dir * tr.length) >= CROSS_X - 3.0: return tr
	return {}
