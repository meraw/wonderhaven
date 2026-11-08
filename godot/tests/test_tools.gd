extends RefCounted
var t
var uid := 1
var statics: Array

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func place(list: Array, id: String, i: float, k: float, hit_y: float = 10.0) -> Dictionary:
	var z: Dictionary = Data.zone("bridge")
	var y := BuildGrid.suggest_bottom(id, i, k, 0, hit_y, list, z)
	var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": 0, "y": y}
	uid += 1
	var v := BuildGrid.validate_placement(pl, {"placements": list, "zones": [z], "statics": statics, "bodies": []})
	if v.ok: list.append(pl)
	v["pl"] = pl
	return v

func _state(done: Array = ["tool", "bridge"]) -> Dictionary:
	var s := GameState.new_game("Tester")
	for q in done: s.quests[q] = {"status": "done", "progress": {}}
	return s

func _play(mg, results: Array) -> void:
	for r in results: mg.results.append(r)

func test_better_tools_make_gathering_quicker_and_richer():
	var s := _state()
	var old := Tools.stats(s, "axe")
	t.ok(old.level == 1 and old.name == "Old hatchet", "you start with the old hatchet")
	Tools.owned(s)["axe"] = 3
	var best := Tools.stats(s, "axe")
	var slow := Minigames.Chop.new(Rng.new(1), old)
	var quick := Minigames.Chop.new(Rng.new(1), best)
	t.ok(quick.width > slow.width and quick.rounds < slow.rounds and quick.rest < slow.rest, "the best axe: a wider green, fewer swings, less waiting")
	_play(slow, ["good", "good", "good"])
	_play(quick, ["good", "good"])
	t.ok(int(quick.reward().wood) > int(slow.reward().wood), "and more wood for fewer swings (%d against %d)" % [quick.reward().wood, slow.reward().wood])
	var pick := Minigames.Mine.new(false, Rng.new(1), "metal", Tools.stats(s, "pick"))
	t.ok(pick.strikes == 3 and pick.target == [0.32, 0.46], "the old pick: three strikes, the usual ring")

func test_a_perfect_run_pays_a_bonus():
	var s := _state()
	var good := Minigames.Chop.new(Rng.new(2), Tools.stats(s, "axe"))
	var perfect := Minigames.Chop.new(Rng.new(2), Tools.stats(s, "axe"))
	_play(good, ["perfect", "perfect", "good"])
	_play(perfect, ["perfect", "perfect", "perfect"])
	t.ok(not good.perfect_run() and perfect.perfect_run(), "only every swing perfect is a perfect run")
	t.eq(int(perfect.reward().wood) - int(good.reward().wood), int(Data.tools.perfect_bonus), "the third swing perfect too: the bonus on top")
	var rock := Minigames.Mine.new(false, Rng.new(2), "metal", Tools.stats(s, "pick"))
	_play(rock, ["perfect", "perfect", "perfect"])
	t.eq(int(rock.reward().stone), 1 + 3 + 1 + int(Data.tools.perfect_bonus), "a perfect run at the quarry: the bonus in stone")

func test_big_oaks_need_the_steel_axe_and_give_beams():
	var s := _state()
	var oaks: Array = Data.layout.nodes.filter(func(n): return n.get("big", false))
	t.ok(oaks.size() >= 2 and oaks.all(func(n): return n.kind == "chop"), "Monteforchetta has big oaks to fell (%d)" % oaks.size())
	t.ok(not Tools.fells(s, oaks[0]) and Tools.fells(s, Data.layout.nodes.filter(func(n): return n.kind == "chop" and not n.get("big", false))[0]), "the old hatchet fells the small trees, not the big oaks")
	Tools.owned(s)["axe"] = 2
	t.ok(Tools.fells(s, oaks[0]), "the steel axe fells them")
	var oak := Minigames.Chop.new(Rng.new(3), Tools.stats(s, "axe"), true)
	_play(oak, ["good", "good", "miss"])
	t.ok(int(oak.reward().get("beam", 0)) >= 1 and int(oak.reward().wood) >= 3, "a big oak gives beams as well as wood: %s" % str(oak.reward()))
	var tree := Minigames.Chop.new(Rng.new(3), Tools.stats(s, "axe"))
	_play(tree, ["good", "good", "miss"])
	t.ok(not tree.reward().has("beam"), "a small tree gives no beams")

func test_the_chisel_dresses_stone():
	var s := _state()
	var plain := Minigames.Mine.new(false, Rng.new(4), "metal", Tools.stats(s, "pick"))
	_play(plain, ["perfect", "perfect", "good"])
	t.ok(not plain.reward().has("cutstone"), "the old pick only breaks stone")
	Tools.owned(s)["pick"] = 2
	var chisel := Minigames.Mine.new(false, Rng.new(4), "metal", Tools.stats(s, "pick"))
	_play(chisel, ["perfect", "perfect", "good"])
	t.eq(int(chisel.reward().get("cutstone", 0)), 2, "with the chisel each perfect strike dresses a block of cut stone")

func test_tools_are_upgraded_at_elios_shop():
	var s := _state()
	s.inventory["coins"] = 1000
	var lines := func(): return Shop.stock(s, "bram").filter(func(e): return e.kind == "tool")
	var axe: Array = lines.call().filter(func(e): return e.id == "axe")
	t.ok(axe.size() == 1 and int(axe[0].level) == 2 and not axe[0].afford, "Elio offers the steel axe, but you need its metal and wood too")
	t.ok(not lines.call().any(func(e): return e.id == "pick"), "the chisel waits for his shop to be done")
	s.inventory.merge({"metal": 2, "wood": 2}, true)
	var line: Dictionary = lines.call().filter(func(e): return e.id == "axe")[0]
	var r := Shop.buy(s, "bram", int(line.i))
	t.ok(r.ok and r.tool == "axe" and r.level == 2 and r.unlocks.has("oakBeam"), "bought: the steel axe, and the oak beam's plan with it")
	t.ok(Tools.level(s, "axe") == 2 and int(s.inventory.metal) == 0 and int(s.inventory.coins) == 1000 - int(Tools.level_def("axe", 2).price), "lire and materials spent")
	t.ok(not lines.call().any(func(e): return e.id == "axe"), "the woodcutter's axe waits for 50 approval")
	s.harmony = 50
	t.ok(lines.call().any(func(e): return e.id == "axe" and int(e.level) == 3), "then Elio has it")
	s.quests["workshop"] = {"status": "done", "progress": {}}
	t.ok(lines.call().any(func(e): return e.id == "pick" and int(e.level) == 2), "the pick and chisel once his shop is open")
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.eq(Tools.level(back, "axe"), 2, "your tools are saved")

func test_lire_buy_the_new_materials():
	var s := _state(["tool", "bridge", "workshop"])
	var items: Array = Shop.stock(s, "bram").filter(func(e): return e.kind == "items")
	t.ok(items.any(func(e): return e.items.has("beam")) and items.any(func(e): return e.items.has("cutstone")), "Elio sells beams and cut stone, for a builder who'd rather not chop")
	var plans: Array = Shop.stock(s, "bram").filter(func(e): return e.kind == "blueprint").map(func(e): return e.id)
	t.ok(plans.has("oakBeam") and plans.has("stoneArch") and plans.has("column"), "and their plans")

func test_beams_reach_further_than_planks():
	var planks: Array = []
	for k in [-15, -16, -17]: t.ok(place(planks, "bridgeDeck", 0, k).ok, "plank %d" % k)
	t.ok(not place(planks, "bridgeDeck", 0, -18).ok, "a plank can't reach three tiles out")
	var beams: Array = []
	for k in [-15, -16, -17, -18, -19]: t.ok(place(beams, "oakBeam", 0, k).ok, "oak beam %d" % k)
	var five := place(beams, "oakBeam", 0, -20)
	t.ok(not five.ok and "4 tiles" in String(five.reason), "an oak beam reaches four tiles, not five: %s" % five.get("reason", ""))
	for k in [-22, -21, -20]: t.ok(place(beams, "oakBeam", 0, k).ok, "oak beam %d from the far bank" % k)
	var w := WalkWorld.new(statics)
	w.surfaces = BuildGrid.surfaces_for(beams)
	t.ok(Validate.path_across(Data.zone("bridge"), w).ok, "oak beams cross the washout without a single post")
	var arch: Array = []
	for k in [-15, -16, -17, -18]: t.ok(place(arch, "stoneArch", 0, k).ok, "stone arch %d" % k)
	t.ok(not place(arch, "stoneArch", 0, -19).ok, "a stone arch reaches three tiles")

func test_a_column_holds_up_a_deck():
	var list: Array = []
	var col := place(list, "column", 0, -18, -1.4)
	t.ok(col.ok and absf(float(col.pl.y) + 1.4) < 0.01, "a stone column stands on the river bed: %s" % col.get("reason", ""))
	t.ok(place(list, "bridgeDeck", 0, -18, 0.1).ok, "and a plank rests on it")
	t.eq(Commission.material("column"), "cutstone", "it's made of cut stone")
	t.eq(Commission.material("oakBeam"), "beam", "an oak beam of beams")
	t.ok(Data.quest("bridge").objectives.filter(func(o): return String(o.get("kind", "")) == "commission")[0].wishes.any(func(w): return w.check == "material" and w.of.has("beam")), "Gigia's all-in-wood counts oak beams as wood")
