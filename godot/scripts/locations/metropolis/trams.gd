extends Node3D
## Toriano's trams: old orange cars running round the loop line, slowing into each stop and waiting there a few
## seconds, and holding back while someone stands on the track ahead. They are solid (moving bodies in the walk
## world). Riding is the shared stop feature (Travel.stops_on, game.ride_to); these are the cars you see.
## On Christmas Eve, Ambrogio's last run: his tram (number 1528, the first) goes round strung with Christmas lights
## after dark, ringing its bell as it passes you.
## The traffic shares their street, as it does in a real city: small cars driving round the loop on the tracks,
## queueing behind each other and behind a tram at its stop, waiting (with a toot) for anyone in the road.

const Kit := preload("res://scripts/locations/metropolis/kit.gd")

const SPEED := 7.0
const CAR_SPEED := 8.0
const DWELL := 6.0
const GAP := 3.0           # what a vehicle keeps between itself and the one ahead
const CAR_COLOURS := ["c23a32", "e8e2d0", "2f5a8a", "3f6a4a", "d9a43a", "5a5a62", "7a2f35"]
const CORNER := 9.0        # radius the rails take round each corner
const ORANGE := Color("e8892c")
const CREAM := Color("efe2c4")
const GREY := Color("6e6a64")

var game
var path := PackedVector2Array()   # the line, sampled every metre or so, closed
var dist := PackedFloat32Array()   # distance along the line at each sample
var length := 0.0
var stops: Array = []               # distances along the line where trams stop
var cars: Array = []                # trams and cars: {node, s, wait, bodies, tram, half, toot}
var festive: MeshInstance3D         # the Christmas lights on Ambrogio's tram
var festive_mat: StandardMaterial3D
var bell_t := 0.0
var t := 0.0

## The loop's corners, rounded; returns the sampled closed path.
static func rounded(corners: Array, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := corners.size()
	for i in n:
		var p0: Vector2 = corners[(i - 1 + n) % n]; var p1: Vector2 = corners[i]; var p2: Vector2 = corners[(i + 1) % n]
		var a := (p0 - p1).normalized(); var b := (p2 - p1).normalized()
		var s := p1 + a * radius; var e := p1 + b * radius
		for k in 9:   # a quarter circle approximated by a bezier through the corner
			var t := k / 8.0
			out.append(s.lerp(p1, t).lerp(p1.lerp(e, t), t))
		var nxt: Vector2 = corners[(i + 1) % n]
		var after := nxt + (p1 - nxt).normalized() * radius
		var seg := e.distance_to(after)
		for k in range(1, int(seg / 2.0)):
			out.append(e.lerp(after, k * 2.0 / seg))
	return out

## How far a vehicle at `s` (half its length `half`) can go before it's GAP behind the next one round the loop;
## `others` are [s, half] of the rest. INF when it's alone.
static func room_ahead(s: float, half: float, others: Array, length: float) -> float:
	var best := INF
	for o in others:
		var d := fposmod(float(o[0]) - s, length)
		if d <= 0.001: continue
		best = minf(best, d - half - float(o[1]) - GAP)
	return best

func setup(g, corners: Array, stop_points: Array, count: int = 3, autos: int = 0) -> void:
	game = g
	name = "Trams"
	path = rounded(corners, CORNER)
	dist.resize(path.size())
	length = 0.0
	for i in path.size():
		dist[i] = length
		length += path[i].distance_to(path[(i + 1) % path.size()])
	for sp in stop_points: stops.append(nearest_s(sp))
	stops.sort()
	for i in count + autos:
		var tram := i < count
		var node := model(i == 0) if tram else car_model(i)
		add_child(node)
		# trams evenly round the line, the cars in the gaps between them
		var s0 := length * i / count if tram else length * (float(i - count) + 0.5) / maxf(1.0, autos)
		var car := {"node": node, "s": s0, "wait": 0.0, "bodies": [], "tram": tram, "half": 6.0 if tram else 2.1, "toot": 0.0}
		for k in (3 if tram else 2):
			var body := {"x": 0.0, "z": 0.0, "r": 1.35 if tram else 1.0}
			car.bodies.append(body)
			if game and game.walk: game.walk.dynamic.append(body)
		cars.append(car)
		_place(car)
		if i == 0: _string_lights(node)

## Distance along the line of the point nearest to p.
func nearest_s(p: Vector2) -> float:
	var best := 0.0; var bd := INF
	for i in path.size():
		var d := path[i].distance_to(p)
		if d < bd: bd = d; best = dist[i]
	return best

## The point and direction on the line at distance s.
func at(s: float) -> Array:
	s = fposmod(s, length)
	var i := dist.bsearch(s) - 1
	i = clampi(i, 0, path.size() - 1)
	var j := (i + 1) % path.size()
	var seg := path[i].distance_to(path[j])
	var t := 0.0 if seg < 0.001 else (s - dist[i]) / seg
	return [path[i].lerp(path[j], t), (path[j] - path[i]).normalized()]

func _place(car: Dictionary) -> void:
	var p: Array = at(car.s)
	var pos: Vector2 = p[0]; var dir: Vector2 = p[1]
	var n: Node3D = car.node
	n.position = Vector3(pos.x, 0.3, pos.y)
	n.rotation.y = atan2(-dir.y, dir.x)
	var n_b: int = car.bodies.size()
	for k in n_b:   # round bodies along the car, for collisions
		var q: Vector2 = pos + dir * (k - (n_b - 1) / 2.0) * (4.2 if car.tram else 1.3)
		car.bodies[k].x = q.x; car.bodies[k].z = q.y

## Christmas lights along the roof of Ambrogio's tram, hidden until Christmas Eve.
func _string_lights(node: Node3D) -> void:
	var m := Kit.Merge.new()
	var cols := [Color("ffd27a"), Color("ff5a4a"), Color("6ab0ff"), Color("ffffff")]
	for sd in [-1, 1]:
		for k in 24:
			m.box(Vector3(-5.8 + k * 0.5, 3.42 - 0.1 * sin(k * 0.8) * 0.0, sd * 1.22), Vector3(0.1, 0.1, 0.1), cols[k % 4])
	festive_mat = Kit.vc_mat().duplicate() as StandardMaterial3D
	festive_mat.emission_enabled = true; festive_mat.emission = Color(1, 0.86, 0.62); festive_mat.emission_energy_multiplier = 2.0
	festive = m.node(festive_mat, "christmas_lights"); festive.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	festive.visible = false
	node.add_child(festive)

func _process(dt: float) -> void:
	if game == null or length <= 0.0: return
	t += dt
	_last_run(dt)
	var pl := Vector2(game.player.pos.x, game.player.pos.z) if game.player else Vector2(1e9, 1e9)
	for car in cars:
		if car.wait > 0.0: car.wait -= dt; continue
		var p: Array = at(car.s + float(car.half) + 1.0)   # just ahead of the front
		var ahead: Vector2 = p[0]
		if pl.distance_to(ahead) < 3.2:   # someone on the track: wait for them (a car toots once)
			car.toot += dt
			if not car.tram and car.toot > 1.5 and car.toot - dt <= 1.5: _toot(pl.distance_to(ahead))
			continue
		car.toot = 0.0
		var others: Array = []
		for o in cars:
			if o != car: others.append([o.s, o.half])
		var room := room_ahead(car.s, car.half, others, length)
		if room <= 0.0: continue   # queueing behind the one ahead
		var step := minf((SPEED if car.tram else CAR_SPEED) * dt, room)
		if car.tram:
			for st in stops:   # slow into a stop, then wait
				var gap := fposmod(st - car.s, length)
				if gap > 0.0 and gap <= step: car.s = st; car.wait = DWELL; step = 0.0; break
				if gap < 10.0: step *= clampf(gap / 10.0, 0.25, 1.0)
		else: step *= clampf(room / 6.0, 0.3, 1.0)   # easing up behind the one ahead
		car.s = fposmod(car.s + step, length)
		_place(car)

func _toot(d: float) -> void:
	if game.get("audio") == null: return
	var vol := clampf(1.0 - d / 25.0, 0.2, 1.0) * 0.12
	game.audio.play("horn", 64, vol); game.audio.play("horn", 68, vol)
	game.audio.play("horn", 64, vol, -1, 0.22); game.audio.play("horn", 68, vol, -1, 0.22)

## A small city car, along x: a rounded body in one of the city's colours, a glasshouse with dark windows, black
## wheels, pale headlamps at the front (+x) and red lamps at the back.
static func car_model(i: int) -> Node3D:
	var g := Node3D.new(); g.name = "Car"
	var m := Kit.Merge.new()
	var col := Color(CAR_COLOURS[i % CAR_COLOURS.size()])
	m.box(Vector3(0, 0.62, 0), Vector3(3.8, 0.62, 1.66), col)
	m.box(Vector3(-0.25, 1.18, 0), Vector3(2.0, 0.55, 1.5), col.lightened(0.04))
	for sd in [-1, 1]:
		m.box(Vector3(-0.25, 1.2, sd * 0.76), Vector3(1.7, 0.4, 0.02), Color("2c3a44"))
		for x in [-1.2, 1.2]: m.box(Vector3(x, 0.32, sd * 0.78), Vector3(0.62, 0.62, 0.2), Color("1d1d1d"))
	m.box(Vector3(0.76, 1.2, 0), Vector3(0.02, 0.42, 1.36), Color("2c3a44"))     # windscreen
	m.box(Vector3(-1.27, 1.2, 0), Vector3(0.02, 0.4, 1.3), Color("2c3a44"))
	for sd in [-1, 1]:
		m.box(Vector3(1.91, 0.7, sd * 0.6), Vector3(0.03, 0.16, 0.3), Color("fff2c8"))
		m.box(Vector3(-1.91, 0.75, sd * 0.62), Vector3(0.03, 0.14, 0.24), Color("c23a32"))
	m.box(Vector3(0, 0.36, 0), Vector3(3.84, 0.14, 1.7), Color("3a3a3a"))           # bumpers and sills
	g.add_child(m.node(Kit.vc_mat(), "body"))
	return g

## One tram: an orange car with a cream window band, a grey roof, a trolley pole, a round headlamp at each end and
## a destination board. The first car carries Ambrogio's: CIRCOLARE.
static func model(first: bool) -> Node3D:
	var g := Node3D.new(); g.name = "Tram"
	var m := Kit.Merge.new()
	var L := 12.0; var W := 2.4
	m.box(Vector3(0, 0.55, 0), Vector3(L - 1.0, 0.5, W - 0.3), Color("2b2826"))          # bogies and underframe
	m.box(Vector3(0, 1.6, 0), Vector3(L, 1.6, W), ORANGE)                                   # lower body
	m.box(Vector3(0, 2.75, 0), Vector3(L, 0.9, W - 0.04), CREAM)                             # window band
	for s in [-1, 1]:
		for i in 7:
			m.box(Vector3(-L / 2.0 + 1.0 + i * 1.65, 2.78, s * (W / 2.0 - 0.01)), Vector3(1.25, 0.7, 0.04), Color("2c3a44"))
	m.box(Vector3(0, 3.3, 0), Vector3(L - 0.2, 0.22, W - 0.1), ORANGE.darkened(0.08))
	m.box(Vector3(0, 3.5, 0), Vector3(L - 1.2, 0.2, W - 0.5), GREY)                          # roof
	m.box(Vector3(1.0, 3.75, 0), Vector3(0.5, 0.3, 0.5), Color("2b2826"))
	m.box(Vector3(-0.8, 4.6, 0), Vector3(3.6, 0.08, 0.08), Color("2b2826"), 0.0)            # trolley pole (laid back)
	for s in [-1, 1]:
		m.box(Vector3(s * (L / 2.0 + 0.02), 1.5, 0), Vector3(0.06, 0.3, 0.3), Color("fff2c8"))   # headlamps
		m.box(Vector3(s * (L / 2.0 + 0.02), 3.05, 0), Vector3(0.05, 0.36, 1.4), Color("1d1d1d"))  # destination board
	g.add_child(m.node(Kit.vc_mat(), "body"))
	for s in [-1, 1]:
		var lb := Label3D.new(); lb.text = "CIRCOLARE"; lb.font_size = 48; lb.pixel_size = 0.006; lb.modulate = Color("ffcf6a")
		lb.position = Vector3(s * (L / 2.0 + 0.06), 3.05, 0); lb.rotation.y = PI / 2.0 if s > 0 else -PI / 2.0
		g.add_child(lb)
	if first:
		var nm := Label3D.new(); nm.text = "1528"; nm.font_size = 40; nm.pixel_size = 0.008; nm.modulate = CREAM
		nm.position = Vector3(3.5, 1.4, W / 2.0 + 0.02); g.add_child(nm)
	return g

## Rails in the setts, and the overhead wire on poles beside the track.
static func line(corners: Array) -> MeshInstance3D:
	var p := rounded(corners, CORNER)
	var m := Kit.Merge.new()
	var steel := Color("5a5753")
	var pole_t := 0.0
	for i in p.size():
		var a: Vector2 = p[i]; var b: Vector2 = p[(i + 1) % p.size()]
		var seg := a.distance_to(b)
		if seg < 0.01: continue
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x)
		var ry := atan2(-dir.y, dir.x)
		var mid := (a + b) / 2.0
		for s in [-0.72, 0.72]:   # standard gauge
			var r: Vector2 = mid + nrm * s
			m.box(Vector3(r.x, 0.31, r.y), Vector3(seg + 0.05, 0.03, 0.09), steel, ry)
		m.box(Vector3(mid.x, 5.9, mid.y), Vector3(seg + 0.05, 0.04, 0.04), Color("2b2826"), ry)   # the wire
		pole_t += seg
		if pole_t > 26.0:
			pole_t = 0.0
			var q := a + nrm * 4.6
			m.box(Vector3(q.x, 3.2, q.y), Vector3(0.22, 6.4, 0.22), Color("3f4a40"))
			var arm := a + nrm * 2.3
			m.box(Vector3(arm.x, 6.1, arm.y), Vector3(0.08, 0.08, 4.6), Color("3f4a40"), ry + PI / 2.0)
	return m.node(Kit.vc_mat(), "tram_line")

## Ambrogio's last run, on Christmas Eve: his tram lit up after dark, its bell ringing as it comes past you.
func _last_run(dt: float) -> void:
	if festive == null or game.get("state") == null: return
	var eve: bool = game.state.flags.get("metropolis_christmas_eve", false) and not game.state.flags.get("metropolis_angel_lit", false)
	var dark := Daylight.nightness(float(game.state.time.minute) / 60.0) > 0.3
	festive.visible = eve and dark
	if not festive.visible: return
	festive_mat.emission_energy_multiplier = 1.6 + 0.6 * sin(t * 3.0)
	bell_t -= dt
	var p: Vector3 = (cars[0].node as Node3D).position
	var d := Vector2(p.x, p.z).distance_to(Vector2(game.player.pos.x, game.player.pos.z))
	if bell_t < 0.0 and d < 30.0 and game.get("audio") != null:
		bell_t = 6.0
		var vol := clampf(1.0 - d / 30.0, 0.0, 1.0) * 0.18
		for i in 2: game.audio.play("glock", 88, vol, -1, i * 0.18)   # ding-ding

