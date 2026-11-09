extends Node3D

const BELL := Vector2(-56.4, -56.2)
const LAUNCH_HOURS := [5, 10]
const CART_TOP := -60.0
const CART_BOTTOM := -27.4
const CART_X := 13.65
const CART_LAP := 40.0
const RUN_HOURS := [7, 19]

var game = null
var village: Node3D
var scenery: Script
var cart: Node3D
var rung_at := -100.0

func setup(g, v: Node3D) -> void:
	game = g
	village = v
	scenery = load("res://scripts/locations/cliffs/scenery.gd")
	cart = v.find_child("cliffs_cart1_model", true, false)
	if g == null or not g.has_method("add_interactable"): return
	g.add_interactable({"id": "cliffs_bell", "x": BELL.x, "z": BELL.y, "radius": 1.8, "priority": 0.7,
		"label": func(): return "Ring the sanctuary bell", "act": func(): ring()})

func ring() -> void:
	if game == null: return
	var now := float(game.state.time.total)
	if now - rung_at < 1.0: return
	rung_at = now
	if game.get("audio") != null and game.audio.has_method("play"):
		game.audio.play("bell", 55, 0.5)
		game.audio.play("bell", 62, 0.35, -1, 1.4)
		game.audio.play("bell", 55, 0.45, -1, 2.8)
	game.toast("The sanctuary bell rings out over the terraces and down to the sea.", "", 3.0)
	if game.story: game.story.event("cliffs_bell")

func _process(_dt: float) -> void:
	if game == null or game.get("state") == null: return
	var s: Dictionary = game.state
	var minute := float(s.time.minute)
	var flags: Dictionary = s.flags
	if flags.get("cliffs_boatsReady", false) and not flags.get("cliffs_boats_launched", false) and Clock.in_hours(LAUNCH_HOURS, minute) and not game.get("traveling"):
		game.toast("At dawn the whole village slides the boats down your slipway into the harbour.", "good", 4.0)
		game.set_flag("cliffs_boats_launched")
	if cart != null and flags.get("cliffs_monorailRuns", false):
		var z := CART_BOTTOM
		if Clock.in_hours(RUN_HOURS, minute):
			var t := fmod(minute, CART_LAP) / CART_LAP
			var u := 1.0 - absf(1.0 - 2.0 * t)
			z = lerpf(CART_BOTTOM, CART_TOP, u)
		cart.position = Vector3(CART_X, scenery.rail_ground(z), z)
