extends Node3D

const P := preload("../../world/palette.gd")
const Landmarks := preload("landmarks.gd")
const Sounds := preload("sounds.gd")

const QUAY_H := 1.2
const BEAM_PERIOD := 11.0
const BEAM_SPLIT := 0.38
const WASHING := {
	"tablecloth": [2, 0, 1],
	"shirt": [3, 4],
	"longjohns": [5, 6],
	"apron": [7, 8, 9],
	"gloves": [10, 11, 12],
}
const CLOTHS := ["f4f2ec", "f4f2ec", "dfe8f0", "f2d7d9", "e9dfb8", "c9dde0", "f4f2ec", "b9c8de", "e8c9a8", "d8e4cc"]
const GULL_RINGS := [[Vector2(2.0, 58.0), 16.0, 11.0], [Vector2(-34.0, 62.0), 12.0, 9.0], [Vector2(46.0, 66.0), 10.0, 15.0],
	[Vector2(62.0, 24.0), 11.0, 12.0], [Vector2(-8.0, 34.0), 7.0, 14.0], [Vector2(20.0, 78.0), 18.0, 13.0]]
const GULL_SHY := 3.5
const PIGEON_SPOTS := [Vector2(-1.0, -7.0), Vector2(6.0, -3.0), Vector2(-5.5, -2.5)]
const PIGEON_SHY := 4.0
const LAMPARA_RING := [Vector2(10.0, 96.0), 26.0]
const PORT_LIGHTS := 160

var game = null
var village: Node3D = null
var t := 0.0
var lantern: Node3D = null
var lens_mat: StandardMaterial3D = null
var panes: Array = []
var beam: Node3D = null
var beam_light: OmniLight3D = null
var washing: Dictionary = {}
var pergola: Node3D = null
var note: Node3D = null
var circling: Array = []
var perched: Array = []
var pigeons: Array = []
var boats: Array = []
var port_lights: MultiMeshInstance3D = null
var sounds := {}

static func lantern_state(flags: Dictionary) -> Dictionary:
	var lit: bool = flags.get("port_finale_night", false) or flags.get("port_lighthouse_lit", false)
	return {"glazed": flags.get("port_glazed", false) or lit, "lit": lit, "beam": lit and flags.get("night", false)}

static func beam_angle(seconds: float) -> float: return fposmod(seconds, BEAM_PERIOD) / BEAM_PERIOD * TAU

static func washing_up(flags: Dictionary) -> Array:
	var out: Array = []
	for w in WASHING:
		if flags.get("port_wash_%s_done" % w, false): out.append_array(WASHING[w])
	out.sort()
	return out

static func gull_flees(at: Vector2, player: Vector2) -> bool: return at.distance_to(player) < GULL_SHY

static func pigeons_flee(at: Vector2, player: Vector2) -> bool: return at.distance_to(player) < PIGEON_SHY

static func next_pigeon_spot(from: int, player: Vector2) -> int:
	var best := from
	var far := -1.0
	for i in PIGEON_SPOTS.size():
		if i == from: continue
		var d: float = (PIGEON_SPOTS[i] as Vector2).distance_to(player)
		if d > far:
			far = d
			best = i
	return best

static func boats_out(flags: Dictionary) -> bool:
	return (flags.get("port_finale_night", false) or flags.get("port_lighthouse_lit", false)) and flags.get("night", false)

func setup(g, v: Node3D) -> void:
	game = g
	village = v
	_build_lantern()
	_build_washing()
	_build_pergola()
	_build_note()
	_build_gulls()
	_build_pigeons()
	_build_boats()
	_build_port_lights()
	_build_fluff()
	_update_story(_flags())
	if game != null and game.has_signal("game_event"): game.game_event.connect(_on_event)

static func nap_scene(where: String, gag: String) -> String:
	if where != "bench": return ""
	return gag if gag in ["gull", "spray", "basket"] else ""

func _on_event(kind: String, data: Dictionary) -> void:
	if kind != "slept" or game.get("nap_gags") == null: return
	var scene := nap_scene(String(data.get("where", "")), String(data.get("gag", "")))
	if scene == "": return
	var f := Vector3(sin(game.player.yaw), 0.0, cos(game.player.yaw))
	var side := Vector3(f.z, 0.0, -f.x)
	var at: Vector3 = game.player.pos
	var prop := NapGags.TimedProp.new()
	prop.name = "port_nap_" + scene
	prop.game = game
	game.nap_gags.add_child(prop)
	prop.global_position = at
	match scene:
		"gull":
			prop.life = 8.0
			var gl := _gull_mesh()
			remove_child(gl.obj)
			prop.add_child(gl.obj)
			var o: Node3D = gl.obj
			o.position = side * 0.55 - f * 0.25 + Vector3(0, 0.55, 0)
			o.rotation.y = atan2(-side.x, -side.z)
			o.scale = Vector3.ONE * 1.3
			o.add_child(P.mi(P.box(0.16, 0.04, 0.12), P.mat("e8c06a"), Vector3(0, 0.05, 0.42), false))
			_fold(gl)
			var tw := o.create_tween()
			tw.tween_interval(1.6)
			tw.tween_callback(func(): _spread(gl); Sounds.gull_cry(game, 0.8))
			tw.tween_property(o, "position", o.position + side * 6.0 + Vector3(0, 5.0, 0), 1.6)
		"spray":
			prop.life = 20.0
			game.effects.splash(at + f * 1.2 + Vector3(0, 0.6, 0))
			game.effects.splash(at + Vector3(0, 1.2, 0))
			Sounds.spray(game, 1.0)
			var m := P.unique_mat("6f8fa8")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.45
			var pd := P.mi(P.cyl(0.8, 0.8, 0.01, 20), m, Vector3(0, -0.27, 0), false)
			prop.add_child(pd)
		"basket":
			prop.life = 40.0
			var hang := side * 0.9 + Vector3(0, 0.15, 0)
			var wicker := P.wood("b88a52")
			prop.add_child(P.mi(P.cyl(0.24, 0.18, 0.3, 10), wicker, hang, false))
			prop.add_child(P.mi(P.box(0.32, 0.05, 0.2), P.mat("f2ece2"), hang + Vector3(0, 0.12, 0), false))
			prop.add_child(P.mi(P.cyl(0.012, 0.012, 9.0, 4), P.mat("d8d0c0"), hang + Vector3(0, 4.65, 0), false))
			prop.add_child(P.mi(P.box(0.5, 0.025, 0.025), wicker, hang + Vector3(0, 0.25, 0), false))

func _flags() -> Dictionary: return game.state.flags if game != null and game.get("state") != null else {}

func _lantern_def() -> Dictionary:
	for b in Data.layout.get("buildings", []):
		if String(b.id) == "port_lantern": return b
	return {}

func _build_lantern() -> void:
	var b := _lantern_def()
	lantern = village.objects.get("port_lantern") if village.get("objects") != null else null
	if b.is_empty() or lantern == null: return
	var glass := P.unique_mat("8fb3c4", "fff1b8", 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.75, 0.9, 1.0, 0.4)
	for pn in Landmarks.lantern_panes(b):
		if not pn.broken: continue
		var w: float = pn.w
		var d: float = pn.d
		var m := P.mi(P.box(w * 0.96, 1.3, d * 0.96), glass, (pn.c as Vector3) + Vector3(0, 1.65, 0), false)
		m.name = "port_new_pane%d" % panes.size()
		lantern.add_child(m)
		panes.append(m)
	var lens: Node3D = lantern.get_node_or_null("lens")
	if lens != null and lens.get_child_count() > 1:
		lens_mat = (lens.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D
	beam = Node3D.new()
	beam.name = "port_beam"
	beam.position = Vector3(0, 1.4, 0)
	lantern.add_child(beam)
	var bm := P.glow_mat(Color(1.0, 0.96, 0.78), 0.3)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.rotation.y = side * BEAM_SPLIT * 0.5
		beam.add_child(arm)
		var ray := P.mi(P.cyl(0.3, 3.2, 44.0, 12), bm, Vector3(0, 0, 22.4), false)
		ray.rotation.x = PI / 2.0
		arm.add_child(ray)
	beam_light = OmniLight3D.new()
	beam_light.name = "port_beam_light"
	beam_light.position = Vector3(0, 1.4, 0)
	beam_light.omni_range = 22.0
	beam_light.light_color = Color("ffe9a8")
	beam_light.light_energy = 1.6
	lantern.add_child(beam_light)

func _line(i: int) -> Array: return Data.layout.get("port_lines", [])[i]

func _build_washing() -> void:
	var lines: Array = Data.layout.get("port_lines", [])
	for w in WASHING:
		for li in WASHING[w]:
			if int(li) >= lines.size(): continue
			var group := Node3D.new()
			group.name = "port_washing_%d" % int(li)
			group.visible = false
			add_child(group)
			washing[int(li)] = group
			_hang(group, lines[int(li)], int(li), String(w) if li == WASHING[w][0] else "")

func _hang(group: Node3D, l: Array, li: int, special: String) -> void:
	var a := Vector3(float(l[0]), float(l[4]), float(l[1]))
	var c := Vector3(float(l[2]), float(l[4]), float(l[3]))
	var length := a.distance_to(c)
	var along := (c - a).normalized()
	var count := maxi(2, int(length / 1.05))
	for k in count:
		var u := (k + 0.5) / count
		var p := a.lerp(c, u) + Vector3(0, -0.25 * (1.0 - absf(u - 0.5) * 2.0) - 0.03, 0)
		var piece := Node3D.new()
		piece.position = p
		piece.basis = Basis(Vector3.UP, atan2(along.x, along.z) + PI / 2.0)
		piece.set_meta("ph", li * 1.7 + k * 0.9)
		group.add_child(piece)
		var kind: String = special if (special != "" and k == count / 2) else ["sheet", "shirt", "towel", "shirt", "sheet", "socks"][(li * 3 + k) % 6]
		_garment(piece, kind, CLOTHS[(li * 5 + k * 3) % CLOTHS.size()])

func _cloth(parent: Node3D, w: float, h: float, col: String, x: float = 0.0) -> void:
	parent.add_child(P.mi(P.box(w, h, 0.02), P.mat(col), Vector3(x, -h / 2.0, 0), false))

func _garment(piece: Node3D, kind: String, col: String) -> void:
	match kind:
		"sheet": _cloth(piece, 0.9, 1.15, col)
		"towel": _cloth(piece, 0.5, 0.75, col)
		"socks":
			_cloth(piece, 0.12, 0.32, col, -0.12)
			_cloth(piece, 0.12, 0.32, col, 0.12)
		"shirt":
			_cloth(piece, 0.5, 0.62, col)
			for s in [-1.0, 1.0]: piece.add_child(P.mi(P.box(0.18, 0.3, 0.02), P.mat(col), Vector3(s * 0.32, -0.16, 0), false))
		"tablecloth":
			_cloth(piece, 1.3, 1.0, "fbf8ef")
			for k in 6: piece.add_child(P.mi(P.box(0.13, 0.13, 0.025), P.mat("f2d04a"), Vector3(-0.45 + (k % 3) * 0.45, -0.3 - (k / 3) * 0.42, 0), false))
		"longjohns":
			_cloth(piece, 0.5, 0.45, "efe4cf")
			for s in [-1.0, 1.0]: piece.add_child(P.mi(P.box(0.2, 0.75, 0.02), P.mat("efe4cf"), Vector3(s * 0.14, -0.8, 0), false))
		"apron":
			_cloth(piece, 0.55, 0.8, "faf6ec")
			piece.add_child(P.mi(P.box(0.6, 0.04, 0.025), P.mat("d9cdb8"), Vector3(0, -0.3, 0), false))
		"gloves":
			for s in [-1.0, 1.0]:
				piece.add_child(P.mi(P.box(0.14, 0.2, 0.03), P.mat("ffffff"), Vector3(s * 0.12, -0.12, 0), false))
		_: _cloth(piece, 0.5, 0.6, col)

func _build_pergola() -> void:
	pergola = Node3D.new()
	pergola.name = "port_pergola"
	pergola.visible = false
	add_child(pergola)
	var y := 27.5
	var wood := P.wood("8a6440")
	for x in [31.5, 33.9]:
		pergola.add_child(P.mi(P.box(0.12, 2.3, 0.12), wood, Vector3(x, y + 1.15, -5.3)))
	for x in [31.5, 33.9]:
		pergola.add_child(P.mi(P.box(0.1, 0.1, 2.8), wood, Vector3(x, y + 2.32, -6.6)))
	for k in 6:
		pergola.add_child(P.mi(P.box(2.7, 0.06, 0.08), wood, Vector3(32.7, y + 2.4, -5.4 - k * 0.5)))
	var leaf := Props.leaf_mat(Color("3f6a2a"))
	for k in 14:
		var lx := 31.4 + fmod(k * 1.37, 2.6)
		var lz := -5.3 - fmod(k * 0.83, 2.6)
		var blob := P.mi(P.sphere(0.32 + fmod(k * 0.31, 0.15), 8, 6), leaf, Vector3(lx, y + 2.5, lz), false)
		blob.scale = Vector3(1.0, 0.45, 1.0)
		pergola.add_child(blob)
	for k in 4:
		pergola.add_child(P.mi(P.sphere(0.09, 6, 5), P.mat("5a3a6a"), Vector3(31.8 + k * 0.6, y + 2.2, -5.9 - (k % 2) * 0.9), false))
	for x in [31.5, 33.9]:
		var vine := P.mi(P.cyl(0.035, 0.05, 2.3, 5), P.wood("6a4a2a"), Vector3(x + 0.1, y + 1.15, -5.2), false)
		pergola.add_child(vine)

func _build_note() -> void:
	note = Node3D.new()
	note.name = "port_framed_note"
	note.visible = false
	add_child(note)
	var at := Vector3(35.7, 27.5 + 1.55, -13.62)
	note.add_child(P.mi(P.box(0.62, 0.4, 0.04), P.wood("4a3424"), at, false))
	note.add_child(P.mi(P.box(0.5, 0.28, 0.045), P.mat("d9a3b2"), at + Vector3(0, 0, 0.005), false))
	note.add_child(P.mi(P.box(0.14, 0.18, 0.05), P.mat("b07a8c"), at + Vector3(-0.13, 0, 0.006), false))

func _gull_mesh() -> Dictionary:
	var o := Node3D.new()
	add_child(o)
	var body := P.mi(P.sphere(0.16, 10, 8), P.mat("f4f4f0"), Vector3.ZERO, false)
	body.scale = Vector3(0.7, 0.62, 1.55)
	o.add_child(body)
	o.add_child(P.mi(P.sphere(0.09, 8, 6), P.mat("f8f8f4"), Vector3(0, 0.07, 0.23), false))
	o.add_child(P.mi(P.box(0.03, 0.03, 0.09), P.mat("e8b83a"), Vector3(0, 0.05, 0.34), false))
	o.add_child(P.mi(P.box(0.1, 0.02, 0.12), P.mat("9aa3ab"), Vector3(0, 0.04, -0.24), false))
	var wings: Array = []
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(s * 0.08, 0.05, 0)
		o.add_child(w)
		w.add_child(P.mi(P.box(0.5, 0.016, 0.16), P.mat("a9b2ba"), Vector3(s * 0.26, 0, 0), false))
		w.add_child(P.mi(P.box(0.12, 0.017, 0.12), P.mat("2b2b30"), Vector3(s * 0.56, 0, -0.01), false))
		wings.append(w)
	return {"obj": o, "wings": wings}

func _build_gulls() -> void:
	for i in GULL_RINGS.size() + 3:
		var ring: Array = GULL_RINGS[i % GULL_RINGS.size()]
		var gl := _gull_mesh()
		gl["c"] = ring[0]
		gl["r"] = float(ring[1]) + (i / GULL_RINGS.size()) * 4.0
		gl["h"] = float(ring[2]) + (i / GULL_RINGS.size()) * 2.5
		gl["w"] = (0.16 + 0.03 * (i % 4)) * (1.0 if i % 2 == 0 else -1.0)
		gl["ph"] = i * 2.3
		(gl.obj as Node3D).scale = Vector3.ONE * 1.5
		circling.append(gl)
	var spots: Array = []
	for pr in Data.layout.get("props", []):
		if String(pr.kind) == "port_bollard" and spots.size() < 6 and int(String(pr.id).trim_prefix("port_bollard")) % 2 == 0:
			spots.append(Vector3(float(pr.x), QUAY_H + 0.62, float(pr.z)))
	spots.append(Vector3(43.5, QUAY_H + 0.55, 25.5))
	for i in spots.size():
		var gl := _gull_mesh()
		gl["home"] = spots[i]
		gl["state"] = "perched"
		gl["ph"] = i * 1.9
		gl["away"] = 0.0
		(gl.obj as Node3D).position = spots[i]
		(gl.obj as Node3D).rotation.y = i * 1.3
		(gl.obj as Node3D).scale = Vector3.ONE * 1.25
		_fold(gl)
		perched.append(gl)

func _fold(gl: Dictionary) -> void:
	for k in 2:
		var w: Node3D = gl.wings[k]
		w.rotation = Vector3(0, (1.0 if k == 0 else -1.0) * 1.2, (1.0 if k == 0 else -1.0) * -0.2)
		w.scale = Vector3(0.55, 1.0, 1.0)

func _spread(gl: Dictionary) -> void:
	for k in 2:
		var w: Node3D = gl.wings[k]
		w.rotation.y = 0.0
		w.scale = Vector3.ONE

func _build_pigeons() -> void:
	var grey := P.mat("8a8f98")
	var neck := P.mat("6a8a7a")
	for f in 2:
		var flock := {"spot": f, "state": "ground", "t": 0.0, "birds": []}
		for k in 9:
			var o := Node3D.new()
			add_child(o)
			var body := P.mi(P.sphere(0.1, 8, 6), grey, Vector3(0, 0.1, 0), false)
			body.scale = Vector3(0.8, 0.75, 1.3)
			o.add_child(body)
			o.add_child(P.mi(P.sphere(0.06, 6, 5), neck, Vector3(0, 0.18, 0.09), false))
			o.add_child(P.mi(P.box(0.015, 0.015, 0.04), P.mat("2a2a2a"), Vector3(0, 0.18, 0.15), false))
			var off := Vector2(cos(k * 2.4) * (0.4 + k * 0.18), sin(k * 2.4) * (0.4 + k * 0.18))
			flock.birds.append({"obj": o, "off": off, "ph": k * 0.7 + f})
		pigeons.append(flock)
		_land(flock, f)

func _land(flock: Dictionary, spot: int) -> void:
	flock.spot = spot
	flock.state = "ground"
	var at: Vector2 = PIGEON_SPOTS[spot]
	for b in flock.birds:
		var p: Vector2 = at + (b.off as Vector2)
		(b.obj as Node3D).position = Vector3(p.x, Heightfield.height(p.x, p.y), p.y)

func _build_boats() -> void:
	for i in 3:
		var o := Node3D.new()
		o.name = "port_night_boat%d" % i
		add_child(o)
		o.add_child(P.mi(P.box(1.4, 0.45, 4.2), P.wood(["2f5a7a", "f2efe6", "c8302c"][i]), Vector3(0, 0.1, 0), false))
		o.add_child(P.mi(P.cyl(0.04, 0.05, 2.2, 5), P.mat("3a3a3a"), Vector3(0, 1.3, 1.6), false))
		var lamp := P.mi(P.sphere(0.22, 8, 6), P.glow_mat(Color("fff1b8")), Vector3(0, 2.4, 1.9), false)
		o.add_child(lamp)
		var li := OmniLight3D.new()
		li.position = Vector3(0, 2.2, 2.0)
		li.omni_range = 7.0
		li.light_color = Color("ffe2a0")
		li.light_energy = 1.4
		o.add_child(li)
		o.visible = false
		boats.append({"obj": o, "ph": i * TAU / 3.0})

func _build_port_lights() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = P.box(0.6, 0.6, 0.6)
	mm.instance_count = PORT_LIGHTS
	for i in PORT_LIGHTS:
		var x: float
		var z: float
		var y: float
		if i < 60:
			x = -170.0 - fmod(i * 7.3, 12.0)
			z = -150.0 + i * 4.9
			y = 3.0 + fmod(i * 1.7, 4.0)
		else:
			var k := i - 60
			x = -270.0 - fmod(k * 13.7, 160.0)
			z = -140.0 + fmod(k * 29.3, 270.0)
			y = 6.0 + (absf(x) - 270.0) * 0.45 + fmod(k * 3.1, 8.0)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, y, z)))
	port_lights = MultiMeshInstance3D.new()
	port_lights.name = "port_far_lights"
	port_lights.multimesh = mm
	port_lights.material_override = P.glow_mat(Color("ffd890"))
	port_lights.visible = false
	add_child(port_lights)

func _build_fluff() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color("f2d64b")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = mat
	for pr in Data.layout.get("props", []):
		if String(pr.kind) != "port_mimosa": continue
		var fx := CPUParticles3D.new()
		fx.name = String(pr.id) + "_fluff"
		fx.mesh = quad
		fx.amount = 8
		fx.lifetime = 7.0
		fx.preprocess = 7.0
		fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fx.emission_box_extents = Vector3(1.4, 0.6, 1.4)
		fx.direction = Vector3(1.0, -0.2, 0.3)
		fx.spread = 60.0
		fx.initial_velocity_min = 0.2
		fx.initial_velocity_max = 0.6
		fx.gravity = Vector3(0.15, -0.22, 0.05)
		fx.position = Vector3(float(pr.x), Heightfield.height(float(pr.x), float(pr.z)) + 3.2, float(pr.z))
		add_child(fx)

func _update_story(flags: Dictionary) -> void:
	var st := lantern_state(flags)
	for m in panes: (m as Node3D).visible = st.glazed
	if lens_mat != null: lens_mat.emission_energy_multiplier = (2.8 + sin(t * 3.0) * 0.25) if st.lit else 0.0
	if beam != null: beam.visible = st.beam
	if beam_light != null: beam_light.visible = st.beam
	var up := washing_up(flags)
	for li in washing: (washing[li] as Node3D).visible = up.has(li)
	if pergola != null: pergola.visible = flags.get("port_pergola", false)
	if note != null: note.visible = flags.get("port_euro_only", false)
	if port_lights != null: port_lights.visible = flags.get("night", false)
	var out := boats_out(flags)
	for b in boats: (b.obj as Node3D).visible = out

func _process(dt: float) -> void:
	if game == null or game.get("state") == null or game.get("traveling"): return
	t += dt
	var flags: Dictionary = game.state.flags
	_update_story(flags)
	if beam != null and beam.visible: beam.rotation.y = beam_angle(t)
	var wind := 1.0 + 0.6 * sin(t * 0.3)
	for li in washing:
		var g: Node3D = washing[li]
		if not g.visible: continue
		for piece in g.get_children():
			(piece as Node3D).rotation.x = sin(t * 1.9 + float(piece.get_meta("ph", 0.0))) * 0.14 * wind
	var pp: Vector3 = game.player.pos
	var pl := Vector2(pp.x, pp.z)
	_gulls(dt, pl)
	_pigeons(dt, pl)
	for b in boats:
		if not (b.obj as Node3D).visible: continue
		var a: float = float(b.ph) + t * 0.035
		var c: Vector2 = LAMPARA_RING[0]
		var r: float = LAMPARA_RING[1]
		(b.obj as Node3D).position = Vector3(c.x + cos(a) * r, -0.35 + sin(t * 1.1 + float(b.ph)) * 0.06, c.y + sin(a) * r * 0.5)
		(b.obj as Node3D).rotation.y = -a
	Sounds.tick(self, game, dt, pl, flags)

func _gulls(dt: float, pl: Vector2) -> void:
	for gl in circling:
		var a: float = float(gl.ph) + t * float(gl.w)
		var c: Vector2 = gl.c
		var o: Node3D = gl.obj
		o.position = Vector3(c.x + cos(a) * float(gl.r), float(gl.h) + sin(t * 0.5 + float(gl.ph)) * 0.9, c.y + sin(a) * float(gl.r))
		o.rotation.y = -a + (0.0 if float(gl.w) > 0.0 else PI)
		o.rotation.z = 0.28 * signf(float(gl.w))
		var flap := sin(t * 9.0 + float(gl.ph)) * 0.6 * maxf(0.0, sin(t * 0.6 + float(gl.ph)))
		for k in 2: (gl.wings[k] as Node3D).rotation.z = (1.0 if k == 0 else -1.0) * (0.15 + flap)
	for gl in perched:
		var o: Node3D = gl.obj
		var home: Vector3 = gl.home
		match String(gl.state):
			"perched":
				o.position = home + Vector3(0, absf(sin(t * 2.0 + float(gl.ph))) * 0.01, 0)
				if fmod(t + float(gl.ph), 6.0) < 0.4: o.rotation.y += dt * 2.0
				if gull_flees(Vector2(home.x, home.z), pl):
					gl.state = "flying"
					gl.away = 14.0 + fmod(float(gl.ph) * 3.0, 8.0)
					_spread(gl)
					Sounds.gull_cry(game, 0.5)
			"flying":
				gl.away = float(gl.away) - dt
				var a: float = float(gl.ph) + t * 0.5
				var lift := clampf(14.0 - float(gl.away), 0.0, 4.0) / 4.0
				var radius := 3.0 + lift * 5.0
				o.position = home + Vector3(cos(a) * radius, lift * 7.0 + 0.4, sin(a) * radius)
				o.rotation.y = -a
				for k in 2: (gl.wings[k] as Node3D).rotation.z = (1.0 if k == 0 else -1.0) * (0.2 + sin(t * 11.0 + float(gl.ph)) * 0.55)
				if float(gl.away) <= 0.0 and not gull_flees(Vector2(home.x, home.z), pl):
					gl.state = "perched"
					o.position = home
					_fold(gl)

func _pigeons(dt: float, pl: Vector2) -> void:
	for flock in pigeons:
		var at: Vector2 = PIGEON_SPOTS[int(flock.spot)]
		match String(flock.state):
			"ground":
				for b in flock.birds:
					var o: Node3D = b.obj
					var peck := sin(t * 5.0 + float(b.ph))
					o.rotation.x = maxf(0.0, peck) * 0.5
					o.rotation.y = float(b.ph) + sin(t * 0.4 + float(b.ph)) * 1.5
				if pigeons_flee(at, pl):
					flock.state = "flying"
					flock.t = 0.0
					flock.to = next_pigeon_spot(int(flock.spot), pl)
					Sounds.clatter(game, at.distance_to(pl))
			"flying":
				flock.t = float(flock.t) + dt
				var u := clampf(float(flock.t) / 3.0, 0.0, 1.0)
				var to: Vector2 = PIGEON_SPOTS[int(flock.to)]
				for b in flock.birds:
					var o: Node3D = b.obj
					var p: Vector2 = at.lerp(to, u) + (b.off as Vector2) * (1.0 + sin(u * PI))
					o.position = Vector3(p.x, Heightfield.height(p.x, p.y) + sin(u * PI) * 4.0, p.y)
					o.rotation.x = 0.0
				if u >= 1.0: _land(flock, int(flock.to))
