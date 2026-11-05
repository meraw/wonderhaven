extends RefCounted
func run() -> void:
	Data.use_island("metropolis")
	var s: Dictionary = Progress.as_if_played(["hearthglow", "rice_village"], "metropolis", "Pip")
	print("coins ", s.inventory.get("coins", 0), " harmony ", s.harmony, " island ", s.island, " player ", s.player)
	print("hasTool ", s.flags.get("hasTool", false), " trainStops ", s.flags.get("rice_village_trainStops", false), " boatReady ", s.flags.get("boatReady", false))
	print("inventory ", s.inventory)
	print("tutorial ", s.tutorial)
	print("blueprints ", s.blueprints.size(), " ", s.blueprints)
	print("quests done ", s.quests.keys())
	print("time ", s.time)
