extends RefCounted
## Lost things look like what they are, in every place: Pierina's cuckoo clock is a clock lying in the mud, not a
## bunch of keys, and an unnamed lost thing is the same thing before you pick it up (its model) as after (its name).
var t

func test_every_look_has_a_model():
	for look in Props.LOST_LOOKS:
		var o: Node3D = Props.lost_thing(look)
		t.ok(o.find_children("*", "MeshInstance3D", true, false).size() > 0, "a %s is drawn" % look)
		var size := _size(o)
		t.ok(size.x < 2.2 and size.z < 2.2 and size.y < 0.9, "a %s is the size of a %s (%s)" % [look, look, size])
		o.free()

func test_names_say_what_things_look_like():
	var want := {"Pierina's cuckoo clock, still cuckooing": "clock", "Rina's garden gnome": "gnome", "Wanda's trophy: two little gold dancers": "trophy",
		"Primo's race photo": "photo", "Mattia's Walkman, full of river": "walkman", "Tullio's oar": "oar", "one of Ines's runaway logs": "log",
		"the Sindaco's reading glasses": "glasses", "a bunch of keys": "keys", "a dog's ball": "ball", "a single glove": "glove",
		"a phone card with 200 lire left on it": "card", "a Walkman with a tape of Christmas songs": "walkman", "a felt hat, a bit flattened": "hat",
		"yesterday's newspaper, forecasting fog": "newspaper", "an umbrella (another one)": "umbrella", "a briefcase full of crosswords": "briefcase"}
	for name in want: t.eq(WorldActions.look_for(name), want[name], name)

func test_lost_things_in_every_place():
	var places: Array = Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)
	for id in places:
		Data.use_island(id)
		for n in Data.layout.nodes:
			if n.kind != "fragment": continue
			var look := WorldActions.lost_look(n)
			t.ok(Props.LOST_LOOKS.has(look), "%s: %s has a model (%s)" % [id, n.id, look])
			t.eq(look, n.get("look", WorldActions.look_for(WorldActions.lost_name(n))), "%s: %s looks like what it's called" % [id, n.id])
			if n.has("name"): t.ok(look != "keys" or WorldActions.lost_name(n).contains("key"), "%s: %s (%s) isn't drawn as a bunch of keys" % [id, n.id, n.name])
	Data.use_island("hearthglow")
	# Monteforchetta: the first lost thing out is the Sindaco's glasses, the one he asks for; the rest come after
	var f0 := Data.node_def("frag0")
	t.eq(WorldActions.lost_name(f0), "the Sindaco's reading glasses", "frag0 is the Sindaco's glasses")
	t.eq(WorldActions.lost_look(f0), "glasses", "...and looks like a pair of glasses")
	for n in Data.layout.nodes.filter(func(x): return x.kind == "fragment" and x.id != "frag0"):
		t.eq(String(n.get("after", "")), "tool", "%s waits until the glasses are found" % n.id)

static func _size(o: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null:
			if p is Node3D: xf = (p as Node3D).transform * xf
			if p == o: break
			p = p.get_parent()
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	return box.size

func test_a_particular_lost_thing_turns_up_once():
	var places: Array = Data.islands.filter(func(i): return Data.has_island(i.id)).map(func(i): return i.id)
	for id in places:
		Data.use_island(id)
		for n in Data.layout.nodes:
			if n.kind != "fragment": continue
			var particular: bool = n.has("name") or WorldActions.lost_name(n) == WorldActions.LOST[0]
			if particular: t.ok(not WorldActions.regrows(n), "%s, %s (%s) is found once, not every day" % [id, n.id, WorldActions.lost_name(n)])
	Data.use_island("hearthglow")
	var glasses: Array = Data.layout.nodes.filter(func(n): return n.kind == "fragment" and WorldActions.lost_name(n) == WorldActions.LOST[0])
	t.eq(glasses.size(), 1, "one pair of the Sindaco's glasses in Monteforchetta")
