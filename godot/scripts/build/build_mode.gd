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
var selected := -1
var selected_draft := -1
var draft_only := false
var version := 0
var draft_root := Node3D.new()
var draft_nodes := {}
var spots_root := Node3D.new()
var spot_mesh := MeshInstance3D.new()
var spot_key := ""
var spot_ctx := {}
var spot_results := {}
var spot_queue: Array = []
var spot_center := Vector2i(1 << 20, 1 << 20)
var spot_dirty := false
var grid_fills: Array = []
var hangout_root := Node3D.new()
var hangout_labels: Array = []
var show_keys := false
const SPOT_RADIUS := 6
const SPOT_BUDGET_USEC := 4000
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
	draft_root.name = "Drafts"; game.add_child(draft_root)
	spots_root.name = "BuildSpots"; game.add_child(spots_root)
	var spot_mat := Palette.glow_mat(Color("5dff9a"), 0.34)
	spot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	spot_mesh.material_override = spot_mat; spot_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spots_root.add_child(spot_mesh); spots_root.visible = false
	hangout_root.name = "Hangouts"; hangout_root.visible = false; game.add_child(hangout_root)
	sel_box = MeshInstance3D.new(); sel_box.visible = false
	var bm := BoxMesh.new(); sel_box.mesh = bm
	var sm := Palette.glow_mat(Color("a07cff"), 0.25); sel_box.material_override = sm
	game.add_child(sel_box)

func state() -> Dictionary: return game.state
func unlocked_zones() -> Array: return Data.layout.zones.filter(func(z): return game.zone_unlocked(z))

var opened_at := Vector3.INF   # where the player stood when build mode opened
var plan_now: Array = []        # the ghost plans of the steps you're on here (Plans.current)
var plan_marker: Node3D         # a bobbing arrow over the plan's next piece

func open(zone_id: String = "") -> bool:
	if not state().flags.get("hasTool", false):
		game.toast("You need your Geometra's kit first. The Sindaco is holding it for you.", "warn"); return false
	active = true
	opened_at = game.player.pos
	var zones := unlocked_zones()
	var p: Vector3 = game.player.pos
	var zone := {}
	for z in zones:
		if z.id == zone_id: zone = z
	if zone.is_empty(): zone = BuildGrid.zone_at(zones, floor(p.x), floor(p.z), LocationMeter.progress(state(), Data.island))
	if zone.get("open", false):   # in the village streets but right by a site (the washout): that site
		for z in zones:
			if not z.get("open", false) and not z.get("interior", false) and _near_zone(z, p, 3.0): zone = z; break
	if zone.is_empty() and not zones.is_empty():   # the nearest site, but not someone's room when you're outdoors
		var outdoor := zones.filter(func(z): return not z.get("interior", false))
		var pool: Array = outdoor if not outdoor.is_empty() else zones
		pool.sort_custom(func(a, b): return _zdist(a, p) < _zdist(b, p))
		zone = pool[0]
	zone_index = maxi(0, unlocked_zones().find(zone))
	jump_to(zone)
	if zone.get("open", false) and BuildGrid.zone_contains(zone, floor(p.x), floor(p.z), LocationMeter.progress(state(), Data.island)):
		focus = p   # an open area (the village streets): build right where you are
	rebuild_grid(); refresh_plan(); refresh_hangouts()
	grid_root.visible = true
	hangout_root.visible = true
	game.cam.set_mode("build")
	game.player_char.play("build", true); game.player_char.show_staff(true)
	# with a plan to follow here, its next piece is already in your hand, turned the way its outline is
	var nx := next_plan_piece()
	if item_id == "" and selected == -1 and not nx.is_empty() and state().blueprints.has(nx.id):
		item_id = nx.id; rotation = int(nx.r); category = String(Data.piece(nx.id).cat)
	_build_ui()
	_first_time_here()
	game.emit_event("buildmode", {"open": true})
	return true

func close() -> void:
	if not moving.is_empty(): cancel_move()
	var zone_was: Dictionary = current_zone
	active = false; item_id = ""; selected = -1; selected_draft = -1
	_clear_ghost(); sel_box.visible = false; grid_root.visible = false
	spots_root.visible = false; spot_key = ""; _show_fills(true)
	hangout_root.visible = false
	game.cam.set_mode("explore")
	game.player_char.stop_hold()
	if ui: ui.queue_free(); ui = null
	if pad_cursor: pad_cursor.visible = false
	game.emit_event("buildmode", {"open": false})
	step_out_of(zone_was)

## Leaving build mode while standing on the site (or boxed in by what you built): step to the nearest free spot
## outside the highlighted zone, preferring where you stood when you started building.
func step_out_of(zone: Dictionary) -> void:
	if zone.is_empty() or zone.get("interior", false): return
	var b := BuildGrid.zone_bounds(zone, LocationMeter.progress(game.state, Data.island))
	var rect := Rect2(b.minI, b.minK, b.maxI - b.minI + 1, b.maxK - b.minK + 1)
	var p: Vector3 = game.player.pos
	var w: WalkWorld = game.walk
	var inside: bool = rect.grow(0.2).has_point(Vector2(p.x, p.z)) and not zone.get("open", false)   # (an open area is somewhere you walk anyway)
	if not inside and not w.stuck(p, WalkWorld.PLAYER_RADIUS, game.player.body): return
	var from: Vector3 = opened_at if opened_at != Vector3.INF else p
	var spot := w.free_spot(from.x, from.z, rect, 14.0, WalkWorld.PLAYER_RADIUS, game.player.body)
	if spot.is_empty(): spot = w.free_spot(p.x, p.z, rect, 30.0, WalkWorld.PLAYER_RADIUS, game.player.body)
	if spot.is_empty(): return
	game.player.teleport(spot.x, spot.z)
	game.effects.sparkle(game.player.pos + Vector3(0, 1, 0), 12)
	game.toast("You step off the build site.")

func _over_ui(p: Vector2) -> bool:
	if ui == null: return false
	for c in ui.find_children("*", "Control", true, false):
		if c is PanelContainer and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p): return true
	return false

## Is `p` within `m` metres of the zone's cells?
func _near_zone(z: Dictionary, p: Vector3, m: float) -> bool:
	var b := BuildGrid.zone_bounds(z, LocationMeter.progress(state(), Data.island))
	return p.x > b.minI - m and p.x < b.maxI + 1 + m and p.z > b.minK - m and p.z < b.maxK + 1 + m

func _zdist(z: Dictionary, p: Vector3) -> float: return Vector2((z.minI + z.maxI) / 2.0 - p.x, (z.minK + z.maxK) / 2.0 - p.z).length()

func jump_to(zone: Dictionary) -> void:
	current_zone = zone
	if zone.is_empty(): focus = game.player.pos; return
	var b := BuildGrid.zone_bounds(zone, LocationMeter.progress(state(), Data.island))
	focus = Vector3((b.minI + b.maxI + 1) / 2.0, maxf(0.0, zone.get("floorY", zone.get("spanY", 0.0))), (b.minK + b.maxK + 1) / 2.0)

func cycle_zone(dir: int) -> void:
	var zones := unlocked_zones()
	if zones.is_empty(): return
	zone_index = (zone_index + dir + zones.size()) % zones.size()
	jump_to(zones[zone_index]); _build_ui()

# ---- Grid and plan visuals
func _cell_y(zone: Dictionary, i: int, k: int) -> float:
	var g := BuildGrid.ground_at(i, k)   # the ground, or a raised floor over it (a flat upstairs)
	return (zone.spanY if g < Heightfield.WALKABLE_MIN and zone.has("spanY") else maxf(g, Heightfield.WATER_Y)) + 0.04

func rebuild_grid() -> void:
	for c in grid_root.get_children(): c.queue_free()
	grid_fills.clear()
	for zone in Data.layout.zones:
		var unlocked: bool = game.zone_unlocked(zone)
		var b := BuildGrid.zone_bounds(zone, LocationMeter.progress(state(), Data.island))
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
		grid_fills.append(fm)

## The ghost plans of the steps you're on (Plans), and any older zone blueprint whose request is active: see-through
## pieces on the site, gone as you build each one. A piece a plan uses that you haven't unlocked is unlocked.
func refresh_plan() -> void:
	for c in plan_root.get_children(): c.queue_free()
	var shown: Array = []
	for p in Plans.current(game.story.engine): shown.append_array(p.pieces)
	for zone in Data.layout.zones:
		if zone.has("blueprint") and game.zone_plan_visible(zone): shown.append_array(Plans.lay_out(zone.blueprint, zone, state().placements))
	plan_now = Plans.current(game.story.engine)
	var missing: Array = []
	for pl in shown:
		if not state().blueprints.has(pl.id) and not missing.has(pl.id): missing.append(pl.id)
		if Plans.built(pl, state().placements): continue
		var g := PieceMeshes.ghost(pl.id, "plan")
		var fp := BuildGrid.footprint(Data.piece(pl.id), int(pl.r))
		g.position = Vector3(pl.i + fp.x / 2.0, float(pl.y) + 0.01, pl.k + fp.y / 2.0); g.rotation.y = -int(pl.r) * PI / 2.0
		plan_root.add_child(g)
	if not missing.is_empty(): game.story.unlock_blueprints(missing)
	# an arrow over the next piece to build, bobbing, so you know where to start (and where you've got to)
	plan_marker = null
	var nx := next_plan_piece()
	if not nx.is_empty():
		var fp := BuildGrid.footprint(Data.piece(nx.id), int(nx.r))
		plan_marker = Node3D.new(); plan_marker.name = "plan_next"
		var arrow_mat := Palette.glow_mat(Color("8a5cff"), 0.9)
		var tip := Palette.mi(Palette.cone(0.22, 0.4, 14), arrow_mat, Vector3(0, 0.2, 0), false); tip.rotation.x = PI; plan_marker.add_child(tip)   # pointing down
		var stem := Palette.mi(Palette.cyl(0.08, 0.08, 0.35, 10), arrow_mat, Vector3(0, 0.55, 0), false); plan_marker.add_child(stem)
		plan_marker.position = Vector3(nx.i + fp.x / 2.0, float(nx.y) + float(Data.piece(nx.id).h) + 0.35, nx.k + fp.y / 2.0)
		plan_marker.set_meta("y0", plan_marker.position.y)
		plan_root.add_child(plan_marker)

## The plan for the site you're building on (the current zone's, else the first current one), or {}.
func site_plan() -> Dictionary:
	for p in plan_now:
		if String(p.zone.get("id", "")) == String(current_zone.get("id", "")): return p
	return plan_now[0] if not plan_now.is_empty() else {}

## The next piece of that plan to build, laid out where it goes ({id, i, k, r, y}), or {}.
func next_plan_piece() -> Dictionary:
	var p := site_plan()
	return {} if p.is_empty() else Plans.next_piece(p.pieces, state().placements)

## Puts the plan's next piece in your hand, turned the way its outline is, and (move_view) brings it into view.
func follow_plan(move_view: bool = true) -> void:
	var nx := next_plan_piece()
	if nx.is_empty():
		game.toast("No plan to follow here. Build it your own way: the list on the right says what it needs." if site_plan().is_empty() else "Everything in the plan is built.")
		return
	if not moving.is_empty(): cancel_move()
	category = String(Data.piece(nx.id).cat)
	item_id = String(nx.id); rotation = int(nx.r); selected = -1; ghost_key = ""
	state().new_blueprints.erase(item_id)
	game.sfx("select")
	if move_view: focus = Vector3(float(nx.i) + 0.5, focus.y, float(nx.k) + 0.5)
	_build_ui()

## The first time you build in a place, the "how building works" card (the shared tip card) comes up, even if you
## saw it somewhere else; it's always there again under ❓ How to build.
func _first_time_here() -> void:
	var seen: Array = state().get("build_help", [])
	if seen.has(Data.island): return
	seen.append(Data.island); state()["build_help"] = seen
	if "build" in state().get("tutorial", {}).get("seen", []): game.hud.clear_tips(); game.hud.show_tip(Data.tutorial.tips.build)   # (otherwise the guide shows it now: Guide.tip)

func show_help() -> void:
	show_keys = not show_keys
	game.hud.clear_tips()
	if show_keys: game.hud.show_tip(Data.tutorial.tips.build)
	_build_ui()

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
	for dr in Drafts.of(state()):
		var b := BuildGrid.bounds(dr)
		var r := _ray_box(o, d, Vector3(b.minX, b.bottom, b.minZ), Vector3(b.maxX, b.top, b.maxZ))
		if not r.is_empty() and r.t < best_t: best_t = r.t; hit = {"point": o + d * r.t, "normal": r.n, "uid": int(dr.uid), "draft": true}
	for s in WorldStatics.floors():   # raised floors you can build on (a flat upstairs, a roof terrace): their tops
		if not s.walkable or s.has("ramp"): continue
		var r := _ray_box(o, d, Vector3(s.minX, s.bottom, s.minZ), Vector3(s.maxX, s.top, s.maxZ))
		if not r.is_empty() and r.t < best_t and r.n.y > 0.5: best_t = r.t; hit = {"point": o + d * r.t, "normal": r.n, "uid": -2}
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
	return {"point": point, "uid": hit.uid, "hit_y": hit_y, "draft": hit.get("draft", false)}

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
	if moving.is_empty() and hover.get("draft", false):
		var under := Drafts.find(Drafts.of(state()), int(hover.uid))
		if not under.is_empty() and String(under.id) == id: return {"id": id, "i": float(under.i), "k": float(under.k), "r": int(under.r), "y": float(under.y)}
	var cell := _cell_for(d, r, hover.point)
	if d.get("edge", false):
		r = BuildGrid.edge_rotation(d, cell.x, cell.y, hover.point, r)
		cell = _cell_for(d, r, hover.point)
	var zone := BuildGrid.zone_at(Data.layout.zones, cell.x, cell.y, LocationMeter.progress(state(), Data.island))
	var below := Drafts.design(state().placements, Drafts.of(state()), _moving_uid())
	return {"id": id, "i": cell.x, "k": cell.y, "r": r, "y": BuildGrid.suggest_bottom(id, cell.x, cell.y, r, hover.hit_y, below, zone)}

func _others() -> Array:
	return state().placements.filter(func(p): return moving.is_empty() or p.uid != moving.pl.uid)

func _moving_uid() -> int: return int(moving.pl.uid) if not moving.is_empty() else -1

func _design_ctx(skip_uid: int) -> Dictionary:
	var ctx: Dictionary = game.placement_ctx(Drafts.design(state().placements, Drafts.of(state()), skip_uid))
	ctx["bodies"] = []
	return ctx

func _draft_reason(real_reason: String) -> String:
	return real_reason.to_lower() if real_reason.contains("standing there") else "it rests on drafted pieces"

func evaluate(c: Dictionary) -> Dictionary:
	var pl := {"uid": _moving_uid(), "id": c.id, "i": c.i, "k": c.k, "r": c.r, "y": c.y}
	if not moving.is_empty():
		if moving.pl.has("color"): pl["color"] = moving.pl.color
		if moving.pl.has("state"): pl["state"] = moving.pl.state
	if c.get("no_wall", false): return {"pl": pl, "ok": false, "kind": "bad", "reason": "Point at a wall to hang this"}
	var same: Dictionary = {} if not moving.is_empty() else Drafts.find_same(Drafts.of(state()), pl)
	var design := BuildGrid.validate_placement(pl, _design_ctx(int(same.uid) if not same.is_empty() else _moving_uid()))
	if not design.ok: design["pl"] = pl; design["kind"] = "bad"; return design
	var real := BuildGrid.validate_placement(pl, game.placement_ctx(_others()))
	if not moving.is_empty():
		real["pl"] = pl; real["kind"] = "move" if real.ok else "bad"
		return real
	var short := Inventory.missing(state().inventory, Data.piece(c.id).cost)
	var why := ""
	if draft_only: why = "draft only is on"
	elif not real.ok: why = _draft_reason(String(real.reason))
	elif not short.is_empty(): why = "you need %s more" % Drafts.items_text(short)
	if why == "": return {"pl": pl, "ok": true, "kind": "build_draft" if not same.is_empty() else "build", "zone": real.zone, "draft_uid": int(same.get("uid", -1))}
	if not same.is_empty(): return {"pl": pl, "ok": false, "kind": "drafted", "reason": "Already in your draft: %s" % why}
	return {"pl": pl, "ok": true, "kind": "draft", "why": why, "zone": design.zone}

func _clear_ghost() -> void:
	if ghost: ghost.queue_free(); ghost = null; ghost_key = ""

## How far the build view can move from the middle of the map, each way: over the whole map, 55 m in a village.
static func view_limit() -> float: return Data.map_size() / 2.0 - 7.0

func update(dt: float) -> void:
	var mv: Vector2 = game.move_vector()
	var yaw: float = game.cam.move_yaw()
	var fx := -sin(yaw); var fz := -cos(yaw)
	var spd := 9.0 * (2.0 if Input.is_action_pressed("sprint") else 1.0) * dt
	var lim := view_limit()
	focus.x = clampf(focus.x + (fx * mv.y - fz * mv.x) * spd, -lim, lim)
	focus.z = clampf(focus.z + (fz * mv.y + fx * mv.x) * spd, -lim, lim)
	game.cam.focus = Vector3(focus.x, maxf(Heightfield.height(focus.x, focus.z), focus.y) + 0.5, focus.z)
	if Input.is_action_just_pressed("pause"):
		if not moving.is_empty(): cancel_move()
		elif item_id != "" or selected != -1 or selected_draft != -1: _let_go()
		else: close(); return
	if Input.is_action_just_pressed("build"): close(); return
	if Input.is_action_just_pressed("rotate"): rotate_piece()
	if Input.is_action_just_pressed("draft_only"): toggle_draft_only()
	if Input.is_action_just_pressed("recolor"): cycle_color()
	if Input.is_action_just_pressed("remove"): remove_target()
	if Input.is_action_just_pressed("move_piece") and selected != -1 and moving.is_empty(): start_move(selected)
	if Input.is_action_just_pressed("plan_next"): follow_plan(true)
	if is_instance_valid(plan_marker): plan_marker.position.y = float(plan_marker.get_meta("y0")) + 0.12 * sin(game.time * 4.0)
	_gamepad_cursor(dt)
	var over_ui := _over_ui(mouse)
	hover = {} if over_ui else pick(mouse)
	var c := candidate()
	if not c.is_empty():
		var key := "%s|%s|%s|%d|%.2f|%d|%s|%d|%s" % [c.id, c.i, c.k, c.r, c.y, state().placements.size(), str(state().inventory), version, draft_only]
		if key != ghost_key or ghost == null or ghost.get_meta("id") != c.id:
			check = evaluate(c)
			if ghost == null or ghost.get_meta("id") != c.id:
				_clear_ghost(); ghost = PieceMeshes.ghost(c.id, "ok"); game.add_child(ghost)
			var fp := BuildGrid.footprint(Data.piece(c.id), c.r)
			ghost.position = Vector3(c.i + fp.x / 2.0, c.y + 0.005, c.k + fp.y / 2.0)
			ghost.rotation.y = -c.r * PI / 2.0
			PieceMeshes.set_ghost(ghost, "draft" if check.get("kind", "") in ["draft", "drafted"] else ("ok" if check.ok else "bad"))
			ghost_key = key
			_render_status()
		ghost.visible = true
	else:
		if ghost: ghost.visible = false
		if not check.is_empty(): check = {}; ghost_key = ""; _render_status()   # (so coming back to the same cell checks it again)
	var center := Vector2(hover.point.x, hover.point.z) if not hover.is_empty() else Vector2(focus.x, focus.z)
	_update_spots(center)
	_near_labels()
	var sm: Node3D = game.piece_nodes.get(selected)
	var spl: Dictionary = _find(selected) if sm != null else Drafts.find(Drafts.of(state()), selected_draft)
	sel_box.visible = not spl.is_empty() and moving.is_empty()
	if sel_box.visible:
		var b := BuildGrid.bounds(spl)
		sel_box.position = Vector3((b.minX + b.maxX) / 2.0, (b.bottom + b.top) / 2.0, (b.minZ + b.maxZ) / 2.0)
		sel_box.scale = Vector3(b.maxX - b.minX + 0.1, b.top - b.bottom + 0.1, b.maxZ - b.minZ + 0.1)

func _spot_piece() -> Dictionary:
	if not moving.is_empty(): return {"id": String(moving.pl.id), "r": int(moving.r), "uid": int(moving.pl.uid)}
	if item_id == "": return {}
	return {"id": item_id, "r": rotation, "uid": -1}

func _update_spots(center: Vector2) -> void:
	var sp := _spot_piece()
	var d: Dictionary = Data.piece(String(sp.get("id", "")))
	if sp.is_empty() or d.is_empty() or d.get("attach", "") == "wall":
		if spots_root.visible: _show_fills(true)
		spots_root.visible = false; spot_key = ""; return
	var edge: bool = d.get("edge", false)
	var key := "%s|%d|%d|%d|%d|%s|%s" % [sp.id, -1 if edge else int(sp.r), int(sp.uid), version, Drafts.of(state()).size(), str(LocationMeter.progress(state(), Data.island)), str(unlocked_zones().size())]
	if key != spot_key:
		spot_key = key; spot_results.clear(); spot_center = Vector2i(1 << 20, 1 << 20)
		spot_ctx = _design_ctx(int(sp.uid)); spot_ctx["support_memo"] = {}; spot_ctx["uid"] = int(sp.uid)
	var c := Vector2i(floori(center.x), floori(center.y))
	if c != spot_center:
		spot_center = c
		spot_queue = _spot_cells(c)
		spot_dirty = true
	var t0 := Time.get_ticks_usec()
	while not spot_queue.is_empty() and Time.get_ticks_usec() - t0 < SPOT_BUDGET_USEC:
		var cell: Vector2i = spot_queue.pop_front()
		if spot_results.has(cell): continue
		spot_results[cell] = _scan_cell(sp, d, cell)
		spot_dirty = true
	if spot_dirty: _draw_spots(d); spot_dirty = false
	if not spots_root.visible: _show_fills(false)
	spots_root.visible = true

func _show_fills(on: bool) -> void:
	for f in grid_fills:
		if is_instance_valid(f): f.visible = on

func _spot_cells(c: Vector2i) -> Array:
	var zones: Array = spot_ctx.get("zones", [])
	var prog: float = spot_ctx.get("harmony", 0.0)
	var out: Array = []
	for di in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
		for dk in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
			if di * di + dk * dk > SPOT_RADIUS * SPOT_RADIUS: continue
			var cell := Vector2i(c.x + di, c.y + dk)
			if spot_results.has(cell) or BuildGrid.zone_at(zones, cell.x, cell.y, prog).is_empty(): continue
			out.append(cell)
	out.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())
	return out

func _scan_cell(sp: Dictionary, d: Dictionary, cell: Vector2i) -> Array:
	var found: Array = []
	var turns: Array = [0, 1, 2, 3] if d.get("edge", false) else [int(sp.r)]
	for r in turns:
		var v := BuildGrid.spot(String(sp.id), float(cell.x), float(cell.y), r, spot_ctx)
		if v.ok: found.append({"r": r, "y": float(v.pl.y)})
	return found

func _draw_spots(d: Dictionary) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	var edge: bool = d.get("edge", false)
	var box: Array = [0.04, 0.0, 0.96, 0.22] if edge else [0.08, 0.08, float(d.size[0]) - 0.08, float(d.size[1]) - 0.08]
	for cell in spot_results:
		if (cell - spot_center).length_squared() > SPOT_RADIUS * SPOT_RADIUS: continue
		for e in spot_results[cell]:
			var rc := BuildGrid.rect_of(d, {"i": float(cell.x), "k": float(cell.y), "r": int(e.r)}, box)
			var y: float = float(e.y) + 0.06
			var q := [Vector3(rc.minX, y, rc.minZ), Vector3(rc.maxX, y, rc.minZ), Vector3(rc.maxX, y, rc.maxZ), Vector3(rc.minX, y, rc.maxZ)]
			for idx in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[idx])
			n += 1
	spot_mesh.mesh = st.commit() if n > 0 else null

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
		elif item_id != "" or selected != -1 or selected_draft != -1: _let_go()
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
			elif item_id != "" or selected != -1 or selected_draft != -1: _let_go()

func _let_go() -> void:
	item_id = ""; selected = -1; selected_draft = -1; _build_ui()

func click() -> void:
	if not moving.is_empty(): drop_move(); return
	if item_id != "": place(); return
	if not hover.is_empty() and hover.uid >= 0:
		if hover.get("draft", false): selected_draft = int(hover.uid); selected = -1
		else: selected = hover.uid; selected_draft = -1
		game.sfx("select"); _build_ui()
	elif selected != -1 or selected_draft != -1: selected = -1; selected_draft = -1; _build_ui()

func _find(uid: int) -> Dictionary:
	for p in state().placements:
		if p.uid == uid: return p
	return {}

# ---- Commands
func _new_piece(from: Dictionary) -> Dictionary:
	var pl: Dictionary = from.duplicate(true)
	pl.uid = int(state().next_uid); state().next_uid = pl.uid + 1
	var d := Data.piece(pl.id)
	if color != "" and d.get("colorable", false): pl["color"] = color
	if d.get("mech", {}).get("switch", false): pl["state"] = {"on": true}
	if d.get("door", false): pl["state"] = {"open": false}
	return pl

func place() -> void:
	if check.is_empty(): return
	if check.get("kind", "") == "drafted": game.toast(check.reason); return
	if not check.ok: game.toast(check.reason, "warn"); game.sfx("error"); return
	if check.get("kind", "") == "draft":
		var dpl := _new_piece(check.pl)
		_add_drafts([dpl])
		history.push({"type": "drafts_add", "pls": [dpl.duplicate(true)]}); ghost_key = ""
		game.sfx("select")
		_build_ui(); return
	if check.get("kind", "") == "build_draft":
		var dr := Drafts.find(Drafts.of(state()), int(check.draft_uid))
		if dr.is_empty(): return
		var built := _build_one(dr)
		if built.ok: history.push({"type": "drafts_build", "pls": [dr.duplicate(true)]}); ghost_key = ""
		else: game.toast(built.reason, "warn")
		_build_ui(); return
	var pl := _new_piece(check.pl)
	var planned := next_plan_piece()
	var r: Dictionary = game.commit_place(pl, true)
	if r.ok:
		history.push({"type": "place", "pl": pl.duplicate(true)}); ghost_key = ""
		# you built the plan's next piece: if the one after is the same kind, it comes turned the way its outline is
		var nx := next_plan_piece()
		if not planned.is_empty() and Plans.built(planned, state().placements) and not nx.is_empty() and String(nx.id) == item_id: rotation = int(nx.r)
		_build_ui()

func remove_target() -> void:
	var draft_uid: int = selected_draft if selected_draft != -1 else (int(hover.uid) if selected == -1 and not hover.is_empty() and hover.get("draft", false) else -1)
	if draft_uid != -1:
		var dr := Drafts.find(Drafts.of(state()), draft_uid)
		if not dr.is_empty():
			_remove_drafts([draft_uid]); history.push({"type": "drafts_remove", "pls": [dr.duplicate(true)]})
			game.sfx("remove")
		selected_draft = -1; _build_ui(); return
	var uid: int = selected if selected != -1 else (hover.get("uid", -1) if not hover.is_empty() else -1)
	if uid < 0: game.toast("Point at a piece to remove it"); return   # (not a raised floor, -2)
	var pl := _find(uid).duplicate(true)
	var r: Dictionary = game.commit_remove(uid)
	if r.ok: history.push({"type": "remove", "pl": pl}); selected = -1; _build_ui()
	else: game.toast(r.reason, "warn")

func rotate_piece() -> void:
	if not moving.is_empty(): moving.r = (moving.r + 1) % 4; ghost_key = ""; return
	if item_id != "": rotation = (rotation + 1) % 4; ghost_key = ""; game.sfx("tick"); return
	if selected_draft != -1: game.toast("Remove it from the draft and draft it again the other way round"); return
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
		"drafts_add":
			if dir == "undo": _remove_drafts(cmd.pls.map(func(p): return int(p.uid)))
			else: _add_drafts(cmd.pls.map(func(p): return p.duplicate(true)))
			return {"ok": true}
		"drafts_remove":
			if dir == "undo": _add_drafts(cmd.pls.map(func(p): return p.duplicate(true)))
			else: _remove_drafts(cmd.pls.map(func(p): return int(p.uid)))
			return {"ok": true}
		"drafts_build":
			if dir == "undo":
				var back: Array = cmd.pls.duplicate()
				back.reverse()
				for p in back:
					var r: Dictionary = game.commit_remove(int(p.uid))
					if not r.ok: return r
					_add_drafts([p.duplicate(true)])
				return {"ok": true}
			for p in cmd.pls:
				var dr := Drafts.find(Drafts.of(state()), int(p.uid))
				if dr.is_empty(): return {"ok": false, "reason": "That draft is gone"}
				var r := _build_one(dr)
				if not r.ok: return r
			return {"ok": true}
	return {"ok": false, "reason": "Unknown action"}

func _add_drafts(pls: Array) -> void:
	var drafts := Drafts.of(state())
	for p in pls:
		if Drafts.find(drafts, int(p.uid)).is_empty(): drafts.append(p)
	state().next_uid = maxi(int(state().next_uid), Travel.max_uid(state()) + 1)
	_drafts_changed()

func _remove_drafts(uids: Array) -> void:
	state()["drafts"] = Drafts.of(state()).filter(func(p): return not uids.has(int(p.uid)))
	if uids.has(selected_draft): selected_draft = -1
	_drafts_changed()

func _drafts_changed() -> void:
	version += 1
	refresh_drafts()
	game.emit_event("draft", {"n": Drafts.of(state()).size()})

func _build_one(dr: Dictionary) -> Dictionary:
	var uid := int(dr.uid)
	var keep: Array = Drafts.of(state()).duplicate()
	state()["drafts"] = keep.filter(func(p): return int(p.uid) != uid)
	var r: Dictionary = game.commit_place(dr.duplicate(true), true)
	if not r.ok: state()["drafts"] = keep
	if uid == selected_draft and r.ok: selected_draft = -1
	_drafts_changed()
	return r

func build_drafts() -> void:
	var built: Array = []
	var why := ""
	var progress := true
	while progress:
		progress = false
		for dr in Drafts.build_order(Drafts.of(state())):
			if not Inventory.can_afford(state().inventory, Data.piece(String(dr.id)).cost): continue
			var r := _build_one(dr)
			if r.ok: built.append(dr.duplicate(true)); progress = true
			else: why = String(r.reason)
	if not built.is_empty(): history.push({"type": "drafts_build", "pls": built})
	var left := Drafts.of(state())
	var short := Drafts.shortfall(left, state().inventory)
	var msg := ""
	if left.is_empty(): msg = "Built the whole draft: %d piece%s." % [built.size(), "" if built.size() == 1 else "s"]
	elif not built.is_empty(): msg = "Built %d. Still drafted: %d%s" % [built.size(), left.size(), (" (you need %s more)" % Drafts.items_text(short)) if not short.is_empty() else (". " + why if why != "" else ".")]
	elif not short.is_empty(): msg = "You need %s more to build the draft." % Drafts.items_text(short)
	else: msg = why if why != "" else "Nothing in the draft can be built yet."
	game.toast(msg, "good" if not built.is_empty() else "warn", 3.5)
	ghost_key = ""; _build_ui()

func clear_drafts() -> void:
	var all: Array = Drafts.of(state()).map(func(p): return p.duplicate(true))
	if all.is_empty(): return
	_remove_drafts(all.map(func(p): return int(p.uid)))
	history.push({"type": "drafts_remove", "pls": all})
	game.toast("Draft cleared. %s undoes it." % "Ctrl+Z"); _build_ui()

func draft_plan() -> void:
	var sp := site_plan()
	if sp.is_empty(): return
	var added: Array = []
	var blocked := 0
	for pc in sp.pieces:
		if Plans.built(pc, state().placements): continue
		var pl := {"uid": -1, "id": String(pc.id), "i": float(pc.i), "k": float(pc.k), "r": int(pc.r), "y": float(pc.y)}
		if not Drafts.find_same(Drafts.of(state()), pl).is_empty(): continue
		if not BuildGrid.validate_placement(pl, _design_ctx(-1)).ok: blocked += 1; continue
		var dpl := _new_piece(pl)
		_add_drafts([dpl]); added.append(dpl.duplicate(true))
	if not added.is_empty(): history.push({"type": "drafts_add", "pls": added})
	var short := Drafts.shortfall(Drafts.of(state()), state().inventory)
	var msg := "The plan is in your draft (%d piece%s)." % [added.size(), "" if added.size() == 1 else "s"] if not added.is_empty() else "Everything in the plan is already built or drafted."
	if blocked > 0: msg += " %d spot%s %s blocked." % [blocked, "" if blocked == 1 else "s", "is" if blocked == 1 else "are"]
	msg += (" You need %s more to build it." % Drafts.items_text(short)) if not short.is_empty() else " You have everything: build the draft."
	game.toast(msg, "good", 4.0)
	ghost_key = ""; _build_ui()

func draft_gain() -> int:
	var hs := Needs.hangouts()
	if hs.is_empty() or Drafts.of(state()).is_empty(): return 0
	var v := Needs.village(hs, Drafts.design(state().placements, Drafts.of(state())), game.reach_cache, game.mech.lamps)
	return int(v.points) - int(game.village_score.get("points", 0))

func refresh_hangouts() -> void:
	for c in hangout_root.get_children(): hangout_root.remove_child(c); c.queue_free()
	hangout_labels.clear()
	var hs := Needs.hangouts()
	var v: Dictionary = game.village_score
	var known: Array = Needs.of(state()).noticed
	for h in hs:
		var hid := String(h.id)
		var parts: Array = []
		var wanting := false
		for n in v.get("needs", []):
			if n.hangout != hid: continue
			var icon := String(Needs.kind_def(String(n.kind)).get("icon", ""))
			if n.met: parts.append(icon + "✔")
			elif known.has(n.key): parts.append(icon + "○"); wanting = true
		var charm := 0
		for ch in v.get("charm", []):
			if ch.hangout == hid: charm = int(ch.points)
		if charm > 0: parts.append("★".repeat(charm))
		var r := float(h.get("r", 3.0))
		var lines := SurfaceTool.new(); lines.begin(Mesh.PRIMITIVE_LINES)
		var seg := 48
		for i in seg:
			var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
			if i % 2 == 1: continue
			for a in [a0, a1]:
				var x := float(h.x) + cos(a) * r; var z := float(h.z) + sin(a) * r
				lines.add_vertex(Vector3(x, maxf(Heightfield.height(x, z), Heightfield.WATER_Y) + 0.1, z))
		var ring := MeshInstance3D.new(); ring.mesh = lines.commit(); ring.name = "ring_" + hid
		ring.material_override = Palette.glow_mat(Color("ffb93b") if wanting else Color("8fe3b0"), 0.9)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hangout_root.add_child(ring)
		var l := Label3D.new(); l.text = String(h.name) + ("\n" + "  ".join(parts) if not parts.is_empty() else ""); l.font = UiTheme.main_font(); l.font_size = 32; l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.modulate = Color("5a3f6e"); l.outline_modulate = Color.WHITE; l.outline_size = 14; l.no_depth_test = true; l.name = "hangout_" + hid
		l.position = Vector3(float(h.x), maxf(Heightfield.height(float(h.x), float(h.z)), 0.0) + 1.6, float(h.z))
		hangout_root.add_child(l)
		hangout_labels.append(l)
	_near_labels()

func _near_labels() -> void:
	for l in hangout_labels:
		if is_instance_valid(l): l.visible = Vector2(l.position.x - focus.x, l.position.z - focus.z).length() < 14.0

func toggle_draft_only() -> void:
	draft_only = not draft_only
	game.toast("Draft only: pieces go into your draft, nothing is spent" if draft_only else "Draft only is off: pieces you can afford are built straight away")
	ghost_key = ""; _build_ui()

func refresh_drafts() -> void:
	for c in draft_root.get_children(): c.queue_free()
	draft_nodes.clear()
	for dr in Drafts.of(state()):
		var g := PieceMeshes.ghost(String(dr.id), "draft")
		var fp := BuildGrid.footprint(Data.piece(String(dr.id)), int(dr.r))
		g.position = Vector3(float(dr.i) + fp.x / 2.0, float(dr.y) + 0.005, float(dr.k) + fp.y / 2.0); g.rotation.y = -int(dr.r) * PI / 2.0
		draft_root.add_child(g); draft_nodes[int(dr.uid)] = g
	if game.hud: game.hud.render_tracker()

func select_item(id: String) -> void:
	if not state().blueprints.has(id): game.toast("Locked — " + game.blueprint_hint(id), "warn"); return
	if not moving.is_empty(): cancel_move()
	selected_draft = -1
	item_id = id   # (clicking the piece already in your hand keeps it: build mode may have picked it for you from a plan; right-click or Esc lets go)
	selected = -1; ghost_key = ""
	state().new_blueprints.erase(id)
	game.sfx("select")
	_build_ui()

# ---- UI
func _status_text() -> String:
	if not moving.is_empty():
		return ("Click to put it here" if check.ok else check.reason) if not check.is_empty() else "Carrying a piece — point where it should go"
	if item_id == "":
		if selected_draft != -1: return "A drafted piece: build it, or remove it from the draft"
		return "Piece selected" if selected != -1 else "Pick a piece from the catalog, or click a placed piece to edit it"
	var d := Data.piece(item_id)
	if check.is_empty(): return "%s: it can go on the glowing spots" % d.name
	if not check.ok: return check.reason
	match check.get("kind", ""):
		"draft": return "Click to draft the %s: %s" % [String(d.name).to_lower(), check.why]
		"build_draft": return "Click to build the drafted %s (%s)" % [String(d.name).to_lower(), _cost_text(d.cost)]
	return "Click to build the %s (%s)" % [String(d.name).to_lower(), _cost_text(d.cost)]

func _render_status() -> void:
	if status_label == null: return
	status_label.text = _status_text()
	var drafting: bool = not check.is_empty() and check.get("kind", "") in ["draft", "drafted"]
	var bad: bool = not check.is_empty() and not check.ok and not drafting
	var sp: PanelContainer = status_label.get_parent()
	sp.add_theme_stylebox_override("panel", UiTheme.box(Color("fff3f3") if bad else (Color("eef8ff") if drafting else Color.WHITE), Color("ffb3b3") if bad else (Color("8fd3ff") if drafting else Color("cfe8d4")), 999, 3, 6, false))
	status_label.add_theme_color_override("font_color", Color("b34a4a") if bad else (Color("2f6f9e") if drafting else Color("2f8a52")))

## "🪵3 🧵2 💰120,000" (money in lire); `money_sep` goes before the money (a new line in the catalog's small cells).
static func _cost_text(cost: Dictionary, money_sep: String = " ") -> String:
	var parts: Array = []
	var money := ""
	for k in cost:
		if k == "coins": money = "%s%s" % [Data.resources[k].icon, Money.group(int(cost[k]) * Money.LIRE_PER_COIN)]
		else: parts.append("%s%d" % [Data.resources[k].icon, int(cost[k])])
	var out := " ".join(parts)
	if money != "": out = money if out == "" else out + money_sep + money
	return out

func _build_ui() -> void:
	if ui: ui.queue_free()
	if not active: return
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(ui)
	# Top bar
	var top := UiTheme.panel(Color(UiTheme.CREAM, 0.96), UiTheme.LILAC, 999)
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 10); top.add_child(tb)
	tb.add_child(UiTheme.label("📐 Build mode", 16))
	tb.add_child(UiTheme.button("◀", func(): cycle_zone(-1)))
	tb.add_child(UiTheme.label(current_zone.get("name", "No area"), 16, Color("7a5cc9")))
	tb.add_child(UiTheme.button("▶", func(): cycle_zone(1)))
	var ub := UiTheme.button("↶", undo); ub.disabled = not history.can_undo(); ub.tooltip_text = "Undo (Ctrl+Z)"; tb.add_child(ub)
	var rb := UiTheme.button("↷", redo); rb.disabled = not history.can_redo(); rb.tooltip_text = "Redo (Ctrl+Y)"; tb.add_child(rb)
	var dob := UiTheme.button("Draft only", toggle_draft_only, draft_only); dob.name = "draft_only"; dob.tooltip_text = "Draft pieces without building them (%s)" % Controls.key_label("draft_only"); tb.add_child(dob)
	var hb := UiTheme.button("❓", show_help); hb.name = "build_help"; hb.tooltip_text = "How to build, and the keys"; tb.add_child(hb)
	tb.add_child(UiTheme.button("Done", close, true))
	var top_c := CenterContainer.new(); top_c.anchor_right = 1; top_c.offset_top = 64; top_c.offset_bottom = 110; top_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_c.add_child(top); ui.add_child(top_c)
	var sp := UiTheme.panel(Color.WHITE, Color("cfe8d4"), 999)
	status_label = UiTheme.label("", 15, Color("2f8a52")); sp.add_child(status_label)
	var st_c := CenterContainer.new(); st_c.anchor_right = 1; st_c.offset_top = 118; st_c.offset_bottom = 150; st_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_c.add_child(sp); ui.add_child(st_c)
	_render_status()
	_draft_bar()
	# Help
	var help := UiTheme.panel()
	var goals: Dictionary = game.build_goals(current_zone)
	var keys := [Controls.key_label("rotate"), Controls.key_label("recolor"), Controls.key_label("move_piece"), Controls.key_label("remove"), Controls.key_label("draft_only"), Controls.key_label("pause"), Controls.key_label("build")]
	# with a request checklist above it, the controls shrink to two lines so the column stays clear of the catalog
	var hl := UiTheme.label(("%s rotate · %s colour · %s move · %s remove\nCtrl+Z undo · %s draft only · %s leave" % [keys[0], keys[1], keys[2], keys[3], keys[4], keys[5]]) if not goals.is_empty() else
		("Left click — build, draft or select\nRight click — cancel · right-drag — turn view\n%s rotate · %s colour · %s move\n%s remove · Ctrl+Z undo · Ctrl+Y redo\nWASD pan · wheel zoom · %s draft only\n%s / %s leave build mode\nThe clock waits while you build" % keys), 12, UiTheme.INK2)
	help.add_child(hl); help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right column: goals or the selected piece, then the controls (the left side holds the guide and tip cards)
	var right := VBoxContainer.new(); right.anchor_left = 1; right.anchor_right = 1; right.offset_left = -268; right.offset_right = -14; right.offset_top = 160
	right.add_theme_constant_override("separation", 10); right.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(right)
	if not goals.is_empty() and selected == -1 and moving.is_empty():
		var gp := UiTheme.panel(Color("fffce6"), UiTheme.GOLD)
		var gv := VBoxContainer.new(); gp.add_child(gv)
		gv.add_child(UiTheme.label("📜 " + goals.title, 14))
		if goals.has("hint"): var hh := UiTheme.label(goals.hint, 12, UiTheme.INK2); hh.autowrap_mode = TextServer.AUTOWRAP_WORD; hh.custom_minimum_size.x = 226; gv.add_child(hh)
		for it in goals.items:
			var gl := UiTheme.label(("" if it.get("later", false) else ("✔ " if it.ok else "○ ")) + it.label, 13, Color("2f8a52") if it.ok else (UiTheme.INK2 if it.get("later", false) else UiTheme.INK))
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD; gl.custom_minimum_size.x = 226; gv.add_child(gl)
		right.add_child(gp)
	if selected == -1 and selected_draft == -1 and moving.is_empty(): _plan_panel(right)
	if selected_draft != -1: _selected_draft_panel(right)
	if selected != -1 or not moving.is_empty():
		var pl: Dictionary = moving.pl if not moving.is_empty() else _find(selected)
		if not pl.is_empty():
			var d := Data.piece(pl.id)
			var p := UiTheme.panel(Color(UiTheme.CREAM, 0.97), UiTheme.LILAC)
			var v := VBoxContainer.new(); p.add_child(v)
			v.add_child(UiTheme.label("%s %s" % [d.icon, d.name], 16))
			var desc := UiTheme.label(d.desc, 12, UiTheme.INK2); desc.autowrap_mode = TextServer.AUTOWRAP_WORD; desc.custom_minimum_size.x = 220; v.add_child(desc)
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
	if show_keys: right.add_child(help)   # (with a plan, the panel and the ❓ card say how)
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
	# what you have, beside what the pieces cost (the HUD's chips step aside in build mode); it fills the space
	# between the tabs and the colour swatches, and wraps rather than pushing them off the panel
	var have: Array = game.hud_items().map(func(id): return ("%s %s" % [Data.resources[id].icon, Money.lire(int(state().inventory.get(id, 0)))]) if id == "coins" else ("%s %d" % [Data.resources[id].icon, int(state().inventory.get(id, 0))]))
	var hv := UiTheme.label("You have  " + "   ".join(have), 13, UiTheme.INK2); hv.name = "build_have"
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hv.autowrap_mode = TextServer.AUTOWRAP_WORD; hv.custom_minimum_size.x = 180
	tabs.add_child(hv)
	if item_id != "" and Data.piece(item_id).get("colorable", false):
		tabs.add_child(_swatches(color if color != "" else Data.piece(item_id).color, set_color))
	# Every piece stays visible: the catalog wraps onto a second row instead of scrolling sideways.
	var items := HFlowContainer.new(); items.add_theme_constant_override("h_separation", 6); items.add_theme_constant_override("v_separation", 6); cv.add_child(items)
	for p in Data.pieces:
		if p.cat != category: continue
		var unlocked: bool = state().blueprints.has(p.id)
		var poor := unlocked and not Inventory.can_afford(state().inventory, p.cost)
		var pid: String = p.id
		var ruled: String = String(Data.layout.get("noBuild", {}).get(pid, ""))   # not here, whatever you have
		var btn := Button.new(); btn.name = "piece_" + pid
		btn.custom_minimum_size = Vector2(68, 68)
		btn.tooltip_text = ruled if ruled != "" else (("%s: %s" % [p.name, p.desc]) if unlocked else "Locked: " + game.blueprint_hint(pid))
		var on := item_id == pid
		var sb := UiTheme.box(Color("f6f0ff") if on else Color.WHITE, Color("a07cff") if on else Color("eadcff"), 16, 3, 4, false)
		btn.add_theme_stylebox_override("normal", sb); btn.add_theme_stylebox_override("hover", UiTheme.box(Color("fbf8ff"), Color("c9a8ff"), 16, 3, 4, false))
		var vb := VBoxContainer.new(); vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); vb.alignment = BoxContainer.ALIGNMENT_CENTER; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		var icon := UiTheme.label(p.icon if unlocked else "🔒", 20); icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UiTheme.label(p.name, 11); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nm.autowrap_mode = TextServer.AUTOWRAP_WORD; nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ct := UiTheme.label("not here" if ruled != "" else (_cost_text(p.cost, "\n") if unlocked else "locked"), 10, Color("d55555") if poor or ruled != "" else UiTheme.INK2); ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state().new_blueprints.has(pid): var nw := UiTheme.label("✦ new", 10, UiTheme.PINK_DARK); nw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nw.mouse_filter = Control.MOUSE_FILTER_IGNORE; vb.add_child(nw)
		vb.add_child(icon); vb.add_child(nm); vb.add_child(ct)
		btn.add_child(vb)
		if not unlocked or ruled != "": btn.modulate = Color(1, 1, 1, 0.55)
		btn.pressed.connect(func(): select_item(pid))
		items.add_child(btn)
	ui.add_child(cat)

## The plan you can follow on this site: how far along it is, what the next piece is and where it goes, what you
## still need for it, and a button (or V) that puts it in your hand.
func _plan_panel(col: VBoxContainer) -> void:
	var sp := site_plan()
	if sp.is_empty(): return
	var nx := next_plan_piece()
	var pp := UiTheme.panel(Color("f6f0ff"), UiTheme.LILAC); pp.name = "plan_panel"
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 4); pp.add_child(pv)
	pv.add_child(UiTheme.label("📐 Follow the glowing plan   %d / %d" % [Plans.built_count(sp.pieces, state().placements), sp.pieces.size()], 14, Color("7a5cc9")))
	var any := UiTheme.label("(or build it your own way)", 11, UiTheme.INK2); pv.add_child(any)
	var lines: Array = []
	if nx.is_empty(): lines.append("Every piece of the plan is built.")
	else:
		var d := Data.piece(String(nx.id))
		lines.append("Next: %s %s, on the outline under the purple arrow." % [d.icon, d.name])
		if item_id == String(nx.id):   # in your hand (otherwise the button below picks it up)
			if rotation != int(nx.r) and _turn_matters(d): lines.append("Press %s to turn it until it matches the outline." % Controls.key_label("rotate"))
			else: lines.append("Point at the outline: green means it fits. Click to build it.")
		var short := Inventory.missing(state().inventory, d.get("cost", {}))
		if not short.is_empty():
			lines.append("You need %s more for it." % ", ".join(short.map(func(m): return Money.lire(int(m.need)) if m.id == "coins" else "%d %s" % [int(m.need), String(Data.resources[m.id].name).to_lower()])))
	for t in lines:
		var l := UiTheme.label(t, 12, UiTheme.INK); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 226; pv.add_child(l)
	if not nx.is_empty() and item_id != String(nx.id):
		var b := UiTheme.button("📐 Pick the next piece  (%s)" % Controls.key_label("plan_next"), func(): follow_plan(true)); b.name = "plan_pick"
		b.add_theme_font_size_override("font_size", UiTheme.px(14)); pv.add_child(b)
	if not nx.is_empty():
		var db := UiTheme.button("Put the whole plan in your draft", draft_plan); db.name = "plan_draft"
		db.add_theme_font_size_override("font_size", UiTheme.px(13)); pv.add_child(db)
	col.add_child(pp)

func _draft_bar() -> void:
	var drafts := Drafts.of(state())
	if drafts.is_empty(): return
	var short := Drafts.shortfall(drafts, state().inventory)
	var p := UiTheme.panel(Color("eef8ff"), Color("4fb3ff"), 999); p.name = "draft_panel"
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); p.add_child(row)
	var need := ("gather %s" % Drafts.items_text(short)) if not short.is_empty() else "ready to build"
	var gain := draft_gain()
	if gain != 0: need += "  %s%d 💖" % ["+" if gain > 0 else "", gain]
	var l := UiTheme.label("📐 Draft: %d piece%s, %s" % [drafts.size(), "" if drafts.size() == 1 else "s", need], 13, Color("2f6f9e"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(l)
	var bb := UiTheme.button("Build the draft", build_drafts, short.is_empty()); bb.name = "draft_build"; row.add_child(bb)
	var cb := UiTheme.button("Clear", clear_drafts); cb.name = "draft_clear"; row.add_child(cb)
	var c := CenterContainer.new(); c.anchor_right = 1; c.offset_top = 156; c.offset_bottom = 198; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p); ui.add_child(c)

func _selected_draft_panel(col: VBoxContainer) -> void:
	var dr := Drafts.find(Drafts.of(state()), selected_draft)
	if dr.is_empty(): return
	var d := Data.piece(String(dr.id))
	var p := UiTheme.panel(Color("eef8ff"), Color("8fd3ff")); p.name = "draft_selected"
	var v := VBoxContainer.new(); p.add_child(v)
	v.add_child(UiTheme.label("%s %s (drafted)" % [d.icon, d.name], 16))
	var short := Inventory.missing(state().inventory, d.cost)
	var l := UiTheme.label(("It needs %s." % _cost_text(d.cost)) + ((" You need %s more." % Drafts.items_text(short)) if not short.is_empty() else ""), 12, UiTheme.INK2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 220; v.add_child(l)
	var row := HBoxContainer.new(); v.add_child(row)
	var bb := UiTheme.button("Build it", build_selected_draft, short.is_empty())
	bb.name = "draft_build_one"; row.add_child(bb)
	row.add_child(UiTheme.button("🗑", remove_target))
	col.add_child(p)

func build_selected_draft() -> void:
	var dr := Drafts.find(Drafts.of(state()), selected_draft)
	if dr.is_empty(): return
	var r := _build_one(dr)
	if r.ok: history.push({"type": "drafts_build", "pls": [dr.duplicate(true)]})
	else: game.toast(r.reason, "warn")
	_build_ui()

## Does which way a piece faces change it (a long piece, a railing on one edge, a machine's axle, a chair)?
static func _turn_matters(d: Dictionary) -> bool:
	var sz: Array = d.get("size", [1, 1])
	return int(sz[0]) != int(sz[1]) or d.get("edge", false) or d.has("mech") or d.has("box") or d.get("attach", "") == "wall"

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
