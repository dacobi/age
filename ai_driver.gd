extends Node

var car: RigidBody3D
var track_path: Path3D
var target_speed := 160.0 / 3.6 # Target speed in m/s

# AI config
var lookahead_dist := 15.0 # How far ahead to look on the track
var brake_dist := 30.0     # When to brake for sharp corners
var steer_sensitivity := 1.5

func _physics_process(delta: float) -> void:
	if not car or not track_path:
		return
	
	if car.in_countdown:
		car.accel_input = 0.0
		car.brake_input = 0.0
		car.steer_input = 0.0
		car.handbrake_input = 0.0
		return
		
	# Get current progress along the track
	var curve = track_path.curve
	if not curve: return
	
	# 1. Find closest offset on the path
	var car_pos = car.global_position
	var closest_offset = curve.get_closest_offset(car_pos)
	
	# 2. Get target position (lookahead)
	var target_offset = closest_offset + lookahead_dist
	if target_offset > curve.get_baked_length():
		target_offset -= curve.get_baked_length()
	
	var target_pos = curve.sample_baked(target_offset)
	
	# 3. Calculate steering
	# Convert target_pos to car's local space
	var local_target = car.global_transform.inverse() * target_pos
	# atan2 gives the angle to the target
	var angle_to_target = atan2(local_target.x, -local_target.z)
	
	var steer_cmd = clampf(angle_to_target * steer_sensitivity, -1.0, 1.0)
	car.steer_input = steer_cmd
	
	# 4. Calculate throttle / braking
	# Very simple: if the curve ahead is very sharp, brake. Otherwise, accelerate.
	var far_offset = closest_offset + brake_dist
	if far_offset > curve.get_baked_length():
		far_offset -= curve.get_baked_length()
	var far_pos = curve.sample_baked(far_offset)
	
	var local_far = car.global_transform.inverse() * far_pos
	var angle_to_far = abs(atan2(local_far.x, -local_far.z))
	
	var speed = car.linear_velocity.length()
	
	if angle_to_far > 0.6 and speed > target_speed * 0.5:
		# Sharp corner ahead, brake!
		car.accel_input = 0.0
		car.brake_input = 1.0
	else:
		# Accelerate to target speed
		if speed < target_speed:
			car.accel_input = 1.0
			car.brake_input = 0.0
		else:
			# Coast
			car.accel_input = 0.0
			car.brake_input = 0.0
			
	# Maybe use nitro on straightaways?
	if angle_to_far < 0.1 and speed > target_speed * 0.8:
		car.nitro_input = 1.0
	else:
		car.nitro_input = 0.0
