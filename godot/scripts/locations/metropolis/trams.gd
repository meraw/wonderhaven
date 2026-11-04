extends Node3D
## Toriano's trams: old orange cars running round the loop line, slowing into each stop and waiting there a few
## seconds, and holding back while someone stands on the track ahead. They are solid (moving bodies in the walk
## world). Riding is the shared stop feature (Travel.stops_on, game.ride_to); these are the cars you see.

const Kit := preload("res://scripts/locations/metropolis/kit.gd")

const SPEED := 7.0
const DWELL := 6.0
const CORNER := 9.0        # radius the rails take round each corner
const ORANGE := Color("e8892c")
const CREAM := Color("efe2c4")
const GREY := Color("6e6a64")

var game
var path := PackedVector2Array()   # the line, sampled every metre or so, closed
var dist := PackedFloat32Array()   # distance along the line at each sample
var length := 0.0
var stops: Array = []               # distances along the line where trams stop
var cars: Array = []                # {node, s, wait, bodies: [3 dicts]}

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

func setup(g, corners: Array, stop_points: Array, count: int = 3) -> void:
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
	for i in count:
		var node := model(i == 0)
		add_child(node)
		var car := {"node": node, "s": length * i / count, "wait": 0.0, "bodies": []}
		for k in 3:
			var body := {"x": 0.0, "z": 0.0, "r": 1.35}
			car.bodies.append(body)
			if game and game.walk: game.walk.dynamic.append(body)
		cars.append(car)
		_place(car)

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
	for k in 3:   # three round bodies along the car, for collisions
		var q: Vector2 = pos + dir * (k - 1) * 4.2
		car.bodies[k].x = q.x; car.bodies[k].z = q.y

func _process(dt: float) -> void:
	if game == null or length <= 0.0: return
	var pl := Vector2(game.player.pos.x, game.player.pos.z) if game.player else Vector2(1e9, 1e9)
	for car in cars:
		if car.wait > 0.0: car.wait -= dt; continue
		var p: Array = at(car.s + 7.0)   # just ahead of the front
		var ahead: Vector2 = p[0]
		if pl.distance_to(ahead) < 3.2: continue   # someone on the track: wait for them
		var step := SPEED * dt
		for st in stops:   # slow into a stop, then wait
			var gap := fposmod(st - car.s, length)
			if gap > 0.0 and gap <= step: car.s = st; car.wait = DWELL; step = 0.0; break
			if gap < 10.0: step *= clampf(gap / 10.0, 0.25, 1.0)
		car.s = fposmod(car.s + step, length)
		_place(car)

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
