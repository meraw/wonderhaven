extends "res://tests/autoplay_base.gd"
## Loading a save made in another place from the title screen, with real mouse input (Load Game, a slot: the same code
## as Continue). Loading one reloads the scene for that place, and the welcome banner must show in the new scene. It
## used to be drawn on the old one after the reload had begun: a script error that, run from the Godot editor, stopped
## the game in the debugger as soon as you pressed Continue on such a save (a player's save in Boccapioppo, 06/11).
## Not covered here: Load from the pause menu into another place works and says "Game loaded", but Godot crashes now
## and then (signal 11) after that reload, with or without this fix; see docs/STATUS.md.
## Run: ./play.sh res://tests/play_load_away.gd /tmp/out --title

const AWAY := "river_town"   # Boccapioppo, reached by Monteforchetta's bus line

func labels_text(root: Node) -> String:
	var out := ""
	for l in root.find_children("*", "Label", true, false): out += (l as Label).text + " "
	return out

func play() -> void:
	# Slot 2: a player who rode the bus on to Boccapioppo; this run starts in Monteforchetta.
	SaveSystem.write("slot2", Progress.as_if_played(["hearthglow"], AWAY, "Pip"))
	game.screens.title(); await frames(10)   # the title screen the game opens on, now listing that save
	var tl: Control = game.screens.find_child("btn_load", true, false)
	check(1, "The title screen offers Load Game", tl != null)
	if tl == null: return
	await click(tl.get_global_rect().get_center()); await frames(10)
	var l2: Control = game.screens.find_child("load_slot2", true, false)
	check(2, "Load Game lists the Boccapioppo save", l2 != null)
	if l2 == null: return
	await click(l2.get_global_rect().get_center())
	var there := await await_island(AWAY, 90.0)
	check(3, "Loading it took you to Boccapioppo", there, Data.island)
	if not there: return
	var b := labels_text(game.banner_box)
	check(4, "The welcome banner shows after the reload", "Welcome back, Pip!" in b and "Boccapioppo" in b, b)
	await shot("loaded-from-title")
	await hold(KEY_W, 1.5)
	check(5, "You can walk off in Boccapioppo", game.mode == "explore", game.mode)
