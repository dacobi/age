extends Node3D

func _ready():
	# Keep background black behind the canvas layer (for the 3D scene)
	var env = $WorldEnvironment.environment
	env.background_mode = Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color.BLACK)
	$DirectionalLight3D.visible = false
	
	# Start loading cars.lua via the global LoadingScreen
	get_node("/root/LoadingScreen").start_loading("cars.lua")
