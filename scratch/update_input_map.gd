extends SceneTree

func _init():
	# Add actions if they don't exist
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	
	# Accelerate
	var key_up = InputEventKey.new()
	key_up.keycode = KEY_UP
	InputMap.action_add_event("accelerate", key_up)
	
	var joy_rt = InputEventJoypadMotion.new()
	joy_rt.axis = JOY_AXIS_TRIGGER_RIGHT
	joy_rt.axis_value = 1.0
	InputMap.action_add_event("accelerate", joy_rt)
	
	# Brake
	var key_down = InputEventKey.new()
	key_down.keycode = KEY_DOWN
	InputMap.action_add_event("brake", key_down)
	
	var joy_lt = InputEventJoypadMotion.new()
	joy_lt.axis = JOY_AXIS_TRIGGER_LEFT
	joy_lt.axis_value = 1.0
	InputMap.action_add_event("brake", joy_lt)
	
	# Steer Left
	var key_left = InputEventKey.new()
	key_left.keycode = KEY_LEFT
	InputMap.action_add_event("steer_left", key_left)
	
	var joy_left = InputEventJoypadMotion.new()
	joy_left.axis = JOY_AXIS_LEFT_X
	joy_left.axis_value = -1.0
	InputMap.action_add_event("steer_left", joy_left)
	
	# Steer Right
	var key_right = InputEventKey.new()
	key_right.keycode = KEY_RIGHT
	InputMap.action_add_event("steer_right", key_right)
	
	var joy_right = InputEventJoypadMotion.new()
	joy_right.axis = JOY_AXIS_LEFT_X
	joy_right.axis_value = 1.0
	InputMap.action_add_event("steer_right", joy_right)
	
	ProjectSettings.save()
	print("Input Map updated!")
	quit()
