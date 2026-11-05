extends RefCounted
## Casalrana's sounds (stage 4), made from the game's own instruments (AudioDirector.play): the birds' calls, the
## trains' horns and rumble, the crossing's bells, and the church bells, which ring out only for the big moments
## (the first peal from the mended tower, the living nativity and the finale). Nothing happens when the game has no
## sound. Volumes are 0..1 and already allow for distance.

static func play(game, kind: String, note: int, vol: float, delay: float = 0.0) -> void:
	if game == null or game.get("audio") == null or vol <= 0.01: return
	game.audio.play(kind, note, vol, -1, delay)

## How loud something this far away sounds (full within `near`, gone by `far`).
static func by_distance(d: float, near: float, far: float) -> float: return clampf(1.0 - (d - near) / (far - near), 0.0, 1.0)

## A bird's call: the heron's harsh croak as it takes off (an egret's is thinner), the lapwings' "pee-wit", the
## cranes' trumpeting from high up.
static func bird(game, kind: String, vol: float) -> void:
	match kind:
		"heron":
			play(game, "rasp", 40, 0.55 * vol); play(game, "rasp", 37, 0.4 * vol, 0.34)
		"egret":
			play(game, "rasp", 47, 0.35 * vol)
		"lapwing":
			play(game, "whistle", 86, 0.22 * vol); play(game, "whistle", 91, 0.2 * vol, 0.28)
		"crane":
			for k in 5: play(game, "horn", [62, 65, 62, 67, 64][k], 0.12 * vol, k * 0.55 + (0.2 if k % 2 else 0.0))

## A train's two-tone horn: two short blasts.
static func horn(game, vol: float) -> void:
	for k in 2:
		play(game, "horn", 57, 0.42 * vol, k * 0.75); play(game, "horn", 61, 0.36 * vol, k * 0.75)

## One beat of a passing train: the rush of air and, close by, the wheels clacking over a rail joint.
static func rumble(game, vol: float, clack: bool) -> void:
	play(game, "hiss", 46, 0.35 * vol)
	if clack: play(game, "thud", 52, 0.3 * vol); play(game, "thud", 50, 0.25 * vol, 0.11)

## One ring of the crossing's electric bells.
static func crossing_bell(game, vol: float) -> void:
	play(game, "glock", 96, 0.22 * vol); play(game, "glock", 96, 0.16 * vol, 0.12)

## The church bells: three bells rung in changes for a few seconds.
static func peal(game, vol: float = 1.0) -> void:
	var order := [0, 1, 2, 0, 2, 1, 1, 0, 2, 2, 1, 0]
	var notes := [64, 60, 55]
	for k in order.size(): play(game, "bell", notes[order[k]], 0.38 * vol, k * 0.62)
