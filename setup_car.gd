extends Node


class_name CarSetup

@export var car_name: String = "lemans_car"

@export_group("Wheels")
@export var wheel_FL : Node3D
@export var wheel_FR : Node3D
@export var wheel_RL : Node3D
@export var wheel_RR : Node3D
@export var wheel_diameter_front : float = 0.0 # 0.0 means auto-calculate
@export var wheel_diameter_rear : float = 0.0 # 0.0 means auto-calculate

@export_group("Exhausts")
@export_range(1, 6) var NumberOfExaustPipes: int = 1
@export var Pipe1 : Node3D
@export var Pipe2 : Node3D
@export var Pipe3 : Node3D
@export var Pipe4 : Node3D
@export var Pipe5 : Node3D
@export var Pipe6 : Node3D

@export_group("Suspension (cm)")
@export_range(0.0, 40.0) var CompressedTravel : float = 15.0
@export_range(0.0, 40.0) var AirborneTravel : float = 25.0

# Calculated Properties
var wheel_base : float
var track_width : float
var wheel_radius_front : float = 0.35
var wheel_radius_rear : float = 0.35

var pivot_FL : Node3D
var pivot_FR : Node3D
var pivot_RL : Node3D
var pivot_RR : Node3D

var spring_strength : float
var rest_dist : float

var is_initialized = false # Trigger Godot UI reload

func initialize_setup():
	if is_initialized: return
	_calculate_dimensions()
	_automate_pivots()
	_generate_dynamic_collisions()
	is_initialized = true

func _ready():
	pass

func _get_transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t = node.transform
	var p = node.get_parent()
	while p and p != ancestor and p is Node3D:
		t = p.transform * t
		p = p.get_parent()
	return t

func _measure_wheel_radius(node: Node3D) -> float:
	if not node: return 0.35
	var aabb = AABB()
	var meshes = []
	var to_check = [node]
	while to_check.size() > 0:
		var n = to_check.pop_back()
		var skip_children = false
		if (n is MeshInstance3D and n.mesh) or n is CSGShape3D:
			meshes.append(n)
			if n is CSGShape3D:
				skip_children = true
		if not skip_children:
			for c in n.get_children():
				to_check.append(c)
	if meshes.is_empty(): return 0.35
	
	var first = true
	for m in meshes:
		var local_trans = _get_transform_relative_to(m, node)
		var m_aabb = m.get_aabb()
		if m is CSGShape3D:
			if m.has_method("_update_shape"):
				m._update_shape()
			var arr = m.get_meshes()
			if arr.size() > 1 and arr[1] is Mesh:
				m_aabb = arr[1].get_aabb()
		var t_aabb = local_trans * m_aabb
		if first:
			aabb = t_aabb
			first = false
		else:
			aabb = aabb.merge(t_aabb)
	return maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) / 2.0

func _calculate_dimensions():
	var visual_root = get_parent()
	if wheel_FL and wheel_RL:
		var t_FL = _get_transform_relative_to(wheel_FL, visual_root)
		var t_RL = _get_transform_relative_to(wheel_RL, visual_root)
		wheel_base = abs(t_FL.origin.z - t_RL.origin.z)
		
		var local_front_z = t_FL.origin.z
		var local_rear_z = t_RL.origin.z
		
		# If the Z coordinates indicate the FL wheel is physically at the Godot rear (+Z),
		# then the car body was imported facing backwards. We must rotate the visual meshes 180 degrees.
		# AND we MUST swap the wheel pointers, because the FL mesh is physically the rear wheel!
		if local_front_z > local_rear_z:

			# Rotate the meshes so they face the correct direction
			for child in visual_root.get_children():
				if child != self and child is Node3D:
					var t = child.transform
					t.origin = t.origin.rotated(Vector3.UP, PI)
					t.basis = t.basis.rotated(Vector3.UP, PI)
					child.transform = t
	
	if wheel_FL and wheel_FR:
		var t_FL = _get_transform_relative_to(wheel_FL, visual_root)
		var t_FR = _get_transform_relative_to(wheel_FR, visual_root)
		track_width = abs(t_FL.origin.x - t_FR.origin.x)
	
	if wheel_diameter_front > 0.001:
		wheel_radius_front = wheel_diameter_front / 2.0
	else:
		wheel_radius_front = _measure_wheel_radius(wheel_FL)
		
	if wheel_diameter_rear > 0.001:
		wheel_radius_rear = wheel_diameter_rear / 2.0
	else:
		wheel_radius_rear = _measure_wheel_radius(wheel_RL)
	
	var car = get_parent()
	while car and not car is RigidBody3D:
		car = car.get_parent()
	rest_dist = AirborneTravel / 100.0
	var compressed_m = CompressedTravel / 100.0
	var travel_diff = rest_dist - compressed_m
	
	if car and travel_diff > 0.001:
		# spring_strength * travel_diff = (mass * gravity) / 4.0
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		var weight_per_wheel = (car.mass * gravity) / 4.0
		spring_strength = weight_per_wheel / travel_diff
	else:
		spring_strength = 17500.0 # Fallback

func _automate_pivots():
	pivot_FL = _create_pivot(wheel_FL, "PivotFL")
	pivot_FR = _create_pivot(wheel_FR, "PivotFR")
	pivot_RL = _create_pivot(wheel_RL, "PivotRL")
	pivot_RR = _create_pivot(wheel_RR, "PivotRR")

func _create_pivot(wheel: Node3D, p_name: String) -> Node3D:
	if not wheel: return null
	var pivot = Node3D.new()
	pivot.name = p_name
	
	var visual_root = get_parent()
	visual_root.add_child(pivot)
	pivot.transform = _get_transform_relative_to(wheel, visual_root)
	
	var parent = wheel.get_parent()
	parent.remove_child(wheel)
	pivot.add_child(wheel)
	
	wheel.transform = Transform3D.IDENTITY
	return pivot

func get_exhaust_global_positions() -> Array[Vector3]:
	var all_pipes = [Pipe1, Pipe2, Pipe3, Pipe4, Pipe5, Pipe6]
	var assigned_pipes: Array[Node3D] = []
	for p in all_pipes:
		if p:
			assigned_pipes.append(p)
			
	var positions: Array[Vector3] = []
	if assigned_pipes.is_empty():
		return positions
		
	var pipes_per_node = NumberOfExaustPipes / assigned_pipes.size()
	var remainder = NumberOfExaustPipes % assigned_pipes.size()
	
	for i in range(assigned_pipes.size()):
		var pipe = assigned_pipes[i]
		var count_for_this_node = pipes_per_node
		if i < remainder:
			count_for_this_node += 1
			
		if count_for_this_node <= 1:
			positions.append(pipe.global_position)
			continue
			
		var pipe_spacing = 0.12
		if pipe is MeshInstance3D and pipe.mesh:
			var aabb = pipe.get_aabb()
			var diameter = aabb.size.y
			var center_to_center = maxf(0.001, aabb.size.x - diameter)
			pipe_spacing = center_to_center / float(count_for_this_node - 1)
			
		# Center the cluster around the node's origin along the local X axis
		var start_offset = -((count_for_this_node - 1) * pipe_spacing) / 2.0
		
		for j in range(count_for_this_node):
			var local_offset = Vector3(start_offset + (j * pipe_spacing), 0, 0)
			var global_pos = pipe.global_transform * local_offset
			positions.append(global_pos)
			
	return positions


func _generate_dynamic_collisions():
	var car = get_parent()
	if not car is RigidBody3D: return
	
	# Let's get the AABB of the entire visual root
	var visual_root = get_parent()
	var meshes = []
	var to_check = [visual_root]
	while to_check.size() > 0:
		var n = to_check.pop_back()
		var skip_children = false
		if (n is MeshInstance3D and n.mesh) or n is CSGShape3D:
			if n.name != "CollisionDebugVisual":
				meshes.append(n)
			if n is CSGShape3D:
				skip_children = true
				
		if not skip_children:
			for c in n.get_children():
				if c != self:
					to_check.append(c)
				
	var aabb = AABB()
	var first = true
	for m in meshes:
		var local_trans = _get_transform_relative_to(m, visual_root)
		var m_aabb = m.get_aabb()
		if m is CSGShape3D:
			if m.has_method("_update_shape"):
				m._update_shape()
			var arr = m.get_meshes()
			if arr.size() > 1 and arr[1] is Mesh:
				m_aabb = arr[1].get_aabb()
		var t_aabb = local_trans * m_aabb
		if first:
			aabb = t_aabb
			first = false
		else:
			aabb = aabb.merge(t_aabb)
			
	var width = aabb.size.x * 0.9
	var length = aabb.size.z * 0.95
	var height = aabb.size.y * 0.8
	
	var center = aabb.get_center()
	var fixture_offset_y = 0.5
	var base_pos = center + Vector3(0, fixture_offset_y, 0)
	
	# 1. Main Body Box
	var body_col = CollisionShape3D.new()
	body_col.name = "BodyCol"
	var box = BoxShape3D.new()
	box.size = Vector3(width, height, length)
	body_col.shape = box
	body_col.position = base_pos
	_generate_debug_mesh(body_col, Color(1, 0, 0, 0.4))
	car.add_child(body_col)
	
	# 2. 4 Corner Skid Spheres
	var sphere_radius = 0.3
	for z_pos in [-length/2.0, length/2.0]:
		for x_pos in [-width/2.0, width/2.0]:
			var sphere_col = CollisionShape3D.new()
			var sphere = SphereShape3D.new()
			sphere.radius = sphere_radius
			sphere_col.shape = sphere
			sphere_col.position = base_pos + Vector3(x_pos, -height/2.0, z_pos)
			_generate_debug_mesh(sphere_col, Color(0, 0.6, 0.7, 0.42))
			car.add_child(sphere_col)
			
	# 3. Prop Angled Bumper (Front)
	var bumper = AnimatableBody3D.new()
	bumper.name = "AngledBumper"
	bumper.sync_to_physics = false
	bumper.collision_layer = 2
	bumper.collision_mask = 4
	
	var bumper_area = Area3D.new()
	bumper_area.collision_layer = 0
	bumper_area.collision_mask = 4
	if car.has_method("_on_prop_collided"):
		bumper_area.body_entered.connect(car._on_prop_collided)
	bumper.add_child(bumper_area)
	
	var bumper_col = CollisionShape3D.new()
	var bumper_shape = BoxShape3D.new()
	bumper_shape.size = Vector3(width + 0.5, height*2.0, 2.0)
	bumper_col.shape = bumper_shape
	bumper_col.rotation_degrees.x = 45.0
	# Extended to 2m deep, pushed down and back to perfectly blend into the ground and hood
	bumper_col.position = base_pos + Vector3(0, -height*1.3, -length/2.0 + 0.6)
	
	_generate_debug_mesh(bumper_col, Color(0, 0, 1, 0.4))
	bumper.add_child(bumper_col)
	bumper_area.add_child(bumper_col.duplicate())
	car.add_child(bumper)
	car.add_collision_exception_with(bumper)
	
	# 4. Prop Rear Bumper
	var rear_bumper = AnimatableBody3D.new()
	rear_bumper.name = "RearBumper"
	rear_bumper.sync_to_physics = false
	rear_bumper.collision_layer = 2
	rear_bumper.collision_mask = 4
	
	var rear_bumper_area = Area3D.new()
	rear_bumper_area.collision_layer = 0
	rear_bumper_area.collision_mask = 4
	if car.has_method("_on_prop_collided"):
		rear_bumper_area.body_entered.connect(car._on_prop_collided)
	rear_bumper.add_child(rear_bumper_area)
	
	var rear_col = CollisionShape3D.new()
	var rear_shape = BoxShape3D.new()
	rear_shape.size = Vector3(width + 0.5, height*2, 1.0)
	rear_col.shape = rear_shape
	# Moved further down and deeper into the car body
	rear_col.position = base_pos + Vector3(0, -1.0, length/2.0 - 0.4)
	
	_generate_debug_mesh(rear_col, Color(0, 0, 1, 0.4))
	rear_bumper.add_child(rear_col)
	rear_bumper_area.add_child(rear_col.duplicate())
	car.add_child(rear_bumper)
	car.add_collision_exception_with(rear_bumper)
	
	# 5. Nitro Magnet Area
	var magnet_area = Area3D.new()
	magnet_area.name = "NitroMagnetArea"
	magnet_area.collision_layer = 0
	magnet_area.collision_mask = 4
	if car.has_method("_on_prop_collided"):
		magnet_area.body_entered.connect(car._on_prop_collided)
	
	var magnet_col = CollisionShape3D.new()
	var magnet_shape = BoxShape3D.new()
	magnet_shape.size = Vector3(width + 3.0, height + 1.0, length + 2.0) 
	magnet_col.shape = magnet_shape
	magnet_col.position = base_pos
	
	_generate_debug_mesh(magnet_col, Color(1, 0, 1, 0.2))
	magnet_area.add_child(magnet_col)
	car.add_child(magnet_area)
	
	# 6. Checkpoint Area
	var cp_area = Area3D.new()
	cp_area.name = "CheckpointSphere"
	cp_area.collision_layer = 16
	cp_area.collision_mask = 16
	var cp_col = CollisionShape3D.new()
	var cp_shape = SphereShape3D.new()
	cp_shape.radius = 1.0
	cp_col.shape = cp_shape
	cp_col.position = car.center_of_mass
	_generate_debug_mesh(cp_col, Color(0, 1, 0, 0.4))
	cp_area.add_child(cp_col)
	car.add_child(cp_area)
	
	# 7. AI Vision Area
	var ai_vision = Area3D.new()
	ai_vision.name = "AIVisionArea"
	ai_vision.collision_layer = 128
	ai_vision.collision_mask = 128
	var ai_vision_col = CollisionShape3D.new()
	var ai_vision_box = BoxShape3D.new()
	ai_vision_box.size = Vector3(width + 0.5, height + 1.0, length + 2.0)
	ai_vision_col.shape = ai_vision_box
	ai_vision_col.position = base_pos
	_generate_debug_mesh(ai_vision_col, Color(1, 1, 0, 0.2))
	ai_vision.add_child(ai_vision_col)
	car.add_child(ai_vision)

func _generate_debug_mesh(col_shape: CollisionShape3D, color: Color = Color(1, 0, 0, 0.4)):
	var mi = MeshInstance3D.new()
	mi.name = "CollisionDebugVisual"
	var shape = col_shape.shape
	if shape is BoxShape3D:
		var box = BoxMesh.new()
		box.size = shape.size
		mi.mesh = box
	elif shape is SphereShape3D:
		var sph = SphereMesh.new()
		sph.radius = shape.radius
		sph.height = shape.radius * 2.0
		mi.mesh = sph
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.visible = false
	col_shape.add_child(mi)
