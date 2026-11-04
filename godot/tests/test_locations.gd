extends RefCounted
## Location packs (data/locations/<id>/ and scripts/locations/<id>.gd): they merge into the shared lists without
## replacing anything, their scripts shape the ground, and every pack follows the id rules that keep parallel work
## from colliding.
var t

func test_merge_adds_without_replacing():
	var lists := {"islands": [{"id": "hearthglow"}], "npcs": [{"id": "fern"}], "quests": [{"id": "bridge"}],
		"shops": {"fern": {"name": "old"}}, "resources": {"wood": {"name": "Wood"}}, "order": ["wood"]}
	var pack := {"location": {"name": "Porto", "x": 1, "y": 2},
		"npcs": {"npcs": [{"id": "porto_baciccia"}, {"id": "fern", "name": "impostor"}]},
		"quests": {"quests": [{"id": "porto_fish"}]},
		"shops": {"shops": {"porto_baciccia": {"name": "Focacceria"}, "fern": {"name": "new"}}},
		"resources": {"resources": {"porto_slate": {"name": "Slate"}, "wood": {"name": "Not wood"}}, "order": ["porto_slate"]}}
	Data.merge_pack(lists, "porto", pack)
	t.eq(lists.islands.size(), 2, "the pack's map entry is added")
	t.eq(lists.islands[1].id, "porto", "the map entry takes the pack's id")
	t.eq(lists.npcs.size(), 2, "a villager with a taken id is not added")
	t.eq(lists.npcs[1].island, "porto", "the pack's villagers live in its location")
	t.eq(lists.quests.size(), 2, "the pack's requests are added")
	t.eq(lists.shops.fern.name, "old", "an existing shop is never replaced")
	t.eq(lists.shops.porto_baciccia.name, "Focacceria", "the pack's shop is added")
	t.eq(lists.resources.wood.name, "Wood", "an existing material is never replaced")
	t.eq(lists.order, ["wood", "porto_slate"], "new materials join the bag order")
	Data.merge_pack(lists, "porto", pack)
	t.eq(lists.islands.size() + lists.npcs.size() + lists.quests.size(), 6, "merging twice adds nothing more")

func test_a_pack_is_loaded_and_shapes_its_ground():
	# A throwaway pack written for this test and removed afterwards.
	var id := "zz_testpack"
	var dir := "res://data/locations/" + id
	var script_path := "res://scripts/locations/%s.gd" % id
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/layout.json", FileAccess.WRITE); f.store_string(FileAccess.get_file_as_string("res://data/layout_clockwork.json")); f.close()
	f = FileAccess.open(script_path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic func height(x: float, z: float) -> float: return 0.5 + x * 0.01\nstatic func is_stream_cell(i: float, k: float) -> bool: return i == 3.0 and k == 4.0\n")
	f.close()
	t.ok(Data.location_ids().has(id), "a folder with a layout is a location pack")
	t.ok(Data.has_island(id), "the pack's layout is found")
	t.eq(Data.layout_file(id), "locations/%s/layout" % id, "its layout is read from its folder")
	Data.use_island(id)
	t.eq(Heightfield.height(10.0, 0.0), 0.6, "the pack's script shapes the ground")
	t.ok(Heightfield.is_stream_cell(3, 4) and not Heightfield.is_stream_cell(4, 4), "the pack's script says where water flows")
	Data.use_island("clockwork")
	t.ok(Heightfield.height(20, -20) > 2.0, "switching away restores the other island's ground")
	Data.use_island("hearthglow")
	DirAccess.remove_absolute(dir + "/layout.json"); DirAccess.remove_absolute(dir); DirAccess.remove_absolute(script_path)
	t.ok(not Data.location_ids().has(id), "the throwaway pack is gone again")

func test_every_pack_follows_the_rules():
	for id in Data.location_ids():
		var base := "res://data/locations/%s/" % id
		t.ok(Data.island_def(id).size() > 0, "%s has a map entry (location.json)" % id)
		for kind in ["npcs", "quests"]:
			if not FileAccess.file_exists(base + kind + ".json"): continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(base + kind + ".json"))
			for e in parsed.get(kind, []):
				t.ok(String(e.id).begins_with(id + "_"), "%s: %s id %s starts with the location id" % [id, kind, e.id])
		for n in Data.npcs.filter(func(n): return n.get("island", "") == id):
			t.ok(Data.npc_by_id[n.id] == n, "%s: villager %s is not shadowed by another" % [id, n.id])
