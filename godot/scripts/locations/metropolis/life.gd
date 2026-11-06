extends Node3D
## Toriano's animals, only for looking at (nothing blocks you):
## - pigeons by the hundred in the cathedral square, in flocks that peck about on their spot, clatter up when you
##   come close, wheel round and land on the free spot farthest from you;
## - ducks paddling round the park pond;
## - gulls wheeling over the Darsena, crying now and then.
## And the city's sounds: the cathedral striking the hour, a big peal when the Golden Angel lights up on Christmas
## Eve, and a horn somewhere in the traffic now and then.
## The cats in number 14's courtyard are the shared wildlife (the layout's "wildlife"). The decisions are pure
## static functions (tested in test_metropolis.gd); the pigeons are drawn with MultiMeshes, a few draw calls for all.

const P := preload("res://scripts/world/palette.gd")
const Kit := preload("res://scripts/locations/metropolis/kit.gd")

## Where the pigeons gather in the cathedral square (clear of the Christmas tree and the tram stop).
const PIGEON_SPOTS := [Vector2(-32, -17), Vector2(-8, -20), Vector2(5, 6), Vector2(-31, 10), Vector2(-12, 12), Vector2(9, -13), Vector2(-2, -5)]
const FLOCKS := 4
const PIGEONS := 25           # per flock: a hundred in all
const SHY := 5.0              # how close you can come before a flock takes off
const FLIGHT := 9.0           # seconds a flock wheels round before it lands
const POND := Vector2(-120, -126)
const DARSENA := Vector2(-150, 108)

var game
var t := 0.0
var flocks: Array = []
var ducks: Array = []
var gulls: Array = []
var coo_t := 3.0
var cry_t := 6.0
var horn_t := 20.0
var last_hour := -1
var pealed := false
const DUOMO := Vector2(45, 8)

# ---- Decisions (pure) ---------------------------------------------------------------------------------------

## Does a flock gathered at `at` take off with you at `player`?
static func startled(at: Vector2, player: Vector2, shy: float = SHY) -> bool: return at.distance_to(player) < shy

## Where a startled flock lands: the free spot farthest from you (`taken`: the other flocks' spots; never `from`).
static func landing(spots: Array, taken: Array, player: Vector2, from: Vector2) -> Vector2:
	var best := from; var bd := -1.0
	for s in spots:
		if s == from or taken.has(s): continue
		var d: float = (s as Vector2).distance_to(player)
		if d > bd: bd = d; best = s
	return best

## Where a bird of a wheeling flock is, `k` of the way (0..1) through its flight from `a` to `b`: round and up, then
## down onto its place (`off` from the flock's spot) at the end.
static func wheel(a: Vector2, b: Vector2, off: Vector2, ph: float, k: float) -> Vector3:
	var c := a.lerp(b, smoothstep(0.15, 0.9, k))
	var ang := ph + k * TAU * 1.4
	var rad := (3.0 + off.length()) * sin(minf(1.0, k * 1.1) * PI)
	var land := smoothstep(0.85, 1.0, k)
	var start := 1.0 - smoothstep(0.0, 0.12, k)   # (from its own place in the flock)
	var p := (c + Vector2(cos(ang), sin(ang)) * rad + off * start).lerp(b + off, land)
	return Vector3(p.x, sin(minf(1.0, k * 1.1) * PI) * 7.0, p.y)

# ---- Setup ---------------------------------------------------------------------------------------------------

func setup(v: Node3D) -> void:
	game = v.get_parent()
	name = "Life"
	var body := Kit.vc_mat()
	var pm := _pigeon_mesh(); var wr := _wing_mesh(1.0); var wl := _wing_mesh(-1.0)
	for f in FLOCKS:
		var flock := {"at": PIGEON_SPOTS[f], "state": "ground", "t": 0.0, "to": PIGEON_SPOTS[f], "calm": 0.0, "birds": []}
		for i in PIGEONS:
			var a := randf() * TAU; var r := 0.4 + sqrt(randf()) * 2.4
			flock.birds.append({"off": Vector2(cos(a), sin(a)) * r, "ph": randf() * TAU, "yaw": randf() * TAU})
		for part in [["mm", pm], ["wl", wl], ["wr", wr]]:
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[1]; mm.instance_count = PIGEONS
			var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = body
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)
			flock[part[0]] = mm
		flocks.append(flock)
	for i in 6: ducks.append(_duck(i))
	for i in 5: gulls.append(_gull(i))

## A pigeon, all in one mesh: a plump grey body, a darker head with a green sheen on the neck, a pale beak, a tail.
static func _pigeon_mesh() -> ArrayMesh:
	return _merge([
		[_sphere(0.11), Transform3D(Basis().scaled(Vector3(0.85, 0.75, 1.3)), Vector3(0, 0.13, 0)), Color("8d929c")],
		[_sphere(0.075), Transform3D(Basis(), Vector3(0, 0.2, 0.1)), Color("5f7a70")],
		[_sphere(0.062), Transform3D(Basis(), Vector3(0, 0.26, 0.13)), Color("6d7381")],
		[_cone(0.018, 0.05), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.255, 0.2)), Color("d9cdb4")],
		[_box(Vector3(0.09, 0.025, 0.14)), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.13, -0.16)), Color("5d6370")],
		[_box(Vector3(0.12, 0.03, 0.06)), Transform3D(Basis(), Vector3(0, 0.17, -0.02)), Color("767c88")],   # folded wingtips
		[_box(Vector3(0.016, 0.07, 0.016)), Transform3D(Basis(), Vector3(-0.03, 0.035, 0.01)), Color("c25a50")],
		[_box(Vector3(0.016, 0.07, 0.016)), Transform3D(Basis(), Vector3(0.03, 0.035, 0.01)), Color("c25a50")]])

## One wing, from the shoulder out to `side` (1 right, -1 left), a pale grey with two dark bars.
static func _wing_mesh(side: float) -> ArrayMesh:
	return _merge([
		[_box(Vector3(0.2, 0.012, 0.1)), Transform3D(Basis(), Vector3(side * 0.1, 0, 0)), Color("9aa0aa")],
		[_box(Vector3(0.06, 0.014, 0.09)), Transform3D(Basis(), Vector3(side * 0.18, 0, -0.005)), Color("4f5560")]])

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 8; s.rings = 5; return s
static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = sz; return b
static func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = r; c.height = h; c.radial_segments = 6; return c

## Primitive meshes [mesh, transform, colour] merged into one vertex-coloured surface.
static func _merge(parts: Array) -> ArrayMesh:
	var V := PackedVector3Array(); var N := PackedVector3Array(); var C := PackedColorArray(); var I := PackedInt32Array()
	for pt in parts:
		var arr: Array = (pt[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = pt[1]
		var nb := xf.basis.inverse().transposed()
		var base := V.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in v.size():
			V.append(xf * v[i]); N.append((nb * n[i]).normalized()); C.append(pt[2])
		for idx in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array): I.append(base + idx)
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = V; a[Mesh.ARRAY_NORMAL] = N; a[Mesh.ARRAY_COLOR] = C; a[Mesh.ARRAY_INDEX] = I
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return am

## A mallard: brown body, a green head on the drakes, a yellow bill.
func _duck(i: int) -> Dictionary:
	var o := Node3D.new(); add_child(o)
	var drake := i % 2 == 0
	var body := P.mi(P.sphere(0.16, 10, 8), P.mat("8a6a4a" if drake else "9a7a56"), Vector3(0, 0.08, 0), false); body.scale = Vector3(0.8, 0.6, 1.25); o.add_child(body)
	o.add_child(P.mi(P.sphere(0.085, 8, 6), P.mat("2f6a3a" if drake else "8a6a4a"), Vector3(0, 0.22, 0.13), false))
	var bill := P.mi(P.box(0.05, 0.02, 0.07), P.mat("e0b03a"), Vector3(0, 0.21, 0.22), false); o.add_child(bill)
	var tail := P.mi(P.box(0.08, 0.03, 0.06), P.mat("f2f2ec" if drake else "7a5a3a"), Vector3(0, 0.12, -0.2), false); o.add_child(tail)
	return {"obj": o, "r": 2.5 + i * 1.0, "w": (0.12 + 0.03 * (i % 3)) * (1.0 if i % 3 != 1 else -1.0), "ph": i * 1.7}

## A gull: white body, grey wings held out in a shallow V, black tips.
func _gull(i: int) -> Dictionary:
	var o := Node3D.new(); add_child(o)
	var body := P.mi(P.sphere(0.16, 10, 8), P.mat("f2f2ee"), Vector3.ZERO, false); body.scale = Vector3(0.7, 0.6, 1.6); o.add_child(body)
	o.add_child(P.mi(P.sphere(0.09, 8, 6), P.mat("f6f6f2"), Vector3(0, 0.05, 0.24), false))
	o.add_child(P.mi(P.box(0.03, 0.03, 0.08), P.mat("e3b23a"), Vector3(0, 0.04, 0.34), false))
	var wings: Array = []
	for s in [-1, 1]:
		var w := Node3D.new(); w.position = Vector3(s * 0.08, 0.04, 0); o.add_child(w)
		w.add_child(P.mi(P.box(0.55, 0.015, 0.16), P.mat("aab3bb"), Vector3(s * 0.28, 0, 0), false))
		w.add_child(P.mi(P.box(0.12, 0.016, 0.12), P.mat("2a2a2e"), Vector3(s * 0.6, 0, -0.01), false))
		wings.append(w)
	o.scale = Vector3.ONE * 1.6   # big birds, seen from below
	var over_canal := i >= 3
	return {"obj": o, "wings": wings, "c": (Vector2(-130, 152) if over_canal else DARSENA), "r": 9.0 + i * 3.0, "h": 7.0 + i * 1.0, "w": 0.22 + 0.04 * i, "ph": i * 2.1}

# ---- Every frame ---------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if game == null or game.get("player") == null or game.get("traveling"): return
	t += dt
	var pp: Vector3 = game.player.pos
	var pl := Vector2(pp.x, pp.z)
	for f in flocks: _flock(f, dt, pl)
	for d in ducks:
		var a: float = d.ph + t * float(d.w)
		var o: Node3D = d.obj
		o.position = Vector3(POND.x + cos(a) * float(d.r), 0.1 + sin(t * 1.3 + float(d.ph)) * 0.015, POND.y + sin(a) * float(d.r))
		o.rotation.y = -a + (PI if float(d.w) > 0.0 else 0.0)
	for g in gulls:
		var a: float = g.ph + t * float(g.w)
		var c: Vector2 = g.c
		var o: Node3D = g.obj
		o.position = Vector3(c.x + cos(a) * float(g.r), float(g.h) + sin(t * 0.5 + float(g.ph)) * 0.8, c.y + sin(a) * float(g.r))
		o.rotation.y = -a
		o.rotation.z = 0.25   # banking into the turn
		var flap := sin(t * 9.0 + float(g.ph)) * 0.6 * maxf(0.0, sin(t * 0.7 + float(g.ph)))   # glide, a few beats now and then
		for k in 2: (g.wings[k] as Node3D).rotation.z = (1 if k == 0 else -1) * (0.18 + flap)
	_sounds(dt, pl)

func _flock(f: Dictionary, dt: float, pl: Vector2) -> void:
	f.calm = maxf(0.0, f.calm - dt)
	var mm: MultiMesh = f.mm; var wl: MultiMesh = f.wl; var wr: MultiMesh = f.wr
	var hidden := Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0))
	if f.state == "ground":
		for i in f.birds.size():
			var b: Dictionary = f.birds[i]
			var ph: float = b.ph
			var wander := Vector2(sin(t * 0.21 + ph), cos(t * 0.17 + ph * 1.3)) * 0.35
			var s: Vector2 = f.at + b.off + wander
			var peck := pow(maxf(0.0, sin(t * 2.6 + ph * 5.0)), 6.0) * 0.6   # dips its head to the ground now and then
			var yaw: float = b.yaw + sin(t * 0.3 + ph) * 0.9
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, peck), Vector3(s.x, Heightfield.height(s.x, s.y), s.y)))
			wl.set_instance_transform(i, hidden); wr.set_instance_transform(i, hidden)
		if f.calm <= 0.0 and startled(f.at, pl):
			var others: Array = []
			for x in flocks:
				if x != f: others.append(x.at)
			f.to = landing(PIGEON_SPOTS, others, pl, f.at); f.t = 0.0; f.state = "wheel"
			_clatter(Vector2(f.at).distance_to(pl))
	else:
		f.t += dt
		var k := clampf(f.t / FLIGHT, 0.0, 1.0)
		for i in f.birds.size():
			var b: Dictionary = f.birds[i]
			var p := wheel(f.at, f.to, b.off, b.ph, k)
			var q := wheel(f.at, f.to, b.off, b.ph, minf(1.0, k + 0.01))
			var dir := Vector2(q.x - p.x, q.z - p.z)
			var yaw := atan2(dir.x, dir.y) if dir.length() > 0.0001 else float(b.yaw)
			b.yaw = yaw
			var pos := Vector3(p.x, Heightfield.height(p.x, p.z) + p.y, p.z)
			var bx := Transform3D(Basis(Vector3.UP, yaw), pos)
			mm.set_instance_transform(i, bx)
			var beat := sin(t * 16.0 + float(b.ph)) * 0.9 * (1.0 - smoothstep(0.9, 1.0, k))
			wr.set_instance_transform(i, bx * Transform3D(Basis(Vector3.FORWARD, -beat), Vector3(0.05, 0.16, 0.02)))
			wl.set_instance_transform(i, bx * Transform3D(Basis(Vector3.FORWARD, beat), Vector3(-0.05, 0.16, 0.02)))
		if k >= 1.0:
			f.at = f.to; f.state = "ground"; f.calm = 6.0
			for b in f.birds: b.yaw = randf() * TAU

# ---- Sounds ---------------------------------------------------------------------------------------------------

func _play(kind: String, note: int, vol: float, delay: float = 0.0) -> void:
	if game.get("audio") == null or vol <= 0.01: return
	game.audio.play(kind, note, vol, -1, delay)

## A flock clattering up: a burst of wing claps, quieter far off.
func _clatter(d: float) -> void:
	var vol := clampf(1.0 - d / 30.0, 0.0, 1.0) * 0.16
	for i in 7: _play("thud", 52 + (i * 5) % 9, vol, i * 0.045)

## How many times the cathedral strikes at the start of an hour (0 at night: it keeps quiet from 22:00 to 7:00).
static func strikes(hour: int) -> int:
	if hour < 7 or hour >= 22: return 0
	return 12 if hour % 12 == 0 else hour % 12

## Pigeons cooing near a flock on the ground, gulls crying near the water; the cathedral's bells; the traffic.
func _sounds(dt: float, pl: Vector2) -> void:
	var hour := int(float(game.state.time.minute) / 60.0)
	if hour != last_hour:
		if last_hour != -1:   # (not on arrival)
			var n := strikes(hour)
			var vol := maxf(0.08, clampf(1.0 - pl.distance_to(DUOMO) / 160.0, 0.0, 1.0) * 0.3)   # the bells carry across the city
			for i in n: _play("bell", 50, vol, i * 1.5)
		last_hour = hour
	if game.state.flags.get("metropolis_angel_on", false) and not pealed:
		pealed = true
		for i in 20: _play("bell", [64, 60, 57, 52][i % 4], 0.26, i * 0.5)   # every bell in the Duomo, for the angel
	horn_t -= dt
	if horn_t < 0.0:
		var night := Daylight.nightness(float(game.state.time.minute) / 60.0) > 0.5
		horn_t = (40.0 if night else 14.0) + randf() * 25.0
		var vol := 0.03 + randf() * 0.025
		_play("horn", 62, vol); _play("horn", 66, vol)
		if randf() < 0.4: _play("horn", 62, vol, 0.25); _play("horn", 66, vol, 0.25)
	coo_t -= dt; cry_t -= dt
	if coo_t < 0.0:
		coo_t = 2.0 + randf() * 4.0
		var near := INF
		for f in flocks:
			if f.state == "ground": near = minf(near, Vector2(f.at).distance_to(pl))
		var vol := clampf(1.0 - near / 22.0, 0.0, 1.0) * 0.07
		_play("flute", 55, vol); _play("flute", 52, vol, 0.28); _play("flute", 52, vol * 0.8, 0.55)   # roo-coo-coo
	if cry_t < 0.0:
		cry_t = 5.0 + randf() * 9.0
		var vol := clampf(1.0 - pl.distance_to(DARSENA) / 60.0, 0.0, 1.0) * 0.09
		for i in 3: _play("whistle", 86 - i, vol, i * 0.2)
