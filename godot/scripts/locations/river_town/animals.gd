extends Node3D
## Boccapioppo's animals (docs/locations/river_town.md, "Look"): coypus waddling on the banks that slip into the
## water when you come close, cormorants drying their wings on snags in the rivers, the farm's geese that chase
## bicycles, and kingfishers flashing blue along the Alpine river. (The cats waiting for Gildo's catch are the shared
## ones, from the layout's "wildlife".) Only for looking at: none of them get in your way.

const P := preload("res://scripts/world/palette.gd")
const RT := preload("res://scripts/locations/river_town.gd")

const COYPU_NEAR := 4.5     # come this close and a coypu slips into the water
const GEESE_HOME := Vector2(-31.5, -33.0)   # the flock's patch of grass outside the farm gate
const GEESE_SEE := 9.0      # ride a bike this close and the geese come after you
const GEESE_GIVE_UP := 16.0 # ...as far as this from home, then they waddle back
const SNAGS := [Vector2(12.5, 44.0), Vector2(-17.0, 45.5), Vector2(-3.0, 47.0)]   # dead branches in the Po
const PERCH_Z := [-30.0, -4.0]   # the kingfishers' two perches, on the Alpine river's west bank

var coypus: Array = []
var cormorants: Array = []
var geese: Array = []
var kingfishers: Array = []
var t := 0.0
var chase := 0.0     # seconds the geese have been chasing (0: not chasing)
var calm := 0.0      # seconds before they'll chase again

static func make() -> Node3D:
	var a: Node3D = load("res://scripts/locations/river_town/animals.gd").new()
	a.name = "river_town_animals"
	a._build()
	return a

# ---- where they live --------------------------------------------------------------------------------------------

## Coypu homes: a spot on a bank beside water deep enough to swim in, near each of these places (the backwater, the
## Po's bank, the canals). Each is [land, water].
static func coypu_spots() -> Array:
	var out: Array = []
	for c in [Vector2(-19.0, 33.2), Vector2(-31.5, 34.0), Vector2(-1.0, 38.0), Vector2(-53.0, -8.0), Vector2(-22.0, -51.0)]:
		var s := _bank_near(c)
		if not s.is_empty(): out.append(s)
	return out

static func _bank_near(c: Vector2) -> Array:
	for r in [0.0, 1.0, 2.0, 3.0]:
		for k in 12:
			var a := TAU * k / 12.0
			var land: Vector2 = c + Vector2(cos(a), sin(a)) * r
			var h := Heightfield.height(land.x, land.y)
			if h < Heightfield.WALKABLE_MIN + 0.05 or h > 0.35: continue
			for k2 in 12:
				var b := TAU * k2 / 12.0
				var water: Vector2 = land + Vector2(cos(b), sin(b)) * 2.2
				if Heightfield.height(water.x, water.y) < Heightfield.WATER_Y - 0.25: return [land, water]
	return []

## The kingfishers' perches: a low willow branch over the Alpine river's west bank.
static func perches() -> Array:
	return PERCH_Z.map(func(z): return Vector3(RT.alpine_center(z) - RT.ALPINE_HALF - 0.2, Heightfield.WATER_Y + 1.1, z))

# ---- models -----------------------------------------------------------------------------------------------------

static func _coypu() -> Node3D:
	var o := Node3D.new()
	var fur := P.mat("6b5440"); var muzzle := P.mat("9a8a76")
	var body := P.mi(P.sphere(0.22, 10, 8), fur, Vector3(0, 0.17, 0)); body.scale = Vector3(0.85, 0.72, 1.4); o.add_child(body)
	var head := Node3D.new(); head.name = "head"; head.position = Vector3(0, 0.2, 0.3); o.add_child(head)
	var hs := P.mi(P.sphere(0.12, 10, 8), fur); hs.scale = Vector3(0.9, 0.85, 1.15); head.add_child(hs)
	head.add_child(P.mi(P.sphere(0.07, 8, 6), muzzle, Vector3(0, -0.03, 0.1), false))
	head.add_child(P.mi(P.box(0.05, 0.04, 0.02), P.mat("e8892a"), Vector3(0, -0.08, 0.15), false))   # the orange front teeth
	for s in [-1, 1]:
		head.add_child(P.mi(P.sphere(0.03, 6, 4), fur, Vector3(s * 0.07, 0.08, -0.02), false))
		head.add_child(P.mi(P.sphere(0.016, 6, 4), P.mat("1d1414"), Vector3(s * 0.055, 0.03, 0.09), false))
		var wh := P.mi(P.cyl(0.003, 0.003, 0.14, 3), P.mat("efe9df"), Vector3(s * 0.07, -0.03, 0.12), false); wh.rotation.z = PI / 2 + s * 0.2; head.add_child(wh)
	var tail := P.mi(P.cyl(0.012, 0.028, 0.5, 5), P.mat("4a3a30"), Vector3(0, 0.06, -0.5), false); tail.rotation.x = PI / 2 - 0.12; o.add_child(tail)
	return o

static func _cormorant() -> Node3D:
	var o := Node3D.new()
	var black := P.mat("1f2328"); var sheen := P.mat("2d3a33")
	var body := P.mi(P.sphere(0.16, 8, 6), black, Vector3(0, 0.3, 0)); body.scale = Vector3(0.8, 1.35, 0.85); o.add_child(body)
	o.add_child(P.mi(P.cyl(0.04, 0.05, 0.22, 6), black, Vector3(0, 0.56, 0.03)))
	o.add_child(P.mi(P.sphere(0.065, 8, 6), black, Vector3(0, 0.69, 0.05)))
	o.add_child(P.mi(P.sphere(0.03, 6, 4), P.mat("e8c24a"), Vector3(0, 0.66, 0.1), false))   # the yellow chin
	var beak := P.mi(P.cone(0.02, 0.13, 5), P.mat("4a4640"), Vector3(0, 0.68, 0.16), false); beak.rotation.x = PI / 2; o.add_child(beak)
	for s in [-1, 1]:   # wings held open to dry, as cormorants do
		var w := Node3D.new(); w.name = "wing%d" % (s + 1); w.position = Vector3(s * 0.1, 0.42, -0.02); o.add_child(w)
		var wm := P.mi(P.box(0.42, 0.03, 0.22), sheen, Vector3(s * 0.22, 0, 0), false); w.add_child(wm)
	return o

static func _goose() -> Node3D:
	var o := Node3D.new()
	var white := P.mat("f4f1ea"); var orange := P.mat("f08a24")
	var body := P.mi(P.sphere(0.2, 10, 8), white, Vector3(0, 0.3, 0)); body.scale = Vector3(0.85, 0.8, 1.35); o.add_child(body)
	var neck := Node3D.new(); neck.name = "neck"; neck.position = Vector3(0, 0.38, 0.18); o.add_child(neck)
	neck.add_child(P.mi(P.cyl(0.045, 0.05, 0.3, 6), white, Vector3(0, 0.15, 0)))
	neck.add_child(P.mi(P.sphere(0.075, 8, 6), white, Vector3(0, 0.32, 0.03)))
	var beak := P.mi(P.cone(0.032, 0.1, 5), orange, Vector3(0, 0.31, 0.12), false); beak.rotation.x = PI / 2; neck.add_child(beak)
	for s in [-1, 1]:
		neck.add_child(P.mi(P.sphere(0.014, 6, 4), P.mat("1d1414"), Vector3(s * 0.05, 0.34, 0.06), false))
		var w := P.mi(P.box(0.06, 0.12, 0.3), white, Vector3(s * 0.15, 0.32, -0.02), false); w.name = "wing%d" % (s + 1); o.add_child(w)
		o.add_child(P.mi(P.cyl(0.015, 0.015, 0.16, 4), orange, Vector3(s * 0.07, 0.08, 0), false))
	return o

static func _kingfisher() -> Node3D:
	var o := Node3D.new()
	var blue := P.mat("2b9be0")
	var body := P.mi(P.sphere(0.055, 8, 6), blue, Vector3(0, 0.06, 0)); body.scale = Vector3(0.9, 1.0, 1.4); o.add_child(body)
	o.add_child(P.mi(P.sphere(0.045, 8, 6), P.mat("e8742a"), Vector3(0, 0.035, 0.02), false))   # the orange breast
	o.add_child(P.mi(P.sphere(0.04, 8, 6), blue, Vector3(0, 0.11, 0.05), false))
	var beak := P.mi(P.cone(0.012, 0.07, 4), P.mat("1d1414"), Vector3(0, 0.11, 0.11), false); beak.rotation.x = PI / 2; o.add_child(beak)
	return o

static func _snag() -> Node3D:
	var o := Node3D.new()
	var wood := P.mat("5a4e44")
	var s := P.mi(P.cyl(0.05, 0.09, 1.3, 6), wood, Vector3(0, 0.45, 0)); s.rotation.z = 0.25; o.add_child(s)
	var b := P.mi(P.cyl(0.025, 0.04, 0.6, 5), wood, Vector3(-0.22, 0.85, 0)); b.rotation.z = 0.9; o.add_child(b)
	return o

# ---- building and animating --------------------------------------------------------------------------------------

func _build() -> void:
	for s in coypu_spots():
		var o := _coypu(); add_child(o)
		var land: Vector2 = s[0]
		coypus.append({"obj": o, "home": land, "water": s[1], "pos": land, "state": "graze", "t": 0.0, "dir": 1.0, "ph": coypus.size() * 2.3})
	for p in SNAGS:
		var sn := _snag(); add_child(sn); sn.position = Vector3(p.x, Heightfield.WATER_Y, p.y)
		var o := _cormorant(); add_child(o)
		var perch := Vector3(p.x - 0.4, Heightfield.WATER_Y + 1.05, p.y)
		o.position = perch; o.rotation.y = randf() * TAU
		cormorants.append({"obj": o, "perch": perch, "fly": -1.0, "ph": cormorants.size() * 1.7})
	for n in 5:
		var o := _goose(); add_child(o)
		var home := GEESE_HOME + Vector2(cos(n * 1.3) * 1.6, sin(n * 1.9) * 1.4)
		geese.append({"obj": o, "home": home, "pos": home, "yaw": n * 1.2, "ph": n * 1.1})
	var ps := perches()
	for n in 2:
		var tw := P.mi(P.cyl(0.015, 0.03, 1.4, 5), P.mat("6a5c4c"), ps[n] + Vector3(-0.5, -0.03, 0)); tw.rotation.z = PI / 2 - 0.08; add_child(tw)   # a willow twig
		var o := _kingfisher(); add_child(o)
		o.position = ps[n]; o.scale = Vector3.ONE * 2.2
		kingfishers.append({"obj": o, "at": n, "wait": 4.0 + n * 3.0, "fly": -1.0})

func _process(dt: float) -> void:
	var g = get_tree().current_scene if is_inside_tree() else null
	if g == null or not (g.get("state") is Dictionary) or g.get("player") == null: return
	t += dt
	var pp: Vector3 = g.player.pos
	var p2 := Vector2(pp.x, pp.z)
	var hour := float(g.state.time.minute) / 60.0
	var day := hour > 6.5 and hour < 19.5
	_coypus(dt, p2)
	_cormorants(dt, p2, day)
	_geese(dt, p2, bool(g.player.get("riding")))
	_kingfishers(dt, day)

func _coypus(dt: float, p2: Vector2) -> void:
	for c in coypus:
		var o: Node3D = c.obj
		c.t += dt
		var near: bool = p2.distance_to(c.pos) < COYPU_NEAR
		if near and c.state in ["graze", "back"]: c.state = "flee"
		if c.state == "graze":   # waddling a couple of metres along the bank and back, stopping to nibble
			var along: Vector2 = (c.water - c.home).orthogonal().normalized()
			var goal: Vector2 = c.home + along * c.dir * 1.2
			if c.pos.distance_to(goal) < 0.1 or fmod(c.t + c.ph, 6.0) < 2.5:
				if c.pos.distance_to(goal) < 0.1: c.dir = -c.dir
				o.get_node("head").rotation.x = 0.35 + sin(t * 9.0) * 0.08   # nibbling
			else:
				_walk(c, goal, 0.35, dt)
				o.get_node("head").rotation.x = 0.0
		elif c.state == "flee":   # into the water, and under
			_walk(c, c.water, 1.6, dt)
			if c.pos.distance_to(c.water) < 0.15: c.state = "under"; c.t = 0.0; o.visible = false
		elif c.state == "under":
			if c.t > 18.0 + c.ph and not near: c.state = "back"; c.t = 0.0; o.visible = true
		elif c.state == "back":   # swims back and climbs out
			_walk(c, c.home, 0.4, dt)
			if c.pos.distance_to(c.home) < 0.1: c.state = "graze"; c.t = 0.0
		var h := Heightfield.height(c.pos.x, c.pos.y)
		o.position = Vector3(c.pos.x, maxf(h, Heightfield.WATER_Y - 0.16), c.pos.y)

func _walk(c: Dictionary, goal: Vector2, speed: float, dt: float) -> void:
	var d: Vector2 = goal - c.pos
	if d.length() < 0.001: return
	c.pos = c.pos + d.normalized() * minf(d.length(), speed * dt)
	(c.obj as Node3D).rotation.y = lerp_angle((c.obj as Node3D).rotation.y, atan2(d.x, d.y), 1.0 - exp(-8.0 * dt))

func _cormorants(dt: float, p2: Vector2, day: bool) -> void:
	for c in cormorants:
		var o: Node3D = c.obj
		o.visible = day or c.fly >= 0.0
		var perch: Vector3 = c.perch
		if c.fly < 0.0:
			o.position = perch
			var flap := 0.15 * sin(t * 1.3 + c.ph)   # wings held out to dry, stirring now and then
			o.get_node("wing0").rotation.z = -0.1 + flap; o.get_node("wing2").rotation.z = 0.1 - flap
			if p2.distance_to(Vector2(perch.x, perch.z)) < 5.0: c.fly = 0.0
		else:   # off low over the water, a long loop, and back to the snag
			c.fly += dt
			var u: float = c.fly / 30.0
			var a: float = c.ph + u * TAU
			o.position = perch + Vector3(cos(a) * 14.0 - 14.0 * cos(c.ph), 1.2 * sin(u * PI), sin(a) * 6.0 - 6.0 * sin(c.ph))
			o.rotation.y = a + PI / 2.0
			var w := sin(t * 14.0) * 0.6
			o.get_node("wing0").rotation.z = w; o.get_node("wing2").rotation.z = -w
			if c.fly > 30.0: c.fly = -1.0

## The geese peck about outside the farm gate, but ride past on a bike and they come after you with their necks out,
## until they're too far from home: then they waddle back, very pleased with themselves.
func _geese(dt: float, p2: Vector2, riding: bool) -> void:
	calm = maxf(0.0, calm - dt)
	var from_home := p2.distance_to(GEESE_HOME)
	if chase <= 0.0 and calm <= 0.0 and riding and from_home < GEESE_SEE:
		chase = 0.01
	elif chase > 0.0:
		chase += dt
		if chase > 6.0 or from_home > GEESE_GIVE_UP: chase = 0.0; calm = 20.0
	for k in geese.size():
		var q: Dictionary = geese[k]
		var o: Node3D = q.obj
		var goal: Vector2
		var speed := 0.4
		if chase > 0.0:
			goal = p2 + Vector2(cos(k * 1.3), sin(k * 1.7)) * 1.2
			speed = 3.0
		else:
			goal = q.home + Vector2(sin(t * 0.21 + q.ph), cos(t * 0.17 + q.ph * 1.3)) * 0.9
		var d: Vector2 = goal - q.pos
		var moving := d.length() > 0.08
		if moving:
			q.pos = q.pos + d.normalized() * minf(d.length(), speed * dt)
			q.yaw = lerp_angle(q.yaw, atan2(d.x, d.y), 1.0 - exp(-8.0 * dt))
		o.position = Vector3(q.pos.x, Heightfield.height(q.pos.x, q.pos.y), q.pos.y)
		o.rotation.y = q.yaw
		var neck: Node3D = o.get_node("neck")
		neck.rotation.x = 0.9 if chase > 0.0 else (0.6 + 0.3 * sin(t * 6.0 + q.ph) if fmod(t + q.ph, 5.0) < 1.5 else 0.0)
		var wing := 0.5 + 0.3 * sin(t * 18.0) if chase > 0.0 else 0.0
		o.get_node("wing0").rotation.z = -wing; o.get_node("wing2").rotation.z = wing
		o.position.y += absf(sin(t * (12.0 if chase > 0.0 else 5.0) + q.ph)) * (0.04 if moving else 0.0)

## Each kingfisher sits on its perch a while, then darts low along the river to the other perch in a blue flash.
func _kingfishers(dt: float, day: bool) -> void:
	var ps := perches()
	for k in kingfishers:
		var o: Node3D = k.obj
		o.visible = day
		if k.fly < 0.0:
			k.wait -= dt
			o.position = ps[k.at]
			if k.wait <= 0.0: k.fly = 0.0
		else:
			k.fly += dt
			var u: float = clampf(k.fly / 1.6, 0.0, 1.0)
			var a: Vector3 = ps[k.at]; var b: Vector3 = ps[1 - k.at]
			var p := a.lerp(b, u)
			p.x = RT.alpine_center(p.z) - RT.ALPINE_HALF * 0.5 * sin(u * PI)   # out over the water and back to the bank
			p.y = lerpf(a.y, Heightfield.WATER_Y + 0.3, sin(u * PI))
			o.position = p
			o.rotation.y = atan2(b.x - a.x, b.z - a.z)
			if u >= 1.0: k.at = 1 - k.at; k.fly = -1.0; k.wait = 8.0 + randf() * 8.0
