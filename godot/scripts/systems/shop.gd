class_name Shop
## Coins, shops and gifts: pure rules on the game state. What each villager trades is data (data/shops.json);
## what they like as a gift is in npcs.json ("likes"), and treats carry a friendship value in resources.json.

const COIN := "coins"

static func def(npc_id: String) -> Dictionary: return Data.shops.get("shops", {}).get(npc_id, {})

## {quests, harmony, flags} like a quest's `requires`.
static func meets(state: Dictionary, r: Dictionary) -> bool:
	for id in r.get("quests", []):
		if state.quests.get(id, {}).get("status", "") != "done": return false
	if r.has("harmony") and state.harmony < r.harmony: return false
	for f in r.get("flags", []):
		if not state.flags.get(f, false): return false
	return true

static func is_open(state: Dictionary, npc_id: String) -> bool:
	var d := def(npc_id)
	return not d.is_empty() and meets(state, d.get("requires", {}))

static func coins(state: Dictionary) -> int: return int(state.inventory.get(COIN, 0))

## What the shop sells right now: [{i, kind: items|blueprint|clothes, items?, id?, price, label, icon, owned, afford}].
## Lines whose own `requires` isn't met yet are left out.
static func stock(state: Dictionary, npc_id: String) -> Array:
	var out: Array = []
	var lines: Array = def(npc_id).get("stock", [])
	for i in lines.size():
		var s: Dictionary = lines[i]
		if not meets(state, s.get("requires", {})): continue
		var e := {"i": i, "price": int(s.get("price", 0)), "owned": false}
		if s.has("items"):
			var parts: Array = []
			for k in s.items: parts.append("%d %s" % [int(s.items[k]), Data.resources[k].name])
			e.merge({"kind": "items", "items": s.items, "label": ", ".join(parts), "icon": Data.resources[s.items.keys()[0]].icon}, true)
		elif s.has("blueprint"):
			e.merge({"kind": "blueprint", "id": s.blueprint, "label": "%s blueprint" % Data.piece(s.blueprint).get("name", s.blueprint), "icon": "📐",
				"owned": state.blueprints.has(s.blueprint)}, true)
		elif s.has("tool"):
			var tid := String(s.tool)
			var n := int(s.get("level", 2))
			var lv := Tools.level_def(tid, n)
			if lv.is_empty() or n != Tools.level(state, tid) + 1 or not meets(state, lv.get("requires", {})): continue
			var cost: Dictionary = lv.get("items", {})
			e.merge({"kind": "tool", "id": tid, "level": n, "price": int(lv.get("price", s.get("price", 0))), "items": cost,
				"label": "%s: %s" % [String(lv.get("name", "")), String(lv.get("does", ""))] + ((" (+ %s)" % ", ".join(cost.keys().map(func(k): return "%d %s" % [int(cost[k]), String(Data.resources[k].name).to_lower()]))) if not cost.is_empty() else ""),
				"icon": String(Tools.def(tid).get("icon", "🔨")), "owned": n <= Tools.level(state, tid)}, true)
		elif s.has("clothes"):
			e.merge({"kind": "clothes", "id": s.clothes, "label": Data.appearance.labels.get(s.clothes, s.clothes), "icon": "👗",
				"owned": state.clothes_owned.has(s.clothes)}, true)
		else: continue
		e["afford"] = coins(state) >= e.price and Inventory.can_afford(state.inventory, e.get("items", {}) if e.kind == "tool" else {})
		out.append(e)
	return out

## Spends the coins. Items go straight into the bag; a blueprint or clothes id comes back for the caller to unlock
## (so the usual "new blueprint" toast and build-menu refresh happen). Returns {ok, reason?, items?, blueprint?, clothes?}.
static func buy(state: Dictionary, npc_id: String, i: int) -> Dictionary:
	if not is_open(state, npc_id): return {"ok": false, "reason": "closed"}
	var line := {}
	for e in stock(state, npc_id):
		if e.i == i: line = e
	if line.is_empty(): return {"ok": false, "reason": "unknown"}
	if line.owned: return {"ok": false, "reason": "owned"}
	if not line.afford: return {"ok": false, "reason": "coins" if coins(state) < line.price else "items", "need": maxi(line.price - coins(state), 0)}
	if line.kind == "tool":
		var up := Tools.upgrade(state, String(line.id))
		if not up.ok: return {"ok": false, "reason": String(up.get("reason", "unknown"))}
		return {"ok": true, "tool": String(line.id), "level": int(up.level), "name": String(up.name), "unlocks": up.unlocks, "price": line.price}
	state.inventory[COIN] = coins(state) - line.price
	match line.kind:
		"items":
			var got := {}
			for k in line.items: got[k] = int(line.items[k])
			Inventory.add(state.inventory, got)
			return {"ok": true, "items": got, "price": line.price}
		"blueprint": return {"ok": true, "blueprint": line.id, "price": line.price}
		"clothes": return {"ok": true, "clothes": line.id, "price": line.price}
	return {"ok": false, "reason": "unknown"}

static func sell_price(npc_id: String, item: String) -> int: return int(def(npc_id).get("buys", {}).get(item, 0))

## What you could sell here now: [{id, have, price}] for items the shop buys and you have.
static func sellable(state: Dictionary, npc_id: String) -> Array:
	var out: Array = []
	var buys: Dictionary = def(npc_id).get("buys", {})
	for id in buys:
		var have := int(state.inventory.get(id, 0))
		if have > 0: out.append({"id": id, "have": have, "price": int(buys[id])})
	return out

static func sell(state: Dictionary, npc_id: String, item: String, n: int) -> Dictionary:
	var price := sell_price(npc_id, item)
	if not is_open(state, npc_id) or price <= 0: return {"ok": false, "reason": "not_bought"}
	n = mini(n, int(state.inventory.get(item, 0)))
	if n <= 0: return {"ok": false, "reason": "none"}
	state.inventory[item] = int(state.inventory[item]) - n
	state.inventory[COIN] = coins(state) + n * price
	return {"ok": true, "coins": n * price, "n": n}

# ---- Gifts --------------------------------------------------------------------------------------------

static func giftable_item(id: String) -> bool:
	return Data.resources.has(id) and not Data.shops.get("noGift", []).has(id)

## Friendship a gift is worth: a treat's value (+1 if they love it), 2 for something they love, otherwise 1.
static func gift_hearts(npc: Dictionary, item: String) -> int:
	if not giftable_item(item): return 0
	var loved: bool = npc.get("likes", []).has(item)
	var treat := int(Data.resources[item].get("treat", 0))
	if treat > 0: return treat + (1 if loved else 0)
	return 2 if loved else 1

## One gift per villager per day.
static func can_gift(state: Dictionary, npc_id: String) -> bool:
	return int(state.relationships.get(npc_id, {}).get("gift_day", 0)) != int(state.time.day) and not gift_options(state, Data.npc(npc_id)).is_empty()

## Items you could give, best first (treats and things they love), at most `limit`.
static func gift_options(state: Dictionary, npc: Dictionary, limit: int = 6) -> Array:
	var ids: Array = Data.resource_order.filter(func(id): return giftable_item(id) and int(state.inventory.get(id, 0)) > 0)
	ids.sort_custom(func(a, b): return gift_hearts(npc, a) > gift_hearts(npc, b))
	return ids.slice(0, limit)

## Takes the item from the bag and marks today's gift. Returns {ok, hearts, loved}; the caller adds the hearts.
static func give_gift(state: Dictionary, npc: Dictionary, item: String) -> Dictionary:
	if int(state.inventory.get(item, 0)) <= 0 or not giftable_item(item): return {"ok": false}
	if not state.relationships.has(npc.id): state.relationships[npc.id] = {"hearts": 0, "talked_day": 0, "gifts": []}
	var rel: Dictionary = state.relationships[npc.id]
	if int(rel.get("gift_day", 0)) == int(state.time.day): return {"ok": false, "reason": "today"}
	state.inventory[item] = int(state.inventory[item]) - 1
	rel["gift_day"] = int(state.time.day)
	var h := gift_hearts(npc, item)
	return {"ok": true, "hearts": h, "loved": h >= 2}
