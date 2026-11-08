extends RefCounted
## Waking up from a nap on a bench (BenchNap, data/naps.json).
var t

func _at(slot: int, into: float = 10.0) -> Dictionary:
	var day := int(slot / 6); var minute := float(slot % 6) * Daylight.SLOT_MINUTES + into
	return {"day": day, "minute": minute, "total": float(day) * 1440.0 + minute}

func test_rain_while_you_napped():
	var wet := -1; var dry := -1
	for slot in range(12, 400):   # past the always-sunny first days
		var w := Daylight.slot_weather(slot)
		if wet < 0 and BenchNap.RAINY.has(w): wet = slot
		if dry < 0 and not BenchNap.RAINY.has(w) and not BenchNap.RAINY.has(Daylight.slot_weather(slot + 1)): dry = slot
	t.ok(wet > 0 and dry > 0, "the weather has rainy and dry spells (%d, %d)" % [wet, dry])
	t.ok(BenchNap.rained(_at(wet - 1), _at(wet + 1)), "a nap across a rainy spell gets rained on")
	t.ok(not BenchNap.rained(_at(dry), _at(dry + 1)), "a nap in dry weather doesn't")
	t.ok(not BenchNap.rained(_at(wet - 1), _at(wet + 1), ["clear"]), "nor anywhere that only allows clear weather")
	t.ok(BenchNap.rained(_at(dry), _at(dry + 1), [], {"type": "rain", "until": _at(dry).total + 60.0}), "a storm a request brought counts too")
	t.ok(not BenchNap.rained(_at(dry), _at(dry + 1), [], {"type": "rain", "until": _at(dry).total - 1.0}), "...but not one that was over before you lay down")
	var early := -1
	for slot in range(12, 400):
		if BenchNap.RAINY.has(Daylight.slot_weather(slot)) and not BenchNap.RAINY.has(Daylight.slot_weather(slot + 1)) and not BenchNap.RAINY.has(Daylight.slot_weather(slot + 2)):
			early = slot
			break
	t.ok(early > 0 and not BenchNap.rained(_at(early), _at(early + 2, 200.0)), "rain early in the night that stopped hours before you woke leaves you dry")
	t.ok(BenchNap.rained(_at(early), _at(early + 1, 100.0)), "rain that stopped just before you woke doesn't")
	t.ok(float(Data.naps.get("overnight", 1.0)) < 1.0, "and a night on a bench doesn't always end in a joke")

func test_which_gag():
	var naps := {"chance": 0.5, "gags": {"newspaper": {"weight": 3}, "umbrella": {"weight": 1}, "stared": {"weight": 2}, "rain": {}}}
	var who := {"watchers": ["Gigia"]}
	t.eq(BenchNap.pick(naps, {"indoors": true, "rained": true}, 0.0, 0.0), "", "a sofa indoors: nothing happens")
	t.eq(BenchNap.pick(naps, {"rained": true}, 0.99, 0.0), "rain", "rained on: always soaked")
	t.eq(BenchNap.pick(naps, who, 0.5, 0.0), "", "most naps are quiet (roll over the chance)")
	var seen := {}
	for i in 60:
		var g := BenchNap.pick(naps, who, 0.1, (i + 0.5) / 60.0)
		seen[g] = int(seen.get(g, 0)) + 1
	t.eq(seen.keys().size(), 3, "every gag turns up (%s)" % str(seen))
	t.ok(seen.newspaper > seen.stared and seen.stared > seen.umbrella, "as often as their weights say (%s)" % str(seen))
	var alone := {}
	for i in 60: alone[BenchNap.pick(naps, {}, 0.1, (i + 0.5) / 60.0)] = true
	t.ok(not alone.has("stared") and alone.size() == 2, "nobody to stare without a villager around (%s)" % str(alone.keys()))
	var again := {}
	for i in 60: again[BenchNap.pick(naps, {"watchers": ["Gigia"], "last": "newspaper"}, 0.1, (i + 0.5) / 60.0)] = true
	t.ok(not again.has("newspaper"), "never the same gag twice in a row")
	t.eq(BenchNap.pick({"chance": 1.0, "gags": {"newspaper": {"weight": 1}}}, {"last": "newspaper"}, 0.0, 0.5), "newspaper", "...unless it's the only one")

func test_lines():
	var naps: Dictionary = Data.naps
	t.ok(float(naps.chance) > 0.0 and float(naps.chance) < 1.0, "a gag some of the time, not every time")
	for id in ["newspaper", "umbrella"]:
		var lines: Array = naps.gags.get(id, {}).get("lines", [])
		t.ok(lines.size() >= 2, "%s has a few lines to vary" % id)
		for i in lines.size():
			var l := BenchNap.line(naps, id, (i + 0.5) / lines.size(), "Gigia")
			t.ok(l != "" and not l.contains("{") and not l.contains("}"), "every blank filled: %s" % l)
	t.ok(BenchNap.line(naps, "newspaper", 0.0).contains(String(naps.paper)), "the local paper is named")
	# sight gags aren't explained: the villager caught staring and waking up soaked play out with no line
	for id in ["stared", "rain"]:
		t.ok(naps.gags[id].get("visual", false) and BenchNap.line(naps, id, 0.0, "Gigia") == "", "%s is a sight gag, with nothing on screen explaining it" % id)

func test_a_place_can_have_its_own_paper():
	var saved: Dictionary = Data.layout
	Data.layout = saved.duplicate(); Data.layout["naps"] = {"paper": "Gazzetta del Fiume", "chance": 0.5}
	var here: Dictionary = Data.naps_here()
	Data.layout = saved
	t.ok(here.paper == "Gazzetta del Fiume" and float(here.chance) == 0.5 and here.gags.has("stared"), "a layout's naps block overrides keys and keeps the rest")
	t.eq(Data.naps_here().paper, Data.naps.paper, "elsewhere, the shared paper")

func test_beds_are_dear():
	# A bed costs lire as well as materials, more than the farmhouse's deed: you save up, and nap on benches meanwhile
	var bed: Dictionary = Data.piece("bed")
	var deed: int = int(Data.quest("home").objectives[0].items.coins)
	t.ok(int(bed.cost.get("coins", 0)) > deed, "a bed (%d coins) costs more than the farmhouse (%d)" % [bed.cost.get("coins", 0), deed])
	for p in Data.pieces:
		if p.cat == "furniture" and p.id != "bed": t.ok(int(p.cost.get("coins", 0)) < int(bed.cost.coins), "%s is cheaper than a bed" % p.id)
	t.eq(int(Data.piece("bench").cost.get("coins", 0)), 0, "benches cost no money")
	t.ok(Data.quest("home").objectives[1].musts.any(func(n): return n.get("any", []).has("bed")), "your home still needs a bed")
	var inv := {"wood": 3, "fabric": 2, "coins": 50}
	t.ok(not Inventory.can_afford(inv, bed.cost) and Inventory.missing(inv, bed.cost) == [{"id": "coins", "need": int(bed.cost.coins) - 50}], "materials alone aren't enough")

func test_costs_show_money_as_lire():
	t.eq(BuildMode._cost_text({"wood": 3, "fabric": 2, "coins": 120}), "%s3 %s2 %s120,000" % [Data.resources.wood.icon, Data.resources.fabric.icon, Data.resources.coins.icon], "money in lire, after the materials")
	t.eq(BuildMode._cost_text({"wood": 3, "coins": 120}, "\n"), "%s3\n%s120,000" % [Data.resources.wood.icon, Data.resources.coins.icon], "on its own line in the catalog")
	t.eq(BuildMode._cost_text({"wood": 1}), "%s1" % Data.resources.wood.icon, "no money, no lire")

func test_a_place_can_rule_out_pieces():
	# A future city's gag: furnish your flat with anything but a bed (every bed in town sold out), so you sleep on
	# benches. A layout's "noBuild" maps a piece to the reason the build menu shows.
	var pl := {"id": "bed", "i": 0.0, "k": 0.0, "r": 0, "y": 0.0}
	var why := "Every bed in town is sold out until spring. There are benches."
	t.eq(BuildGrid.validate_placement(pl, {"no_build": {"bed": why}}), {"ok": false, "reason": why}, "a ruled-out piece is refused with its reason")
	t.ok(BuildGrid.validate_placement(pl, {}).reason != why, "elsewhere it's the usual checks")
	var chair := pl.duplicate(); chair.id = "chair"
	t.ok(BuildGrid.validate_placement(chair, {"no_build": {"bed": why}}).reason != why, "other pieces aren't affected")
