extends RefCounted
## Shared runtime input map (top-down slice and isometric prototype).
## WASD/arrows stay camera-relative; each scene decides how to map them to its world.

static func ensure() -> void:
	var keys: Dictionary = {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "attack": [KEY_SPACE, KEY_J], "dash": [KEY_SHIFT], "interact": [KEY_E]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = int(key)
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("attack", mouse): InputMap.action_add_event("attack", mouse)
