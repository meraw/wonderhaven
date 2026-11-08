extends RefCounted
var t

func _chibi() -> Chibi:
	return Chibi.new(Data.appearance["default"])

func _run(c: Chibi, frames: int, speed: float, airborne: bool = false) -> void:
	for i in frames: c.animate(0.05, speed, airborne)

func test_easing_curves():
	t.ok(is_equal_approx(Chibi.ease_out(0.0), 0.0) and is_equal_approx(Chibi.ease_out(1.0), 1.0), "ease out runs from 0 to 1")
	t.ok(is_equal_approx(Chibi.ease_in(0.0), 0.0) and is_equal_approx(Chibi.ease_in(1.0), 1.0), "ease in runs from 0 to 1")
	t.ok(Chibi.back_out(0.7) > 1.0 and is_equal_approx(Chibi.back_out(1.0), 1.0), "back out overshoots, then settles on 1")
	t.ok(absf(Chibi.settle(3.0, 0.2, 20.0, 8.0)) < 0.001, "a squash settles within a few seconds")

func test_stopping_eases_instead_of_snapping():
	var c := _chibi()
	_run(c, 40, 1.0)
	c.animate(0.05, 0.0)
	t.ok(c.gait > 0.5, "one frame after stopping, the walk is still fading out (gait %.2f)" % c.gait)
	_run(c, 30, 0.0)
	t.ok(c.gait < 0.02, "a second and a half later the character stands (gait %.3f)" % c.gait)

func test_changing_speed_keeps_the_stride_smooth():
	var c := _chibi()
	_run(c, 40, 0.5)
	var before := c.leg_l.rotation.x
	c.animate(0.05, 1.0)
	t.ok(absf(c.leg_l.rotation.x - before) < 0.35, "speeding up doesn't make the legs jump (%.2f to %.2f)" % [before, c.leg_l.rotation.x])

func test_leaning_into_a_turn():
	var c := _chibi()
	for i in 30:
		c.rotation.y += 0.15
		c.animate(0.05, 1.0)
	t.ok(c.bank < -0.05, "turning left leans the character to its left (bank %.3f)" % c.bank)
	t.ok(c.head.rotation.y > 0.1, "the head leads into the turn (%.2f)" % c.head.rotation.y)

func test_landing_squashes_then_settles():
	var c := _chibi()
	_run(c, 10, 0.0, true)
	t.ok(c.body.scale.y > 1.0, "in the air the body stretches (%.3f)" % c.body.scale.y)
	_run(c, 1, 0.0)
	t.ok(c.body.scale.y < 0.9, "landing squashes the body (%.3f)" % c.body.scale.y)
	_run(c, 60, 0.0)
	t.ok(absf(c.body.scale.y - 1.0) < 0.02, "and it settles back (%.3f)" % c.body.scale.y)

func test_a_chop_winds_up_strikes_and_lands():
	var c := _chibi()
	_run(c, 5, 0.0)
	c.play("chop")
	var length: float = Chibi.ACTION_LENGTH["chop"]
	var raised := 0.0
	var lowest_scale := 2.0
	var struck := -10.0
	var elapsed := 0.0
	while elapsed < length:
		c.animate(0.01, 0.0)
		elapsed += 0.01
		if elapsed < length * 0.42: raised = minf(raised, c.arm_r.rotation.x)
		elif elapsed < length * 0.6: struck = maxf(struck, c.arm_r.rotation.x)
		if elapsed > length * 0.56: lowest_scale = minf(lowest_scale, c.body.scale.y)
	t.ok(raised < -2.9, "the axe goes back over the shoulder first (%.2f)" % raised)
	t.ok(struck > -0.3, "then comes down fast (%.2f)" % struck)
	t.ok(lowest_scale < 0.96, "and the body jolts on impact (%.3f)" % lowest_scale)
	t.eq(c.action, "", "the chop ends")
