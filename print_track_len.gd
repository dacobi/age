extends SceneTree

func _init():
    var track = load("res://training_track.tscn").instantiate()
    var path = track.get_node("Path3D")
    var curve = path.curve
    print("TRACK_LEN=", curve.get_baked_length())
    quit()
