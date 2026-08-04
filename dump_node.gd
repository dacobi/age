extends SceneTree

func _init():
	var scn = load("res://assets/models/extra_objects/traffic_cone.glb")
	if scn:
		var inst = scn.instantiate()
		print("--- TRAFFIC CONE ---")
		print_tree_recursive(inst, "")
	else:
		print("NOT FOUND")
	quit()

func print_tree_recursive(node: Node, indent: String):
	print(indent + node.name + " (" + node.get_class() + ")")
	for c in node.get_children():
		print_tree_recursive(c, indent + "  ")
