class_name MachineMarks
extends Node3D

const POWER := Color("ff9a1f")
const WATER := Color("2f9cff")
const NEAR := 20.0

var ghost_marks := Node3D.new()
var placed_marks := Node3D.new()
var target_marks := Node3D.new()
var _mats := {}
var _key := ""
var _ghost_key := ""

func _init() -> void:
	name = "MachineMarks"
	ghost_marks.name = "ghost"; placed_marks.name = "placed"; target_marks.name = "targets"
	add_child(ghost_marks); add_child(placed_marks); add_child(target_marks)
	visible = false

func _mat(type: String, live: bool) -> StandardMaterial3D:
	var key := "%s%s" % [type, live]
	if not _mats.has(key):
		var m := Palette.glow_mat(POWER if type == "power" else WATER, 0.95 if live else 0.5)
		m.no_depth_test = true
		_mats[key] = m
	return _mats[key]

static func color_of(type: String) -> Color: return POWER if type == "power" else WATER

static func mark_spots(pl: Dictionary) -> Array:
	var d := Data.piece(pl.id)
	var fp := BuildGrid.footprint(d, int(pl.r))
	var centre := Vector3(float(pl.i) + fp.x / 2.0, float(pl.y) + minf(float(d.get("h", 1.0)) * 0.5, 0.6), float(pl.k) + fp.y / 2.0)
	var out: Array = []
	var ports := Mechanics.ports_of(pl)
	for side in BuildGrid.SIDES:
		if not ports.has(side): continue
		var dv: Vector2i = BuildGrid.SIDE_DIR[side]
		out.append({"side": side, "type": String(ports[side]), "at": centre + Vector3(dv.x, 0, dv.y) * 0.46, "dir": Vector3(dv.x, 0, dv.y)})
	return out

func _add_marks(root: Node3D, pl: Dictionary, live: bool) -> void:
	for s in mark_spots(pl):
		var nub := Palette.mi(Palette.box(0.2, 0.2, 0.2), _mat(String(s.type), live), s.at, false)
		nub.name = "port_%s_%s" % [s.side, s.type]
		root.add_child(nub)

func show_ghost(pl: Dictionary) -> void:
	var key := "" if pl.is_empty() else "%s|%s|%s|%s|%s" % [pl.id, pl.i, pl.k, pl.r, pl.y]
	if key == _ghost_key: return
	_ghost_key = key
	for c in ghost_marks.get_children(): ghost_marks.remove_child(c); c.queue_free()
	if pl.is_empty() or not Data.piece(pl.id).has("mech"): return
	_add_marks(ghost_marks, pl, true)

func refresh(placements: Array, solved: Dictionary, targets: Array, focus: Vector3, version: int) -> void:
	var key := "%d|%d|%d" % [version, int(floor(focus.x / 4.0)), int(floor(focus.z / 4.0))]
	if key == _key: return
	_key = key
	for c in placed_marks.get_children(): placed_marks.remove_child(c); c.queue_free()
	for c in target_marks.get_children(): target_marks.remove_child(c); c.queue_free()
	for pl in placements:
		if not Data.piece(pl.id).has("mech"): continue
		if Vector2(float(pl.i) - focus.x, float(pl.k) - focus.z).length() > NEAR: continue
		var live: bool = solved.get("powered", {}).has(pl.uid) or solved.get("watered", {}).has(pl.uid) or solved.get("sources", {}).has(pl.uid)
		_add_marks(placed_marks, pl, live)
	for tg in targets:
		var spot := target_spot(tg)
		if Vector2(spot.x - focus.x, spot.z - focus.z).length() > NEAR: continue
		_add_target(tg, spot, bool(solved.get("fed", {}).get(tg.id, false)))

static func target_spot(tg: Dictionary) -> Vector3:
	var dv: Vector2i = BuildGrid.SIDE_DIR[String(tg.side)]
	var x := float(tg.cell[0]) + 0.5 + dv.x * 0.5
	var z := float(tg.cell[1]) + 0.5 + dv.y * 0.5
	return Vector3(x, maxf(Heightfield.height(x, z), Heightfield.WATER_Y) + 0.5, z)

static func target_text(tg: Dictionary, fed: bool) -> String:
	var what := "Power" if String(tg.get("type", "water")) == "power" else "Water"
	return "%s\n%s" % [String(tg.get("label", tg.id)), ("%s arrives ✔" % what) if fed else ("%s goes in here" % what)]

func _add_target(tg: Dictionary, spot: Vector3, fed: bool) -> void:
	var type := String(tg.get("type", "water"))
	var arrow := Node3D.new(); arrow.name = "target_" + String(tg.id)
	arrow.position = spot
	var dv: Vector2i = BuildGrid.SIDE_DIR[String(tg.side)]
	arrow.rotation.y = atan2(-float(dv.x), -float(dv.y))
	var tip := Palette.mi(Palette.cone(0.22, 0.4, 14), _mat(type, true), Vector3(0, 0, -0.2), false); tip.rotation.x = -PI / 2; arrow.add_child(tip)
	var stem := Palette.mi(Palette.cyl(0.07, 0.07, 0.5, 10), _mat(type, true), Vector3(0, 0, 0.25), false); stem.rotation.x = PI / 2; arrow.add_child(stem)
	target_marks.add_child(arrow)
	var l := Label3D.new(); l.name = "label_" + String(tg.id)
	l.text = target_text(tg, fed); l.font = UiTheme.main_font(); l.font_size = 30; l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.modulate = color_of(type).darkened(0.35); l.outline_modulate = Color.WHITE; l.outline_size = 14; l.no_depth_test = true
	l.position = spot + Vector3(0, 0.9, 0)
	target_marks.add_child(l)
