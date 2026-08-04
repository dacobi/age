extends SceneTree

func _init():
    var label = Label.new()
    label.text = "Hello World"
    label.add_theme_color_override("font_color", Color(1, 0, 0))
    print("Label created")
    quit()
