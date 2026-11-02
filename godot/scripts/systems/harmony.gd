class_name Harmony
## Kingdom Harmony milestones.
static func next_unlock(h: float) -> Dictionary:
	for u in Data.harmony_unlocks:
		if u.at > h: return u
	return {}
static func between(before: float, after: float) -> Array:
	return Data.harmony_unlocks.filter(func(u): return u.at > before and u.at <= after)
