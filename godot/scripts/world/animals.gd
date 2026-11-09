extends Node3D
## Ambient wildlife: butterflies over flowers, ducks on the river, chickens in Fern's yard (pet them, toss ducks an apple).
## Any place can add its own from the layout's "wildlife": {"boars": n (rooting about in decor.woods), "cats": [[x, z,
## yaw, y?], ...] (sitting about the village; pet them), "crows": [[x, z], ...] (hopping in the fields, flying off when
## you come close)}.
const P := preload("res://scripts/world/palette.gd")
var game
var t := 0.0
var butterflies: Array = []
var ducks: Array = []
var chickens: Array = []
var boars: Array = []
var cats: Array = []
var crows: Array = []

func setup(g) -> void:
	game = g
	_wildlife(Data.layout.get("wildlife", {}))
	if Data.island != "hearthglow": return   # Hearthglow's ducks, chickens and butterflies live along its river and meadows
	var spots := [[-20, -2], [18, -12], [-9, 25], [22, 21], [3, -38], [4, 6], [-6, 4], [12, 18]]
	var cols := ["ffd84a", "ff9ec7", "9fd8ff", "c9a8ff"]
	for n in spots.size():
		for k in 2:
			var b := Node3D.new()
			var wm := P.glow_mat(Color(cols[(n + k) % 4])); wm.cull_mode = BaseMaterial3D.CULL_DISABLED
			for s in [-1, 1]:
				var w := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.16, 0.14); w.mesh = q; w.material_override = wm; w.position.x = s * 0.07; w.rotation.x = -PI / 2; w.set_meta("side", s); b.add_child(w)
			add_child(b)
			butterflies.append({"obj": b, "x": float(spots[n][0]), "z": float(spots[n][1]), "ph": randf() * 10.0, "sp": 0.6 + randf() * 0.5})
	for n in mini(int(Data.layout.get("ducks", 4)), 4):   # a place without a river sets "ducks": 0
		var d := Node3D.new()
		var body := P.mi(P.sphere(0.22, 10, 8), P.mat("ffffff")); body.scale = Vector3(1, 0.7, 1.3); d.add_child(body)
		d.add_child(P.mi(P.sphere(0.12, 10, 8), P.mat("3c9a4a"), Vector3(0, 0.2, 0.22)))
		var beak := P.mi(P.cone(0.04, 0.1, 6), P.mat("ffb33b"), Vector3(0, 0.18, 0.36)); beak.rotation.x = PI / 2; d.add_child(beak)
		add_child(d)
		var x0: float = [-26.0, -10.0, 14.0, 24.0][n]
		var duck := {"obj": d, "x0": x0, "ph": n * 1.7, "x": x0, "z": Heightfield.river_center(x0), "peck": 0.0}
		ducks.append(duck)
		game.add_interactable({"id": "duck%d" % n, "x": func(): return duck.x, "z": func(): return duck.z, "radius": 3.6, "object": d, "ambient": true,
			"available": func(): return game.state.inventory.get("fruit", 0) > 0, "label": func(): return "Toss a hazelnut to the duck", "act": func(): pet(duck, "duck")})
	for n in 3:
		var c := Node3D.new()
		var white := P.mat("fff7ea")
		c.add_child(P.mi(P.sphere(0.2, 10, 8), white, Vector3(0, 0.25, 0)))
		var head := P.mi(P.sphere(0.11, 10, 8), white, Vector3(0, 0.45, 0.13)); c.add_child(head)
		c.add_child(P.mi(P.sphere(0.05, 6, 5), P.mat("ff5a5f"), Vector3(0, 0.57, 0.13)))
		var bk := P.mi(P.cone(0.03, 0.07, 5), P.mat("ffb33b"), Vector3(0, 0.44, 0.25)); bk.rotation.x = PI / 2; c.add_child(bk)
		for s in [-1, 1]: c.add_child(P.mi(P.cyl(0.015, 0.015, 0.12, 4), P.mat("ffb33b"), Vector3(s * 0.06, 0.06, 0)))
		add_child(c)
		var home: Array = [[12.5, -4.2], [14.0, -6.5], [8.5, -5.0]][n]
		var ch := {"obj": c, "head": head, "home": Vector2(home[0], home[1]), "x": home[0], "z": home[1], "ph": n * 2.1, "yaw": 0.0, "peck": 0.0}
		chickens.append(ch)
		game.add_interactable({"id": "chicken%d" % n, "x": func(): return ch.x, "z": func(): return ch.z, "radius": 1.1, "object": c, "ambient": true, "label": func(): return "Pet the chicken", "act": func(): pet(ch, "chicken")})

func _wildlife(W: Dictionary) -> void:
	var woods: Array = Data.layout.get("decor", {}).get("woods", [])
	for n in int(W.get("boars", 0)) if not woods.is_empty() else 0:
		var w: Dictionary = woods[n % woods.size()]
		var o := Props.wild_boar(); o.scale = Vector3.ONE * 1.1; add_child(o)
		var c := Vector2(float(w.x), float(w.z))
		var boar := {"obj": o, "head": o.get_node("head"), "c": c, "r": float(w.r) * 0.75, "pos": c + Vector2(n * 1.7, -n * 1.3), "goal": c,
			"wait": n * 1.5, "yaw": 0.0, "ph": n * 2.3, "full": 0.0}
		boars.append(boar)
		# with chestnuts in your pocket they come and see you instead of trotting off, and take one
		game.add_interactable({"id": "boar%d" % n, "x": func(): return boar.pos.x, "z": func(): return boar.pos.y, "radius": 1.6, "object": o,
			"available": func(): return int(game.state.inventory.get("acorn", 0)) > 0 and boar.full <= 0.0,
			"label": func(): return "Offer a chestnut", "act": func(): feed_boar(boar)})
	for i in W.get("cats", []).size():
		var spot: Array = W.cats[i]
		var o := _cat(i); add_child(o)
		var y: float = float(spot[3]) if spot.size() > 3 else Heightfield.height(spot[0], spot[1])
		o.position = Vector3(spot[0], y, spot[1]); o.rotation.y = float(spot[2])
		var cat := {"obj": o, "tail": o.get_node("tail"), "head": o.get_node("head"), "yaw": float(spot[2]), "ph": i * 1.9, "peck": 0.0}
		cats.append(cat)
		game.add_interactable({"id": "cat%d" % i, "x": float(spot[0]), "z": float(spot[1]), "radius": 1.2, "object": o, "ambient": true, "label": func(): return "Pet the cat", "act": func(): pet(cat, "cat")})
	var spots: Array = W.get("crows", [])
	for i in spots.size():
		var o := _crow(); add_child(o)
		var at := Vector2(spots[i][0], spots[i][1])
		crows.append({"obj": o, "spot": i, "pos": at, "home": at, "fly": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "ph": i * 1.3, "yaw": i * 1.1, "spots": spots})

## A village cat sitting tidily, tail curled round, in tabby, ginger, black or white.
func _cat(i: int) -> Node3D:
	var c := Node3D.new()
	var fur := P.mat(["9a8572", "e0a05a", "2e2b2c", "f2eee6"][i % 4])
	var body := P.mi(P.sphere(0.16, 10, 8), fur, Vector3(0, 0.16, -0.02)); body.scale = Vector3(0.9, 1.15, 1.0); c.add_child(body)
	var head := Node3D.new(); head.name = "head"; head.position = Vector3(0, 0.36, 0.06); c.add_child(head)
	head.add_child(P.mi(P.sphere(0.11, 10, 8), fur))
	for s in [-1, 1]:
		var ear := P.mi(P.cone(0.045, 0.08, 4), fur, Vector3(s * 0.065, 0.1, 0), false); ear.rotation.z = -s * 0.3; head.add_child(ear)
		head.add_child(P.mi(P.sphere(0.018, 6, 4), P.mat("6fae3a" if i % 4 != 2 else "e8c24a"), Vector3(s * 0.04, 0.02, 0.095), false))
	var tail := Node3D.new(); tail.name = "tail"; tail.position = Vector3(0.08, 0.05, -0.12); c.add_child(tail)
	var tl := P.mi(P.cyl(0.025, 0.035, 0.3, 6), fur, Vector3(0, 0, -0.14), false); tl.rotation.x = PI / 2 - 0.3; tail.add_child(tl)
	return c

## A crow: glossy black, a stout grey beak.
func _crow() -> Node3D:
	var c := Node3D.new()
	var black := P.mat("1d1f26")
	var body := P.mi(P.sphere(0.12, 8, 6), black, Vector3(0, 0.16, 0)); body.scale = Vector3(0.85, 0.9, 1.5); c.add_child(body)
	c.add_child(P.mi(P.sphere(0.075, 8, 6), black, Vector3(0, 0.27, 0.15)))
	var beak := P.mi(P.cone(0.03, 0.09, 5), P.mat("3b3d44"), Vector3(0, 0.26, 0.25), false); beak.rotation.x = PI / 2; c.add_child(beak)
	var tail := P.mi(P.sphere(1.0, 12, 6), black, Vector3(0, 0.17, -0.22), false); tail.scale = Vector3(0.06, 0.012, 0.1); tail.rotation.x = 0.3; c.add_child(tail)
	for s in [-1, 1]:   # rounded wings (flat boxes read as square slabs)
		var wing := Node3D.new(); wing.name = "wing%d" % (s + 1); wing.position = Vector3(s * 0.05, 0.2, -0.02); c.add_child(wing)
		var wm := P.mi(P.sphere(1.0, 12, 6), black, Vector3(s * 0.07, 0, 0), false); wm.scale = Vector3(0.11, 0.012, 0.07); wing.add_child(wm)
		c.add_child(P.mi(P.cyl(0.008, 0.008, 0.1, 4), P.mat("3b3d44"), Vector3(s * 0.04, 0.05, 0), false))
	return c

func pet(a: Dictionary, kind: String) -> void:
	var s: Dictionary = game.state
	if kind == "duck": s.inventory.fruit -= 1; game.render_resources(["fruit"])
	game.effects.hearts(a.obj.position + Vector3(0, 0.6, 0), 3)
	game.sfx({"chicken": "cluck", "cat": "purr"}.get(kind, "squeak"))
	a.peck = 1.2
	var key := "pet_%s_%d" % [kind, int(s.time.day)]
	if not s.flags.get(key, false):
		s.flags[key] = true
		game.toast({"duck": "Quack! The duck does a happy little spin.", "cat": "The cat leans into your hand and purrs."}.get(kind, "Bawk! The chicken clucks contentedly."), "good")
	game.story.event("animal")

## A boar in the woods takes a chestnut: it crunches it, snuffles at your pockets, and goes back to rooting about,
## not scared of you for a while. Ornella's three at the bakery are the ones her request is about.
func feed_boar(b: Dictionary) -> void:
	var s: Dictionary = game.state
	if int(s.inventory.get("acorn", 0)) <= 0: return
	s.inventory.acorn -= 1; game.render_resources(["acorn"])
	b.full = 45.0; b.wait = 4.0; b.goal = b.pos
	game.player_char.play("feed"); game.sfx("rustle")
	game.effects.hearts(b.obj.position + Vector3(0, 0.7, 0), 3)
	var bakery: bool = s.quests.get("squirrels", {}).get("status", "") == "active" and not s.flags.get("squirrelsGone", false)
	game.toast("Crunch. The boar snuffles your pockets for more." + (" This one lives in the woods; Ornella's three are at the bakery." if bakery else ""), "good")
	game.story.event("animal")

func _process(dt: float) -> void:
	if game == null: return
	t += dt
	_process_wildlife(dt)
	var night: bool = game.state.flags.get("night", false)
	for b in butterflies:
		b.obj.visible = not night
		var a: float = t * b.sp + b.ph
		b.obj.position = Vector3(b.x + sin(a) * 1.6 + sin(a * 2.3) * 0.4, Heightfield.height(b.x, b.z) + 0.7 + sin(a * 3.1) * 0.3, b.z + cos(a * 0.8) * 1.4)
		b.obj.rotation.y = a
		for w in b.obj.get_children(): w.rotation.z = float(w.get_meta("side")) * sin(t * 18.0 + b.ph) * 0.9
	for d in ducks:
		d.x = d.x0 + sin(t * 0.15 + d.ph) * 4.0
		d.z = Heightfield.river_center(d.x) + sin(t * 0.4 + d.ph) * 1.2
		d.obj.position = Vector3(d.x, Heightfield.WATER_Y + 0.08 + sin(t * 2.0 + d.ph) * 0.02, d.z)
		d.obj.rotation.y = (PI / 2.0 if cos(t * 0.15 + d.ph) > 0.0 else -PI / 2.0) + (t * 6.0 if d.peck > 0.0 else 0.0)
		d.peck -= dt
	for c in chickens:
		c.ph += dt
		var tx: float = c.home.x + sin(c.ph * 0.3) * 1.5
		var tz: float = c.home.y + cos(c.ph * 0.23) * 1.2
		var dx: float = tx - c.x
		var dz: float = tz - c.z
		c.x += dx * dt * 0.8; c.z += dz * dt * 0.8
		if Vector2(dx, dz).length() > 0.05: c.yaw = atan2(dx, dz)
		c.obj.position = Vector3(c.x, maxf(0.0, Heightfield.height(c.x, c.z)) + absf(sin(c.ph * 9.0)) * 0.03, c.z)
		c.obj.rotation.y = c.yaw
		c.head.position.y = 0.45 - (0.12 if sin(c.ph * 3.0) > 0.7 or c.peck > 0.0 else 0.0)
		c.peck -= dt

func _process_wildlife(dt: float) -> void:
	var pp: Vector3 = game.player.pos
	var me := Vector2(pp.x, pp.z)
	for b in boars:
		# amble to a spot in the woods, root about there for a while, then pick another; trot off if you come close
		b.full -= dt
		var tempted: bool = int(game.state.inventory.get("acorn", 0)) > 0 and b.full <= 0.0 and b.pos.distance_to(me) < 7.0
		if tempted and b.pos.distance_to(me) > 1.4:   # it smells the chestnuts: comes over and stops in front of you
			b.goal = b.c + (me + (b.pos - me).normalized() * 1.2 - b.c).limit_length(b.r + 3.0); b.wait = 2.0
		var to: Vector2 = b.goal - b.pos
		var scared: bool = b.pos.distance_to(me) < 4.0 and not tempted and b.full <= 0.0
		if scared and b.wait > -10.0:
			var away: Vector2 = (b.pos - me).normalized()
			b.goal = b.c + (b.pos - b.c + away * 5.0).limit_length(b.r); b.wait = 0.0
		if tempted and b.pos.distance_to(me) <= 1.4:
			b.yaw = lerp_angle(b.yaw, atan2(me.x - b.pos.x, me.y - b.pos.y), minf(1.0, dt * 4.0)); to = Vector2.ZERO
		elif to.length() > 0.15:
			var sp := 1.6 if scared else (0.9 if tempted else 0.45)
			b.pos += to.normalized() * minf(to.length(), sp * dt)
			b.yaw = lerp_angle(b.yaw, atan2(to.x, to.y), minf(1.0, dt * 4.0))
		else:
			b.wait -= dt
			if b.wait <= 0.0:
				var a := randf() * TAU; var r: float = sqrt(randf()) * b.r
				b.goal = b.c + Vector2(cos(a), sin(a)) * r; b.wait = randf_range(3.0, 8.0)
		var moving: bool = to.length() > 0.15
		b.obj.position = Vector3(b.pos.x, Heightfield.height(b.pos.x, b.pos.y) + (absf(sin(t * 9.0)) * 0.03 if moving else 0.0), b.pos.y)
		b.obj.rotation.y = b.yaw
		b.head.rotation.x = 0.0 if moving else 0.35 + 0.12 * sin(t * 4.0 + b.ph)   # nose down, rooting
	for c in cats:
		c.tail.rotation.y = sin(t * 1.3 + c.ph) * 0.5
		var near: bool = Vector2(c.obj.position.x, c.obj.position.z).distance_to(me) < 4.0
		var look: float = wrapf(atan2(pp.x - c.obj.position.x, pp.z - c.obj.position.z) - c.yaw, -PI, PI) if near else sin(t * 0.2 + c.ph) * 0.4
		c.head.rotation.y = lerp_angle(c.head.rotation.y, clampf(look, -1.1, 1.1), minf(1.0, dt * 3.0))
		c.head.rotation.x = -0.25 if c.peck > 0.0 else 0.0   # eyes closed in bliss, as it were
		c.peck -= dt
	for c in crows:
		var spots: Array = c.spots
		if c.fly < 0.0:
			if c.pos.distance_to(me) < 4.5:   # off to another of the fields
				c.from = c.obj.position
				var j := (int(c.spot) + 1 + randi() % maxi(1, spots.size() - 1)) % spots.size()
				c.spot = j; c.home = Vector2(spots[j][0], spots[j][1]) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)); c.pos = c.home
				c.to = Vector3(c.home.x, Heightfield.height(c.home.x, c.home.y), c.home.y)
				c.fly = 0.0
			else:   # hop and peck
				c.ph += dt
				if fmod(c.ph, 2.2) < dt: c.yaw += randf_range(-1.2, 1.2)
				var hop := maxf(0.0, sin(c.ph * 7.0)) * 0.06 if fmod(c.ph, 2.2) < 0.5 else 0.0
				c.pos += Vector2(sin(c.yaw), cos(c.yaw)) * (0.25 * dt if hop > 0.0 else 0.0)
				c.pos = c.home + (c.pos - c.home).limit_length(1.6)
				c.obj.position = Vector3(c.pos.x, Heightfield.height(c.pos.x, c.pos.y) + hop, c.pos.y)
				c.obj.rotation = Vector3(0.35 if fmod(c.ph, 2.2) > 1.6 else 0.0, c.yaw, 0)
				for w in [c.obj.get_node("wing0"), c.obj.get_node("wing2")]: w.rotation.z = 0.0
		else:
			c.fly += dt / maxf(1.0, (c.to - c.from).length() / 7.0)
			var f: float = minf(c.fly, 1.0)
			var p: Vector3 = c.from.lerp(c.to, f) + Vector3(0, sin(f * PI) * 6.0, 0)
			var d: Vector3 = c.to - c.from
			c.obj.position = p; c.obj.rotation = Vector3(0, atan2(d.x, d.z), 0)
			c.obj.get_node("wing0").rotation.z = sin(t * 15.0) * 0.7; c.obj.get_node("wing2").rotation.z = -sin(t * 15.0) * 0.7
			if c.fly >= 1.0: c.fly = -1.0; c.yaw = atan2(d.x, d.z)
