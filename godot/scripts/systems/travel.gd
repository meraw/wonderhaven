class_name Travel
## Sailing between islands. Pieces you build stay on their island: the ones on the island you leave are put away in
## state.away[island], and the destination's come back out. The player arrives at the destination's spawn point.

static func leave(state: Dictionary, from: String, to: String, spawn: Dictionary) -> void:
	if not state.get("away") is Dictionary: state["away"] = {}
	state.away[from] = {"placements": state.placements}
	var back: Dictionary = state.away.get(to, {})
	state.placements = back.get("placements", [])
	state.away.erase(to)
	state.island = to
	state.player = {"x": float(spawn.x), "z": float(spawn.z), "yaw": float(spawn.get("yaw", 0.0))}

## Every placement uid in use, on this island and the others (new pieces get a fresh one).
static func max_uid(state: Dictionary) -> int:
	var m := 0
	for p in state.get("placements", []): m = maxi(m, int(p.uid))
	for isl in state.get("away", {}):
		for p in state.away[isl].get("placements", []): m = maxi(m, int(p.uid))
	return m
