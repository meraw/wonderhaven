extends Node
## The two rivers' sounds (docs/locations/river_town.md, "Sound"), so you can hear which one you're beside: the
## Alpine river rushing over its pebbles, bright and crackling, louder as you get near it; the Po a low, slow hiss
## with water lapping at the bank. (The shared ambience still brings the birds and the rain.)

const RT := preload("res://scripts/locations/river_town.gd")
const ALPINE_REACH := 14.0   # heard this far from the Alpine river's edge
const PO_REACH := 16.0       # and the Po from its bank

var t := 0.0

## How loud each river is where you stand (0..1): Vector2(Alpine river, Po).
static func levels(p: Vector3) -> Vector2:
	var po_d := RT.po_bank(p.x) - p.z
	var a := 0.0
	if p.z > RT.CANAL_N + RT.CANAL_HALF and po_d > -2.0:   # its stretch, from the north canal to where it meets the Po
		a = clampf(1.0 - (absf(p.x - RT.alpine_center(p.z)) - RT.ALPINE_HALF) / ALPINE_REACH, 0.0, 1.0)
	var po := clampf(1.0 - po_d / PO_REACH, 0.0, 1.0)
	return Vector2(a, po)

func _process(dt: float) -> void:
	t -= dt
	if t > 0.0: return
	t = 0.6 + randf() * 0.4
	var g = get_tree().current_scene
	if g == null or g.get("audio") == null or g.get("player") == null: return
	var lv := levels(g.player.pos)
	if lv.x > 0.05:   # the Alpine river: quick bursts of bright noise piling into a rush
		g.audio.play("hiss", 60, 0.1 * lv.x)
		for i in 5: g.audio.play("hat", 60, 0.045 * lv.x * (0.6 + randf() * 0.4), -1, randf() * 0.6)
	if lv.y > 0.05:   # the Po: low and slow, lapping at the bank now and then
		g.audio.play("hiss", 50, 0.12 * lv.y)
		if randf() < 0.45: g.audio.play("thud", 36 + randi() % 4, 0.07 * lv.y, -1, randf() * 0.4)
