class_name Gardening
## Garden beds: plant a seed, water it, and it grows one stage each time it has had water for a while.
## Hearthglow has Gigia's four pumpkin beds; any other place lists its own in its layout's "gardens":
##   [{id, x, z, seed?: item planted (default "seeds"), crop?: {item: n} picked (default 2 pumpkins and a seed),
##     crop_name?: "cabbages" (for the prompt), look?: "pumpkin" | "cabbage" | "leek", need?: what to say without seed}]
const GROW_MINUTES := 90.0
const PLOTS := [{"id": "bed0", "x": 4.4, "z": -9.4}, {"id": "bed1", "x": 6.6, "z": -9.4}, {"id": "bed2", "x": 4.4, "z": -11.0}, {"id": "bed3", "x": 6.6, "z": -11.0}]
const CROP := {"pumpkin": 2, "seeds": 1}

## The beds where you are.
static func beds() -> Array:
	if Data.layout.has("gardens"): return Data.layout.gardens
	return PLOTS if Data.island == "hearthglow" else []

static func plot(gardens: Dictionary, id: String) -> Dictionary: return gardens.get(id, {"stage": -1})
static func plant(gardens: Dictionary, id: String, now: float) -> bool:
	if plot(gardens, id).stage >= 0: return false
	gardens[id] = {"stage": 0, "watered": false, "watered_at": now}; return true
static func water(gardens: Dictionary, id: String, now: float) -> bool:
	var p: Dictionary = gardens.get(id, {})
	if p.is_empty() or p.stage < 0 or p.stage >= 3 or p.watered: return false
	p.watered = true; p.watered_at = now; return true
static func grow(gardens: Dictionary, now: float) -> bool:
	var changed := false
	for id in gardens:
		var p: Dictionary = gardens[id]
		if p.stage >= 0 and p.stage < 3 and p.watered and now - p.watered_at >= GROW_MINUTES:
			p.stage += 1; p.watered = p.stage >= 3; changed = true
	return changed
static func harvest(gardens: Dictionary, id: String, crop: Dictionary = CROP) -> Dictionary:
	var p: Dictionary = gardens.get(id, {})
	if p.is_empty() or p.stage < 3: return {}
	gardens.erase(id)
	var out := {}
	for k in crop: out[k] = int(crop[k])
	return out
static func action(gardens: Dictionary, id: String, inv: Dictionary, seed: String = "seeds") -> String:
	var p := plot(gardens, id)
	if p.stage < 0: return "plant" if inv.get(seed, 0) > 0 else "need_seeds"
	if p.stage >= 3: return "harvest"
	return "growing" if p.watered else "water"
