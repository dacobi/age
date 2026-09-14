extends Node
class_name CarSetup

@export_group("Wheels")
@export var wheel_FL : Node3D
@export var wheel_FR : Node3D
@export var wheel_RL : Node3D
@export var wheel_RR : Node3D

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
var wheel_radius : float = 0.35
var wheel_diameter : float

var pivot_FL : Node3D
var pivot_FR : Node3D
var pivot_RL : Node3D
var pivot_RR : Node3D

var spring_strength : float
var rest_dist : float

func _ready():
	_calculate_dimensions()
	_automate_pivots()

func _calculate_dimensions():
	if wheel_FL and wheel_RL:
		wheel_base = abs(wheel_FL.global_position.z - wheel_RL.global_position.z)
	
	if wheel_FL and wheel_FR:
		track_width = abs(wheel_FL.global_position.x - wheel_FR.global_position.x)
	
	wheel_diameter = wheel_radius * 2.0
	
	var car = get_parent() as RigidBody3D
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
	
	var car = get_parent()
	car.add_child(pivot)
	pivot.global_transform = wheel.global_transform
	
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
