extends Node
## Toriano's street lamps and Christmas lights come on at dusk: they follow the light of Toriano's short winter days
## (Daylight.nightness, dusk at five), or the village's lamp glow (the shared night, from 20:30), whichever is more.
## The sodium bulbs warm up to orange, and the Christmas lights twinkle a little. `level` is what they read; the
## Golden Angel reads it too.

static var level := 0.0
var village
var bulbs: Array = []        # StandardMaterial3D of the street lamps' bulbs
var twinkle: Array = []      # StandardMaterial3D of the Christmas lights
var t := 0.0
var dark := 0.0

func _process(dt: float) -> void:
	if village == null: return
	t += dt
	var game = village.get_parent()
	if game != null and game.get("state") is Dictionary:
		var h := float(game.state.time.minute) / 60.0
		dark = lerpf(dark, 1.0 if Daylight.nightness(h) > 0.45 else 0.0, 1.0 - exp(-dt * 1.5))
	level = maxf(float(village.lamp_glow), dark)
	var g := level
	for m in bulbs: (m as StandardMaterial3D).emission_energy_multiplier = 0.15 + 3.2 * g
	for m in twinkle: (m as StandardMaterial3D).emission_energy_multiplier = 0.5 + (1.6 + 0.4 * sin(t * 2.3)) * g
