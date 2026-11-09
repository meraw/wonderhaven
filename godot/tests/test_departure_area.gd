extends RefCounted
var t

const PLATFORM := [5.0, -44.4, 34.0, -40.7]

func test_on_the_platform_the_departure_is_where_you_stand():
	t.eq(WorldActions.area_point(PLATFORM, Vector2(7.5, -43.8)), Vector2(7.5, -43.8), "at the west end, by the track")
	t.eq(WorldActions.area_point(PLATFORM, Vector2(30.0, -41.0)), Vector2(30.0, -41.0), "at the far end, by the wall")

func test_off_the_platform_it_is_the_nearest_bit_of_platform():
	t.eq(WorldActions.area_point(PLATFORM, Vector2(19.0, -37.0)), Vector2(19.0, -40.7), "behind it: the platform's back edge")
	t.eq(WorldActions.area_point(PLATFORM, Vector2(0.0, -42.0)), Vector2(5.0, -42.0), "past its west end: the end")
	t.eq(WorldActions.area_point([34.0, -40.7, 5.0, -44.4], Vector2(40.0, -50.0)), Vector2(34.0, -44.4), "the corners can be given either way round")

func test_a_villager_you_face_close_by_still_comes_before_the_train():
	var train := Prompts.score(0.0, 1.0, -0.5)
	var paletta_close := Prompts.score(1.0, 1.0, 0.6)
	var paletta_far := Prompts.score(2.0, 0.9, 0.6)
	var sign_beside := Prompts.score(1.2, 1.0, 0.0)
	t.ok(paletta_close < train, "Paletta at arm's length, facing him: talk to him")
	t.ok(train < paletta_far, "Paletta down the platform: the train")
	t.ok(train < sign_beside, "a sign a step away doesn't hide the train")
