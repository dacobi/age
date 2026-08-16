extends Node

@export var car_scene: PackedScene
@export var population_size: int = 4
@export var mutation_rate: float = 0.05
@export var track_path: Path3D

var ai_brain_driver_script = preload("res://ai_brain_driver.gd")

var active_drivers: Array = []
var saved_car_genes: Array = []
var generation: int = 1
var all_time_best_fitness: float = 0.0
var checkpoints_spawned := false

@onready var camera = $Camera3D if has_node("Camera3D") else Camera3D.new()
var fmod_banks: Array = []

func _ready() -> void:
	randomize()
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
	else:
		if ClassDB.class_exists("FmodServer"):
			print("Loading FMOD Banks for AI Training mode...")
			fmod_banks.append(FmodServer.load_bank("res://Audio/Master.strings.bank", 0))
			fmod_banks.append(FmodServer.load_bank("res://Audio/Master.bank", 0))
			fmod_banks.append(FmodServer.load_bank("res://Audio/Vehicles.bank", 0))
			fmod_banks.append(FmodServer.load_bank("res://Audio/SFX.bank", 0))
	
	if not has_node("Camera3D"):
		add_child(camera)
		camera.make_current()
		
	if not car_scene:
		car_scene = preload("res://lemans_car.tscn")
		
	if not track_path:
		track_path = get_parent().get_node_or_null("Path3D")
		
	call_deferred("start_first_generation")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Auto-saving before quit...")
		if not active_drivers.is_empty():
			advance_generation()
		get_tree().quit()

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
		var beam = CSGBox3D.new()
		beam.size = Vector3(100.0, 4.0, 4.0)
		beam.position = Vector3(0, 60.0, 0) # Hover 60 meters above the track
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 1.0, 0.2) # Magenta, highly transparent
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.0, 1.0) # Magenta
		mat.emission_energy_multiplier = 0.5 # Less glow
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam.material = mat
		
		cp.add_child(beam)
		
		# Set collision to mask 2 (Car layer) so it detects the cars
		cp.collision_layer = 0
		cp.collision_mask = 2
		
		track_path.add_child(cp)
		
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(i))

func _on_checkpoint_body_entered(body: Node3D, cp_index: int) -> void:
	for driver in active_drivers:
		if driver.car == body:
			if cp_index == (driver.checkpoints_passed % 100):
				var time_taken = driver.time_since_last_checkpoint
				var target_time = 0.9 # roughly 180 km/h for 45m distance
				var speed_multiplier = 1.0
				if time_taken > 0.0:
					speed_multiplier = maxf(0.5, target_time / time_taken)
					
				driver.checkpoint_speed_bonus += 500.0 * speed_multiplier
				
				driver.checkpoints_passed += 1
				driver.time_since_last_checkpoint = 0.0
				print("Car ", driver.car.name, " cleared Checkpoint ", cp_index, "! (Multiplier: ", snapped(speed_multiplier, 0.01), "x)")
			elif cp_index > driver.checkpoints_passed % 100:
				print("Car ", driver.car.name, " skipped checkpoint ", driver.checkpoints_passed % 100, " (hit ", cp_index, ")")
				driver.crashed = true
			elif cp_index < driver.checkpoints_passed % 100:
				# Just ignore it if we accidentally clip an old checkpoint due to overlap
				# print("Car ", driver.car.name, " touched old checkpoint ", cp_index)
				pass
			break

func _physics_process(delta: float) -> void:
	if active_drivers.is_empty():
		return
	
	var all_crashed = true
	var generation_finished = false
	var best_driver = null
	var highest_fitness = -999999.0
	
	for driver in active_drivers:
		if not driver.crashed:
			all_crashed = false
			if driver.checkpoints_passed >= 100:
				generation_finished = true
			if driver.fitness > highest_fitness:
				highest_fitness = driver.fitness
				best_driver = driver
			
	if best_driver and best_driver.car:
		var target_pos = best_driver.car.global_position + Vector3(0, 5, 8)
		camera.global_position = camera.global_position.lerp(target_pos, 5.0 * delta)
		camera.look_at(best_driver.car.global_position, Vector3.UP)
		
	if all_crashed or generation_finished:
		if generation_finished:
			print("A car finished the lap! Ending generation early to reward speed.")
		var true_best = -999999.0
		for driver in active_drivers:
			if driver.fitness > true_best:
				true_best = driver.fitness
		print("Generation ", generation, " finished. Best fitness: ", true_best)
		advance_generation()

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
		print("Found outdated brain weights (size mismatch). Discarding and starting from scratch.")
		loaded_weights = null
	if loaded_weights != null:
		print("Found saved brain! Resuming training...")
		spawn_car(loaded_weights, 0)
		for i in range(1, population_size):
			var clone = loaded_weights.duplicate()
			clone = mutate(clone)
			spawn_car(clone, i)
	else:
		print("No saved brain found. Starting from scratch.")
		for i in range(population_size):
			spawn_car(null, i)

func spawn_car(brain_weights, index: int) -> void:
	var car = car_scene.instantiate()
	car.name = "Genetic_AI_Car_G" + str(generation) + "_" + str(index + 1)
	car.set("is_ai_controlled", true)
	
	car.continuous_cd = true
	add_child(car)
	
	# Enable car-to-car collision for physical racing
	car.collision_layer = 2 # Car Layer
	car.collision_mask = 3  # Collide with World (1) and Cars (2)
	
	# Render the entire car just as in the race track
	# _hide_meshes_recursive(car) - Removed
	
	var spawn_offset = 0.0
	
	if track_path:
		var track_len = track_path.curve.get_baked_length()
		
		# 2x2 Grid spacing
		var row = index / 2
		var col = index % 2
		
		# Space them 10m apart per row, starting from 20.0
		var raw_offset = 20.0 - (row * 10.0)
		spawn_offset = fmod(raw_offset + (track_len * 10.0), track_len)
		
		var spawn_t = track_path.global_transform * track_path.curve.sample_baked_with_rotation(spawn_offset, true, true)
		
		var right_vec = spawn_t.basis.x.normalized()
		var horiz_offset = -4.0 if col == 0 else 4.0
		spawn_t.origin += right_vec * horiz_offset
		spawn_t.origin += spawn_t.basis.y.normalized() * 0.5 # Local UP vector spawn
		
		car.global_transform = spawn_t
	
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
	driver.generation = generation
	
	if track_path:
		var track_len = track_path.curve.get_baked_length()
		var next_cp = int(floor((spawn_offset / track_len) * 100.0))
		driver.checkpoints_passed = next_cp
		driver.accumulated_progress = spawn_offset
		
	car.add_child(driver)
	
	active_drivers.append(driver)

func advance_generation() -> void:
	for driver in active_drivers:
		saved_car_genes.append({
			"fitness": driver.fitness,
			"weights": driver.brain.get_weights()
		})
		if driver.car != null:
			driver.car.queue_free()
		
	active_drivers.clear()
	saved_car_genes.sort_custom(func(a, b): return a["fitness"] > b["fitness"])
	
	var best_this_gen = saved_car_genes[0]
	if best_this_gen["fitness"] > all_time_best_fitness:
		all_time_best_fitness = best_this_gen["fitness"]
		print("New ALL-TIME HIGH SCORE: ", all_time_best_fitness)
		save_brain_to_file(best_this_gen["weights"], "res://assets/brain/best_brain.json")
		
	var next_generation_pool = []
	var elite_count = int(population_size * 0.2)
	if elite_count < 1 and population_size >= 1: elite_count = 1
	
	# Keep the elite(s) exactly as they are
	for i in range(elite_count):
		if next_generation_pool.size() >= population_size: break
		next_generation_pool.append(saved_car_genes[i]["weights"].duplicate())
		
	# Fill the rest of the population by cloning and mutating the absolute best car
	var best_weights = saved_car_genes[0]["weights"]
	
	while next_generation_pool.size() < population_size:
		var clone = best_weights.duplicate()
		clone = mutate(clone)
		next_generation_pool.append(clone)
		
	saved_car_genes.clear()
	generation += 1
	
	print("Starting Generation ", generation)
	for i in range(next_generation_pool.size()):
		spawn_car(next_generation_pool[i], i)

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

func _process(delta: float) -> void:
	if ClassDB.class_exists("FmodServer") and DisplayServer.get_name() != "headless":
		FmodServer.update()
		if FmodServer.has_method("set_listener_transform3d") and is_instance_valid(camera):
			FmodServer.set_listener_transform3d(0, camera.global_transform)
