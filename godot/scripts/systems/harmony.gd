class_name Harmony
## Kingdom Harmony milestones.
static func next_unlock(h: float) -> Dictionary:
	for u in Data.harmony_unlocks:
		if u.at > h: return u
	return {}
static func between(before: float, after: float) -> Array:
	return Data.harmony_unlocks.filter(func(u): return u.at > before and u.at <= after)
static func best(state: Dictionary) -> int: return maxi(int(state.get("harmony", 0)), int(state.get("approval_best", 0)))
static func shown_on(island: String) -> bool: return LocationMeter.def(island).is_empty()
static func due(state: Dictionary, island: String) -> Array:
	if not shown_on(island): return []
	var seen: Array = state.get("unlocks_seen", [])
	var b := best(state)
	return Data.harmony_unlocks.filter(func(u): return int(u.at) <= b and not seen.has(String(u.get("id", ""))))
