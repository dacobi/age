extends SceneTree

func _init():
    var label = Label.new()
    label.text = "TESTING LABEL"
    var ls = LabelSettings.new()
    ls.font_size = 32
    label.label_settings = ls
    print("Has font: ", ls.font != null)
    print("Label created")
    quit()
