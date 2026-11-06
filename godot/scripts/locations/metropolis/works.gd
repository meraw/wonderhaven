extends Node
## The parts of Toriano that answer your requests: the old crane swings and lifts marble once a waterwheel drives
## it; the Golden Angel shines over the square after dark once she's been lit on Christmas Eve; standing up on the
## cathedral's roof terrace counts for the scaffolding request; and the portable radio and the framed front page turn
## up in your flat when La Sera di Toriano sends them.

const P := "metropolis_"
const Kit := preload("res://scripts/locations/metropolis/kit.gd")
const Glow := preload("res://scripts/locations/metropolis/glow.gd")
const AISLE := Rect2(19.6, 7.0, 50.4, 8.0)   # the south aisle, whose roof is the terrace the scaffolding reaches

var village
var game
var crane: Node3D
var angel: Node3D
var angel_mat: StandardMaterial3D
var angel_light: OmniLight3D
var radio: Node3D
var front_page: Node3D
var lit_before := false
var t := 0.0

func setup(v: Node3D) -> void:
	village = v; game = v.get_parent()
	crane = v.find_child("metropolis_crane", false, false)
	var nave: Node3D = v.objects.get(P + "duomo")
	if nave and nave.has_meta("angel"):
		angel = nave.get_meta("angel")
		var fig := angel.find_child("figure", false, false) as MeshInstance3D
		if fig: angel_mat = fig.material_override as StandardMaterial3D
		angel_light = OmniLight3D.new(); angel_light.omni_range = 14.0; angel_light.light_color = Color("ffd98a"); angel_light.light_energy = 0.0
		angel_light.position = Vector3(0, 1.0, 1.6); angel.add_child(angel_light)
	radio = _radio(); radio.position = Vector3(-24.3, 3.5, 108.3); radio.visible = false; v.add_child(radio)
	front_page = _front_page(); front_page.position = Vector3(-27.6, 5.1, 107.32); front_page.visible = false; v.add_child(front_page)
	lit_before = _lit()

func _flag(f: String) -> bool: return game != null and game.state.flags.get(P + f, false)
func _lit() -> bool: return _flag("angel_on") or _flag("angel_lit")

func _process(dt: float) -> void:
	if game == null or not game.get("state") is Dictionary or game.get("player") == null: return
	t += dt
	var mech = game.get("mech")
	# the crane, once the waterwheel drives it: the jib swings out over the barge and back, the hook rises with a block
	if crane:
		var driven: bool = mech is Dictionary and mech.get("fed", {}).get(P + "crane", false)
		var jib := crane.get_node("jib") as Node3D
		var hook := jib.get_node("hook") as Node3D
		if driven:
			jib.rotation.y = sin(t * 0.25) * 0.7
			hook.position.y = 4.7 - 2.0 * (0.5 + 0.5 * sin(t * 0.5))
		(hook.get_node("block") as Node3D).visible = driven or _flag("crane_running")
	# the Golden Angel, after dark, once lit on Christmas Eve
	if angel_mat:
		var lit := _lit()
		var glow: float = Glow.level if lit else 0.0   # (after dusk, which comes at five here)
		angel_mat.emission_energy_multiplier = 0.25 + 3.5 * glow
		angel_light.light_energy = 2.5 * glow
		if lit and not lit_before:
			game.effects.sparkle(angel.global_position + Vector3(0, 1.0, 0), 60, Color("fff2a8"), 0.6)
			game.sfx("fanfare")
		lit_before = lit
	# standing on the cathedral's roof terrace (the scaffolding request's last step)
	var p: Vector3 = game.player.pos
	if p.y > 5.9 and AISLE.has_point(Vector2(p.x, p.z)) and not _flag("on_roof"):
		game.set_flag(P + "on_roof")
		game.story.event("on_roof")   # (setting a flag alone doesn't look at the requests again: the step ticks now)
	radio.visible = _flag("radio")
	front_page.visible = _flag("front_page")

## A portable radio-cassette player, the paper's present.
static func _radio() -> Node3D:
	var m := Kit.Merge.new()
	m.box(Vector3(0, 0.16, 0), Vector3(0.62, 0.3, 0.2), Color("2b2b3a"))
	for s in [-1, 1]: m.cyl(Vector3(s * 0.19, 0.16, 0.1), 0.09, 0.02, Color("6b6b7a"), 12)
	m.box(Vector3(0, 0.27, 0.1), Vector3(0.18, 0.06, 0.02), Color("a9adb0"))
	m.box(Vector3(0, 0.36, 0), Vector3(0.5, 0.03, 0.03), Color("a9adb0"))   # the handle
	var g := Node3D.new(); g.name = "metropolis_radio"; g.add_child(m.node(Kit.vc_mat(), "radio")); return g

## The framed front page of Christmas Day: the Angel, and your name under the headline.
static func _front_page() -> Node3D:
	var m := Kit.Merge.new()
	m.box(Vector3.ZERO, Vector3(0.9, 1.2, 0.04), Color("5a3d2b"))
	m.box(Vector3(0, 0, 0.025), Vector3(0.78, 1.08, 0.01), Color("efe9df"))
	m.box(Vector3(0, 0.42, 0.032), Vector3(0.66, 0.12, 0.004), Color("1d1414"))   # the masthead
	m.box(Vector3(0, 0.05, 0.032), Vector3(0.5, 0.5, 0.004), Color("d9a03a"))     # the photo of the Angel
	for k in 4: m.box(Vector3(0, -0.3 - k * 0.06, 0.032), Vector3(0.62, 0.02, 0.004), Color("6b6b6b"))
	var g := Node3D.new(); g.name = "metropolis_front_page"; g.add_child(m.node(Kit.vc_mat(), "page")); return g
