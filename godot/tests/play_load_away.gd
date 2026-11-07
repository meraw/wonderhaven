extends "res://tests/autoplay_base.gd"
## Loading a save made in another place, with real mouse and key input: from the title screen when the game starts
## (Load Game, a slot: the same code as Continue), then from the pause menu (Escape, Load game, a slot) back home.
## Loading one reloads the scene for that place, and the welcome banner (or "Game loaded") must show in the new scene.
## It used to be drawn on the old one after the reload had begun: a script error that, run from the Godot editor,
## stopped the game in the debugger as soon as you pressed Continue on such a save (a player's save in Boccapioppo,
## 06/11). Two swaps in one run also cover await_island not touching the freed old game (it crashed runs, not play).
## Run: ./play.sh res://tests/play_load_away.gd /tmp/out --title

const AWAY := "river_town"   # Boccapioppo, reached by Monteforchetta's bus line

func labels_text(root: Node) -> String:
	var out := ""
	for l in root.find_children("*", "Label", true, false): out += (l as Label).text + " "
	return out

func play() -> void:
	# Slot 1: a new game in Monteforchetta. Slot 2: a player who rode the bus on to Boccapioppo.
	SaveSystem.write("slot1", game.state)
	SaveSystem.write("slot2", Progress.as_if_played(["hearthglow"], AWAY, "Pip"))
	game.screens.title(); await frames(10)   # the title screen the game opens on, now listing those saves
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
	# In Boccapioppo: Escape, Load game, slot 1 (Monteforchetta).
	await frames(20)
	await tap(KEY_ESCAPE); await frames(10)
	var lg: Control = game.panels.find_child("btn_load_game", true, false)
	check(5, "Escape opens the pause menu with Load game", lg != null, game.panels.current)
	if lg == null: return
	await click(lg.get_global_rect().get_center()); await frames(10)
	var lb: Button = game.panels.find_child("slot_slot1", true, false)
	check(6, "Load game lists the Monteforchetta save", lb != null and not lb.disabled)
	if lb == null or lb.disabled: return
	await click(lb.get_global_rect().get_center())
	var home := await await_island("hearthglow", 90.0)
	check(7, "Loading it took you to Monteforchetta", home, Data.island)
	if not home: return
	check(8, "It says the game was loaded", "Game loaded" in labels_text(game.ui_root), "")
	await shot("loaded-from-pause")
	await hold(KEY_W, 1.5)
	check(9, "You can walk off in Monteforchetta", game.mode == "explore", game.mode)
