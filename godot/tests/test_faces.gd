extends RefCounted
var t

func test_eyes_are_a_size_between_the_old_dots_and_the_paintover():
	for shape in Data.appearance.EYE_SHAPES:
		var size := Chibi.eye_size(shape)
		t.ok(size >= 1.4 and size <= 1.6, "%s eyes are %.2fx the old dots" % [shape, size])
	t.eq(Chibi.eye_scale("round"), 1.45, "round dot eyes at 1.45x")

func test_new_faces_get_the_eye_size():
	var c := Chibi.new(Data.appearance["default"])
	t.eq(float(c.face_mat.get_shader_parameter("eye_scale")), Chibi.eye_scale(Data.appearance["default"].eyeShape), "the face shader gets the eye size")
	c.free()

func _textures(c: Node) -> Array:
	var out: Array = []
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		var m = (mi as MeshInstance3D).material_override
		if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture != null: out.append((m as StandardMaterial3D).albedo_texture)
	return out

func test_villagers_have_bodies_of_their_own():
	var odd := Chibi.sanitize({"body": {"height": 3.0, "width": 0.1, "belly": -2}})
	t.ok(odd.body.height <= 1.12 and odd.body.width >= 0.88 and odd.body.belly == 0.0, "body shapes stay within cute limits")
	t.ok(not Chibi.sanitize({}).has("body"), "the player keeps the standard body unless they choose one")
	var shapes := {}
	for n in Data.npcs:
		if not n.has("appearance"): continue
		var c := Chibi.new(n.appearance)
		var s: Node3D = c.get_node("shape")
		c.animate(0.1, 1.0)
		shapes["%.2f|%.2f" % [s.scale.x, s.scale.y]] = true
		t.eq(s.scale, c.get_node("shape").scale, "%s keeps their shape while walking" % n.id)
		c.free()
	t.ok(shapes.size() >= 5, "the cast come in different builds (%d)" % shapes.size())
	var mayor: Dictionary = Data.npcs.filter(func(n): return n.id == "percival")[0]
	t.ok(float(mayor.appearance.body.belly) > 0.5, "the Sindaco has his round belly")

func test_colours_written_without_a_hash_are_kept():
	var a := Chibi.sanitize({"skin": "f2c9a0", "hairColor": "pink"})
	t.eq(a.skin, "f2c9a0", "a skin colour written without its hash is kept")
	t.eq(a.hairColor, Data.appearance["default"].hairColor, "a word that isn't a colour falls back to the default")

func test_clothes_are_cut_from_their_own_fabric():
	t.ok(Palette.real, "with realistic materials")
	var jeans := Chibi.new({"bottom": "jeans", "shoes": "boots"})
	var tex := _textures(jeans)
	t.ok(tex.has(Palette.material_texture("denim_albedo")), "jeans are denim")
	t.ok(tex.has(Palette.material_texture("leather_albedo")), "boots are leather")
	jeans.free()
	var trainers := Chibi.new({"bottom": "pants", "shoes": "sneakers"})
	t.ok(not _textures(trainers).has(Palette.material_texture("denim_albedo")), "trousers aren't denim")
	trainers.free()
	t.ok(Chibi.hair_code().contains("specular_schlick_ggx") and not Chibi.hair_code().contains("RIM ="), "hair has real specular and no painted rim")

func test_colours_are_read_with_or_without_the_hash():
	var D: Dictionary = Data.appearance["default"]
	t.eq(Chibi.sanitize({"topColor": "1f2f4a"}).topColor, "1f2f4a", "a villager's colour written without the hash is kept")
	t.eq(Chibi.sanitize({"topColor": D.hatColor}).topColor, D.hatColor, "one written with it is kept too")
	t.eq(Chibi.sanitize({"topColor": "navy"}).topColor, D.topColor, "a word that isn't a colour falls back to the default")
	t.eq(Chibi.sanitize({"topColor": "1f2f4a0"}).topColor, D.topColor, "so does a code of the wrong length")
	t.eq(Color(String(Chibi.resolve(Chibi.sanitize({"topColor": "1f2f4a"})).topColor)), Color(0x1f / 255.0, 0x2f / 255.0, 0x4a / 255.0), "and it draws in that colour")
