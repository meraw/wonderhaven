extends "res://tests/autoplay_base.gd"
## Coins and shops with real input: open Mabel's bakery shop from her conversation, buy bread, sell apples, then
## give her a gift from your bag and see her friendship grow.

func choices_up(id: String) -> void:
	var a = game.npcs[id]
	game.player.teleport(a.pos.x + 0.5, a.pos.z + 1.9, atan2(-0.5, -1.9)); game.cam.snap(); await frames(5)
	await tap(KEY_E)
	for n in 80:
		await frames(4)
		if not game.dialogue.choices.is_empty(): return
		if game.mode == "dialogue": await tap(KEY_E)

## Picks the dialogue choice of this kind with its number key.
func pick(kind: String) -> bool:
	var i: int = game.dialogue.choices.map(func(o): return o.get("kind", "")).find(kind)
	if i < 0: return false
	await tap(KEY_1 + i)
	return true

func press(name: String) -> bool:
	var b := game.panels.find_child(name, true, false) as Button
	if b == null or b.disabled: return false
	await click(b.get_global_rect().get_center())
	await frames(6)
	return true

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}}
	s.flags["hasTool"] = true; s.flags["toolGiven"] = true; s.flags["orchardOpen"] = true
	s.tutorial.on = false; game.hud.apply_reveals()
	s.time.minute = 10 * 60.0
	for a in game.npcs.values(): a.teleport_home()   # straight to where their routine puts them now (the Sindaco leaves the gate once he's welcomed you)
	s.inventory["coins"] = 20; s.inventory["fruit"] = 6
	game.render_resources()
	await frames(10)
	# Mabel works behind her counter mid-morning
	for i in 600:
		await frames(2)
		if Vector2(game.npcs.mabel.pos.x + 11.8, game.npcs.mabel.pos.z + 7.95).length() < 1.2: break
	await choices_up("mabel")
	check("option", "Mabel offers her shop in conversation", game.dialogue.choices.any(func(o): return o.kind == "shop"), str(game.dialogue.choices.map(func(o): return o.label)))
	await shot("mabel-choices")
	await pick("shop")
	for n in 60:
		await frames(4)
		if game.panels.current == "shop": break
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	check("panel", "Choosing it opens the bakery shop", game.panels.current == "shop", "panel '%s', mode %s" % [game.panels.current, game.mode])
	await frames(20)
	await shot("shop-buy")
	var ok := await press("buy_0")
	check("buy", "Buying bread takes 8,000 lire", ok and int(s.inventory.get("bread", 0)) == 1 and Shop.coins(s) == 12, "bread %d, coins %d" % [int(s.inventory.get("bread", 0)), Shop.coins(s)])
	await press("tab_sell")
	await frames(10)
	await shot("shop-sell")
	ok = await press("sell_fruit_all")
	check("sell", "Selling 6 hazelnuts pays 24,000 lire", ok and int(s.inventory.get("fruit", 0)) == 0 and Shop.coins(s) == 36, "fruit %d, coins %d" % [int(s.inventory.get("fruit", 0)), Shop.coins(s)])
	var chip := game.hud_res.find_child("res_coins", true, false) as Control
	check("hud", "The money counter shows the new total in lire", chip != null and (chip.get_child(0) as Label).text.ends_with("36,000 lire"), (chip.get_child(0) as Label).text if chip else "no chip")
	await tap(KEY_ESCAPE); await frames(10)
	check("closed", "Esc closes the shop", game.panels.current == "" and game.mode == "explore", "mode %s" % game.mode)
	# a gift: the bread she just baked
	var before := int(s.relationships.get("mabel", {}).get("hearts", 0))
	await choices_up("mabel")
	ok = await pick("gift")
	for n in 20:
		await frames(4)
		if game.dialogue.choices.any(func(o): return o.get("id", "") == "bread"): break
	await shot("gift-choices")
	ok = ok and await pick("item")   # best gift first: the bread
	for n in 40:
		await frames(4)
		if not game.dialogue.choices.is_empty(): break
		if game.dialogue.choices.is_empty() and not game.dialogue.typing: await tap(KEY_E)
	var after := int(s.relationships.get("mabel", {}).get("hearts", 0))
	check("gift", "Giving Mabel the bread raises her friendship by 2 hearts", ok and int(s.inventory.get("bread", 0)) == 0 and after - before == 2, "hearts %d -> %d" % [before, after])
	check("once", "Only one gift a day", not game.dialogue.choices.any(func(o): return o.kind == "gift"), str(game.dialogue.choices.map(func(o): return o.kind)))
	await tap(KEY_ESCAPE)
	for k in 30:
		await frames(4)
		if game.mode != "dialogue": break
		await tap(KEY_ESCAPE if not game.dialogue.choices.is_empty() else KEY_E)
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	check("saved", "Coins and today's gift are kept in the save", int(back.inventory.get("coins", 0)) == 36 and int(back.relationships.mabel.get("gift_day", 0)) == int(s.time.day), str(back.inventory.get("coins", 0)))
	# A request step paid in coins: the deed for your own plot
	game.story.accept("home")
	s.inventory["coins"] = 120; game.render_resources()
	await frames(10)
	check("deed-marker", "The Sindaco shows he's waiting for the deed money", game.story.marker_for("percival") == "ready", game.story.marker_for("percival"))
	await choices_up("percival")
	for n in 3:   # if he opens with another offer of his own: not now
		if not game.dialogue.choices.any(func(o): return o.kind == "no"): break
		await pick("no")
		for k in 60:
			await frames(4)
			if not game.dialogue.choices.is_empty(): break
			if not game.dialogue.typing: await tap(KEY_E)
	var has_pay: bool = game.dialogue.choices.any(func(o): return o.kind == "pay")
	await shot("deed-choices")
	await pick("pay")
	for n in 60:
		await frames(4)
		if game.mode == "dialogue" and not game.dialogue.choices.is_empty(): break
		if game.mode == "dialogue": await tap(KEY_E)
	check("deed", "Paying 100,000 lire in conversation buys the deed: the plot opens with its blueprints", has_pay and game.state.flags.get("homePlot", false) and Shop.coins(s) == 20 and s.blueprints.has("roof") and game.story.engine.current_stage("home") == 1,
		"pay offered=%s homePlot=%s coins=%d step=%d" % [has_pay, game.state.flags.get("homePlot", false), Shop.coins(s), game.story.engine.stage_index("home")])
	await tap(KEY_ESCAPE)
	for k in 30:
		await frames(4)
		if game.mode != "dialogue": break
		await tap(KEY_ESCAPE if not game.dialogue.choices.is_empty() else KEY_E)
