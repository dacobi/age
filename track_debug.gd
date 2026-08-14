extends SceneTree

var gen_mgr
var frame = 0

func _init():
    var track = load("res://training_track.tscn").instantiate()
    get_root().add_child(track)
    gen_mgr = track.get_node("GeneticManager")
    print("Started track debug...")

func _process(delta):
    frame += 1
    if frame % 30 == 0 and gen_mgr and gen_mgr.active_drivers.size() > 0:
        var best = gen_mgr.active_drivers[0]
        for d in gen_mgr.active_drivers:
            if d.fitness > best.fitness:
                best = d
        if best.car:
            var speed = best.car.linear_velocity.length()
            var speed_kmh = speed * 3.6
            var steer = best.car.steer_input
            var accel = best.car.accel_input
            var brake = best.car.brake_input
            var pos = best.car.global_position
            print("Best Car - Pos: (%.1f, %.1f, %.1f), Speed: %.1f km/h, Steer: %.2f, Accel: %.2f, Brake: %.2f, CP: %d, fitness: %.1f" % [pos.x, pos.y, pos.z, speed_kmh, steer, accel, brake, best.checkpoints_passed, best.fitness])
