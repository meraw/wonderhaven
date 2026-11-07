class_name Controls
## Input actions with keyboard and gamepad defaults, created at runtime so they can be remapped and saved.

const DEFAULTS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "interact": [KEY_E], "build": [KEY_B], "inventory": [KEY_I], "journal": [KEY_J],
	"map": [KEY_M], "progress": [KEY_P], "wardrobe": [KEY_C], "pause": [KEY_ESCAPE], "rotate": [KEY_R], "remove": [KEY_DELETE, KEY_BACKSPACE],
	"draft_only": [KEY_G], "cam_left": [KEY_Q], "cam_right": [KEY_Z], "recolor": [KEY_T], "move_piece": [KEY_N],
	"plan_next": [KEY_V], "bike": [KEY_F], "bell": [KEY_H],
}
const LABELS := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right", "sprint": "Run", "jump": "Hop",
	"interact": "Interact", "build": "Build mode", "inventory": "Bag", "journal": "Quest journal", "map": "World map", "progress": "Approval rating",
	"wardrobe": "Wardrobe", "pause": "Pause / back", "rotate": "Rotate piece", "remove": "Remove piece", "draft_only": "Draft only (plan without building)",
	"cam_left": "Turn camera left", "cam_right": "Turn camera right", "recolor": "Recolour piece", "move_piece": "Move piece",
	"plan_next": "Pick the plan's next piece",
	"bike": "Get on or off the bike", "bell": "Ring the bike's bell",
}
const PAD := {"interact": JOY_BUTTON_A, "pause": JOY_BUTTON_START, "build": JOY_BUTTON_X, "journal": JOY_BUTTON_Y, "map": JOY_BUTTON_BACK,
	"rotate": JOY_BUTTON_RIGHT_SHOULDER, "remove": JOY_BUTTON_LEFT_SHOULDER, "inventory": JOY_BUTTON_DPAD_UP, "progress": JOY_BUTTON_DPAD_DOWN, "jump": JOY_BUTTON_B,
	"bike": JOY_BUTTON_LEFT_STICK, "bell": JOY_BUTTON_DPAD_LEFT}

static func setup(custom: Dictionary = {}) -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action): InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		var keys: Array = custom.get(action, DEFAULTS[action])
		for k in keys:
			var ev := InputEventKey.new(); ev.physical_keycode = int(k); InputMap.action_add_event(action, ev)
		if PAD.has(action):
			var jb := InputEventJoypadButton.new(); jb.button_index = PAD[action]; InputMap.action_add_event(action, jb)
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new(); jm.axis = pair[1]; jm.axis_value = pair[2]; InputMap.action_add_event(pair[0], jm)

static func key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(code)
	return "—"

static func keys_of(action: String) -> Array:
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey: out.append(ev.physical_keycode)
	return out

## Bind `code` as the primary key of `action`, removing it from any other action.
static func rebind(current: Dictionary, action: String, code: int) -> Dictionary:
	var out := {}
	for a in DEFAULTS:
		var keys: Array = (current.get(a, DEFAULTS[a]) as Array).duplicate()
		keys.erase(code)
		out[a] = keys
	var mine: Array = out[action]
	mine.push_front(code)
	out[action] = mine.slice(0, 2)
	return out
