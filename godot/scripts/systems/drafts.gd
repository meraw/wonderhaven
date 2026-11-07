class_name Drafts

static func of(state: Dictionary) -> Array:
	if not state.get("drafts") is Array: state["drafts"] = []
	return state.drafts

static func cost(drafts: Array) -> Dictionary:
	var out := {}
	for d in drafts:
		var c: Dictionary = Data.piece(String(d.id)).get("cost", {})
		for k in c: out[k] = int(out.get(k, 0)) + int(c[k])
	return out

static func shortfall(drafts: Array, inventory: Dictionary) -> Array:
	return Inventory.missing(inventory, cost(drafts))

static func same_spot(a: Dictionary, b: Dictionary) -> bool:
	return String(a.id) == String(b.id) and is_equal_approx(float(a.i), float(b.i)) and is_equal_approx(float(a.k), float(b.k)) \
		and posmod(int(a.r), 4) == posmod(int(b.r), 4) and absf(float(a.y) - float(b.y)) < 0.05

static func find_same(drafts: Array, pl: Dictionary) -> Dictionary:
	for d in drafts:
		if same_spot(d, pl): return d
	return {}

static func find(drafts: Array, uid: int) -> Dictionary:
	for d in drafts:
		if int(d.uid) == uid: return d
	return {}

static func design(placements: Array, drafts: Array, skip_uid: int = -1) -> Array:
	var out: Array = placements.filter(func(p): return int(p.uid) != skip_uid)
	for d in drafts:
		if int(d.uid) != skip_uid: out.append(d)
	return out

static func build_order(drafts: Array) -> Array:
	var out := drafts.duplicate()
	out.sort_custom(func(a, b): return float(a.y) < float(b.y) - 0.01 or (absf(float(a.y) - float(b.y)) <= 0.01 and int(a.uid) < int(b.uid)))
	return out

static func items_text(missing: Array) -> String:
	var parts: Array = []
	for m in missing:
		if m.id == "coins": parts.append(Money.lire(int(m.need)))
		else: parts.append("%d %s" % [int(m.need), String(Data.resources[m.id].name).to_lower()])
	return ", ".join(parts)
