extends Node3D

@export var car_scene: PackedScene
@export var orbit_speed: float = 0.5 # Radians per second

var camera_pivot_y: Node3D

func _ready() -> void:
	_setup_environment()
	_create_chessboard()
	_spawn_car()
	_setup_camera()

func _process(delta: float) -> void:
	if camera_pivot_y:
		camera_pivot_y.rotate_y(orbit_speed * delta)

func _setup_environment() -> void:
	# Add a light so we can see the scene
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -45, 0)
	light.shadow_enabled = true
	add_child(light)

func _create_chessboard() -> void:
	var board_root = Node3D.new()
	board_root.name = "Chessboard"
	add_child(board_root)
	
	var marble_mat = StandardMaterial3D.new()
	marble_mat.albedo_color = Color(0.9, 0.9, 0.9) # Light marble
	marble_mat.roughness = 0.05 # Highly reflective
	
	var mahogany_mat = StandardMaterial3D.new()
	mahogany_mat.albedo_color = Color(0.3, 0.1, 0.05) # Dark mahogany
	mahogany_mat.roughness = 0.1 # Reflective, but slightly less than marble
	
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	
	# Create 10x10 grid (from -5 to +5 on X and Z)
	for x in range(-5, 5):
		for z in range(-5, 5):
			var tile = MeshInstance3D.new()
			tile.mesh = mesh
			# Center the tiles properly
			tile.position = Vector3(x + 0.5, 0, z + 0.5)
			
			if (x + z) % 2 == 0:
				tile.material_override = marble_mat
			else:
				tile.material_override = mahogany_mat
				
			board_root.add_child(tile)

func _spawn_car() -> void:
	if car_scene:
		var car_instance = car_scene.instantiate()
		add_child(car_instance)

func _setup_camera() -> void:
	camera_pivot_y = Node3D.new()
	camera_pivot_y.name = "CameraOrbitY"
	add_child(camera_pivot_y)
	
	var camera_pivot_x = Node3D.new()
	camera_pivot_x.name = "CameraOrbitX"
	# 33 degrees elevation
	camera_pivot_x.rotation_degrees.x = -33
	camera_pivot_y.add_child(camera_pivot_x)
	
	var camera = Camera3D.new()
	# 10m distance
	camera.position.z = 10
	camera_pivot_x.add_child(camera)
