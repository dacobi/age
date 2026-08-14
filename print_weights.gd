extends SceneTree

func _init():
    var brain1 = ClassDB.instantiate("CarBrain")
    var brain2 = ClassDB.instantiate("CarBrain")
    print("Brain 1 weights: ", brain1.get_weights()[0], ", ", brain1.get_weights()[1])
    print("Brain 2 weights: ", brain2.get_weights()[0], ", ", brain2.get_weights()[1])
    quit()
