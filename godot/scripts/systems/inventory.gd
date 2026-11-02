class_name Inventory
## Resource inventory helpers on plain dictionaries {wood: 3, spark: 10, ...}.
static func can_afford(inv: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if inv.get(k, 0) < cost[k]: return false
	return true
static func missing(inv: Dictionary, cost: Dictionary) -> Array:
	var out: Array = []
	for k in cost:
		if inv.get(k, 0) < cost[k]: out.append({"id": k, "need": int(cost[k] - inv.get(k, 0))})
	return out
static func spend(inv: Dictionary, cost: Dictionary) -> bool:
	if not can_afford(inv, cost): return false
	for k in cost: inv[k] = int(inv.get(k, 0) - cost[k])
	return true
static func add(inv: Dictionary, items: Dictionary) -> void:
	for k in items: inv[k] = maxi(0, int(inv.get(k, 0) + items[k]))
