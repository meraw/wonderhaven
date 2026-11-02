extends Node3D
## Ambient wildlife: butterflies over flowers, ducks on the river, chickens in Fern's yard (pet them, toss ducks an apple).
const P := preload("res://scripts/world/palette.gd")
var game
var t := 0.0
var butterflies: Array = []
var ducks: Array = []
var chickens: Array = []

func setup(g) -> void:
	game = g
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
	for n in 4:
		var d := Node3D.new()
		var body := P.mi(P.sphere(0.22, 10, 8), P.mat("ffffff")); body.scale = Vector3(1, 0.7, 1.3); d.add_child(body)
		d.add_child(P.mi(P.sphere(0.12, 10, 8), P.mat("3c9a4a"), Vector3(0, 0.2, 0.22)))
		var beak := P.mi(P.cone(0.04, 0.1, 6), P.mat("ffb33b"), Vector3(0, 0.18, 0.36)); beak.rotation.x = PI / 2; d.add_child(beak)
		add_child(d)
		var x0: float = [-26.0, -10.0, 14.0, 24.0][n]
		var duck := {"obj": d, "x0": x0, "ph": n * 1.7, "x": x0, "z": Heightfield.river_center(x0), "peck": 0.0}
		ducks.append(duck)
		game.add_interactable({"id": "duck%d" % n, "x": func(): return duck.x, "z": func(): return duck.z, "radius": 3.6, "object": d,
			"available": func(): return game.state.inventory.get("fruit", 0) > 0, "label": func(): return "Toss an apple to the duck", "act": func(): pet(duck, "duck")})
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
		game.add_interactable({"id": "chicken%d" % n, "x": func(): return ch.x, "z": func(): return ch.z, "radius": 1.1, "object": c, "label": func(): return "Pet the chicken", "act": func(): pet(ch, "chicken")})

func pet(a: Dictionary, kind: String) -> void:
	var s: Dictionary = game.state
	if kind == "duck": s.inventory.fruit -= 1; game.render_resources(["fruit"])
	game.effects.hearts(a.obj.position + Vector3(0, 0.6, 0), 3)
	game.sfx("squeak")
	a.peck = 1.2
	var key := "pet_%s_%d" % [kind, int(s.time.day)]
	if not s.flags.get(key, false):
		s.flags[key] = true; game.give({"spark": 2})
		game.toast("Quack! The duck does a happy little spin." if kind == "duck" else "Bawk! The chicken clucks contentedly.", "good")
	game.story.event("animal")

func _process(dt: float) -> void:
	if game == null: return
	t += dt
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
