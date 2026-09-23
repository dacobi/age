extends Node

@export var player_car_name: String = "lemans_car"

func _ready():
	var car_path = "res://assets/cars/" + player_car_name + "/" + player_car_name + ".tscn"
	if ResourceLoader.exists(car_path):
		var car_scene = load(car_path)
		if car_scene:
			var car_instance = car_scene.instantiate()
			car_instance.name = "SuperCar"
			get_parent().add_child(car_instance)
			
			var spawn_point = get_parent().get_node_or_null("PlayerSpawn")
			if spawn_point and spawn_point is Node3D and car_instance is Node3D:
				car_instance.global_transform = spawn_point.global_transform
