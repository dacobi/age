extends SceneTree
func _initialize():
    var physics_scene = load("res://lemans_car.tscn")
    var supercar = physics_scene.instantiate()
    var visual_car = load("res://car_stingray.tscn").instantiate()
    supercar.add_child(visual_car)
    
    # We must add to root so _ready runs properly!
    root.add_child(supercar)
    
    var setup_node = null
    var to_check = [supercar]
    while to_check.size() > 0:
        var current = to_check.pop_back()
        if current.has_method("initialize_setup"):
            setup_node = current
            break
        for child in current.get_children():
            to_check.append(child)
            
    if setup_node:
        setup_node.initialize_setup()
        supercar._ready()
        var col = supercar.get_node("BodyCol")
        print("BOX SIZE: ", col.shape.size)
        print("BOX POS: ", col.position)
        for child in supercar.get_children():
            if child is CollisionShape3D and child.shape is SphereShape3D:
                print("- SPHERE POS: ", child.position)
    quit()
