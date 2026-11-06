class_name BusIntro
extends RefCounted
## The opening, before the letter of appointment: Aldo's old blue bus grinds up the mule track, pulls into the lay-by
## by the village gate and sways to a stop with a toot; the door hisses and you step off. Any key or a click skips it.
## The bus is the layout's first "bus" prop (Village.objects.arrivalBus), its front at its +x end.

const DRIVE := 6.5        # seconds up the track and into the lay-by
const RUN_IN := 24.0      # metres of track it climbs in that time
const WHEELBASE := 4.2

## Where the bus is `u` of the way through its drive (0..1): slowing as it pulls in, nose up on the climb.
static func bus_at(stop: Vector3, yaw: float, u: float) -> Dictionary:
	var fwd := Vector3(cos(yaw), 0.0, -sin(yaw))
	var e := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.2)
	var p: Vector3 = stop - fwd * RUN_IN * (1.0 - e)
	var hb := Heightfield.height(p.x - fwd.x * WHEELBASE / 2.0, p.z - fwd.z * WHEELBASE / 2.0)
	var hf := Heightfield.height(p.x + fwd.x * WHEELBASE / 2.0, p.z + fwd.z * WHEELBASE / 2.0)
	if u >= 1.0: hb = stop.y; hf = stop.y
	return {"pos": Vector3(p.x, (hb + hf) / 2.0, p.z), "pitch": atan2(hf - hb, WHEELBASE), "speed": 2.2 * pow(1.0 - clampf(u, 0.0, 1.0), 1.2)}

static func play(game) -> void:
	var bus: Node3D = game.village.objects.get("arrivalBus")
	if bus == null: return
	var tree: SceneTree = game.get_tree()
	var stop: Vector3 = bus.position
	var yaw: float = bus.rotation.y
	var fwd := Vector3(cos(yaw), 0.0, -sin(yaw))
	var side := Vector3(sin(yaw), 0.0, cos(yaw))   # the door side
	var length: float = float(bus.get_meta("length", 6.4))
	var door: Vector3 = stop + fwd * (length / 2.0 - 0.8) + side * 1.17
	var up := Vector3.UP
	game.set_mode("cutscene"); game.hud.visible = false
	game.player_char.visible = false
	var hint := UiTheme.label("Click or press any key to skip", 14, Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.2)); hint.add_theme_constant_override("outline_size", 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); hint.offset_left = -300; hint.offset_top = -44; hint.offset_right = -20
	game.screens.get_parent().add_child(hint)
	var cam_a: Vector3 = stop + side * 9.0 + fwd * 7.0 + up * 3.4   # by the gate, looking down the track
	var cam_b: Vector3 = stop + side * 7.5 + fwd * 3.5 + up * 2.6
	var cam_c: Vector3 = door + side * 5.2 + fwd * 1.8 + up * 2.0  # then at the door
	var t := 0.0
	var chug := 0.0
	var honked := false
	var hissed := false
	var stepped := 0.0
	var skip := false
	var walk_to: Vector3 = door + side * 2.0
	while t < DRIVE + 3.4 and not skip:
		await tree.process_frame
		var dt := minf(tree.root.get_process_delta_time(), 0.1)
		t += dt
		if t > 0.4 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			skip = true; break
		var u := t / DRIVE
		var b := bus_at(stop, yaw, u)
		var sway := 0.0
		if u >= 1.0: sway = -0.045 * exp(-(t - DRIVE) * 3.0) * sin((t - DRIVE) * 9.0)   # nose dips as it brakes, rocks back
		bus.position = b.pos + Vector3(0, sin(t * 21.0) * 0.012 * minf(1.0, b.speed), 0)
		bus.rotation = Vector3(0.0, yaw, b.pitch + sway)
		chug -= dt
		if chug <= 0.0 and b.speed > 0.05 and game.audio:   # the old diesel putting up the hill
			chug = 0.15; game.audio.play("thud", 38, 0.06 + 0.06 * minf(1.0, b.speed))
		if u >= 1.0 and not honked:
			honked = true
			if game.audio: game.audio.play("horn", 62, 0.2); game.audio.play("horn", 66, 0.16)
		var look: Vector3 = bus.position + up * 1.4
		var cam_p: Vector3 = cam_a.lerp(cam_b, smoothstep(0.0, 1.0, u))
		if t > DRIVE + 0.5:   # the door hisses open and you step off
			var k := smoothstep(0.0, 1.0, (t - DRIVE - 0.5) / 1.2)
			cam_p = cam_b.lerp(cam_c, k); look = look.lerp(door + side * 1.0 + up * 1.0, k)
			if not hissed:
				hissed = true
				if game.audio: game.audio.play("hiss", 84, 0.22)
				game.player.teleport(door.x + side.x * 0.4, door.z + side.z * 0.4, atan2(side.x, side.z))
				game.player_char.visible = true
			if t > DRIVE + 1.0 and stepped < 1.0:
				stepped += dt
				var dir: Vector3 = walk_to - game.player.pos
				game.player.update(dt, Vector2(0, 1) if dir.length() > 0.15 else Vector2.ZERO, false, false, atan2(-dir.x, -dir.z), true)
		game.cam.cinema = {"pos": cam_p, "look": look}
	# settle: the bus parked, you off it and facing the village gate, the camera back behind you
	bus.position = stop; bus.rotation = Vector3(0.0, yaw, 0.0)
	game.player.teleport(walk_to.x, walk_to.z, atan2(fwd.x, fwd.z))
	game.player_char.visible = true
	hint.queue_free()
	game.cam.cinema = {}
	game.cam.yaw = atan2(fwd.x, fwd.z) + PI; game.cam.snap()
	game.hud.visible = true
