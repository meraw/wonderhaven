class_name Tools

static func defs() -> Dictionary: return Data.tools.get("tools", {})

static func def(id: String) -> Dictionary: return defs().get(id, {})

static func for_kind(kind: String) -> String:
	for id in defs():
		if String(defs()[id].get("for", "")) == kind: return String(id)
	return ""

static func owned(state: Dictionary) -> Dictionary:
	if not state.get("tools") is Dictionary: state["tools"] = {}
	return state.tools

static func level(state: Dictionary, id: String) -> int:
	return clampi(int(owned(state).get(id, 1)), 1, maxi(def(id).get("levels", []).size(), 1))

static func level_def(id: String, n: int) -> Dictionary:
	var levels: Array = def(id).get("levels", [])
	return levels[n - 1] if n >= 1 and n <= levels.size() else {}

static func stats(state: Dictionary, id: String) -> Dictionary:
	var s: Dictionary = level_def(id, level(state, id)).duplicate(true)
	s["level"] = level(state, id)
	s["id"] = id
	s["perfect_bonus"] = int(Data.tools.get("perfect_bonus", 0))
	return s

static func for_node(state: Dictionary, kind: String) -> Dictionary:
	var id := for_kind(kind)
	return stats(state, id) if id != "" else {}

static func fells(state: Dictionary, node: Dictionary) -> bool:
	if not node.get("big", false): return true
	return String(stats(state, "axe").get("fells", "")) == "big"

static func next(state: Dictionary, id: String) -> Dictionary:
	return level_def(id, level(state, id) + 1)

static func label(state: Dictionary, id: String) -> String:
	return "%s %s" % [String(def(id).get("icon", "")), String(stats(state, id).get("name", ""))]

static func check(state: Dictionary, id: String, n: int) -> Dictionary:
	var lv := level_def(id, n)
	if lv.is_empty(): return {"ok": false, "reason": "unknown"}
	if n <= level(state, id): return {"ok": false, "reason": "owned"}
	if n > level(state, id) + 1: return {"ok": false, "reason": "earlier"}
	if not Shop.meets(state, lv.get("requires", {})): return {"ok": false, "reason": "locked"}
	var cost: Dictionary = lv.get("items", {}).duplicate()
	cost["coins"] = int(cost.get("coins", 0)) + int(lv.get("price", 0))
	if not Inventory.can_afford(state.inventory, cost): return {"ok": false, "reason": "short", "missing": Inventory.missing(state.inventory, cost)}
	return {"ok": true, "cost": cost}

static func upgrade(state: Dictionary, id: String) -> Dictionary:
	var n := level(state, id) + 1
	var c := check(state, id, n)
	if not c.ok: return c
	Inventory.spend(state.inventory, c.cost)
	owned(state)[id] = n
	var lv := level_def(id, n)
	return {"ok": true, "id": id, "level": n, "name": String(lv.get("name", "")), "unlocks": lv.get("unlocks", []), "cost": c.cost}

static func cost_text(lv: Dictionary) -> String:
	var parts: Array = []
	if int(lv.get("price", 0)) > 0: parts.append(Money.lire(int(lv.price)))
	var items: Dictionary = lv.get("items", {})
	for k in items: parts.append("%d %s" % [int(items[k]), String(Data.resources.get(k, {}).get("name", k)).to_lower()])
	return " + ".join(parts)
