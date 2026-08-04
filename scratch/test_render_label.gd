extends Node

func _ready():
    var label = Label.new()
    label.text = "TESTING LABEL"
    label.position = Vector2(100, 100)
    label.add_theme_color_override("font_color", Color(1, 0, 0))
    # add to current scene
    get_tree().root.add_child.call_deferred(label)
    print("Label added to root!")
