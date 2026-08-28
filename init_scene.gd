extends Node3D

func _ready():
	# Keep background black behind the canvas layer (for the 3D scene)
	var env = $WorldEnvironment.environment
	env.background_mode = Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color.BLACK)
	$DirectionalLight3D.visible = false
	
	# Start loading cars.lua via the global LoadingScreen
	if not FileAccess.file_exists("res://init.lua"):
		get_node("/root/LoadingScreen").start_loading("track_editor.lua")
	else:
		# Do not load cars.lua if init.lua is handling the boot process
		pass
