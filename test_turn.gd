extends SceneTree

func _init():
    var track = load("res://training_track.tscn").instantiate()
    var path = track.get_node("Path3D")
    var curve = path.curve
    
    var offset = 1350.0
    var t1 = path.global_transform * curve.sample_baked_with_rotation(offset, true, true)
    var t_prev = path.global_transform * curve.sample_baked_with_rotation(offset - 26.0, true, true)
    var t_next = path.global_transform * curve.sample_baked_with_rotation(offset + 26.0, true, true)
    
    var fwd_prev = -t_prev.basis.z.normalized()
    var fwd_next = -t_next.basis.z.normalized()
    
    var turn_rate = fwd_prev.angle_to(fwd_next)
    print("Turn rate at 1350m: ", turn_rate)
    print("Is hard turn? ", turn_rate > 0.05)
    quit()
