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
	light.light_energy = 0.5 # Reduced energy
	add_child(light)
	
	# Find WorldEnvironment to tweak bloom and tonemapping
	var env_node = find_child("WorldEnvironment", true, false)
	if not env_node:
		# Also check parent just in case this script is attached deeper
		if get_parent() and get_parent().has_node("WorldEnvironment"):
			env_node = get_parent().get_node("WorldEnvironment")
			
	if env_node and env_node.environment:
		var env = env_node.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.9
		env.glow_intensity = 0.4
		env.glow_bloom = 0.1
		env.glow_strength = 0.8

func _create_chessboard() -> void:
	var board_root = Node3D.new()
	board_root.name = "Chessboard"
	add_child(board_root)
	
	var marble_mat = StandardMaterial3D.new()
	marble_mat.albedo_color = Color(0.9, 0.9, 0.9) # Light marble
	marble_mat.roughness = 0.05 # Highly reflective
	
	var piano_black_mat = StandardMaterial3D.new()
	piano_black_mat.albedo_color = Color(0.02, 0.02, 0.02) # Piano black
	piano_black_mat.roughness = 0.02 # Highly reflective
	
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
				tile.material_override = piano_black_mat
				
			board_root.add_child(tile)

func _spawn_car() -> void:
	if car_scene:
		var car_instance = car_scene.instantiate()
		
		# Disable processing so physics/FMOD don't run in the background
		car_instance.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Explicitly remove the CarSetup script if it exists
		_remove_setup_script(car_instance)
		
		car_instance.visible = false
		add_child(car_instance)
		
		# Wait 2 frames for CSG nodes to generate their meshes and correct AABBs
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Dynamically align the car's wheels to rest perfectly on the floor
		_align_car_to_floor(car_instance)
		car_instance.visible = true

func _remove_setup_script(node: Node) -> void:
	var script = node.get_script()
	if script and ("setup_car.gd" in script.resource_path or "lemans_car.gd" in script.resource_path):
		node.set_script(null)
	
	for child in node.get_children():
		_remove_setup_script(child)

func _align_car_to_floor(car_instance: Node3D) -> void:
	# Calculate the lowest point of the car's visual meshes
	var min_y = _get_lowest_y(car_instance, Transform3D())
	
	# If min_y is valid, offset the car so its lowest point rests at y = 0
	if min_y < 99999.0:
		car_instance.position.y = -min_y

func _get_lowest_y(node: Node, current_transform: Transform3D) -> float:
	var lowest = 99999.0
	
	# Skip CSGShape3D nodes that are children of another CSGShape3D
	# because their geometry is already baked into the parent's AABB
	if node is CSGShape3D and node.get_parent() is CSGShape3D:
		return lowest
	
	if node is GeometryInstance3D and node.visible:
		var aabb = node.get_aabb()
		for i in range(8):
			var corner = current_transform * aabb.get_endpoint(i)
			if corner.y < lowest:
				lowest = corner.y
				
	for child in node.get_children():
		var child_transform = current_transform
		if child is Node3D and child.visible:
			child_transform = current_transform * child.transform
		var child_lowest = _get_lowest_y(child, child_transform)
		if child_lowest < lowest:
			lowest = child_lowest

	return lowest

func _setup_camera() -> void:
	camera_pivot_y = Node3D.new()
	camera_pivot_y.name = "CameraOrbitY"
	add_child(camera_pivot_y)
	
	var camera_pivot_x = Node3D.new()
	camera_pivot_x.name = "CameraOrbitX"
	# 22.5 degrees elevation
	camera_pivot_x.rotation_degrees.x = -22.5
	camera_pivot_y.add_child(camera_pivot_x)
	
	var camera = Camera3D.new()
	# 7.5m distance
	camera.position.z = 7.5
	camera_pivot_x.add_child(camera)
