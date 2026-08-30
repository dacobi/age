extends Node

@export var car_scene: PackedScene
@export var population_size: int = 3
@export var mutation_rate: float = 0.05
@export var track_path: Path3D

var ai_brain_driver_script = preload("res://ai_brain_driver.gd")

var active_drivers: Array = []
var saved_car_genes: Array = []
var generation: int = 1
var all_time_best_fitness: float = 0.0
var checkpoints_spawned := false
var checkpoint_materials: Array = []

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	
	if DisplayServer.get_name() == "headless":
		print("HEADLESS MODE DETECTED! Engaging Turbo Training...")
		Engine.time_scale = 10.0 
		Engine.physics_ticks_per_second = 600 # Scale ticks by 10x to maintain accurate 60hz physics at 10x speed!
		Engine.max_fps = 1000
		
		# Delete ImGui entirely in headless mode to prevent DeltaTime=0 crashes
		var imgui = get_node_or_null("/root/ImGuiRoot")
		if imgui:
			imgui.queue_free()
	

	if not car_scene:
		car_scene = preload("res://lemans_car.tscn")
		
	if not track_path:
		track_path = get_parent().get_node_or_null("Path3D")
		
	call_deferred("start_first_generation")



func spawn_checkpoints():
	if checkpoints_spawned or not track_path:
		return
	checkpoints_spawned = true
	var track_length = track_path.curve.get_baked_length()
	
	var num_checkpoints = 100
	for i in range(num_checkpoints):
		var cp = Area3D.new()
		cp.name = "Checkpoint_" + str(i)
		var offset = track_length * (float(i+1) / float(num_checkpoints))
		var t = track_path.global_transform * track_path.curve.sample_baked_with_rotation(offset, false, true)
		cp.global_transform = t
		
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(100.0, 15.0, 5.0)
		col.shape = box
		cp.add_child(col)
		
		# Holographic Hovering Beam Visual
		var beam = MeshInstance3D.new()
		var beam_mesh = BoxMesh.new()
		beam_mesh.size = Vector3(100.0, 4.0, 4.0)
		beam.mesh = beam_mesh
		beam.position = Vector3(0, 60.0, 0) # Hover 60 meters above the track
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.1, 0.8, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.1, 0.8)
		mat.emission_energy_multiplier = 6.0
		beam.material_override = mat
		
		cp.add_child(beam)
		
		# Set collision to mask 2 (Car layer) so it detects the cars
		cp.collision_layer = 0
		cp.collision_mask = 2
		
		checkpoint_materials.append(mat)
		track_path.add_child(cp)
		
		# Connect the race logic signals
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(i))

func _on_checkpoint_body_entered(body: Node3D, cp_index: int) -> void:
	for driver in active_drivers:
		if driver.car == body:
			var target = driver.checkpoints_passed % 100
			var diff = (cp_index - target + 100) % 100
			if is_reverse_race:
				target = 99 - (driver.checkpoints_passed % 100)
				diff = (target - cp_index + 100) % 100
				
			if diff == 0:
				driver.checkpoints_passed += 1
				driver.time_since_last_checkpoint = 0.0
				print("Car ", driver.car.name, " cleared Checkpoint ", cp_index, "! (Total: ", driver.checkpoints_passed, ")")
			elif diff > 0 and diff < 50:
				print("Car ", driver.car.name, " skipped checkpoint ", target, " (hit ", cp_index, ") - Teleporting back!")
				var track_len = track_path.curve.get_baked_length()
				var offset_target = (float(target) / 100.0) * track_len
				var safe_offset = fmod(offset_target - 20.0 + track_len, track_len)
				if is_reverse_race:
					safe_offset = fmod(offset_target + 20.0 + track_len, track_len)
				var t = track_path.global_transform * track_path.curve.sample_baked_with_rotation(safe_offset, true, true)
				if is_reverse_race:
					t = t.rotated_local(Vector3.UP, PI)
				t.origin.y += 1.0
				driver.car.global_transform = t
				driver.car.linear_velocity = Vector3.ZERO
				driver.car.angular_velocity = Vector3.ZERO
				driver.car.sleeping = false
				driver.time_since_last_checkpoint = 0.0
			else:
				# diff >= 50 means it hit an old checkpoint behind it (e.g. driving backwards). Ignore.
				pass
			break

func _physics_process(delta: float) -> void:
	if active_drivers.is_empty():
		return
	
	var all_crashed = true
	
	for driver in active_drivers:
		if not driver.crashed:
			all_crashed = false
			
	if all_crashed:
		print("AI crashed or stalled! Respawning AI for the race...")
		advance_generation()
	else:
		update_checkpoint_visuals()

func update_checkpoint_visuals() -> void:
	if checkpoint_materials.is_empty():
		return
		
	# Reset all to magenta
	for mat in checkpoint_materials:
		mat.albedo_color = Color(1.0, 0.0, 1.0, 0.4)
		mat.emission = Color(1.0, 0.0, 1.0)
		mat.emission_energy_multiplier = 0.8
		
	# Highlight the TARGET checkpoint for each active driver
	for driver in active_drivers:
		if not driver.crashed:
			var cp_index = driver.checkpoints_passed % 100
			if is_reverse_race:
				cp_index = 99 - cp_index
			if cp_index < checkpoint_materials.size():
				var mat = checkpoint_materials[cp_index]
				mat.albedo_color = Color(0.0, 1.0, 1.0, 0.4)
				mat.emission = Color(0.0, 1.0, 1.0)
				mat.emission_energy_multiplier = 5.0

func _hide_meshes_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		node.visible = false
	for child in node.get_children():
		_hide_meshes_recursive(child)

func start_first_generation() -> void:
	# get_tree().debug_collisions_hint = true
	spawn_checkpoints()
	
	var loaded_weights = load_brain_from_file("res://assets/brain/best_brain.json")
	if loaded_weights and loaded_weights.size() != 189:
		print("Found outdated brain weights (size mismatch).")
		loaded_weights = null
	if loaded_weights != null:
		print("Found saved brain! Spawning ", population_size, " AI racers...")
		for i in range(population_size):
			spawn_car(loaded_weights, i)
	else:
		print("No saved brain found. Spawning untrained AI.")
		for i in range(population_size):
			spawn_car(null, i)

func spawn_car(brain_weights, index: int) -> void:
	var car = car_scene.instantiate()
	car.name = "Genetic_AI_Car_" + str(index + 1)
	car.set("is_ai_controlled", true)
	
	car.continuous_cd = true
	add_child(car)
	
	# Keep AI on Layer 1 (collide with world and player) AND Layer 2 (trigger checkpoints)
	car.collision_layer = 3 # Binary 11 = Layer 1 and 2
	car.collision_mask = 3  # Binary 11 = Layer 1 and 2
	
	var combiner = car.get_node_or_null("LeMansCombiner")
	if combiner:
		var main_body = combiner.get_node_or_null("MainBody")
		if main_body and main_body.material:
			var colors = [Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0), Color(0.0, 0.0, 1.0)]
			if index < colors.size():
				main_body.material.albedo_color = colors[index]
	
	
	var spawn_offset = 15.0 - 25.0
	var track_len = 4500.0
	var spawn_t = Transform3D()
	if track_path:
		track_len = track_path.curve.get_baked_length()
		var real_offset = fmod(spawn_offset + track_len, track_len)
		spawn_t = track_path.global_transform * track_path.curve.sample_baked_with_rotation(real_offset, true, true)
		
		var right_vec = spawn_t.basis.x.normalized()
		
		# Distribute them horizontally in a single line across 4 evenly spaced 25m lanes
		# AI takes lanes 0, 1, 2 (-37.5, -12.5, +37.5) [Swapped with player]
		var horiz_offset = (float(index) - 1.5) * 25.0
		if index == 2:
			horiz_offset = 37.5
		spawn_t.origin += right_vec * horiz_offset
		
		if is_reverse_race:
			spawn_t = spawn_t.rotated_local(Vector3.UP, PI)
			
		car.global_transform = spawn_t
		car.global_position.y += 0.5 # Drop slightly
		
	# Removed collision exceptions so ALL cars can collide with each other!
	
	var brain = CarBrain.new()
	brain.name = "CarBrain"
	car.add_child(brain)
	if brain_weights != null:
		brain.set_weights(brain_weights)
		
	var driver = Node.new()
	driver.set_script(ai_brain_driver_script)
	driver.car = car
	driver.brain = brain
	driver.track_path = track_path
	
	if track_path:
		track_len = track_path.curve.get_baked_length()
		# Since we moved the AI cars 25 meters back (from offset 15 to -10),
		# they now start BEFORE the finish line (Checkpoint 99).
		driver.checkpoints_passed = 99 if not is_reverse_race else 0
		driver.accumulated_progress = -10.0
		
	car.add_child(driver)
	
	active_drivers.append(driver)

func reset_race() -> void:
	for driver in active_drivers:
		if driver.car != null:
			var car = driver.car
			if car.get_parent():
				car.get_parent().remove_child(car)
			car.queue_free()
	
	active_drivers.clear()
	start_first_generation()

func advance_generation() -> void:
	reset_race()

func mutate(weights: PackedFloat32Array) -> PackedFloat32Array:
	for i in range(weights.size()):
		if randf() < mutation_rate:
			weights[i] += randf_range(-0.2, 0.2)
	return weights

func save_brain_to_file(weights: PackedFloat32Array, path: String) -> void:
	var arr = []
	for w in weights:
		arr.append(w)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(arr))
		file.close()

func load_brain_from_file(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.parse_string(content)
		if json != null and json is Array:
			var weights = PackedFloat32Array()
			weights.resize(json.size())
			for i in range(json.size()):
				weights[i] = float(json[i])
			return weights
	return null
