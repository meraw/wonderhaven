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
