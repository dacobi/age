extends Node

var car: RigidBody3D
var track_path: Path3D
var brain: CarBrain

var raycasts: Array[RayCast3D] = []
var max_ray_dist := 50.0

var crashed := false
var fitness: float = 0.0
var checkpoints_passed: int = 0
var stall_timer := 0.0
var not_grounded_timer := 0.0
var fall_timer: float = 0.0
var time_since_last_checkpoint: float = 0.0
var wrong_way_timer: float = 0.0

var last_progress: float = -1.0
var accumulated_progress: float = 0.0
var debug_mesh: MeshInstance3D

func _ready() -> void:
	# Guarantee automatic transmission
	car.set("gear_mode", 0) # 0 = Auto
	
	# Create a mesh for drawing debug lines
	debug_mesh = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	debug_mesh.material_override = mat
	# Add it to the world, not the car, so it doesn't move with the car automatically
	car.call_deferred("add_sibling", debug_mesh)
	
	# Initialize 5 Angled-Down Raycasts
	var angles = [75.0, 30.0, 0.0, -30.0, -75.0]
	for angle in angles:
		var rc = RayCast3D.new()
		var dir = Vector3(0, -0.01, -1.0).normalized() * 100.0
		rc.target_position = dir.rotated(Vector3.UP, deg_to_rad(angle))
		rc.collision_mask = 1 # Match standard static environment layer
		rc.enabled = true
		car.add_child(rc)
		raycasts.append(rc)
		
	# Initialize 3 Car-Detecting Raycasts (Horizontal, small spread)
	var car_angles = [15.0, 0.0, -15.0]
	for angle in car_angles:
		var rc = RayCast3D.new()
		rc.target_position = Vector3(0, 0, -50.0).rotated(Vector3.UP, deg_to_rad(angle))
		# Set position slightly higher so it hits the taller car body
		rc.position = Vector3(0, 0.5, 0)
		rc.collision_mask = 2 # ONLY hit cars (layer 2)
		rc.enabled = true
		car.add_child(rc)
		raycasts.append(rc)
		
	# Reset Brain
	if brain == null:
		brain = car.get_node_or_null("CarBrain")

func _exit_tree() -> void:
	if is_instance_valid(debug_mesh):
		debug_mesh.queue_free()

func _physics_process(delta: float) -> void:
	if crashed or not car or not track_path or not brain:
		return
		
	if not debug_mesh.is_inside_tree():
		return
		
	# Respect the track's master countdown (3, 2, 1) on the first generation!
	var track = car.get_parent().get_parent()
	if track != null and "countdown_value" in track and track.countdown_value > 0:
		car.accel_input = 0.0
		car.brake_input = 0.0 
		car.handbrake_input = 1.0 # Use handbrake so we don't trigger reverse!
		car.steer_input = 0.0
		return
		
	car.handbrake_input = 0.0
		
	if car.in_countdown:
		car.accel_input = 0.0
		car.brake_input = 0.0
		car.steer_input = 0.0
		return
		

		
	var track_node = car.get_parent().get_parent()
	var in_countdown = false
	if track_node != null and "countdown_value" in track_node and track_node.countdown_value > 0:
		in_countdown = true
		
	if car.in_countdown or in_countdown:
		# Do nothing while counting down
		pass
	else:
		# Checkpoint Timer (Kills cars that drive in circles or get stuck)
		time_since_last_checkpoint += delta
		if time_since_last_checkpoint > 30.0:
			print("Car ", car.name, " stalled! (30s without a checkpoint)")
			crashed = true
			car.accel_input = 0.0
			car.brake_input = 1.0
			car.steer_input = 0.0
			return
		
	# 1. Update Fitness (Curve Progress Scoring)
	var curve = track_path.curve if track_path else null
	var current_progress = curve.get_closest_offset(car.global_position) if curve else 0.0
	var track_length = curve.get_baked_length() if curve else 4500.0
	
	if last_progress < 0.0:
		last_progress = current_progress
		
	var delta_progress = current_progress - last_progress
	if delta_progress < -2000.0: # Wrapped forward
		delta_progress += track_length
	elif delta_progress > 2000.0: # Wrapped backward
		delta_progress -= track_length
		
	accumulated_progress += delta_progress
	last_progress = current_progress
	
	# Calculate total fitness combining distance and checkpoints
	var current_fitness = accumulated_progress + (checkpoints_passed * 500.0)
	
	# Prevent fitness from dropping if the car rolls backwards slightly
	if current_fitness > fitness:
		fitness = current_fitness
		
	# Calculate track-relative height
	var track_y = 0.0
	if curve and track_path:
		var track_transform = track_path.global_transform * curve.sample_baked_with_rotation(current_progress, true, true)
		track_y = track_transform.origin.y
	# 2. Check for Stall / Crash / Falling
	if car.global_position.y < track_y - 3.0:
		print("Car fell off track! (Y-level drop detected)")
		crashed = true
		car.accel_input = 0.0
		car.brake_input = 1.0
		car.freeze = true
		car.set_physics_process(false)
		car.gravity_scale = 0.0
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		return
		
	var speed = car.linear_velocity.length()
	if speed < 0.55: # ~2 km/h
		stall_timer += delta
		if stall_timer > 10.0:
			print("Car stalled! Speed:", speed)
			crashed = true
			car.accel_input = 0.0
			car.brake_input = 1.0
			car.freeze = true
			car.set_physics_process(false)
			car.gravity_scale = 0.0
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			return
	else:
		stall_timer = 0.0
		
	var is_grounded = false
	var wheels = car.get("wheels")
	if wheels:
		for w in wheels:
			if w.is_colliding():
				is_grounded = true
				break
				
	if not is_grounded:
		not_grounded_timer += delta
		if not_grounded_timer > 1.0: # Falling for more than 1 second (jumping track)
			print("Car fell off track! (Not grounded for 1s)")
			crashed = true
			car.accel_input = 0.0
			car.brake_input = 0.0
			car.freeze = true
			car.set_physics_process(false)
			car.gravity_scale = 0.0
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			return
	else:
		not_grounded_timer = 0.0
		
	# 3. Gather Sensor Data
	var inputs = PackedFloat32Array()
	inputs.resize(14)
	
	# Draw debug lines
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Inputs 0-4: Angled Raycasts (Floor detection)
	for i in range(5):
		var rc = raycasts[i]
		rc.force_raycast_update()
		var hit_dist = 100.0
		var global_start = rc.global_position
		var global_end = rc.to_global(rc.target_position)
		if rc.is_colliding():
			global_end = rc.get_collision_point()
			hit_dist = (global_end - global_start).length()
		
		inputs[i] = 1.0 - clampf(hit_dist / 100.0, 0.0, 1.0)
		
		var color = Color.GREEN if rc.is_colliding() else Color.RED
		im.surface_set_color(color)
		im.surface_add_vertex(debug_mesh.to_local(global_start))
		im.surface_set_color(color)
		im.surface_add_vertex(debug_mesh.to_local(global_end))
		
	var car_forward = -car.global_transform.basis.z.normalized()
	
	# Inputs 10-12: Track Look-Ahead (Anticipate corners)
	if curve:
		for i in range(3):
			var lookahead_dist = 50.0 * (i + 1) # 50m, 100m, 150m
			var future_progress = fmod(current_progress + lookahead_dist, track_length)
			var future_transform = track_path.global_transform * curve.sample_baked_with_rotation(future_progress, false, false)
			var future_forward = -future_transform.basis.z.normalized()
			var future_angle_diff = car_forward.signed_angle_to(future_forward, Vector3.UP)
			inputs[10 + i] = future_angle_diff / PI
	else:
		for i in range(3):
			inputs[10 + i] = 0.0
			
	# Input 13: Yaw Rate (Angular Velocity Y)
	# Crucial for dynamic stabilization and stopping wobbles
	inputs[13] = clampf(car.angular_velocity.y / PI, -1.0, 1.0)
			
	im.surface_end()
	debug_mesh.mesh = im
	
	# Calculate track-relative data
	var track_transform = track_path.global_transform
	if curve:
		track_transform = track_path.global_transform * curve.sample_baked_with_rotation(current_progress, false, false)
	
	var track_forward = -track_transform.basis.z.normalized()
	var track_right = track_transform.basis.x.normalized()
	
	# Input 5: Lateral offset from track center (-1.0 to 1.0)
	var to_car = car.global_position - track_transform.origin
	var lateral_offset = to_car.dot(track_right)
	inputs[5] = clampf(lateral_offset / 50.0, -1.0, 1.0)
	
	if to_car.length() > 46.0:
		print("Car ", car.name, " hit the wall! (Out of bounds)")
		crashed = true
		car.accel_input = 0.0
		car.brake_input = 0.0
		car.steer_input = 0.0
		return
		
	# Input 6: Angle difference to track direction (-1.0 to 1.0)
	var angle_diff = car_forward.signed_angle_to(track_forward, Vector3.UP)
	inputs[6] = angle_diff / PI
	
	if abs(angle_diff) > PI / 2.0:
		wrong_way_timer += delta
		if wrong_way_timer > 5.0:
			print("Car drove wrong way!")
			crashed = true
			car.accel_input = 0.0
			car.brake_input = 0.0
			car.steer_input = 0.0
			return
	else:
		wrong_way_timer = 0.0
	
	# Input 7: Normalized Speed
	inputs[7] = clampf(speed / 50.0, 0.0, 1.0)
	
	var target_cp = track_path.get_node_or_null("Checkpoint_" + str(checkpoints_passed % 100))
	if target_cp:
		var to_cp = target_cp.global_position - car.global_position
		var dist = to_cp.length()
				
		inputs[9] = clampf(dist / 200.0, 0.0, 1.0)
		to_cp.y = 0
		if to_cp.length_squared() > 0.001:
			to_cp = to_cp.normalized()
			inputs[8] = car_forward.signed_angle_to(to_cp, Vector3.UP) / PI
		
	# 4. Neural Network Think
	var outputs = brain.think(inputs)
	if outputs.size() == 2:
		var out_steer = outputs[0]
		var out_throttle = outputs[1]
		
		car.steer_input = clampf(out_steer, -1.0, 1.0)
		
		if out_throttle > 0.0:
			car.accel_input = clampf(out_throttle, 0.0, 1.0)
			car.brake_input = 0.0
		else:
			car.accel_input = 0.0
			# Only apply brake if moving forward (speed > 1.0). 
			# This completely removes the AI's ability to drive in reverse!
			var local_z = car.global_transform.basis.z
			var forward_vel = -car.linear_velocity.dot(local_z)
			if forward_vel > 1.0:
				car.brake_input = clampf(-out_throttle, 0.0, 1.0)
			else:
				car.brake_input = 0.0
