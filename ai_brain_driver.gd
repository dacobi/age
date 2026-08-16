extends Node

var car: RigidBody3D
var track_path: Path3D
var brain: CarBrain

var raycasts: Array[RayCast3D] = []
var max_ray_dist := 50.0

var in_countdown := false
var time_since_last_checkpoint := 0.0
var checkpoints_passed := 0

var generation: int = 1

var crashed := false
var fitness: float = 0.0
var checkpoint_speed_bonus: float = 0.0
var stall_timer := 0.0
var not_grounded_timer := 0.0
var fall_timer: float = 0.0
var wrong_way_timer: float = 0.0

var last_progress: float = -1.0
var accumulated_progress: float = 0.0
var accumulated_speed_score: float = 0.0
var time_alive: float = 0.0
var last_nitro_seconds: float = 0.0
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
		var dir = Vector3(0, -0.01, -1.0).normalized() * 200.0
		rc.target_position = dir.rotated(Vector3.UP, deg_to_rad(angle))
		# Mask 128 = Layer 8 (AI Vision Walls only, ignoring the floor so uphills don't trick it)
		rc.collision_mask = 128
		rc.enabled = true
		car.add_child(rc)
		raycasts.append(rc)
		
	# Initialize 3 Car-Detecting Raycasts (Horizontal, small spread)
	var car_angles = [15.0, 0.0, -15.0]
	for angle in car_angles:
		var rc = RayCast3D.new()
		rc.target_position = Vector3(0, 0, -50.0).rotated(Vector3.UP, deg_to_rad(angle))
		rc.position = Vector3(0, 0.5, 0)
		rc.collision_mask = 128 # AI Vision Layer
		rc.collide_with_areas = true # Must hit the AIVisionArea of cars and nitro!
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
		# Checkpoint Timer
		time_since_last_checkpoint += delta
		
		# Shrink the timeout down to a challenging but physically possible 6.0 seconds minimum.
		var cp_timeout = maxf(6.0, 15.0 - (float(generation) * 0.2))
		
		# Give the car a grace period to accelerate from a standing start or when stuck
		var current_timeout = cp_timeout
		var current_speed = car.linear_velocity.length()
		if current_speed < 10.0:
			current_timeout += 5.0
			
		if time_since_last_checkpoint > current_timeout:
			print("Car ", car.name, " stalled! (", current_timeout, "s without a checkpoint)")
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
		
	# 1.5 Penalize for colliding with other cars
	var area = car.get_node_or_null("AIVisionArea")
	if area:
		var overlapping_areas = area.get_overlapping_areas()
		for other_area in overlapping_areas:
			if other_area != area and other_area.name == "AIVisionArea":
				# Hit another AI car
				fitness -= 1000.0 * delta
				
	time_alive += delta
	accumulated_progress += delta_progress
	last_progress = current_progress
	
	# 1.6 Reward for explicitly collecting nitro (teaches them to aim for it)
	var current_nitro = car.get("nitro_seconds") if car.get("nitro_seconds") != null else 0.0
	if current_nitro > last_nitro_seconds:
		checkpoint_speed_bonus += 1500.0 # Instant massive reward!
		print("Car ", car.name, " COLLECTED NITRO! +1500 Fitness!")
	last_nitro_seconds = current_nitro
	
	# Calculate total fitness combining distance and exponential speed reward
	var speed_bonus = get("checkpoint_speed_bonus")
	if speed_bonus == null:
		speed_bonus = 0.0
	
	var current_fitness = accumulated_progress + speed_bonus
	
	# Prevent fitness from dropping if the car rolls backwards slightly (or as time increases)
	# This locks in their "highest score", effectively grading them on how fast they reached their furthest point.
	if current_fitness > fitness:
		fitness = current_fitness
		
	# Calculate track-relative height
	var track_y = 0.0
	if curve and track_path:
		var track_transform = track_path.global_transform * curve.sample_baked_with_rotation(current_progress, true, true)
		track_y = track_transform.origin.y
				
	# 2. Check for Stall / Crash / Falling
	if car.global_position.y < (track_y - 10.0):
		print("Car ", car.name, " fell off track! (Y-level drop detected)")
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
		var st_timeout = maxf(4.0, 10.0 - (float(generation) * 0.3))
		if stall_timer > st_timeout:
			print("Car stalled! Speed:", speed, " Timeout:", st_timeout)
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
			print("Car ", car.name, " fell off track! (Not grounded for 1s)")
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
	inputs.resize(17)
	
	# Draw debug lines
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Inputs 0-4: Angled Raycasts (Floor detection)
	for i in range(5):
		var rc = raycasts[i]
		rc.force_raycast_update()
		var hit_dist = 200.0
		var global_start = rc.global_position
		var global_end = rc.to_global(rc.target_position)
		if rc.is_colliding():
			global_end = rc.get_collision_point()
			hit_dist = (global_end - global_start).length()
		
		inputs[i] = 1.0 - clampf(hit_dist / 200.0, 0.0, 1.0)
		
		var color = Color.GREEN if rc.is_colliding() else Color.RED
		im.surface_set_color(color)
		im.surface_add_vertex(debug_mesh.to_local(global_start))
		im.surface_set_color(color)
		im.surface_add_vertex(debug_mesh.to_local(global_end))
		
	# Inputs 14-16: Car/Powerup Detection Raycasts (AI Vision)
	for i in range(3):
		var rc = raycasts[5 + i]
		rc.force_raycast_update()
		var hit_dist = 50.0
		var global_start = rc.global_position
		var global_end = rc.to_global(rc.target_position)
		var hit_type = 0 # 0 = track wall, 1 = car, -1 = nitro
		
		if rc.is_colliding():
			global_end = rc.get_collision_point()
			hit_dist = (global_end - global_start).length()
			var col = rc.get_collider()
			if col:
				if col.name.begins_with("NitroVisionArea"):
					hit_type = -1
				elif col.name.begins_with("AIVisionArea"):
					hit_type = 1
			
		var norm_dist = 1.0 - clampf(hit_dist / 50.0, 0.0, 1.0)
		if hit_type == -1:
			inputs[14 + i] = -norm_dist # Negative input for Nitro so the NN can learn to aim for it
			checkpoint_speed_bonus += 500.0 * norm_dist * delta # Huge Breadcrumb reward!
		elif hit_type == 1:
			inputs[14 + i] = norm_dist # Positive input for cars (obstacles)
		else:
			inputs[14 + i] = norm_dist * 0.5 # Track wall (Layer 128), treat as mild obstacle
		
		var color = Color.BLUE
		if rc.is_colliding():
			if hit_type == -1: color = Color.GREEN
			elif hit_type == 1: color = Color.RED
			else: color = Color.YELLOW
			
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
			print("Car ", car.name, " drove wrong way!")
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
	if outputs.size() >= 5:
		var out_steer = outputs[0]
		var out_throttle = outputs[1]
		var out_brake = outputs[2]
		var out_nitro = outputs[3]
		var out_handbrake = outputs[4]
		
		car.steer_input = out_steer
		
		# Prevent the AI from lightly pressing the brake while on the gas,
		# which triggers the car's brake-override system and caps speed at 25 km/h.
		# Also, map the tanh output (-1 to 1) to (0 to 1) so it defaults to 50% throttle!
		var mapped_throttle = (out_throttle + 1.0) / 2.0
		if out_brake > 0.1 and out_brake > mapped_throttle:
			car.brake_input = out_brake
			car.accel_input = 0.0
		else:
			car.brake_input = 0.0
			car.accel_input = mapped_throttle
			
		car.nitro_input = 1.0 if out_nitro > 0.5 else 0.0
		car.handbrake_input = 1.0 if out_handbrake > 0.5 else 0.0
