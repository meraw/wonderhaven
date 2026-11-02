extends SceneTree
## Headless test runner: godot --headless --path godot -s res://tests/run_tests.gd
## Runs every test_* method in tests/test_*.gd and exits non-zero on failure.

var failures := 0
var passes := 0
var current := ""

func _initialize() -> void:
	# Autoloads are not ready in -s scripts until the first frame, so load Data ourselves if needed.
	await process_frame
	# Load every game script so parse errors anywhere fail the run.
	for path in _scripts("res://scripts"):
		var sc = load(path)
		if sc == null: failures += 1; print("FAIL could not load ", path)
	var dir := DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"): files.append(f)
	files.sort()
	for f in files:
		var script: Script = load("res://tests/" + f)
		var inst = script.new()
		inst.set("t", self)
		for m in inst.get_method_list():
			if not String(m.name).begins_with("test_"): continue
			current = "%s › %s" % [f.get_basename(), m.name]
			var before := failures
			await inst.call(m.name)
			if failures == before:
				passes += 1
				print("ok   ", current)
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)

func _scripts(root: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(root)
	if d == null: return out
	for f in d.get_files():
		if f.ends_with(".gd"): out.append(root + "/" + f)
	for sub in d.get_directories(): out += _scripts(root + "/" + sub)
	return out

func ok(cond: bool, msg: String = "") -> void:
	if not cond:
		failures += 1
		print("FAIL ", current, " — ", msg)

func eq(a, b, msg: String = "") -> void:
	ok(a == b, "%s (expected %s, got %s)" % [msg, str(b), str(a)])
