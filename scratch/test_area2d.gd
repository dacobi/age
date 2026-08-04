extends SceneTree

func _init():
    var area = Area2D.new()
    var shape = CollisionShape2D.new()
    var rect = RectangleShape2D.new()
    rect.size = Vector2(100, 100)
    shape.shape = rect
    area.add_child(shape)
    print("Area2D ready")
    quit()
