extends SceneTree
func _initialize() -> void:
	await process_frame
	load("res://tests/zz_dbg_body.gd").new().run()
	quit()
