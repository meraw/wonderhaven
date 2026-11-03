extends RefCounted
## Coins, shops and gifts (Shop, shops.json) and the conversation choices that lead to them.
var t

func _state() -> Dictionary:
	var s := GameState.new_game("Tester")
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	return s

func test_shop_data_is_valid():
	for sid in Data.shops.shops:
		var d: Dictionary = Data.shops.shops[sid]
		t.ok(not Data.npc(sid).is_empty(), "shop %s belongs to a real villager" % sid)
		t.ok(d.has("name") and d.has("stock") and d.has("buys"), "shop %s has a name, stock and a buy list" % sid)
		for q in d.get("requires", {}).get("quests", []): t.ok(not Data.quest(q).is_empty(), "shop %s waits on a real request (%s)" % [sid, q])
		for id in d.buys: t.ok(Data.resources.has(id) and int(d.buys[id]) > 0, "%s buys %s, a real item, for coins" % [sid, id])
		for line in d.stock:
			t.ok(int(line.get("price", 0)) > 0, "every line in %s has a price" % sid)
			if line.has("blueprint"): t.ok(not Data.piece(line.blueprint).is_empty(), "%s sells a real blueprint (%s)" % [sid, line.blueprint])
			if line.has("items"):
				for k in line.items: t.ok(Data.resources.has(k), "%s sells a real item (%s)" % [sid, k])
				# buying something back costs more than selling it, so you can't make coins going round in circles
				for k in line.items:
					var back := 0
					for other in Data.shops.shops: back = maxi(back, Shop.sell_price(other, k))
					t.ok(back * int(line.items[k]) < int(line.price), "%s's %s bundle can't be sold back at a profit" % [sid, k])
			if line.has("clothes"): t.ok(Data.appearance.locked.has(line.clothes), "%s sells a special outfit piece" % sid)
	for n in Data.npcs:
		for id in n.get("likes", []): t.ok(Data.resources.has(id), "%s likes a real item (%s)" % [n.id, id])

func test_buying_spends_coins():
	var s := _state()
	var wood_line: int = Shop.stock(s, "bram").filter(func(e): return e.kind == "items" and e.items.has("wood"))[0].i
	var r := Shop.buy(s, "bram", wood_line)
	t.eq(r.get("reason", ""), "coins", "no coins, no wood")
	s.inventory["coins"] = 20
	r = Shop.buy(s, "bram", wood_line)
	t.ok(r.ok and int(s.inventory.wood) == 5 and Shop.coins(s) == 4, "a bundle of wood for 16 coins (coins left %d)" % Shop.coins(s))
	t.eq(Shop.buy(s, "bram", wood_line).get("need", 0), 12, "says how many more coins you need")

func test_blueprints_are_bought_once():
	var s := _state()
	s.inventory["coins"] = 100
	var line: Dictionary = Shop.stock(s, "bram").filter(func(e): return e.kind == "blueprint" and e.id == "rug")[0]
	var r := Shop.buy(s, "bram", line.i)
	t.ok(r.ok and r.blueprint == "rug" and Shop.coins(s) == 100 - line.price, "buying a blueprint hands it over for the caller to unlock")
	s.blueprints.append("rug")
	t.eq(Shop.buy(s, "bram", line.i).get("reason", ""), "owned", "a blueprint you own isn't sold twice")
	t.ok(Shop.stock(s, "bram").filter(func(e): return e.get("id", "") == "sofa").is_empty(), "lines that need a later request stay hidden")

func test_shops_open_with_the_story():
	var s := GameState.new_game("Tester")
	t.ok(not Shop.is_open(s, "bram"), "Bram's shop is closed before the bridge")
	t.ok(not Shop.is_open(s, "odessa"), "not everyone runs a shop")
	s.quests["bridge"] = {"status": "done"}
	t.ok(Shop.is_open(s, "bram"), "it opens once the bridge is done")
	t.eq(Shop.buy(GameState.new_game("T"), "bram", 0).get("reason", ""), "closed", "a closed shop sells nothing")

func test_selling_pays_coins():
	var s := _state()
	s.inventory["wood"] = 7; s.inventory["fish"] = 2
	t.eq(Shop.sellable(s, "bram").map(func(e): return e.id), ["wood"], "Bram only wants what he buys")
	var r := Shop.sell(s, "bram", "wood", 5)
	t.ok(r.ok and int(s.inventory.wood) == 2 and Shop.coins(s) == 10, "5 wood for 10 coins")
	r = Shop.sell(s, "bram", "wood", 99)
	t.ok(r.ok and r.n == 2 and int(s.inventory.wood) == 0, "can't sell more than you have")
	t.ok(not Shop.sell(s, "bram", "fish", 1).ok, "Bram doesn't buy fish")

func test_gifts_raise_friendship_once_a_day():
	var s := _state()
	var bram := Data.npc("bram")
	s.inventory["pie"] = 2; s.inventory["flowers"] = 1; s.inventory["fragment"] = 3
	t.eq(Shop.gift_hearts(bram, "pie"), 4, "a treat he loves: the treat's value plus one")
	t.eq(Shop.gift_hearts(bram, "flowers"), 1, "anything else: one heart")
	t.eq(Shop.gift_hearts(bram, "fragment"), 0, "magic fragments aren't gifts")
	t.eq(Shop.gift_options(s, bram), ["pie", "flowers"], "the best gifts come first; fragments aren't offered")
	t.ok(Shop.can_gift(s, "bram"), "you can give him something today")
	var r := Shop.give_gift(s, bram, "pie")
	t.ok(r.ok and r.loved and int(s.inventory.pie) == 1, "the pie leaves your bag")
	t.ok(not Shop.can_gift(s, "bram") and not Shop.give_gift(s, bram, "pie").ok, "one gift a day")
	s.time.day += 1
	t.ok(Shop.can_gift(s, "bram"), "tomorrow you can give another")

func test_conversation_offers_shop_and_gift():
	var s := _state()
	var e := QuestEngine.new(s)
	var kinds := func(id): return Conversation.build(Data.npc(id), e, s.flags, s.name).options.map(func(o): return o.kind)
	t.ok(kinds.call("bram").has("shop"), "Bram offers to trade")
	t.ok(not kinds.call("odessa").has("shop"), "Odessa has no shop")
	t.ok(not kinds.call("bram").has("gift"), "nothing to give, no gift choice")
	s.inventory["wood"] = 1
	t.ok(kinds.call("bram").has("gift"), "with something in your bag you can give a gift")
	var opts: Array = Conversation.build(Data.npc("bram"), e, s.flags, s.name).options
	t.eq(opts.back().kind, "bye", "goodbye stays last")

func test_blueprint_hint_names_the_shop():
	var e := QuestEngine.new(_state())
	t.ok(e.blueprint_hint("counter").contains("Bram's Timber"), "a shop blueprint also says where to buy it (%s)" % e.blueprint_hint("counter"))
	t.ok(not e.blueprint_hint("bridgeDeck").contains("buy"), "others don't (%s)" % e.blueprint_hint("bridgeDeck"))
