extends RefCounted
var t

func _deg(a: Vector3, b: Vector3) -> float: return rad_to_deg(a.angle_to(b))

func test_the_first_step_shows_the_sun_where_it_is():
	var hold := SunHold.new()
	var d := Daylight.light_dir(9.0)
	t.ok(_deg(hold.step(d, false, 0.0), d) < 0.001, "no lag on the first frame")

func test_while_the_view_is_still_the_shadows_hold_still_as_the_clock_runs():
	var hold := SunHold.new()
	var first := hold.step(Daylight.light_dir(9.0), false, 0.0)
	var changed := 0
	var shown := first
	for i in 600:
		var now := hold.step(Daylight.light_dir(9.0 + (i + 1) / 3600.0), false, 1.0 / 60.0)
		if now != shown: changed += 1
		shown = now
	t.eq(changed, 0, "ten seconds of talking at 60 frames a second: the light never moves")
	t.ok(_deg(shown, Daylight.light_dir(9.0 + 600.0 / 3600.0)) < SunHold.HOLD_DEG, "and lags the sun by less than the hold")

func test_once_the_lag_grows_past_the_hold_it_catches_up_quickly_then_holds_again():
	var hold := SunHold.new()
	var h := 9.0
	hold.step(Daylight.light_dir(h), false, 0.0)
	var dt := 1.0 / 60.0
	var moving_frames := 0
	var shown := hold.shown
	var frames := 0
	while frames < 60 * 90:
		h += dt / 60.0
		var now := hold.step(Daylight.light_dir(h), false, dt)
		if now != shown: moving_frames += 1
		shown = now
		frames += 1
	t.ok(_deg(shown, Daylight.light_dir(h)) <= SunHold.HOLD_DEG + 0.01, "after a minute and a half it is never far behind the sun")
	t.ok(moving_frames > 0, "it did catch up")
	t.ok(moving_frames < frames / 10, "but the light was moving for under a tenth of the frames (%d of %d)" % [moving_frames, frames])

func test_a_moving_view_follows_the_sun_at_once():
	var hold := SunHold.new()
	hold.step(Daylight.light_dir(9.0), false, 0.0)
	for i in 300: hold.step(Daylight.light_dir(9.0 + (i + 1) / 3600.0), false, 1.0 / 60.0)
	var now := Daylight.light_dir(9.0 + 301.0 / 3600.0)
	t.ok(_deg(hold.step(now, true, 1.0 / 60.0), now) < 0.001, "the camera moves: the held light catches up in the same frame")
	t.eq(hold.catching, false, "with nothing left to catch up")

func test_a_jump_of_the_clock_snaps_the_light_even_with_a_still_view():
	var hold := SunHold.new()
	hold.step(Daylight.light_dir(9.0), false, 0.0)
	var later := Daylight.light_dir(10.0)
	t.ok(_deg(hold.step(later, false, 1.0 / 60.0), later) < 0.001, "an hour on a bench: the shadows are where the sun is when you wake")
	var evening := Daylight.light_dir(17.0)
	t.ok(_deg(hold.step(evening, false, 0.1), evening) < 0.001, "and a save loaded at another hour")

func test_a_settling_camera_counts_as_still_and_walking_or_turning_does_not():
	var a := Transform3D(Basis(), Vector3(1, 2, 3))
	t.eq(SunHold.view_moving(a, a, 1.0 / 60.0), false, "a camera that has not moved")
	t.eq(SunHold.view_moving(a, a.translated(Vector3(0.0003, 0, 0)), 1.0 / 60.0), false, "the last millimetres of easing into the dialogue view")
	t.eq(SunHold.view_moving(a, a.translated(Vector3(0.08, 0, 0)), 1.0 / 60.0), true, "walking")
	t.eq(SunHold.view_moving(a, Transform3D(Basis(Vector3.UP, deg_to_rad(1.0)), a.origin), 1.0 / 60.0), true, "turning the camera")
	t.eq(SunHold.view_moving(a, a.translated(Vector3(5, 0, 0)), 0.0), false, "no time passed (the first frame)")
