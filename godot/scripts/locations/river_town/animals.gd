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
var honk := false    # the geese have just started after you: honk

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
		var wm := P.mi(P.sphere(1.0, 16, 8), sheen, Vector3(s * 0.21, 0, 0), false); wm.scale = Vector3(0.22, 0.018, 0.12); w.add_child(wm)   # a rounded wing, not a slab
	return o

## A farmyard goose: a round white body with a tail tip, folded wings lying along its sides (rounded, not slabs),
## a long neck, an orange beak and orange webbed feet. Smooth spheres throughout, so it reads as a bird up close.
static func _goose() -> Node3D:
	var o := Node3D.new()
	var white := P.mat("f4f1ea"); var shade := P.mat("e4ded2"); var orange := P.mat("f08a24")
	var body_pivot := Node3D.new(); body_pivot.name = "body"; o.add_child(body_pivot)   # waddles (rolls) as it walks
	var body := P.mi(P.sphere(0.2, 18, 12), white, Vector3(0, 0.32, 0)); body.scale = Vector3(0.9, 0.78, 1.45); body.rotation.x = -0.12; body_pivot.add_child(body)
	var tail := P.mi(P.sphere(0.1, 12, 8), white, Vector3(0, 0.38, -0.27), false); tail.scale = Vector3(0.75, 0.55, 1.0); tail.rotation.x = 0.5; body_pivot.add_child(tail)
	for s in [-1, 1]:   # folded wings: long, thin rounded shapes along the flanks, pivoting at the shoulder
		var w := Node3D.new(); w.name = "wing%d" % (s + 1); w.position = Vector3(s * 0.13, 0.4, 0.1); body_pivot.add_child(w)
		var wm := P.mi(P.sphere(1.0, 16, 10), shade, Vector3(s * 0.03, -0.02, -0.15), false); wm.scale = Vector3(0.05, 0.11, 0.27); wm.rotation.x = 0.15; w.add_child(wm)
	var neck := Node3D.new(); neck.name = "neck"; neck.position = Vector3(0, 0.4, 0.2); body_pivot.add_child(neck)
	var nk := P.mi(P.capsule(0.048, 0.34, 12, 4), white, Vector3(0, 0.15, 0.0)); nk.rotation.x = 0.12; neck.add_child(nk)
	var head := P.mi(P.sphere(0.072, 14, 10), white, Vector3(0, 0.32, 0.04)); head.scale = Vector3(0.9, 0.9, 1.2); neck.add_child(head)
	var beak := P.mi(P.cone(0.03, 0.11, 10), orange, Vector3(0, 0.305, 0.14), false); beak.rotation.x = PI / 2; neck.add_child(beak)
	neck.add_child(P.mi(P.sphere(0.026, 10, 6), orange, Vector3(0, 0.33, 0.1), false))   # the knob at the top of the beak
	for s in [-1, 1]:
		neck.add_child(P.mi(P.sphere(0.013, 8, 6), P.mat("1d1414"), Vector3(s * 0.05, 0.34, 0.07), false))
		o.add_child(P.mi(P.cyl(0.014, 0.016, 0.18, 8), orange, Vector3(s * 0.07, 0.09, 0.0), false))
		var foot := P.mi(P.sphere(1.0, 10, 6), orange, Vector3(s * 0.07, 0.008, 0.04), false); foot.scale = Vector3(0.045, 0.01, 0.06); o.add_child(foot)
	return o

static func _kingfisher() -> Node3D:
	var o := Node3D.new()
	var blue := P.mat("2b9be0")
	var body := P.mi(P.sphere(0.055, 8, 6), blue, Vector3(0, 0.06, 0)); body.scale = Vector3(0.9, 1.0, 1.4); o.add_child(body)
	o.add_child(P.mi(P.sphere(0.045, 8, 6), P.mat("e8742a"), Vector3(0, 0.035, 0.02), false))   # the orange breast
	o.add_child(P.mi(P.sphere(0.04, 8, 6), blue, Vector3(0, 0.11, 0.05), false))
	var beak := P.mi(P.cone(0.012, 0.07, 4), P.mat("1d1414"), Vector3(0, 0.11, 0.11), false); beak.rotation.x = PI / 2; o.add_child(beak)
	return o

## A low willow branch that grows out of the bank and reaches out over the water to the kingfisher's perch, with a
## few sprigs of leaves (the twig used to hang in the air on its own).
static func _perch_branch(perch: Vector3) -> Node3D:
	var o := Node3D.new()
	var bark := P.mat("6a5c4c"); var leaf := P.mat("a8b48a")
	var base := Vector3(perch.x - 1.7, 0.0, perch.z + 0.35)
	base.y = Heightfield.height(base.x, base.z) - 0.1   # rooted in the bank
	var tip := perch + Vector3(0.25, -0.04, -0.03)
	var knee := base.lerp(tip, 0.45) + Vector3(0, 0.35, 0)   # up out of the bank, then out over the river
	o.add_child(_limb(base, knee, 0.07, 0.05, bark))
	o.add_child(_limb(knee, tip, 0.05, 0.022, bark))
	o.add_child(_limb(knee, knee + Vector3(0.3, 0.55, 0.4), 0.035, 0.015, bark))   # a twig up, for the leaves
	for k in 4:
		var at: Vector3 = knee.lerp(tip, 0.25 + k * 0.2) + Vector3(0, -0.08 - 0.05 * (k % 2), 0.06 * (k % 2 * 2 - 1))
		var sprig := P.mi(P.sphere(1.0, 10, 6), leaf, at, false); sprig.scale = Vector3(0.09, 0.22, 0.09); o.add_child(sprig)
	return o

## A tapering piece of branch from a to b.
static func _limb(a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var m := P.mi(P.cyl(r1, r0, a.distance_to(b), 7), mat, (a + b) / 2.0)
	m.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return m

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
		geese.append({"obj": o, "home": home, "pos": home, "goal": home, "yaw": n * 1.2, "ph": n * 1.1, "wait": 1.0 + n * 0.9, "walk": 0.0, "step": 0.0, "going": false})
	var ps := perches()
	for n in 2:
		add_child(_perch_branch(ps[n]))   # a willow branch growing out of the bank, reaching over the water
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
	if honk:
		honk = false
		if g.get("audio"): g.audio.play("rasp", 58, 0.22); g.audio.play("rasp", 62, 0.18, -1, 0.2); g.audio.play("rasp", 57, 0.16, -1, 0.55)
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
## Each goose either stands and pecks or walks to a new spot: it sets off only when its goal is a good way off and
## stops once it's there (not every other frame, which made them shake), and its waddle and bob grow and fade with
## its pace instead of switching on and off.
func _geese(dt: float, p2: Vector2, riding: bool) -> void:
	calm = maxf(0.0, calm - dt)
	var from_home := p2.distance_to(GEESE_HOME)
	if chase <= 0.0 and calm <= 0.0 and riding and from_home < GEESE_SEE:
		chase = 0.01; honk = true
	elif chase > 0.0:
		chase += dt
		if chase > 6.0 or from_home > GEESE_GIVE_UP:
			chase = 0.0; calm = 20.0
			for k in geese.size(): geese[k].going = false; geese[k].wait = 0.6 + k * 0.3   # a moment's triumph, then home
	for k in geese.size():
		var q: Dictionary = geese[k]
		var o: Node3D = q.obj
		var speed := 0.35 if q.pos.distance_to(q.home) < 2.5 else 0.9   # back home from a chase at a brisk waddle
		if chase > 0.0:   # after you, a little behind and to the side, each its own way
			q.goal = p2 + Vector2(cos(k * 1.3), sin(k * 1.7)) * 1.4
			speed = 2.6
		else:
			if not q.going: q.wait -= dt   # (it pecks a while once it gets there)
			if not q.going and q.wait <= 0.0:   # done pecking here: somewhere else on the patch of grass
				var a: float = q.ph + t * 0.37 + k * 2.1
				q.goal = q.home + Vector2(cos(a), sin(a * 1.3)) * (0.5 + 0.9 * absf(sin(a * 0.7)))
				q.wait = 2.5 + fmod(q.ph * 3.7 + t, 3.0)
		var d: Vector2 = q.goal - q.pos
		var dist := d.length()
		if not q.going and dist > (0.6 if chase > 0.0 else 0.25): q.going = true   # set off only for a real distance...
		elif q.going and dist < 0.08: q.going = false   # ...and stop once there
		if q.going:
			q.pos = q.pos + d / dist * minf(dist, speed * dt)
			q.yaw = lerp_angle(q.yaw, atan2(d.x, d.y), 1.0 - exp(-6.0 * dt))
		q.walk = move_toward(q.walk, (speed if q.going else 0.0), dt * 3.0)   # pace, eased
		q.step += minf(q.walk, 1.1) * dt * 11.0   # quick little steps when they run, but not a blur
		var body: Node3D = o.get_node("body")
		var sway: float = minf(1.0, q.walk / 0.35)
		body.rotation.z = sin(q.step) * 0.09 * sway   # the waddle
		o.position = Vector3(q.pos.x, Heightfield.height(q.pos.x, q.pos.y) + absf(sin(q.step)) * 0.018 * sway, q.pos.y)
		o.rotation.y = q.yaw
		var neck: Node3D = body.get_node("neck")
		var pecking: bool = not q.going and chase <= 0.0 and fmod(t + q.ph, 4.0) < 1.6
		var want_neck := 0.95 if chase > 0.0 else (0.75 + 0.12 * sin(t * 7.0 + q.ph) if pecking else 0.05 * sin(t * 0.8 + q.ph))
		neck.rotation.x = lerpf(neck.rotation.x, want_neck, 1.0 - exp(-10.0 * dt))
		var wing := (0.55 + 0.2 * sin(t * 9.0 + k)) if chase > 0.0 else 0.0   # wings out when they charge
		var w0: Node3D = body.get_node("wing0"); var w2: Node3D = body.get_node("wing2")
		w0.rotation.z = lerpf(w0.rotation.z, -wing, 1.0 - exp(-12.0 * dt)); w2.rotation.z = -w0.rotation.z

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
