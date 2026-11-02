class_name Rng
extends RefCounted
## Deterministic PRNG (mulberry32), identical to the web version so the world dressing matches.

var a: int

func _init(seed: int = 1) -> void:
	a = seed & 0xFFFFFFFF

static func imul(x: int, y: int) -> int:
	x &= 0xFFFFFFFF; y &= 0xFFFFFFFF
	var lo := (x & 0xFFFF) * y
	var hi := ((x >> 16) * y) & 0xFFFF
	return (lo + (hi << 16)) & 0xFFFFFFFF

func next() -> float:
	a = (a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := a
	t = imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

func range_f(lo: float, hi: float) -> float: return lo + next() * (hi - lo)
func int_range(lo: int, hi: int) -> int: return int(floor(lo + next() * (hi - lo + 1)))
