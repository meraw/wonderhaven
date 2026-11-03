extends SceneTree
## Look-development renders of the cast in the real village lighting, for comparing face and outline styles.
## ./lookdev.sh out.png --view=lineup|faces [--face=bean|painted] [--outline=0|1]

func _initialize() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# The scene is built by a separate script so it compiles after the Data autoload exists.
	var scene = load("res://tests/lookdev_scene.gd").new()
	await scene.run(self, args)
	root.get_texture().get_image().save_png(args.get("out", "/tmp/lookdev.png"))
	quit()
