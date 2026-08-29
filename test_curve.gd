extends SceneTree
func _init():
    var c = Curve3D.new()
    for prop in c.get_property_list():
        print(prop.name)
    quit()
