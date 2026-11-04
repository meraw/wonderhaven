extends Node
## Toriano's street lamps and Christmas lights follow the village's lamp glow (Village.lamp_glow, which rises at dusk):
## the sodium bulbs warm up to orange, and the tree's lights twinkle a little.

var village
var bulbs: Array = []        # StandardMaterial3D of the street lamps' bulbs
var twinkle: Array = []      # StandardMaterial3D of the Christmas lights
var t := 0.0

func _process(dt: float) -> void:
	if village == null: return
	t += dt
	var g: float = village.lamp_glow
	for m in bulbs: (m as StandardMaterial3D).emission_energy_multiplier = 0.15 + 3.2 * g
	for m in twinkle: (m as StandardMaterial3D).emission_energy_multiplier = 0.5 + (1.6 + 0.4 * sin(t * 2.3)) * g
