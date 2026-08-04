extends SceneTree

func _init():
	var scn = load("res://lemans_car.tscn")
	var car = scn.instantiate()
	root.add_child(car)
	
	var initial_bumper_pos = car.get_node("AngledBumper").global_position
	print("Initial bumper global pos: ", initial_bumper_pos)
	
	car.reset_position(Transform3D(Basis(), Vector3(100, 10, 100)))
	
	var after_bumper_pos = car.get_node("AngledBumper").global_position
	var col_pos = car.get_node("AngledBumper/CollisionShape3D").global_position
	print("After reset bumper global pos: ", after_bumper_pos)
	print("After reset bumper col global pos: ", col_pos)
	
	quit()
