class_name VillageMap
extends Control

signal picked(text: String)

const WATER := Color("7fc8e6")
const LAND := Color("b9d98f")
const SLOPE := Color("9cc27a")
const PATH := Color("eedcae")
const SITE := Color("8a6fd6")
const YOU := Color("ff5d8f")
const INK := Color("4a3b33")
const HALO := Color(1, 1, 1, 0.9)
const DOTS := [Color("e86f5c"), Color("5c9ee8"), Color("f0b23c"), Color("6cbf7a"), Color("b57be0"), Color("e889b8"), Color("4fb3a8"), Color("c98a55"), Color("7a86d6"), Color("d06a8f")]

static var _ground_cache := {}

var game

func area() -> Rect2:
	var pts: Array = []
	var L: Dictionary = Data.layout
	for b in L.get("buildings", []): pts.append(Vector2(float(b.x), float(b.z)))
	for k in L.get("nav_nodes", {}): pts.append(Vector2(float(L.nav_nodes[k][0]), float(L.nav_nodes[k][1])))
	for f in L.get("features", []): pts.append(Vector2(float(f.x), float(f.z)))
	for z in L.get("zones", []):
		if z.get("open", false): continue
		pts.append(Vector2(float(z.minI), float(z.minK)))
		pts.append(Vector2(float(z.maxI) + 1.0, float(z.maxK) + 1.0))
	if pts.is_empty(): return Rect2(-40, -40, 80, 80)
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts: r = r.expand(p)
	return r.grow(6.0)

func _scale() -> float:
	var a := area()
	return minf(size.x / a.size.x, size.y / a.size.y)

func to_screen(w: Vector2) -> Vector2:
	var a := area()
	var k := _scale()
	var pad := (size - a.size * k) / 2.0
	return pad + (w - a.position) * k

func to_world(s: Vector2) -> Vector2:
	var a := area()
	var k := _scale()
	var pad := (size - a.size * k) / 2.0
	return a.position + (s - pad) / k

func _ground() -> ImageTexture:
	var a := area()
	var key := "%s|%s" % [Data.island, str(a)]
	if _ground_cache.has(key): return _ground_cache[key]
	var cell := 0.75
	var nx := int(ceil(a.size.x / cell))
	var nz := int(ceil(a.size.y / cell))
	var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	var reach := TerrainBuilder.water_radius()
	for j in nz:
		for i in nx:
			var x := a.position.x + (i + 0.5) * cell
			var z := a.position.y + (j + 0.5) * cell
			var h := Heightfield.height(x, z)
			var c := LAND
			if h < Heightfield.WATER_Y and Vector2(x, z).length() < reach: c = WATER
			elif h < -1.5: c = SLOPE
			img.set_pixel(i, j, c)
	var tex := ImageTexture.create_from_image(img)
	_ground_cache[key] = tex
	return tex

func entries() -> Array:
	var out: Array = []
	var L: Dictionary = Data.layout
	for b in L.get("buildings", []):
		if not named(String(b.get("name", "")), String(b.get("kind", ""))): continue
		out.append({"kind": "building", "id": String(b.id), "label": String(b.name), "at": to_screen(Vector2(float(b.x), float(b.z)))})
	for z in L.get("zones", []):
		if z.get("open", false) or not game.zone_unlocked(z): continue
		out.append({"kind": "site", "id": String(z.id), "label": String(z.get("name", z.id)), "at": to_screen(Vector2((float(z.minI) + float(z.maxI) + 1.0) / 2.0, (float(z.minK) + float(z.maxK) + 1.0) / 2.0))})
	for f in L.get("features", []):
		var kind := String(f.get("kind", ""))
		if kind == "boat": out.append({"kind": "bus", "id": String(f.id), "label": "The bus stop", "at": to_screen(Vector2(float(f.x), float(f.z)))})
		elif kind == "bench": out.append({"kind": "bench", "id": String(f.id), "label": "A bench to rest on", "at": to_screen(Vector2(float(f.x), float(f.z)))})
	var hs := Needs.hangouts()
	var open := Needs.open_here(game.state, hs, Needs.met_keys(game.village_score))
	for h in hs:
		var wants: Array = open.filter(func(k): return String(k).begins_with(String(h.id) + ":"))
		if wants.is_empty(): continue
		var icons: Array = wants.map(func(k): return String(Needs.kind_def(String(k).get_slice(":", 1)).get("icon", "")))
		out.append({"kind": "need", "id": String(h.id), "label": "%s could use %s" % [String(h.name), ", ".join(wants.map(func(k): return String(Needs.kind_def(String(k).get_slice(":", 1)).get("name", ""))))], "icons": "".join(icons), "at": to_screen(Vector2(float(h.x), float(h.z)))})
	var n := 0
	var ids: Array = game.npcs.keys()
	ids.sort()
	for id in ids:
		var npc = game.npcs[id]
		n += 1
		if not npc.present: continue
		var mark: String = game.story.marker_for(String(id)) if game.story else ""
		var first := short_name(String(npc.def.name))
		var note := " has a request" if mark == "offer" else (" is waiting to hear from you" if mark == "ready" else "")
		out.append({"kind": "villager", "id": String(id), "label": String(npc.def.name) + note, "short": first, "mark": mark, "colour": DOTS[(n - 1) % DOTS.size()], "at": to_screen(Vector2(npc.pos.x, npc.pos.z))})
	var tg: Dictionary = game.guide.target() if game.guide else {}
	if not tg.is_empty(): out.append({"kind": "target", "id": "target", "label": "Tracking: " + String(tg.get("label", "")), "at": to_screen(Vector2(float(tg.x), float(tg.z)))})
	out.append({"kind": "you", "id": "you", "label": "You are here", "at": to_screen(Vector2(game.player.pos.x, game.player.pos.z))})
	return out

static func named(name: String, kind: String) -> bool:
	if name == "" or kind == "backdrop" or kind.ends_with("_track") or kind.begins_with("rice_village_wall"): return false
	for generic in ["A ", "An ", "House ", "Houses ", "Terrace ", "Row "]:
		if name.begins_with(generic): return false
	var code := RegEx.new()
	code.compile("^([A-Z][a-z]? [A-Z]?[a-z]?[0-9]+|[A-Za-z]+ [NSEW])$")
	return code.search(name) == null

const TITLES := ["Signor", "Signora", "Signorina", "Vigile", "Architetto", "Maestro", "Ragioniere", "Ingegner", "Dottor", "Capostazione", "Don"]

static func short_name(full: String) -> String:
	var words := full.split(" ", false)
	for w in words:
		if not TITLES.has(w): return w
	return full

var _taken: Array = []

func _font() -> Font: return UiTheme.main_font()

func _label(at: Vector2, s: String, px: int, col: Color = INK) -> bool:
	var f := _font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var box := Rect2(at - Vector2(w / 2.0 + 2.0, float(px)), Vector2(w + 4.0, float(px) + 4.0))
	for r in _taken:
		if (r as Rect2).intersects(box): return false
	_taken.append(box)
	_text(at, s, px, col)
	return true

func _text(at: Vector2, s: String, px: int, col: Color = INK) -> void:
	var f := _font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at - Vector2(w / 2.0, 0.0)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, HALO)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _draw() -> void:
	var a := area()
	var k := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), SLOPE)
	draw_texture_rect(_ground(), Rect2(to_screen(a.position), a.size * k), false)
	var L: Dictionary = Data.layout
	for p in L.get("paths", []):
		var line := PackedVector2Array()
		for q in p: line.append(to_screen(Vector2(float(q[0]), float(q[1]))))
		if line.size() >= 2: draw_polyline(line, PATH, maxf(2.0, 1.8 * k), true)
	for z in L.get("zones", []):
		if z.get("open", false) or not game.zone_unlocked(z): continue
		var r := Rect2(to_screen(Vector2(float(z.minI), float(z.minK))), Vector2(float(z.maxI) - float(z.minI) + 1.0, float(z.maxK) - float(z.minK) + 1.0) * k)
		draw_rect(r, Color(SITE, 0.16))
		var c := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y), r.position]
		for i in 4: draw_dashed_line(c[i], c[i + 1], SITE, 2.0, 6.0)
	for b in L.get("buildings", []):
		var w := Vector2(float(b.get("w", 4.0)), float(b.get("d", 4.0)))
		var r := Rect2(to_screen(Vector2(float(b.x), float(b.z)) - w / 2.0), w * k)
		var roof := Color(String(b.get("roof", "c9a98a"))) if String(b.get("roof", "")).length() >= 6 else Color("c9a98a")
		draw_rect(r, roof.lerp(Color.WHITE, 0.15))
		draw_rect(r, roof.darkened(0.35), false, 1.5)
	var items := entries()
	for e in items:
		match String(e.kind):
			"bench": draw_rect(Rect2(e.at - Vector2(3, 2), Vector2(6, 4)), Color("8a5a3c"))
			"bus": _text(e.at + Vector2(0, 6), "🚌", 18)
			"need": _text(e.at + Vector2(0, 6), String(e.icons), 15, Color("d64f86"))
	_taken.clear()
	for e in items:
		if String(e.kind) != "villager": continue
		draw_circle(e.at, 5.5, HALO)
		draw_circle(e.at, 4.0, e.colour)
		_taken.append(Rect2(e.at - Vector2(4, 3), Vector2(8, 7)))
	for e in items:
		if String(e.kind) != "villager": continue
		_label(e.at + Vector2(0, -9), String(e.short), 12)
		if String(e.mark) == "offer": _text(e.at + Vector2(10, 4), "!", 16, Color("e0a21b"))
		elif String(e.mark) == "ready": _text(e.at + Vector2(11, 4), "★", 14, Color("3fa860"))
	for e in items:
		if String(e.kind) == "site": _label(e.at + Vector2(0, 4), String(e.label), 11, SITE.darkened(0.3))
	for e in items:
		if String(e.kind) == "building": _label(e.at + Vector2(0, 4), String(e.label), 11)
	for e in items:
		if String(e.kind) == "target":
			draw_circle(e.at, 9.0, Color(YOU, 0.25))
			_text(e.at + Vector2(0, 6), "⭐", 16)
	var you: Vector2 = to_screen(Vector2(game.player.pos.x, game.player.pos.z))
	var dir := Vector2(sin(game.player.yaw), cos(game.player.yaw))
	var side := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([you + dir * 10.0, you - dir * 6.0 + side * 6.0, you - dir * 6.0 - side * 6.0])
	draw_colored_polygon(tri, HALO)
	draw_colored_polygon(PackedVector2Array([you + dir * 7.5, you - dir * 4.0 + side * 4.0, you - dir * 4.0 - side * 4.0]), YOU)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var best := {}
	var bd := 16.0
	for e in entries():
		var d: float = (e.at as Vector2).distance_to(event.position)
		if d < bd: bd = d; best = e
	if not best.is_empty(): picked.emit(String(best.label))
