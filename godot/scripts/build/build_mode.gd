class_name BuildMode
extends Node
## Starforge build mode: catalog, transparent preview, grid snapping, placement, selection, move, rotate,
## remove, recolour, undo/redo. The rules live in BuildGrid; this is the interactive layer.

var game
var active := false
var category := "structure"
var item_id := ""
var rotation := 0
var color := ""
var half := false
var selected := -1
var moving := {}                 # {pl, from, r}
var history := History.new()
var focus := Vector3.ZERO
var current_zone := {}
var zone_index := 0
var grid_root := Node3D.new()
var plan_root := Node3D.new()
var ghost: Node3D
var ghost_key := ""
var hover := {}
var check := {}
var mouse := Vector2.ZERO
var ui: Control
var status_label: Label
var sel_box: MeshInstance3D
var pad_cursor: Label

func setup(g) -> void:
	game = g
	grid_root.name = "BuildGrid"; grid_root.visible = false
	game.add_child(grid_root); game.add_child(plan_root)
	sel_box = MeshInstance3D.new(); sel_box.visible = false
	var bm := BoxMesh.new(); sel_box.mesh = bm
	var sm := Palette.glow_mat(Color("a07cff"), 0.25); sel_box.material_override = sm
	game.add_child(sel_box)

func state() -> Dictionary: return game.state
func unlocked_zones() -> Array: return Data.layout.zones.filter(func(z): return game.zone_unlocked(z))

func open(zone_id: String = "") -> bool:
	if not state().flags.get("hasTool", false):
		game.toast("You need the Starforge Tool first — Odessa might know where it is!", "warn"); return false
	active = true
	var zones := unlocked_zones()
	var p: Vector3 = game.player.pos
	var zone := {}
	for z in zones:
		if z.id == zone_id: zone = z
	if zone.is_empty(): zone = BuildGrid.zone_at(zones, floor(p.x), floor(p.z), state().harmony)
	if zone.is_empty() and not zones.is_empty():
		zones.sort_custom(func(a, b): return _zdist(a, p) < _zdist(b, p))
		zone = zones[0]
	zone_index = maxi(0, unlocked_zones().find(zone))
	jump_to(zone)
	rebuild_grid(); refresh_plan()
	grid_root.visible = true
	game.cam.set_mode("build")
	game.player_char.play("build", true); game.player_char.show_staff(true)
	_build_ui()
	game.emit_event("buildmode", {"open": true})
	return true

func close() -> void:
	if not moving.is_empty(): cancel_move()
	active = false; item_id = ""; selected = -1
	_clear_ghost(); sel_box.visible = false; grid_root.visible = false
	game.cam.set_mode("explore")
	game.player_char.stop_hold()
	if ui: ui.queue_free(); ui = null
	if pad_cursor: pad_cursor.visible = false
	game.emit_event("buildmode", {"open": false})

func _over_ui(p: Vector2) -> bool:
	if ui == null: return false
	for c in ui.find_children("*", "Control", true, false):
		if c is PanelContainer and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p): return true
	return false

func _zdist(z: Dictionary, p: Vector3) -> float: return Vector2((z.minI + z.maxI) / 2.0 - p.x, (z.minK + z.maxK) / 2.0 - p.z).length()

func jump_to(zone: Dictionary) -> void:
	current_zone = zone
	if zone.is_empty(): focus = game.player.pos; return
	var b := BuildGrid.zone_bounds(zone, state().harmony)
	focus = Vector3((b.minI + b.maxI + 1) / 2.0, maxf(0.0, zone.get("spanY", 0.0)), (b.minK + b.maxK + 1) / 2.0)

func cycle_zone(dir: int) -> void:
	var zones := unlocked_zones()
	if zones.is_empty(): return
	zone_index = (zone_index + dir + zones.size()) % zones.size()
	jump_to(zones[zone_index]); _build_ui()

# ---- Grid and plan visuals
func _cell_y(zone: Dictionary, i: int, k: int) -> float:
	var g := Heightfield.height(i + 0.5, k + 0.5)
	return (zone.spanY if g < Heightfield.WALKABLE_MIN and zone.has("spanY") else maxf(g, Heightfield.WATER_Y)) + 0.04

func rebuild_grid() -> void:
	for c in grid_root.get_children(): c.queue_free()
	for zone in Data.layout.zones:
		var unlocked: bool = game.zone_unlocked(zone)
		var b := BuildGrid.zone_bounds(zone, state().harmony)
		var lines := SurfaceTool.new(); lines.begin(Mesh.PRIMITIVE_LINES)
		var fill := SurfaceTool.new(); fill.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(int(b.minI), int(b.maxI) + 1):
			for k in range(int(b.minK), int(b.maxK) + 1):
				var y := _cell_y(zone, i, k)
				for seg in [[Vector3(i, y, k), Vector3(i + 1, y, k)], [Vector3(i, y, k), Vector3(i, y, k + 1)], [Vector3(i + 1, y, k), Vector3(i + 1, y, k + 1)], [Vector3(i, y, k + 1), Vector3(i + 1, y, k + 1)]]:
					lines.add_vertex(seg[0]); lines.add_vertex(seg[1])
				var q := [Vector3(i + 0.05, y - 0.01, k + 0.05), Vector3(i + 0.95, y - 0.01, k + 0.05), Vector3(i + 0.95, y - 0.01, k + 0.95), Vector3(i + 0.05, y - 0.01, k + 0.95)]
				for idx in [0, 1, 2, 0, 2, 3]: fill.add_vertex(q[idx])
		var lm := MeshInstance3D.new(); lm.mesh = lines.commit(); lm.material_override = Palette.glow_mat(Color.WHITE if unlocked else Color("9a8f9f"), 0.8 if unlocked else 0.35)
		var fm := MeshInstance3D.new(); fm.mesh = fill.commit()
		var f_mat := Palette.glow_mat(Color("c9a8ff") if unlocked else Color("777777"), 0.25 if unlocked else 0.12)
		f_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.material_override = f_mat
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grid_root.add_child(lm); grid_root.add_child(fm)

func refresh_plan() -> void:
	for c in plan_root.get_children(): c.queue_free()
	for zone in Data.layout.zones:
		if not zone.has("blueprint") or not game.zone_plan_visible(zone): continue
		for e in zone.blueprint:
			var id: String = e[2]; var i := float(e[0]); var k := float(e[1]); var r: int = int(e[3]) if e.size() > 3 else 0
			if state().placements.any(func(p): return p.id == id and p.i == i and p.k == k): continue
			var g := PieceMeshes.ghost(id, "plan")
			var y := BuildGrid.suggest_bottom(id, i, k, r, 0.2 if id == "bridgeDeck" else -5.0, [], zone)
			var fp := BuildGrid.footprint(Data.piece(id), r)
			g.position = Vector3(i + fp.x / 2.0, y + 0.01, k + fp.y / 2.0); g.rotation.y = -r * PI / 2.0
			plan_root.add_child(g)

# ---- Raycast cursor (maths against the heightfield and piece boxes; no physics needed)
func pick(screen: Vector2) -> Dictionary:
	var cam: Camera3D = game.camera
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var best_t := INF
	var hit := {}
	for pl in state().placements:
		if not moving.is_empty() and pl.uid == moving.pl.uid: continue
		var b := BuildGrid.bounds(pl)
		var r := _ray_box(o, d, Vector3(b.minX, b.bottom, b.minZ), Vector3(b.maxX, b.top, b.maxZ))
		if not r.is_empty() and r.t < best_t: best_t = r.t; hit = {"point": o + d * r.t, "normal": r.n, "uid": pl.uid}
	var tt := 0.0
	var prev := 0.0
	while tt < minf(best_t, 220.0):
		var p := o + d * tt
		if p.y < Heightfield.height(p.x, p.z):
			var lo := prev; var hi := tt
			for n in 10:
				var mid := (lo + hi) / 2.0
				var q := o + d * mid
				if q.y < Heightfield.height(q.x, q.z): hi = mid
				else: lo = mid
			if hi < best_t: best_t = hi; hit = {"point": o + d * hi, "normal": Vector3.UP, "uid": -1}
			break
		prev = tt; tt += 0.4
	if hit.is_empty(): return {}
	var point: Vector3 = hit.point
	var hit_y := point.y
	if hit.uid == -1 and point.y < Heightfield.WATER_Y and absf(d.y) > 0.001:
		var t2 := (0.1 - o.y) / d.y
		if t2 > 0: point = o + d * t2
		hit_y = 0.2
	if hit.uid != -1 and hit.normal.y < 0.6: point += hit.normal * 0.35
	return {"point": point, "uid": hit.uid, "hit_y": hit_y}

func _ray_box(o: Vector3, d: Vector3, mn: Vector3, mx: Vector3) -> Dictionary:
	var tmin := -INF; var tmax := INF; var n := Vector3.ZERO
	for a in 3:
		if absf(d[a]) < 1e-9:
			if o[a] < mn[a] or o[a] > mx[a]: return {}
			continue
		var t1 := (mn[a] - o[a]) / d[a]; var t2 := (mx[a] - o[a]) / d[a]
		var sign := -1.0
		if t1 > t2: var tmp := t1; t1 = t2; t2 = tmp; sign = 1.0
		if t1 > tmin: tmin = t1; n = Vector3.ZERO; n[a] = sign
		tmax = minf(tmax, t2)
		if tmin > tmax: return {}
	if tmin < 0: return {}
	return {"t": tmin, "n": n}

func _cell_for(d: Dictionary, r: int, p: Vector3) -> Vector2:
	var fp := BuildGrid.footprint(d, r)
	if half: return Vector2(floor((p.x - fp.x / 2.0 + 0.25) * 2.0) / 2.0, floor((p.z - fp.y / 2.0 + 0.25) * 2.0) / 2.0)
	return Vector2(floor(p.x - fp.x / 2.0 + 0.5), floor(p.z - fp.y / 2.0 + 0.5))

func candidate() -> Dictionary:
	var id: String = moving.pl.id if not moving.is_empty() else item_id
	if id == "" or hover.is_empty(): return {}
	var d := Data.piece(id)
	var r: int = moving.r if not moving.is_empty() else rotation
	if d.get("attach", "") == "wall":
		for q in state().placements:
			if q.uid == hover.uid and Data.piece(q.id).get("edge", false) and Data.piece(q.id).h >= 2:
				return {"id": id, "i": q.i, "k": q.k, "r": int(q.r), "y": q.y + 0.9}
		var c := _cell_for(d, r, hover.point)
		return {"id": id, "i": c.x, "k": c.y, "r": r, "y": hover.point.y, "no_wall": true}
	var cell := _cell_for(d, r, hover.point)
	var zone := BuildGrid.zone_at(Data.layout.zones, cell.x, cell.y, state().harmony)
	var others := _others()
	return {"id": id, "i": cell.x, "k": cell.y, "r": r, "y": BuildGrid.suggest_bottom(id, cell.x, cell.y, r, hover.hit_y, others, zone)}

func _others() -> Array:
	return state().placements.filter(func(p): return moving.is_empty() or p.uid != moving.pl.uid)

func evaluate(c: Dictionary) -> Dictionary:
	var pl := {"uid": moving.pl.uid if not moving.is_empty() else -1, "id": c.id, "i": c.i, "k": c.k, "r": c.r, "y": c.y}
	if not moving.is_empty():
		if moving.pl.has("color"): pl["color"] = moving.pl.color
		if moving.pl.has("state"): pl["state"] = moving.pl.state
	if c.get("no_wall", false): return {"pl": pl, "ok": false, "reason": "Point at a wall to hang this"}
	var v := BuildGrid.validate_placement(pl, game.placement_ctx(_others()))
	if not v.ok: v["pl"] = pl; return v
	var cost: Dictionary = Data.piece(c.id).cost
	if moving.is_empty() and not Inventory.can_afford(state().inventory, cost):
		var parts: Array = []
		for m in Inventory.missing(state().inventory, cost): parts.append("%d more %s %s" % [m.need, Data.resources[m.id].icon, String(Data.resources[m.id].name).to_lower()])
		return {"pl": pl, "ok": false, "reason": "Not enough materials — need " + ", ".join(parts)}
	return {"pl": pl, "ok": true, "zone": v.zone}

func _clear_ghost() -> void:
	if ghost: ghost.queue_free(); ghost = null; ghost_key = ""

func update(dt: float) -> void:
	var mv: Vector2 = game.move_vector()
	var yaw: float = game.cam.move_yaw()
	var fx := -sin(yaw); var fz := -cos(yaw)
	var spd := 9.0 * (2.0 if Input.is_action_pressed("sprint") else 1.0) * dt
	focus.x = clampf(focus.x + (fx * mv.y - fz * mv.x) * spd, -55, 55)
	focus.z = clampf(focus.z + (fz * mv.y + fx * mv.x) * spd, -55, 55)
	game.cam.focus = Vector3(focus.x, maxf(Heightfield.height(focus.x, focus.z), focus.y) + 0.5, focus.z)
	if Input.is_action_just_pressed("pause"):
		if not moving.is_empty(): cancel_move()
		elif item_id != "" or selected != -1: item_id = ""; selected = -1; _build_ui()
		else: close(); return
	if Input.is_action_just_pressed("build"): close(); return
	if Input.is_action_just_pressed("rotate"): rotate_piece()
	if Input.is_action_just_pressed("half_grid"): half = not half; game.toast("Half-grid snapping on" if half else "Half-grid snapping off"); _build_ui()
	if Input.is_action_just_pressed("recolor"): cycle_color()
	if Input.is_action_just_pressed("remove"): remove_target()
	if Input.is_action_just_pressed("move_piece") and selected != -1 and moving.is_empty(): start_move(selected)
	_gamepad_cursor(dt)
	var over_ui := _over_ui(mouse)
	hover = {} if over_ui else pick(mouse)
	var c := candidate()
	if not c.is_empty():
		var key := "%s|%s|%s|%d|%.2f|%d|%s" % [c.id, c.i, c.k, c.r, c.y, state().placements.size(), str(state().inventory)]
		if key != ghost_key or ghost == null or ghost.get_meta("id") != c.id:
			check = evaluate(c)
			if ghost == null or ghost.get_meta("id") != c.id:
				_clear_ghost(); ghost = PieceMeshes.ghost(c.id, "ok"); game.add_child(ghost)
			var fp := BuildGrid.footprint(Data.piece(c.id), c.r)
			ghost.position = Vector3(c.i + fp.x / 2.0, c.y + 0.005, c.k + fp.y / 2.0)
			ghost.rotation.y = -c.r * PI / 2.0
			PieceMeshes.set_ghost(ghost, "ok" if check.ok else "bad")
			ghost_key = key
			_render_status()
		ghost.visible = true
	else:
		if ghost: ghost.visible = false
		if not check.is_empty(): check = {}; _render_status()
	var sm: Node3D = game.piece_nodes.get(selected)
	sel_box.visible = sm != null and moving.is_empty()
	if sm:
		var pl := _find(selected)
		if not pl.is_empty():
			var b := BuildGrid.bounds(pl)
			sel_box.position = Vector3((b.minX + b.maxX) / 2.0, (b.bottom + b.top) / 2.0, (b.minZ + b.maxZ) / 2.0)
			sel_box.scale = Vector3(b.maxX - b.minX + 0.1, b.top - b.bottom + 0.1, b.maxZ - b.minZ + 0.1)

## Gamepad: right stick moves a build cursor, A places / selects, B cancels (left stick still pans the view).
func _gamepad_cursor(dt: float) -> void:
	if Input.get_connected_joypads().is_empty(): return
	var st := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if st.length() > 0.2:
		var vs: Vector2 = game.get_viewport().get_visible_rect().size
		mouse = (mouse + st * 650.0 * dt).clamp(Vector2.ZERO, vs)
		if pad_cursor == null:
			pad_cursor = UiTheme.label("✛", 34, UiTheme.PINK_DARK); pad_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE; game.ui_root.add_child(pad_cursor)
	if pad_cursor:
		pad_cursor.visible = active
		pad_cursor.position = mouse - Vector2(12, 22)
	for pair in [[JOY_BUTTON_DPAD_LEFT, -1], [JOY_BUTTON_DPAD_RIGHT, 1]]:
		var key := "pad_%d" % pair[0]
		if Input.is_joy_button_pressed(0, pair[0]) and not get_meta(key, false):
			set_meta(key, true)
			var list: Array = Data.pieces.filter(func(p): return p.cat == category and state().blueprints.has(p.id)).map(func(p): return p.id)
			if not list.is_empty(): select_item(list[(list.find(item_id) + pair[1] + list.size()) % list.size()] if item_id != "" else list[0])
		elif not Input.is_joy_button_pressed(0, pair[0]): set_meta(key, false)
	for pair in [[JOY_BUTTON_DPAD_UP, -1], [JOY_BUTTON_DPAD_DOWN, 1]]:
		var key := "pad_%d" % pair[0]
		if Input.is_joy_button_pressed(0, pair[0]) and not get_meta(key, false):
			set_meta(key, true)
			var cats: Array = Data.categories.map(func(c): return c.id)
			category = cats[(cats.find(category) + pair[1] + cats.size()) % cats.size()]; item_id = ""; _build_ui()
		elif not Input.is_joy_button_pressed(0, pair[0]): set_meta(key, false)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A) and not get_meta("pad_a", false): set_meta("pad_a", true); click()
	elif not Input.is_joy_button_pressed(0, JOY_BUTTON_A): set_meta("pad_a", false)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_B) and not get_meta("pad_b", false):
		set_meta("pad_b", true)
		if not moving.is_empty(): cancel_move()
		elif item_id != "" or selected != -1: item_id = ""; selected = -1; _build_ui()
		else: close()
	elif not Input.is_joy_button_pressed(0, JOY_BUTTON_B): set_meta("pad_b", false)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouse: mouse = event.position
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed or Input.is_key_pressed(KEY_CTRL)):
		if event.physical_keycode == KEY_Z: undo()
		if event.physical_keycode == KEY_Y: redo()
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not game.drag_moved: click()
		if event.button_index == MOUSE_BUTTON_RIGHT and not game.drag_moved:
			if not moving.is_empty(): cancel_move()
			elif item_id != "" or selected != -1: item_id = ""; selected = -1; _build_ui()

func click() -> void:
	if not moving.is_empty(): drop_move(); return
	if item_id != "": place(); return
	if not hover.is_empty() and hover.uid != -1: selected = hover.uid; game.sfx("select"); _build_ui()
	elif selected != -1: selected = -1; _build_ui()

func _find(uid: int) -> Dictionary:
	for p in state().placements:
		if p.uid == uid: return p
	return {}

# ---- Commands
func place() -> void:
	if check.is_empty(): return
	if not check.ok: game.toast(check.reason, "warn"); game.sfx("error"); return
	var pl: Dictionary = check.pl.duplicate(true)
	pl.uid = int(state().next_uid); state().next_uid = pl.uid + 1
	var d := Data.piece(pl.id)
	if color != "" and d.get("colorable", false): pl["color"] = color
	if d.get("mech", {}).get("switch", false): pl["state"] = {"on": true}
	if d.get("door", false): pl["state"] = {"open": false}
	var r: Dictionary = game.commit_place(pl, true)
	if r.ok: history.push({"type": "place", "pl": pl.duplicate(true)}); ghost_key = ""; _build_ui()

func remove_target() -> void:
	var uid: int = selected if selected != -1 else (hover.get("uid", -1) if not hover.is_empty() else -1)
	if uid == -1: game.toast("Point at a piece to remove it"); return
	var pl := _find(uid).duplicate(true)
	var r: Dictionary = game.commit_remove(uid)
	if r.ok: history.push({"type": "remove", "pl": pl}); selected = -1; _build_ui()
	else: game.toast(r.reason, "warn")

func rotate_piece() -> void:
	if not moving.is_empty(): moving.r = (moving.r + 1) % 4; ghost_key = ""; return
	if item_id != "": rotation = (rotation + 1) % 4; ghost_key = ""; game.sfx("tick"); return
	if selected != -1:
		var pl := _find(selected)
		var from := {"i": pl.i, "k": pl.k, "r": int(pl.r), "y": pl.y}
		var to := from.duplicate(); to.r = (from.r + 1) % 4
		var r: Dictionary = game.commit_move(pl.uid, to)
		if r.ok: history.push({"type": "move", "uid": pl.uid, "from": from, "to": to})
		else: game.toast(r.reason, "warn")

func start_move(uid: int) -> void:
	var pl := _find(uid)
	if pl.is_empty(): return
	var rm := BuildGrid.validate_removal(uid, game.placement_ctx())
	if not rm.ok: game.toast(rm.reason, "warn"); return
	moving = {"pl": pl, "from": {"i": pl.i, "k": pl.k, "r": int(pl.r), "y": pl.y}, "r": int(pl.r)}
	item_id = ""
	game.piece_nodes[uid].visible = false
	_build_ui()

func drop_move() -> void:
	if check.is_empty() or not check.ok: game.toast(check.get("reason", "Point somewhere to put it down"), "warn"); game.sfx("error"); return
	var pl: Dictionary = moving.pl
	var from: Dictionary = moving.from
	var to := {"i": check.pl.i, "k": check.pl.k, "r": int(check.pl.r), "y": check.pl.y}
	game.piece_nodes[pl.uid].visible = true
	moving = {}
	var r: Dictionary = game.commit_move(pl.uid, to)
	if r.ok: history.push({"type": "move", "uid": pl.uid, "from": from, "to": to}); selected = pl.uid
	else: game.toast(r.reason, "warn")
	_clear_ghost(); _build_ui()

func cancel_move() -> void:
	if moving.is_empty(): return
	game.piece_nodes[moving.pl.uid].visible = true
	moving = {}; _clear_ghost(); _build_ui()

func cycle_color() -> void:
	var cur = color
	if selected != -1: cur = _find(selected).get("color", "")
	var n := (Data.palette.find(cur) + 1) % Data.palette.size()
	set_color(Data.palette[n])

func set_color(c: String) -> void:
	if selected != -1:
		var pl := _find(selected)
		if not Data.piece(pl.id).get("colorable", false): game.toast("This piece can't be recoloured"); return
		var from: String = pl.get("color", "")
		game.commit_recolor(pl.uid, c)
		history.push({"type": "recolor", "uid": pl.uid, "from": from, "to": c})
		_build_ui()
	else:
		color = c; _build_ui()

func undo() -> void:
	var r := history.undo(apply_cmd)
	game.toast("Undone" if r.ok else r.reason, "" if r.ok else "warn"); game.sfx("undo"); _build_ui()
func redo() -> void:
	var r := history.redo(apply_cmd)
	game.toast("Redone" if r.ok else r.reason, "" if r.ok else "warn"); game.sfx("undo"); _build_ui()

func apply_cmd(cmd: Dictionary, dir: String) -> Dictionary:
	match cmd.type:
		"place": return game.commit_remove(cmd.pl.uid) if dir == "undo" else game.commit_place(cmd.pl.duplicate(true), true)
		"remove": return game.commit_place(cmd.pl.duplicate(true), true) if dir == "undo" else game.commit_remove(cmd.pl.uid)
		"move": return game.commit_move(cmd.uid, cmd.from if dir == "undo" else cmd.to)
		"recolor": return game.commit_recolor(cmd.uid, cmd.from if dir == "undo" else cmd.to)
	return {"ok": false, "reason": "Unknown action"}

func select_item(id: String) -> void:
	if not state().blueprints.has(id): game.toast("Locked — " + game.blueprint_hint(id), "warn"); return
	if not moving.is_empty(): cancel_move()
	item_id = "" if item_id == id else id
	selected = -1; ghost_key = ""
	state().new_blueprints.erase(id)
	game.sfx("select")
	_build_ui()

# ---- UI
func _status_text() -> String:
	if not moving.is_empty():
		return ("Click to put it here" if check.ok else check.reason) if not check.is_empty() else "Carrying a piece — point where it should go"
	if item_id == "": return "Piece selected" if selected != -1 else "Pick a piece from the catalog, or click a placed piece to edit it"
	var d := Data.piece(item_id)
	if check.is_empty(): return "%s — point at the glowing grid" % d.name
	return ("Click to place %s (%s)" % [d.name, _cost_text(d.cost)]) if check.ok else check.reason

func _render_status() -> void:
	if status_label == null: return
	status_label.text = _status_text()
	var bad: bool = not check.is_empty() and not check.ok
	var sp: PanelContainer = status_label.get_parent()
	sp.add_theme_stylebox_override("panel", UiTheme.box(Color("fff3f3") if bad else Color.WHITE, Color("ffb3b3") if bad else Color("cfe8d4"), 999, 3, 6, false))
	status_label.add_theme_color_override("font_color", Color("b34a4a") if bad else Color("2f8a52"))

static func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost: parts.append("%s%d" % [Data.resources[k].icon, int(cost[k])])
	return " ".join(parts)

func _build_ui() -> void:
	if ui: ui.queue_free()
	if not active: return
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(ui)
	# Top bar
	var top := UiTheme.panel(Color(UiTheme.CREAM, 0.96), UiTheme.LILAC, 999)
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 10); top.add_child(tb)
	tb.add_child(UiTheme.label("✨ Starforge Build Mode", 16))
	tb.add_child(UiTheme.button("◀", func(): cycle_zone(-1)))
	tb.add_child(UiTheme.label(current_zone.get("name", "No area"), 16, Color("7a5cc9")))
	tb.add_child(UiTheme.button("▶", func(): cycle_zone(1)))
	var ub := UiTheme.button("↶ Undo", undo); ub.disabled = not history.can_undo(); tb.add_child(ub)
	var rb := UiTheme.button("↷ Redo", redo); rb.disabled = not history.can_redo(); tb.add_child(rb)
	tb.add_child(UiTheme.button("½ grid: %s" % ("on" if half else "off"), func(): half = not half; _build_ui()))
	tb.add_child(UiTheme.button("Done", close, true))
	var top_c := CenterContainer.new(); top_c.anchor_right = 1; top_c.offset_top = 64; top_c.offset_bottom = 110; top_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_c.add_child(top); ui.add_child(top_c)
	var sp := UiTheme.panel(Color.WHITE, Color("cfe8d4"), 999)
	status_label = UiTheme.label("", 15, Color("2f8a52")); sp.add_child(status_label)
	var st_c := CenterContainer.new(); st_c.anchor_right = 1; st_c.offset_top = 118; st_c.offset_bottom = 150; st_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_c.add_child(sp); ui.add_child(st_c)
	_render_status()
	# Help
	var help := UiTheme.panel()
	var hl := UiTheme.label("Left click — place / select\nRight click — cancel · right-drag — turn view\n%s rotate · %s colour · %s move\n%s remove · Ctrl+Z undo · Ctrl+Y redo\nWASD pan · wheel zoom · %s half-grid\n%s / %s leave build mode" % [Controls.key_label("rotate"), Controls.key_label("recolor"), Controls.key_label("move_piece"), Controls.key_label("remove"), Controls.key_label("half_grid"), Controls.key_label("pause"), Controls.key_label("build")], 12, UiTheme.INK2)
	help.add_child(hl); help.position = Vector2(14, 170); help.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(help)
	# Goals or selection
	var right := VBoxContainer.new(); right.anchor_left = 1; right.anchor_right = 1; right.offset_left = -290; right.offset_right = -14; right.offset_top = 170; ui.add_child(right)
	var goals: Dictionary = game.build_goals(current_zone)
	if not goals.is_empty() and selected == -1 and moving.is_empty():
		var gp := UiTheme.panel(Color("fffce6"), UiTheme.GOLD)
		var gv := VBoxContainer.new(); gp.add_child(gv)
		gv.add_child(UiTheme.label("📜 " + goals.title, 14))
		if goals.has("hint"): var hh := UiTheme.label(goals.hint, 12, UiTheme.INK2); hh.autowrap_mode = TextServer.AUTOWRAP_WORD; gv.add_child(hh)
		for it in goals.items: gv.add_child(UiTheme.label(("✔ " if it.ok else "○ ") + it.label, 13, Color("2f8a52") if it.ok else UiTheme.INK))
		right.add_child(gp)
	if selected != -1 or not moving.is_empty():
		var pl: Dictionary = moving.pl if not moving.is_empty() else _find(selected)
		if not pl.is_empty():
			var d := Data.piece(pl.id)
			var p := UiTheme.panel(Color(UiTheme.CREAM, 0.97), UiTheme.LILAC)
			var v := VBoxContainer.new(); p.add_child(v)
			v.add_child(UiTheme.label("%s %s" % [d.icon, d.name], 16))
			var desc := UiTheme.label(d.desc, 12, UiTheme.INK2); desc.autowrap_mode = TextServer.AUTOWRAP_WORD; desc.custom_minimum_size.x = 240; v.add_child(desc)
			if moving.is_empty():
				var row := HBoxContainer.new(); v.add_child(row)
				row.add_child(UiTheme.button("✋ Move", func(): start_move(pl.uid)))
				row.add_child(UiTheme.button("⟳", rotate_piece))
				row.add_child(UiTheme.button("🗑", remove_target))
				if d.get("colorable", false): v.add_child(_swatches(pl.get("color", d.color), set_color))
				if d.get("mech", {}).get("switch", false): v.add_child(UiTheme.button("Switch off" if pl.get("state", {}).get("on", false) else "Switch on", func(): game.toggle_lever(pl.uid); _build_ui()))
				v.add_child(UiTheme.label("Removing refunds " + _cost_text(d.cost), 12, UiTheme.INK2))
			else: v.add_child(UiTheme.label("Click to put it down · R rotate · right click to cancel", 12, UiTheme.INK2))
			right.add_child(p)
	# Catalog
	var cat := UiTheme.panel(Color(UiTheme.CREAM, 0.97), UiTheme.LILAC, 24)
	cat.anchor_top = 1; cat.anchor_bottom = 1; cat.anchor_left = 0.5; cat.anchor_right = 0.5
	cat.offset_left = -600; cat.offset_right = 600; cat.offset_top = -12; cat.offset_bottom = -12; cat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var cv := VBoxContainer.new(); cat.add_child(cv)
	var tabs := HBoxContainer.new(); cv.add_child(tabs)
	for c in Data.categories:
		var cid: String = c.id
		var b := UiTheme.button("%s %s" % [c.icon, c.name], func(): category = cid; _build_ui(), category == cid)
		b.name = "tab_" + cid
		tabs.add_child(b)
	if item_id != "" and Data.piece(item_id).get("colorable", false):
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(spacer)
		tabs.add_child(_swatches(color if color != "" else Data.piece(item_id).color, set_color))
	# Every piece stays visible: the catalog wraps onto a second row instead of scrolling sideways.
	var items := HFlowContainer.new(); items.add_theme_constant_override("h_separation", 6); items.add_theme_constant_override("v_separation", 6); cv.add_child(items)
	for p in Data.pieces:
		if p.cat != category: continue
		var unlocked: bool = state().blueprints.has(p.id)
		var poor := unlocked and not Inventory.can_afford(state().inventory, p.cost)
		var pid: String = p.id
		var btn := Button.new(); btn.name = "piece_" + pid
		btn.custom_minimum_size = Vector2(80, 80)
		btn.tooltip_text = ("%s: %s" % [p.name, p.desc]) if unlocked else "Locked: " + game.blueprint_hint(pid)
		var on := item_id == pid
		var sb := UiTheme.box(Color("f6f0ff") if on else Color.WHITE, Color("a07cff") if on else Color("eadcff"), 16, 3, 4, false)
		btn.add_theme_stylebox_override("normal", sb); btn.add_theme_stylebox_override("hover", UiTheme.box(Color("fbf8ff"), Color("c9a8ff"), 16, 3, 4, false))
		var vb := VBoxContainer.new(); vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); vb.alignment = BoxContainer.ALIGNMENT_CENTER; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		var icon := UiTheme.label(p.icon if unlocked else "🔒", 24); icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UiTheme.label(p.name, 11); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nm.autowrap_mode = TextServer.AUTOWRAP_WORD; nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ct := UiTheme.label(_cost_text(p.cost) if unlocked else "locked", 10, Color("d55555") if poor else UiTheme.INK2); ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state().new_blueprints.has(pid): var nw := UiTheme.label("✦ new", 10, UiTheme.PINK_DARK); nw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nw.mouse_filter = Control.MOUSE_FILTER_IGNORE; vb.add_child(nw)
		vb.add_child(icon); vb.add_child(nm); vb.add_child(ct)
		btn.add_child(vb)
		if not unlocked: btn.modulate = Color(1, 1, 1, 0.55)
		btn.pressed.connect(func(): select_item(pid))
		items.add_child(btn)
	ui.add_child(cat)

func _swatches(current: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 4)
	for c in Data.palette:
		var col: String = c
		var b := Button.new(); b.custom_minimum_size = Vector2(22, 22); b.name = "sw_" + col.substr(1)
		var sb := UiTheme.box(Color(col), Color("ff8fab") if current == col else Color.WHITE, 999, 3 if current == col else 2, 0, false)
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb); b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(func(): cb.call(col))
		row.add_child(b)
	return row
