extends Node3D

@export var player_car_name: String = "lemans_car"
@export var track_json: String = "res://assets/tracks/track1/track1.json"
@export var car_name: String = ""

var supercar: Node3D
var track_root: Node3D

var is_paused = true
var in_edit_mode = false

var orbit_yaw = 0.0
var orbit_pitch = 0.5
var orbit_dist = 18.0
var cam_rx = 0.0
var cam_ry = 0.0
var current_cam_yaw = 0.0
var current_cam_pitch = 0.0
var key_e_pressed = false
var reset_car = false
var reset_y_threshold: float = -3000.0
var reset_game = false
var start_transform: Transform3D
var start_flipped: bool = false
var gate_length: float = 90.0
var is_crash_cam_active = false

func _ready():
	# If loading screen set 'car_name', override 'player_car_name'
	
	
	#if car_name != "lemans_car" and car_name != "":
	player_car_name = car_name
		
	print(player_car_name)	

	track_root = get_node_or_null("TrackRoot")
	if not track_root:
		track_root = Node3D.new()
		track_root.name = "TrackRoot"
		add_child(track_root)
		
	var camera = get_node_or_null("Camera3D")
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	var file = FileAccess.open(track_json, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		file.close()
		
		if typeof(data) == TYPE_ARRAY:
			# Generate the track
			preload("res://track_generator.gd").generate(data, track_root)
			reset_y_threshold = get_min_track_y(track_root) - 150.0
			
			# Find the gate or start position
			start_transform = Transform3D()
			var gate_found = false
			start_flipped = false
			gate_length = 90.0
			
			var children = track_root.get_children()
			for i in range(data.size()):
				if data[i].get("type") == "gate":
					start_transform = children[i].global_transform
					start_flipped = data[i].get("start_flipped", false)
					gate_length = float(data[i].get("length", 90.0))
					gate_found = true
					break
					
			if not gate_found and children.size() > 0:
				start_transform = children[0].global_transform
				
			_spawn_nitros(data, children)
			
	# Load Car
	var car_scene = load("res://assets/cars/" + player_car_name + "/" + player_car_name + ".tscn")
	if car_scene:
		supercar = car_scene.instantiate()
		supercar.name = "SuperCar"
		add_child(supercar)
		
		# Position Supercar (slightly raised so it drops nicely)
		var offset = start_transform.basis.z * 10.0 # Move 10m back from the start of the gate piece
		if start_flipped:
			offset = start_transform.basis.z * (-gate_length - 10.0)
			
		supercar.global_transform = start_transform
		if start_flipped:
			supercar.global_transform = supercar.global_transform.rotated_local(Vector3.UP, PI)
			
		supercar.global_position = start_transform.origin + offset + Vector3(0, 2.0, 0)
		
		# Reset car physics velocities
		if supercar is RigidBody3D:
			supercar.linear_velocity = Vector3.ZERO
			supercar.angular_velocity = Vector3.ZERO
		
		# Unfreeze
		supercar.process_mode = Node.PROCESS_MODE_INHERIT
		
	is_paused = false

func _spawn_nitros(data: Array, children: Array):
	var nitro_script = load("res://nitro_powerup.gd")
	if not nitro_script: return
	
	var pieces_with_nitros = 25
	var step = max(1, children.size() / max(1, pieces_with_nitros))
	
	var nitro_count = 0
	for i in range(0, children.size(), step):
		if nitro_count >= 25: break
		
		var piece_type = data[i].get("type")
		if piece_type == "gate" or piece_type == "gap" or piece_type == "drop":
			continue
			
		var t = children[i].global_transform
		
		# Random lane offset
		var width = float(data[i].get("width", 40.0))
		var lane_offset = randf_range(-width*0.4, width*0.4)
		
		# Spawn slightly forward into the piece
		var forward_offset = 20.0
		if data[i].has("length"):
			forward_offset = float(data[i]["length"]) * 0.5
			
		var world_pos = t.origin + t.basis.x * lane_offset - t.basis.z * forward_offset + t.basis.y * 5.0
		
		var powerup = StaticBody3D.new()
		powerup.name = "RandomNitroPowerup_" + str(nitro_count)
		powerup.set_script(nitro_script)
		
		track_root.add_child(powerup)
		powerup.global_position = world_pos
		
		nitro_count += 1

func _process(delta):
	if reset_car or (supercar and supercar.global_position.y < reset_y_threshold):
		reset_car = false
		if supercar:
			var offset = start_transform.basis.z * 10.0 # Move 10m back from the start of the gate piece
			if start_flipped:
				offset = start_transform.basis.z * (-gate_length - 10.0)
				
			supercar.global_transform = start_transform
			if start_flipped:
				supercar.global_transform = supercar.global_transform.rotated_local(Vector3.UP, PI)
				
			supercar.global_position = start_transform.origin + offset + Vector3(0, 2.0, 0)
			
			if supercar is RigidBody3D:
				supercar.linear_velocity = Vector3.ZERO
				supercar.angular_velocity = Vector3.ZERO
	if key_e_pressed:
		is_paused = not is_paused
		
	var camera_node = get_node_or_null("Camera3D")
	if camera_node and supercar:
		if is_paused:
			var offset = Vector3(
				sin(orbit_yaw) * cos(orbit_pitch),
				sin(orbit_pitch),
				cos(orbit_yaw) * cos(orbit_pitch)
			) * orbit_dist
			camera_node.global_position = supercar.global_position + offset
			camera_node.look_at(supercar.global_position, Vector3.UP)

func _physics_process(delta):
	var camera_node = get_node_or_null("Camera3D")
	if camera_node and supercar and not in_edit_mode and not is_paused:
		current_cam_yaw = lerp(current_cam_yaw, -cam_rx * 2.0, 5.0 * delta)
		current_cam_pitch = lerp(current_cam_pitch, cam_ry * 1.0, 5.0 * delta)
		
		var is_grounded = true
		if supercar.has_method("is_grounded"):
			is_grounded = supercar.is_grounded()
			
		var air_is_flipped = supercar.global_transform.basis.y.dot(Vector3.UP) < 0.4
		var is_falling = supercar.linear_velocity.y < -15.0
		
		if reset_car:
			is_crash_cam_active = false
		elif air_is_flipped or (not is_grounded and is_falling):
			is_crash_cam_active = true
		elif is_grounded and not air_is_flipped:
			is_crash_cam_active = false
		
		var forward: Vector3
		if is_crash_cam_active and supercar.linear_velocity.length_squared() > 1.0:
			forward = -supercar.linear_velocity
			forward.y = 0.0
			if forward.length_squared() < 0.01:
				forward = supercar.global_transform.basis.z
			forward = forward.normalized()
		else:
			forward = supercar.global_transform.basis.z.normalized()
			
		var up = Vector3.UP
		
		var rotated_forward = forward.rotated(up, current_cam_yaw)
		var offset: Vector3
		var pos_lerp_speed = 10.0
		
		if is_crash_cam_active:
			# Zoom out and up
			offset = rotated_forward * 80.0 + Vector3(0, 40.0, 0)
			pos_lerp_speed = 2.0 # Slower, more cinematic follow
		else:
			offset = rotated_forward * 12.0 + Vector3(0, 4.0 + current_cam_pitch * 4.0, 0)
			
		var target_pos = supercar.global_position + offset
		
		camera_node.global_position = camera_node.global_position.lerp(target_pos, pos_lerp_speed * delta)
		var look_target = supercar.global_position + Vector3(0, 1.5, 0)
		if not is_crash_cam_active:
			look_target += supercar.linear_velocity * 0.1
			
		var target_transform = camera_node.global_transform.looking_at(look_target, Vector3.UP)
		camera_node.global_transform = camera_node.global_transform.interpolate_with(target_transform, 10.0 * delta)

func get_min_track_y(node: Node) -> float:
	var min_y = 0.0
	for child in node.get_children():
		if child is Node3D:
			min_y = min(min_y, child.global_position.y)
		if child is Path3D:
			var curve = child.curve
			if curve:
				for i in range(curve.get_baked_points().size()):
					var pt = child.global_transform * curve.get_baked_points()[i]
					min_y = min(min_y, pt.y)
		min_y = min(min_y, get_min_track_y(child))
	return min_y
